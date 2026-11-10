import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/app_http_client.dart';
import '../../../services/notification_service.dart';

/// Mobile-only FCM lifecycle. Firebase project configuration remains external;
/// absence of configuration disables push without affecting the durable inbox.
class NotificationPushCoordinator {
  NotificationPushCoordinator({
    required AppHttpClient httpClient,
    required NotificationService alerts,
  }) : _httpClient = httpClient,
       _alerts = alerts;

  final AppHttpClient _httpClient;
  final NotificationService _alerts;
  FirebaseMessaging? _messaging;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenSubscription;
  final Set<String> _seenMessageIds = <String>{};
  String? _ownerKey;
  String? _registeredToken;
  bool _initializing = false;

  Future<void> initialize() async {
    if (kIsWeb || _messaging != null || _initializing) return;
    _initializing = true;
    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;
      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: true,
        sound: false,
      );
      _messaging = messaging;
      _messageSubscription = FirebaseMessaging.onMessage.listen(
        _onForegroundMessage,
      );
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        _onOpenedMessage,
      );
      _tokenSubscription = messaging.onRegistered.listen(_registerToken);
      final initial = await messaging.getInitialMessage();
      if (initial != null) _onOpenedMessage(initial);
    } catch (_) {
      // Missing Firebase project files/entitlements are an external setup state.
      // REST inbox + authenticated realtime reconciliation remain available.
      _messaging = null;
    } finally {
      _initializing = false;
    }
  }

  Future<void> startSession(String ownerKey) async {
    final normalized = ownerKey.trim();
    if (normalized.isEmpty) return;
    _ownerKey = normalized;
    await initialize();
    final messaging = _messaging;
    if (messaging == null || _ownerKey != normalized) return;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;
    await messaging.register();
  }

  Future<void> stopSession() async {
    final token = _registeredToken;
    _ownerKey = null;
    _seenMessageIds.clear();
    if (token != null) {
      try {
        await _httpClient.dio.delete<void>(
          '/notifications/token',
          data: <String, String>{'token': token},
        );
        _registeredToken = null;
      } catch (_) {
        // Authentication may already be gone. The next authenticated registration
        // transfers the globally unique token; push payloads contain no PHI and all
        // deep links still require backend authorization.
      }
    }
    try {
      await _messaging?.unregister();
    } catch (_) {
      // Provider unregistration is best-effort; stale-token handling is server-side.
    }
  }

  Future<void> _registerToken(String token) async {
    if (_ownerKey == null || token.isEmpty || token == _registeredToken) return;
    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => 'IOS',
      _ => 'ANDROID',
    };
    try {
      await _httpClient.dio.post<void>(
        '/notifications/token',
        data: <String, String>{'token': token, 'platform': platform},
      );
      if (_ownerKey != null) _registeredToken = token;
    } catch (_) {
      // Token refresh and the next authenticated session retry registration.
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final identity = message.messageId;
    if (_ownerKey == null ||
        (identity != null && !_seenMessageIds.add(identity))) {
      return;
    }
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'];
    final body = notification?.body ?? message.data['body'];
    if (title == null || body == null) return;
    unawaited(
      _alerts.showRemoteNotification(
        title: title,
        body: body,
        data: message.data,
        urgent: message.data['type'] == 'URGENT_CABINET_REQUEST_TARGETED',
      ),
    );
  }

  void _onOpenedMessage(RemoteMessage message) {
    // Cold/background opens may arrive before session restoration. Retain only
    // a validated opaque identity; the authenticated resolver claims it later.
    _alerts.openPayload(
      Map<String, dynamic>.from(message.data),
      accountScope: _ownerKey?.split('::').first,
    );
  }

  Future<void> dispose() async {
    await _messageSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _tokenSubscription?.cancel();
  }
}
