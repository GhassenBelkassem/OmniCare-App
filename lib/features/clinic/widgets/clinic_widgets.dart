import 'package:flutter/material.dart';

/// Restrained clinical palette shared by the clinic screens. It reuses the
/// existing OmniCare green and neutral tokens already used across the app.
class ClinicPalette {
  const ClinicPalette._();

  static const Color primary = Color(0xFF1FBF9A);
  static const Color primarySoft = Color(0xFFE7F7F2);
  static const Color background = Color(0xFFF4F5F7);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFEAECF0);
  static const Color textPrimary = Color(0xFF101828);
  static const Color textSecondary = Color(0xFF667085);
  static const Color textMuted = Color(0xFF98A2B3);
  static const Color warningSoft = Color(0xFFFEF6E7);
  static const Color warning = Color(0xFFB54708);
}

/// The bundled font family declared in pubspec.yaml.
const String clinicFontFamily = 'Plus Jakarta Sans';

TextStyle clinicTextStyle({
  double fontSize = 14,
  FontWeight fontWeight = FontWeight.w500,
  Color color = ClinicPalette.textPrimary,
  double? height,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: clinicFontFamily,
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

/// Plain white card used for every clinic information block.
class ClinicCard extends StatelessWidget {
  const ClinicCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ClinicPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ClinicPalette.border),
      ),
      child: child,
    );
  }
}

class ClinicSectionTitle extends StatelessWidget {
  const ClinicSectionTitle(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final subtitleText = subtitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: clinicTextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        if (subtitleText != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitleText,
            style: clinicTextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: ClinicPalette.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// Label/value row used for identity and membership facts.
class ClinicInfoRow extends StatelessWidget {
  const ClinicInfoRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: Text(
                label,
                style: clinicTextStyle(
                  fontSize: 13,
                  color: ClinicPalette.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 5,
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: clinicTextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ClinicStatusChip extends StatelessWidget {
  const ClinicStatusChip({super.key, required this.label, this.active = true});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? ClinicPalette.primarySoft : ClinicPalette.warningSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: clinicTextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: active ? const Color(0xFF0E6B57) : ClinicPalette.warning,
        ),
      ),
    );
  }
}

/// Non-interactive tile for a future clinic module. Phase 1 always renders
/// these as unavailable and never exposes a tap target.
class ClinicUnavailableModuleTile extends StatelessWidget {
  const ClinicUnavailableModuleTile({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label, not available yet',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: ClinicPalette.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ClinicPalette.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.lock_outline,
              size: 16,
              color: ClinicPalette.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: clinicTextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ClinicPalette.textSecondary,
                ),
              ),
            ),
            Text(
              'Not available yet',
              style: clinicTextStyle(
                fontSize: 12,
                color: ClinicPalette.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ClinicPrimaryButton extends StatelessWidget {
  const ClinicPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final iconData = icon;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: ClinicPalette.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (iconData != null) ...[
              Icon(iconData, size: 18),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: clinicTextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ClinicSecondaryButton extends StatelessWidget {
  const ClinicSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final iconData = icon;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: ClinicPalette.textPrimary,
          side: const BorderSide(color: Color(0xFFD0D5DD)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (iconData != null) ...[
              Icon(iconData, size: 18),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: clinicTextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared page frame: safe area, responsive max width and consistent padding.
class ClinicPageScaffold extends StatelessWidget {
  const ClinicPageScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final subtitleText = subtitle;
    return Scaffold(
      backgroundColor: ClinicPalette.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(height: 16),
                  ],
                  Text(
                    title,
                    style: clinicTextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (subtitleText != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitleText,
                      style: clinicTextStyle(
                        fontSize: 14,
                        color: ClinicPalette.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
