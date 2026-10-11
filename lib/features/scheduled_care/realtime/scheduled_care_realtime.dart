import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../../../core/config/app_environment.dart';
import '../../../core/storage/secure_token_store.dart';
import '../domain/scheduled_care_models.dart';

typedef ScheduledCareEventCallback = void Function(ScheduledCareEvent event);
typedef NotificationInvalidationCallback =
    void Function(NotificationInvalidation event);
typedef StompClientFactory = StompClient Function(StompConfig config);

class NotificationInvalidation {
  const NotificationInvalidation({
    required this.eventType,
    required this.notificationId,
    required this.occurredAt,
  });

  final String eventType;
  final String notificationId;
  final DateTime occurredAt;

  factory NotificationInvalidation.fromJson(Map<String, dynamic> json) {
    final eventType = json['eventType'];
    final notificationId = json['notificationId'];
    final occurredAt = DateTime.tryParse(json['occurredAt']?.toString() ?? '');
    if (eventType is! String ||
        eventType != 'NOTIFICATION_CREATED' ||
        notificationId is! String ||
        notificationId.isEmpty ||
        occurredAt == null) {
      throw const FormatException('Invalid notification invalidation.');
    }
    return NotificationInvalidation(
      eventType: eventType,
      notificationId: notificationId,
      occurredAt: occurredAt.toUtc(),
    );
  }
}

abstract class ScheduledCareRealtime {
  bool get isConnected;
  Future<void> connect(
    ScheduledCareEventCallback onEvent, {
    void Function()? onConnected,
  });
  Future<void> connectNotifications(
    NotificationInvalidationCallback onEvent, {
    void Function()? onConnected,
  }) async {}
  void disconnectNotifications() {}
  void disconnect();
}

class StompScheduledCareRealtime implements ScheduledCareRealtime {
  StompScheduledCareRealtime({
    required SecureTokenStore tokenStore,
    StompClientFactory? clientFactory,
  }) : _tokenStore = tokenStore,
       _clientFactory =
           clientFactory ?? ((config) => StompClient(config: config));

  final SecureTokenStore _tokenStore;
  final StompClientFactory _clientFactory;
  StompClient? _client;
  ScheduledCareEventCallback? _onEvent;
  NotificationInvalidationCallback? _onNotification;
  void Function()? _onScheduledConnected;
  void Function()? _onNotificationConnected;
  bool _scheduledConsumer = false;
  bool _notificationConsumer = false;
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect(
    ScheduledCareEventCallback onEvent, {
    void Function()? onConnected,
  }) async {
    _onEvent = onEvent;
    _onScheduledConnected = onConnected;
    _scheduledConsumer = true;
    if (_connected) {
      onConnected?.call();
      return;
    }
    await _ensureConnected();
  }

  @override
  Future<void> connectNotifications(
    NotificationInvalidationCallback onEvent, {
    void Function()? onConnected,
  }) async {
    _onNotification = onEvent;
    _onNotificationConnected = onConnected;
    _notificationConsumer = true;
    if (_connected) {
      onConnected?.call();
      return;
    }
    await _ensureConnected();
  }

  Future<void> _ensureConnected() async {
    if (_client?.isActive == true) return;
    final session = await _tokenStore.readSession();
    if (session == null || session.accessToken.trim().isEmpty) return;
    final connectHeaders = <String, String>{
      'Authorization': 'Bearer ${session.accessToken}',
    };
    late final StompClient client;
    client = _clientFactory(
      StompConfig.sockJS(
        url: '${AppEnvironment.apiBaseUrl}/api/v1/ws',
        stompConnectHeaders: connectHeaders,
        beforeConnect: () async {
          final current = await _tokenStore.readSession();
          if (current == null || current.accessToken.trim().isEmpty) {
            throw StateError('Authenticated session is unavailable.');
          }
          connectHeaders['Authorization'] = 'Bearer ${current.accessToken}';
        },
        reconnectDelay: const Duration(seconds: 5),
        heartbeatIncoming: const Duration(seconds: 10),
        heartbeatOutgoing: const Duration(seconds: 10),
        onConnect: (_) {
          _connected = true;
          client.subscribe(
            destination: '/user/queue/scheduled-care',
            callback: _receiveScheduledCare,
          );
          client.subscribe(
            destination: '/user/queue/notifications',
            callback: _receiveNotification,
          );
          if (_scheduledConsumer) _onScheduledConnected?.call();
          if (_notificationConsumer) _onNotificationConnected?.call();
        },
        onDisconnect: (_) => _connected = false,
        onWebSocketDone: () => _connected = false,
        onWebSocketError: (_) => _connected = false,
        onStompError: (_) {
          _connected = false;
          client.deactivate();
        },
      ),
    );
    _client = client;
    client.activate();
  }

  void _receiveScheduledCare(StompFrame frame) {
    final body = frame.body;
    if (body == null || body.isEmpty) return;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return;
      _onEvent?.call(
        ScheduledCareEvent.fromJson(decoded.cast<String, dynamic>()),
      );
    } on FormatException {
      // Invalid hints are ignored; REST remains authoritative.
    }
  }

  void _receiveNotification(StompFrame frame) {
    final body = frame.body;
    if (body == null || body.isEmpty) return;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return;
      _onNotification?.call(
        NotificationInvalidation.fromJson(decoded.cast<String, dynamic>()),
      );
    } on FormatException {
      // Invalid hints are ignored; REST remains authoritative.
    }
  }

  @override
  void disconnect() {
    _scheduledConsumer = false;
    _onEvent = null;
    _onScheduledConnected = null;
    _deactivateIfUnused();
  }

  @override
  void disconnectNotifications() {
    _notificationConsumer = false;
    _onNotification = null;
    _onNotificationConnected = null;
    _deactivateIfUnused();
  }

  void _deactivateIfUnused() {
    if (_scheduledConsumer || _notificationConsumer) return;
    _connected = false;
    _client?.deactivate();
    _client = null;
  }
}

class NoopScheduledCareRealtime implements ScheduledCareRealtime {
  const NoopScheduledCareRealtime();
  @override
  bool get isConnected => false;
  @override
  Future<void> connect(
    ScheduledCareEventCallback onEvent, {
    void Function()? onConnected,
  }) async {}
  @override
  Future<void> connectNotifications(
    NotificationInvalidationCallback onEvent, {
    void Function()? onConnected,
  }) async {}
  @override
  void disconnectNotifications() {}
  @override
  void disconnect() {}
}
