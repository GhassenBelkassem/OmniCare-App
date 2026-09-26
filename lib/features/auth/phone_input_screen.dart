import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_environment.dart';
import '../../core/theme/omni_theme.dart';
import '../../providers/user_onboarding_provider.dart';
import 'application/auth_controller.dart';
import 'application/auth_flow_models.dart';
import 'application/post_auth_navigation.dart';
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
        if (auth.isAuthenticated) {
          await navigateAfterAuthentication(context, auth);
        } else if (AppEnvironment.phoneVerificationEnabled) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpVerificationScreen(
                mode: widget.mode,
                contactInfo: phoneNumber,
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(auth.errorMessage ?? 'Unable to continue.')),
        );
      }
    }
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
        title: const Text('Numéro de téléphone'),
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
              child: Form(
                key: _formKey,
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
                          Icons.phone_iphone_rounded,
                          size: 30,
                          color: OmniColors.infoBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: OmniSpacing.lg),
                    Text(
                      widget.mode == AuthFlowMode.login
                          ? 'Connexion par téléphone'
                          : AppEnvironment.phoneVerificationEnabled
                          ? 'Vérifiez votre téléphone'
                          : 'Votre numéro de téléphone',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: OmniColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                    ),
                    const SizedBox(height: OmniSpacing.sm),
                    Text(
                      widget.mode == AuthFlowMode.login
                          ? 'Saisissez votre numéro pour recevoir un code de connexion.'
                          : AppEnvironment.phoneVerificationEnabled
                          ? 'Nous devons vérifier votre numéro avant de continuer.'
                          : 'Ajoutez un numéro de contact pour finaliser votre compte.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        height: 1.45,
                        color: OmniColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: OmniSpacing.xl),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      validator: _validatePhone,
                      onFieldSubmitted: (_) => _submitPhone(),
                      decoration: const InputDecoration(
                        labelText: 'Numéro de téléphone',
                        hintText: '12 345 678',
                        prefixIcon: Icon(
                          Icons.phone_outlined,
                          size: 20,
                          color: OmniColors.textSecondary,
                        ),
                        prefixText: '+216  ',
                      ),
                    ),
                    const SizedBox(height: OmniSpacing.sm),
                    Text(
                      'Format tunisien à 8 chiffres',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: OmniColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: OmniSpacing.xxl),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submitPhone,
                      child: _isLoading
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              AppEnvironment.phoneVerificationEnabled
                                  ? 'Envoyer le code'
                                  : 'Continuer',
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
