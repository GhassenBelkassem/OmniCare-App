import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'history_tab.dart';
import '../../core/api/consultations_api.dart';
import '../../core/api/medical_acts_api.dart';
import '../../core/api/files_api.dart';
import '../../providers/user_provider.dart';

class ConsultationDetailScreen extends StatefulWidget {
  final Consultation consultation;

  const ConsultationDetailScreen({super.key, required this.consultation});

  @override
  State<ConsultationDetailScreen> createState() =>
      _ConsultationDetailScreenState();
}

class _ConsultationDetailScreenState extends State<ConsultationDetailScreen> {
  Consultation get consultation => widget.consultation;

  List<String>? _prescribedMedications;
  bool _isLoadingPrescription = false;
  String? _prescriptionError;
  String? _prescriptionId;

  bool _isSavingMedicalAct = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadPrescriptionIfNeeded();
    });
  }

  Widget _buildMedicalActActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.verified, color: Color(0xFF1FBF9A), size: 20),
            const SizedBox(width: 8),
            Text(
              'Prescription',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A202C),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSavingMedicalAct
                      ? null
                      : () => _showMarkAsAdministeredSheet(),
                  icon: _isSavingMedicalAct
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check, size: 16),
                  label: Text(
                    _isSavingMedicalAct ? 'Saving...' : 'Mark as Administered',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1FBF9A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showMarkAsAdministeredSheet() async {
    if ((_prescriptionId ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prescription not loaded yet'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
      return;
    }

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Record Medical Act',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A202C),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _createMedicalAct(actType: 'ADMINISTERED');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1FBF9A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Administered (no photo)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _createInjectionMedicalAct();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1A202C),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Injection (requires photo)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _createInjectionMedicalAct() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );
      final path = result?.files.single.path;
      if (path == null || path.trim().isEmpty) {
        return;
      }

      final upload = await FilesApi().uploadFile(
        file: XFile(path),
        folder: 'omnicare/documents',
      );

      await _createMedicalAct(actType: 'INJECTION', photoUrl: upload.url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _createMedicalAct({
    required String actType,
    String? photoUrl,
  }) async {
    final pid = (_prescriptionId ?? '').trim();
    if (pid.isEmpty) {
      return;
    }

    setState(() {
      _isSavingMedicalAct = true;
    });

    try {
      await MedicalActsApi().createMedicalAct(
        prescriptionId: pid,
        actType: actType,
        photoUrl: photoUrl,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medical act recorded'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSavingMedicalAct = false;
      });
    }
  }

  Future<void> _loadPrescriptionIfNeeded() async {
    final isCompleted = (widget.consultation.status == 'completed');
    if (!isCompleted) return;
    if (widget.consultation.id.trim().isEmpty) return;

    setState(() {
      _isLoadingPrescription = true;
      _prescriptionError = null;
    });

    try {
      final raw = await ConsultationsApi().getPrescription(
        consultationId: widget.consultation.id,
      );
      final prescriptionId = raw['id']?.toString().trim();
      final items = raw['items'];

      final meds = <String>[];
      if (items is List) {
        for (final it in items) {
          if (it is Map) {
            final name = (it['medicationName'] ?? '').toString().trim();
            if (name.isNotEmpty) meds.add(name);
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _prescribedMedications = meds;
        _prescriptionId = (prescriptionId != null && prescriptionId.isNotEmpty)
            ? prescriptionId
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _prescriptionError = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingPrescription = false;
      });
    }
  }

  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    final months = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];
    final days = [
      'lundi',
      'mardi',
      'mercredi',
      'jeudi',
      'vendredi',
      'samedi',
      'dimanche',
    ];

    final weekday = days[date.weekday - 1];
    final day = date.day;
    final month = months[date.month - 1];
    final year = date.year;

    return '${weekday.substring(0, 1).toUpperCase()}${weekday.substring(1)} $day $month $year';
  }

  @override
  Widget build(BuildContext context) {
    final consultation = widget.consultation;
    final isCompleted = consultation.status == 'completed';

    final userRole = context
        .read<UserProvider>()
        .user
        ?.role
        ?.trim()
        .toUpperCase();
    final canRecordMedicalAct = userRole == 'NURSE' || userRole == 'KINE';

    final List<String>? medications =
        (consultation.medications != null &&
            consultation.medications!.isNotEmpty)
        ? consultation.medications
        : _prescribedMedications;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: Column(
        children: [
          _buildHeader(context, isCompleted),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDateTimeSection(),
                  const SizedBox(height: 20),
                  _buildDoctorSection(),
                  const SizedBox(height: 20),
                  _buildPatientLocationSection(),
                  const SizedBox(height: 20),
                  _buildReasonSection(),
                  if (isCompleted && consultation.diagnosis != null) ...[
                    const SizedBox(height: 20),
                    _buildDiagnosisSection(),
                  ],
                  if (isCompleted && _prescriptionError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _prescriptionError!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                  if (isCompleted && _isLoadingPrescription) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Loading prescription...',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF667085),
                      ),
                    ),
                  ],
                  if (isCompleted &&
                      medications != null &&
                      medications.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildMedicationsSection(),
                  ],
                  if (isCompleted &&
                      canRecordMedicalAct &&
                      (_prescriptionId ?? '').isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _buildMedicalActActionsSection(),
                  ],
                  const SizedBox(height: 20),
                  _buildCostActionsSection(),
                  const SizedBox(height: 20),
                  _buildNoteSection(),
                  const SizedBox(height: 20),
                  _buildFooter(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isCompleted) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFF1FBF9A).withOpacity(0.1),
            Colors.white,
            const Color(0xFF6BE3B2).withOpacity(0.1),
          ],
        ),
        border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Color(0xFF1A202C)),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF4F5F7),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? const Color(0xFF10B981).withOpacity(0.1)
                                : const Color(0xFFFECACA),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.description,
                            color: isCompleted
                                ? const Color(0xFF10B981)
                                : const Color(0xFFDC2626),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Consultation Médicale',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1A202C),
                                ),
                              ),
                              Row(
                                children: [
                                  Icon(
                                    isCompleted
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    size: 14,
                                    color: isCompleted
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFDC2626),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isCompleted ? 'Terminée' : 'Annulée',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isCompleted
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFDC2626),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimeSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1FBF9A).withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1FBF9A).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.calendar_today,
                    color: Color(0xFF1FBF9A),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DATE',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF667085),
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(consultation.date),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A202C),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F6F73).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.access_time,
                    color: Color(0xFF0F6F73),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HEURE',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF667085),
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        consultation.time,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A202C),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.medical_services,
              color: Color(0xFF1FBF9A),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Informations du Médecin',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A202C),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
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
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF1FBF9A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF1FBF9A).withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.person,
                  color: Color(0xFF1FBF9A),
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      consultation.doctorName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1A202C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      consultation.specialty,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1FBF9A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone,
                          size: 14,
                          color: Color(0xFF667085),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '+216 98 XXX XXX',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: const Color(0xFF667085),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.email,
                          size: 14,
                          color: Color(0xFF667085),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'contact@doctor.tn',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: const Color(0xFF667085),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPatientLocationSection() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F6F73).withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F6F73).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        color: Color(0xFF0F6F73),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'PATIENT',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF667085),
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  consultation.patientName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A202C),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1FBF9A).withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1FBF9A).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.location_on,
                        color: Color(0xFF1FBF9A),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'LIEU',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF667085),
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  consultation.location,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A202C),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReasonSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.description, color: Color(0xFF1FBF9A), size: 20),
            const SizedBox(width: 8),
            Text(
              'Motif de Consultation',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A202C),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            consultation.reason,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: const Color(0xFF1A202C),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDiagnosisSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.favorite, color: Color(0xFF1FBF9A), size: 20),
            const SizedBox(width: 8),
            Text(
              'Diagnostic Médical',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A202C),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1FBF9A).withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF1FBF9A).withOpacity(0.2),
              width: 2,
            ),
          ),
          child: Text(
            consultation.diagnosis!,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: const Color(0xFF1A202C),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMedicationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.medication, color: Color(0xFF0F6F73), size: 20),
            const SizedBox(width: 8),
            Text(
              'Médicaments Prescrits',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A202C),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
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
            children: consultation.medications!.asMap().entries.map((entry) {
              final index = entry.key;
              final med = entry.value;
              return Container(
                margin: EdgeInsets.only(
                  bottom: index < consultation.medications!.length - 1 ? 12 : 0,
                ),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F6F73).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F6F73).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.medication,
                        color: Color(0xFF0F6F73),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        med,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A202C),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCostActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.attach_money, color: Color(0xFF1FBF9A), size: 20),
            const SizedBox(width: 8),
            Text(
              'Coût & Actions',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A202C),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1FBF9A).withOpacity(0.05),
                const Color(0xFF6BE3B2).withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'COÛT TOTAL',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF667085),
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        consultation.cost,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1FBF9A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.download, size: 16),
                      label: Text(
                        'Télécharger',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1A202C),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.print, size: 16),
                      label: Text(
                        'Imprimer',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1A202C),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.share, size: 16),
                      label: Text(
                        'Partager',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1A202C),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoteSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: Color(0xFF1FBF9A), width: 4),
        ),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'Note: ',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A202C),
              ),
            ),
            TextSpan(
              text:
                  'Ce document est un résumé de votre consultation médicale. Pour toute question ou besoin de clarification, veuillez contacter directement votre médecin.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: const Color(0xFF667085),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Consultation ID: #${consultation.id}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: const Color(0xFF667085),
            ),
          ),
        ],
      ),
    );
  }
}
