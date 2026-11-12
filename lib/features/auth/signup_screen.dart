import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/google_web_sign_in_button.dart';
import '../../core/config/app_environment.dart';
import '../../core/theme/omni_theme.dart';
import '../../core/widgets/omni_birth_date_picker.dart';
import '../../core/widgets/omni_pressable.dart';
import '../../core/widgets/omni_segmented_choice.dart';
import '../../core/widgets/omni_step_progress.dart';
import '../../core/widgets/omni_text_field.dart';
import '../../providers/user_provider.dart';
import '../../core/nav/keyboard_navigation.dart';
import 'application/auth_controller.dart';
import 'application/auth_flow_models.dart';
import 'login_screen.dart';
import 'phone_input_screen.dart';
import 'widgets/auth_flow_frame.dart';
import 'widgets/auth_prompt_link.dart';
import 'widgets/google_brand_button.dart';
import 'widgets/password_rule_chip.dart';
import 'widgets/trusted_device_switch.dart';
import '../../l10n/omni_localizations.dart';

/// Bundled family (pubspec, weights 500–800). The theme's google_fonts
/// text styles keep their 400 face when only the weight changes.
const String _bundledFont = 'Plus Jakarta Sans';

/// Patient sign-up (G3-P2b): step 1 « Compte », step 2 « Identité » here;
/// step 3 « Téléphone » is [PhoneInputScreen] (pushed exactly as before).
///
/// Behaviour unchanged: same validator rules, same [PhoneSignupDraft], same
/// controller calls and navigation. The phone step may return 0 or 1
/// (« Modifier » in its summary) to reopen step 1 or 2 with values kept.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // Same limits as before (server: SignupCompleteRequest 12–128).
  static const int _passwordMinLength = 12;
  static const int _passwordMaxLength = 128;
  static const int _emailMaxLength = 255;
  static const int _nameMaxLength = 100;
  static const int _stepCount = 3;
  static const double _buttonRadius = 14;

  bool _isLoading = false;
  int _step = 0;
  final GlobalKey<FormState> _accountFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _identityFormKey = GlobalKey<FormState>();
  final GlobalKey<FormFieldState<String>> _confirmFieldKey =
      GlobalKey<FormFieldState<String>>();
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
  bool _accountSubmitted = false;
  String? _genderError;
  String? _dateOfBirthError;

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

  /// Latest birth date [_isAtLeast18] accepts today: the picker's upper
  /// limit. Derived from the rule itself (handles 29 February).
  static DateTime _latestAdultBirthDate() {
    final now = DateTime.now();
    var candidate = DateTime(now.year - 18, now.month, now.day);
    while (!_isAtLeast18(candidate)) {
      candidate = DateTime(candidate.year, candidate.month, candidate.day - 1);
    }
    return candidate;
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

  // ── Google sign-up: unchanged ────────────────────────────────────────────

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
      _showSnackBar(
        auth.errorMessage(OmniLocalizations.of(context)) ??
            OmniLocalizations.of(context).signupGoogleFailed,
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
      final idToken = await context
          .read<AuthController>()
          .requestGoogleIdToken();
      if (idToken == null || idToken.isEmpty) {
        throw StateError('Google did not return an ID token.');
      }
      await _handleGoogleIdToken(idToken);
    } catch (_) {
      if (!mounted) return;
      _showSnackBar(OmniLocalizations.of(context).signupGoogleFailed);
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: _bundledFont,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ── Step 1 → step 2 ─────────────────────────────────────────────────────

  /// Validates step 1 only; on failure every step-1 error is shown.
  void _continueFromAccount() {
    final isValid = _accountFormKey.currentState?.validate() ?? false;
    setState(() => _accountSubmitted = true);
    if (!isValid) return;
    FocusScope.of(context).unfocus();
    setState(() => _step = 1);
  }

  // ── Step 2 → phone step: same checks, same draft as before ──────────────

  Future<void> _handleEmailSignUp() async {
    final isValid = _identityFormKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    final l10n = OmniLocalizations.of(context);
    if ((_gender ?? '').trim().isEmpty) {
      setState(() => _genderError = l10n.signupSelectGender);
      return;
    }

    if (_selectedDateOfBirth == null) {
      setState(() => _dateOfBirthError = l10n.signupSelectBirthDate);
      return;
    }

    if (!_isAtLeast18(_selectedDateOfBirth!)) {
      setState(() => _dateOfBirthError = l10n.signupAgeRequirement);
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
    // The phone step returns 0 / 1 when « Modifier » asks for step 1 / 2.
    final editStep = await Navigator.push<int>(
      context,
      MaterialPageRoute<int>(
        builder: (context) => PhoneInputScreen(
          mode: AuthFlowMode.signup,
          signupDraft: draft,
          rememberDevice: _rememberDevice,
        ),
      ),
    );
    if (!mounted || editStep == null) return;
    setState(() => _step = editStep.clamp(0, 1));
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final initial = _selectedDateOfBirth ?? DateTime(now.year - 20, 1, 1);
    final picked = await showOmniBirthDatePicker(
      context,
      initialDate: initial,
      firstDate: DateTime(1900, 1, 1),
      lastDate: _latestAdultBirthDate(),
      lastDateError: OmniLocalizations.of(context).signupAgeRequirement,
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDateOfBirth = picked;
        _dateOfBirthController.text = _formatDobDisplay(picked);
        _dateOfBirthError = null;
      });
      _identityFormKey.currentState?.validate();
    }
  }

  // ── Navigation of the frame ─────────────────────────────────────────────

  void _back() {
    if (_step > 0) {
      setState(() => _step = 0);
      return;
    }
    Navigator.of(context).maybePop();
  }

  /// Back to the welcome screen (first route), whatever the step.
  void _close() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = OmniLocalizations.of(context);
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final stepName = _step == 0
        ? l10n.signupStepAccount
        : l10n.signupStepIdentity;

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0) setState(() => _step = 0);
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: AuthFlowFrame(
          title: l10n.signupTitle,
          onBack: _isLoading ? null : _back,
          onClose: _isLoading ? null : _close,
          progress: OmniStepProgress(
            current: _step + 1,
            total: _stepCount,
            stepName: stepName,
          ),
          body: AnimatedSwitcher(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topCenter,
              children: [...previous, ?current],
            ),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: AnimatedBuilder(
                animation: animation,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, 16 * (1 - animation.value)),
                  child: child,
                ),
                child: child,
              ),
            ),
            child: _step == 0
                ? KeyedSubtree(
                    key: const ValueKey('signup-step-account'),
                    child: _accountStep(l10n),
                  )
                : KeyedSubtree(
                    key: const ValueKey('signup-step-identity'),
                    child: _identityStep(l10n),
                  ),
          ),
          bottom: OmniPressable(
            borderRadius: _buttonRadius,
            builder: (context, states) => ElevatedButton(
              statesController: states,
              onPressed: _isLoading
                  ? null
                  : OmniPressable.withHaptic(
                      _step == 0 ? _continueFromAccount : _handleEmailSignUp,
                    ),
              style: ButtonStyle(
                overlayColor: OmniPressable.overlay(OmniColors.textOnDark),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: OmniColors.textOnDark,
                      ),
                    )
                  : Text(l10n.authContinue),
            ),
          ),
        ),
      ),
    );
  }

  // ── Step 1 « Compte » ───────────────────────────────────────────────────

  Widget _accountStep(OmniLocalizations l10n) {
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    final ruleState = password.length >= _passwordMinLength
        ? PasswordRuleState.met
        : _accountSubmitted
        ? PasswordRuleState.failed
        : PasswordRuleState.idle;
    final passwordsMatch = confirm.isNotEmpty && confirm == password;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepTitle(
          title: l10n.signupAccountTitle,
          subtitle: l10n.signupAccountSubtitle,
        ),
        const SizedBox(height: OmniSpacing.xl),
        _buildGoogleButton(),
        const SizedBox(height: OmniSpacing.lg),
        _DividerLabel(label: l10n.signupOrWithEmail),
        const SizedBox(height: OmniSpacing.lg),
        Form(
          key: _accountFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OmniTextField(
                label: l10n.authEmailLabel,
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                prefixIcon: Icons.email_outlined,
                maxLength: _emailMaxLength,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return l10n.signupFieldRequired;
                  final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                  if (!emailRegex.hasMatch(value)) {
                    return l10n.signupEmailInvalid;
                  }
                  return null;
                },
              ),
              const SizedBox(height: OmniSpacing.base),
              OmniTextField(
                label: l10n.authPasswordLabel,
                controller: _passwordController,
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                prefixIcon: Icons.lock_outline,
                maxLength: _passwordMaxLength,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                onChanged: (_) {
                  setState(() {});
                  if (_confirmPasswordController.text.isNotEmpty) {
                    _confirmFieldKey.currentState?.validate();
                  }
                },
                suffix: _eyeToggle(
                  l10n,
                  obscured: _obscurePassword,
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                validator: (v) {
                  final value = v ?? '';
                  if (value.isEmpty) return l10n.signupFieldRequired;
                  if (value.length < _passwordMinLength) {
                    return l10n.signupPasswordTooShort;
                  }
                  if (value.length > _passwordMaxLength) {
                    return l10n.signupPasswordTooLong;
                  }
                  return null;
                },
              ),
              const SizedBox(height: OmniSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: PasswordRuleChip(
                  label: l10n.signupPasswordRuleMinLength,
                  state: ruleState,
                ),
              ),
              const SizedBox(height: OmniSpacing.base),
              OmniTextField(
                fieldKey: _confirmFieldKey,
                label: l10n.signupConfirmPasswordLabel,
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                prefixIcon: Icons.lock_outline,
                maxLength: _passwordMaxLength,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                onChanged: (_) => setState(() {}),
                onFieldSubmitted: (_) => _continueFromAccount(),
                isSuccess: passwordsMatch,
                successText: l10n.signupPasswordsMatch,
                suffix: _eyeToggle(
                  l10n,
                  obscured: _obscureConfirmPassword,
                  onPressed: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  ),
                ),
                validator: (v) {
                  final value = v ?? '';
                  if (value.isEmpty) return l10n.signupFieldRequired;
                  if (value != _passwordController.text) {
                    return l10n.passwordsNotMatch;
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: OmniSpacing.lg),
        AuthPromptLink(
          prompt: l10n.signupHaveAccount,
          action: l10n.authSignIn,
          onTap: _isLoading
              ? null
              : () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                ),
          promptColor: OmniColors.textSecondary,
          actionColor: OmniColors.deepTeal,
        ),
      ],
    );
  }

  Widget _eyeToggle(
    OmniLocalizations l10n, {
    required bool obscured,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: obscured ? l10n.authShowPassword : l10n.authHidePassword,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      onPressed: onPressed,
      icon: Icon(
        obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      ),
    );
  }

  Widget _buildGoogleButton() {
    if (kIsWeb) {
      return GoogleWebSignInButton(onIdToken: _handleGoogleIdToken);
    }
    return GoogleBrandButton(
      onPressed: _isLoading ? null : _handleGoogleSignUp,
    );
  }

  // ── Step 2 « Identité » ─────────────────────────────────────────────────

  Widget _identityStep(OmniLocalizations l10n) {
    return Form(
      key: _identityFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepTitle(
            title: l10n.signupIdentityTitle,
            subtitle: l10n.signupIdentitySubtitle,
          ),
          const SizedBox(height: OmniSpacing.xl),
          LayoutBuilder(
            builder: (context, constraints) {
              final firstName = OmniTextField(
                label: l10n.signupFirstNameLabel,
                controller: _firstNameController,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.givenName],
                maxLength: _nameMaxLength,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return l10n.signupFieldRequired;
                  return null;
                },
              );
              final lastName = OmniTextField(
                label: l10n.signupLastNameLabel,
                controller: _lastNameController,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.familyName],
                maxLength: _nameMaxLength,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return l10n.signupFieldRequired;
                  return null;
                },
              );
              // Same responsive rule as before: stacked below 390 px.
              if (constraints.maxWidth < 390) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    firstName,
                    const SizedBox(height: OmniSpacing.base),
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
          const SizedBox(height: OmniSpacing.base),
          OmniTextField(
            label: l10n.birthDatePickerTitle,
            controller: _dateOfBirthController,
            readOnly: true,
            prefixIcon: Icons.calendar_today_outlined,
            helperText: l10n.signupAgeRequirement,
            onTap: _pickDateOfBirth,
            validator: (_) {
              if (_selectedDateOfBirth == null) {
                return l10n.signupFieldRequired;
              }
              if (!_isAtLeast18(_selectedDateOfBirth!)) {
                return l10n.signupAgeTooYoung;
              }
              return null;
            },
          ),
          if (_dateOfBirthError != null) ...[
            const SizedBox(height: 6),
            _InlineError(message: _dateOfBirthError!),
          ],
          const SizedBox(height: OmniSpacing.base),
          Text(
            l10n.signupGenderLabel,
            style: const TextStyle(
              fontFamily: _bundledFont,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: OmniColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          OmniSegmentedChoice<String>(
            semanticLabel: l10n.signupGenderLabel,
            options: [
              OmniChoiceOption(value: 'M', label: l10n.signupGenderMale),
              OmniChoiceOption(value: 'F', label: l10n.signupGenderFemale),
            ],
            value: _gender,
            errorText: _genderError,
            onChanged: (value) => setState(() {
              _gender = value;
              _genderError = null;
            }),
          ),
          // Same flag as the login: the server only keeps the trust when the
          // phone is verified. Hidden otherwise (same value, false, is sent).
          if (AppEnvironment.phoneVerificationEnabled) ...[
            const SizedBox(height: OmniSpacing.lg),
            TrustedDeviceSwitch(
              value: _rememberDevice,
              onChanged: _isLoading
                  ? null
                  : (value) => setState(() => _rememberDevice = value),
            ),
          ],
        ],
      ),
    );
  }
}

/// Step title (24 w800) + subtitle (14 w500).
class _StepTitle extends StatelessWidget {
  const _StepTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: _bundledFont,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: OmniColors.textPrimary,
          ),
        ),
        const SizedBox(height: OmniSpacing.sm),
        Text(
          subtitle,
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
}

class _DividerLabel extends StatelessWidget {
  const _DividerLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    // The label may take up to 70 % of the row and wraps (large text).
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          const Expanded(child: Divider()),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.7),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.md),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: _bundledFont,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: OmniColors.textSecondary,
                ),
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Text(
        message,
        style: const TextStyle(
          fontFamily: _bundledFont,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: OmniColors.error,
        ),
      ),
    );
  }
}
