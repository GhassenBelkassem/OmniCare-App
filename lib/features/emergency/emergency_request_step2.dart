import 'package:flutter/material.dart';

import '../../core/theme/omni_theme.dart';
import 'emergency_symptom_intake_value.dart';
import 'widgets/body_map_widget.dart';
import 'widgets/medical_intake_widgets.dart';
import 'widgets/specialty_assistant_card.dart';
import 'urgent_flow_mode.dart';

class EmergencyRequestStep2 extends StatefulWidget {
  const EmergencyRequestStep2({
    super.key,
    required this.step1Data,
    this.flowMode = UrgentFlowMode.create,
    this.onCompleted,
    this.maxDescriptionCharacters,
    this.requireExplicitPainSelection = false,
  });
  final Map<String, dynamic> step1Data;
  final UrgentFlowMode flowMode;
  final ValueChanged<EmergencySymptomIntakeValue>? onCompleted;
  final int? maxDescriptionCharacters;
  final bool requireExplicitPainSelection;

  @override
  State<EmergencyRequestStep2> createState() => _EmergencyRequestStep2State();
}

class _EmergencyRequestStep2State extends State<EmergencyRequestStep2>
    with WidgetsBindingObserver {
  List<String> _selectedBodyParts = const [];
  final _descriptionController = TextEditingController();
  final _descriptionKey = GlobalKey();
  double _painLevel = 5;
  bool _painWasExplicitlySelected = false;
  bool _shareMedicalRecord = false;

  bool get _canProceed =>
      _selectedBodyParts.isNotEmpty &&
      _descriptionController.text.trim().isNotEmpty &&
      (!widget.requireExplicitPainSelection || _painWasExplicitlySelected) &&
      _descriptionWithinLimit;

  bool get _descriptionWithinLimit {
    final maximum = widget.maxDescriptionCharacters;
    return maximum == null ||
        _descriptionController.text.trim().runes.length <= maximum;
  }

  @override
  void initState() {
    super.initState();
    final bodyParts = widget.step1Data['bodyParts'];
    _selectedBodyParts = bodyParts is List
        ? List<String>.unmodifiable(bodyParts.map((part) => part.toString()))
        : const [];
    _descriptionController.text =
        (widget.step1Data['description'] ?? widget.step1Data['symptoms'] ?? '')
            .toString();
    _painLevel = (widget.step1Data['painLevel'] as num?)?.toDouble() ?? 5;
    _painWasExplicitlySelected = widget.step1Data['painLevel'] is num;
    _shareMedicalRecord = widget.step1Data['shareMedicalRecord'] == true;
    WidgetsBinding.instance.addObserver(this);
    _descriptionController.addListener(_descriptionChanged);
  }

  void _descriptionChanged() => setState(() {});

  @override
  void didChangeMetrics() {
    // The patient shell removes MediaQuery bottom insets. Read the view's
    // actual keyboard inset locally without changing either fixed app nav.
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || View.of(context).viewInsets.bottom == 0) return;
      final descriptionContext = _descriptionKey.currentContext;
      if (descriptionContext != null) {
        Scrollable.ensureVisible(descriptionContext, alignment: 0.1);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _descriptionController.dispose();
    super.dispose();
  }

  void _toggleBodyPart(String part) => setState(() {
    _selectedBodyParts = List<String>.unmodifiable(
      _selectedBodyParts.contains(part)
          ? _selectedBodyParts.where((value) => value != part)
          : [..._selectedBodyParts, part],
    );
  });

  void _handleNext() {
    if (!_canProceed) return;
    final description = _descriptionController.text.trim();
    final data = {
      ...widget.step1Data,
      'bodyParts': List<String>.from(_selectedBodyParts),
      'painLevel': _painLevel.round(),
      'description': description,
      // Legacy review expects a string. Keep the same narrative in both keys.
      'symptoms': description,
      'voiceMessage': null,
      'shareMedicalRecord': _shareMedicalRecord,
    };
    final onCompleted = widget.onCompleted;
    if (onCompleted != null) {
      onCompleted(
        EmergencySymptomIntakeValue(
          rawAnatomicalRegionIds: _selectedBodyParts,
          painScore: _painLevel.round(),
          shortDescription: description,
        ),
      );
      return;
    }
    if (widget.flowMode == UrgentFlowMode.editFromReview) {
      Navigator.pop(context, data);
      return;
    }
    Navigator.pushNamed(context, '/emergency-step3', arguments: data);
  }

  @override
  Widget build(BuildContext context) {
    final view = View.of(context);
    final keyboardInset = view.viewInsets.bottom / view.devicePixelRatio;
    return ColoredBox(
      key: const ValueKey('emergency-step2-page-surface'),
      color: OmniColors.pageBackground,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Retour',
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  Expanded(
                    child: Text(
                      'Demande urgente',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: OmniColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: const ValueKey('emergency-step2-scroll'),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  OmniSpacing.pageHorizontal,
                  OmniSpacing.base,
                  OmniSpacing.pageHorizontal,
                  OmniSpacing.xxl + keyboardInset,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 840),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Où avez-vous mal ?',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: OmniColors.textPrimary,
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                height: 1.15,
                                letterSpacing: -0.5,
                              ),
                        ),
                        const SizedBox(height: OmniSpacing.sm),
                        Text(
                          'Sélectionnez une ou plusieurs zones du corps.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: OmniColors.textSecondary,
                                fontSize: 14,
                                height: 1.5,
                              ),
                        ),
                        const SizedBox(height: OmniSpacing.xl),
                        if (_selectedBodyParts.isNotEmpty) ...[
                          SelectedBodyAreasPanel(
                            key: const ValueKey('emergency-selected-areas'),
                            parts: _selectedBodyParts,
                            onRemove: (part) => setState(() {
                              _selectedBodyParts = List<String>.unmodifiable(
                                _selectedBodyParts.where(
                                  (value) => value != part,
                                ),
                              );
                            }),
                            onReset: () =>
                                setState(() => _selectedBodyParts = const []),
                          ),
                          const SizedBox(height: OmniSpacing.base),
                        ],
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final front = MuscleAnatomyMap(
                              isFront: true,
                              selectedParts: _selectedBodyParts,
                              onPartClick: _toggleBodyPart,
                            );
                            final back = MuscleAnatomyMap(
                              isFront: false,
                              selectedParts: _selectedBodyParts,
                              onPartClick: _toggleBodyPart,
                            );
                            if (constraints.maxWidth >= 720) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: front),
                                  const SizedBox(width: OmniSpacing.base),
                                  Expanded(child: back),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                front,
                                const SizedBox(height: OmniSpacing.md),
                                back,
                              ],
                            );
                          },
                        ),
                        const _SectionDivider(),
                        PainLevelControl(
                          value: _painLevel,
                          onChanged: (value) => setState(() {
                            _painLevel = value;
                            _painWasExplicitlySelected = true;
                          }),
                        ),
                        const _SectionDivider(),
                        SymptomDescriptionCard(
                          key: _descriptionKey,
                          controller: _descriptionController,
                        ),
                        const SizedBox(height: OmniSpacing.xl),
                        MedicalPassportToggle(
                          value: _shareMedicalRecord,
                          onChanged: (value) =>
                              setState(() => _shareMedicalRecord = value),
                        ),
                        const SizedBox(height: OmniSpacing.base),
                        SpecialtyAssistantCard(
                          areas: _selectedBodyParts,
                          description: _descriptionController.text,
                        ),
                        const SizedBox(height: OmniSpacing.base),
                        const _InstructionsPanel(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _ContinueFooter(onPressed: _canProceed ? _handleNext : null),
          ],
        ),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: OmniSpacing.lg),
    child: Divider(height: 1, color: OmniColors.borderLight),
  );
}

class _InstructionsPanel extends StatelessWidget {
  const _InstructionsPanel();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(OmniSpacing.base),
    decoration: BoxDecoration(
      color: OmniColors.surfaceSecondary,
      borderRadius: BorderRadius.circular(OmniRadii.card),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Instructions',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: OmniColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: OmniSpacing.sm),
        Text(
          'Sélectionnez une ou plusieurs zones et décrivez brièvement vos symptômes. Les suggestions de spécialité sont indicatives.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: OmniColors.textSecondary,
            fontSize: 13,
            height: 1.45,
          ),
        ),
        const SizedBox(height: OmniSpacing.sm),
        Text(
          'Urgence vitale ? Appelez le SAMU 190',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: OmniColors.urgentCoral,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _ContinueFooter extends StatelessWidget {
  const _ContinueFooter({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: OmniColors.surfacePrimary,
      border: Border(top: BorderSide(color: OmniColors.borderLight)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          OmniSpacing.pageHorizontal,
          OmniSpacing.md,
          OmniSpacing.pageHorizontal,
          OmniSpacing.md,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                key: const ValueKey('emergency-continue'),
                onPressed: onPressed,
                child: const Text('Continuer'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
