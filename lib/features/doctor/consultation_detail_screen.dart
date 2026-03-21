import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/api/api_error_utils.dart';
import '../../core/api/consultations_api.dart';
import '../../core/models/consultation.dart';

class ConsultationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> consultation;
  final String consultationId;

  const ConsultationDetailScreen({
    super.key,
    required this.consultation,
    required this.consultationId,
  });

  @override
  State<ConsultationDetailScreen> createState() =>
      _ConsultationDetailScreenState();
}

class _ConsultationDetailScreenState extends State<ConsultationDetailScreen> {
  Consultation? _consultation;

  Map<String, dynamic> get consultation => widget.consultation;

  late final TextEditingController _diagnosisController;
  late final TextEditingController _treatmentController;

  bool _isLoading = true;
  bool _isSaving = false;

  String _displayOrDash(String? v) {
    final t = (v ?? '').trim();
    return t.isEmpty ? '--' : t;
  }

  String _vitalText(num? v, {String? unit}) {
    if (v == null) return 'Not Recorded';
    final u = (unit ?? '').trim();
    if (u.isEmpty) return v.toString();
    return '${v.toString()} $u';
  }

  String get _consultationId {
    final id = widget.consultationId.trim();
    if (id.isEmpty) {
      throw StateError('consultationId is required');
    }
    return id;
  }

  @override
  void initState() {
    super.initState();

    _diagnosisController = TextEditingController(
      text: (widget.consultation['diagnosis'] ?? '').toString(),
    );
    _treatmentController = TextEditingController(
      text: (widget.consultation['treatment'] ?? '').toString(),
    );

    _load();
  }

