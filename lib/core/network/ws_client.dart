import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../shared/models/event_envelope.dart';
import '../config/app_config.dart';
import 'secure_session_store.dart';

enum WsConnectionStatus {
  connected,
  reconnecting,
  staleOffline,
  sessionExpired,
}

/// State tracked by the WebSocket `RealtimeUpdate` (`§7.11`) client.
class WsStreamState {
  final WsConnectionStatus status;
  final int lastStreamSequence;
  final DateTime? lastSyncedAtUtc;
  final bool resyncRequired;
  final int duplicateEventsIgnored;
  final int sequenceGapResyncCount;
  final String? lastErrorMessage;

  const WsStreamState({
    required this.status,
    required this.lastStreamSequence,
    this.lastSyncedAtUtc,
    this.resyncRequired = false,
    this.duplicateEventsIgnored = 0,
    this.sequenceGapResyncCount = 0,
    this.lastErrorMessage,
  });

  bool get isHealthy =>
      status == WsConnectionStatus.connected && !resyncRequired;

  WsStreamState copyWith({
    WsConnectionStatus? status,
    int? lastStreamSequence,
    DateTime? lastSyncedAtUtc,
    bool? resyncRequired,
    int? duplicateEventsIgnored,
    int? sequenceGapResyncCount,
    String? lastErrorMessage,
  }) {
    return WsStreamState(
      status: status ?? this.status,
      lastStreamSequence: lastStreamSequence ?? this.lastStreamSequence,
      lastSyncedAtUtc: lastSyncedAtUtc ?? this.lastSyncedAtUtc,
      resyncRequired: resyncRequired ?? this.resyncRequired,
      duplicateEventsIgnored:
          duplicateEventsIgnored ?? this.duplicateEventsIgnored,
      sequenceGapResyncCount:
          sequenceGapResyncCount ?? this.sequenceGapResyncCount,
      lastErrorMessage: lastErrorMessage,
    );
  }
}

/// Handles `realtime_update` (`§7.11`) WebSocket invalidation signals, enforcing:
/// - `event_id` deduplication
/// - Monotonic `stream_sequence` validation (sequence gap triggers full snapshot resync)
/// - `refresh_required: true` targeted resource refetch for `access_attempt`, `access_visit`,
///   `parking_assignment`, `parking_space`, `guard_review`, and `device`
/// - `resync_required: true` full snapshot recovery
/// - WebSocket close code `1008` policy/session expiration redirect
class WsInvalidationCoordinator {
  final Set<String> _seenEventIds = <String>{};
  final Map<String, int> _resourceVersions = <String, int>{};

  WsStreamState _state = WsStreamState(
    status: WsConnectionStatus.connected,
    lastStreamSequence: 0,
    lastSyncedAtUtc: DateTime.now().toUtc(),
  );

  final StreamController<WsStreamState> _stateController =
      StreamController<WsStreamState>.broadcast();
  final StreamController<RealtimeUpdateData> _refreshController =
      StreamController<RealtimeUpdateData>.broadcast();
  final StreamController<String> _fullResyncController =
      StreamController<String>.broadcast();
  final StreamController<String> _sessionExpired1008Controller =
      StreamController<String>.broadcast();

  WsStreamState get state => _state;
  Stream<WsStreamState> get stateStream => _stateController.stream;
  Stream<RealtimeUpdateData> get targetedRefreshStream =>
      _refreshController.stream;
  Stream<String> get fullResyncStream => _fullResyncController.stream;
  Stream<String> get sessionExpired1008Stream =>
      _sessionExpired1008Controller.stream;

  /// Processes a raw JSON string or map received from `/api/v1/ws/updates`.
  bool handleRawFrame(dynamic rawFrame) {
    try {
      final Map<String, dynamic> decoded;
      if (rawFrame is String) {
        decoded = jsonDecode(rawFrame) as Map<String, dynamic>;
      } else if (rawFrame is Map<String, dynamic>) {
        decoded = rawFrame;
      } else {
        return false;
      }
      final envelope = CommonEventEnvelope<RealtimeUpdateData>.fromJson(
        decoded,
        RealtimeUpdateData.fromJson,
      );
      return handleRealtimeEnvelope(envelope);
    } catch (e) {
      markOfflineOrStale('Malformed realtime_update frame: $e');
      return false;
    }
  }

