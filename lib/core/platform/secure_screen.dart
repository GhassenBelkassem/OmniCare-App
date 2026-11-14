import 'dart:async';

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

  static int _holders = 0;

  /// Requests the flag. Reference-counted: the window flag only changes when
  /// the first holder acquires or the last one releases, so nested holders
  /// (the patient shell and the « Dossier médical » screen) never toggle it.
  static void acquire() {
    if (_holders++ == 0) unawaited(_call('enable'));
  }

  /// Releases one [acquire]. Extra releases are ignored.
  static void release() {
    if (_holders == 0) return;
    if (--_holders == 0) unawaited(_call('disable'));
  }

  @visibleForTesting
  static int get debugHolderCount => _holders;

  @visibleForTesting
  static void debugReset() => _holders = 0;

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
