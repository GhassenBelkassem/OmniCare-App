import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';
import '../../../core/widgets/omni_pressable.dart';
import '../../../l10n/omni_localizations.dart';
import '../../auth/widgets/auth_decorative_circles.dart';
import '../../auth/widgets/omni_logo_badge.dart';

/// Bundled family (pubspec, weights 500–800). The theme's google_fonts
/// text styles keep their 400 face when only the weight changes.
const String _bundledFont = 'Plus Jakarta Sans';

/// Onboarding intro (G3-ONB2), shown by the onboarding screen on a fresh
/// start only, outside its PageView. Dark teal top (circles, 96 px logo,
/// 4 label chips) and a white card with the two actions. Pure UI.
///
/// Entrance as the welcome screen: one 700 ms controller, the top fades in
/// first, then the card blocks fade + slide 12 px in turn (easeOutCubic).
/// No animation with reduced motion.
class OnboardingIntro extends StatefulWidget {
  const OnboardingIntro({
    super.key,
    required this.onStart,
    required this.onLater,
  });

  /// « Commencer »: shows the first onboarding page.
  final VoidCallback onStart;

  /// « Plus tard »: the screen's existing skip.
  final VoidCallback onLater;

  @override
  State<OnboardingIntro> createState() => _OnboardingIntroState();
}

