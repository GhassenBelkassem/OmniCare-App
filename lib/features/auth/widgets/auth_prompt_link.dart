import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';
import '../../../core/widgets/omni_pressable.dart';

/// Bundled family (pubspec, weights 500–800). The theme's google_fonts
/// text styles keep their 400 face when only the weight changes.
const String _bundledFont = 'Plus Jakarta Sans';

/// « Prompt ? **Action** » one-line link (welcome footer, login-sheet footer).
///
/// The text is one [RichText] made of `'$prompt '` + [action], the same
/// structure as the former login screen (tests find the full sentence).
/// [onTap] null disables it (e.g. while a sign-in is running).
///
/// Feedback: state layer of [actionColor] (pressed 10 %, hover 6 %,
/// focus 10 %) on its own transparent Material, click cursor, action
/// underlined on hover, focus ring and press scale via [OmniPressable].
class AuthPromptLink extends StatelessWidget {
  const AuthPromptLink({
    super.key,
    required this.prompt,
    required this.action,
    required this.onTap,
    required this.promptColor,
    required this.actionColor,
  });

  final String prompt;
  final String action;
  final VoidCallback? onTap;
  final Color promptColor;
  final Color actionColor;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(OmniRadii.field);
    return OmniPressable(
      borderRadius: OmniRadii.field,
      builder: (context, states) {
        final hovered = states.value.contains(WidgetState.hovered);
        return Semantics(
          button: true,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              statesController: states,
              borderRadius: borderRadius,
              mouseCursor: onTap == null
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.click,
              overlayColor: OmniPressable.overlay(actionColor),
              splashColor: actionColor.withValues(alpha: 0.10),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: OmniSpacing.sm,
                    vertical: OmniSpacing.sm,
                  ),
                  child: Center(
                    child: RichText(
                      textAlign: TextAlign.center,
                      textScaler: MediaQuery.textScalerOf(context),
                      text: TextSpan(
                        style: TextStyle(
                          fontFamily: _bundledFont,
                          fontSize: 14,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                          color: promptColor,
                        ),
                        children: [
                          TextSpan(text: '$prompt '),
                          TextSpan(
                            text: action,
                            style: TextStyle(
                              color: actionColor,
                              fontWeight: FontWeight.w700,
                              decoration: hovered
                                  ? TextDecoration.underline
                                  : TextDecoration.none,
                              decorationColor: actionColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
