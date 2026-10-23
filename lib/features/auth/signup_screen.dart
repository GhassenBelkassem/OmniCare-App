import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../core/auth/google_web_sign_in_button.dart';
import '../../core/config/app_environment.dart';
import '../../core/theme/omni_theme.dart';
import '../../providers/user_provider.dart';
import '../../core/nav/keyboard_navigation.dart';
import 'application/auth_controller.dart';
import 'application/auth_flow_models.dart';
import 'login_screen.dart';
import 'phone_input_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  bool _isLoading = false;
  bool _showEmailForm = false;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _dateOfBirthController = TextEditingController();
  String? _gender;
  DateTime? _selectedDateOfBirth;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _rememberDevice = false;

  static const Color _primaryColor = OmniColors.freshMint;
  static const Color _textColor = OmniColors.textPrimary;
  static const Color _mutedTextColor = OmniColors.textSecondary;
  static const Color _borderColor = OmniColors.borderLight;

  static String _formatDobDisplay(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yyyy = date.year.toString().padLeft(4, '0');
    return '$dd/$mm/$yyyy';
  }

  static bool _isAtLeast18(DateTime dateOfBirth) {
    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;
    final hasHadBirthdayThisYear =
        (now.month > dateOfBirth.month) ||
        (now.month == dateOfBirth.month && now.day >= dateOfBirth.day);
    if (!hasHadBirthdayThisYear) {
      age -= 1;
    }
    return age >= 18;
  }

  InputDecoration _inputDecoration({
    required String labelText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      prefixIcon: Icon(prefixIcon, color: OmniColors.textSecondary, size: 20),
      suffixIcon: suffixIcon,
    );
  }

  @override
  void initState() {
    super.initState();
    _showEmailForm = true;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dateOfBirthController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleIdToken(String idToken) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    final auth = context.read<AuthController>();
    final success = await auth.startGoogleAuth(
      idToken,
      rememberDevice: _rememberDevice,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            auth.errorMessage ?? 'Inscription avec Google impossible.',
          ),
        ),
      );
      return;
    }

    if (auth.isAuthenticated) {
      await _routeAuthenticated(auth);
      return;
    }

    if (auth.hasPendingGoogleSignup) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PhoneInputScreen(
            mode: AuthFlowMode.signup,
            rememberDevice: _rememberDevice,
          ),
        ),
      );
    }
  }

  Future<void> _handleGoogleSignUp() async {
    if (kIsWeb) return;
    try {
      final account = await GoogleSignIn(scopes: const ['email']).signIn();
      final idToken = (await account?.authentication)?.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError('Google did not return an ID token.');
      }
      await _handleGoogleIdToken(idToken);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inscription avec Google impossible.')),
      );
    }
  }

  Future<void> _routeAuthenticated(AuthController auth) async {
    final profile = auth.patientProfile;
    final nextRoute = auth.nextRoute;
    if (profile == null || nextRoute == null) return;
    await dismissKeyboardBeforeNavigation(context);
    if (!mounted) return;
    context.read<UserProvider>().setPatientProfile(profile);
    Navigator.of(context).pushNamedAndRemoveUntil(nextRoute, (route) => false);
  }

  Future<void> _handleEmailSignUp() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    if ((_gender ?? '').trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez votre genre.')),
      );
      return;
    }

    if (_selectedDateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez votre date de naissance.')),
      );
      return;
    }

    if (!_isAtLeast18(_selectedDateOfBirth!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vous devez avoir au moins 18 ans pour créer un compte.',
          ),
        ),
      );
      return;
    }

    final draft = PhoneSignupDraft(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      dateOfBirth: _selectedDateOfBirth!,
      gender: _gender!,
    );

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhoneInputScreen(
          mode: AuthFlowMode.signup,
          signupDraft: draft,
          rememberDevice: _rememberDevice,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OmniColors.pageBackground,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Retour',
          onPressed: _isLoading ? null : () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Créer un compte patient'),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          top: false,
          child: Center(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(
                OmniSpacing.pageHorizontal,
                OmniSpacing.lg,
                OmniSpacing.pageHorizontal,
                OmniSpacing.xxl,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Votre compte patient',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: _textColor,
                          ),
                    ),
                    const SizedBox(height: OmniSpacing.sm),
                    Text(
                      'Renseignez vos informations pour commencer avec OmniCare.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        height: 1.45,
                        color: _mutedTextColor,
                      ),
                    ),
                    const SizedBox(height: OmniSpacing.xl),
                    _buildGoogleButton(),
                    const SizedBox(height: OmniSpacing.lg),
                    _buildDividerOr(),
                    const SizedBox(height: OmniSpacing.lg),
                    if (_showEmailForm) ...[
                      _buildEmailPasswordForm(),
                      const SizedBox(height: 8),
                      _buildRememberDeviceControl(),
                      const SizedBox(height: 18),
                    ],
                    _buildEmailButton(),
                    const SizedBox(height: 18),
                    _buildTermsSection(),
                    const SizedBox(height: 18),
                    _buildFooter(),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleEmailSignUp,
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              AppEnvironment.phoneVerificationEnabled
                  ? 'Vérifier le numéro de téléphone'
                  : 'Continuer',
            ),
    );
  }

  Widget _buildEmailPasswordForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              labelText: 'Adresse e-mail',
              prefixIcon: Icons.email_outlined,
            ),
            validator: (v) {
              final value = (v ?? '').trim();
              if (value.isEmpty) return 'Champ requis';
              final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
              if (!emailRegex.hasMatch(value)) return 'Adresse e-mail invalide';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              labelText: 'Mot de passe',
              prefixIcon: Icons.lock_outline,
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (v) {
              final value = v ?? '';
              if (value.isEmpty) return 'Champ requis';
              if (value.length < 12) return 'Utilisez au moins 12 caractères';
              if (value.length > 128) return 'Utilisez 128 caractères maximum';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              labelText: 'Confirmer le mot de passe',
              prefixIcon: Icons.lock_outline,
              suffixIcon: IconButton(
                onPressed: () {
                  setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  );
                },
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (v) {
              final value = v ?? '';
              if (value.isEmpty) return 'Champ requis';
              if (value != _passwordController.text) {
                return 'Les mots de passe ne correspondent pas';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final firstName = TextFormField(
                controller: _firstNameController,
                textInputAction: TextInputAction.next,
                decoration: _inputDecoration(
                  labelText: 'Prénom',
                  prefixIcon: Icons.person_outline,
                ),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return 'Champ requis';
                  return null;
                },
              );
              final lastName = TextFormField(
                controller: _lastNameController,
                textInputAction: TextInputAction.next,
                decoration: _inputDecoration(
                  labelText: 'Nom',
                  prefixIcon: Icons.person_outline,
                ),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return 'Champ requis';
                  return null;
                },
              );
              if (constraints.maxWidth < 390) {
                return Column(
                  children: [
                    firstName,
                    const SizedBox(height: OmniSpacing.md),
                    lastName,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: firstName),
                  const SizedBox(width: OmniSpacing.md),
                  Expanded(child: lastName),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _dateOfBirthController,
            readOnly: true,
            decoration: _inputDecoration(
              labelText: 'Date de naissance',
              prefixIcon: Icons.calendar_today_outlined,
            ),
            validator: (_) {
              if (_selectedDateOfBirth == null) return 'Champ requis';
              if (!_isAtLeast18(_selectedDateOfBirth!)) {
                return 'Vous devez avoir au moins 18 ans';
              }
              return null;
            },
            onTap: () async {
              final now = DateTime.now();
              final initial =
                  _selectedDateOfBirth ?? DateTime(now.year - 20, 1, 1);
              final picked = await showDatePicker(
                context: context,
                initialDate: initial,
                firstDate: DateTime(1900, 1, 1),
                lastDate: now,
              );
              if (picked != null && mounted) {
                setState(() {
                  _selectedDateOfBirth = picked;
                  _dateOfBirthController.text = _formatDobDisplay(picked);
                });
                _formKey.currentState?.validate();
              }
            },
          ),
          const SizedBox(height: 6),
          Text(
            'Vous devez avoir au moins 18 ans pour créer un compte.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: _mutedTextColor,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Genre',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _GenderCard(
                  label: 'Homme',
                  selected: _gender == 'M',
                  onTap: () => setState(() => _gender = 'M'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GenderCard(
                  label: 'Femme',
                  selected: _gender == 'F',
                  onTap: () => setState(() => _gender = 'F'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildRememberDeviceControl() {
    return CheckboxListTile(
      value: _rememberDevice,
      onChanged: _isLoading
          ? null
          : (value) => setState(() => _rememberDevice = value ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      dense: true,
      visualDensity: VisualDensity.compact,
      activeColor: _primaryColor,
      title: Text(
        'Faire confiance à cet appareil',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: _textColor,
        ),
      ),
      subtitle: Text(
        'À utiliser uniquement sur un appareil personnel.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontSize: 12, color: _mutedTextColor),
      ),
    );
  }

  Widget _buildDividerOr() {
    return Row(
      children: [
        const Expanded(child: Divider(color: _borderColor, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'ou',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 13,
              color: _mutedTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Expanded(child: Divider(color: _borderColor, thickness: 1)),
      ],
    );
  }

  Widget _buildGoogleButton() {
    if (kIsWeb) {
      return GoogleWebSignInButton(onIdToken: _handleGoogleIdToken);
    }

    return OutlinedButton.icon(
      onPressed: _isLoading ? null : _handleGoogleSignUp,
      icon: SvgPicture.asset(
        'assets/icons/google_logo.svg',
        width: 20,
        height: 20,
      ),
      label: const Text('Continuer avec Google'),
    );
  }

  Widget _buildTermsSection() {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        text: 'En créant un compte, vous acceptez nos ',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 13,
          height: 1.6,
          color: OmniColors.textTertiary,
        ),
        children: [
          TextSpan(
            text: 'conditions',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 13,
              height: 1.6,
              color: OmniColors.deepTeal,
            ),
          ),
          TextSpan(
            text: ' et notre ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 13,
              height: 1.6,
              color: OmniColors.textTertiary,
            ),
          ),
          TextSpan(
            text: 'politique de confidentialité',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 13,
              height: 1.6,
              color: OmniColors.deepTeal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return GestureDetector(
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      },
      child: RichText(
        text: TextSpan(
          text: 'Vous avez déjà un compte ? ',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            color: OmniColors.textSecondary,
          ),
          children: [
            TextSpan(
              text: 'Se connecter',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: OmniColors.deepTeal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenderCard extends StatelessWidget {
  const _GenderCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const primary = OmniColors.freshMint;
    const border = OmniColors.borderStrong;
    const text = OmniColors.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OmniRadii.field),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: OmniSpacing.md,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(OmniRadii.field),
            border: Border.all(
              color: selected ? primary : border,
              width: selected ? 2 : 1,
            ),
            color: selected ? OmniColors.mintSoft : Colors.white,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: text,
                  ),
                ),
              ),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? primary : border,
                    width: selected ? 5 : 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