class _OnboardingIntroState extends State<OnboardingIntro>
    with SingleTickerProviderStateMixin {
  static const Duration _total = Duration(milliseconds: 700);
  static const int _blockCount = 4;
  static const double _maxContentWidth = 480;

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: _total,
  );

  late final Animation<double> _header = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0, 200 / 700, curve: Curves.easeOutCubic),
  );

  late final List<Animation<double>> _blocks = [
    for (var i = 0; i < _blockCount; i++)
      CurvedAnimation(
        parent: _entrance,
        curve: Interval(
          (140 + 60 * i) / 700,
          ((140 + 60 * i) + 320) / 700,
          curve: Curves.easeOutCubic,
        ),
      ),
  ];

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OmniColors.deepTealActive,
      body: Stack(
        children: [
          const Positioned.fill(child: AuthDecorativeCircles()),
          SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side = ((constraints.maxWidth - _maxContentWidth) / 2)
                    .clamp(OmniSpacing.pageHorizontal, double.infinity);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header + card text scroll on small phones; the two
                    // actions below stay pinned and visible.
                    Expanded(
                      child: CustomScrollView(
                        slivers: [
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: FadeTransition(
                                    opacity: _header,
                                    child: _Header(side: side),
                                  ),
                                ),
                                _CardText(side: side, blocks: _blocks),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _Actions(
                      side: side,
                      animation: _blocks.last,
                      onStart: widget.onStart,
                      onLater: widget.onLater,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Logo badge and the 4 label chips on the dark top.
class _Header extends StatelessWidget {
  const _Header({required this.side});

  final double side;

  @override
  Widget build(BuildContext context) {
    final l10n = OmniLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        side,
        OmniSpacing.lg,
        side,
        OmniSpacing.lg,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OmniLogoBadge(
            size: 96,
            padding: 10,
            semanticLabel: l10n.authLogoLabel,
          ),
          const SizedBox(height: OmniSpacing.lg),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: OmniSpacing.sm,
            runSpacing: OmniSpacing.sm,
            children: [
              _LabelChip(
                icon: Icons.bloodtype_outlined,
                label: l10n.onboardingIntroChipBlood,
              ),
              _LabelChip(
                icon: Icons.health_and_safety_outlined,
                label: l10n.onboardingIntroChipAllergies,
              ),
              _LabelChip(
                icon: Icons.medication_outlined,
                label: l10n.onboardingIntroChipMedications,
              ),
              _LabelChip(
                icon: Icons.monitor_heart_outlined,
                label: l10n.onboardingIntroChipFollowUp,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// White chip on the dark header; decorative text only.
class _LabelChip extends StatelessWidget {
  const _LabelChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: OmniSpacing.md,
        vertical: OmniSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.circular(OmniRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(icon, size: 16, color: OmniColors.deepTeal),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: _bundledFont,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: OmniColors.deepTealActive,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Top of the white card (radius 28): title, text and the two lines.
class _CardText extends StatelessWidget {
  const _CardText({required this.side, required this.blocks});

  final double side;
  final List<Animation<double>> blocks;

  static const double _radius = 28;

  @override
  Widget build(BuildContext context) {
    final l10n = OmniLocalizations.of(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(_radius)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(side, OmniSpacing.xl, side, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Entrance(
              animation: blocks[0],
              child: Semantics(
                header: true,
                child: Text(
                  l10n.onboardingIntroTitle,
                  style: const TextStyle(
                    fontFamily: _bundledFont,
                    fontSize: 26,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: OmniColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: OmniSpacing.sm),
            _Entrance(
              animation: blocks[1],
              child: Text(
                l10n.onboardingIntroBody,
                style: const TextStyle(
                  fontFamily: _bundledFont,
                  fontSize: 15,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: OmniColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: OmniSpacing.base),
            _Entrance(
              animation: blocks[2],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MetaLine(
                    icon: Icons.schedule_rounded,
                    text: l10n.onboardingIntroDuration,
                  ),
                  const SizedBox(height: OmniSpacing.sm),
                  _MetaLine(
                    icon: Icons.edit_outlined,
                    text: l10n.onboardingIntroEditable,
                  ),
                ],
              ),
            ),
            const SizedBox(height: OmniSpacing.lg),
          ],
        ),
      ),
    );
  }
}

/// Pinned white bottom of the card: « Commencer » and « Plus tard ».
class _Actions extends StatelessWidget {
  const _Actions({
    required this.side,
    required this.animation,
    required this.onStart,
    required this.onLater,
  });

  final double side;
  final Animation<double> animation;
  final VoidCallback onStart;
  final VoidCallback onLater;

  static const double _buttonRadius = 14;

  @override
  Widget build(BuildContext context) {
    final l10n = OmniLocalizations.of(context);
    return ColoredBox(
      color: OmniColors.surfacePrimary,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(side, 0, side, OmniSpacing.sm),
          child: _Entrance(
            animation: animation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OmniPressable(
                  borderRadius: _buttonRadius,
                  builder: (context, states) => ElevatedButton(
                    statesController: states,
                    onPressed: OmniPressable.withHaptic(onStart),
                    style: ButtonStyle(
                      minimumSize: const WidgetStatePropertyAll(
                        Size.fromHeight(52),
                      ),
                      elevation: const WidgetStatePropertyAll(0),
                      backgroundColor: const WidgetStatePropertyAll(
                        OmniColors.primaryAction,
                      ),
                      foregroundColor: const WidgetStatePropertyAll(
                        OmniColors.textOnDark,
                      ),
                      shape: const WidgetStatePropertyAll(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(
                            Radius.circular(_buttonRadius),
                          ),
                        ),
                      ),
                      overlayColor: OmniPressable.overlay(
                        OmniColors.textOnDark,
                      ),
                    ),
                    child: Text(
                      l10n.onboardingIntroStart,
                      style: const TextStyle(
                        fontFamily: _bundledFont,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: OmniSpacing.xs),
                OmniPressable(
                  borderRadius: _buttonRadius,
                  builder: (context, states) => TextButton(
                    statesController: states,
                    onPressed: onLater,
                    style: ButtonStyle(
                      minimumSize: const WidgetStatePropertyAll(
                        Size.fromHeight(48),
                      ),
                      foregroundColor: const WidgetStatePropertyAll(
                        OmniColors.textSecondary,
                      ),
                      overlayColor: OmniPressable.overlay(
                        OmniColors.textSecondary,
                      ),
                    ),
                    child: Text(
                      l10n.onboardingIntroLater,
                      style: const TextStyle(
                        fontFamily: _bundledFont,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ExcludeSemantics(
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: OmniColors.mintSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: OmniColors.deepTeal),
          ),
        ),
        const SizedBox(width: OmniSpacing.md),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: _bundledFont,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: OmniColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Fade + 12 px slide up, driven by [animation].
class _Entrance extends StatelessWidget {
  const _Entrance({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - animation.value)),
          child: child,
        ),
      ),
    );
  }
}
