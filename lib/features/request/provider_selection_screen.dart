import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/omni_theme.dart';
import '../home/patient_care_destinations.dart';

class ProviderSelectionScreen extends StatelessWidget {
  const ProviderSelectionScreen({super.key});

  static const _comingSoonTypes = {PatientCareType.kine, PatientCareType.nurse};

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
                icon: const Icon(Icons.arrow_back, color: OmniColors.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            _buildHeader(),
            const SizedBox(height: 32),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: patientCareDestinations.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final d = patientCareDestinations[index];
                  final isDisabled = _comingSoonTypes.contains(d.type);
                  return _ServiceCard(
                    label: d.label,
                    subtitle: d.subtitle,
                    illustration: d.illustration,
                    color: d.color,
                    enabled: !isDisabled,
                    onTap: isDisabled
                        ? null
                        : () => Navigator.pushNamed(
                            context,
                            d.route,
                            arguments: d.isClinic
                                ? null
                                : {'providerType': d.type.name},
                          ),
                  );
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
            'Quel service\navez-vous besoin ?',
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
            'Choisissez le type de professionnel de santé\ndont vous avez besoin.',
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

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.label,
    required this.subtitle,
    required this.illustration,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final String illustration;
  final Color color;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final titleColor = enabled
        ? OmniColors.textPrimary
        : OmniColors.textSecondary;
    final subtitleColor = enabled
        ? OmniColors.textSecondary
        : OmniColors.textTertiary;

    final card = Ink(
      decoration: BoxDecoration(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(color: OmniColors.borderLight, width: 1),
        boxShadow: const [OmniColors.shadowSm],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            _ServiceIllustration(assetPath: illustration, enabled: enabled),
            const SizedBox(width: 14),
            Expanded(
              child: _ServiceInfo(
                label: label,
                subtitle: subtitle,
                titleColor: titleColor,
                subtitleColor: subtitleColor,
              ),
            ),
            const SizedBox(width: 8),
            if (enabled)
              Icon(
                Icons.chevron_right_rounded,
                color: OmniColors.textTertiary,
                size: 22,
              )
            else
              _ComingSoonChip(color: color),
          ],
        ),
      ),
    );

    if (!enabled) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        splashColor: color.withValues(alpha: 0.06),
        highlightColor: color.withValues(alpha: 0.03),
        child: card,
      ),
    );
  }
}

class _ServiceIllustration extends StatelessWidget {
  const _ServiceIllustration({required this.assetPath, required this.enabled});

  final String assetPath;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      height: 76,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.55,
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

class _ServiceInfo extends StatelessWidget {
  const _ServiceInfo({
    required this.label,
    required this.subtitle,
    required this.titleColor,
    required this.subtitleColor,
  });

  final String label;
  final String subtitle;
  final Color titleColor;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: titleColor,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: subtitleColor,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _ComingSoonChip extends StatelessWidget {
  const _ComingSoonChip({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(OmniRadii.pill),
      ),
      child: Text(
        'Bientôt',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
