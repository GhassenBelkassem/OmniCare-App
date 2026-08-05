import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Releases authentication-field focus and waits briefly for the platform
/// keyboard to return the Flutter view to its full height before navigation.
Future<void> dismissKeyboardBeforeNavigation(BuildContext context) async {
  final hadKeyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
  final hadFocus = FocusManager.instance.primaryFocus != null;

  FocusManager.instance.primaryFocus?.unfocus();
  try {
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  } on PlatformException {
    // Unfocus is sufficient on platforms without a text-input channel.
  }

  if (!hadKeyboard && !hadFocus) return;

  // Mobile browsers update their visual viewport asynchronously while the
  // keyboard closes. Waiting here prevents the next route from inheriting a
  // half-height surface on its first frame.
  for (var attempt = 0; attempt < 12; attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 25));
    if (!context.mounted) return;
    if (MediaQuery.viewInsetsOf(context).bottom <= 0) return;
  }
}
