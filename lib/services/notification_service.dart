import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

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
    // Handle notification tap - navigate to appropriate screen
    debugPrint('Notification tapped: ${response.payload}');
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
