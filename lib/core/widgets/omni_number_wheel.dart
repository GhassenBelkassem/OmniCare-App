import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/omni_localizations.dart';
import '../theme/omni_theme.dart';
import 'omni_pressable.dart';

/// Bundled family (pubspec, weights 500–800). The theme's google_fonts
/// text styles keep their 400 face when only the weight changes.
const String _bundledFont = 'Plus Jakarta Sans';

/// Single-column number wheel with a big readout above it (G3-ONB1), e.g.
/// a height in cm. Pure UI: the screen owns [value] and reacts in
/// [onChanged].
///
/// [value] may be null (nothing chosen yet): the readout shows « — », no
/// row is styled as selected, and the wheel rests on [initialPosition].
/// Positioning the wheel (first build, or a new [value] from the screen)
/// never calls [onChanged]; only a user scroll or tap does, with a
/// selection click haptic. A drag that ends where it started still picks
/// that row.
///
/// Screen readers get one slider (label [semanticLabel], value « 170 cm »
/// or « Non renseigné ») with increase / decrease actions.
class OmniNumberWheel extends StatefulWidget {
  const OmniNumberWheel({
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
  final int? value;
  final String unit;
  final ValueChanged<int> onChanged;

  /// Where the wheel rests while [value] is null (clamped to min..max).
  final int initialPosition;

  /// Name for screen readers (e.g. « Taille »).
  final String? semanticLabel;

  @override
  State<OmniNumberWheel> createState() => _OmniNumberWheelState();
}

class _OmniNumberWheelState extends State<OmniNumberWheel> {
  static const double _itemExtent = 56;
  static const int _visibleRows = 5;
  static const double _height = _itemExtent * _visibleRows;
  static const Duration _tapDuration = Duration(milliseconds: 200);

  late final FixedExtentScrollController _controller =
      FixedExtentScrollController(initialItem: _restingIndex());

  /// True between the start of a user drag and the end of its fling.
  bool _userScrolling = false;

  /// Row a tap is animating to; the screen's new [value] must not cut it.
  int? _tapTarget;

  int _indexOf(int number) => number.clamp(widget.min, widget.max) - widget.min;

  int _restingIndex() => _indexOf(widget.value ?? widget.initialPosition);

  @override
  void didUpdateWidget(OmniNumberWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final value = widget.value;
    if (value == null || value == oldWidget.value || _userScrolling) return;
    final target = _indexOf(value);
    if (target == _tapTarget) return;
    if (_controller.hasClients && _controller.selectedItem != target) {
      // Programmatic: no ScrollStart with drag details, so no onChanged.
      _controller.jumpToItem(target);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _emit(int number) {
    final next = number.clamp(widget.min, widget.max);
    if (next == widget.value) return;
    HapticFeedback.selectionClick();
    widget.onChanged(next);
  }

  void _onSelectedItemChanged(int index) {
    if (_userScrolling) _emit(widget.min + index);
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      _userScrolling = notification.dragDetails != null;
    } else if (notification is ScrollEndNotification) {
      if (_userScrolling && widget.value == null && _controller.hasClients) {
        _emit(widget.min + _controller.selectedItem);
      }
      _userScrolling = false;
      _tapTarget = null;
    }
    return false;
  }

  void _tapRow(int index) {
    _userScrolling = false;
    if (_controller.hasClients && _controller.selectedItem != index) {
      _tapTarget = index;
    }
    _emit(widget.min + index);
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _controller.jumpToItem(index);
    } else {
      _controller.animateToItem(
        index,
        duration: _tapDuration,
        curve: Curves.easeOut,
      );
    }
  }

  void _step(int delta) {
    final from = widget.value ?? widget.initialPosition;
    final next = (from + delta).clamp(widget.min, widget.max);
    _tapRow(_indexOf(next));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = OmniLocalizations.of(context);
    final value = widget.value;
    String spoken(int? number) =>
        number == null ? l10n.pickerNoValue : '$number ${widget.unit}';
    final base = value ?? widget.initialPosition;

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
            _Readout(value: value?.toString(), unit: widget.unit),
            const SizedBox(height: OmniSpacing.base),
            SizedBox(
              height: _height,
              child: Stack(
                children: [
                  // Selection band behind the centre row.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: (_height - _itemExtent) / 2,
                    height: _itemExtent,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        color: OmniColors.mintSoft,
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                      ),
                    ),
                  ),
                  NotificationListener<ScrollNotification>(
                    onNotification: _onScrollNotification,
                    child: ListWheelScrollView.useDelegate(
                      controller: _controller,
                      itemExtent: _itemExtent,
                      physics: const FixedExtentScrollPhysics(),
                      diameterRatio: 2.4,
                      onSelectedItemChanged: _onSelectedItemChanged,
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: widget.max - widget.min + 1,
                        builder: (context, index) => _WheelRow(
                          label: '${widget.min + index}',
                          selected: value != null && index == _indexOf(value),
                          onTap: () => _tapRow(index),
                        ),
                      ),
                    ),
                  ),
                  const _EdgeFade(top: true),
                  const _EdgeFade(top: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WheelRow extends StatelessWidget {
  const _WheelRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const radius = 14.0;
    return OmniPressable(
      borderRadius: radius,
      builder: (context, states) => Material(
        type: MaterialType.transparency,
        child: InkWell(
          statesController: states,
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          overlayColor: OmniPressable.overlay(OmniColors.deepTeal),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: _bundledFont,
                fontSize: selected ? 24 : 20,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected
                    ? OmniColors.textPrimary
                    : OmniColors.textTertiary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// White fade over the top or bottom rows; no hit testing.
class _EdgeFade extends StatelessWidget {
  const _EdgeFade({required this.top});

  final bool top;

  static const double _height = 72;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: top ? 0 : null,
      bottom: top ? null : 0,
      height: _height,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: top ? Alignment.topCenter : Alignment.bottomCenter,
              end: top ? Alignment.bottomCenter : Alignment.topCenter,
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

/// Big readout: value 56 w800 (« — » when null) + unit 20 w700.
class _Readout extends StatelessWidget {
  const _Readout({required this.value, required this.unit});

  final String? value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            value ?? '—',
            maxLines: 1,
            style: const TextStyle(
              fontFamily: _bundledFont,
              fontSize: 56,
              height: 1.1,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              color: OmniColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: OmniSpacing.sm),
        Text(
          unit,
          style: const TextStyle(
            fontFamily: _bundledFont,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: OmniColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
