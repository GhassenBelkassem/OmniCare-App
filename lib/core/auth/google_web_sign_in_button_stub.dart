import 'package:flutter/widgets.dart';

class GoogleWebSignInButton extends StatelessWidget {
  final void Function(String idToken) onIdToken;

  const GoogleWebSignInButton({super.key, required this.onIdToken});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
