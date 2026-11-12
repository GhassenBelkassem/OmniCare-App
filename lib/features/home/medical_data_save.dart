import '../../core/api/account_api.dart';
import 'edit_medical_data_screen.dart';

/// Saves the parts of the patient's own [edit] the backend can store today.
///
/// Only a changed blood type is sent (`PATCH /profile/passport`). Conditions
/// and medications are never sent: the backend drops them, and they move to
/// `/profile/medical-data` in G-2 Phase 3. Returns true when a request was
/// made. Errors propagate to the editor, which shows a French message.
Future<bool> saveOwnMedicalEdit(AccountApi api, MedicalDataEdit edit) async {
  final bloodType = edit.bloodType;
  if (bloodType == null) return false;
  await api.patchMedicalPassport(bloodType: bloodType);
  return true;
}
