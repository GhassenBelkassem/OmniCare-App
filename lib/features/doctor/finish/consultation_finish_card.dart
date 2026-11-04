import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'consultation_finish_controller.dart';

class ConsultationFinishCard extends StatelessWidget {
  const ConsultationFinishCard({super.key, required this.controller});
  final ConsultationFinishController controller;
  @override
  Widget build(BuildContext context) {
    final status = controller.consultation?.status ?? 'IN_PROGRESS';
    final complete = status == 'COMPLETED';
    final finalizing = status == 'FINALIZING';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            complete
                ? 'Consultation completed'
                : finalizing
                ? 'Finalizing consultation'
                : 'Finish consultation',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1D2939),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            complete
                ? 'Official documents may continue rendering in the background.'
                : finalizing
                ? 'Clinical editing is locked. Retry safely resumes the durable operation.'
                : 'The server validates the saved clinical record, orders, prescription, and artifact definitions.',
          ),
          if (controller.failureCode != null) ...[
            const SizedBox(height: 12),
            Text(
              controller.failureCode == 'UNSAVED_CLINICAL_CHANGES'
                  ? 'Save clinical changes before finishing.'
                  : controller.failureCode == 'CONSULTATION_NOT_READY_TO_FINISH'
                  ? 'The Consultation is not ready. Review missing decisions and drafts.'
                  : 'Finish did not complete. The authoritative state was refreshed.',
              style: const TextStyle(color: Color(0xFFB42318)),
            ),
          ],
          if (!complete) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: controller.submitting ? null : controller.finish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1FBF9A),
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  controller.submitting
                      ? 'Finalizing…'
                      : finalizing
                      ? 'Resume finalization'
                      : 'Finish consultation',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
