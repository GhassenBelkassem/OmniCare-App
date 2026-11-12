import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/network/app_http_client.dart';
import '../../../core/utils/uuid_v4.dart';
import '../../scheduled_care/realtime/scheduled_care_realtime_coordinator.dart';
import 'prescription.dart';
import 'prescription_api.dart';
import 'prescription_controller.dart';

class PrescriptionCard extends StatefulWidget {
  const PrescriptionCard({
    super.key,
    required this.consultationId,
    this.isActive,
  });
  final String consultationId;
  final bool Function()? isActive;
  @override
  State<PrescriptionCard> createState() => _PrescriptionCardState();
}

class _PrescriptionCardState extends State<PrescriptionCard> {
  PrescriptionController? _controller;
  PrescriptionRealtimeTarget? _target;
  VoidCallback? _unregister;
  final FocusNode _newMedicationFocus = FocusNode();
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
      _target = PrescriptionRealtimeTarget(
        controller,
        isWorkspaceActive: widget.isActive,
      );
      _unregister = coordinator.registerTarget(_target!);
    }
    if (widget.isActive?.call() ?? true) controller.load();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _addMedication(PrescriptionController controller) {
    FocusManager.instance.primaryFocus?.unfocus();
    controller.update(
      (draft) => draft.medications.add(
        PrescriptionMedication(itemId: generateUuidV4()),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _newMedicationFocus.requestFocus();
    });
  }

  void _removeMedication(PrescriptionController controller, int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    controller.update((draft) => draft.medications.removeAt(index));
  }

  Future<void> _save(PrescriptionController controller) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await controller.save();
  }

  @override
  void dispose() {
    _controller?.removeListener(_changed);
    _target?.dispose();
    _unregister?.call();
    _controller?.dispose();
    _newMedicationFocus.dispose();
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
              nameFocusNode:
                  entry.key == controller.draft.medications.length - 1
                  ? _newMedicationFocus
                  : null,
              changed: () => controller.update((_) {}),
              remove: () => _removeMedication(controller, entry.key),
            ),
          ),
          if (!readOnly)
            OutlinedButton.icon(
              onPressed: () => _addMedication(controller),
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
                        ? () => _save(controller)
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
    required this.nameFocusNode,
    required this.changed,
    required this.remove,
  });
  final int index;
  final PrescriptionMedication medication;
  final bool readOnly;
  final FocusNode? nameFocusNode;
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
        _field('Medication', medication.name, (v) {
          medication.name = nullablePrescriptionText(v);
          changed();
        }, focusNode: nameFocusNode),
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
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            children: [1, 2, 3]
                .map(
                  (times) => ChoiceChip(
                    label: Text('${times}x/day'),
                    selected: medication.timesPerDay == times,
                    onSelected: readOnly
                        ? null
                        : (_) {
                            medication.timesPerDay = times;
                            medication.frequencyText = null;
                            _deriveQuantity();
                            changed();
                          },
                  ),
                )
                .toList(growable: false),
          ),
        ),
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
                  isExpanded: true,
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
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            children: [3, 5, 7, 10]
                .map(
                  (days) => ChoiceChip(
                    label: Text('$days days'),
                    selected:
                        medication.durationUnit == 'DAY' &&
                        medication.durationValue == days,
                    onSelected: readOnly
                        ? null
                        : (_) {
                            medication.durationValue = days;
                            medication.durationUnit = 'DAY';
                            _deriveQuantity();
                            changed();
                          },
                  ),
                )
                .toList(growable: false),
          ),
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
    FocusNode? focusNode,
  }) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: TextFormField(
      initialValue: value ?? '',
      enabled: !readOnly,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      maxLines: lines,
      focusNode: focusNode,
      decoration: _decoration(label),
      onChanged: onChanged,
    ),
  );

  void _deriveQuantity() {
    final times = medication.timesPerDay;
    final days = medication.durationUnit == 'DAY'
        ? medication.durationValue
        : null;
    if (times == null || days == null) return;
    final quantity = medication.doseAmount * times * days;
    if (quantity == quantity.roundToDouble()) {
      medication.quantity = quantity.toInt();
    }
  }
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
