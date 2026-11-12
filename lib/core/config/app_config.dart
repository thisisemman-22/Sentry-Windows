import 'roster_mode.dart';

enum DataSourceMode {
  mock,
  real;

  static DataSourceMode fromString(String value) {
    return value.trim().toLowerCase() == 'mock'
        ? DataSourceMode.mock
        : DataSourceMode.real;
  }
}

/// Compile-time and runtime configuration for SENTRY Desktop (`campus_parking_desktop`).
/// Reads `--dart-define` / `--dart-define-from-file=config/local.example.json` values.
///
/// Safety rule: In `DataSourceMode.real`, the app fails closed if `apiBaseUrl` or
/// `wsBaseUrl` is missing or invalid, and never falls back to mock success.
class AppConfig {
  final String appEnv;
  final DataSourceMode dataSource;
  final RosterMode initialRosterMode;
  final String apiBaseUrl;
  final String wsBaseUrl;
  final int requestTimeoutMs;
  final String displayTimezone;

  const AppConfig({
    required this.appEnv,
    required this.dataSource,
    required this.initialRosterMode,
    required this.apiBaseUrl,
    required this.wsBaseUrl,
    required this.requestTimeoutMs,
    required this.displayTimezone,
  });

  factory AppConfig.fromEnvironment() {
    const appEnv =
        String.fromEnvironment('APP_ENV', defaultValue: 'production');
    const dataSourceStr =
        String.fromEnvironment('DATA_SOURCE', defaultValue: 'real');
    const rosterModeStr =
        String.fromEnvironment('ROSTER_MODE', defaultValue: 'class_demo');
    // TODO(API): Replace API_URL_PLACEHOLDER with Patrick's live FastAPI LAN/Tunnel URL
    const apiBaseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://API_URL_PLACEHOLDER.local:8000',
    );
    // TODO(API): Replace API_URL_PLACEHOLDER with Patrick's live FastAPI LAN/Tunnel URL
    const wsBaseUrl = String.fromEnvironment(
      'WS_BASE_URL',
      defaultValue: 'wss://API_URL_PLACEHOLDER.local:8000/api/v1/ws/updates',
    );
    const requestTimeoutMs =
        int.fromEnvironment('REQUEST_TIMEOUT_MS', defaultValue: 5000);
    const displayTimezone =
        String.fromEnvironment('DISPLAY_TIMEZONE', defaultValue: 'Asia/Manila');

    return AppConfig(
      appEnv: appEnv,
      dataSource: DataSourceMode.fromString(dataSourceStr),
      initialRosterMode: RosterMode.fromString(rosterModeStr),
      apiBaseUrl: apiBaseUrl,
      wsBaseUrl: wsBaseUrl,
      requestTimeoutMs: requestTimeoutMs,
      displayTimezone: displayTimezone,
    );
  }

  bool get isMock => dataSource == DataSourceMode.mock;
  bool get isReal => dataSource == DataSourceMode.real;

  /// Validates configuration when running in strict `DATA_SOURCE=real` mode.
  String? validateForRealMode() {
    if (!isReal) return null;
    if (apiBaseUrl.trim().isEmpty || !apiBaseUrl.startsWith('http')) {
      return 'CONFIGURATION_INVALID: API_BASE_URL must be a valid HTTP/HTTPS URL in DATA_SOURCE=real mode.';
    }
    if (wsBaseUrl.trim().isEmpty || !wsBaseUrl.startsWith('ws')) {
      return 'CONFIGURATION_INVALID: WS_BASE_URL must be a valid WS/WSS URL in DATA_SOURCE=real mode.';
    }
    return null;
  }

  AppConfig copyWith({
    String? appEnv,
    DataSourceMode? dataSource,
    RosterMode? initialRosterMode,
    String? apiBaseUrl,
    String? wsBaseUrl,
    int? requestTimeoutMs,
    String? displayTimezone,
  }) {
    return AppConfig(
      appEnv: appEnv ?? this.appEnv,
      dataSource: dataSource ?? this.dataSource,
      initialRosterMode: initialRosterMode ?? this.initialRosterMode,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      wsBaseUrl: wsBaseUrl ?? this.wsBaseUrl,
      requestTimeoutMs: requestTimeoutMs ?? this.requestTimeoutMs,
      displayTimezone: displayTimezone ?? this.displayTimezone,
    );
  }
}
