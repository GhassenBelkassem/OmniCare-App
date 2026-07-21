import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/user_onboarding_provider.dart';
import 'application/auth_controller.dart';
import 'application/auth_flow_models.dart';
import 'application/tunisian_phone_number.dart';
import 'otp_verification_screen.dart';

class PhoneInputScreen extends StatefulWidget {
  const PhoneInputScreen({
    super.key,
    required this.mode,
    this.signupDraft,
    this.rememberDevice = false,
  });

  final AuthFlowMode mode;
  final PhoneSignupDraft? signupDraft;
  final bool rememberDevice;

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    try {
      TunisianPhoneNumber.normalize(value);
      return null;
    } on PhoneNumberFormatException catch (e) {
      return e.message;
    }
  }

  Future<void> _submitPhone() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final phoneNumber = TunisianPhoneNumber.normalize(_phoneController.text);
      final onboardingProvider = Provider.of<UserOnboardingProvider>(
        context,
        listen: false,
      );
      onboardingProvider.setPhoneNumber(phoneNumber);

      final auth = context.read<AuthController>();
      final draft = widget.signupDraft;
      final success = widget.mode == AuthFlowMode.login
          ? await auth.startPhoneLogin(
              phoneNumber,
              rememberDevice: widget.rememberDevice,
            )
          : draft != null
          ? await auth.startPhoneSignup(
              draft,
              phoneNumber,
              rememberDevice: widget.rememberDevice,
            )
          : auth.hasPendingGoogleSignup &&
                await auth.startGooglePhoneSignup(phoneNumber);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (success) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpVerificationScreen(
              mode: widget.mode,
              contactInfo: phoneNumber,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(auth.errorMessage ?? 'Unable to send code.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF101828)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 4),
                // Illustration placeholder
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF9),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Image.asset(
                      'assets/images/phone_verification.png',
                      width: 160,
                      height: 160,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.phone_android_rounded,
                          size: 90,
                          color: const Color(0xFF1FBF9A),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.mode == AuthFlowMode.login
                      ? 'Phone Login'
                      : 'Phone Verification',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF101828),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.mode == AuthFlowMode.login
                      ? 'Enter your phone number to receive a login code.'
                      : 'We need to register your phone number before getting started!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Country code selector
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD0D5DD)),
                      ),
                      child: Row(
                        children: [
                          Text('🇹🇳', style: const TextStyle(fontSize: 24)),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_drop_down,
                            color: Color(0xFF667085),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Phone input
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFD0D5DD)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Text(
                                '+216',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF101828),
                                ),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 32,
                              color: const Color(0xFFD0D5DD),
                            ),
                            Expanded(
                              child: TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                validator: _validatePhone,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  color: const Color(0xFF101828),
                                ),
                                decoration: InputDecoration(
                                  hintText: '12 345 678',
                                  hintStyle: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    color: const Color(0xFF98A2B3),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitPhone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1FBF9A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      disabledBackgroundColor: const Color(
                        0xFF1FBF9A,
                      ).withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            'Send the Code',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
