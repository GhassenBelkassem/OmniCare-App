import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../providers/user_onboarding_provider.dart';
import '../../providers/user_provider.dart';
import 'phone_input_screen.dart';
import 'medical_data_welcome_screen.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';
import '../../core/api/auth_api.dart';
import '../../core/api/dio_client.dart';
import '../../core/utils/logger.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/api/api_error_utils.dart';
import 'package:flutter/foundation.dart';
import '../../core/auth/google_web_sign_in_button.dart';
import 'package:dio/dio.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  bool _showEmailForm = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  bool _devAccountsLoading = false;
  List<_DevAccount> _devAccounts = const [];

  void _fillDevCredentials({required String email}) {
    setState(() {
      _showEmailForm = true;
      _emailController.text = email;
      _passwordController.text = 'Passw0rd!123';
    });
  }

  Future<void> _loadDevAccounts() async {
    if (_devAccountsLoading) return;
    setState(() => _devAccountsLoading = true);

    try {
      final Dio dio = DioClient.instance.dio;
      final res = await dio.get('/auth/dev/accounts');
      final data = res.data;
      if (data is List) {
        final items = data
            .whereType<Map>()
            .map(
              (m) => _DevAccount(
                role: m['role']?.toString() ?? '',
                name: m['name']?.toString() ?? '',
                email: m['email']?.toString() ?? '',
              ),
            )
            .where((a) => a.email.trim().isNotEmpty)
            .toList();

        setState(() => _devAccounts = items);
      } else {
        setState(() => _devAccounts = const []);
      }
    } catch (e, st) {
      AppLogger.error('Failed to load dev accounts', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load dev accounts: ${apiErrorMessage(e)}'),
          ),
        );
      }
      setState(() => _devAccounts = const []);
    } finally {
      if (mounted) setState(() => _devAccountsLoading = false);
    }
  }

  Future<void> _pickDevAccount({required String role}) async {
    await _loadDevAccounts();
    if (!mounted) return;

    final wantedRole = role.trim().toUpperCase();
    final items = _devAccounts
        .where((a) => a.role.trim().toUpperCase() == wantedRole)
        .toList();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Text(
                  'Choose $wantedRole account',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF101828),
                  ),
                ),
              ),
              if (_devAccountsLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No $wantedRole accounts found. Seed first, then retry.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF667085),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final a = items[i];
                      return ListTile(
                        title: Text(
                          a.name.isNotEmpty ? a.name : a.email,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF101828),
                          ),
                        ),
                        subtitle: Text(
                          a.email,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF667085),
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          if (wantedRole == 'DOCTOR') {
                            _setActiveSimDoctor(email: a.email);
                          }
                          _fillDevCredentials(email: a.email);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _setActiveSimDoctor({required String email}) async {
    try {
      final Dio dio = DioClient.instance.dio;
      await dio.post('/auth/dev/active-doctor', data: {'email': email});
    } catch (e, st) {
      AppLogger.error('Failed to set active sim doctor', e, st);
    }
  }

  void _navigateAfterLogin(AuthLoginResult result) {
    if (!mounted) return;

    final onboarding = context.read<UserOnboardingProvider>();
    onboarding.setEmail(result.email);
    if (result.phoneNumber != null && result.phoneNumber!.isNotEmpty) {
      onboarding.setPhoneNumber(result.phoneNumber!);
    }
    onboarding.setEmailVerified(result.emailVerified);
    onboarding.setPhoneVerified(result.phoneVerified);

    final role = (context.read<UserProvider>().user?.role ?? '')
        .trim()
        .toUpperCase();
    final isProfessional =
        role == 'DOCTOR' ||
        role == 'NURSE' ||
        role == 'KINE' ||
        role == 'PSYCHIATRIST';
    if (isProfessional) {
      Navigator.pushReplacementNamed(context, '/doctor-dashboard');
      return;
    }

    if (!result.phoneVerified) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const PhoneInputScreen()),
      );
      return;
    }

    if (!result.onboardingComplete) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const MedicalDataWelcomeScreen(),
        ),
      );
      return;
    }

    Navigator.pushReplacementNamed(context, '/home');
  }

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
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please use the Google button to sign in on web.'),
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
      print(
        '[LoginScreen] JWT saved. Forcing UserProvider.refresh() before /home navigation...',
      );
      await context.read<UserProvider>().refresh();
      print('[LoginScreen] UserProvider.refresh() done. Navigating to /home');
      _navigateAfterLogin(result);
    } catch (e, st) {
      AppLogger.error('Google sign-in failed', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign-in failed: ${apiErrorMessage(e)}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleEmailSignIn() async {
    if (!_showEmailForm) {
      // Toggle to show the form
      setState(() => _showEmailForm = true);
    } else {
      // Handle actual sign in
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      if (email.isEmpty || password.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email and password are required')),
        );
        return;
      }

      setState(() => _isLoading = true);
      try {
        final result = await AuthApi().loginWithStatus(
          email: email,
          password: password,
        );
        if (!mounted) return;
        print(
          '[LoginScreen] JWT saved. Forcing UserProvider.refresh() before /home navigation...',
        );
        await context.read<UserProvider>().refresh();
        print('[LoginScreen] UserProvider.refresh() done. Navigating to /home');
        _navigateAfterLogin(result);
      } catch (e, st) {
        AppLogger.error('Login failed', e, st);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: ${apiErrorMessage(e)}')),
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
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

                                      if (kDebugMode) ...[
                                        _buildDevQuickFill(),
                                        const SizedBox(height: 12),
                                      ],

                                      // Email/Password Form (conditionally shown)
                                      if (_showEmailForm) ...[
                                        _buildEmailPasswordForm(),
                                        const SizedBox(height: 18),
                                      ],

                                      // Email Sign In Button
                                      _buildEmailButton(),
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

  Widget _buildDevQuickFill() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Dev quick fill',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF98A2B3),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading
                    ? null
                    : () => _pickDevAccount(role: 'PATIENT'),
                child: const Text('Pick Patient'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading
                    ? null
                    : () => _pickDevAccount(role: 'DOCTOR'),
                child: const Text('Pick Doctor'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGoogleButton() {
    if (kIsWeb) {
      return GoogleWebSignInButton(
        onIdToken: (idToken) async {
          setState(() => _isLoading = true);
          try {
            await AuthApi().googleLogin(idToken: idToken);
            if (!mounted) return;
            print(
              '[LoginScreen] (Web) JWT saved. Forcing UserProvider.refresh() before /home navigation...',
            );
            await context.read<UserProvider>().refresh();
            print(
              '[LoginScreen] (Web) UserProvider.refresh() done. Navigating to /home',
            );
            Navigator.pushReplacementNamed(context, '/home');
          } catch (e, st) {
            AppLogger.error('Google web sign-in failed', e, st);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Google sign-in failed: ${apiErrorMessage(e)}'),
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
          onTap: _isLoading ? null : _handleGoogleSignIn,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFD0D5DD)),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF101828).withOpacity(0.05),
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

  Widget _buildEmailButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: Material(
        color: const Color(0xFF1FBF9A),
        borderRadius: BorderRadius.circular(12),
        elevation: 0,
        child: InkWell(
          onTap: _isLoading ? null : _handleEmailSignIn,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF101828).withOpacity(0.05),
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
                      _showEmailForm ? 'Sign In' : 'Sign in with Email',
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

  Widget _buildEmailPasswordForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Email Input
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'Email',
            hintStyle: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF98A2B3),
            ),
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Password Input
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            hintText: 'Password',
            hintStyle: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF98A2B3),
            ),
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Forgot Password Link
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ForgotPasswordScreen()),
              );
            },
            child: Text(
              'Forgot password?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1FBF9A),
              ),
            ),
          ),
        ),
      ],
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

class _DevAccount {
  final String role;
  final String name;
  final String email;

  const _DevAccount({
    required this.role,
    required this.name,
    required this.email,
  });
}
