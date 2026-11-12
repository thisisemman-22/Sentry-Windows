import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/secure_session_store.dart';
import '../core/network/ws_client.dart';
import '../features/access_logs/data/access_logs_repository.dart';
import '../features/administration/data/administration_repository.dart';
import '../features/authentication/data/auth_repository.dart';
import '../features/device_monitoring/data/device_monitoring_repository.dart';
import '../features/guard_reviews/data/guard_reviews_repository.dart';
import '../features/live_gate_monitoring/data/gate_monitoring_repository.dart';
import '../features/overview/state/overview_providers.dart';
import '../features/parking_management/data/parking_repository.dart';
import '../shared/fixtures/scenario_simulator.dart';
import '../shared/fixtures/synthetic_fixtures.dart';
import '../shared/models/auth_models.dart';

/// Runtime toggle for Developer Test Mode (unlocked via secret credentials,
/// 5x logo tap within 2s, or `Ctrl+Shift+Alt+D`).
final devModeUnlockedProvider = StateProvider<bool>((ref) => false);

/// Root compile-time/runtime configuration provider.
/// Defaults to `DATA_SOURCE=real` (`AppConfig.fromEnvironment()`), and switches
/// to `DataSourceMode.mock` in memory when `devModeUnlockedProvider` is unlocked.
final appConfigProvider = Provider<AppConfig>((ref) {
  final base = AppConfig.fromEnvironment();
  final devUnlocked = ref.watch(devModeUnlockedProvider);
  if (devUnlocked) {
    return base.copyWith(dataSource: DataSourceMode.mock);
  }
  return base;
});

/// Global ThemeMode provider (Light Mode vs. Pure OLED Dark Command Mode).
final themeModeProvider = StateProvider<ThemeMode>((ref) {
  return ThemeMode.light;
});

/// Global pointer position provider so `SentryInteractiveLogo` tracks the cursor
/// anywhere inside the Windows desktop window.
final globalPointerPositionProvider = StateProvider<Offset?>((ref) => null);

/// Secure session store provider.
final sessionStoreProvider = Provider<SecureSessionStore>((ref) {
  return InMemorySessionStore();
});

/// WebSocket invalidation coordinator (`§7.11`).
final wsCoordinatorProvider = Provider<WsInvalidationCoordinator>((ref) {
  final coord = WsInvalidationCoordinator();
  ref.onDispose(coord.dispose);
  return coord;
});

/// Centralized HTTP API Client (`lib/core/network/api_client.dart`).
final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final sessionStore = ref.watch(sessionStoreProvider);
  final wsCoordinator = ref.watch(wsCoordinatorProvider);
  return ApiClient(
    config: config,
    sessionStore: sessionStore,
    onSessionExpired: (reason) {
      wsCoordinator.handleCloseCode1008(reason);
    },
  );
});

/// Real WebSocket Client (`lib/core/network/ws_client.dart`) for `/api/v1/ws/updates`.
final Provider<WsRealtimeClient> wsRealtimeClientProvider =
    Provider<WsRealtimeClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final sessionStore = ref.watch(sessionStoreProvider);
  final coordinator = ref.watch(wsCoordinatorProvider);
  final client = WsRealtimeClient(
    config: config,
    sessionStore: sessionStore,
    coordinator: coordinator,
    onTargetedInvalidation: (_) {
      ref.read(sentryScenarioProvider.notifier).forceFullSnapshotResync();
    },
    onFullResyncRequired: (_) {
      ref.read(sentryScenarioProvider.notifier).forceFullSnapshotResync();
    },
  );
  ref.onDispose(() {
    client.dispose();
  });
  return client;
});

/// Feature Repository Providers (`DATA_SOURCE=real` HTTP adapters).
final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((ref) {
  return AuthRepository(apiClient: ref.watch(apiClientProvider));
});

final overviewRepositoryProvider = Provider<OverviewRepository>((ref) {
  return OverviewRepository(apiClient: ref.watch(apiClientProvider));
});

final gateMonitoringRepositoryProvider =
    Provider<GateMonitoringRepository>((ref) {
  return GateMonitoringRepository(apiClient: ref.watch(apiClientProvider));
});

final guardReviewsRepositoryProvider = Provider<GuardReviewsRepository>((ref) {
  return GuardReviewsRepository(apiClient: ref.watch(apiClientProvider));
});