  /// Processes an incoming `CommonEventEnvelope<RealtimeUpdateData>` (`§7.11`).
  /// Returns `true` if the update was applied or triggered a resync, `false` if ignored as duplicate/older.
  bool handleRealtimeEnvelope(
    CommonEventEnvelope<RealtimeUpdateData> envelope,
  ) {
    // 1. Deduplicate by event_id
    if (_seenEventIds.contains(envelope.eventId)) {
      _updateState(
        _state.copyWith(
          duplicateEventsIgnored: _state.duplicateEventsIgnored + 1,
        ),
      );
      return false;
    }
    _seenEventIds.add(envelope.eventId);

    final data = envelope.data;
    final expectedSeq = _state.lastStreamSequence + 1;

    // 2. Check for explicit resync_required or sequence gap
    if (data.resyncRequired ||
        (_state.lastStreamSequence > 0 && data.streamSequence > expectedSeq)) {
      final gapReason = data.resyncRequired
          ? 'Server signaled resync_required=true at seq ${data.streamSequence}'
          : 'Sequence gap detected (expected $expectedSeq, received ${data.streamSequence})';
      _updateState(
        _state.copyWith(
          status: WsConnectionStatus.connected,
          lastStreamSequence: data.streamSequence,
          lastSyncedAtUtc: envelope.occurredAtUtc,
          resyncRequired: true,
          sequenceGapResyncCount: _state.sequenceGapResyncCount + 1,
          lastErrorMessage: gapReason,
        ),
      );
      _fullResyncController.add(gapReason);
      return true;
    }

    // Ignore out-of-order older stream sequence frames
    if (_state.lastStreamSequence > 0 &&
        data.streamSequence <= _state.lastStreamSequence) {
      return false;
    }

    // 3. Check resource_version monotonic guard per (resource_type, resource_id)
    final resourceKey = '${data.resourceType}:${data.resourceId}';
    final currentVersion = _resourceVersions[resourceKey] ?? 0;
    if (data.resourceVersion < currentVersion) {
      return false;
    }
    _resourceVersions[resourceKey] = data.resourceVersion;

    _updateState(
      _state.copyWith(
        status: WsConnectionStatus.connected,
        lastStreamSequence: data.streamSequence,
        lastSyncedAtUtc: envelope.occurredAtUtc,
        resyncRequired: false,
      ),
    );

    if (data.refreshRequired) {
      _refreshController.add(data);
    }
    return true;
  }

  /// Simulates or records a WebSocket disconnect / stale telemetry state (`T18`).
  void markOfflineOrStale(String reason) {
    _updateState(
      _state.copyWith(
        status: WsConnectionStatus.staleOffline,
        resyncRequired: true,
        lastErrorMessage: reason,
      ),
    );
  }

  /// Simulates or handles WebSocket `1008` policy/auth expiration close code.
  void handleCloseCode1008(String reason) {
    final msg = 'WS 1008 Policy Violation / Session Expired: $reason';
    _updateState(
      _state.copyWith(
        status: WsConnectionStatus.sessionExpired,
        resyncRequired: true,
        lastErrorMessage: msg,
      ),
    );
    if (!_sessionExpired1008Controller.isClosed) {
      _sessionExpired1008Controller.add(msg);
    }
  }

  /// Restores live sync and triggers a full snapshot resync.
  void reconnectAndResync() {
    _updateState(
      _state.copyWith(
        status: WsConnectionStatus.connected,
        lastSyncedAtUtc: DateTime.now().toUtc(),
        resyncRequired: false,
        lastErrorMessage: null,
      ),
    );
    _fullResyncController.add('Manual/Automatic reconnect full snapshot resync');
  }

  void _updateState(WsStreamState next) {
    _state = next;
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }

  void dispose() {
    _stateController.close();
    _refreshController.close();
    _fullResyncController.close();
    _sessionExpired1008Controller.close();
  }
}

/// Real WebSocket client for `/api/v1/ws/updates` when `DATA_SOURCE=real`.
/// Security rule: NEVER puts reusable bearer tokens in the query URL!
/// Uses an authorization handshake frame / subprotocol ticket upon connect,
/// and enforces exponential reconnection backoff (`1s, 2s, 4s, 8s, 16s` capped with jitter).
class WsRealtimeClient {
  static const List<int> backoffSecondsSchedule = <int>[1, 2, 4, 8, 16];

  final AppConfig config;
  final SecureSessionStore sessionStore;
  final WsInvalidationCoordinator coordinator;
  final bool enableAutoReconnect;
  final void Function(String reason)? onSessionExpired;
  final void Function(RealtimeUpdateData update)? onTargetedInvalidation;
  final void Function(String reason)? onFullResyncRequired;

  final math.Random _rng = math.Random();
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  StreamSubscription<RealtimeUpdateData>? _targetedSub;
  StreamSubscription<String>? _resyncSub;
  StreamSubscription<String>? _expiredSub;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _isDisposed = false;
  bool _hadPriorConnection = false;

