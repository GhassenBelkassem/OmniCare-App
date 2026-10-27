import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/network/app_http_client.dart';
import '../../scheduled_care/realtime/scheduled_care_realtime_coordinator.dart';
import 'clinical_record.dart';
import 'clinical_record_api.dart';
import 'clinical_record_controller.dart';

class ClinicalAuthoringCard extends StatefulWidget {
  const ClinicalAuthoringCard({
    super.key,
    required this.consultationId,
    this.controller,
  });
  final String consultationId;
  final ClinicalRecordController? controller;

  @override
  State<ClinicalAuthoringCard> createState() => _ClinicalAuthoringCardState();
}

class _ClinicalAuthoringCardState extends State<ClinicalAuthoringCard> {
  ClinicalRecordController? _controller;
  ClinicalRecordRealtimeTarget? _target;
  VoidCallback? _unregister;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final controller =
        widget.controller ??
        ClinicalRecordController(
          consultationId: widget.consultationId,
          api: ClinicalRecordApi(context.read<AppHttpClient>()),
        );
    controller.addListener(_changed);
    _controller = controller;
    final coordinator = context.read<ScheduledCareRealtimeCoordinator?>();
    if (coordinator != null) {
      _target = ClinicalRecordRealtimeTarget(controller);
      _unregister = coordinator.registerTarget(_target!);
    }
    if (controller.authoritative == null) controller.load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _unregister?.call();
    _target?.dispose();
    _controller?.removeListener(_changed);
    if (widget.controller == null) _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null ||
        (controller.isLoading && controller.authoritative == null)) {
      return const _Surface(child: Center(child: CircularProgressIndicator()));
    }
    if (controller.authoritative == null) {
      return _Surface(
        child: Column(
          children: [
            const Text('Clinical record temporarily unavailable.'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: controller.load,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    final draft = controller.draft;
    return _Surface(
      child: KeyedSubtree(
        key: ValueKey(controller.authoritative!.clinicalRecordVersion),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Clinical authoring', style: _heading())),
                Text(
                  'v${controller.authoritative!.clinicalRecordVersion}',
                  style: _label(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              controller.isSaving
                  ? 'Saving…'
                  : controller.conflict
                  ? 'Version conflict'
                  : controller.dirty
                  ? 'Unsaved changes'
                  : 'Saved',
              style: _label(),
            ),
            if (controller.newerVersionAvailable ||
                controller.failureCode != null) ...[
              const SizedBox(height: 12),
              Text(
                controller.conflict
                    ? 'This record changed on another device. Your local edits are preserved.'
                    : controller.newerVersionAvailable
                    ? 'A newer version is available. Your local edits were not replaced.'
                    : 'Save failed. Your draft remains in memory.',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFFB42318),
                ),
              ),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: draft.medicationDecision,
              decoration: _decoration('Medication decision'),
              items: const [
                DropdownMenuItem(
                  value: 'MEDICATION_PRESCRIBED',
                  child: Text('Medication prescribed'),
                ),
                DropdownMenuItem(
                  value: 'NO_MEDICATION',
                  child: Text('No medication'),
                ),
              ],
              onChanged: (value) =>
                  controller.update((d) => d.medicationDecision = value),
            ),
            const SizedBox(height: 12),
            _text(
              'Chief complaint',
              draft.chiefComplaint,
              (v) => controller.update(
                (d) => d.chiefComplaint = nullableClinicalText(v),
              ),
              maxLines: 2,
            ),
            _text(
              'Present illness',
              draft.presentIllness,
              (v) => controller.update(
                (d) => d.presentIllness = nullableClinicalText(v),
              ),
            ),
            _text(
              'Relevant medical history',
              draft.relevantMedicalHistory,
              (v) => controller.update(
                (d) => d.relevantMedicalHistory = nullableClinicalText(v),
              ),
            ),
            _text(
              'Relevant dental history',
              draft.relevantDentalHistory,
              (v) => controller.update(
                (d) => d.relevantDentalHistory = nullableClinicalText(v),
              ),
            ),
            _text(
              'Finding type',
              draft.findingType,
              (v) => controller.update((d) => d.findingType = v),
              maxLines: 1,
            ),
            _text(
              'Clinical finding',
              draft.findingDescription,
              (v) => controller.update((d) => d.findingDescription = v),
            ),
            _text(
              'Diagnosis system',
              draft.diagnosisSystem,
              (v) => controller.update((d) => d.diagnosisSystem = v),
              maxLines: 1,
            ),
            _text(
              'Diagnosis code',
              draft.diagnosisCode,
              (v) => controller.update((d) => d.diagnosisCode = v),
              maxLines: 1,
            ),
            _text(
              'Diagnosis',
              draft.diagnosisLabel,
              (v) => controller.update((d) => d.diagnosisLabel = v),
              maxLines: 2,
            ),
            DropdownButtonFormField<String>(
              initialValue: draft.diagnosisStatus,
              decoration: _decoration('Diagnosis status'),
              items: const [
                DropdownMenuItem(
                  value: 'PROVISIONAL',
                  child: Text('Provisional'),
                ),
                DropdownMenuItem(value: 'CONFIRMED', child: Text('Confirmed')),
                DropdownMenuItem(value: 'RULED_OUT', child: Text('Ruled out')),
              ],
              onChanged: (value) {
                if (value != null) {
                  controller.update((d) => d.diagnosisStatus = value);
                }
              },
            ),
            const SizedBox(height: 12),
            _text(
              'Assessment',
              draft.assessment,
              (v) => controller.update(
                (d) => d.assessment = nullableClinicalText(v),
              ),
            ),
            _text(
              'Treatment plan (one item per line)',
              draft.treatmentPlan.join('\n'),
              (v) => controller.update(
                (d) => d.treatmentPlan = v
                    .split('\n')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList(),
              ),
            ),
            _text(
              'Clinical notes',
              draft.notes,
              (v) =>
                  controller.update((d) => d.notes = nullableClinicalText(v)),
            ),
            DropdownButtonFormField<String>(
              initialValue: draft.followUpDecision,
              decoration: _decoration('Follow-up decision'),
              items: const [
                DropdownMenuItem(
                  value: 'NO_FOLLOW_UP',
                  child: Text('No follow-up'),
                ),
                DropdownMenuItem(
                  value: 'FOLLOW_UP_IN_PERIOD',
                  child: Text('Follow-up in a period'),
                ),
                DropdownMenuItem(
                  value: 'FOLLOW_UP_AFTER_RESULTS',
                  child: Text('Follow-up after results'),
                ),
                DropdownMenuItem(
                  value: 'FOLLOW_UP_AS_NEEDED',
                  child: Text('Follow-up as needed'),
                ),
              ],
              onChanged: (value) => controller.update((d) {
                d.followUpDecision = value;
                d.followUpRequired = value != null && value != 'NO_FOLLOW_UP';
                if (value != 'FOLLOW_UP_IN_PERIOD') {
                  d.followUpRecommendedAt = null;
                }
              }),
            ),
            if (draft.followUpDecision == 'FOLLOW_UP_IN_PERIOD')
              _text(
                'Recommended date (YYYY-MM-DD)',
                draft.followUpRecommendedAt,
                (v) => controller.update(
                  (d) => d.followUpRecommendedAt = nullableClinicalText(v),
                ),
                maxLines: 1,
              ),
            const SizedBox(height: 8),
            Text(
              'The medication decision is canonical MRS clinical content. The prescription is stored separately.',
              style: _label(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (controller.conflict ||
                    controller.newerVersionAvailable) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => controller.load(force: true),
                      child: const Text('Reload MRS version'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: controller.dirty && !controller.isSaving
                        ? controller.save
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1FBF9A),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _text(
    String label,
    String? value,
    ValueChanged<String> changed, {
    int maxLines = 3,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      initialValue: value ?? '',
      maxLines: maxLines,
      decoration: _decoration(label),
      onChanged: changed,
    ),
  );

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );

  TextStyle _heading() => GoogleFonts.plusJakartaSans(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: const Color(0xFF1D2939),
  );
  TextStyle _label() =>
      GoogleFonts.plusJakartaSans(fontSize: 13, color: const Color(0xFF667085));
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );
}
