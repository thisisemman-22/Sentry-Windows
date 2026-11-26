import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_envelope.dart';
import '../core/network/phase4_contract.dart';
import '../core/network/secure_session_store.dart';
import '../core/network/ws_client.dart';
import '../features/access_logs/data/access_logs_repository.dart';
import '../features/administration/data/admin_registration_api.dart';
import '../features/administration/data/administration_repository.dart';
import '../features/administration/state/register_form_controller.dart';
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
    onSessionRefreshed: (nextSession) {
      ref.read(authControllerProvider.notifier).applyRefreshedSession(nextSession);
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

/// Lazy Administrator-only Phase 4 registration API & form controller.
/// NEVER watched or instantiated in Guard sessions.
final Provider<AdminRegistrationApi> adminRegistrationApiProvider =
    Provider<AdminRegistrationApi>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.isMock) {
    return MockAdminRegistrationApi();
  }
  return HttpAdminRegistrationApi(apiClient: ref.watch(apiClientProvider));
});

final StateNotifierProvider<RegisterFormController, RegisterFormState>
    registerFormControllerProvider =
    StateNotifierProvider<RegisterFormController, RegisterFormState>((ref) {
  return RegisterFormController(
    readApi: () => ref.read(adminRegistrationApiProvider),
  );
});

final administrationRepositoryProvider =
    Provider<AdministrationRepository>((ref) {
  return AdministrationRepository(apiClient: ref.watch(apiClientProvider));
});

/// Authenticated session state (`SessionDto?` + optional banners).
class AuthState {
  final SessionDto? session;
  final bool isLoading;
  final String? errorBanner;
  final String? sessionExpiredBanner;
  final String? infoBanner;

