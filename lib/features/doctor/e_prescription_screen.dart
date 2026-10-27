import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Compatibility destination for legacy navigation only.
///
/// Prescription authoring, signing, Consultation completion, PDF rendering,
/// and verification QR generation intentionally do not live here. The active
/// Consultation detail is the only production prescription workspace.
class EPrescriptionScreen extends StatelessWidget {
  const EPrescriptionScreen({
    super.key,
    required this.patientData,
    this.consultationId,
  });

  final Map<String, dynamic> patientData;
  final String? consultationId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1D2939),
        elevation: 0,
        title: Text(
          'Prescription',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.medication_outlined,
                size: 48,
                color: Color(0xFF0F6F73),
              ),
              const SizedBox(height: 16),
              Text(
                'Use the active Consultation workspace',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1D2939),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Prescription drafts and signatures are stored by MRS from the active Consultation. Official documents and verification codes are not part of this milestone.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  height: 1.5,
                  color: const Color(0xFF667085),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.maybePop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1FBF9A),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Back to Consultation'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
