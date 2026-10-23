import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/omni_theme.dart';

class EmergencyRequestStep0 extends StatelessWidget {
  const EmergencyRequestStep0({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: OmniSpacing.pageHorizontal,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: IconButton(
                icon: const Icon(Icons.close, color: OmniColors.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            _buildHeader(),
            const SizedBox(height: 32),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: 2,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _ConsultationModeCard(
                      title: 'Demande urgente',
                      subtitle:
                          'Choisissez une prise en charge urgente à domicile ou au cabinet.',
                      illustration:
                          'assets/illustrations/doctor_consultation/doctor_home_consultation.png',
                      accentColor: OmniColors.freshMint,
                      splashColor: OmniColors.freshMint.withValues(alpha: 0.06),
                      highlightColor: OmniColors.freshMint.withValues(
                        alpha: 0.03,
                      ),
                      onTap: () {
                        final routeArgs =
                            ModalRoute.of(context)?.settings.arguments
                                as Map<String, dynamic>?;
                        final providerType =
                            routeArgs?['providerType'] as String? ?? 'doctor';
                        Navigator.pushNamed(
                          context,
                          '/urgent-care-mode-selection',
                          arguments: {'providerType': providerType},
                        );
                      },
                    );
                  } else {
                    return _ConsultationModeCard(
                      title: 'Consultation au cabinet',
                      subtitle: 'Prenez rendez-vous au cabinet du médecin.',
                      illustration:
                          'assets/illustrations/doctor_consultation/doctor_cabinet_consultation.png',
                      accentColor: OmniColors.infoBlue,
                      splashColor: OmniColors.infoBlue.withValues(alpha: 0.06),
                      highlightColor: OmniColors.infoBlue.withValues(
                        alpha: 0.03,
                      ),
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/doctor/cabinet/who-needs-care',
                        );
                      },
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comment souhaitez-vous\nconsulter ?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: OmniColors.textPrimary,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Choisissez le mode de consultation\nqui vous convient.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: OmniColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConsultationModeCard extends StatelessWidget {
  const _ConsultationModeCard({
    required this.title,
    required this.subtitle,
    required this.illustration,
    required this.accentColor,
    required this.splashColor,
    required this.highlightColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String illustration;
  final Color accentColor;
  final Color splashColor;
  final Color highlightColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final card = Ink(
      decoration: BoxDecoration(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(color: OmniColors.borderLight, width: 1),
        boxShadow: const [OmniColors.shadowSm],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(OmniRadii.card),
                child: Image.asset(
                  illustration,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: OmniColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: OmniColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: OmniColors.textTertiary,
                  size: 22,
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        splashColor: splashColor,
        highlightColor: highlightColor,
        child: card,
      ),
    );
  }
}
