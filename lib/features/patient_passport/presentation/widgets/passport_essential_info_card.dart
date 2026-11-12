import 'package:flutter/material.dart';

import '../../../../core/theme/omni_theme.dart';
import '../../models/patient_passport_view_models.dart';
import 'passport_card.dart';
import 'passport_card_status.dart';

class PassportEssentialInfoCard extends StatelessWidget {
  final PatientPassportViewData data;

  /// When set, shown as plain text in place of the condition chips
  /// (« Non renseigné », « Aucun antécédent connu »). G2-FT-3.
  final String? conditionsText;

  /// Loading or failure in place of the rows (G2-FT-3).
  final PassportCardStatus? status;

  const PassportEssentialInfoCard({
    super.key,
    required this.data,
    this.conditionsText,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    return PassportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PassportSectionHeading(
            icon: Icons.health_and_safety_outlined,
            title: 'Informations essentielles',
            subtitle:
                'Informations prioritaires pour les professionnels de santé',
            iconColor: OmniColors.clinicalCyan,
            iconBackground: OmniColors.clinicalCyanSoft,
          ),
          const SizedBox(height: 18),
          if (status case final status?)
            PassportCardStatusBody(status: status)
          else
            ..._rows(context),
        ],
      ),
    );
  }

  List<Widget> _rows(BuildContext context) {
    final valueStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800);
    return [
      _EssentialRow(
        icon: Icons.bloodtype_outlined,
        iconColor: OmniColors.error,
        iconBackground: OmniColors.errorSoft,
        label: 'Groupe Sanguin',
        value: data.bloodGroup,
      ),
      const Divider(height: 24),
      _EssentialRow(
        icon: Icons.warning_amber_rounded,
        iconColor: OmniColors.amber,
        iconBackground: OmniColors.amberSoft,
        label: 'Allergies et réactions',
        value: data.allergies,
      ),
      const Divider(height: 24),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _IconTile(
            icon: Icons.favorite_border_rounded,
            color: OmniColors.urgentCoral,
            background: OmniColors.urgentCoralSoft,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Conditions Chroniques',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: OmniColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                if (conditionsText case final text?)
                  Text(text, style: valueStyle)
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: data.chronicConditions
                        .map(
                          (condition) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: OmniColors.slateSoft,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: OmniColors.borderLight),
                            ),
                            child: Text(
                              condition,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: OmniColors.slateBlue,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
              ],
            ),
          ),
        ],
      ),
    ];
  }
}

class _EssentialRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String label;
  final String value;

  const _EssentialRow({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconTile(icon: icon, color: iconColor, background: iconBackground),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: OmniColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;

  const _IconTile({
    required this.icon,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
