import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/api/consultations_api.dart';
import '../../core/api/api_error_utils.dart';
import '../../core/models/consultation.dart';
import '../../core/utils/console_log.dart';

class ConsultationQRScreen extends StatefulWidget {
  final Map<String, dynamic> requestData;

  const ConsultationQRScreen({
    super.key,
    required this.requestData,
  });

  @override
  State<ConsultationQRScreen> createState() => _ConsultationQRScreenState();
}

class _ConsultationQRScreenState extends State<ConsultationQRScreen> {
  bool _isCompleting = false;

  Map<String, dynamic> get requestData => widget.requestData;

  Future<void> _completeAndNavigate() async {
    if (_isCompleting) return;

    final consultationId = requestData['consultationId']?.toString();
    if (consultationId == null || consultationId.isEmpty) {
      consoleLog('[ConsultationQR] Missing consultationId; navigating without finalize.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Missing consultationId; cannot finalize.')),
        );
      }
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/consultation-complete',
        arguments: requestData,
      );
      return;
    }

    consoleLog('[ConsultationQR] Finalizing consultationId=$consultationId');

    setState(() {
      _isCompleting = true;
    });

    try {
      await ConsultationsApi().devAutoCompleteConsultation(
        consultationId: consultationId,
        diagnosis: 'Auto diagnosis',
        treatment: 'Auto treatment',
        clinicalNotes: 'Completed from Flutter QR dev flow',
      );

      consoleLog('[ConsultationQR] Auto-complete succeeded. Fetching latest consultation...');

      final Consultation latest = await ConsultationsApi().getConsultation(
        consultationId: consultationId,
      );

      consoleLog('[ConsultationQR] Latest status=${latest.status}');

      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/consultation-complete',
        arguments: {
          ...requestData,
          'consultationId': consultationId,
          'consultation': latest,
        },
      );
    } catch (e, st) {
      consoleLog('[ConsultationQR] Auto-complete failed: $e');
      consoleLog('[ConsultationQR] Auto-complete stack: $st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Finalize failed: ${apiErrorMessage(e)}')),
        );
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _isCompleting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientName = requestData['patientName'] ?? 'Patient';
    final patientId = requestData['patientId'] ?? 'unknown';
    final consultationId = requestData['consultationId']?.toString();
    
    // Generate QR data with consultation info (preferred)
    final qrData = (consultationId != null && consultationId.isNotEmpty)
        ? 'OMNICARE_CONSULTATION:$consultationId'
        : 'OMNICARE_PATIENT:$patientId:$patientName';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A202C)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Consultation en Cours',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A202C),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_isCompleting)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Finalizing consultation...',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF667085),
                  ),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildStatusCard(),
                    const SizedBox(height: 20),
                    _buildQRCard(qrData, patientName),
                    const SizedBox(height: 20),
                    _buildInstructionsCard(),
                  ],
                ),
              ),
            ),
            _buildBottomButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1FBF9A), Color(0xFF0F6F73)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1FBF9A).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
              Icons.medical_services,
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
                  'Le médecin est arrivé',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Consultation en cours',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRCard(String qrData, String patientName) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
          Text(
            'Votre Code QR',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A202C),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Présentez ce code au médecin',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: const Color(0xFF667085),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF1FBF9A).withOpacity(0.3),
                width: 2,
              ),
            ),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1A202C),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1FBF9A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.person,
                  color: Color(0xFF0F6F73),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  patientName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F6F73),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withOpacity(0.05),
        border: Border.all(
          color: const Color(0xFF3B82F6).withOpacity(0.2),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: Color(0xFF3B82F6),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Instructions',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A202C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInstructionItem(
            '1',
            'Montrez ce code QR au médecin',
          ),
          _buildInstructionItem(
            '2',
            'Le médecin scannera le code pour accéder à vos informations',
          ),
          _buildInstructionItem(
            '3',
            'Après la consultation, cliquez sur "Terminer la Consultation"',
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
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
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: const Color(0xFF667085),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isCompleting ? null : _completeAndNavigate,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1FBF9A),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Text(
                'Terminer la Consultation',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
