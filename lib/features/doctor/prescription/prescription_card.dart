import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/app_http_client.dart';
import '../../../core/utils/uuid_v4.dart';
import '../../scheduled_care/realtime/scheduled_care_realtime_coordinator.dart';
import 'prescription.dart';
import 'prescription_api.dart';
import 'prescription_controller.dart';

class PrescriptionCard extends StatefulWidget {
  const PrescriptionCard({super.key, required this.consultationId});
  final String consultationId;
  @override
  State<PrescriptionCard> createState() => _PrescriptionCardState();
}

class _PrescriptionCardState extends State<PrescriptionCard> {
  PrescriptionController? _controller;
  PrescriptionRealtimeTarget? _target;
  VoidCallback? _unregister;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final controller = PrescriptionController(
      consultationId: widget.consultationId,
      api: PrescriptionApi(context.read<AppHttpClient>()),
    )..addListener(_changed);
    _controller = controller;
    final coordinator = context.read<ScheduledCareRealtimeCoordinator?>();
    if (coordinator != null) {
      _target = PrescriptionRealtimeTarget(controller);
      _unregister = coordinator.registerTarget(_target!);
    }
    controller.load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _unregister?.call();
    _target?.dispose();
    _controller
      ?..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null ||
        controller.isLoading && controller.authoritative == null) {
      return const _Surface(child: Center(child: CircularProgressIndicator()));
    }
    if (controller.authoritative == null) {
      return _Surface(
        child: Column(
          children: [
            const Text('Prescription temporarily unavailable.'),
            OutlinedButton(
              onPressed: controller.load,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    final current = controller.authoritative!;
    final readOnly = current.finalized;
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Prescription',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              Text('v${current.prescriptionVersion}'),
            ],
          ),
          Text(
            readOnly
                ? 'Finalized and signed'
                : controller.isSaving
                ? 'Saving…'
                : controller.dirty
                ? 'Unsaved changes'
                : 'Saved',
          ),
          const SizedBox(height: 8),
          Text(
            'Medication decision: ${current.medicationDecision ?? 'not selected'}',
          ),
          if (controller.failureCode != null ||
              controller.newerVersionAvailable)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _failure(controller),
                style: const TextStyle(color: Color(0xFFB42318)),
              ),
            ),
          const SizedBox(height: 12),
          ...controller.draft.medications.asMap().entries.map(
            (entry) => _MedicationEditor(
              index: entry.key,
              medication: entry.value,
              readOnly: readOnly,
              changed: () => controller.update((_) {}),
              remove: () => controller.update(
                (draft) => draft.medications.removeAt(entry.key),
              ),
            ),
          ),
          if (!readOnly)
            OutlinedButton.icon(
              onPressed: () => controller.update(
                (draft) => draft.medications.add(
                  PrescriptionMedication(itemId: generateUuidV4()),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add medication'),
            ),
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey('${current.prescriptionVersion}-general'),
            initialValue: controller.draft.generalInstructions ?? '',
            enabled: !readOnly,
            decoration: _decoration('General instructions'),
            maxLines: 2,
            onChanged: (value) => controller.update(
              (draft) =>
                  draft.generalInstructions = nullablePrescriptionText(value),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (controller.conflict || controller.newerVersionAvailable)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => controller.load(force: true),
                    child: const Text('Reload MRS version'),
                  ),
                ),
              if (!readOnly) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        controller.dirty &&
                            current.medicationDecision ==
                                'MEDICATION_PRESCRIBED'
                        ? controller.save
                        : null,
                    child: const Text('Save'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        !controller.dirty &&
                            current.prescriptionVersion > 0 &&
                            current.medicationDecision ==
                                'MEDICATION_PRESCRIBED' &&
                            !controller.isFinalizing
                        ? () => _confirmFinalize(controller)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1FBF9A),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Finalize & sign'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmFinalize(PrescriptionController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalize prescription?'),
        content: const Text(
          'The signed clinical content will become immutable.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Finalize'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.finalize();
    }
  }

  String _failure(PrescriptionController value) {
    if (value.newerVersionAvailable) {
      return 'A newer version is available. Your local draft was preserved.';
    }
    return switch (value.failureCode) {
      'PRESCRIPTION_SIGNING_UNAVAILABLE' =>
        'Signing is unavailable. The prescription remains a draft.',
      'MEDICATION_DECISION_REQUIRED' =>
        'Save “Medication prescribed” in the clinical record first.',
      'PRESCRIPTION_VERSION_CONFLICT' || 'CLINICAL_RECORD_VERSION_CONFLICT' =>
        'Another device changed the clinical state. Reload and review.',
      _ => 'The operation failed. Your draft remains in memory.',
    };
  }
}

