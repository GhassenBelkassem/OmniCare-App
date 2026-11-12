import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/omni_theme.dart';
import '../../../core/widgets/omni_pressable.dart';
import '../../../l10n/omni_localizations.dart';

/// Google brand colors for a self-built « Continuer avec Google » button
/// (light theme spec: white fill, 1 px #747775 stroke, #1F1F1F text).
/// https://developers.google.com/identity/branding-guidelines
/// These are the only hex literals allowed outside `OmniColors`.
const Color _googleStroke = Color(0xFF747775);
const Color _googleText = Color(0xFF1F1F1F);

/// « Continuer avec Google » button for Android / iOS / desktop.
///
/// Visual only: the screen passes its existing Google handler in
/// [onPressed] (null disables the button). The web build keeps the
/// Google-rendered GIS button (`GoogleWebSignInButton`).
class GoogleBrandButton extends StatelessWidget {
  const GoogleBrandButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  static const double _height = 52;
  static const double _radius = 14;
  static const double _logoSize = 20;

  static const double _disabledOpacity = 0.6;

  @override
  Widget build(BuildContext context) {
    // Disabled (e.g. while a sign-in runs): the brand look is kept and the
    // whole button is shown at 60 % opacity.
    // Press scale, focus ring and 10 / 6 / 10 % state layers come from
    // OmniPressable (same feedback as the other auth buttons).
    return Opacity(
      opacity: onPressed == null ? _disabledOpacity : 1,
      child: OmniPressable(
        borderRadius: _radius,
        builder: (context, states) => _button(context, states),
      ),
    );
  }

  Widget _button(BuildContext context, WidgetStatesController states) {
    return OutlinedButton(
      onPressed: onPressed,
      statesController: states,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, _height),
        backgroundColor: OmniColors.surfacePrimary,
        foregroundColor: _googleText,
        disabledBackgroundColor: OmniColors.surfacePrimary,
        disabledForegroundColor: _googleText,
        side: const BorderSide(color: _googleStroke),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
      ).copyWith(overlayColor: OmniPressable.overlay(_googleText)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ExcludeSemantics(
            child: SvgPicture.asset(
              'assets/icons/google_logo.svg',
              width: _logoSize,
              height: _logoSize,
            ),
          ),
          const SizedBox(width: OmniSpacing.md),
          Flexible(
            child: Text(
              OmniLocalizations.of(context).authContinueWithGoogle,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
