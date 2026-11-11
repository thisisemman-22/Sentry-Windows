import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/app_config.dart';
import '../core/network/secure_session_store.dart';
import '../core/network/ws_client.dart';
import '../shared/fixtures/scenario_simulator.dart';
import '../shared/fixtures/synthetic_fixtures.dart';
import '../shared/models/auth_models.dart';

/// Root compile-time/runtime configuration provider.
final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
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
  final AppConfig config;
  final SecureSessionStore sessionStore;

  AuthController({
    required this.config,
    required this.sessionStore,
  }) : super(const AuthState());

  /// Authenticates a Guard (`guard01@sentry.test`) or Administrator (`admin01@sentry.test`).
  /// Enforces generic 401 message (`"Invalid username or password"`) without leaking whether username exists.
  Future<bool> signIn({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSessionExpired: true,
    );

    final configErr = config.validateForRealMode();
    if (configErr != null) {
      state = state.copyWith(
        isLoading: false,
        errorBanner: configErr,
      );
      return false;
    }

    final normalizedUser = username.trim().toLowerCase();
    final trimmedPass = password.trim();

    if (normalizedUser.isEmpty || trimmedPass.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorBanner: '401 UNAUTHORIZED: Invalid username or password',
      );
      return false;
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
      accessToken: 'sentry-jwt-${matchedProfile.userCode.toLowerCase()}-mock-token',
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
      issuedAtUtc: now,
      expiresAtUtc: now.add(const Duration(hours: 8)),
      profile: profile,
    );
    await sessionStore.saveSession(session);
    state = AuthState(session: session);
  }

  /// Logs out (`POST /api/v1/auth/logout`) and clears stored credentials.
  Future<void> signOut() async {
    await sessionStore.clearSession();
    state = const AuthState();
  }

  /// Simulates an HTTP 401 or WebSocket 1008 session expiration redirect.
  Future<void> expireSessionWith1008([String? reason]) async {
    await sessionStore.clearSession();
    state = AuthState(
      session: null,
      sessionExpiredBanner: reason ??
          'WS 1008 / HTTP 401 SESSION_EXPIRED: Your operator session has expired or was revoked. Please sign in again.',
    );
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    config: ref.watch(appConfigProvider),
    sessionStore: ref.watch(sessionStoreProvider),
  );
});

/// Main SENTRY Scenario & Mock Repository State Provider.
final sentryScenarioProvider =
    StateNotifierProvider<SentryScenarioController, SentrySystemState>((ref) {
  final config = ref.watch(appConfigProvider);
  final wsCoord = ref.watch(wsCoordinatorProvider);
  return SentryScenarioController(
    initialRosterMode: config.initialRosterMode,
    wsCoordinator: wsCoord,
  );
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
