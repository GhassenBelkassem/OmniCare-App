import 'dart:ui' show SemanticsRole;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/google_web_sign_in_button.dart';
import '../../../core/config/app_environment.dart';
import '../../../core/theme/omni_theme.dart';
import '../../../core/widgets/omni_pressable.dart';
import '../../../core/widgets/omni_text_field.dart';
import '../../../l10n/omni_localizations.dart';
import '../application/auth_controller.dart';
import '../application/auth_flow_models.dart';
import '../application/post_auth_navigation.dart';
import '../google_account_link_sheet.dart';
import '../otp_verification_screen.dart';
import '../phone_input_screen.dart';
import '../signup_screen.dart';
import 'auth_prompt_link.dart';
import 'google_brand_button.dart';
import 'omni_logo_badge.dart';
import 'trusted_device_switch.dart';

/// Bundled family (pubspec, weights 500–800). The theme's google_fonts
/// text styles keep their 400 face when only the weight changes.
const String _bundledFont = 'Plus Jakarta Sans';

/// Opens the e-mail / Google login form in a modal bottom sheet (G3-P2a).
///
/// Drag-to-close is off and back / barrier taps / the close button are
/// refused while a sign-in runs or once the account is authenticated: the
/// sign-in logic below stops at `if (!mounted) return;`, so closing the
/// sheet mid-request would drop the post-login navigation. The sheet
/// otherwise closes with back, a tap above it, or the × button.
Future<void> showLoginSheet(BuildContext context) {
  final maxHeight = MediaQuery.sizeOf(context).height * 0.92;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: false,
    showDragHandle: false,
    constraints: BoxConstraints(maxHeight: maxHeight),
    builder: (_) => const LoginSheet(),
  );
}

/// Login form shown by [showLoginSheet].
///
/// Its State holds the former `LoginScreen` sign-in logic unchanged
/// (`login_screen.dart:41-167` before G3-P2a): same controller calls, same
/// order, same OTP / Google / account-link routing, same messages. Changes:
/// failure messages appear in an inline banner instead of a SnackBar (a
/// SnackBar would sit behind the modal sheet), their French text comes from
/// the ARB (same wording), and the web « select Google again » hint is a
/// neutral note.
class LoginSheet extends StatefulWidget {
  const LoginSheet({super.key});