  const AuthState({
    this.session,
    this.isLoading = false,
    this.errorBanner,
    this.sessionExpiredBanner,
    this.infoBanner,
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
    String? infoBanner,
    bool clearInfo = false,
  }) {
    return AuthState(
      session: clearSession ? null : (session ?? this.session),
      isLoading: isLoading ?? this.isLoading,
      errorBanner: clearError ? null : (errorBanner ?? this.errorBanner),
      sessionExpiredBanner: clearSessionExpired
          ? null
          : (sessionExpiredBanner ?? this.sessionExpiredBanner),
      infoBanner: clearInfo ? null : (infoBanner ?? this.infoBanner),
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
  final VoidCallback? onDifferentAccountSignedIn;
  final String? initialUserId;

  String? _lastAuthenticatedUserId;

  AuthController({
    required this.config,
    required this.sessionStore,
    this.authRepository,
    this.onSessionCleared,
    this.onUnlockDevMode,
    this.onDifferentAccountSignedIn,
    this.initialUserId,
  })  : _lastAuthenticatedUserId = initialUserId,
        super(const AuthState());

  void updateConfig(AppConfig nextConfig) {
    config = nextConfig;
  }

  /// Updates session tokens silently after a single-flight refresh WITHOUT
  /// resetting open Admin forms or pending `Idempotency-Key`.
  void applyRefreshedSession(SessionDto nextSession) {
    state = state.copyWith(
      session: nextSession,
      clearError: true,
    );
  }

  void setLoginInfoBanner(String message) {
    state = state.copyWith(
      infoBanner: message,
      clearError: true,
      clearSessionExpired: true,
    );
  }

  void _recordSignedInAccount(String userId) {
    if (_lastAuthenticatedUserId != null && _lastAuthenticatedUserId != userId) {
      onDifferentAccountSignedIn?.call();
    }
    _lastAuthenticatedUserId = userId;
  }

  /// Authenticates a Guard or Administrator (`POST /api/v1/auth/login` -> `GET /api/v1/me`).
  /// - NEVER trims or normalizes `password`.
  /// - Returns neutral `"Sign-in failed"` on `401 AUTHENTICATION_FAILED`.
  /// - Rejects mobile-only roles (`student`, `faculty`, `staff`) with `"Please use the SENTRY Mobile Application"`, calls logout, and clears tokens.
  Future<bool> signIn({
    String? identifier,
    String? username,
    required String password,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSessionExpired: true,
      clearInfo: true,
    );

    final rawIdentifier = identifier ?? username ?? '';
    final cleanIdentifier = rawIdentifier.trim();
    final normalizedLower = cleanIdentifier.toLowerCase();

    if (cleanIdentifier.isEmpty || password.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorBanner: 'Sign-in failed',
      );
      return false;
    }

    // Secret Developer Backdoor: bypasses HTTP login, switches session to mock
    // mode in memory, loads U001–U007 fixtures, and logs in as Administrator.
    if (normalizedLower == devBackdoorUsername &&
        password == devBackdoorPassword) {
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
        refreshExpiresAtUtc: now.add(const Duration(hours: 12)),
        profile: adminProfile,
      );
      _recordSignedInAccount(adminProfile.userId);
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
      final loginRes = await authRepository!.login(
        LoginRequest(
          identifier: cleanIdentifier,
          password: password,
        ),
      );
      if (!loginRes.ok || loginRes.data == null) {
        final err = loginRes.error;
        final String msg;
        if (err == null) {
          msg =
              '503 SERVICE_UNAVAILABLE (Request ID: ${loginRes.meta.requestId}): Authentication endpoint unreachable.';
        } else if (err.code == ErrorCatalog.authenticationFailed ||
            err.httpStatus == 401) {
          msg = 'Sign-in failed';
        } else {
          final failure = Phase4ApiFailure.fromError(
            err,
            requestId: loginRes.meta.requestId,
          );
          msg = '${failure.userDisplayMessage} [Request ID: ${loginRes.meta.requestId}]';
        }
        state = state.copyWith(
          isLoading: false,
          errorBanner: msg,
        );
        return false;
      }

      final pair = loginRes.data!;
      // Save provisional token pair so getOwnProfile sends Bearer authorization.
      final provisionalSession = SessionDto(
        sessionId: 'sess-provisional',
        accessToken: pair.accessToken,
        refreshToken: pair.refreshToken,
        tokenType: pair.tokenType,
        issuedAtUtc: DateTime.now().toUtc(),
        expiresAtUtc: pair.accessExpiresAtUtc,
        refreshExpiresAtUtc: pair.refreshExpiresAtUtc,
        profile: SentryFixtures.guardOperator,
      );
      await sessionStore.saveSession(provisionalSession);

      final profileRes = await authRepository!.getOwnProfile();
      if (!profileRes.ok || profileRes.data == null) {
        await sessionStore.clearSession();
        final err = profileRes.error;
        state = state.copyWith(
          isLoading: false,
          errorBanner: err != null
              ? 'Unable to load account profile (${err.code}). [Request ID: ${profileRes.meta.requestId}]'
              : '503 SERVICE_UNAVAILABLE: Unable to verify operator role. [Request ID: ${profileRes.meta.requestId}]',
        );
        return false;
      }

      final profileData = profileRes.data!;
      if (!profileData.role.isGuardOrAdmin) {
        try {
          await authRepository!.logoutCurrentSession();
        } catch (_) {}
        await sessionStore.clearSession();
        state = state.copyWith(
          isLoading: false,
          errorBanner: 'Please use the SENTRY Mobile Application',
        );
        return false;
      }

      final realSession = SessionDto.fromTokenPairAndProfile(pair, profileData);
      _recordSignedInAccount(profileData.id);
      await sessionStore.saveSession(realSession);
      state = AuthState(session: realSession);
      return true;
    }

    // Mock / Developer Test Mode authentication
    ProfileDto? matchedProfile;
    if ((normalizedLower == 'guard01@sentry.test' ||
            normalizedLower == 'guard01' ||
            normalizedLower == 'g001') &&
        password.length >= 4) {
      matchedProfile = SentryFixtures.guardOperator;
    } else if ((normalizedLower == 'admin01@sentry.test' ||
            normalizedLower == 'admin01' ||
            normalizedLower == 'a001') &&
        password.length >= 4) {
      matchedProfile = SentryFixtures.adminOperator;
    }

    if (matchedProfile == null) {
      state = state.copyWith(
        isLoading: false,
        errorBanner: 'Sign-in failed',
      );
      return false;
    }

    if (!matchedProfile.role.isGuardOrAdmin) {
      state = state.copyWith(
        isLoading: false,
        errorBanner: 'Please use the SENTRY Mobile Application',
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
      expiresAtUtc: now.add(
        matchedProfile.role.isAdmin
            ? const Duration(minutes: 5)
            : const Duration(minutes: 10),
      ),
      refreshExpiresAtUtc: now.add(const Duration(hours: 8)),
      profile: matchedProfile,
    );

    _recordSignedInAccount(matchedProfile.userId);
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
      refreshExpiresAtUtc: now.add(const Duration(hours: 12)),
      profile: profile,
    );
    _recordSignedInAccount(profile.userId);
    await sessionStore.saveSession(session);
    state = AuthState(session: session);
  }

