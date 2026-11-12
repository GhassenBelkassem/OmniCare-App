import '../../l10n/omni_localizations.dart';
import '../models/blood_type.dart';

/// Label shown to the patient for a blood type: the wire value for a known
/// type (« A+ »…), « Je ne sais pas » for [BloodType.unknown].
extension BloodTypeLabel on BloodType {
  String label(OmniLocalizations l10n) =>
      isKnown ? wireValue : l10n.bloodTypeUnknown;
}
