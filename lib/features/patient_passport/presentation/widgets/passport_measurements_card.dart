import 'package:flutter/material.dart';

import '../../../../core/theme/omni_theme.dart';
import '../../../../l10n/omni_localizations.dart';
import 'passport_card.dart';
import 'passport_card_status.dart';

class PassportMeasurementsCard extends StatelessWidget {
  /// Null when not recorded: shown as « Non renseigné », never a default.
  final double? heightCm;
  final double? weightKg;

  /// The record's BMI. When null it is computed from both measurements, and
  /// shown as « Non renseigné » if either is missing.
  final double? bmi;

  /// Loading or failure in place of the measurements (G2-FT-3).
  final PassportCardStatus? status;

  const PassportMeasurementsCard({
    super.key,
    required this.heightCm,
    required this.weightKg,
    this.bmi,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    // Looked up only for a missing value, so callers that always pass both
    // values (the doctor preview) never need the app localizations.
    String notRecorded() =>
        OmniLocalizations.of(context).medicalRecordNotRecorded;
    final height = heightCm;
    final weight = weightKg;
    final bmiValue = bmi ?? _computedBmi(height, weight);

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
          if (status case final status?)
            PassportCardStatusBody(status: status)
          else
            Row(
              children: [
                Expanded(
                  child: _Measurement(
                    label: 'Taille',
                    value: height == null
                        ? notRecorded()
                        : _formatMeasurement(height),
                    unit: height == null ? '' : 'cm',
                  ),
                ),
                const _MeasurementDivider(),
                Expanded(
                  child: _Measurement(
                    label: 'Poids',
                    value: weight == null
                        ? notRecorded()
                        : _formatMeasurement(weight),
                    unit: weight == null ? '' : 'kg',
                  ),
                ),
                const _MeasurementDivider(),
                Expanded(
                  child: _Measurement(
                    label: 'IMC',
                    value: bmiValue?.toStringAsFixed(1) ?? notRecorded(),
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

  /// Same rule as before for callers that pass both values (0 when the
  /// height is not positive); null when either value is missing.
  static double? _computedBmi(double? heightCm, double? weightKg) {
    if (heightCm == null || weightKg == null) return null;
    final heightMeters = heightCm / 100;
    return heightMeters > 0 ? weightKg / (heightMeters * heightMeters) : 0;
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
