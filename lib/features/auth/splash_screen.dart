import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../core/theme/omni_theme.dart';
import '../../core/widgets/omni_pressable.dart';
import '../../l10n/omni_localizations.dart';
import '../../providers/user_provider.dart';
import 'application/auth_controller.dart';
import 'application/post_auth_navigation.dart';
import 'widgets/auth_decorative_circles.dart';
import 'widgets/omni_logo_badge.dart';

/// Bundled family (pubspec, weights 500–800). The theme's google_fonts
/// text styles keep their 400 face when only the weight changes.
const String _bundledFont = 'Plus Jakarta Sans';

/// Splash (G3-P2c restyle, logic unchanged): same dark background and
/// circles as the welcome screen, logo badge + « OmniCare », a small white
/// spinner, or a white card with the retry button when the saved session
/// could not be checked.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const double _maxContentWidth = 480;
  static const Duration _logoFade = Duration(milliseconds: 200);

  bool _navigationScheduled = false;

  @override
  void initState() {
    super.initState();
  }

  void _routeFor(AuthController auth) {
    if (_navigationScheduled || !auth.initializationCompleted) return;

    if (auth.status == AuthStatus.failure ||
        auth.status == AuthStatus.initializing) {
      return;
    }

    _navigationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      if (auth.isAuthenticated) {
        await navigateAfterAuthentication(
          context,
          auth,
          dismissKeyboard: false,
        );
        return;
      }

      Navigator.of(context).pushReplacementNamed('/login');
    });
  }

  Future<void> _retry() async {
    _navigationScheduled = false;
    await context.read<AuthController>().initialize();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    _routeFor(auth);

    final initializationFailed =
        auth.initializationCompleted && auth.status == AuthStatus.failure;
    // Nullable lookup: like the former splash, this screen must also build
    // where the app's localizations are not installed (some routing tests
    // mount it in a bare MaterialApp). It then shows the spinner only.
    final l10n = Localizations.of<OmniLocalizations>(
      context,
      OmniLocalizations,
    );
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final Widget brand = l10n == null
        ? const SizedBox.shrink()
        : _Brand(logoLabel: l10n.authLogoLabel, name: l10n.welcomeBrandName);

    return Scaffold(
      backgroundColor: OmniColors.deepTealActive,
      body: Stack(
        children: [
          const Positioned.fill(child: AuthDecorativeCircles()),
          SafeArea(
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
                          OmniSpacing.xl,
                          side,
                          OmniSpacing.xl,
                        ),
                        child: Column(
                          children: [
                            const Spacer(flex: 2),
                            if (reduceMotion)
                              brand
                            else
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: 1),
                                duration: _logoFade,
                                curve: Curves.easeOut,
                                builder: (context, value, child) =>
                                    Opacity(opacity: value, child: child),
                                child: brand,
                              ),
                            const Spacer(flex: 2),
                            if (initializationFailed && l10n != null)
                              _SessionErrorCard(
                                message: l10n.splashSessionError,
                                retryLabel: l10n.splashRetry,
                                onRetry: _retry,
                              )
                            else
                              const SizedBox.square(
                                dimension: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: OmniColors.textOnDark,
                                ),
                              ),
                            if (kDebugMode) ...[
                              const SizedBox(height: OmniSpacing.base),
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: OmniColors.textOnDark,
                                  minimumSize: const Size(44, 44),
                                ),
                                onPressed: () async {
                                  await context.read<AuthController>().logout();
                                  if (!context.mounted) return;
                                  await context.read<UserProvider>().logout();
                                  if (!context.mounted) return;
                                  Navigator.of(
                                    context,
                                  ).pushReplacementNamed('/login');
                                },
                                child: const Text(
                                  'Clear Local Session',
                                  style: TextStyle(
                                    fontFamily: _bundledFont,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            const Spacer(),
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
}

/// Logo badge (72 px) + « OmniCare ».
class _Brand extends StatelessWidget {
  const _Brand({required this.logoLabel, required this.name});

  final String logoLabel;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        OmniLogoBadge(size: 72, padding: 8, semanticLabel: logoLabel),
        const SizedBox(height: OmniSpacing.md),
        Text(
          name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: _bundledFont,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: OmniColors.textOnDark,
          ),
        ),
      ],
    );
  }
}

/// White card: offline icon, message and the retry button (same key and
/// same action as before).
class _SessionErrorCard extends StatelessWidget {
  const _SessionErrorCard({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(OmniSpacing.lg),
      decoration: BoxDecoration(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.circular(OmniRadii.card),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ExcludeSemantics(
            child: Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: OmniColors.textSecondary,
            ),
          ),
          const SizedBox(height: OmniSpacing.md),
          Semantics(
            liveRegion: true,
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: _bundledFont,
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: OmniColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: OmniSpacing.lg),
          OmniPressable(
            borderRadius: 14,
            builder: (context, states) => ElevatedButton(
              key: const Key('splash-retry-session'),
              statesController: states,
              onPressed: onRetry,
              style: ButtonStyle(
                overlayColor: OmniPressable.overlay(OmniColors.textOnDark),
              ),
              child: Text(
                retryLabel,
                style: const TextStyle(
                  fontFamily: _bundledFont,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