class _MedicationEditor extends StatelessWidget {
  const _MedicationEditor({
    required this.index,
    required this.medication,
    required this.readOnly,
    required this.changed,
    required this.remove,
  });
  final int index;
  final PrescriptionMedication medication;
  final bool readOnly;
  final VoidCallback changed, remove;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: const Color(0xFFE2E8F0)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      children: [
        Text(
          'Medication ${index + 1}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        _field('Name', medication.name, (v) {
          medication.name = nullablePrescriptionText(v);
          changed();
        }),
        Row(
          children: [
            Expanded(
              child: _field('Medication code', medication.medicationCode, (v) {
                medication.medicationCode = nullablePrescriptionText(v);
                changed();
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _field('Strength', medication.strength, (v) {
                medication.strength = nullablePrescriptionText(v);
                changed();
              }),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _field('Dose', medication.doseAmount.toString(), (v) {
                medication.doseAmount = double.tryParse(v) ?? 0;
                changed();
              }, number: true),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _field('Unit', medication.doseUnit, (v) {
                medication.doseUnit = v;
                changed();
              }),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _field('Route', medication.route, (v) {
                medication.route = v;
                changed();
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _field(
                'Times/day',
                medication.timesPerDay?.toString() ?? '',
                (v) {
                  medication.timesPerDay = int.tryParse(v);
                  if (medication.timesPerDay != null) {
                    medication.frequencyText = null;
                  }
                  changed();
                },
                number: true,
              ),
            ),
          ],
        ),
        _field('Frequency text', medication.frequencyText, (v) {
          medication.frequencyText = nullablePrescriptionText(v);
          if (medication.frequencyText != null) {
            medication.timesPerDay = null;
          }
          changed();
        }),
        Row(
          children: [
            Expanded(
              child: _field('Duration', medication.durationValue?.toString(), (
                v,
              ) {
                medication.durationValue = int.tryParse(v);
                medication.durationUnit = medication.durationValue == null
                    ? null
                    : medication.durationUnit ?? 'DAY';
                changed();
              }, number: true),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: DropdownButtonFormField<String>(
                  initialValue: medication.durationUnit ?? 'DAY',
                  decoration: _decoration('Duration unit'),
                  items: const [
                    DropdownMenuItem(value: 'DAY', child: Text('Day')),
                    DropdownMenuItem(value: 'WEEK', child: Text('Week')),
                    DropdownMenuItem(value: 'MONTH', child: Text('Month')),
                  ],
                  onChanged: readOnly || medication.durationValue == null
                      ? null
                      : (value) {
                          medication.durationUnit = value;
                          changed();
                        },
                ),
              ),
            ),
          ],
        ),
        _field('Quantity', medication.quantity?.toString(), (v) {
          medication.quantity = int.tryParse(v);
          changed();
        }, number: true),
        _field('Instructions', medication.instructions, (v) {
          medication.instructions = nullablePrescriptionText(v);
          changed();
        }, lines: 2),
        if (!readOnly)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: remove, child: const Text('Remove')),
          ),
      ],
    ),
  );
  Widget _field(
    String label,
    String? value,
    ValueChanged<String> onChanged, {
    bool number = false,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: TextFormField(
      initialValue: value ?? '',
      enabled: !readOnly,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      maxLines: lines,
      decoration: _decoration(label),
      onChanged: onChanged,
    ),
  );
}

InputDecoration _decoration(String label) => InputDecoration(
  labelText: label,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
);

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
