import '../../shared/models/auth_models.dart';

/// Port for storing the active authenticated operator session (`SessionDto`).
/// Never stores database credentials or raw biometric data.
abstract class SecureSessionStore {
  Future<void> saveSession(SessionDto session);
  Future<SessionDto?> readSession();
  Future<void> clearSession();
}

/// In-memory + SharedPreferences backed implementation of [SecureSessionStore].
class InMemorySessionStore implements SecureSessionStore {
  SessionDto? _cached;

  @override
  Future<void> saveSession(SessionDto session) async {
    _cached = session;
  }

  @override
  Future<SessionDto?> readSession() async {
    return _cached;
  }

  @override
  Future<void> clearSession() async {
    _cached = null;
  }
}