final parkingRepositoryProvider = Provider<ParkingRepository>((ref) {
  return ParkingRepository(apiClient: ref.watch(apiClientProvider));
});

final accessLogsRepositoryProvider = Provider<AccessLogsRepository>((ref) {
  return AccessLogsRepository(apiClient: ref.watch(apiClientProvider));
});

final deviceMonitoringRepositoryProvider =
    Provider<DeviceMonitoringRepository>((ref) {
  return DeviceMonitoringRepository(apiClient: ref.watch(apiClientProvider));
});

final administrationRepositoryProvider =
    Provider<AdministrationRepository>((ref) {
  return AdministrationRepository(apiClient: ref.watch(apiClientProvider));
});

/// Authenticated session state (`SessionDto?` + optional error/expiry banner).
class AuthState {
  final SessionDto? session;
  final bool isLoading;
  final String? errorBanner;
  final String? sessionExpiredBanner;

  const AuthState({
    this.session,
    this.isLoading = false,
    this.errorBanner,
    this.sessionExpiredBanner,
  });

  bool get isAuthenticated => session != null && !session!.isExpired();

  ProfileDto? get profile => session?.profile;

  UserRole get role => session?.profile.role ?? UserRole.guard;

  AuthState copyWith({
    SessionDto? session,
    bool clearSession = false,
    bool? isLoading,
    String? errorBanner,
    bool clearError = false,
    String? sessionExpiredBanner,
    bool clearSessionExpired = false,
  }) {
    return AuthState(
      session: clearSession ? null : (session ?? this.session),
      isLoading: isLoading ?? this.isLoading,
      errorBanner: clearError ? null : (errorBanner ?? this.errorBanner),
      sessionExpiredBanner: clearSessionExpired
          ? null
          : (sessionExpiredBanner ?? this.sessionExpiredBanner),
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  static const String devBackdoorUsername = 'emman.dev@sentry.internal';
  static const String devBackdoorPassword = 'SENTRY-DEV-4102!';

  AppConfig config;
  final SecureSessionStore sessionStore;
  final AuthRepository? authRepository;
  final VoidCallback? onSessionCleared;
  final VoidCallback? onUnlockDevMode;

  AuthController({
    required this.config,
    required this.sessionStore,
    this.authRepository,
    this.onSessionCleared,
    this.onUnlockDevMode,
  }) : super(const AuthState());

  void updateConfig(AppConfig nextConfig) {
    config = nextConfig;
  }

  /// Authenticates a Guard or Administrator.
  /// Enforces generic 401 message (`"Invalid username or password"`) without leaking whether username exists.
  /// In `DATA_SOURCE=real`, calls `POST /api/v1/auth/login` and strictly fails closed on error,
  /// unless the hidden Developer Backdoor credentials (`emman.dev@sentry.internal` / `SENTRY-DEV-4102!`) are supplied.
  Future<bool> signIn({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSessionExpired: true,
    );

    final normalizedUser = username.trim().toLowerCase();
    final trimmedPass = password.trim();

    if (normalizedUser.isEmpty || trimmedPass.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorBanner: '401 UNAUTHORIZED: Invalid username or password',
      );
      return false;
    }

    // Secret Developer Backdoor: bypasses HTTP login, switches session to mock
    // mode in memory, loads U001–U007 fixtures, and logs in as Administrator.
    if (normalizedUser == devBackdoorUsername &&
        trimmedPass == devBackdoorPassword) {
      config = config.copyWith(dataSource: DataSourceMode.mock);
      onUnlockDevMode?.call();
      const adminProfile = SentryFixtures.adminOperator;
      final now = DateTime.now().toUtc();
      final devSession = SessionDto(
        sessionId: 'sess-${adminProfile.userCode.toLowerCase()}-dev-backdoor',
        accessToken:
            'sentry-jwt-${adminProfile.userCode.toLowerCase()}-dev-token',
        refreshToken:
            'sentry-refresh-${adminProfile.userCode.toLowerCase()}-dev-token',
        issuedAtUtc: now,
        expiresAtUtc: now.add(const Duration(hours: 8)),
        profile: adminProfile,
      );
      await sessionStore.saveSession(devSession);
      state = AuthState(session: devSession);
      return true;
    }

    final configErr = config.validateForRealMode();
    if (configErr != null) {
      state = state.copyWith(
        isLoading: false,
        errorBanner: configErr,
      );
      return false;
    }

    if (config.isReal && authRepository != null) {
      final response = await authRepository!.loginReal(
        LoginRequest(
          username: normalizedUser,
          password: trimmedPass,
        ),
      );
      if (!response.ok || response.data == null) {
        final err = response.error;
        state = state.copyWith(
          isLoading: false,
          errorBanner: err != null
              ? '${err.httpStatus} ${err.code}: ${err.message}'
              : '503 SERVICE_UNAVAILABLE: FastAPI authentication endpoint unreachable.',
        );
        return false;
      }
      final realSession = response.data!;
      if (!realSession.profile.role.isGuardOrAdmin) {
        state = state.copyWith(
          isLoading: false,
          errorBanner:
              '403 ACCESS_DENIED: Student principals must use the SENTRY Android Mobile Application.',
        );
        return false;
      }
      await sessionStore.saveSession(realSession);
      state = AuthState(session: realSession);
      return true;
    }

    ProfileDto? matchedProfile;
    if ((normalizedUser == 'guard01@sentry.test' ||
            normalizedUser == 'guard01' ||
            normalizedUser == 'g001') &&
        trimmedPass.length >= 4) {
      matchedProfile = SentryFixtures.guardOperator;
    } else if ((normalizedUser == 'admin01@sentry.test' ||
            normalizedUser == 'admin01' ||
            normalizedUser == 'a001') &&
        trimmedPass.length >= 4) {
      matchedProfile = SentryFixtures.adminOperator;
    }

    if (matchedProfile == null) {
      state = state.copyWith(
        isLoading: false,
        errorBanner: '401 UNAUTHORIZED: Invalid username or password',
      );
      return false;
    }

    // Desktop app is strictly for Guard and Administrator principals
    if (!matchedProfile.role.isGuardOrAdmin) {
      state = state.copyWith(
        isLoading: false,
        errorBanner:
            '403 ACCESS_DENIED: Student principals must use the SENTRY Android Mobile Application.',
      );
      return false;
    }

    final now = DateTime.now().toUtc();
    final session = SessionDto(
      sessionId: 'sess-${matchedProfile.userCode.toLowerCase()}-0001',
      accessToken:
          'sentry-jwt-${matchedProfile.userCode.toLowerCase()}-mock-token',
      refreshToken:
          'sentry-refresh-${matchedProfile.userCode.toLowerCase()}-mock-token',
      issuedAtUtc: now,
      expiresAtUtc: now.add(const Duration(hours: 8)),
      profile: matchedProfile,
    );

    await sessionStore.saveSession(session);
    state = AuthState(session: session);
    return true;
  }

  /// Quick persona switch for live defense demonstration (Guard <-> Administrator).
  Future<void> switchDemoPersona(UserRole targetRole) async {
    final profile = targetRole == UserRole.administrator
        ? SentryFixtures.adminOperator
        : SentryFixtures.guardOperator;
    final now = DateTime.now().toUtc();
    final session = SessionDto(
      sessionId: 'sess-${profile.userCode.toLowerCase()}-demo',
      accessToken: 'sentry-jwt-${profile.userCode.toLowerCase()}-mock-token',
      refreshToken:
          'sentry-refresh-${profile.userCode.toLowerCase()}-mock-token',
      issuedAtUtc: now,
      expiresAtUtc: now.add(const Duration(hours: 8)),
      profile: profile,
    );
    await sessionStore.saveSession(session);
    state = AuthState(session: session);
  }

  /// Logs out (`POST /api/v1/auth/logout`) and clears stored credentials.
  Future<void> signOut() async {
    if (config.isReal && authRepository != null) {
      await authRepository!.logoutReal();
    }
    await sessionStore.clearSession();
    onSessionCleared?.call();
    state = const AuthState();
  }

  /// Simulates an HTTP 401 or WebSocket 1008 session expiration redirect.
  Future<void> expireSessionWith1008([String? reason]) async {
    await sessionStore.clearSession();
    onSessionCleared?.call();
    state = AuthState(
      session: null,
      sessionExpiredBanner: reason ??
          'WS 1008 / HTTP 401 SESSION_EXPIRED: Your operator session has expired or was revoked. Please sign in again.',
    );
  }
}

final StateNotifierProvider<AuthController, AuthState> authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final config = ref.read(appConfigProvider);
  final sessionStore = ref.watch(sessionStoreProvider);
  final authRepo = ref.read(authRepositoryProvider);
  final wsCoordinator = ref.watch(wsCoordinatorProvider);
  final controller = AuthController(
    config: config,
    sessionStore: sessionStore,
    authRepository: authRepo,
    onSessionCleared: () {
      ref.read(devModeUnlockedProvider.notifier).state = false;
      ref.read(sentryScenarioProvider.notifier).resetToProductionRealMode();
    },
    onUnlockDevMode: () {
      ref.read(devModeUnlockedProvider.notifier).state = true;
      ref.read(sentryScenarioProvider.notifier).enableDeveloperMockMode();
    },
  );
  ref.listen<AppConfig>(appConfigProvider, (_, next) {
    controller.updateConfig(next);
  });
  final sub = wsCoordinator.sessionExpired1008Stream.listen((reason) {
    controller.expireSessionWith1008(reason);
  });
  ref.onDispose(sub.cancel);
  return controller;
});

