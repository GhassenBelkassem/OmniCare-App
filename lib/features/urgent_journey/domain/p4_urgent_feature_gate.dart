import 'package:flutter/foundation.dart';

/// Non-production gate for the API-free P4 static demonstration.
final class P4UrgentFeatureGate {
  const P4UrgentFeatureGate._(this.isEnabled);

  final bool isEnabled;

  static const _requested = bool.fromEnvironment(
    'OMNICARE_ENABLE_P4_SYNTHETIC_UI',
    defaultValue: true,
  );

  /// A release build is always disabled, even if the dart-define is supplied.
  static const runtime = P4UrgentFeatureGate._(!kReleaseMode && _requested);
  static const enabledForTests = P4UrgentFeatureGate._(true);
  static const disabled = P4UrgentFeatureGate._(false);
}
