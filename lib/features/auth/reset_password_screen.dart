import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import 'application/auth_controller.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateCurrentPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Mot de passe actuel requis';
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    final l10n = AppLocalizations.of(context);
    if (value == null || value.isEmpty) {
      return l10n?.passwordRequired ?? 'Password is required';
    }
    if (value.length < 12) {
      return 'Le mot de passe doit contenir au moins 12 caracteres';
    }
    if (value.length > 128) {
      return 'Le mot de passe est trop long';
    }
    if (value == _currentPasswordController.text) {
      return 'Choisissez un mot de passe different';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final l10n = AppLocalizations.of(context);
    if (value == null || value.isEmpty) {
      return l10n?.confirmPasswordRequired ?? 'Please confirm your password';
    }
    if (value != _newPasswordController.text) {
      return l10n?.passwordsNotMatch ?? 'Passwords do not match';
    }
    return null;
  }

  Future<void> _changePassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final controller = context.read<AuthController>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final changed = await controller.changeRequiredPassword(
      _currentPasswordController.text,
      _newPasswordController.text,
    );
    if (!mounted) return;

    if (changed) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Mot de passe mis a jour. Connectez-vous a nouveau.'),
          backgroundColor: Color(0xFF1FBF9A),
        ),
      );
      navigator.pushNamedAndRemoveUntil('/login', (_) => false);
      return;
    }

    final message =
        controller.errorMessage ??
        'Impossible de mettre a jour le mot de passe.';
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFDC2626),
      ),
    );
  }

  Future<void> _logout() async {
    final controller = context.read<AuthController>();
    final navigator = Navigator.of(context);
    await controller.logout();
    if (!mounted) return;
    navigator.pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final isLoading = auth.isSubmitting;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Se deconnecter',
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF344054)),
            onPressed: isLoading ? null : _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 132,
                    height: 132,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF0FDF9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      size: 72,
                      color: Color(0xFF1FBF9A),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Changer le mot de passe',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF101828),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Votre mot de passe actuel doit etre remplace avant de continuer.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 32),
                _PasswordField(
                  label: 'Mot de passe actuel',
                  hintText: 'Entrez le mot de passe actuel',
                  controller: _currentPasswordController,
                  validator: _validateCurrentPassword,
                  obscureText: _obscureCurrentPassword,
                  onToggleObscure: () {
                    setState(() {
                      _obscureCurrentPassword = !_obscureCurrentPassword;
                    });
                  },
                ),
                const SizedBox(height: 20),
                _PasswordField(
                  label: 'Nouveau mot de passe',
                  hintText: '12 caracteres minimum',
                  controller: _newPasswordController,
                  validator: _validateNewPassword,
                  obscureText: _obscureNewPassword,
                  onToggleObscure: () {
                    setState(() {
                      _obscureNewPassword = !_obscureNewPassword;
                    });
                  },
                ),
                const SizedBox(height: 20),
                _PasswordField(
                  label: 'Confirmer le nouveau mot de passe',
                  hintText: 'Repetez le nouveau mot de passe',
                  controller: _confirmPasswordController,
                  validator: _validateConfirmPassword,
                  obscureText: _obscureConfirmPassword,
                  onToggleObscure: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _changePassword,
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
                    child: isLoading
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
                            'Mettre a jour',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.label,
    required this.hintText,
    required this.controller,
    required this.validator,
    required this.obscureText,
    required this.onToggleObscure,
  });

  final String label;
  final String hintText;
  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final bool obscureText;
  final VoidCallback onToggleObscure;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF1D2939),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          obscureText: obscureText,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF1D2939),
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF9CA3AF),
            ),
            filled: true,
            fillColor: Colors.white,
            suffixIcon: IconButton(
              tooltip: obscureText ? 'Afficher' : 'Masquer',
              icon: Icon(
                obscureText
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: const Color(0xFF667085),
              ),
              onPressed: onToggleObscure,
            ),
            border: _border(const Color(0xFFE5E7EB)),
            enabledBorder: _border(const Color(0xFFE5E7EB)),
            focusedBorder: _border(const Color(0xFF1FBF9A), width: 2),
            errorBorder: _border(const Color(0xFFDC2626)),
            focusedErrorBorder: _border(const Color(0xFFDC2626), width: 2),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
