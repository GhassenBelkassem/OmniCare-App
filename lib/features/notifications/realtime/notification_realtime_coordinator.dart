import 'dart:async';
import 'dart:convert';

import '../../../core/realtime/authenticated_realtime_transport.dart';
import '../application/notification_center_controller.dart';
import '../domain/notification_models.dart';

class NotificationRealtimeInvalidation {
  const NotificationRealtimeInvalidation({
    required this.notificationId,
    required this.occurredAt,
  });

  final String notificationId;
  final DateTime occurredAt;

  static NotificationRealtimeInvalidation? tryParse(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      final json = decoded.cast<String, dynamic>();
      if (json['eventType'] != 'NOTIFICATION_CREATED') return null;
      final id = json['notificationId'];
      final rawInstant = json['occurredAt'];
      if (id is! String ||
          !isUuid(id) ||
          rawInstant is! String ||
          !RegExp(r'(?:[zZ]|[+-]\d{2}:\d{2})$').hasMatch(rawInstant)) {
        return null;
      }
      final instant = DateTime.tryParse(rawInstant);
      if (instant == null) return null;
      return NotificationRealtimeInvalidation(
        notificationId: id.toLowerCase(),
        occurredAt: instant.toUtc(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Notification invalidations are best-effort because the current backend
/// publishes them through its local broker only (no Redis fan-out). Durable
/// correctness comes from initial, foreground, reconnect, and manual REST reads.
class NotificationRealtimeCoordinator {
  NotificationRealtimeCoordinator({
    required ScheduledCareRealtimeTransport transport,
    required NotificationCenterController controller,
    this.onForegroundNotification,
  }) : _controller = controller {
    _messageSubscription = transport.notificationMessages.listen(_onMessage);
    _epochSubscription = transport.connectedEpochs.listen(_onReconnect);
  }

  final NotificationCenterController _controller;
  final Future<void> Function(InboxNotification notification)?
  onForegroundNotification;
  late final StreamSubscription<String> _messageSubscription;
  late final StreamSubscription<int> _epochSubscription;
  int _generation = 0;
  bool _active = false;
  final Set<String> _alertedNotificationIds = <String>{};

  void startSession() {
    _generation++;
    _active = true;
  }

  void stopSession() {
    _generation++;
    _active = false;
    _alertedNotificationIds.clear();
  }

  void _onMessage(String body) {
    final invalidation = NotificationRealtimeInvalidation.tryParse(body);
    if (!_active || invalidation == null) {
      return;
    }
    final generation = _generation;
    unawaited(_handleNotification(generation, invalidation));
  }

  Future<void> _handleNotification(
    int generation,
    NotificationRealtimeInvalidation invalidation,
  ) async {
    if (!_active || generation != _generation) return;
    final notification = await _controller.onRealtimeNotification(
      invalidation.notificationId,
    );
    if (!_active ||
        generation != _generation ||
        notification == null ||
        notification.isExpired ||
        !_alertedNotificationIds.add(notification.id)) {
      return;
    }
    if (_alertedNotificationIds.length > 100) {
      _alertedNotificationIds.remove(_alertedNotificationIds.first);
    }
    await onForegroundNotification?.call(notification);
  }

  void _onReconnect(int _) {
    if (!_active) return;
    final generation = _generation;
    unawaited(_runIfCurrent(generation, _controller.onReconnect));
  }

  Future<void> foregroundResync() async {
    if (!_active) return;
    await _runIfCurrent(_generation, _controller.onForeground);
  }

  Future<void> _runIfCurrent(
    int generation,
    Future<void> Function() action,
  ) async {
    if (!_active || generation != _generation) return;
    await action();
  }

  Future<void> dispose() async {
    stopSession();
    await _messageSubscription.cancel();
    await _epochSubscription.cancel();
  }
}
