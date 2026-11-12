import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../../core/theme/omni_theme.dart';
import '../../../l10n/omni_localizations.dart';

/// Bundled family (pubspec, weights 500–800). The theme's google_fonts
/// text styles keep their 400 face when only the weight changes.
const String _bundledFont = 'Plus Jakarta Sans';

/// BMI display on the weight sub-step (G3-ONB3a). Display only: [bmi] is
/// the screen's existing `_bmiPreview`, shown as is. No categories, no
/// thresholds, no colour by range (a clinical rule, out of scope).
///
/// - [bmi] null: the neutral line « L’IMC sera calculé… ».
/// - [bmi] set: mintSoft card « Votre IMC », the value (1 French decimal,
///   tabular figures) and « Calculé avec votre taille (… cm) ». The card
///   fades in and slides up 12 px the first time a value exists; after
///   that the number counts from the previous value to the new one.
/// - Reduced motion: no slide, no count; the value just updates.
///
/// Announced as a live region with the final value only.
class BmiCard extends StatefulWidget {
  const BmiCard({super.key, required this.bmi, required this.heightCm});

  final double? bmi;
  final int? heightCm;

  @override
  State<BmiCard> createState() => _BmiCardState();
}

class _BmiCardState extends State<BmiCard> with SingleTickerProviderStateMixin {
  static const double _iconTile = 44;
  static const Duration _countDuration = Duration(milliseconds: 420);

  // Created in initState (not lazily), so dispose never builds a ticker on
  // a deactivated element when no value ever arrived.
  late final AnimationController _entrance;
  late final Animation<double> _entranceCurve;

  /// The entrance plays once, the first time a value exists.
  bool _entered = false;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _entranceCurve = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
  }

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeEnter();
  }

  @override
  void didUpdateWidget(BmiCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeEnter();
  }

  void _maybeEnter() {
    if (_entered || widget.bmi == null) return;
    _entered = true;
    if (_reduceMotion) {
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
    final l10n = OmniLocalizations.of(context);
    final bmi = widget.bmi;
    if (bmi == null) return _pending(l10n.onboardingBmiPending);

    final format = NumberFormat(
      '0.0',
      Localizations.localeOf(context).toLanguageTag(),
    );
    final reduceMotion = _reduceMotion;
    final height = widget.heightCm;

    final card = Container(
      padding: const EdgeInsets.all(OmniSpacing.base),
      decoration: BoxDecoration(
        color: OmniColors.mintSoft,
        borderRadius: BorderRadius.circular(OmniRadii.card),
      ),
      child: Row(
        children: [
          Container(
            width: _iconTile,
            height: _iconTile,
            decoration: BoxDecoration(
              color: OmniColors.surfacePrimary,
              borderRadius: BorderRadius.circular(OmniRadii.field),
            ),
            child: const Icon(
              Icons.monitor_heart_outlined,
              size: 24,
              color: OmniColors.deepTeal,
            ),
          ),
          const SizedBox(width: OmniSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.onboardingBmiTitle,
                  style: const TextStyle(
                    fontFamily: _bundledFont,
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: OmniColors.deepTeal,
                  ),
                ),
                TweenAnimationBuilder<double>(
                  // begin stays null: the first build shows the value, each
                  // later change counts from the value on screen.
                  tween: Tween<double>(end: bmi),
                  duration: reduceMotion ? Duration.zero : _countDuration,
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => Text(
                    format.format(value),
                    style: const TextStyle(
                      fontFamily: _bundledFont,
                      fontSize: 30,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      color: OmniColors.textPrimary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                if (height != null)
                  Text(
                    l10n.onboardingBmiHeightNote(height),
                    style: const TextStyle(
                      fontFamily: _bundledFont,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                      color: OmniColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    return Semantics(
      liveRegion: true,
      container: true,
      label: l10n.onboardingBmi(format.format(bmi)),
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _entranceCurve,
          child: card,
          builder: (context, child) {
            final t = _entranceCurve.value;
            return Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, 12 * (1 - t)),
                child: child,
              ),
            );
          },
        ),
      ),
    );
  }

  /// The former neutral line, unchanged except the text colour.
  Widget _pending(String text) {
    return Container(
      padding: const EdgeInsets.all(OmniSpacing.md),
      decoration: BoxDecoration(
        color: OmniColors.slateSoft,
        borderRadius: BorderRadius.circular(OmniRadii.field),
      ),
      child: Row(
        children: [
          const ExcludeSemantics(
            child: Icon(
              Icons.monitor_heart_outlined,
              size: 20,
              color: OmniColors.deepTeal,
            ),
          ),
          const SizedBox(width: OmniSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: _bundledFont,
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: OmniColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
