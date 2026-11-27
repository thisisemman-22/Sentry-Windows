import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_envelope.dart';
import '../core/network/phase4_contract.dart';
import '../core/network/secure_session_store.dart';
import '../core/network/ws_client.dart';
import '../features/access_logs/data/access_logs_repository.dart';
import '../features/admin_ops/data/desktop_ops_repository.dart';
import '../features/admin_ops/state/desktop_ops_controller.dart';
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

final desktopOpsRepositoryProvider = Provider<DesktopOpsRepository>((ref) {
  return RealDesktopOpsRepository(apiClient: ref.watch(apiClientProvider));
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
    final bool forceFirstLogin = password == 'SENTRY-WELCOME-2026!';
    if ((normalizedLower == 'firstlogin@sentry.test' ||
            normalizedLower == 'newguard@sentry.test') &&
        password.length >= 4) {
      matchedProfile = SentryFixtures.guardOperator.copyWith(
        firstLoginRequired: true,
      );
    } else if ((normalizedLower == 'guard01@sentry.test' ||
            normalizedLower == 'guard01' ||
            normalizedLower == 'g001') &&
        password.length >= 4) {
      matchedProfile = SentryFixtures.guardOperator.copyWith(
        firstLoginRequired: forceFirstLogin,
      );
    } else if ((normalizedLower == 'admin01@sentry.test' ||
            normalizedLower == 'admin01' ||
            normalizedLower == 'a001') &&
        password.length >= 4) {
      matchedProfile = SentryFixtures.adminOperator.copyWith(
        firstLoginRequired: forceFirstLogin,
      );
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

  /// Completes forced first-login password setup (`first_login_required == true`)
  /// with matching validation, clearing the flag so the operator enters [DesktopShell].
  Future<ApiEnvelope<bool>> completeFirstLoginPassword({
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (newPassword != confirmPassword) {
      return ApiEnvelope.failure(
        code: ErrorCatalog.validationError,
        message: 'Both password fields must match exactly.',
        httpStatus: 400,
      );
    }
    final policyErr = validatePasswordPolicy(newPassword);
    if (policyErr != null) {
      return ApiEnvelope.failure(
        code: ErrorCatalog.passwordPolicyRejected,
        message: policyErr,
        httpStatus: 400,
      );
    }
    if (newPassword == 'SENTRY-WELCOME-2026!') {
      return ApiEnvelope.failure(
        code: ErrorCatalog.passwordPolicyRejected,
        message: 'New password cannot reuse the General Password.',
        httpStatus: 400,
      );
    }

    final current = state.session;
    if (current == null) {
      return ApiEnvelope.failure(
        code: ErrorCatalog.authenticationRequired,
        message: 'Operator session unavailable.',
        httpStatus: 401,
      );
    }

    if (config.isReal && authRepository != null) {
      // TODO(API): confirm dedicated /api/v1/auth/first-login/password if separate from /password/change
      final res = await authRepository!.changePassword(
        PasswordChangeRequest(
          currentPassword: 'SENTRY-WELCOME-2026!',
          newPassword: newPassword,
        ),
      );
      if (!res.ok) return res;
    }

    final updatedSession = current.copyWith(
      profile: current.profile.copyWith(firstLoginRequired: false),
    );
    await sessionStore.saveSession(updatedSession);
    state = state.copyWith(
      session: updatedSession,
      clearError: true,
    );
    return ApiEnvelope.success(true, requestId: 'first-login-complete');
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
          DesktopNavTab.dashboard;
      ref.read(monitoringSubTabProvider.notifier).state = 0;
      ref.read(usersSubTabProvider.notifier).state = 0;
      ref.read(sentryScenarioProvider.notifier).resetToProductionRealMode();
      ref.read(desktopOpsControllerProvider.notifier).resetToProductionRealMode();
    },
    onUnlockDevMode: () {
      ref.read(devModeUnlockedProvider.notifier).state = true;
      ref.read(sentryScenarioProvider.notifier).enableDeveloperMockMode();
      ref.read(desktopOpsControllerProvider.notifier).enableDeveloperMockMode();
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

final StateNotifierProvider<DesktopOpsController, DesktopOpsState>
    desktopOpsControllerProvider =
    StateNotifierProvider<DesktopOpsController, DesktopOpsState>((ref) {
  final config = ref.read(appConfigProvider);
  final repo = ref.watch(desktopOpsRepositoryProvider);
  final controller = DesktopOpsController(
    dataSourceMode: config.dataSource,
    repository: repo,
    onAppendAudit: (log) {
      ref.read(sentryScenarioProvider.notifier).appendAuditLog(log);
    },
  );
  ref.listen<AppConfig>(appConfigProvider, (prev, next) {
    if (next.isMock && prev?.isReal == true) {
      controller.enableDeveloperMockMode();
    } else if (next.isReal && prev?.isMock == true) {
      controller.resetToProductionRealMode();
    }
  });
  return controller;
});

/// Updated 10-Section SENTRY Desktop Navigation (2026-11-27 Spec).
enum DesktopNavTab {
  dashboard('Dashboard', 'How campus parking looks right now.',
      Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, false),
  users('Users', 'Accounts, registration, face enrollment & password resets.',
      Icons.people_outline_rounded, Icons.people_rounded, true),
  vehiclesRfid('Vehicles & RFID', 'Vehicles, user requests & RFID inventory.',
      Icons.directions_car_outlined, Icons.directions_car_rounded, true),
  parking('Parking', 'Lots B1–B5 blueprints, status & parking rules.',
      Icons.local_parking_outlined, Icons.local_parking_rounded, false),
  guests('Guests', 'Guest visit approvals, accounts & overdue stays.',
      Icons.badge_outlined, Icons.badge_rounded, true),
  monitoring('Monitoring', 'Live gates, reviews, entries/exits & hardware.',
      Icons.videocam_outlined, Icons.videocam_rounded, false),
  reports('Reports', 'Preset reports, masked previews & CSV/PDF exports.',
      Icons.analytics_outlined, Icons.analytics_rounded, false),
  announcements('Announcements', 'Member notices pushed to mobile app.',
      Icons.campaign_outlined, Icons.campaign_rounded, true),
  audit('Audit', 'Searchable security and administrative audit trail.',
      Icons.policy_outlined, Icons.policy_rounded, true),
  settings('Settings', 'Read-only backend security & system configuration.',
      Icons.settings_outlined, Icons.settings_rounded, true);

  final String title;
  final String subtitle;
  final IconData icon;
  final IconData selectedIcon;
  final bool isAdminOnly;
  const DesktopNavTab(
    this.title,
    this.subtitle,
    this.icon,
    this.selectedIcon,
    this.isAdminOnly,
  );
}

final selectedDesktopTabProvider = StateProvider<DesktopNavTab>((ref) {
  return DesktopNavTab.dashboard;
});

/// Active sub-tab inside View 6 `Monitoring`
/// (0: Live Gates, 1: Review Cases, 2: Entries & Exits, 3: Cameras & Devices, 4: Guard Accounts [Admin Only]).
final monitoringSubTabProvider = StateProvider<int>((ref) => 0);

/// Active sub-tab inside View 2 `Users` (Admin Only)
/// (0: Directory, 1: Register User, 2: Face Enrollment, 3: Phase 4 OTP & Activation).
final usersSubTabProvider = StateProvider<int>((ref) => 0);

/// Currently selected campus lot tab in Parking (`'B1'..'B5'`, `'MATRIX'`, `'RULES'`).
final selectedParkingLotProvider = StateProvider<String>((ref) => 'B1');

/// Lane currently focused on Live Gates (`lane-car-in` | `lane-car-out` | `lane-moto-in` | `lane-moto-out`).
final focusedLaneProvider = StateProvider<String>((ref) => 'lane-car-in');
