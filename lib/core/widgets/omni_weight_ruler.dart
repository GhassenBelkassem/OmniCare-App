import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../l10n/omni_localizations.dart';
import '../theme/omni_theme.dart';

/// Bundled family (pubspec, weights 500–800). The theme's google_fonts
/// text styles keep their 400 face when only the weight changes.
const String _bundledFont = 'Plus Jakarta Sans';

/// Horizontal ruler with a big readout (G3-ONB1), e.g. a weight in kg.
/// Pure UI: the screen owns [value] and reacts in [onChanged].
///
/// * one tick per unit, 12 px apart; every 5th medium, every 10th long with
///   its number; deepTeal 3 px centre indicator;
/// * the ruler snaps to whole units: a user drag calls [onChanged] with an
///   `int` each time a unit crosses the centre (selection click haptic) and
///   once more on release if needed;
/// * [value] may be a decimal (e.g. typed in a fallback field): the readout
///   shows one decimal only when it is not whole, and the ruler is placed
///   at that position;
/// * [value] may be null: the readout shows « — » and the ruler rests on
///   [initialPosition]. Placing the ruler (first build or a new [value])
///   never calls [onChanged]; a drag that ends where it started still picks
///   that unit.
///
/// Screen readers get one slider (label [semanticLabel], value « 68 kg » or
/// « Non renseigné ») with increase / decrease actions of one unit.
class OmniWeightRuler extends StatefulWidget {
  const OmniWeightRuler({
    super.key,
    required this.min,
    required this.max,
    required this.value,
    required this.unit,
    required this.onChanged,
    required this.initialPosition,
    this.semanticLabel,
  }) : assert(min < max, 'min must be below max');

  final int min;
  final int max;
  final double? value;
  final String unit;
  final ValueChanged<int> onChanged;

  /// Where the ruler rests while [value] is null (clamped to min..max).
  final int initialPosition;

  /// Name for screen readers (e.g. « Poids »).
  final String? semanticLabel;

  @override
  State<OmniWeightRuler> createState() => _OmniWeightRulerState();
}

class _OmniWeightRulerState extends State<OmniWeightRuler> {
  static const double _spacing = 12;
  static const double _rulerHeight = 76;
  static const Duration _snapDuration = Duration(milliseconds: 160);

  late final ScrollController _controller = ScrollController(
    initialScrollOffset: _offsetOf(widget.value ?? widget.initialPosition),
  );

  /// True between the start of a user drag and the end of its fling.
  bool _userScrolling = false;

  /// Last unit sent during the current drag (avoids repeats within a frame).
  int? _lastSent;

  double _offsetOf(num position) =>
      (position.clamp(widget.min, widget.max) - widget.min) * _spacing;

  int _unitAt(double offset) =>
      (widget.min + (offset / _spacing).round()).clamp(widget.min, widget.max);

