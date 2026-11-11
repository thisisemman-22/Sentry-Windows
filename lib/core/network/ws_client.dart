import 'dart:async';
import '../../shared/models/event_envelope.dart';

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
/// - `refresh_required: true` targeted resource refetch
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

  WsStreamState get state => _state;
  Stream<WsStreamState> get stateStream => _stateController.stream;
  Stream<RealtimeUpdateData> get targetedRefreshStream =>
      _refreshController.stream;
  Stream<String> get fullResyncStream => _fullResyncController.stream;

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
          resyncRequired: false,
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
    _updateState(
      _state.copyWith(
        status: WsConnectionStatus.sessionExpired,
        resyncRequired: true,
        lastErrorMessage: 'WS 1008 Policy Violation / Session Expired: $reason',
      ),
    );
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
  }
}
