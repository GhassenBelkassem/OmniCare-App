import 'dart:async';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../config/app_environment.dart';
import '../storage/secure_token_store.dart';

enum RealtimeConnectionState {
  disconnected,
  connecting,
  connected,
  authRejected,
}

class RealtimeSessionOwner {
  const RealtimeSessionOwner({required this.userId, required this.role});

  final String userId;
  final String role;

  String get normalizedRole => role.trim().toUpperCase();

  @override
  bool operator ==(Object other) =>
      other is RealtimeSessionOwner &&
      other.userId == userId &&
      other.normalizedRole == normalizedRole;

  @override
  int get hashCode => Object.hash(userId, normalizedRole);
}

abstract class ScheduledCareRealtimeTransport {
  RealtimeConnectionState get state;
  RealtimeSessionOwner? get owner;
  int get connectionEpoch;
  Stream<String> get messages;
  Stream<String> get notificationMessages;
  Stream<int> get connectedEpochs;

  Future<void> startSession(RealtimeSessionOwner owner);
  Future<void> ensureConnected();
  Future<void> stopSession();
}

typedef RealtimeMessageCallback = void Function(String body);

class RealtimeSocketConfiguration {
  const RealtimeSocketConfiguration({
    required this.url,
    required this.useSockJs,
    required this.stompConnectHeaders,
    required this.onConnected,
    required this.onStompError,
    required this.onTransportError,
    required this.onTransportDone,
  });

  final String url;
  final bool useSockJs;
  final Map<String, String> stompConnectHeaders;
  final void Function() onConnected;
  final void Function() onStompError;
  final void Function() onTransportError;
  final void Function() onTransportDone;
}

abstract class RealtimeSocket {
  bool get isActive;
  void activate();
  void deactivate();
  void Function() subscribe({
    required String destination,
    required RealtimeMessageCallback onMessage,
  });
}

abstract class RealtimeSocketFactory {
  RealtimeSocket create(RealtimeSocketConfiguration configuration);
}

class StompRealtimeSocketFactory implements RealtimeSocketFactory {
  const StompRealtimeSocketFactory();

  @override
  RealtimeSocket create(RealtimeSocketConfiguration configuration) =>
      _StompRealtimeSocket(configuration);
}

class _StompRealtimeSocket implements RealtimeSocket {
  _StompRealtimeSocket(RealtimeSocketConfiguration configuration)
    : _client = StompClient(
        config: StompConfig.sockJS(
          url: configuration.url,
          reconnectDelay: Duration.zero,
          stompConnectHeaders: configuration.stompConnectHeaders,
          onConnect: (_) => configuration.onConnected(),
          onStompError: (_) => configuration.onStompError(),
          onWebSocketError: (_) => configuration.onTransportError(),
          onWebSocketDone: configuration.onTransportDone,
        ),
      );

  final StompClient _client;

  @override
  bool get isActive => _client.isActive;

  @override
  void activate() => _client.activate();

  @override
  void deactivate() => _client.deactivate();

  @override
  void Function() subscribe({
    required String destination,
    required RealtimeMessageCallback onMessage,
  }) {
    final unsubscribe = _client.subscribe(
      destination: destination,
      callback: (frame) {
        final body = frame.body;
        if (body != null) onMessage(body);
      },
    );
    return () => unsubscribe();
  }
}

/// Owns the single authenticated SockJS/STOMP connection for an app session.
///
/// The access token is intentionally present only in the native STOMP CONNECT
/// headers. It is never placed in the URL or WebSocket handshake headers.
class AuthenticatedRealtimeTransport implements ScheduledCareRealtimeTransport {
  AuthenticatedRealtimeTransport({
    required SecureTokenStore tokenStore,
    RealtimeSocketFactory socketFactory = const StompRealtimeSocketFactory(),
    String? endpoint,
    this.reconnectDelay = const Duration(seconds: 5),
  }) : _tokenStore = tokenStore,
       _socketFactory = socketFactory,
       endpoint = endpoint ?? '${AppEnvironment.apiV1BaseUrl}/ws';

  static const privateDestination = '/user/queue/scheduled-care';
  static const notificationDestination = '/user/queue/notifications';

  final SecureTokenStore _tokenStore;
  final RealtimeSocketFactory _socketFactory;
  final String endpoint;
  final Duration reconnectDelay;
  final StreamController<String> _messages = StreamController.broadcast();
  final StreamController<String> _notificationMessages =
      StreamController.broadcast();
  final StreamController<int> _epochs = StreamController.broadcast();

  RealtimeSocket? _socket;
  void Function()? _unsubscribe;
  void Function()? _unsubscribeNotifications;
  Timer? _reconnectTimer;
  RealtimeSessionOwner? _owner;
  String? _connectedAccessToken;
  int? _connectedCredentialFingerprint;
  int? _rejectedCredentialFingerprint;
  RealtimeConnectionState _state = RealtimeConnectionState.disconnected;
  int _connectionEpoch = 0;
  int _generation = 0;
  bool _authRejected = false;

  @override
  RealtimeConnectionState get state => _state;

  @override
  RealtimeSessionOwner? get owner => _owner;

  @override
  int get connectionEpoch => _connectionEpoch;

  @override
  Stream<String> get messages => _messages.stream;

  @override
  Stream<String> get notificationMessages => _notificationMessages.stream;

  @override
  Stream<int> get connectedEpochs => _epochs.stream;

