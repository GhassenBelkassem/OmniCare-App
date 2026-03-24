import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../providers/user_onboarding_provider.dart';
import 'login_screen.dart';
import 'phone_input_screen.dart';
import 'otp_verification_screen.dart';
import 'medical_data_welcome_screen.dart';
import '../../core/api/auth_api.dart';
import '../../core/utils/logger.dart';
import '../../core/api/api_error_utils.dart';
import '../../providers/user_provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../../core/auth/google_web_sign_in_button.dart';

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
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _dateOfBirthController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _gender;
  DateTime? _selectedDateOfBirth;

  static const Color _primaryColor = Color(0xFF1FBF9A);
  static const Color _textColor = Color(0xFF101828);
  static const Color _mutedTextColor = Color(0xFF667085);
  static const Color _borderColor = Color(0xFFD0D5DD);
  static const Color _fieldFillColor = Color(0xFFF9FAFB);

  static String _formatDobDisplay(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yyyy = date.year.toString().padLeft(4, '0');
    return '$dd/$mm/$yyyy';
  }

  static String _formatDobIso(DateTime date) {
    final yyyy = date.year.toString().padLeft(4, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
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
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF98A2B3)),
      prefixIcon: Icon(prefixIcon, color: const Color(0xFF98A2B3)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _fieldFillColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primaryColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  void _navigateAfterAuth(BuildContext navContext, AuthLoginResult result) {
    final onboarding = navContext.read<UserOnboardingProvider>();
    onboarding.setEmail(result.email);
    if (result.phoneNumber != null && result.phoneNumber!.isNotEmpty) {
      onboarding.setPhoneNumber(result.phoneNumber!);
    }
    onboarding.setEmailVerified(result.emailVerified);
    onboarding.setPhoneVerified(result.phoneVerified);

    if (!result.phoneVerified) {
      Navigator.pushReplacement(
        navContext,
        MaterialPageRoute(builder: (context) => const PhoneInputScreen()),
      );
      return;
    }

    if (!result.onboardingComplete) {
      Navigator.pushReplacement(
        navContext,
        MaterialPageRoute(
          builder: (context) => const MedicalDataWelcomeScreen(),
        ),
      );
      return;
    }

    Navigator.pushReplacementNamed(navContext, '/home');
  }

  @override
  void initState() {
    super.initState();
    _showEmailForm = true;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dateOfBirthController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignUp() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please use the Google button to sign up on web.'),
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final googleSignIn = GoogleSignIn(scopes: <String>['email', 'profile']);
      final account = await googleSignIn.signIn();
      if (account == null) {
        return;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError('Google idToken is null');
      }

      final result = await AuthApi().googleLoginWithStatus(idToken: idToken);
      if (!mounted) return;
      _navigateAfterAuth(context, result);
    } catch (e, st) {
      AppLogger.error('Google sign-up failed', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign-up failed: ${apiErrorMessage(e)}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEmailSignUp() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    if ((_gender ?? '').trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your gender')),
      );
      return;
    }

    if (_selectedDateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your date of birth')),
      );
      return;
    }

    if (!_isAtLeast18(_selectedDateOfBirth!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You must be at least 18 years old to create an account',
          ),
        ),
      );
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final dateOfBirthIso = _formatDobIso(_selectedDateOfBirth!);

    final derivedName = [
      firstName,
      lastName,
    ].where((e) => e.trim().isNotEmpty).join(' ').trim();

    setState(() => _isLoading = true);
    try {
      await AuthApi().register(
        email: email,
        password: password,
        name: derivedName.isEmpty ? null : derivedName,
        firstName: firstName.isEmpty ? null : firstName,
        lastName: lastName.isEmpty ? null : lastName,
        gender: (_gender ?? '').trim().isEmpty ? null : _gender,
        dateOfBirth: dateOfBirthIso,
      );
      if (!mounted) return;
      Provider.of<UserOnboardingProvider>(
        context,
        listen: false,
      ).setEmail(email);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (otpContext) => OtpVerificationScreen(
            verificationType: 'email',
            contactInfo: email,
            onVerified: () async {
              final result = await AuthApi().loginWithStatus(
                email: email,
                password: password,
              );

              await otpContext.read<UserProvider>().refresh();
              _navigateAfterAuth(otpContext, result);
            },
          ),
        ),
      );
    } catch (e, st) {
      AppLogger.error('Register failed', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Register failed: ${apiErrorMessage(e)}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Create account',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: _textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Create an account to get started',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: _mutedTextColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildGoogleButton(),
                    const SizedBox(height: 16),
                    _buildDividerOr(),
                    const SizedBox(height: 16),
                    if (_showEmailForm) ...[
                      _buildEmailPasswordForm(),
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
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: Material(
        color: _primaryColor,
        borderRadius: BorderRadius.circular(12),
        elevation: 0,
        child: InkWell(
          onTap: _isLoading ? null : _handleEmailSignUp,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Create account',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailPasswordForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _firstNameController,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(
                    hintText: 'First name',
                    prefixIcon: Icons.person_outline,
                  ),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return 'Required';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _lastNameController,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(
                    hintText: 'Last name',
                    prefixIcon: Icons.person_outline,
                  ),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return 'Required';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _dateOfBirthController,
            readOnly: true,
            decoration: _inputDecoration(
              hintText: 'dd/mm/yyyy',
              prefixIcon: Icons.calendar_today_outlined,
            ),
            validator: (_) {
              if (_selectedDateOfBirth == null) return 'Required';
              if (!_isAtLeast18(_selectedDateOfBirth!)) {
                return 'You must be at least 18 years old';
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
            'You must be 18+ to create an account',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: _mutedTextColor,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Gender',
            style: GoogleFonts.plusJakartaSans(
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
                  label: 'Male',
                  selected: _gender == 'M',
                  onTap: () => setState(() => _gender = 'M'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GenderCard(
                  label: 'Female',
                  selected: _gender == 'F',
                  onTap: () => setState(() => _gender = 'F'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              hintText: 'Email',
              prefixIcon: Icons.email_outlined,
            ),
            validator: (v) {
              final value = (v ?? '').trim();
              if (value.isEmpty) return 'Required';
              if (!value.contains('@')) return 'Invalid email';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            decoration: _inputDecoration(
              hintText: 'Password',
              prefixIcon: Icons.lock_outline,
            ),
            validator: (v) {
              final value = v ?? '';
              if (value.isEmpty) return 'Required';
              if (value.length < 6)
                return 'Password must be at least 6 characters';
              return null;
            },
            onFieldSubmitted: (_) {
              if (!_isLoading) {
                _handleEmailSignUp();
              }
            },
          ),
        ],
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
            'Or',
            style: GoogleFonts.plusJakartaSans(
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
      return GoogleWebSignInButton(
        onIdToken: (idToken) async {
          setState(() => _isLoading = true);
          try {
            final result = await AuthApi().googleLoginWithStatus(
              idToken: idToken,
            );
            if (!mounted) return;
            _navigateAfterAuth(context, result);
          } catch (e, st) {
            AppLogger.error('Google web sign-up failed', e, st);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Google sign-up failed: ${apiErrorMessage(e)}'),
              ),
            );
          } finally {
            if (mounted) setState(() => _isLoading = false);
          }
        },
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 0,
        child: InkWell(
          onTap: _isLoading ? null : _handleGoogleSignUp,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: _borderColor),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _textColor.withOpacity(0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.string(
                  '''<svg width="20" height="20" viewBox="0 0 24 24">
                    <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z" fill="#4285F4"/>
                    <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
                    <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/>
                    <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
                  </svg>''',
                  width: 20,
                  height: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Continue with Google',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTermsSection() {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        text: 'By signing up, you agree to our ',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          height: 1.6,
          color: const Color(0xFF98A2B3),
        ),
        children: [
          TextSpan(
            text: 'Terms',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              height: 1.6,
              color: const Color(0xFF1FBF9A),
            ),
          ),
          TextSpan(
            text: ' and ',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              height: 1.6,
              color: const Color(0xFF98A2B3),
            ),
          ),
          TextSpan(
            text: 'Privacy Policy',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              height: 1.6,
              color: const Color(0xFF1FBF9A),
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
          text: 'Already have an account? ',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: const Color(0xFF667085),
          ),
          children: [
            TextSpan(
              text: 'Sign in',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1FBF9A),
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
    const primary = Color(0xFF1FBF9A);
    const border = Color(0xFFD0D5DD);
    const text = Color(0xFF101828);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? primary : border,
              width: selected ? 2 : 1,
            ),
            color: selected ? primary.withOpacity(0.08) : Colors.white,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
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
