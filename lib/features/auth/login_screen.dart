import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../core/auth/google_web_sign_in_button.dart';
import '../../providers/user_provider.dart';
import 'application/auth_controller.dart';
import 'application/auth_flow_models.dart';
import 'otp_verification_screen.dart';
import 'phone_input_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  final GlobalKey<FormState> _emailLoginFormKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberDevice = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Cubic(0.16, 1, 0.3, 1),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 20), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Cubic(0.16, 1, 0.3, 1),
          ),
        );

    _scaleAnimation = Tween<double>(begin: 1.1, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Cubic(0.16, 1, 0.3, 1),
      ),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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
        SnackBar(content: Text(auth.errorMessage ?? 'Google sign-in failed.')),
      );
      return;
    }

    if (auth.isAuthenticated) {
      _routeAuthenticated(auth);
      return;
    }

    if (auth.hasPendingGoogleSignup) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              const PhoneInputScreen(mode: AuthFlowMode.signup),
        ),
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Google sign-in failed.')));
    }
  }

  Future<void> _handlePhoneSignIn() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhoneInputScreen(
          mode: AuthFlowMode.login,
          rememberDevice: _rememberDevice,
        ),
      ),
    );
  }

  Future<void> _handleEmailPasswordSignIn() async {
    final isValid = _emailLoginFormKey.currentState?.validate() ?? false;
    if (!isValid || _isLoading) return;

    setState(() => _isLoading = true);
    final auth = context.read<AuthController>();
    final success = await auth.loginWithEmailPassword(
      _emailController.text,
      _passwordController.text,
      rememberDevice: _rememberDevice,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Sign-in failed.')),
      );
      return;
    }

    if (auth.isAuthenticated) {
      _routeAuthenticated(auth);
      return;
    }

    if (auth.pendingFlow == AuthFlowMode.login && auth.pendingPhone != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtpVerificationScreen(
            mode: AuthFlowMode.login,
            contactInfo: auth.pendingPhone!,
          ),
        ),
      );
    }
  }

  void _routeAuthenticated(AuthController auth) {
    final profile = auth.patientProfile;
    final nextRoute = auth.nextRoute;
    if (profile == null || nextRoute == null) return;
    context.read<UserProvider>().setPatientProfile(profile);
    Navigator.of(context).pushNamedAndRemoveUntil(nextRoute, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Hero Image Section with Gradient Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: screenHeight * 0.35,
            child: AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          'https://images.unsplash.com/photo-1659353888357-75e5858a5bc5?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w3Nzg4Nzd8MHwxfHNlYXJjaHwxfHxtb2Rlcm4lMjBoZWFsdGhjYXJlJTIwbWVkaWNhbCUyMHByb2Zlc3Npb25hbCUyMGNsZWFufGVufDF8fHx8MTc3MjI0MTMzNXww&ixlib=rb-4.1.0&q=80&w=1080',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(color: const Color(0xFF1FBF9A));
                          },
                        ),
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color.fromRGBO(0, 0, 0, 0.2),
                                Color.fromRGBO(0, 0, 0, 0),
                                Color.fromRGBO(255, 255, 255, 1),
                              ],
                              stops: [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Content Section
          Positioned.fill(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SafeArea(
                child: Column(
                  children: [
                    SizedBox(height: screenHeight * 0.35 - 40),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: AnimatedBuilder(
                          animation: _slideAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: _slideAnimation.value,
                              child: FadeTransition(
                                opacity: _fadeAnimation,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    maxWidth: 384,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: Column(
                                    children: [
                                      // Title Section
                                      Text(
                                        'Welcome back',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.5,
                                          color: const Color(0xFF101828),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Sign in to continue to OmniCare',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                          color: const Color(0xFF667085),
                                        ),
                                      ),
                                      const SizedBox(height: 32),

                                      // Google Button
                                      _buildGoogleButton(),
                                      const SizedBox(height: 20),

                                      // Divider
                                      _buildDivider(),
                                      const SizedBox(height: 20),

                                      _buildEmailPasswordForm(),
                                      const SizedBox(height: 16),

                                      _buildPhoneButton(),
                                      const SizedBox(height: 24),

                                      // Footer
                                      _buildFooter(),
                                      const SizedBox(height: 24),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleButton() {
    if (kIsWeb) {
      return GoogleWebSignInButton(onIdToken: _handleGoogleIdToken);
    }

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 0,
        child: InkWell(
          onTap: _isLoading ? null : _handleGoogleSignIn,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD0D5DD)),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF101828).withValues(alpha: 0.05),
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
                    color: const Color(0xFF101828),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFEAECF0), thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF98A2B3),
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFEAECF0), thickness: 1)),
      ],
    );
  }

  Widget _buildPhoneButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: Material(
        color: const Color(0xFF1FBF9A),
        borderRadius: BorderRadius.circular(12),
        elevation: 0,
        child: InkWell(
          onTap: _isLoading ? null : _handlePhoneSignIn,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF101828).withValues(alpha: 0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
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
                      'Continue with phone',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _loginInputDecoration({
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
      fillColor: const Color(0xFFF9FAFB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1FBF9A), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildEmailPasswordForm() {
    return Form(
      key: _emailLoginFormKey,
      child: Column(
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            decoration: _loginInputDecoration(
              hintText: 'Email address',
              prefixIcon: Icons.email_outlined,
            ),
            validator: (v) {
              final value = (v ?? '').trim();
              if (value.isEmpty) return 'Required';
              final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
              if (!emailRegex.hasMatch(value)) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleEmailPasswordSignIn(),
            decoration: _loginInputDecoration(
              hintText: 'Password',
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
              if ((v ?? '').isEmpty) return 'Required';
              return null;
            },
          ),
          const SizedBox(height: 12),
          _buildRememberDeviceControl(),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _isLoading ? null : _handleEmailPasswordSignIn,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1FBF9A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Sign in',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
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
      activeColor: const Color(0xFF1FBF9A),
      title: Text(
        'Trust this browser',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF101828),
        ),
      ),
      subtitle: Text(
        'Use only on a private device.',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          color: const Color(0xFF667085),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SignupScreen()),
        );
      },
      child: RichText(
        text: TextSpan(
          text: "Don't have an account? ",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: const Color(0xFF667085),
          ),
          children: [
            TextSpan(
              text: 'Sign up',
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
