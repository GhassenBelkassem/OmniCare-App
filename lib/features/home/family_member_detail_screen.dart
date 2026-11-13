import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/models/blood_type.dart';
import 'edit_medical_data_screen.dart';
import 'document_viewer_screen.dart';
import 'qr_code_modal.dart';
import '../patient_passport/sharing/medical_sharing_models.dart';

import '../patient_passport/application/medical_data_editor_view_model.dart';
import '../patient_passport/data/medical_record_models.dart';
import '../../core/l10n/blood_type_label.dart';
import '../../l10n/omni_localizations.dart';

class FamilyMember {
  String id;
  String name;
  int age;
  String relationship;
  String avatar;

  /// Null when not provided (shown as "-").
  BloodType? bloodType;
  List<String> chronicConditions;
  List<Medication> currentMedications;
  List<MedicalDocument> documents;
  String? criticalAlert;
  String? phoneNumber;

  FamilyMember({
    required this.id,
    required this.name,
    required this.age,
    required this.relationship,
    required this.avatar,
    required this.bloodType,
    required this.chronicConditions,
    required this.currentMedications,
    required this.documents,
    this.criticalAlert,
    this.phoneNumber,
  });
}

class FamilyMemberDetailScreen extends StatefulWidget {
  final FamilyMember member;

  const FamilyMemberDetailScreen({super.key, required this.member});

  @override
  State<FamilyMemberDetailScreen> createState() =>
      _FamilyMemberDetailScreenState();
}

class _FamilyMemberDetailScreenState extends State<FamilyMemberDetailScreen> {
  late FamilyMember _member;
  final bool _showQR = false;

  @override
  void initState() {
    super.initState();
    _member = widget.member;
  }

  /// The record editor's section saves for this family member only
  /// (FAMILY:{id}, G2.1-A3). What was saved is shown here; the documents
  /// block stays local, as before.
  Future<void> _handleEditMedicalData() async {
    final editor = context.read<MedicalDataEditorFactory>().create(
      FamilyRecordSubject(_member.id),
    );
    final result = await Navigator.push<MedicalDataEditResult>(
      context,
      MaterialPageRoute(
        builder: (context) => EditMedicalDataScreen(
          viewModel: editor,
          documents: _member.documents,
        ),
      ),
    );
    editor.dispose();
    if (!mounted || result == null) return;
    setState(() {
      _member.documents = result.documents;
      if (result.saved case final saved?) {
        _member.bloodType = saved.bloodType;
        _member.chronicConditions = saved.conditions;
        _member.currentMedications = saved.medications;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A202C)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.assignment,
                  color: Color(0xFF1FBF9A),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Carnet de Santé',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A202C),
                  ),
                ),
              ],
            ),
            Text(
              'Détails médicaux complets',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: const Color(0xFF667085),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: _handleEditMedicalData,
              icon: const Icon(Icons.edit, size: 16),
              label: Text(
                'Modifier',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1FBF9A),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildProfileOverviewCard(),
            const SizedBox(height: 20),
            _buildMedicalPassportSection(),
            const SizedBox(height: 20),
            _buildMedicalDocumentsSection(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOverviewCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar with relationship badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF1FBF9A), width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1FBF9A).withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Icon(
                    Icons.person,
                    size: 48,
                    color: const Color(0xFF1FBF9A),
                  ),
                ),
              ),
              Positioned(
                bottom: -8,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F6F73),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      _member.relationship,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Name
          Text(
            _member.name,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A202C),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Info row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person, size: 16, color: const Color(0xFF667085)),
              const SizedBox(width: 4),
              Text(
                '${_member.age} ans',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: const Color(0xFF667085),
                ),
              ),
              if (_member.phoneNumber != null) ...[
                const SizedBox(width: 16),
                const Text('📞', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text(
                  _member.phoneNumber!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: const Color(0xFF667085),
                  ),
                ),
              ],
            ],
          ),

          // Critical Alert
          if (_member.criticalAlert != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                border: Border.all(color: const Color(0xFFFECACA)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFDC2626),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _member.criticalAlert!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFDC2626),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMedicalPassportSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1FBF9A).withOpacity(0.05),
            Colors.white,
            const Color(0xFF6BE3B2).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // QR Code
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => QRCodeModal(
                  patientName: _member.name,
                  subject: MedicalSharingSubject.family(_member.id),
                  isFamilyMember: true,
                ),
              );
            },
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF1FBF9A).withOpacity(0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1FBF9A).withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.qr_code_2,
                    size: 64,
                    color: const Color(0xFF1FBF9A),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Cliquez pour afficher',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'QR Code Médical',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A202C),
            ),
          ),
          Text(
            'Pour scan par médecin',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: const Color(0xFF667085),
            ),
          ),
          const SizedBox(height: 24),

          // Blood Type
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              border: Border.all(color: const Color(0xFFFECACA)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.favorite, color: Color(0xFFDC2626), size: 24),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GROUPE SANGUIN',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF667085),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _member.bloodType?.label(OmniLocalizations.of(context)) ??
                          '-',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Chronic Conditions
          if (_member.chronicConditions.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'CONDITIONS CHRONIQUES',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF667085),
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _member.chronicConditions.map((condition) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6BE3B2).withOpacity(0.1),
                    border: Border.all(
                      color: const Color(0xFF6BE3B2).withOpacity(0.3),
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: const Color(0xFF0F6F73),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        condition,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F6F73),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],

          // Current Medications
          if (_member.currentMedications.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'MÉDICAMENTS ACTUELS',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF667085),
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Column(
              children: _member.currentMedications.map((med) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1FBF9A).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.medication,
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
                              med.name,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1A202C),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${med.dosage} • ${med.frequency}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF667085),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMedicalDocumentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Documents Médicaux',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A202C),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Historique médical complet',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: const Color(0xFF667085),
          ),
        ),
        const SizedBox(height: 16),

        if (_member.documents.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 48,
                    color: const Color(0xFF667085).withOpacity(0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Aucun document médical',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: const Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: _member.documents.map((doc) {
                Color docColor;
                IconData docIcon;

                switch (doc.type) {
                  case 'blood-test':
                    docColor = const Color(0xFFDC2626);
                    docIcon = Icons.bloodtype;
                    break;
                  case 'xray':
                  case 'scan':
                    docColor = const Color(0xFF8B5CF6);
                    docIcon = Icons.medical_services;
                    break;
                  case 'prescription':
                    docColor = const Color(0xFF1FBF9A);
                    docIcon = Icons.description;
                    break;
                  default:
                    docColor = const Color(0xFF667085);
                    docIcon = Icons.insert_drive_file;
                }

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DocumentViewerScreen(
                          documentName: doc.name,
                          documentDate: doc.date,
                          documentType: doc.type,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: docColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: docColor.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: docColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(docIcon, color: docColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                doc.name,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1A202C),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                doc.date,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF667085),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: Color(0xFF667085),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
