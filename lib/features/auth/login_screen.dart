import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../core/auth/google_web_sign_in_button.dart';
import '../../core/config/app_environment.dart';
import '../../core/theme/omni_theme.dart';
import 'application/auth_controller.dart';
import 'application/auth_flow_models.dart';
import 'application/post_auth_navigation.dart';
import 'google_account_link_sheet.dart';
import 'otp_verification_screen.dart';
import 'phone_input_screen.dart';
import 'signup_screen.dart';

/// Role-neutral entry: the backend resolves the workspace after authentication.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _rememberDevice = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Connexion impossible.')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Connexion Google impossible.'),
        ),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Sélectionnez à nouveau « Continuer avec Google ».',
              ),
            ),
          );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connexion Google impossible.')),
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OmniColors.pageBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(
              horizontal: OmniSpacing.pageHorizontal,
              vertical: OmniSpacing.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 156,
                      height: 58,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.local_hospital_outlined,
                        size: 48,
                        color: OmniColors.deepTeal,
                      ),
                    ),
                  ),
                  const SizedBox(height: OmniSpacing.xxl),
                  Text(
                    'Bienvenue',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: OmniColors.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: OmniSpacing.sm),
                  Text(
                    'Connectez-vous pour retrouver votre espace OmniCare.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      height: 1.45,
                      color: OmniColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: OmniSpacing.xxl),
                  _passwordForm(),
                  const SizedBox(height: OmniSpacing.xl),
                  _divider(),
                  const SizedBox(height: OmniSpacing.xl),
                  _googleButton(),
                  if (AppEnvironment.phoneVerificationEnabled) ...[
                    const SizedBox(height: OmniSpacing.md),
                    OutlinedButton(
                      onPressed: _loading ? null : _signInWithPhone,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.phone_outlined, size: 20),
                          SizedBox(width: OmniSpacing.sm),
                          Flexible(
                            child: Text(
                              'Continuer avec un numéro de téléphone',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: OmniSpacing.xl),
                  _patientSignupLink(),
                  const SizedBox(height: OmniSpacing.sm),
                  _professionalRequestLink(),
                  const SizedBox(height: OmniSpacing.sm),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _passwordForm() => Form(
    key: _formKey,
    child: Column(
      children: [
        TextFormField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          decoration: _decoration('E-mail', Icons.email_outlined),
          validator: (value) {
            final email = value?.trim() ?? '';
            if (email.isEmpty) return 'Adresse e-mail requise';
            return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
                ? null
                : 'Saisissez une adresse e-mail valide';
          },
        ),
        const SizedBox(height: OmniSpacing.md),
        TextFormField(
          controller: _password,
          obscureText: _obscurePassword,
          autofillHints: const [AutofillHints.password],
          onFieldSubmitted: (_) => _submitPassword(),
          decoration: _decoration('Mot de passe', Icons.lock_outline).copyWith(
            suffixIcon: IconButton(
              tooltip: _obscurePassword
                  ? 'Afficher le mot de passe'
                  : 'Masquer le mot de passe',
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          validator: (value) =>
              (value?.isEmpty ?? true) ? 'Mot de passe requis' : null,
        ),
        CheckboxListTile(
          value: _rememberDevice,
          onChanged: _loading
              ? null
              : (value) => setState(() => _rememberDevice = value ?? false),
          contentPadding: EdgeInsets.zero,
          dense: true,
          visualDensity: VisualDensity.compact,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            'Faire confiance à cet appareil',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: OmniColors.textPrimary,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submitPassword,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Se connecter'),
        ),
      ],
    ),
  );

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 20, color: OmniColors.textSecondary),
  );

  Widget _divider() => Row(
    children: [
      const Expanded(child: Divider()),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          'ou',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: OmniColors.textSecondary),
        ),
      ),
      const Expanded(child: Divider()),
    ],
  );

  Widget _googleButton() {
    if (kIsWeb) return GoogleWebSignInButton(onIdToken: _handleGoogleIdToken);
    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        onPressed: _loading ? null : _signInWithGoogle,
        icon: SvgPicture.asset(
          'assets/icons/google_logo.svg',
          width: 20,
          height: 20,
        ),
        label: const Text('Continuer avec Google'),
      ),
    );
  }

  Widget _patientSignupLink() => _link(
    prompt: 'Nouveau sur OmniCare ?',
    action: 'Créer un compte patient',
    onTap: () => Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SignupScreen())),
  );

  Widget _professionalRequestLink() => _link(
    prompt: 'Professionnel de santé ?',
    action: 'Demander à rejoindre OmniCare',
    onTap: () =>
        Navigator.of(context).pushNamed('/professional-access-request'),
  );

  Widget _link({
    required String prompt,
    required String action,
    required VoidCallback onTap,
  }) => Semantics(
    button: true,
    child: InkWell(
      onTap: _loading ? null : onTap,
      borderRadius: BorderRadius.circular(OmniRadii.field),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: OmniSpacing.sm),
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              color: OmniColors.textSecondary,
            ),
            children: [
              TextSpan(text: '$prompt '),
              TextSpan(
                text: action,
                style: const TextStyle(
                  color: OmniColors.deepTeal,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