  /// Calls `POST /api/v1/auth/logout` with `{}` and ALWAYS clears local tokens
  /// on every outcome (including `503` or network failure).
  Future<void> signOut() async {
    try {
      if (config.isReal && authRepository != null) {
        await authRepository!.logoutCurrentSession();
      }
    } catch (_) {
      // Discard local tokens regardless of backend outcome.
    } finally {
      await sessionStore.clearSession();
      onSessionCleared?.call();
      state = const AuthState();
    }
  }

  /// Changes the authenticated caller's password (`POST /api/v1/auth/password/change`).
  /// Never trims passwords. On `200`, revokes every session and redirects to `LoginScreen`.
  Future<ApiEnvelope<bool>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final policyErr = validatePasswordPolicy(newPassword);
    if (policyErr != null) {
      return ApiEnvelope.failure(
        code: ErrorCatalog.passwordPolicyRejected,
        message: policyErr,
        httpStatus: 400,
      );
    }

    if (config.isReal && authRepository != null) {
      final res = await authRepository!.changePassword(
        PasswordChangeRequest(
          currentPassword: currentPassword,
          newPassword: newPassword,
        ),
      );
      if (res.ok) {
        await sessionStore.clearSession();
        onSessionCleared?.call();
        state = const AuthState(
          infoBanner:
              'Password changed. Every active session was signed out; please sign in again.',
        );
      } else if (res.error?.code == ErrorCatalog.passwordChangeConflict) {
        await sessionStore.clearSession();
        onSessionCleared?.call();
        state = AuthState(
          errorBanner:
              'Credentials changed concurrently. Please sign in again. [Request ID: ${res.meta.requestId}]',
        );
      }
      return res;
    }

    // Mock / Developer Test Mode behavior
    if (currentPassword.isEmpty) {
      return ApiEnvelope.failure(
        code: ErrorCatalog.currentPasswordInvalid,
        message: 'Current password is incorrect.',
        httpStatus: 400,
      );
    }
    if (currentPassword == newPassword) {
      return ApiEnvelope.failure(
        code: ErrorCatalog.passwordPolicyRejected,
        message: 'New password cannot reuse the current password.',
        httpStatus: 400,
      );
    }

    await sessionStore.clearSession();
    onSessionCleared?.call();
    state = const AuthState(
      infoBanner:
          'Password changed (Developer Test Mode). All sessions signed out; please sign in again.',
    );
    return ApiEnvelope.success(true, requestId: 'mock-pwd-change-200');
  }

  /// Handles HTTP 401 refresh failure or WebSocket 1008 session expiration.
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
      ref.read(selectedDesktopTabProvider.notifier).state =
          DesktopNavTab.overview;
      ref.read(sentryScenarioProvider.notifier).resetToProductionRealMode();
    },
    onUnlockDevMode: () {
      ref.read(devModeUnlockedProvider.notifier).state = true;
      ref.read(sentryScenarioProvider.notifier).enableDeveloperMockMode();
    },
    onDifferentAccountSignedIn: () {
      if (ref.exists(registerFormControllerProvider)) {
        ref.read(registerFormControllerProvider.notifier).resetAll();
      }
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
  parkingManagement('Parking', 'Every bay across Lots B1 to B5.',
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

/// Currently selected campus lot tab in View 5 (`'B1'..'B5'` or `'MATRIX'`).
final selectedParkingLotProvider = StateProvider<String>((ref) => 'B1');

/// Lane currently focused on the Live Gates page
/// (`lane-car-in` | `lane-moto-in` | `lane-car-out` | `lane-moto-out`).
/// Demo scenarios set this so the operator lands on the relevant lane.
final focusedLaneProvider = StateProvider<String>((ref) => 'lane-car-in');