  @override
  Future<void> startSession(RealtimeSessionOwner owner) async {
    final normalized = RealtimeSessionOwner(
      userId: owner.userId.trim(),
      role: owner.normalizedRole,
    );
    if (normalized.userId.isEmpty || normalized.normalizedRole.isEmpty) {
      await stopSession();
      return;
    }
    if (_owner == normalized &&
        (_state != RealtimeConnectionState.disconnected ||
            _reconnectTimer != null)) {
      return;
    }
    await stopSession();
    _owner = normalized;
    await _connect();
  }

  @override
  Future<void> ensureConnected() async {
    final currentOwner = _owner;
    if (currentOwner == null) return;
    final session = await _tokenStore.readSession();
    if (!_belongsToOwner(session, currentOwner)) {
      await stopSession();
      return;
    }
    final fingerprint = _credentialFingerprint(session!);
    if (_authRejected) {
      if (fingerprint == _rejectedCredentialFingerprint) return;
      _authRejected = false;
      _rejectedCredentialFingerprint = null;
      _state = RealtimeConnectionState.disconnected;
    }
    if (_connectedAccessToken != null &&
        (session.accessToken != _connectedAccessToken ||
            fingerprint != _connectedCredentialFingerprint)) {
      _tearDownSocket();
      _state = RealtimeConnectionState.disconnected;
    }
    if (_state == RealtimeConnectionState.disconnected &&
        _reconnectTimer == null) {
      await _connect(session: session);
    }
  }

  Future<void> _connect({StoredSession? session}) async {
    final currentOwner = _owner;
    if (currentOwner == null || _authRejected) return;
    final currentSession = session ?? await _tokenStore.readSession();
    if (!_belongsToOwner(currentSession, currentOwner)) {
      await stopSession();
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _tearDownSocket();
    final generation = ++_generation;
    _connectedAccessToken = currentSession!.accessToken;
    _connectedCredentialFingerprint = _credentialFingerprint(currentSession);
    _state = RealtimeConnectionState.connecting;
    final socket = _socketFactory.create(
      RealtimeSocketConfiguration(
        url: endpoint,
        useSockJs: true,
        stompConnectHeaders: <String, String>{
          'Authorization': 'Bearer ${currentSession.accessToken}',
        },
        onConnected: () => _handleConnected(generation),
        onStompError: () => _handleAuthError(generation),
        onTransportError: () => _handleTransportDrop(generation),
        onTransportDone: () => _handleTransportDrop(generation),
      ),
    );
    _socket = socket;
    socket.activate();
  }

  void _handleConnected(int generation) {
    if (!_isCurrent(generation) || _authRejected) return;
    try {
      _unsubscribe?.call();
      _unsubscribe = _socket!.subscribe(
        destination: privateDestination,
        onMessage: (body) {
          if (_isCurrent(generation) && !_messages.isClosed) {
            _messages.add(body);
          }
        },
      );
      _unsubscribeNotifications?.call();
      _unsubscribeNotifications = _socket!.subscribe(
        destination: notificationDestination,
        onMessage: (body) {
          if (_isCurrent(generation) && !_notificationMessages.isClosed) {
            _notificationMessages.add(body);
          }
        },
      );
      _state = RealtimeConnectionState.connected;
      _rejectedCredentialFingerprint = null;
      _connectionEpoch++;
      if (!_epochs.isClosed) _epochs.add(_connectionEpoch);
    } catch (_) {
      _handleTransportDrop(generation);
    }
  }

  void _handleAuthError(int generation) {
    if (!_isCurrent(generation)) return;
    _authRejected = true;
    _rejectedCredentialFingerprint = _connectedCredentialFingerprint;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _tearDownSocket();
    _state = RealtimeConnectionState.authRejected;
  }

  void _handleTransportDrop(int generation) {
    if (!_isCurrent(generation) || _authRejected || _owner == null) return;
    _tearDownSocket(invalidateGeneration: false);
    _state = RealtimeConnectionState.disconnected;
    if (_reconnectTimer != null) return;
    _reconnectTimer = Timer(reconnectDelay, () {
      _reconnectTimer = null;
      if (_owner != null && !_authRejected) unawaited(_connect());
    });
  }

  bool _belongsToOwner(StoredSession? session, RealtimeSessionOwner owner) =>
      session != null &&
      session.hasRequiredValues &&
      session.userId.trim() == owner.userId &&
      session.userRole.trim().toUpperCase() == owner.normalizedRole;

  int _credentialFingerprint(StoredSession session) =>
      Object.hash(session.accessToken, session.sessionId);

  bool _isCurrent(int generation) => generation == _generation;

  void _tearDownSocket({bool invalidateGeneration = true}) {
    if (invalidateGeneration) _generation++;
    _unsubscribe?.call();
    _unsubscribe = null;
    _unsubscribeNotifications?.call();
    _unsubscribeNotifications = null;
    _socket?.deactivate();
    _socket = null;
    _connectedAccessToken = null;
    _connectedCredentialFingerprint = null;
  }

  @override
  Future<void> stopSession() async {
    _generation++;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _tearDownSocket(invalidateGeneration: false);
    _owner = null;
    _authRejected = false;
    _rejectedCredentialFingerprint = null;
    _connectionEpoch = 0;
    _state = RealtimeConnectionState.disconnected;
  }

  Future<void> dispose() async {
    await stopSession();
    await _messages.close();
    await _notificationMessages.close();
    await _epochs.close();
  }
}
