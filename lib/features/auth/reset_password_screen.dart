import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/omni_theme.dart';
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
          backgroundColor: OmniColors.primaryAction,
        ),
      );
      navigator.pushNamedAndRemoveUntil('/login', (_) => false);
      return;
    }

    final message =
        controller.errorMessage ??
        'Impossible de mettre a jour le mot de passe.';
    messenger.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: OmniColors.error),
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
      backgroundColor: OmniColors.pageBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Sécurité du compte'),
        actions: [
          IconButton(
            tooltip: 'Se deconnecter',
            icon: const Icon(
              Icons.logout_rounded,
              color: OmniColors.textSecondary,
            ),
            onPressed: isLoading ? null : _logout,
          ),
        ],
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
                          color: OmniColors.violetSoft,
                          borderRadius: BorderRadius.circular(OmniRadii.card),
                        ),
                        child: const Icon(
                          Icons.lock_reset_rounded,
                          size: 30,
                          color: OmniColors.violet,
                        ),
                      ),
                    ),
                    const SizedBox(height: OmniSpacing.lg),
                    Text(
                      'Changer le mot de passe',
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
                      'Votre mot de passe actuel doit être remplacé avant de continuer.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        height: 1.45,
                        color: OmniColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: OmniSpacing.xl),
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
                    const SizedBox(height: OmniSpacing.base),
                    _PasswordField(
                      label: 'Nouveau mot de passe',
                      hintText: '12 caractères minimum',
                      controller: _newPasswordController,
                      validator: _validateNewPassword,
                      obscureText: _obscureNewPassword,
                      onToggleObscure: () {
                        setState(() {
                          _obscureNewPassword = !_obscureNewPassword;
                        });
                      },
                    ),
                    const SizedBox(height: OmniSpacing.base),
                    _PasswordField(
                      label: 'Confirmer le nouveau mot de passe',
                      hintText: 'Répétez le nouveau mot de passe',
                      controller: _confirmPasswordController,
                      validator: _validateConfirmPassword,
                      obscureText: _obscureConfirmPassword,
                      onToggleObscure: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                    const SizedBox(height: OmniSpacing.xxl),
                    ElevatedButton(
                      onPressed: isLoading ? null : _changePassword,
                      child: isLoading
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Mettre à jour'),
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
    return TextFormField(
      controller: controller,
      validator: validator,
      obscureText: obscureText,
      textInputAction: label.startsWith('Confirmer')
          ? TextInputAction.done
          : TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: const Icon(
          Icons.lock_outline_rounded,
          size: 20,
          color: OmniColors.textSecondary,
        ),
        suffixIcon: IconButton(
          tooltip: obscureText ? 'Afficher' : 'Masquer',
          icon: Icon(
            obscureText
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: OmniColors.textSecondary,
          ),
          onPressed: onToggleObscure,
        ),
      ),
    );
  }
}