/// Main SENTRY Scenario & Repository State Provider.
final StateNotifierProvider<SentryScenarioController, SentrySystemState>
    sentryScenarioProvider =
    StateNotifierProvider<SentryScenarioController, SentrySystemState>((ref) {
  final config = ref.read(appConfigProvider);
  final wsCoord = ref.watch(wsCoordinatorProvider);
  final controller = SentryScenarioController(
    initialRosterMode: config.initialRosterMode,
    wsCoordinator: wsCoord,
    dataSourceMode: config.dataSource,
    gateMonitoringRepository: ref.read(gateMonitoringRepositoryProvider),
    guardReviewsRepository: ref.read(guardReviewsRepositoryProvider),
    parkingRepository: ref.read(parkingRepositoryProvider),
    accessLogsRepository: ref.read(accessLogsRepositoryProvider),
    deviceMonitoringRepository: ref.read(deviceMonitoringRepositoryProvider),
    administrationRepository: ref.read(administrationRepositoryProvider),
  );
  ref.listen<AppConfig>(appConfigProvider, (prev, next) {
    if (next.isMock && prev?.isReal == true) {
      controller.enableDeveloperMockMode();
    }
  });
  return controller;
});

/// Currently selected Desktop Navigation View (Views 2–8 inside authenticated shell).
/// [title] is the short sidebar label; [subtitle] is the one-line page intro.
enum DesktopNavTab {
  overview('Overview', 'How campus parking looks right now.',
      Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
  liveGateMonitoring('Live Gates', 'Vehicles at the gates, as they arrive.',
      Icons.videocam_outlined, Icons.videocam_rounded),
  guardReviews('Reviews', 'Cases the system wasn\'t sure about.',
      Icons.fact_check_outlined, Icons.fact_check_rounded),
  parkingManagement('Parking', 'Every bay across Lots A to D.',
      Icons.local_parking_outlined, Icons.local_parking_rounded),
  accessLogs('Access Logs', 'Search entries, exits and registered vehicles.',
      Icons.receipt_long_outlined, Icons.receipt_long_rounded),
  deviceMonitoring('Devices', 'Cameras, readers and sensors on site.',
      Icons.router_outlined, Icons.router_rounded),
  administration('Administration', 'Accounts, vehicles and the audit trail.',
      Icons.admin_panel_settings_outlined, Icons.admin_panel_settings_rounded);

  final String title;
  final String subtitle;
  final IconData icon;
  final IconData selectedIcon;
  const DesktopNavTab(this.title, this.subtitle, this.icon, this.selectedIcon);
}

final selectedDesktopTabProvider = StateProvider<DesktopNavTab>((ref) {
  return DesktopNavTab.overview;
});

/// Lane currently focused on the Live Gates page
/// (`lane-car-in` | `lane-moto-in` | `lane-car-out` | `lane-moto-out`).
/// Demo scenarios set this so the operator lands on the relevant lane.
final focusedLaneProvider = StateProvider<String>((ref) => 'lane-car-in');
