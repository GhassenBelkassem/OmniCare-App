import 'package:flutter/material.dart';

import '../../../../core/theme/omni_theme.dart';
import 'passport_card.dart';

class PassportMeasurementsCard extends StatelessWidget {
  final double heightCm;
  final double weightKg;

  const PassportMeasurementsCard({
    super.key,
    required this.heightCm,
    required this.weightKg,
  });

  @override
  Widget build(BuildContext context) {
    final heightMeters = heightCm / 100;
    final bmi = heightMeters > 0 ? weightKg / (heightMeters * heightMeters) : 0;

    return PassportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PassportSectionHeading(
            icon: Icons.straighten_outlined,
            title: 'Mesures Corporelles',
            subtitle: 'Données renseignées par vous',
            iconColor: OmniColors.violet,
            iconBackground: OmniColors.violetSoft,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _Measurement(
                  label: 'Taille',
                  value: _formatMeasurement(heightCm),
                  unit: 'cm',
                ),
              ),
              const _MeasurementDivider(),
              Expanded(
                child: _Measurement(
                  label: 'Poids',
                  value: _formatMeasurement(weightKg),
                  unit: 'kg',
                ),
              ),
              const _MeasurementDivider(),
              Expanded(
                child: _Measurement(
                  label: 'IMC',
                  value: bmi.toStringAsFixed(1),
                  unit: '',
                  valueColor: OmniColors.primaryAction,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatMeasurement(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }
}

class _Measurement extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color valueColor;

  const _Measurement({
    required this.label,
    required this.value,
    required this.unit,
    this.valueColor = OmniColors.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: OmniColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: valueColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 3),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    unit,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: OmniColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MeasurementDivider extends StatelessWidget {
  const _MeasurementDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 44, color: OmniColors.borderLight);
  }
}
