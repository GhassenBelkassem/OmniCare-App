import '../data/doctor_directory_models.dart';

/// Immutable constraints imposed by the flow that opened Doctor discovery.
///
/// These are deliberately separate from user-controlled filters: clearing or
/// replacing optional filters must never broaden a constrained acquisition
/// flow.
class DoctorDiscoveryContext {
  const DoctorDiscoveryContext({
    this.requiredCareCapability,
    this.requireAcceptingNewPatients = false,
  });

  static const DoctorDiscoveryContext generic = DoctorDiscoveryContext();

  static const DoctorDiscoveryContext cabinetNewPatient =
      DoctorDiscoveryContext(
        requiredCareCapability: DoctorCareCapability.cabinet,
        requireAcceptingNewPatients: true,
      );

  final DoctorCareCapability? requiredCareCapability;
  final bool requireAcceptingNewPatients;

  @override
  bool operator ==(Object other) {
    return other is DoctorDiscoveryContext &&
        requiredCareCapability == other.requiredCareCapability &&
        requireAcceptingNewPatients == other.requireAcceptingNewPatients;
  }

  @override
  int get hashCode =>
      Object.hash(requiredCareCapability, requireAcceptingNewPatients);
}
