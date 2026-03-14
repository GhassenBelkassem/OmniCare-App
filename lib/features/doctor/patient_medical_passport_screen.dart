import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'consultation_detail_screen.dart';
import 'medical_document_viewer_screen.dart';
import 'e_prescription_screen.dart';

class PatientMedicalPassportScreen extends StatelessWidget {
  final String patientId;

  const PatientMedicalPassportScreen({
    super.key,
    required this.patientId,
  });

  // Mock patient data - in real app, fetch from backend using patientId
  Map<String, dynamic> get _patientData => {
    'name': 'Amina Chaari',
    'age': 32,
    'gender': 'Female',
    'bloodType': 'A+',
    'phone': '+216 98 765 432',
    'address': '15 Avenue Habib Bourguiba, Tunis',
    'allergies': ['Pénicilline', 'Arachides'],
    'chronicConditions': ['Migraine chronique', 'Hypertension légère'],
    'currentMedications': [
      {
        'name': 'Paracétamol',
        'dosage': '500mg',
        'frequency': '2x par jour',
        'prescribedBy': 'Dr. Karim Mansour',
        'startDate': '2026-01-15',
      },
      {
        'name': 'Propranolol',
        'dosage': '40mg',
        'frequency': '1x par jour (préventif migraine)',
        'prescribedBy': 'Dr. Leila Trabelsi',
        'startDate': '2025-11-20',
      },
    ],
    'recentConsultations': [
      {
        'date': '2026-01-15',
        'doctor': 'Dr. Karim Mansour',
        'specialty': 'Médecin Généraliste',
        'diagnosis': 'Contrôle tension artérielle',
        'medications': ['Paracétamol 500mg'],
        'symptoms': 'Légère tension, fatigue',
        'notes': 'Patient en bonne santé générale. Tension artérielle légèrement élevée. Recommandation de surveiller et de réduire la consommation de sel. Suivi dans 3 mois.',
        'duration': '25 min',
        'payment': '80 TND',
        'type': 'Home Visit',
      },
      {
        'date': '2025-11-20',
        'doctor': 'Dr. Leila Trabelsi',
        'specialty': 'Neurologue',
        'diagnosis': 'Migraine chronique - Traitement préventif',
        'medications': ['Propranolol 40mg'],
        'symptoms': 'Maux de tête fréquents, sensibilité à la lumière',
        'notes': 'Migraines récurrentes depuis 6 mois. Prescription de Propranolol comme traitement préventif. Éviter les déclencheurs connus. Suivi dans 2 mois.',
        'duration': '40 min',
        'payment': '120 TND',
        'type': 'Clinic Visit',
      },
      {
        'date': '2025-10-08',
        'doctor': 'Dr. Ahmed Khelifi',
        'specialty': 'Cardiologue',
        'diagnosis': 'Hypertension légère',
        'medications': [],
        'symptoms': 'Aucun symptôme spécifique, contrôle de routine',
        'notes': 'ECG normal. Tension artérielle légèrement élevée. Recommandation de modifications du mode de vie: exercice régulier, alimentation équilibrée, réduction du stress.',
        'duration': '30 min',
        'payment': '100 TND',
        'type': 'Clinic Visit',
      },
    ],
    'medicalDocuments': [
      {
        'name': 'Analyse Sang Complète',
        'type': 'blood-test',
        'date': '2026-01-10',
        'uploadedBy': 'Dr. Karim Mansour',
      },
      {
        'name': 'Scanner Cérébral',
        'type': 'scan',
        'date': '2025-11-15',
        'uploadedBy': 'Dr. Leila Trabelsi',
      },
      {
        'name': 'ECG',
        'type': 'report',
        'date': '2025-10-08',
        'uploadedBy': 'Dr. Ahmed Khelifi',
      },
    ],
    'emergencyContact': {
      'name': 'Mohamed Chaari',
      'relation': 'Spouse',
      'phone': '+216 98 123 456',
    },
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: const Color(0xFF1FBF9A),
            leading: const SizedBox.shrink(),
            actions: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  // Navigate to e-prescription screen
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EPrescriptionScreen(
                        patientData: _patientData,
                      ),
                    ),
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1FBF9A), Color(0xFF0F6F73)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                              ),
                              child: const Icon(
                                Icons.person,
                                size: 40,
                                color: Color(0xFF1FBF9A),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _patientData['name'],
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    '${_patientData['age']} years • ${_patientData['gender']}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _patientData['bloodType'],
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Critical Alerts - Allergies
                  _buildAllergiesCard(),
                  const SizedBox(height: 16),

                  // Current Medications
                  _buildCurrentMedicationsCard(),
                  const SizedBox(height: 16),

                  // Chronic Conditions
                  _buildChronicConditionsCard(),
                  const SizedBox(height: 16),

                  // Recent Consultations
                  _buildRecentConsultationsCard(context),
                  const SizedBox(height: 16),

                  // Medical Documents
                  _buildMedicalDocumentsCard(context),
                  const SizedBox(height: 16),

                  // Emergency Contact
                  _buildEmergencyContactCard(),
                  const SizedBox(height: 16),

                  // Contact Info
                  _buildContactInfoCard(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllergiesCard() {
    final allergies = _patientData['allergies'] as List;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning, color: Colors.red, size: 24),
              const SizedBox(width: 12),
              Text(
                'ALLERGIES - CRITICAL',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allergies.map((allergy) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                allergy,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentMedicationsCard() {
    final medications = _patientData['currentMedications'] as List;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.medication, color: Color(0xFF1FBF9A), size: 24),
              const SizedBox(width: 12),
              Text(
                'Current Medications',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1D2939),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...medications.map((med) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F5F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  med['name'],
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1D2939),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${med['dosage']} - ${med['frequency']}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: const Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Prescribed by ${med['prescribedBy']} on ${med['startDate']}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFF667085),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildChronicConditionsCard() {
    final conditions = _patientData['chronicConditions'] as List;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite, color: Color(0xFF1FBF9A), size: 24),
              const SizedBox(width: 12),
              Text(
                'Chronic Conditions',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1D2939),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...conditions.map((condition) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 8, color: Color(0xFF1FBF9A)),
                const SizedBox(width: 12),
                Text(
                  condition,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: const Color(0xFF1D2939),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildRecentConsultationsCard(BuildContext context) {
    final consultations = _patientData['recentConsultations'] as List;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, color: Color(0xFF1FBF9A), size: 24),
              const SizedBox(width: 12),
              Text(
                'Recent Consultations',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1D2939),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...consultations.map((consultation) => GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ConsultationDetailScreen(
                    consultation: consultation,
                  ),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F5F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        consultation['doctor'],
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1D2939),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            consultation['date'],
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: const Color(0xFF667085),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right, color: Color(0xFF667085), size: 20),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    consultation['specialty'],
                    style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: const Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  consultation['diagnosis'],
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: const Color(0xFF1D2939),
                  ),
                ),
              ],
            ),
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildMedicalDocumentsCard(BuildContext context) {
    final documents = _patientData['medicalDocuments'] as List;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.folder_open, color: Color(0xFF1FBF9A), size: 24),
              const SizedBox(width: 12),
              Text(
                'Medical Documents',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1D2939),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...documents.map((doc) => GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MedicalDocumentViewerScreen(
                    document: doc,
                  ),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F5F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1FBF9A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.description, color: Color(0xFF1FBF9A), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc['name'],
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1D2939),
                          ),
                        ),
                        Text(
                          '${doc['date']} • ${doc['uploadedBy']}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: const Color(0xFF667085),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFF667085)),
                ],
              ),
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildEmergencyContactCard() {
    final emergency = _patientData['emergencyContact'] as Map;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emergency, color: Colors.orange, size: 24),
              const SizedBox(width: 12),
              Text(
                'Emergency Contact',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1D2939),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emergency['name'],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1D2939),
                      ),
                    ),
                    Text(
                      emergency['relation'],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: const Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                emergency['phone'],
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1FBF9A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.contact_phone, color: Color(0xFF1FBF9A), size: 24),
              const SizedBox(width: 12),
              Text(
                'Contact Information',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1D2939),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.phone, 'Phone', _patientData['phone']),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.location_on, 'Address', _patientData['address']),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF667085), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF667085),
                ),
              ),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: const Color(0xFF1D2939),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
