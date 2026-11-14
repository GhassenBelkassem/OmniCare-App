import 'package:flutter/widgets.dart';

/// Lets screens inside the patient shell's branches drive the shell.
///
/// A branch screen calling `Navigator.pushNamed(context, '/home')` only
/// reaches its own branch Navigator, so a « back to home » action must ask
/// the shell instead.
class PatientShellScope extends InheritedWidget {
  const PatientShellScope({
    super.key,
    required this.showHome,
    required super.child,
  });

  /// Shows the « Accueil » home feed and resets the finished flow's branch.
  final VoidCallback showHome;

  /// Null outside the patient shell (standalone routes, tests).
  static PatientShellScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PatientShellScope>();

  @override
  bool updateShouldNotify(PatientShellScope oldWidget) => false;
}
