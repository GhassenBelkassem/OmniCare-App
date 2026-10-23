import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/omni_theme.dart';
import 'application/auth_controller.dart';
import 'application/auth_flow_models.dart';
import 'application/post_auth_navigation.dart';

class OtpVerificationScreen extends StatefulWidget {
  final AuthFlowMode mode;
  final String contactInfo;

  const OtpVerificationScreen({
    super.key,
    required this.mode,
    required this.contactInfo,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  bool _isLoading = false;
  int _resendCountdown = 60;
  Timer? _timer;
  String? _errorMessage;
  late AuthController _authController;
  bool _verificationCompleted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authController = context.read<AuthController>();
  }

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (!_verificationCompleted) {
      _authController.cancelPendingFlow();
    }
    for (var controller in _controllers) {
      controller.clear();
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
    if (_isLoading) return;
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length != 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = context.read<AuthController>();
    final success = widget.mode == AuthFlowMode.login
        ? await auth.verifyPhoneLoginOtp(otp)
        : await auth.verifyPhoneSignupOtp(otp);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      _verificationCompleted = true;
      await navigateAfterAuthentication(context, auth);
      return;
    }

    setState(() {
      _errorMessage = auth.errorMessage ?? 'Unable to verify code.';
    });
  }

  Future<void> _resendCode() async {
    if (_resendCountdown > 0 || _isLoading) return;

    setState(() => _isLoading = true);

    final success = await context.read<AuthController>().resendOtp();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = success
          ? null
          : context.read<AuthController>().errorMessage ??
                'Unable to resend code.';
    });
    if (success) _startResendTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OmniColors.pageBackground,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Retour',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Vérification'),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              OmniSpacing.pageHorizontal,
              OmniSpacing.xl,
              OmniSpacing.pageHorizontal,
              OmniSpacing.xxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: OmniColors.infoBlueSoft,
                        borderRadius: BorderRadius.circular(OmniRadii.card),
                      ),
                      child: const Icon(
                        Icons.sms_outlined,
                        size: 30,
                        color: OmniColors.infoBlue,
                      ),
                    ),
                  ),
                  const SizedBox(height: OmniSpacing.lg),
                  Text(
                    'Vérifiez votre téléphone',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: OmniColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: OmniSpacing.sm),
                  Text(
                    'Saisissez le code à 6 chiffres envoyé au ${widget.contactInfo}.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      height: 1.45,
                      color: OmniColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: OmniSpacing.xl),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = ((constraints.maxWidth - 40) / 6)
                          .clamp(40.0, 48.0)
                          .toDouble();
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(6, (index) {
                          return SizedBox(
                            width: width,
                            height: 52,
                            child: TextField(
                              controller: _controllers[index],
                              focusNode: _focusNodes[index],
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              maxLength: 1,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                    color: OmniColors.textPrimary,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                counterText: '',
                                contentPadding: EdgeInsets.zero,
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
                          );
                        }),
                      );
                    },
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: OmniSpacing.base),
                    Container(
                      padding: const EdgeInsets.all(OmniSpacing.md),
                      decoration: BoxDecoration(
                        color: OmniColors.errorSoft,
                        borderRadius: BorderRadius.circular(OmniRadii.field),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: OmniColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: OmniSpacing.base),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Vous n’avez pas reçu le code ?',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: OmniColors.textSecondary,
                        ),
                      ),
                      TextButton(
                        onPressed: _resendCountdown == 0 ? _resendCode : null,
                        child: Text(
                          _resendCountdown > 0
                              ? 'Renvoyer (${_resendCountdown}s)'
                              : 'Renvoyer',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: OmniSpacing.xl),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _verifyOtp,
                    child: _isLoading
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Vérifier le code'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
