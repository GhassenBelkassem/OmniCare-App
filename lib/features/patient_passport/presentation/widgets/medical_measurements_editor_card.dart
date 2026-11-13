import 'package:flutter/material.dart';

import '../../../../core/theme/omni_theme.dart';

const _bmiValueGreen = Color(0xFF10C98F);
const _bmiBlue = Color(0xFFC2E5FC);
const _bmiGreen = Color(0xFFB6F2D2);
const _bmiYellow = Color(0xFFFAE792);
const _bmiPink = Color(0xFFF7CCCB);
const _statusGreen = Color(0xFF5BBC9C);

class MedicalMeasurementsEditorCard extends StatelessWidget {
  final TextEditingController heightController;
  final TextEditingController weightController;

  /// `null` without both values: no number and no category is shown.
  final double? bmi;

  /// The computed category text (G2.1-A2); `null` hides the pill.
  final String? bmiCategory;
  final String? heightError;
  final String? weightError;
  final ValueChanged<String> onHeightChanged;
  final ValueChanged<String> onWeightChanged;

  const MedicalMeasurementsEditorCard({
    super.key,
    required this.heightController,
    required this.weightController,
    required this.bmi,
    required this.bmiCategory,
    required this.onHeightChanged,
    required this.onWeightChanged,
    this.heightError,
    this.weightError,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.circular(OmniRadii.sheet),
        border: Border.all(color: OmniColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: OmniColors.mintSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.speed_rounded,
                  color: OmniColors.freshMint,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Taille, Poids & IMC',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: OmniColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _MeasurementInput(
                  icon: Icons.straighten_outlined,
                  label: 'Taille',
                  unit: 'cm',
                  controller: heightController,
                  errorText: heightError,
                  onChanged: onHeightChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MeasurementInput(
                  icon: Icons.scale_outlined,
                  label: 'Poids',
                  unit: 'kg',
                  controller: weightController,
                  errorText: weightError,
                  onChanged: onWeightChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _BmiPanel(bmi: bmi, category: bmiCategory),
        ],
      ),
    );
  }
}

class _MeasurementInput extends StatelessWidget {
  final IconData icon;
  final String label;
  final String unit;
  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String> onChanged;

  const _MeasurementInput({
    required this.icon,
    required this.label,
    required this.unit,
    required this.controller,
    required this.errorText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 17, color: OmniColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: OmniColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        SizedBox(
          height: errorText == null ? 52 : null,
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: onChanged,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: OmniColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              isDense: true,
              errorText: errorText,
              errorMaxLines: 3,
              suffixText: unit,
              suffixStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: OmniColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 13),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: OmniColors.borderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: OmniColors.borderFocus,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BmiPanel extends StatelessWidget {
  final double? bmi;
  final String? category;

  const _BmiPanel({required this.bmi, required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OmniColors.borderLight),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _bmiValueGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  bmi?.toStringAsFixed(1) ?? '',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'IMC',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: OmniColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Calculé automatiquement',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: OmniColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (category case final category?)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: OmniColors.mintSoft,
                    borderRadius: BorderRadius.circular(OmniRadii.pill),
                    border: Border.all(color: _statusGreen),
                  ),
                  child: Text(
                    category,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: _statusGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _BmiScale(bmi: bmi),
        ],
      ),
    );
  }
}

class _BmiScale extends StatelessWidget {
  final double? bmi;

  const _BmiScale({required this.bmi});

  @override
  Widget build(BuildContext context) {
    final bmi = this.bmi;
    final normalized = bmi == null
        ? 0.0
        : ((bmi - 15) / 25).clamp(0.0, 1.0).toDouble();

    return Column(
      children: [
        SizedBox(
          height: 16,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final markerLeft = (normalized * (constraints.maxWidth - 10))
                  .clamp(0.0, constraints.maxWidth - 10)
                  .toDouble();
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(OmniRadii.pill),
                      child: const SizedBox(
                        height: 8,
                        child: Row(
                          children: [
                            Expanded(
                              flex: 45,
                              child: ColoredBox(color: _bmiBlue),
                            ),
                            Expanded(
                              flex: 18,
                              child: ColoredBox(color: _bmiGreen),
                            ),
                            Expanded(
                              flex: 13,
                              child: ColoredBox(color: _bmiYellow),
                            ),
                            Expanded(
                              flex: 24,
                              child: ColoredBox(color: _bmiPink),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (bmi != null)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      left: markerLeft,
                      top: 0,
                      child: Container(
                        width: 10,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: _statusGreen, width: 1.5),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            _ScaleLabel('18.5'),
            _ScaleLabel('25'),
            _ScaleLabel('30'),
            _ScaleLabel('40+'),
          ],
        ),
      ],
    );
  }
}

class _ScaleLabel extends StatelessWidget {
  final String label;

  const _ScaleLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: OmniColors.textTertiary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
