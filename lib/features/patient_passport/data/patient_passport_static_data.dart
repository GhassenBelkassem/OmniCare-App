import '../models/patient_passport_view_models.dart';

abstract final class PatientPassportStaticData {
  static const PatientPassportViewData current = PatientPassportViewData(
    name: 'Sarah Ben Ahmed',
    relationship: 'Mon passeport',
    phone: '+216 98 456 789',
    email: 'sarah.benahmed@omnicare.app',
    omniCareId: 'OMNI-12345',
    bloodGroup: 'A+',
    allergies: 'Aucune allergie connue',
    chronicConditions: ['Diabète Type 2', 'Hypertension'],
    medications: [
      PassportMedication(
        name: 'Metformine',
        dosage: '500mg',
        frequency: '2× par jour',
        isCurrent: true,
      ),
      PassportMedication(
        name: 'Lisinopril',
        dosage: '10mg',
        frequency: '1× par jour',
        isCurrent: true,
      ),
      PassportMedication(
        name: 'Aspirine',
        dosage: '81mg',
        frequency: '1× par jour',
        isCurrent: true,
      ),
      PassportMedication(
        name: 'Amoxicilline',
        dosage: '500mg',
        frequency: '3× par jour',
        isCurrent: false,
        stoppedLabel: 'Arrêté nov. 2025',
      ),
    ],
    consultations: [
      PassportConsultation(
        date: '12 févr. 2026',
        doctor: 'Dr. Karim Mansour',
        reason: 'Contrôle de routine',
        specialty: 'Médecin Généraliste',
        status: PassportConsultationStatus.completed,
        isShareable: true,
      ),
      PassportConsultation(
        date: '15 janv. 2026',
        doctor: 'Dr. Karim Mansour',
        reason: 'Vaccination',
        specialty: 'Médecin Généraliste',
        status: PassportConsultationStatus.completed,
        isShareable: true,
      ),
      PassportConsultation(
        date: '10 janv. 2026',
        doctor: 'Dr. Nadia Hamdi',
        reason: 'Consultation annuelle',
        specialty: 'Gynécologue',
        status: PassportConsultationStatus.cancelled,
        isShareable: false,
      ),
    ],
    familyMembers: [
      PassportFamilyMember(
        name: 'Sarah Ben Ahmed',
        relationship: 'Mon passeport',
        avatarAsset: 'assets/images/doctors/sarah_mansour.jpg',
      ),
      PassportFamilyMember(
        name: 'Mohamed Ben Ahmed',
        relationship: 'Baba',
        avatarAsset: 'assets/images/doctors/karim_bensalem.jpg',
      ),
      PassportFamilyMember(
        name: 'Fatma Ben Salem',
        relationship: 'Maman',
        avatarAsset: 'assets/images/doctors/nadia_cherif.jpg',
      ),
      PassportFamilyMember(
        name: 'Youssef Ben Ahmed',
        relationship: 'Enfant',
        avatarAsset: 'assets/images/doctors/redha_amrani.jpg',
      ),
      PassportFamilyMember(
        name: 'Amira Ben Ahmed',
        relationship: 'Enfant',
        avatarAsset: 'assets/images/doctors/amina_hadj.jpg',
      ),
    ],
  );
}
