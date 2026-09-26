import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';

/// Deliberately restrained D0 state for Doctor features that are not built yet.
class DoctorPlaceholderTab extends StatelessWidget {
  const DoctorPlaceholderTab({
    super.key,
    required this.title,
    required this.icon,
    this.child,
  });

  final String title;
  final IconData icon;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      key: ValueKey('doctor-placeholder-${title.toLowerCase()}'),
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal,
        OmniSpacing.pageVertical,
        OmniSpacing.pageHorizontal,
        OmniSpacing.xxl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: OmniSpacing.xxl),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(OmniSpacing.xl),
                decoration: BoxDecoration(
                  color: OmniColors.slateSoft,
                  borderRadius: BorderRadius.circular(OmniRadii.card),
                  border: Border.all(color: OmniColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: OmniColors.surfacePrimary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: OmniColors.slateBlue),
                    ),
                    const SizedBox(height: OmniSpacing.lg),
                    Text(
                      'Bientôt disponible dans cette démo.',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (child != null) ...[
                const SizedBox(height: OmniSpacing.xl),
                child!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