  @override
  State<LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends State<LoginSheet>
    with SingleTickerProviderStateMixin {
  static const double _logoSize = 76;
  static const double _buttonRadius = 14;

  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _rememberDevice = false;
  String? _errorMessage;
  String? _hintMessage;

  // Logo badge: scale 0.9 → 1 + fade, 200 ms, once the sheet is open.
  late final AnimationController _badge = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  late final CurvedAnimation _badgeCurve = CurvedAnimation(
    parent: _badge,
    curve: Curves.easeOut,
  );
  late final Animation<double> _badgeScale = Tween<double>(
    begin: 0.9,
    end: 1,
  ).animate(_badgeCurve);
  Animation<double>? _routeAnimation;
  bool _firstDependencies = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_firstDependencies) return;
    _firstDependencies = false;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final route = ModalRoute.of(context)?.animation;
    if (reduceMotion || route == null || route.isCompleted) {
      if (reduceMotion) {
        _badge.value = 1;
      } else {
        _badge.forward();
      }
      return;
    }
    _routeAnimation = route..addStatusListener(_onRouteStatus);
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _routeAnimation = null;
    if (mounted) _badge.forward();
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _badgeCurve.dispose();
    _badge.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _hintMessage = null;
    });
  }

  void _showHint(String message) {
    setState(() {
      _hintMessage = message;
      _errorMessage = null;
    });
  }

  void _clearMessages(String _) {
    if (_errorMessage == null && _hintMessage == null) return;
    setState(() {
      _errorMessage = null;
      _hintMessage = null;
    });
  }

  // ── Sign-in logic moved verbatim from login_screen.dart:41-167 ──────────
  // Only changes: `showSnackBar(X)` → `_showError(X)` (web retry note →
  // `_showHint`), and the hardcoded French fallbacks read from the ARB with
  // the same wording.

  Future<void> _submitPassword() async {
    if (!(_formKey.currentState?.validate() ?? false) || _loading) return;
    setState(() => _loading = true);
    final auth = context.read<AuthController>();
    final success = await auth.loginWithEmailPassword(
      _email.text,
      _password.text,
      rememberDevice: _rememberDevice,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (!success) {
      _showError(
        auth.errorMessage(OmniLocalizations.of(context)) ??
            OmniLocalizations.of(context).authLoginFailed,
      );
      return;
    }
    if (auth.isAuthenticated) {
      await navigateAfterAuthentication(context, auth);
      return;
    }
    if (auth.pendingFlow == AuthFlowMode.login && auth.pendingPhone != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            mode: AuthFlowMode.login,
            contactInfo: auth.pendingPhone!,
          ),
        ),
      );
    }
  }

  Future<void> _handleGoogleIdToken(String idToken) async {
    if (_loading) return;
    setState(() => _loading = true);
    final auth = context.read<AuthController>();
    final success = await auth.startGoogleAuth(
      idToken,
      rememberDevice: _rememberDevice,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (!success) {
      _showError(
        auth.errorMessage(OmniLocalizations.of(context)) ??
            OmniLocalizations.of(context).authGoogleLoginFailed,
      );
      return;
    }
    if (auth.isAuthenticated) {
      await navigateAfterAuthentication(context, auth);
      return;
    }
    if (auth.hasPendingGoogleAccountLink) {
      final action = await showModalBottomSheet<GoogleAccountLinkAction>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        builder: (_) => const GoogleAccountLinkSheet(),
      );
      if (!mounted) return;
      if (action == GoogleAccountLinkAction.linked) {
        await navigateAfterAuthentication(context, auth);
      } else if (action == GoogleAccountLinkAction.retryGoogle) {
        if (kIsWeb) {
          _showHint(OmniLocalizations.of(context).authGoogleRetryHint);
        } else {
          await _signInWithGoogle();
        }
      }
      return;
    }
    if (auth.hasPendingGoogleSignup) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PhoneInputScreen(
            mode: AuthFlowMode.signup,
            rememberDevice: _rememberDevice,
          ),
        ),
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    if (kIsWeb) return;
    try {
      final token = await context.read<AuthController>().requestGoogleIdToken();
      if (token == null || token.isEmpty) {
        throw StateError('No Google ID token');
      }
      await _handleGoogleIdToken(token);
    } catch (_) {
      if (!mounted) return;
      _showError(OmniLocalizations.of(context).authGoogleLoginFailed);
    }
  }

  Future<void> _signInWithPhone() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhoneInputScreen(
          mode: AuthFlowMode.login,
          rememberDevice: _rememberDevice,
        ),
      ),
    );
  }

  // ── End of moved logic ──────────────────────────────────────────────────

  /// Same destination as the former « Créer un compte patient » link. The
  /// sheet closes first so the stack stays « login → sign-up » as before.
  void _openSignup() {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(MaterialPageRoute(builder: (_) => const SignupScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = OmniLocalizations.of(context);
    final authenticated = context.watch<AuthController>().isAuthenticated;
    // One guard for back, a tap above the sheet and the × button.
    final canClose = !_loading && !authenticated;

    return PopScope(
      canPop: canClose,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(
                OmniSpacing.pageHorizontal,
                _logoSize / 2 + OmniSpacing.base,
                OmniSpacing.pageHorizontal,
                OmniSpacing.xl,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(l10n),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: OmniSpacing.lg),
                        _MessageBanner.error(message: _errorMessage!),
                      ],
                      if (_hintMessage != null) ...[
                        const SizedBox(height: OmniSpacing.lg),
                        _MessageBanner.hint(message: _hintMessage!),
                      ],
                      const SizedBox(height: OmniSpacing.xl),
                      _passwordForm(l10n),
                      const SizedBox(height: OmniSpacing.lg),
                      _OrDivider(label: l10n.authOrDivider),
                      const SizedBox(height: OmniSpacing.lg),
                      _googleButton(),
                      if (AppEnvironment.phoneVerificationEnabled) ...[
                        const SizedBox(height: OmniSpacing.md),
                        OmniPressable(
                          borderRadius: _buttonRadius,
                          builder: (context, states) => OutlinedButton.icon(
                            statesController: states,
                            onPressed: _loading ? null : _signInWithPhone,
                            style: ButtonStyle(
                              overlayColor: OmniPressable.overlay(
                                OmniColors.slateBlue,
                              ),
                            ),
                            icon: const Icon(Icons.phone_outlined, size: 20),
                            label: Text(
                              l10n.authPhoneLogin,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: OmniSpacing.base),
                      AuthPromptLink(
                        prompt: l10n.authNewToOmniCare,
                        action: l10n.authCreateAccount,
                        onTap: _loading ? null : _openSignup,
                        promptColor: OmniColors.textSecondary,
                        actionColor: OmniColors.deepTeal,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -_logoSize / 2,
              left: 0,
              right: 0,
              child: Center(
                child: FadeTransition(
                  opacity: _badgeCurve,
                  child: ScaleTransition(
                    scale: _badgeScale,
                    child: OmniLogoBadge(
                      size: _logoSize,
                      semanticLabel: l10n.authLogoLabel,
                      shadow: OmniColors.shadowSm,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: OmniSpacing.xs,
              right: OmniSpacing.xs,
              child: IconButton(
                tooltip: l10n.commonClose,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                color: OmniColors.textSecondary,
                onPressed: canClose ? () => Navigator.of(context).pop() : null,
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(OmniLocalizations l10n) {
    return Column(
      children: [
        Text(
          l10n.loginSheetTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: _bundledFont,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: OmniColors.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: OmniSpacing.sm),
        Text(
          l10n.loginSheetSubtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: _bundledFont,
            fontSize: 14,
            height: 1.45,
            fontWeight: FontWeight.w500,
            color: OmniColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _passwordForm(OmniLocalizations l10n) => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OmniTextField(
          label: l10n.authEmailLabel,
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          prefixIcon: Icons.email_outlined,
          onChanged: _clearMessages,
          // Rule unchanged (former login_screen.dart:269-275); text from ARB.
          validator: (value) {
            final email = value?.trim() ?? '';
            if (email.isEmpty) return l10n.authEmailRequired;
            return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
                ? null
                : l10n.authEmailInvalid;
          },
        ),
        const SizedBox(height: OmniSpacing.base),
        OmniTextField(
          label: l10n.authPasswordLabel,
          controller: _password,
          obscureText: _obscurePassword,
          autofillHints: const [AutofillHints.password],
          prefixIcon: Icons.lock_outline,
          onChanged: _clearMessages,
          onFieldSubmitted: (_) => _submitPassword(),
          suffix: IconButton(
            tooltip: _obscurePassword
                ? l10n.authShowPassword
                : l10n.authHidePassword,
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
          // Rule unchanged (former login_screen.dart:297-298); text from ARB.
          validator: (value) =>
              (value?.isEmpty ?? true) ? l10n.authPasswordMissing : null,
        ),
        const SizedBox(height: OmniSpacing.base),
        TrustedDeviceSwitch(
          value: _rememberDevice,
          onChanged: _loading
              ? null
              : (value) => setState(() => _rememberDevice = value),
        ),
        const SizedBox(height: OmniSpacing.lg),
        OmniPressable(
          borderRadius: _buttonRadius,
          builder: (context, states) => ElevatedButton(
            statesController: states,
            onPressed: _loading
                ? null
                : OmniPressable.withHaptic(_submitPassword),
            // The global primary theme only sets a pressed layer; add the
            // hover / focus layers locally (white on action teal).
            style: ButtonStyle(
              overlayColor: OmniPressable.overlay(OmniColors.textOnDark),
            ),
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: OmniColors.textOnDark,
                    ),
                  )
                : Text(l10n.authSignIn),
          ),
        ),
      ],
    ),
  );

  Widget _googleButton() {
    if (kIsWeb) return GoogleWebSignInButton(onIdToken: _handleGoogleIdToken);
    return GoogleBrandButton(onPressed: _loading ? null : _signInWithGoogle);
  }
}

/// Inline message: red alert for failures, neutral note for hints.
class _MessageBanner extends StatelessWidget {
  const _MessageBanner.error({required this.message}) : _isError = true;
  const _MessageBanner.hint({required this.message}) : _isError = false;

  final String message;
  final bool _isError;

  @override
  Widget build(BuildContext context) {
    final foreground = _isError ? OmniColors.error : OmniColors.textSecondary;
    final banner = Container(
      padding: const EdgeInsets.all(OmniSpacing.md),
      decoration: BoxDecoration(
        color: _isError ? OmniColors.errorSoft : OmniColors.slateSoft,
        borderRadius: BorderRadius.circular(OmniRadii.field),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Icon(
              _isError
                  ? Icons.error_outline_rounded
                  : Icons.info_outline_rounded,
              size: 20,
              color: foreground,
            ),
          ),
          const SizedBox(width: OmniSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: _bundledFont,
                fontSize: 13,
                height: 1.4,
                fontWeight: _isError ? FontWeight.w600 : FontWeight.w500,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
    if (!_isError) return banner;
    return Semantics(role: SemanticsRole.alert, container: true, child: banner);
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: _bundledFont,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: OmniColors.textSecondary,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
