import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../theme/omni_theme.dart';

/// Builds the tappable child. Pass [states] to the child's
/// `statesController` (Material buttons, [InkWell]) so this wrapper can
/// follow its pressed / hovered / focused states.
typedef OmniPressableBuilder =
    Widget Function(BuildContext context, WidgetStatesController states);

/// Adds OmniCare press feedback around a Material button or [InkWell]:
///
/// * press: scale to 0.98 in 100 ms (easeOut), back on release / cancel;
/// * hover (web / desktop): optional shadow change in 150 ms;
/// * keyboard focus: 2 px [OmniColors.freshMint] ring, 2 px outside the
///   child, radius = child radius + offset;
/// * reduced motion (`MediaQueryData.disableAnimations`): no scale and no
///   shadow animation; state layers and the focus ring stay.
///
/// The child keeps its own Material state layers, cursor, semantics and
/// focus handling. Use [overlay] for the 10 % / 6 % / 10 % layers and
/// [withHaptic] for the main actions.
///
/// Docs: api.flutter.dev — WidgetStatesController, WidgetStateProperty,
/// AnimatedScale, MediaQueryData.disableAnimations.
class OmniPressable extends StatefulWidget {
  const OmniPressable({
    super.key,
    required this.builder,
    required this.borderRadius,
    this.shadow,
    this.hoverShadow,
  });

  final OmniPressableBuilder builder;

  /// Corner radius of the child; the focus ring follows it.
  final double borderRadius;

  /// Resting shadow (optional). With [hoverShadow], animates on hover.
  final BoxShadow? shadow;
  final BoxShadow? hoverShadow;

  static const double pressedScale = 0.98;
  static const Duration pressDuration = Duration(milliseconds: 100);
  static const Duration hoverDuration = Duration(milliseconds: 150);
  static const double _ringWidth = 2;
  static const double _ringOffset = 2;

  /// State layer: pressed 10 %, hovered 6 %, focused 10 % of [color].
  static WidgetStateProperty<Color?> overlay(Color color) =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return color.withValues(alpha: 0.10);
        }
        if (states.contains(WidgetState.hovered)) {
          return color.withValues(alpha: 0.06);
        }
        if (states.contains(WidgetState.focused)) {
          return color.withValues(alpha: 0.10);
        }
        return null;
      });

  /// [action] preceded by a light haptic tap on Android / iOS only.
  /// Returns null when [action] is null (disabled stays disabled).
  static VoidCallback? withHaptic(VoidCallback? action) {
    if (action == null) return null;
    return () {
      final mobile =
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);
      if (mobile) HapticFeedback.lightImpact();
      action();
    };
  }

  @override
  State<OmniPressable> createState() => _OmniPressableState();
}

class _OmniPressableState extends State<OmniPressable> {
  static const Set<WidgetState> _tracked = {
    WidgetState.pressed,
    WidgetState.hovered,
    WidgetState.focused,
  };

  final WidgetStatesController _states = WidgetStatesController();
  Set<WidgetState> _visible = const {};

  @override
  void initState() {
    super.initState();
    _states.addListener(_onStatesChanged);
  }

  @override
  void dispose() {
    _states.removeListener(_onStatesChanged);
    _states.dispose();
    super.dispose();
  }

  void _onStatesChanged() {
    final next = _states.value.intersection(_tracked);
    if (setEquals(next, _visible)) return;
    _visible = next;
    // Buttons may update their states while they build (e.g. disabled →
    // pressed cleared): rebuild after the frame in that case.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final pressed = _visible.contains(WidgetState.pressed);
    final hovered = _visible.contains(WidgetState.hovered);
    final focused = _visible.contains(WidgetState.focused);
    final radius = BorderRadius.circular(widget.borderRadius);

    Widget child = widget.builder(context, _states);

    final shadow = widget.shadow;
    if (shadow != null) {
      final hoverShadow = widget.hoverShadow ?? shadow;
      child = AnimatedContainer(
        duration: reduceMotion ? Duration.zero : OmniPressable.hoverDuration,
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [hovered ? hoverShadow : shadow],
        ),
        child: child,
      );
    }

    const inset = -(OmniPressable._ringOffset + OmniPressable._ringWidth);
    child = Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (focused)
          Positioned(
            left: inset,
            top: inset,
            right: inset,
            bottom: inset,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    widget.borderRadius - inset,
                  ),
                  border: Border.all(
                    color: OmniColors.freshMint,
                    width: OmniPressable._ringWidth,
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    return AnimatedScale(
      scale: pressed && !reduceMotion ? OmniPressable.pressedScale : 1,
      duration: reduceMotion ? Duration.zero : OmniPressable.pressDuration,
      curve: Curves.easeOut,
      child: child,
    );
  }
}