  Future<void> _load() async {
    final id = _consultationId;

    try {
      final c = await ConsultationsApi().getConsultation(consultationId: id);
      if (!mounted) return;
      setState(() {
        _consultation = c;
      });

      _diagnosisController.text = (c.diagnosis ?? '').toString();
      _treatmentController.text = (c.treatment ?? '').toString();
    } catch (_) {
      // Non-fatal; we can still use the passed-in map values.
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveDraft() async {
    final id = _consultationId;

    setState(() {
      _isSaving = true;
    });
    try {
      final updated = await ConsultationsApi().patchConsultation(
        consultationId: id,
        diagnosis: _diagnosisController.text,
        treatment: _treatmentController.text,
      );
      if (!mounted) return;
      setState(() {
        _consultation = updated;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Saved to Database'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: ${apiErrorMessage(e)}'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _complete() async {
    final id = _consultationId;

    setState(() {
      _isSaving = true;
    });
    try {
      await ConsultationsApi().patchConsultation(
        consultationId: id,
        diagnosis: _diagnosisController.text,
        treatment: _treatmentController.text,
      );

      final completed = await ConsultationsApi().completeConsultation(
        consultationId: id,
        diagnosis: _diagnosisController.text,
        treatment: _treatmentController.text,
      );

      if (!mounted) return;
      setState(() {
        _consultation = completed;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Consultation completed'),
          backgroundColor: Color(0xFF10B981),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to complete: ${apiErrorMessage(e)}'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  void dispose() {
    _diagnosisController.dispose();
    _treatmentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _consultation;
    final symptoms = (c?.symptoms ?? widget.consultation['symptoms'])
        ?.toString()
        .trim();
    final doctorName = (c?.doctorName ?? widget.consultation['doctorName'])
        ?.toString()
        .trim();
    final doctorSpecialty =
        (c?.doctorSpecialty ?? widget.consultation['doctorSpecialty'])
            ?.toString()
            .trim();

    final fee = c?.fee;
    final feeText = (fee == null) ? null : '${fee.toStringAsFixed(0)} DT';

    final patientName = _displayOrDash(
      (c?.patientName ?? widget.consultation['patientName'])?.toString(),
    );
    final patientAge = (c?.patientAge ?? widget.consultation['patientAge']);
    final patientGender = _displayOrDash(
      (c?.patientGender ?? widget.consultation['patientGender'])?.toString(),
    );
    final height = c?.height;
    final weight = c?.weight;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1D2939)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Consultation Details',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1D2939),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1FBF9A), Color(0xFF0F6F73)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                patientName,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                [
                                      if (patientAge != null)
                                        '${patientAge.toString()}y',
                                      if (patientGender != '--') patientGender,
                                    ].join(' • ').trim().isEmpty
                                    ? 'Patient'
                                    : [
                                        if (patientAge != null)
                                          '${patientAge.toString()}y',
                                        if (patientGender != '--')
                                          patientGender,
                                      ].join(' • '),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                              if (symptoms != null && symptoms.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'Symptoms: $symptoms',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                [
                                      (doctorName == null || doctorName.isEmpty)
                                          ? 'Doctor'
                                          : doctorName,
                                      (doctorSpecialty == null ||
                                              doctorSpecialty.isEmpty)
                                          ? null
                                          : doctorSpecialty,
                                    ]
                                    .whereType<String>()
                                    .where((e) => e.trim().isNotEmpty)
                                    .join(' • '),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Patient',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1D2939),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSectionCard(
                                'Name',
                                Icons.person,
                                patientName,
                                const Color(0xFF0F6F73),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSectionCard(
                                'Age',
                                Icons.cake,
                                (patientAge == null)
                                    ? '--'
                                    : patientAge.toString(),
                                const Color(0xFF0F6F73),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildSectionCard(
                                'Gender',
                                Icons.wc,
                                patientGender,
                                const Color(0xFF0F6F73),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSectionCard(
                                'Height',
                                Icons.height,
                                _vitalText(height, unit: 'cm'),
                                const Color(0xFF0F6F73),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildSectionCard(
                                'Weight',
                                Icons.monitor_weight_outlined,
                                _vitalText(weight, unit: 'kg'),
                                const Color(0xFF0F6F73),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Diagnosis',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1D2939),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _diagnosisController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Enter diagnosis',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Treatment',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1D2939),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _treatmentController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Enter treatment',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isSaving ? null : _saveDraft,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF1FBF9A),
                                  side: const BorderSide(
                                    color: Color(0xFF1FBF9A),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Save',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _complete,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1FBF9A),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Complete',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  if (symptoms != null && symptoms.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      'Symptoms',
                      Icons.sick,
                      symptoms,
                      Colors.orange,
                    ),
                  ],

                  if (feeText != null) ...[
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      'Payment',
                      Icons.payments_outlined,
                      feeText,
                      const Color(0xFF0F6F73),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildSectionCard(
    String title,
    IconData icon,
    String content,
    Color color,
  ) {
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
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1D2939),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              color: const Color(0xFF1D2939),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationsCard() {
    final medications = consultation['medications'] as List? ?? [];
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
                'Prescribed Medications',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1D2939),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (medications.isEmpty)
            Text(
              'No medications prescribed',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: const Color(0xFF667085),
              ),
            )
          else
            ...medications.map(
              (med) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F5F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 8, color: Color(0xFF1FBF9A)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        med,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: const Color(0xFF1D2939),
                        ),
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

  Widget _buildDoctorNotesCard() {
    final notes = (consultation['notes'] ?? consultation['clinicalNotes'])
        ?.toString()
        .trim();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF8FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0F6F73).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.note_alt, color: Color(0xFF0F6F73), size: 24),
              const SizedBox(width: 12),
              Text(
                'Doctor\'s Notes',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1D2939),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            (notes == null || notes.isEmpty) ? 'No notes recorded' : notes,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: const Color(0xFF1D2939),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEPrescriptionCard() {
    final medications = consultation['medications'] as List? ?? [];
    final date = consultation['date']?.toString();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1FBF9A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.receipt_long,
                    color: Color(0xFF1FBF9A),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'E-Prescription',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1D2939),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1FBF9A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified,
                      color: Color(0xFF1FBF9A),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Verified',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1FBF9A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F5F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Date:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      (date == null || date.trim().isEmpty) ? 'N/A' : date,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF1D2939),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  'Medications:',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1D2939),
                  ),
                ),
                const SizedBox(height: 12),
                if (medications.isEmpty)
                  Text(
                    'No medications prescribed',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: const Color(0xFF667085),
                    ),
                  )
                else
                  ...medications.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1FBF9A),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${entry.key + 1}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                color: const Color(0xFF1D2939),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsultationInfoCard() {
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
                Icons.info_outline,
                color: Color(0xFF1FBF9A),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Consultation Information',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1D2939),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Duration', consultation['duration'] ?? '30 min'),
          _buildInfoRow('Payment', consultation['payment'] ?? '100 TND'),
          _buildInfoRow('Type', consultation['type'] ?? 'Home Visit'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF667085),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1D2939),
            ),
          ),
        ],
      ),
    );
  }
}