  WsRealtimeClient({
    required this.config,
    required this.sessionStore,
    required this.coordinator,
    this.enableAutoReconnect = true,
    this.onSessionExpired,
    this.onTargetedInvalidation,
    this.onFullResyncRequired,
  }) {
    _targetedSub = coordinator.targetedRefreshStream.listen((update) {
      onTargetedInvalidation?.call(update);
    });
    _resyncSub = coordinator.fullResyncStream.listen((reason) {
      onFullResyncRequired?.call(reason);
    });
    _expiredSub = coordinator.sessionExpired1008Stream.listen((reason) {
      onSessionExpired?.call(reason);
    });
  }

  int get reconnectAttempt => _reconnectAttempt;

  /// Computes reconnection backoff delay following `1s, 2s, 4s, 8s, 16s` capped with jitter.
  static Duration computeBackoffDelay(
    int attemptIndex, {
    int? jitterMsOverride,
  }) {
    final clampedIndex =
        attemptIndex.clamp(0, backoffSecondsSchedule.length - 1);
    final baseSeconds = backoffSecondsSchedule[clampedIndex];
    final jitterMs = (jitterMsOverride ?? 0).clamp(0, 500);
    return Duration(seconds: baseSeconds, milliseconds: jitterMs);
  }

  /// Validates and builds the sanitized WebSocket URI without any bearer token query params.
  static Uri buildSanitizedWsUri(String rawWsUrl) {
    final parsed = Uri.parse(rawWsUrl);
    if (parsed.queryParameters.containsKey('token') ||
        parsed.queryParameters.containsKey('access_token') ||
        parsed.queryParameters.containsKey('bearer')) {
      final filtered = Map<String, String>.from(parsed.queryParameters)
        ..remove('token')
        ..remove('access_token')
        ..remove('bearer');
      return parsed.replace(
        queryParameters: filtered.isEmpty ? null : filtered,
      );
    }
    return parsed;
  }

  Future<void> connect({WebSocketChannel? channelOverride}) async {
    if (_isDisposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _closeActiveChannel();

    final session = await sessionStore.readSession();
    if (session == null || session.accessToken.isEmpty) {
      coordinator.handleCloseCode1008('Missing authenticated session for WS.');
      return;
    }

    try {
      final sanitizedUri = buildSanitizedWsUri(config.wsBaseUrl);
      _channel = channelOverride ?? WebSocketChannel.connect(sanitizedUri);
      // Send initial authorization handshake frame over the encrypted/connected channel
      // rather than leaking the reusable bearer token in the URL query string.
      _channel!.sink.add(
        jsonEncode({
          'type': 'auth_handshake',
          'session_id': session.sessionId,
          'authorization': 'Bearer ${session.accessToken}',
        }),
      );

      final isReconnecting = _hadPriorConnection || _reconnectAttempt > 0;
      _hadPriorConnection = true;
      _reconnectAttempt = 0;
      if (isReconnecting) {
        coordinator.reconnectAndResync();
      }

      _subscription = _channel!.stream.listen(
        (frame) {
          coordinator.handleRawFrame(frame);
        },
        onError: (Object err) {
          coordinator.markOfflineOrStale('WebSocket stream error: $err');
          _scheduleReconnectIfEnabled();
        },
        onDone: () {
          final closeCode = _channel?.closeCode;
          if (closeCode == 1008) {
            _reconnectTimer?.cancel();
            _reconnectTimer = null;
            sessionStore.clearSession();
            coordinator.handleCloseCode1008(
              _channel?.closeReason ?? 'Session expired or revoked (1008).',
            );
          } else {
            coordinator.markOfflineOrStale(
              'WebSocket disconnected (code ${closeCode ?? 'unknown'}). Reconnect required.',
            );
            _scheduleReconnectIfEnabled();
          }
        },
      );
    } catch (e) {
      coordinator.markOfflineOrStale('Failed to connect to WebSocket: $e');
      _scheduleReconnectIfEnabled();
    }
  }

  void _scheduleReconnectIfEnabled() {
    if (_isDisposed || !enableAutoReconnect) return;
    _reconnectTimer?.cancel();
    final delay = computeBackoffDelay(
      _reconnectAttempt,
      jitterMsOverride: _rng.nextInt(250),
    );
    _reconnectAttempt++;
    _reconnectTimer = Timer(delay, () {
      if (!_isDisposed) {
        connect();
      }
    });
  }

  Future<void> _closeActiveChannel() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _closeActiveChannel();
  }

  Future<void> dispose() async {
    _isDisposed = true;
    await disconnect();
    await _targetedSub?.cancel();
    await _resyncSub?.cancel();
    await _expiredSub?.cancel();
  }
}
