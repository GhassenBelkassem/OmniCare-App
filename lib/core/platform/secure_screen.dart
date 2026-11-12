import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Blocks screenshots and the recent-apps preview while a screen with medical
/// data is shown (Android `FLAG_SECURE`, MASVS-PLATFORM; roadmap G-2 §5).
/// A no-op on other platforms. Failures are ignored: the flag is a defence in
/// depth, never a reason to hide the patient's own data.
abstract final class SecureScreen {
  static const MethodChannel _channel = MethodChannel('omnicare/secure_screen');

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> enable() => _call('enable');

  static Future<void> disable() => _call('disable');

  static Future<void> _call(String method) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>(method);
    } on PlatformException {
      // Defence in depth only.
    } on MissingPluginException {
      // Defence in depth only.
    }
  }
}
