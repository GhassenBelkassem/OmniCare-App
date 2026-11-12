import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'consultation_finish_controller.dart';

class ConsultationFinishCard extends StatelessWidget {
  const ConsultationFinishCard({
    super.key,
    required this.controller,
    this.onResolve,
  });
  final ConsultationFinishController controller;
  final ValueChanged<String>? onResolve;

  @override
  Widget build(BuildContext context) {
    final status = controller.consultation?.status ?? 'IN_PROGRESS';
    final complete = status == 'COMPLETED';
    final finalizing = status == 'FINALIZING';
    return Container(
      width: double.infinity,
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
                : 'Review the minimum decisions and every conditional resource before finishing.',
          ),
          if (controller.failureCode != null) ...[
            const SizedBox(height: 12),
            Text(
              controller.failureCode == 'UNSAVED_CLINICAL_CHANGES'
                  ? 'Save clinical changes before finishing.'
                  : 'Finish readiness could not be verified. The authoritative state was preserved.',
              style: const TextStyle(color: Color(0xFFB42318)),
            ),
          ],
          if (!complete) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: controller.submitting || controller.reviewing
                    ? null
                    : finalizing
                    ? controller.finish
                    : () => _review(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1FBF9A),
                  foregroundColor: const Color(0xFF102A26),
                ),
                child: Text(
                  controller.reviewing
                      ? 'Checking…'
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

  Future<void> _review(BuildContext context) async {
    await controller.review();
    final readiness = controller.readiness;
    if (!context.mounted || readiness == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Finish review',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _row('Diagnosis', readiness.diagnosisReady),
              _row('Medication decision', readiness.medicationDecisionReady),
              _row('Prescription', readiness.prescriptionReady),
              _row('Orders', readiness.ordersReady),
              _row('Follow-up', readiness.followUpReady),
              _row('Documents', readiness.artifactsReady),
              if (!readiness.ready) ...[
                const SizedBox(height: 12),
                ...readiness.missing.map(
                  (code) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _missing(code),
                            style: const TextStyle(color: Color(0xFFB42318)),
                          ),
                        ),
                        if (onResolve != null)
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              WidgetsBinding.instance.addPostFrameCallback(
                                (_) => onResolve!(code),
                              );
                            },
                            child: const Text('Open'),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: readiness.ready
                      ? () async {
                          Navigator.pop(context);
                          await controller.finish();
                        }
                      : null,
                  child: const Text('Finish consultation'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, bool ready) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      ready ? Icons.check_circle_outline : Icons.error_outline,
      color: ready ? const Color(0xFF067647) : const Color(0xFFB54708),
    ),
    title: Text(label),
    trailing: Text(ready ? 'Ready' : 'Required'),
  );

  String _missing(String code) => switch (code) {
    'CLINICAL_RECORD_MISSING' => 'Save the clinical record.',
    'DIAGNOSIS' => 'Diagnosis or conclusion is required.',
    'MEDICATION_DECISION' => 'Medication decision is required.',
    'FOLLOW_UP_DECISION' => 'Follow-up decision is required.',
    'PRESCRIPTION_NOT_FINALIZED' => 'Finalize and sign the prescription.',
    'PRESCRIPTION_CONTRADICTS_DECISION' =>
      'Prescription conflicts with the medication decision.',
    'ORDER_NOT_FINALIZED' => 'Finalize draft orders.',
    'ARTIFACT_NOT_FINALIZED' => 'Finalize draft official documents.',
    _ => 'Review an incomplete consultation item.',
  };
}