  @override
  void didUpdateWidget(OmniWeightRuler oldWidget) {
    super.didUpdateWidget(oldWidget);
    final value = widget.value;
    if (value == null || value == oldWidget.value || _userScrolling) return;
    if (!_controller.hasClients) return;
    final target = _offsetOf(value);
    if ((_controller.offset - target).abs() > 0.5) {
      // Programmatic: no ScrollStart with drag details, so no onChanged.
      _controller.jumpTo(target);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _emit(int unit) {
    if (unit == _lastSent || unit.toDouble() == widget.value) return;
    _lastSent = unit;
    HapticFeedback.selectionClick();
    widget.onChanged(unit);
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      _userScrolling = notification.dragDetails != null;
      _lastSent = null;
    } else if (notification is ScrollUpdateNotification) {
      if (_userScrolling) _emit(_unitAt(notification.metrics.pixels));
    } else if (notification is ScrollEndNotification) {
      if (_userScrolling) {
        final unit = _unitAt(notification.metrics.pixels);
        _emit(unit);
        _snapTo(unit);
      }
      _userScrolling = false;
    }
    return false;
  }

  /// Aligns the ruler on [unit] after the current frame (programmatic).
  void _snapTo(int unit) {
    final target = _offsetOf(unit);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      if ((_controller.offset - target).abs() <= 0.5) return;
      final reduceMotion =
          MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (reduceMotion) {
        _controller.jumpTo(target);
      } else {
        _controller.animateTo(
          target,
          duration: _snapDuration,
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _step(int delta) {
    final base = (widget.value ?? widget.initialPosition).round();
    final unit = (base + delta).clamp(widget.min, widget.max);
    _lastSent = null;
    _emit(unit);
    _snapTo(unit);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = OmniLocalizations.of(context);
    final format = NumberFormat(
      '0.#',
      Localizations.localeOf(context).toLanguageTag(),
    );
    final value = widget.value;
    String spoken(num? number) => number == null
        ? l10n.pickerNoValue
        : '${format.format(number)} ${widget.unit}';
    final base = (value ?? widget.initialPosition).round();
    final textScaler = MediaQuery.textScalerOf(context);

    return Semantics(
      slider: true,
      label: widget.semanticLabel,
      value: spoken(value),
      increasedValue: base < widget.max ? spoken(base + 1) : null,
      decreasedValue: base > widget.min ? spoken(base - 1) : null,
      onIncrease: base < widget.max ? () => _step(1) : null,
      onDecrease: base > widget.min ? () => _step(-1) : null,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    value == null ? '—' : format.format(value),
                    maxLines: 1,
                    style: const TextStyle(
                      fontFamily: _bundledFont,
                      fontSize: 64,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                      color: OmniColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: OmniSpacing.sm),
                Text(
                  widget.unit,
                  style: const TextStyle(
                    fontFamily: _bundledFont,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: OmniColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: OmniSpacing.base),
            SizedBox(
              height: _rulerHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final viewport = constraints.maxWidth;
                  final contentWidth =
                      (widget.max - widget.min) * _spacing + viewport;
                  return Stack(
                    children: [
                      NotificationListener<ScrollNotification>(
                        onNotification: _onScrollNotification,
                        child: SingleChildScrollView(
                          controller: _controller,
                          scrollDirection: Axis.horizontal,
                          physics: const ClampingScrollPhysics(),
                          child: CustomPaint(
                            size: Size(contentWidth, _rulerHeight),
                            painter: _RulerPainter(
                              min: widget.min,
                              max: widget.max,
                              spacing: _spacing,
                              leading: viewport / 2,
                              textScaler: textScaler,
                            ),
                          ),
                        ),
                      ),
                      // Centre indicator.
                      Positioned(
                        top: 0,
                        left: viewport / 2 - 1.5,
                        child: const IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: OmniColors.deepTeal,
                              borderRadius: BorderRadius.all(
                                Radius.circular(1.5),
                              ),
                            ),
                            child: SizedBox(width: 3, height: 44),
                          ),
                        ),
                      ),
                      const _SideFade(left: true),
                      const _SideFade(left: false),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  _RulerPainter({
    required this.min,
    required this.max,
    required this.spacing,
    required this.leading,
    required this.textScaler,
  });

  final int min;
  final int max;
  final double spacing;
  final double leading;
  final TextScaler textScaler;

  static const double _short = 14;
  static const double _medium = 22;
  static const double _long = 32;

  @override
  void paint(Canvas canvas, Size size) {
    final shortPaint = Paint()
      ..color = OmniColors.borderStrong
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final mediumPaint = Paint()
      ..color = OmniColors.textTertiary
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final longPaint = Paint()
      ..color = OmniColors.textSecondary
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (var unit = min; unit <= max; unit++) {
      final x = leading + (unit - min) * spacing;
      final isLong = unit % 10 == 0;
      final isMedium = !isLong && unit % 5 == 0;
      final length = isLong
          ? _long
          : isMedium
          ? _medium
          : _short;
      canvas.drawLine(
        Offset(x, 4),
        Offset(x, 4 + length),
        isLong
            ? longPaint
            : isMedium
            ? mediumPaint
            : shortPaint,
      );
      if (isLong) {
        final label = TextPainter(
          text: TextSpan(
            text: '$unit',
            style: const TextStyle(
              fontFamily: _bundledFont,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: OmniColors.textSecondary,
            ),
          ),
          textDirection: TextDirection.ltr,
          textScaler: textScaler,
        )..layout();
        label.paint(canvas, Offset(x - label.width / 2, 4 + _long + 6));
        label.dispose();
      }
    }
  }

  @override
  bool shouldRepaint(_RulerPainter old) =>
      old.min != min ||
      old.max != max ||
      old.spacing != spacing ||
      old.leading != leading ||
      old.textScaler != textScaler;
}

/// White fade on the left or right edge; no hit testing.
class _SideFade extends StatelessWidget {
  const _SideFade({required this.left});

  final bool left;

  static const double _width = 48;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      bottom: 0,
      left: left ? 0 : null,
      right: left ? null : 0,
      width: _width,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: left ? Alignment.centerLeft : Alignment.centerRight,
              end: left ? Alignment.centerRight : Alignment.centerLeft,
              colors: [
                OmniColors.surfacePrimary,
                OmniColors.surfacePrimary.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
