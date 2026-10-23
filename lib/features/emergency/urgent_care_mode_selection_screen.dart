import 'package:flutter/material.dart';

import '../../core/theme/omni_theme.dart';

class UrgentCareModeSelectionScreen extends StatelessWidget {
  const UrgentCareModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Retour',
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: OmniColors.textPrimary,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Demande urgente',
                    style: textTheme.titleLarge?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: OmniColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                OmniSpacing.pageHorizontal,
                OmniSpacing.lg,
                OmniSpacing.pageHorizontal,
                OmniSpacing.xxl,
              ),
              children: [
                Text(
                  'Où souhaitez-vous consulter ?',
                  style: textTheme.headlineSmall?.copyWith(
                    fontSize: 26,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: OmniColors.textPrimary,
                    letterSpacing: -0.45,
                  ),
                ),
                const SizedBox(height: OmniSpacing.sm),
                Text(
                  'Choisissez le mode de prise en charge qui vous convient.',
                  style: textTheme.bodyLarge?.copyWith(
                    fontSize: 15,
                    height: 1.45,
                    color: OmniColors.textSecondary,
                  ),
                ),
                const SizedBox(height: OmniSpacing.xl),
                _UrgentCareModeCard(
                  title: 'Urgence à domicile',
                  description: 'Un médecin se déplace chez vous.',
                  illustration:
                      'assets/illustrations/doctor_consultation/doctor_home_consultation.png',
                  accentColor: OmniColors.freshMint,
                  onTap: () => _openHomeUrgency(context),
                ),
                const SizedBox(height: OmniSpacing.md),
                _UrgentCareModeCard(
                  title: 'Urgence au cabinet',
                  description:
                      "Rendez-vous au cabinet d'un médecin disponible.",
                  illustration:
                      'assets/illustrations/doctor_consultation/doctor_cabinet_consultation.png',
                  accentColor: OmniColors.infoBlue,
                  onTap: () => _openCabinetUrgency(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openHomeUrgency(BuildContext context) {
    final routeArgs =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final providerType = routeArgs?['providerType'] as String? ?? 'doctor';

    Navigator.pushNamed(
      context,
      '/emergency-step1',
      arguments: {'consultationType': 'home', 'providerType': providerType},
    );
  }

  void _openCabinetUrgency(BuildContext context) {
    Navigator.pushNamed(context, '/urgent-cabinet/care-subject');
  }
}

class _UrgentCareModeCard extends StatelessWidget {
  const _UrgentCareModeCard({
    required this.title,
    required this.description,
    required this.illustration,
    required this.accentColor,
    required this.onTap,
  });

  final String title;
  final String description;
  final String illustration;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: '$title. $description',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(OmniRadii.card),
          splashColor: accentColor.withValues(alpha: 0.06),
          highlightColor: accentColor.withValues(alpha: 0.03),
          child: Ink(
            decoration: BoxDecoration(
              color: OmniColors.surfacePrimary,
              borderRadius: BorderRadius.circular(OmniRadii.card),
              border: Border.all(color: OmniColors.borderLight),
              boxShadow: const [OmniColors.shadowSm],
            ),
            child: Padding(
              padding: const EdgeInsets.all(OmniSpacing.base),
              child: Row(
                children: [
                  SizedBox(
                    width: 112,
                    height: 112,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(OmniRadii.card),
                      child: Image.asset(
                        illustration,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                  const SizedBox(width: OmniSpacing.base),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: textTheme.titleMedium?.copyWith(
                            fontSize: 17,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                            color: OmniColors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: OmniSpacing.xs),
                        Text(
                          description,
                          style: textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            height: 1.4,
                            color: OmniColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: OmniSpacing.sm),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: OmniColors.textTertiary,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
