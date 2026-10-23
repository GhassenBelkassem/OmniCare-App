import 'core/config/p4_cabinet_synthetic_activation.dart';
import 'main.dart' as app;

Future<void> main() => app.startOmniCare(
  submissionActivationGate: P4CabinetSyntheticActivation.forCurrentBuild(),
);
