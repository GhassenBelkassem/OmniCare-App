import 'dart:async';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/nav/app_nav.dart';
import '../features/notifications/domain/notification_models.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final StreamController<UrgentCabinetNotificationOpenIntent>
  _urgentCabinetOpens =
      StreamController<UrgentCabinetNotificationOpenIntent>.broadcast(
        sync: true,
      );
  UrgentCabinetNotificationOpenIntent? _pendingUrgentCabinetOpen;
  bool _initialized = false;

  Stream<UrgentCabinetNotificationOpenIntent> get urgentCabinetOpens =>
      _urgentCabinetOpens.stream;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request iOS permission once. Initialization now runs after the first
    // Flutter frame, so this platform dialog cannot delay application startup.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    _initialized = true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) {
      openNotificationCenter();
      return;
    }
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        openPayload(decoded.map((key, value) => MapEntry('$key', value)));
        return;
      }
    } catch (_) {
      // Legacy/non-JSON notification payloads retain the safe inbox fallback.
    }
    openNotificationCenter();
  }

  void openPayload(Map<String, dynamic> data) {
    final requestId = data['request_id']?.toString().trim();
    if (data['destination'] == 'URGENT_CABINET_REQUEST' &&
        requestId != null &&
        _uuidPattern.hasMatch(requestId)) {
      final intent = UrgentCabinetNotificationOpenIntent(
        requestId: requestId.toLowerCase(),
      );
      // A push-open may arrive before the authenticated Doctor workspace has
      // completed bootstrap. Broadcast streams do not replay, so retain the
      // latest opaque lookup intent until the correct role-specific surface
      // atomically claims it. No notification data becomes lifecycle authority.
      _pendingUrgentCabinetOpen = intent;
      _urgentCabinetOpens.add(intent);
      return;
    }
    openNotificationCenter();
  }

  UrgentCabinetNotificationOpenIntent? claimUrgentCabinetOpen(
    UrgentCabinetNotificationOpenIntent intent,
  ) {
    if (!identical(_pendingUrgentCabinetOpen, intent)) return null;
    _pendingUrgentCabinetOpen = null;
    return intent;
  }

  UrgentCabinetNotificationOpenIntent? takePendingUrgentCabinetOpen() {
    final intent = _pendingUrgentCabinetOpen;
    _pendingUrgentCabinetOpen = null;
    return intent;
  }

  void openNotificationCenter() {
    AppNav.navigatorKey.currentState?.pushNamed('/notifications');
  }

  Future<void> showInboxNotification(InboxNotification notification) async {
    if (notification.isExpired) return;
    final urgent = notification.priority == InboxNotificationPriority.critical;
    final messenger = AppNav.scaffoldMessengerKey.currentState;
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${notification.titleFr}\n${notification.bodyFr}'),
          action: SnackBarAction(
            label: 'Ouvrir',
            onPressed: () => openPayload(notification.deepLinkPayload),
          ),
        ),
      );
    if (kIsWeb) return;
    final androidDetails = AndroidNotificationDetails(
      urgent ? 'omnicare_critical' : 'omnicare_high',
      urgent ? 'Urgences OmniCare' : 'Alertes OmniCare',
      channelDescription: 'Notifications opérationnelles OmniCare',
      importance: urgent ? Importance.max : Importance.high,
      priority: urgent ? Priority.max : Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      presentBanner: true,
      presentList: true,
    );
    await _notifications.show(
      notification.id.hashCode & 0x7fffffff,
      notification.titleFr,
      notification.bodyFr,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: jsonEncode(<String, Object?>{
        'notification_id': notification.id,
        ...notification.deepLinkPayload,
      }),
    );
  }

  Future<void> showRemoteNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
    required bool urgent,
  }) async {
    final messenger = AppNav.scaffoldMessengerKey.currentState;
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$title\n$body'),
          action: SnackBarAction(
            label: 'Ouvrir',
            onPressed: () => openPayload(data),
          ),
        ),
      );
    if (kIsWeb) return;
    final androidDetails = AndroidNotificationDetails(
      urgent ? 'omnicare_critical' : 'omnicare_high',
      urgent ? 'Urgences OmniCare' : 'Alertes OmniCare',
      channelDescription: 'Notifications opérationnelles OmniCare',
      importance: urgent ? Importance.max : Importance.high,
      priority: urgent ? Priority.max : Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      presentBanner: true,
      presentList: true,
    );
    await _notifications.show(
      Object.hash(title, body, data['request_id']) & 0x7fffffff,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: jsonEncode(data),
    );
  }

  Future<void> showDoctorsFoundNotification() async {
    debugPrint(
      '🔔 NOTIFICATION: Attempting to show Doctors Found notification',
    );
    final androidDetails = AndroidNotificationDetails(
      'emergency_channel',
      'Urgences Médicales',
      channelDescription: 'Notifications pour les demandes d\'urgence médicale',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF1FBF9A),
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      // Show notification even when app is in foreground
      presentBanner: true,
      presentList: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      1,
      'Médecins Disponibles 👨‍⚕️',
      'Excellente nouvelle ! Nous avons trouvé des médecins qualifiés près de vous. Sélectionnez celui qui vous convient.',
      details,
      payload: 'doctors_found',
    );
    debugPrint('✅ NOTIFICATION: Doctors Found notification sent successfully');
  }

  Future<void> showDoctorOnWayNotification(String doctorName) async {
    debugPrint(
      '🔔 NOTIFICATION: Attempting to show Doctor On Way notification for $doctorName',
    );
    final androidDetails = AndroidNotificationDetails(
      'emergency_channel',
      'Urgences Médicales',
      channelDescription: 'Notifications pour les demandes d\'urgence médicale',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF1FBF9A),
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      // Show notification even when app is in foreground
      presentBanner: true,
      presentList: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      2,
      'Médecin En Route 🚗',
      '$doctorName a accepté votre demande et se dirige vers votre localisation. Veuillez rester disponible.',
      details,
      payload: 'doctor_on_way',
    );
    debugPrint('✅ NOTIFICATION: Doctor On Way notification sent successfully');
  }

  Future<void> showDoctorArrivedNotification(String doctorName) async {
    debugPrint(
      '🔔 NOTIFICATION: Attempting to show Doctor Arrived notification for $doctorName',
    );
    final androidDetails = AndroidNotificationDetails(
      'emergency_channel',
      'Urgences Médicales',
      channelDescription: 'Notifications pour les demandes d\'urgence médicale',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF1FBF9A),
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color(0xFF1FBF9A),
      ledOnMs: 1000,
      ledOffMs: 500,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      interruptionLevel: InterruptionLevel.critical,
      // Show notification even when app is in foreground
      presentBanner: true,
      presentList: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      3,
      'Le Médecin Est Arrivé ! 🏥',
      '$doctorName est arrivé à votre localisation. Veuillez ouvrir l\'application pour afficher votre code QR.',
      details,
      payload: 'doctor_arrived',
    );
    debugPrint('✅ NOTIFICATION: Doctor Arrived notification sent successfully');
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  // Test notification to verify setup works
  Future<void> showTestNotification() async {
    debugPrint('🔔 NOTIFICATION: Sending test notification');

    final androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Test',
      channelDescription: 'Test notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF1FBF9A),
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      presentBanner: true,
      presentList: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      999,
      'Test Notification 🧪',
      'Si vous voyez ceci, les notifications fonctionnent correctement!',
      details,
      payload: 'test',
    );
    debugPrint('✅ NOTIFICATION: Test notification sent');
  }
}

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);

class UrgentCabinetNotificationOpenIntent {
  const UrgentCabinetNotificationOpenIntent({required this.requestId});

  final String requestId;
}
