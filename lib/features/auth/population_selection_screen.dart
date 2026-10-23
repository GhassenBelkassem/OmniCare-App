import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/omni_theme.dart';
import 'language_selection_screen.dart';

/// Entry choice only. The authenticated role from /auth/me owns routing.
class PopulationSelectionScreen extends StatelessWidget {
  const PopulationSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OmniColors.pageBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: OmniSpacing.pageHorizontal,
              vertical: OmniSpacing.pageVertical,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 112,
                      height: 112,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.local_hospital_outlined,
                        size: 72,
                        color: OmniColors.deepTeal,
                      ),
                    ),
                  ),
                  const SizedBox(height: OmniSpacing.xxl),
                  Text(
                    'Bienvenue sur OmniCare',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: OmniColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: OmniSpacing.sm),
                  Text(
                    'Choisissez votre espace pour continuer.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      color: OmniColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: OmniSpacing.xxxl),
                  _PopulationCard(
                    title: 'Je suis patient',
                    subtitle: 'Gérer ma santé et celle de ma famille',
                    icon: Icons.favorite_outline_rounded,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LanguageSelectionScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: OmniSpacing.base),
                  _PopulationCard(
                    title: 'Je suis professionnel de santé',
                    subtitle: 'Accéder à mon espace professionnel',
                    icon: Icons.medical_services_outlined,
                    onTap: () =>
                        Navigator.of(context).pushNamed('/professional-login'),
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

class _PopulationCard extends StatelessWidget {
  const _PopulationCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: OmniColors.surfacePrimary,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OmniRadii.cardLarge),
        side: const BorderSide(color: OmniColors.borderLight),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OmniRadii.cardLarge),
        child: Padding(
          padding: const EdgeInsets.all(OmniSpacing.xl),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: OmniColors.slateSoft,
                  borderRadius: BorderRadius.circular(OmniRadii.field),
                ),
                child: Icon(icon, color: OmniColors.slateBlue),
              ),
              const SizedBox(width: OmniSpacing.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: OmniColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: OmniSpacing.xs),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: OmniColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: OmniSpacing.sm),
              const Icon(
                Icons.chevron_right_rounded,
                color: OmniColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
