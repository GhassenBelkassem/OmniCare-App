import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api/patients_api.dart';
import 'consultation_detail_screen.dart';
import 'medical_document_viewer_screen.dart';
import 'e_prescription_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';

class PatientMedicalPassportScreen extends StatefulWidget {
  final String patientId;
  final String? patientName;

  const PatientMedicalPassportScreen({
    super.key,
    required this.patientId,
    this.patientName,
  });

  @override
  State<PatientMedicalPassportScreen> createState() =>
      _PatientMedicalPassportScreenState();
}

class _PatientMedicalPassportScreenState
    extends State<PatientMedicalPassportScreen> {
  late Future<Map<String, dynamic>> _passportFuture;

  @override
  void initState() {
    super.initState();
    _passportFuture = PatientsApi().getPatientPassport(widget.patientId);
  }

  Map<String, dynamic> _toUiPatientData(Map<String, dynamic> passport) {
    final name = (passport['displayName']?.toString() ?? '').trim();
    final bloodGroup = passport['bloodGroup']?.toString();
    final phone = passport['phoneNumber']?.toString();
    final medicalInfo = passport['medicalInfo'] is Map
        ? (passport['medicalInfo'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};

    return <String, dynamic>{
      'patientId': widget.patientId,
      'name': name.isNotEmpty
          ? name
          : ((widget.patientName ?? '').trim().isNotEmpty
                ? widget.patientName!.trim()
                : 'Patient'),
      'bloodType': (bloodGroup == null || bloodGroup.trim().isEmpty)
          ? 'N/A'
          : bloodGroup,
      'phone': (phone == null || phone.trim().isEmpty) ? 'N/A' : phone,
      'medicalInfo': medicalInfo,
      'age': medicalInfo['age'] ?? 'N/A',
      'gender': medicalInfo['gender'] ?? 'N/A',
      'address': medicalInfo['address'] ?? 'N/A',
      'allergies': (medicalInfo['allergies'] is List)
          ? (medicalInfo['allergies'] as List)
          : const <String>[],
      'chronicConditions': (medicalInfo['chronicConditions'] is List)
          ? (medicalInfo['chronicConditions'] as List)
          : const <String>[],
      'currentMedications': (medicalInfo['currentMedications'] is List)
          ? (medicalInfo['currentMedications'] as List)
          : const <dynamic>[],
      'recentConsultations': const <dynamic>[],
      'medicalDocuments': const <dynamic>[],
      'emergencyContact': const <String, dynamic>{},
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _passportFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFFF4F5F7),
            appBar: AppBar(
              backgroundColor: const Color(0xFF1FBF9A),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: Center(
              child: Text(
                'Failed to load patient data',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF667085),
                ),
              ),
            ),
          );
        }

        final passport = snapshot.data;
        final patientData = passport == null
            ? <String, dynamic>{
                'patientId': widget.patientId,
                'name': (widget.patientName ?? '').trim().isNotEmpty
                    ? widget.patientName!.trim()
                    : 'Patient',
                'age': '...',
                'gender': '...',
                'bloodType': '...',
                'phone': '...',
                'address': '...',
                'allergies': const <String>[],
                'chronicConditions': const <String>[],
                'currentMedications': const <dynamic>[],
                'recentConsultations': const <dynamic>[],
                'medicalDocuments': const <dynamic>[],
                'emergencyContact': const <String, dynamic>{},
              }
            : _toUiPatientData(passport);

        return Scaffold(
          backgroundColor: const Color(0xFFF4F5F7),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButton: _buildBottomActionButton(context, patientData),
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
                      Navigator.pop(context);
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
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        patientData['name'],
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        '${patientData['age']} years  ${patientData['gender']}',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          color: Colors.white.withOpacity(0.9),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    patientData['bloodType'],
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
                      _buildAllergiesCard(patientData),
                      const SizedBox(height: 16),
                      _buildCurrentMedicationsCard(patientData),
                      const SizedBox(height: 16),
                      _buildChronicConditionsCard(patientData),
                      const SizedBox(height: 16),
                      _buildRecentConsultationsCard(context, patientData),
                      const SizedBox(height: 16),
                      _buildMedicalDocumentsCard(context, patientData),
                      const SizedBox(height: 16),
                      _buildEmergencyContactCard(patientData),
                      const SizedBox(height: 16),
                      _buildContactInfoCard(patientData),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget? _buildBottomActionButton(
    BuildContext context,
    Map<String, dynamic> patientData,
  ) {
    final role = (context.read<UserProvider>().user?.role ?? '')
        .trim()
        .toUpperCase();
    final providerType = (context.read<UserProvider>().user?.providerType ?? '')
        .trim()
        .toUpperCase();
    final isDoctor = providerType == 'DOCTOR' || role == 'DOCTOR';

    if (!isDoctor) {
      return null;
    }

    return SizedBox(
      width: MediaQuery.of(context).size.width - 32,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  EPrescriptionScreen(patientData: patientData),
            ),
          );
        },
        icon: const Icon(Icons.description),
        label: Text(
          'Create Prescription',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1FBF9A),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildAllergiesCard(Map<String, dynamic> patientData) {
    final allergies = (patientData['allergies'] as List?) ?? const <String>[];
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
            children: allergies
                .map(
                  (allergy) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      allergy.toString(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentMedicationsCard(Map<String, dynamic> patientData) {
    final medications =
        (patientData['currentMedications'] as List?) ?? const <dynamic>[];
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
          ...medications.map((med) {
            final m = med is Map ? med : <String, dynamic>{};
            return Container(
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
                    (m['name'] ?? 'Medication').toString(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1D2939),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(m['dosage'] ?? '').toString()} - ${(m['frequency'] ?? '').toString()}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: const Color(0xFF667085),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Prescribed by ${(m['prescribedBy'] ?? 'N/A').toString()} on ${(m['startDate'] ?? 'N/A').toString()}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChronicConditionsCard(Map<String, dynamic> patientData) {
    final conditions =
        (patientData['chronicConditions'] as List?) ?? const <String>[];
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
          ...conditions.map(
            (condition) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 8, color: Color(0xFF1FBF9A)),
                  const SizedBox(width: 12),
                  Text(
                    condition.toString(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: const Color(0xFF1D2939),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentConsultationsCard(
    BuildContext context,
    Map<String, dynamic> patientData,
  ) {
    final consultations =
        (patientData['recentConsultations'] as List?) ?? const <dynamic>[];
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
          ...consultations.map(
            (consultation) => GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ConsultationDetailScreen(consultation: consultation),
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
                          (consultation is Map
                                  ? (consultation['doctor'] ?? '')
                                  : '')
                              .toString(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1D2939),
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              (consultation is Map
                                      ? (consultation['date'] ?? '')
                                      : '')
                                  .toString(),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: const Color(0xFF667085),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.chevron_right,
                              color: Color(0xFF667085),
                              size: 20,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (consultation is Map
                              ? (consultation['specialty'] ?? '')
                              : '')
                          .toString(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: const Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      (consultation is Map
                              ? (consultation['diagnosis'] ?? '')
                              : '')
                          .toString(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: const Color(0xFF1D2939),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalDocumentsCard(
    BuildContext context,
    Map<String, dynamic> patientData,
  ) {
    final documents =
        (patientData['medicalDocuments'] as List?) ?? const <dynamic>[];
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
          ...documents.map(
            (doc) => GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        MedicalDocumentViewerScreen(document: doc),
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
                      child: const Icon(
                        Icons.description,
                        color: Color(0xFF1FBF9A),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (doc is Map ? (doc['name'] ?? '') : '').toString(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1D2939),
                            ),
                          ),
                          Text(
                            '${(doc is Map ? (doc['date'] ?? '') : '').toString()} • ${(doc is Map ? (doc['uploadedBy'] ?? '') : '').toString()}',
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyContactCard(Map<String, dynamic> patientData) {
    final emergency = patientData['emergencyContact'] is Map
        ? (patientData['emergencyContact'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
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
                      (emergency['name'] ?? 'N/A').toString(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1D2939),
                      ),
                    ),
                    Text(
                      (emergency['relation'] ?? 'N/A').toString(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: const Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                (emergency['phone'] ?? 'N/A').toString(),
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

  Widget _buildContactInfoCard(Map<String, dynamic> patientData) {
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
              const Icon(
                Icons.contact_phone,
                color: Color(0xFF1FBF9A),
                size: 24,
              ),
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
          _buildInfoRow(
            Icons.phone,
            'Phone',
            (patientData['phone'] ?? 'N/A').toString(),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            Icons.location_on,
            'Address',
            (patientData['address'] ?? 'N/A').toString(),
          ),
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
