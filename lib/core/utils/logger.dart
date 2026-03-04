import 'package:flutter/foundation.dart';

class AppLogger {
  const AppLogger._();

  static void api(String message) {
    debugPrint('🚀 API $message');
  }

  static void gps(String message) {
    debugPrint('📍 GPS $message');
  }

  static void notif(String message) {
    debugPrint('🔔 NOTIF $message');
  }

  static void info(String message) {
    debugPrint('ℹ️ $message');
  }

  static void warn(String message) {
    debugPrint('⚠️ $message');
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('❌ $message');
    if (error != null) {
      debugPrint('❌ error: $error');
    }
    if (stackTrace != null) {
      debugPrint('❌ stack: $stackTrace');
    }
  }
}
