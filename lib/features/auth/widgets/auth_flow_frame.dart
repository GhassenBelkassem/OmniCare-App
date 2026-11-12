import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';
import '../../../l10n/omni_localizations.dart';

/// Bundled family (pubspec, weights 500–800). The theme's google_fonts
/// text styles keep their 400 face when only the weight changes.
const String _bundledFont = 'Plus Jakarta Sans';

/// Frame of the auth flow screens (sign-up steps, phone screen), G3-P2b.
///
/// * dark [OmniColors.deepTealActive] band (56 px below the safe area) with
///   back (« Retour »), [title] (16 w700) and close (« Fermer »);
/// * white panel, top radius 24: optional [progress], scrolling [body],
///   and [bottom] pinned at the bottom (the Scaffold resizes for the
///   keyboard, so it stays above it). Overflow guard (G3-P2c): the pinned
///   area takes at most half of the panel; when its content is taller
///   (keyboard open on a small phone, large text) it scrolls inside itself,
///   anchored at the bottom so the main button stays visible.
///
/// Pure UI: the screen passes every callback (null disables the button).
/// [showBack] false hides the back button (a screen with nothing to go back
/// to); [closeIcon] / [closeTooltip] replace the close button's icon and
/// tooltip (e.g. « Se déconnecter » on the forced password change), G3-P2c.
class AuthFlowFrame extends StatelessWidget {
  const AuthFlowFrame({
    super.key,
    required this.title,
    required this.onBack,
    required this.onClose,
    required this.body,
    required this.bottom,
    this.progress,
    this.showBack = true,
    this.closeIcon,
    this.closeTooltip,
  });

  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onClose;
  final Widget? progress;
  final Widget body;
  final Widget bottom;
  final bool showBack;
  final IconData? closeIcon;
  final String? closeTooltip;

  static const double _headerHeight = 56;
  static const double _maxContentWidth = 480;
  static const double _maxBottomShare = 0.5;

  @override
  Widget build(BuildContext context) {
    final l10n = OmniLocalizations.of(context);
    return Scaffold(
      backgroundColor: OmniColors.deepTealActive,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: _headerHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.xs),
                child: Row(
                  children: [
                    if (showBack)
                      _HeaderIcon(
                        icon: Icons.arrow_back_rounded,
                        tooltip: l10n.authBack,
                        onPressed: onBack,
                      )
                    else
                      // Keeps the title centred.
                      const SizedBox(width: _HeaderIcon.size),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: _bundledFont,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: OmniColors.textOnDark,
                        ),
                      ),
                    ),
                    _HeaderIcon(
                      icon: closeIcon ?? Icons.close_rounded,
                      tooltip: closeTooltip ?? l10n.commonClose,
                      onPressed: onClose,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(OmniRadii.sheet),
                ),
                child: ColoredBox(
                  color: OmniColors.surfacePrimary,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final side =
                          ((constraints.maxWidth - _maxContentWidth) / 2).clamp(
                            OmniSpacing.pageHorizontal,
                            double.infinity,
                          );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (progress != null)
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                side,
                                OmniSpacing.lg,
                                side,
                                0,
                              ),
                              child: progress,
                            ),
                          Expanded(
                            child: SingleChildScrollView(
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: EdgeInsets.fromLTRB(
                                side,
                                OmniSpacing.xl,
                                side,
                                OmniSpacing.xl,
                              ),
                              child: body,
                            ),
                          ),
                          DecoratedBox(
                            decoration: const BoxDecoration(
                              color: OmniColors.surfacePrimary,
                              border: Border(
                                top: BorderSide(color: OmniColors.borderLight),
                              ),
                            ),
                            child: SafeArea(
                              top: false,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight:
                                      constraints.maxHeight * _maxBottomShare,
                                ),
                                child: SingleChildScrollView(
                                  reverse: true,
                                  physics: const ClampingScrollPhysics(),
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      side,
                                      OmniSpacing.md,
                                      side,
                                      OmniSpacing.base,
                                    ),
                                    child: bottom,
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Default IconButton footprint (24 px icon + 8 px padding on each side).
  static const double size = 48;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      color: OmniColors.textOnDark,
      disabledColor: OmniColors.textOnDark.withValues(alpha: 0.4),
      icon: Icon(icon),
    );
  }
}
