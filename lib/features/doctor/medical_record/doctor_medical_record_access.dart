import '../urgent/doctor_urgent_controller.dart';
import '../../patient_passport/data/patient_passport_static_data.dart';
import '../../patient_passport/models/patient_passport_view_models.dart';

/// The scope granted to a doctor for one focused care interaction.
///
/// This is deliberately a local D6 representation. A signed QR grant and its
/// server-side authorization are out of scope until the real access flow is
/// introduced.
enum DoctorMedicalRecordScope { lifeSafetyOnly, fullPassport }

class DoctorMedicalRecordDocument {
  const DoctorMedicalRecordDocument({
    required this.title,
    required this.detail,
    required this.icon,
  });

  final String title;
  final String detail;
  final String icon;
}

/// Read-only patient context for the Doctor medical-record presentation.
class DoctorMedicalRecordAccess {
  const DoctorMedicalRecordAccess({
    required this.patientName,
    required this.patientAge,
    required this.sourceLabel,
    required this.requestId,
    required this.scope,
    required this.passport,
    required this.triageSummary,
    required this.documents,
  });

  final String patientName;
  final int patientAge;
  final String sourceLabel;
  final String requestId;
  final DoctorMedicalRecordScope scope;
  final PatientPassportViewData passport;
  final String triageSummary;
  final List<DoctorMedicalRecordDocument> documents;

  bool get hasFullPassport => scope == DoctorMedicalRecordScope.fullPassport;

  /// D6 demo data reuses the current Patient Passport fixture as a
  /// presentation source, while keeping the urgent-care identity contextual.
  factory DoctorMedicalRecordAccess.fullDemo(DoctorUrgentRequest request) {
    final passport = PatientPassportStaticData.current.copyWith(
      name: request.patientName ?? 'Patient',
      relationship: 'Dossier patient',
      omniCareId: request.id,
      familyMembers: const [],
    );
    return DoctorMedicalRecordAccess(
      patientName: request.patientName ?? 'Patient',
      patientAge: request.age,
      sourceLabel: 'Urgence à domicile',
      requestId: request.id,
      scope: DoctorMedicalRecordScope.fullPassport,
      passport: passport,
      triageSummary: '${request.complaint} · ${request.symptoms.join(', ')}',
      documents: const [
        DoctorMedicalRecordDocument(
          title: 'Bilan sanguin',
          detail: '12 févr. 2026 · PDF',
          icon: 'PDF',
        ),
        DoctorMedicalRecordDocument(
          title: 'Ordonnance',
          detail: '15 janv. 2026 · PDF',
          icon: 'PDF',
        ),
      ],
    );
  }

  /// Fixture used only by UI tests and future restricted-access demos.
  factory DoctorMedicalRecordAccess.lifeSafetyDemo(
    DoctorUrgentRequest request,
  ) {
    final full = DoctorMedicalRecordAccess.fullDemo(request);
    return DoctorMedicalRecordAccess(
      patientName: full.patientName,
      patientAge: full.patientAge,
      sourceLabel: full.sourceLabel,
      requestId: full.requestId,
      scope: DoctorMedicalRecordScope.lifeSafetyOnly,
      passport: full.passport,
      triageSummary: full.triageSummary,
      documents: const [],
    );
  }
}
