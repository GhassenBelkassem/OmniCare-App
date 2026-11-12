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
    this.isActive,
    this.onAction,
  });
  final String consultationId;
  final ClinicalRecordController? controller;
  final bool Function()? isActive;
  final ValueChanged<String>? onAction;

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
    final realtime = context.read<ScheduledCareRealtimeCoordinator?>();
    if (realtime != null) {
      _target = ClinicalRecordRealtimeTarget(
        controller,
        isWorkspaceActive: widget.isActive,
      );
      _unregister = realtime.registerTarget(_target!);
    }
    if ((widget.isActive?.call() ?? true) && controller.authoritative == null) {
      controller.load();
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_changed);
    _target?.dispose();
    _unregister?.call();
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
                Expanded(
                  child: Text('Consultation in progress', style: _heading()),
                ),
                Text(
                  'v${controller.authoritative!.clinicalRecordVersion}',
                  style: _label(),
                ),
              ],
            ),
            Text(
              controller.isSaving
                  ? 'Saving…'
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
                style: const TextStyle(color: Color(0xFFB42318)),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('clinical-conclusion'),
              initialValue: draft.diagnosisLabel,
              maxLength: 500,
              textInputAction: TextInputAction.next,
              decoration: _decoration(
                'Diagnosis / clinical conclusion *',
                hint: 'Search or enter a diagnosis',
              ),
              onChanged: (value) => controller.update((d) {
                d.diagnosisLabel = value;
                if (d.diagnosisSystem.trim().isEmpty) {
                  d.diagnosisSystem = 'LOCAL';
                  d.diagnosisCode = '';
                }
              }),
            ),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Confirmed'),
                  selected: draft.diagnosisStatus == 'CONFIRMED',
                  onSelected: (_) =>
                      controller.update((d) => d.diagnosisStatus = 'CONFIRMED'),
                ),
                ChoiceChip(
                  label: const Text('Provisional'),
                  selected: draft.diagnosisStatus == 'PROVISIONAL',
                  onSelected: (_) => controller.update(
                    (d) => d.diagnosisStatus = 'PROVISIONAL',
                  ),
                ),
              ],
            ),
            if (draft.diagnosisStatus == 'RULED_OUT')
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Ruled-out history does not satisfy Finish. Select an active status.',
                  style: TextStyle(color: Color(0xFFB54708)),
                ),
              ),
            const SizedBox(height: 16),
            Text('Medication *', style: _section()),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('No medication'),
                  selected: draft.medicationDecision == 'NO_MEDICATION',
                  onSelected: (_) => controller.update(
                    (d) => d.medicationDecision = 'NO_MEDICATION',
                  ),
                ),
                ChoiceChip(
                  label: const Text('Prescribe'),
                  selected: draft.medicationDecision == 'MEDICATION_PRESCRIBED',
                  onSelected: (_) {
                    controller.update(
                      (d) => d.medicationDecision = 'MEDICATION_PRESCRIBED',
                    );
                    widget.onAction?.call('PRESCRIPTION');
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Actions', style: _section()),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('Prescription'),
                  onPressed: () => widget.onAction?.call('PRESCRIPTION'),
                ),
                ActionChip(
                  label: const Text('Laboratory'),
                  onPressed: () => widget.onAction?.call('LAB'),
                ),
                ActionChip(
                  label: const Text('Imaging'),
                  onPressed: () => widget.onAction?.call('IMAGING'),
                ),
                ActionChip(
                  label: const Text('Specialist'),
                  onPressed: () => widget.onAction?.call('REFERRAL'),
                ),
                ActionChip(
                  label: const Text('Medical certificate'),
                  onPressed: () => widget.onAction?.call('MEDICAL_CERTIFICATE'),
                ),
                ActionChip(
                  label: const Text('Sick leave'),
                  onPressed: () =>
                      widget.onAction?.call('SICK_LEAVE_CERTIFICATE'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Follow-up *', style: _section()),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _followUp(controller, 'NO_FOLLOW_UP', 'None'),
                _followUp(controller, 'FOLLOW_UP_AS_NEEDED', 'As needed'),
                _followUp(
                  controller,
                  'FOLLOW_UP_AFTER_RESULTS',
                  'After results',
                ),
                _followUp(controller, 'FOLLOW_UP_IN_PERIOD', 'In a period'),
              ],
            ),
            if (draft.followUpDecision == 'FOLLOW_UP_IN_PERIOD')
              _text(
                'Recommended date (YYYY-MM-DD)',
                draft.followUpRecommendedAt,
                (value) => controller.update(
                  (d) => d.followUpRecommendedAt = nullableClinicalText(value),
                ),
                lines: 1,
              ),
            const SizedBox(height: 8),
            ExpansionTile(
              key: const PageStorageKey('advanced-clinical-details'),
              tilePadding: EdgeInsets.zero,
              title: const Text('Add clinical details'),
              children: [
                _text(
                  'Chief complaint',
                  draft.chiefComplaint,
                  (v) => controller.update(
                    (d) => d.chiefComplaint = nullableClinicalText(v),
                  ),
                  lines: 2,
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
                  'Clinical findings',
                  draft.findingDescription,
                  (v) => controller.update((d) {
                    d.findingDescription = v;
                    if (v.trim().isNotEmpty && d.findingType.trim().isEmpty) {
                      d.findingType = 'EXAMINATION';
                    }
                  }),
                ),
                _text(
                  'Assessment',
                  draft.assessment,
                  (v) => controller.update(
                    (d) => d.assessment = nullableClinicalText(v),
                  ),
                ),
                _text(
                  'Plan / advice (one item per line)',
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
                  (v) => controller.update(
                    (d) => d.notes = nullableClinicalText(v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (controller.conflict ||
                    controller.newerVersionAvailable) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => controller.load(force: true),
                      child: const Text('Reload MRS'),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: controller.dirty && !controller.isSaving
                        ? controller.save
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1FBF9A),
                      foregroundColor: const Color(0xFF102A26),
                    ),
                    child: const Text('Save clinical record'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _followUp(
    ClinicalRecordController controller,
    String value,
    String label,
  ) {
    final selected = controller.draft.followUpDecision == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => controller.update((d) {
        d.followUpDecision = value;
        d.followUpRequired = value != 'NO_FOLLOW_UP';
        if (value != 'FOLLOW_UP_IN_PERIOD') d.followUpRecommendedAt = null;
      }),
    );
  }

  Widget _text(
    String label,
    String? value,
    ValueChanged<String> changed, {
    int lines = 3,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      initialValue: value ?? '',
      maxLines: lines,
      decoration: _decoration(label),
      onChanged: changed,
    ),
  );

  InputDecoration _decoration(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  );
  TextStyle _heading() => GoogleFonts.plusJakartaSans(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: const Color(0xFF1D2939),
  );
  TextStyle _section() => GoogleFonts.plusJakartaSans(
    fontSize: 14,
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
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );
}
