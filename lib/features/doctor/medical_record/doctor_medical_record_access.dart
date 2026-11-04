import '../urgent/doctor_urgent_controller.dart';
import '../../patient_passport/data/patient_passport_static_data.dart';
import '../../patient_passport/models/patient_passport_view_models.dart';
import 'doctor_medical_record_workspace.dart';

/// The scope granted to a doctor for one focused care interaction.
///
/// The production workspace builds this presentation adapter only from the
/// Spring/MRS response. Demo constructors below are retained for UI tests and
/// previews and are not reachable from the authenticated Doctor shell.
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
    this.canonical = false,
    this.essentialShared = true,
    this.medicationsShared = true,
    this.summariesShared = true,
  });

  final String patientName;
  final int patientAge;
  final String sourceLabel;
  final String requestId;
  final DoctorMedicalRecordScope scope;
  final PatientPassportViewData passport;
  final String triageSummary;
  final List<DoctorMedicalRecordDocument> documents;
  final bool canonical;
  final bool essentialShared;
  final bool medicationsShared;
  final bool summariesShared;

  bool get hasFullPassport => scope == DoctorMedicalRecordScope.fullPassport;

  factory DoctorMedicalRecordAccess.fromWorkspace(
    DoctorMedicalRecordWorkspace workspace,
  ) {
    final essential = workspace.essentialInformation;
    final medications = workspace.currentMedications
        .map(
          (item) => PassportMedication(
            name: item.displayName,
            dosage: item.instruction,
            frequency: '',
            isCurrent: true,
          ),
        )
        .toList(growable: false);
    final consultations = workspace.consultationSummaries
        .map(
          (item) => PassportConsultation(
            consultationId: item.consultationId,
            date: item.occurredAt ?? 'Date non renseignée',
            doctor: '',
            doctorType: 'Dossier MRS',
            reason: item.title,
            specialty: '',
            diagnosis: item.diagnoses.join(', '),
            status: PassportConsultationStatus.completed,
            isShareable: true,
            assessment: item.assessment,
            treatmentPlan: item.treatmentPlan,
            notes: item.notes,
          ),
        )
        .toList(growable: false);
    return DoctorMedicalRecordAccess(
      patientName: 'Patient',
      patientAge: 0,
      sourceLabel: 'Consultation active',
      requestId: workspace.consultationId,
      scope: DoctorMedicalRecordScope.fullPassport,
      passport: PatientPassportViewData(
        name: '',
        relationship: '',
        phone: '',
        email: '',
        omniCareId: '',
        bloodGroup: essential?.bloodType ?? 'Non renseigné',
        allergies: essential == null || essential.allergies.isEmpty
            ? 'Aucune donnée'
            : essential.allergies.join(', '),
        chronicConditions: essential?.criticalConditions ?? const [],
        medications: medications,
        consultations: consultations,
        familyMembers: const [],
        heightCm: 0,
        weightKg: 0,
      ),
      triageSummary: '',
      documents: const [],
      canonical: true,
      essentialShared: workspace.sectionAuthorized('ESSENTIAL_INFORMATION'),
      medicationsShared: workspace.sectionAuthorized('CURRENT_MEDICATIONS'),
      summariesShared: workspace.sectionAuthorized('CONSULTATION_SUMMARIES'),
    );
  }

  /// Test/preview-only D6 fixture retained for visual regression coverage.
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
      medicationsShared: false,
      summariesShared: false,
    );
  }
}
