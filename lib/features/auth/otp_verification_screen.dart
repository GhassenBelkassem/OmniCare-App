import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/user_onboarding_provider.dart';
import '../../core/api/auth_api.dart';
import '../../core/api/api_error_utils.dart';
import '../../core/utils/logger.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String verificationType;
  final String contactInfo;
  final Future<void> Function() onVerified;

  const OtpVerificationScreen({
    super.key,
    required this.verificationType,
    required this.contactInfo,
    required this.onVerified,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );

  bool _isLoading = false;
  bool _verificationSucceeded = false;
  int _resendCountdown = 60;
  Timer? _timer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _resendCountdown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _verifyOtp() async {
    if (_isLoading || _verificationSucceeded) return;
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length != 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.verificationType == 'email') {
        AppLogger.api(
          'verifyEmailOtp enteredCode=$otp email=${widget.contactInfo}',
        );
        await AuthApi().verifyEmailOtp(
          email: widget.contactInfo,
          code: otp,
        );
      } else if (widget.verificationType == 'phone') {
        AppLogger.api(
          'verifyPhoneOtp enteredCode=$otp phoneNumber=${widget.contactInfo}',
        );
        await AuthApi().verifyPhoneOtp(
          phoneNumber: widget.contactInfo,
          otp: otp,
        );
      } else {
        await Future.delayed(const Duration(seconds: 2));
      }

      if (!mounted) return;

      _verificationSucceeded = true;

      final provider = Provider.of<UserOnboardingProvider>(context, listen: false);

      if (widget.verificationType == 'email') {
        provider.setEmailVerified(true);
      } else {
        provider.setPhoneVerified(true);
      }

      await widget.onVerified();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e, st) {
      AppLogger.error('OTP verification failed', e, st);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = apiErrorMessage(e);
      });
    }
  }

  Future<void> _resendCode() async {
    if (_resendCountdown > 0) return;

    setState(() => _isLoading = true);

    try {
      if (widget.verificationType == 'phone') {
        await AuthApi().requestPhoneOtp(phoneNumber: widget.contactInfo);
      } else {
        await Future.delayed(const Duration(seconds: 1));
      }

      if (!mounted) return;
      setState(() => _isLoading = false);
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification code sent!'),
          backgroundColor: Color(0xFF1FBF9A),
        ),
      );
    } catch (e, st) {
      AppLogger.error('Resend OTP failed', e, st);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = apiErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEmail = widget.verificationType == 'email';

    return Scaffold(
      resizeToAvoidBottomInset: false,
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
                    isEmail 
                      ? 'assets/images/email_verification.png'
                      : 'assets/images/phone_otp.png',
                    width: 160,
                    height: 160,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        isEmail ? Icons.email_rounded : Icons.sms_rounded,
                        size: 90,
                        color: const Color(0xFF1FBF9A),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isEmail ? 'Email Verification' : 'Phone Verification',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF101828),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'We sent a code to ${widget.contactInfo}',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF667085),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  return Container(
                    margin: EdgeInsets.only(
                      right: index < 5 ? 8 : 0,
                    ),
                    child: SizedBox(
                      width: 45,
                      height: 48,
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF101828),
                          height: 1.2,
                        ),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
                            borderSide: const BorderSide(
                              color: Color(0xFF1FBF9A),
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFDC2626)),
                          ),
                        ),
                        onChanged: (value) {
                          if (value.isNotEmpty && index < 5) {
                            _focusNodes[index + 1].requestFocus();
                          }
                          if (value.isEmpty && index > 0) {
                            _focusNodes[index - 1].requestFocus();
                          }
                          setState(() => _errorMessage = null);
                        },
                      ),
                    ),
                  );
                }),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: const Color(0xFFDC2626),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Edit phone number?',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: const Color(0xFF667085),
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: _resendCountdown == 0 ? _resendCode : null,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      _resendCountdown > 0
                          ? 'Send again (${_resendCountdown}s)'
                          : 'Send again',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _resendCountdown > 0
                            ? const Color(0xFF667085)
                            : const Color(0xFF1FBF9A),
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1FBF9A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    disabledBackgroundColor:
                        const Color(0xFF1FBF9A).withOpacity(0.5),
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
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          isEmail ? 'Verify Email' : 'Verify Phone Number',
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
    );
  }
}
