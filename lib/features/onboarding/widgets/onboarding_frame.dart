import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';
import '../../../core/widgets/omni_pressable.dart';
import '../../../l10n/omni_localizations.dart';

/// Bundled family (pubspec, weights 500–800). The theme's google_fonts
/// text styles keep their 400 face when only the weight changes.
const String _bundledFont = 'Plus Jakarta Sans';

/// White frame of one onboarding page (G3-ONB1). Pure UI: every value and
/// callback comes from the screen.
///
/// * top row: back (44 px circle, hidden when [onBack] is null), thin
///   progress bar ([progress] 0–1, animated from the previous value in
///   450 ms, none with reduced motion), « Passer » (hidden when [onSkip] is
///   null);
/// * scrolling content: [title], optional [subtitle], [child];
/// * pinned bottom: the main button with a 32 px white fade above it. The
///   Scaffold resizes for the keyboard, so the button stays above it.
class OnboardingFrame extends StatelessWidget {
  const OnboardingFrame({
    super.key,
    required this.progress,
    required this.title,
    required this.child,
    required this.primaryLabel,
    required this.onPrimary,
    this.subtitle,
    this.onBack,
    this.onSkip,
    this.primaryEnabled = true,
    this.primaryLoading = false,
    this.previousProgress,
  });

  /// 0–1, clamped.
  final double progress;

  /// Where the bar starts on the first build (e.g. the previous page's
  /// value when each page builds its own frame). Null: no first animation.
  final double? previousProgress;

  final String title;
  final String? subtitle;
  final Widget child;

  final VoidCallback? onBack;
  final VoidCallback? onSkip;

  final String primaryLabel;
  final VoidCallback? onPrimary;

  /// False shows the disabled look (borderLight background, textTertiary
  /// label) and makes the button not tappable.
  final bool primaryEnabled;

  /// True while the page is being saved: a spinner replaces the label and
  /// taps are ignored; the button keeps its enabled look (G3-ONB2).
  final bool primaryLoading;

  static const double _maxContentWidth = 480;
  static const double _fadeHeight = 32;
  static const double _buttonRadius = 14;
  static const double _buttonHeight = 52;

