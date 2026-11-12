import 'package:flutter/material.dart';

import '../../core/theme/omni_theme.dart';
import '../../core/widgets/omni_pressable.dart';
import '../../l10n/omni_localizations.dart';
import 'signup_screen.dart';
import 'widgets/auth_decorative_circles.dart';
import 'widgets/auth_prompt_link.dart';
import 'widgets/login_sheet.dart';
import 'widgets/omni_logo_badge.dart';

/// Bundled family (pubspec, weights 500–800). The theme's google_fonts
/// text styles keep their 400 face when only the weight changes.
const String _bundledFont = 'Plus Jakarta Sans';

/// Role-neutral entry: the backend resolves the workspace after authentication.
///
/// G3-P2a: this is now the welcome screen. « Se connecter » opens the login
/// form in a bottom sheet ([showLoginSheet]), which holds the sign-in logic
/// unchanged. Routes are unchanged (`/login`, `/auth-entry`,
/// `/professional-login`); on `/professional-login` the sheet opens by itself
/// after the first frame.
///
/// Layout: header at the top, free space, then the text block and the
/// actions anchored at the bottom (`SliverFillRemaining(hasScrollBody:
/// false)`), scrolling when the content is taller than the screen.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  static const String _professionalLoginRoute = '/professional-login';

  // Entrance: header fades 0–200 ms; the 5 blocks (chip, title, subtitle,
  // buttons, footer) fade + slide 12 px, 320 ms each, 60 ms apart, from
  // 140 ms → the last one ends at 700 ms.
  static const int _totalMs = 700;
  static const int _headerMs = 200;
  static const int _firstBlockMs = 140;
  static const int _blockMs = 320;
  static const int _staggerMs = 60;
  static const int _blockCount = 5;

  static final BoxShadow _ctaShadow = BoxShadow(
    color: Colors.black.withValues(alpha: 0.12),
    blurRadius: 12,
    offset: const Offset(0, 4),
  );
  static final BoxShadow _ctaHoverShadow = BoxShadow(
    color: Colors.black.withValues(alpha: 0.18),
    blurRadius: 24,
    offset: const Offset(0, 10),
  );
  static const double _buttonRadius = 14;
  static const double _maxContentWidth = 480;

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _totalMs),
  );
  late final CurvedAnimation _header = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0, _headerMs / _totalMs),
  );
  late final List<CurvedAnimation> _blocks = [
    for (var i = 0; i < _blockCount; i++)
      CurvedAnimation(
        parent: _entrance,
        curve: Interval(
          (_firstBlockMs + i * _staggerMs) / _totalMs,
          (_firstBlockMs + i * _staggerMs + _blockMs) / _totalMs,
          curve: Curves.easeOutCubic,
        ),
      ),
  ];

  bool _firstDependencies = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_firstDependencies) return;
    _firstDependencies = false;

    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _entrance.value = 1;
    } else {
      _entrance.forward();
    }

    if (ModalRoute.of(context)?.settings.name == _professionalLoginRoute) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showLoginSheet(context);
      });
    }
  }

  @override
  void dispose() {
    _header.dispose();
    for (final block in _blocks) {
      block.dispose();
    }
    _entrance.dispose();
    super.dispose();
  }

  void _openSignup() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SignupScreen()));
  }

  void _openProfessionalRequest() {
    Navigator.of(context).pushNamed('/professional-access-request');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = OmniLocalizations.of(context);
    return Scaffold(
      backgroundColor: OmniColors.deepTealActive,
      body: Stack(
        children: [
          const Positioned.fill(child: AuthDecorativeCircles()),
          SafeArea(
            // The side padding is computed here (not with a max-width box
            // inside the sliver) so SliverFillRemaining measures the column
            // at its real width (it sizes from the intrinsic height).
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side = ((constraints.maxWidth - _maxContentWidth) / 2)
                    .clamp(OmniSpacing.pageHorizontal, double.infinity);
                return CustomScrollView(
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          side,
                          OmniSpacing.base,
                          side,
                          OmniSpacing.xxl,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FadeTransition(
                              opacity: _header,
                              child: _WelcomeHeader(
                                brandName: l10n.welcomeBrandName,
                                logoLabel: l10n.authLogoLabel,
                              ),
                            ),
                            const Spacer(),
                            const SizedBox(height: OmniSpacing.xxxl),
                            ..._content(l10n),
                          ],
                        ),
                      ),
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

  List<Widget> _content(OmniLocalizations l10n) {
    return [
      _EntranceBlock(
        animation: _blocks[0],
        child: Align(
          alignment: Alignment.centerLeft,
          child: _AudienceChip(label: l10n.welcomeAudienceChip),
        ),
      ),
      const SizedBox(height: OmniSpacing.lg),
      _EntranceBlock(
        animation: _blocks[1],
        child: Text.rich(
          TextSpan(
            text: '${l10n.welcomeTitleLine1}\n',
            children: [
              TextSpan(
                text: l10n.welcomeTitleLine2,
                style: const TextStyle(color: OmniColors.freshMint),
              ),
            ],
          ),
          style: const TextStyle(
            fontFamily: _bundledFont,
            fontSize: 40,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            height: 1.1,
            color: OmniColors.textOnDark,
          ),
        ),
      ),
      const SizedBox(height: OmniSpacing.base),
      _EntranceBlock(
        animation: _blocks[2],
        child: Text(
          l10n.welcomeSubtitle,
          style: TextStyle(
            fontFamily: _bundledFont,
            fontSize: 16,
            height: 1.45,
            fontWeight: FontWeight.w500,
            color: OmniColors.textOnDark.withValues(alpha: 0.9),
          ),
        ),
      ),
      const SizedBox(height: OmniSpacing.xxl),
      _EntranceBlock(animation: _blocks[3], child: _actions(l10n)),
      const SizedBox(height: OmniSpacing.base),
      _EntranceBlock(
        animation: _blocks[4],
        child: AuthPromptLink(
          prompt: l10n.authProfessionalPrompt,
          action: l10n.authProfessionalAction,
          onTap: _openProfessionalRequest,
          promptColor: OmniColors.textOnDark.withValues(alpha: 0.88),
          actionColor: OmniColors.textOnDark,
        ),
      ),
    ];
  }

  Widget _actions(OmniLocalizations l10n) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_buttonRadius),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OmniPressable(
          borderRadius: _buttonRadius,
          shadow: _ctaShadow,
          hoverShadow: _ctaHoverShadow,
          builder: (context, states) => ElevatedButton(
            statesController: states,
            onPressed: OmniPressable.withHaptic(_openSignup),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              backgroundColor: OmniColors.surfacePrimary,
              foregroundColor: OmniColors.deepTeal,
              shape: shape,
            ).copyWith(overlayColor: OmniPressable.overlay(OmniColors.deepTeal)),
            child: Text(l10n.authCreateAccount),
          ),
        ),
        const SizedBox(height: OmniSpacing.md),
        OmniPressable(
          borderRadius: _buttonRadius,
          builder: (context, states) => OutlinedButton(
            statesController: states,
            onPressed: OmniPressable.withHaptic(() => showLoginSheet(context)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              backgroundColor: Colors.transparent,
              foregroundColor: OmniColors.textOnDark,
              side: BorderSide(
                color: OmniColors.textOnDark.withValues(alpha: 0.6),
                width: 1.25,
              ),
              shape: shape,
            ).copyWith(
              overlayColor: OmniPressable.overlay(OmniColors.textOnDark),
            ),
            child: Text(l10n.authSignIn),
          ),
        ),
      ],
    );
  }
}

/// Fades in and slides up 12 px with its [animation] (0 → 1).
class _EntranceBlock extends StatelessWidget {
  const _EntranceBlock({required this.animation, required this.child});

  static const double _slide = 12;

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, _slide * (1 - animation.value)),
          child: child,
        ),
        child: child,
      ),
    );
  }
}

/// Symbol in a 44 px white circle + « OmniCare ».
class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.brandName, required this.logoLabel});

  final String brandName;
  final String logoLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        OmniLogoBadge(size: 44, semanticLabel: logoLabel),
        const SizedBox(width: OmniSpacing.md),
        Flexible(
          child: Text(
            brandName,
            style: const TextStyle(
              fontFamily: _bundledFont,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: OmniColors.textOnDark,
            ),
          ),
        ),
      ],
    );
  }
}

/// « Médecins · Infirmiers · Kinés » pill.
class _AudienceChip extends StatelessWidget {
  const _AudienceChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: OmniSpacing.md,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: OmniColors.textOnDark.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(OmniRadii.pill),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: _bundledFont,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: OmniColors.textOnDark,
        ),
      ),
    );
  }
}