  static void _ignoreTap() {}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OmniColors.surfacePrimary,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = ((constraints.maxWidth - _maxContentWidth) / 2).clamp(
              OmniSpacing.pageHorizontal,
              double.infinity,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    side - OmniSpacing.xs,
                    OmniSpacing.sm,
                    side - OmniSpacing.xs,
                    0,
                  ),
                  child: _TopRow(
                    progress: progress,
                    previousProgress: previousProgress,
                    onBack: onBack,
                    onSkip: onSkip,
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.fromLTRB(
                            side,
                            OmniSpacing.xl,
                            side,
                            OmniSpacing.xl + _fadeHeight,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Semantics(
                                header: true,
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontFamily: _bundledFont,
                                    fontSize: 28,
                                    height: 1.2,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.6,
                                    color: OmniColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: OmniSpacing.sm),
                                Text(
                                  subtitle!,
                                  style: const TextStyle(
                                    fontFamily: _bundledFont,
                                    fontSize: 15,
                                    height: 1.45,
                                    fontWeight: FontWeight.w500,
                                    color: OmniColors.textSecondary,
                                  ),
                                ),
                              ],
                              const SizedBox(height: OmniSpacing.xl),
                              child,
                            ],
                          ),
                        ),
                      ),
                      // White fade above the pinned button.
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: _fadeHeight,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  OmniColors.surfacePrimary.withValues(
                                    alpha: 0,
                                  ),
                                  OmniColors.surfacePrimary,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(side, 0, side, OmniSpacing.base),
                  child: OmniPressable(
                    borderRadius: _buttonRadius,
                    builder: (context, states) => ElevatedButton(
                      statesController: states,
                      onPressed: !primaryEnabled || onPrimary == null
                          ? null
                          : primaryLoading
                          ? _ignoreTap
                          : OmniPressable.withHaptic(onPrimary),
                      style: ButtonStyle(
                        minimumSize: const WidgetStatePropertyAll(
                          Size.fromHeight(_buttonHeight),
                        ),
                        elevation: const WidgetStatePropertyAll(0),
                        shape: const WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(
                              Radius.circular(_buttonRadius),
                            ),
                          ),
                        ),
                        backgroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.disabled)
                              ? OmniColors.borderLight
                              : OmniColors.primaryAction,
                        ),
                        foregroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.disabled)
                              ? OmniColors.textTertiary
                              : OmniColors.textOnDark,
                        ),
                        overlayColor: OmniPressable.overlay(
                          OmniColors.textOnDark,
                        ),
                      ),
                      child: primaryLoading
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: OmniColors.textOnDark,
                              ),
                            )
                          : Text(
                              primaryLabel,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: _bundledFont,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.progress,
    required this.previousProgress,
    required this.onBack,
    required this.onSkip,
  });

  final double progress;
  final double? previousProgress;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;

  static const double _backSize = 44;

  @override
  Widget build(BuildContext context) {
    final l10n = OmniLocalizations.of(context);
    final back = onBack;
    final skip = onSkip;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _backSize),
      child: Row(
        children: [
          if (back != null) ...[
            OmniPressable(
              borderRadius: _backSize / 2,
              builder: (context, states) => IconButton(
                statesController: states,
                tooltip: l10n.authBack,
                onPressed: back,
                style: ButtonStyle(
                  fixedSize: const WidgetStatePropertyAll(
                    Size.square(_backSize),
                  ),
                  minimumSize: const WidgetStatePropertyAll(
                    Size.square(_backSize),
                  ),
                  backgroundColor: const WidgetStatePropertyAll(
                    OmniColors.slateSoft,
                  ),
                  foregroundColor: const WidgetStatePropertyAll(
                    OmniColors.textPrimary,
                  ),
                  shape: const WidgetStatePropertyAll(CircleBorder()),
                  overlayColor: OmniPressable.overlay(OmniColors.textPrimary),
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 22),
              ),
            ),
            const SizedBox(width: OmniSpacing.md),
          ] else
            const SizedBox(width: OmniSpacing.xs),
          Expanded(
            child: _ThinProgress(
              value: progress.clamp(0.0, 1.0),
              from: previousProgress?.clamp(0.0, 1.0),
              semanticLabel: l10n.onboardingProgressLabel,
            ),
          ),
          if (skip != null) ...[
            const SizedBox(width: OmniSpacing.sm),
            OmniPressable(
              borderRadius: OmniRadii.field,
              builder: (context, states) => TextButton(
                statesController: states,
                onPressed: skip,
                style: ButtonStyle(
                  minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
                  foregroundColor: const WidgetStatePropertyAll(
                    OmniColors.textSecondary,
                  ),
                  overlayColor: OmniPressable.overlay(OmniColors.textSecondary),
                ),
                child: Text(
                  l10n.onboardingSkip,
                  style: const TextStyle(
                    fontFamily: _bundledFont,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ] else
            const SizedBox(width: OmniSpacing.xs),
        ],
      ),
    );
  }
}

/// 4 px bar, radius 2: borderLight track, deepTeal fill.
class _ThinProgress extends StatelessWidget {
  const _ThinProgress({
    required this.value,
    required this.from,
    required this.semanticLabel,
  });

  final double value;
  final double? from;
  final String semanticLabel;

  static const double _height = 4;
  static const Duration _duration = Duration(milliseconds: 450);

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      label: semanticLabel,
      value: '${(value * 100).round()} %',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_height / 2),
        child: SizedBox(
          height: _height,
          child: ColoredBox(
            color: OmniColors.borderLight,
            child: TweenAnimationBuilder<double>(
              // `begin` is used on the first build only; later changes of
              // [value] animate from the current width.
              tween: Tween(
                begin: reduceMotion ? value : (from ?? value),
                end: value,
              ),
              duration: reduceMotion ? Duration.zero : _duration,
              curve: Curves.easeOut,
              builder: (context, width, _) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: width,
                heightFactor: 1,
                child: const ColoredBox(color: OmniColors.deepTeal),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
