import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/omni_theme.dart';
import '../../core/widgets/omni_pressable.dart';
import '../../core/widgets/omni_text_field.dart';
import '../../l10n/omni_localizations.dart';
import 'application/auth_controller.dart';
import 'widgets/auth_flow_frame.dart';
import 'widgets/password_rule_chip.dart';

/// Bundled family (pubspec, weights 500–800). The theme's google_fonts
/// text styles keep their 400 face when only the weight changes.
const String _bundledFont = 'Plus Jakarta Sans';

/// Forced password change (/change-password-required), G3-P2c restyle on
/// [AuthFlowFrame]. Same handler (`changeRequiredPassword`), same
/// validators, same messages; the failure SnackBar became an inline banner.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  /// Same value as the « 12 » in [_validateNewPassword] (rule unchanged).
  static const int _passwordMinLength = 12;
  static const double _buttonRadius = 14;

  final _formKey = GlobalKey<FormState>();
  final _confirmFieldKey = GlobalKey<FormFieldState<String>>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _submitted = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ── Unchanged validators ────────────────────────────────────────────────

  String? _validateCurrentPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Mot de passe actuel requis';
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    final l10n = OmniLocalizations.of(context);
    if (value == null || value.isEmpty) {
      return l10n.passwordRequired;
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
    final l10n = OmniLocalizations.of(context);
    if (value == null || value.isEmpty) {
      return l10n.confirmPasswordRequired;
    }
    if (value != _newPasswordController.text) {
      return l10n.passwordsNotMatch;
    }
    return null;
  }

  // ── Same handler; only the failure SnackBar became [_errorMessage] ─────

  Future<void> _changePassword() async {
    setState(() {
      _submitted = true;
      _errorMessage = null;
    });
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
        controller.errorMessage(OmniLocalizations.of(context)) ??
        'Impossible de mettre a jour le mot de passe.';
    setState(() => _errorMessage = message);
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
    final l10n = OmniLocalizations.of(context);

    final newPassword = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;
    final ruleState = newPassword.length >= _passwordMinLength
        ? PasswordRuleState.met
        : _submitted
        ? PasswordRuleState.failed
        : PasswordRuleState.idle;
    final passwordsMatch = confirm.isNotEmpty && confirm == newPassword;

    return AuthFlowFrame(
      title: 'Sécurité du compte',
      showBack: false,
      onBack: null,
      closeIcon: Icons.logout_rounded,
      closeTooltip: 'Se deconnecter',
      onClose: isLoading ? null : _logout,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.forcedPasswordTitle,
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
              l10n.forcedPasswordReason,
              style: const TextStyle(
                fontFamily: _bundledFont,
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: OmniColors.textSecondary,
              ),
            ),
            const SizedBox(height: OmniSpacing.xl),
            OmniTextField(
              label: 'Mot de passe actuel',
              hintText: 'Entrez le mot de passe actuel',
              controller: _currentPasswordController,
              validator: _validateCurrentPassword,
              obscureText: _obscureCurrentPassword,
              textInputAction: TextInputAction.next,
              prefixIcon: Icons.lock_outline_rounded,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              suffix: _eyeToggle(
                obscured: _obscureCurrentPassword,
                onPressed: () => setState(
                  () => _obscureCurrentPassword = !_obscureCurrentPassword,
                ),
              ),
            ),
            const SizedBox(height: OmniSpacing.base),
            OmniTextField(
              label: 'Nouveau mot de passe',
              hintText: '12 caractères minimum',
              controller: _newPasswordController,
              validator: _validateNewPassword,
              obscureText: _obscureNewPassword,
              textInputAction: TextInputAction.next,
              prefixIcon: Icons.lock_outline_rounded,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              onChanged: (_) {
                setState(() {});
                if (_confirmPasswordController.text.isNotEmpty) {
                  _confirmFieldKey.currentState?.validate();
                }
              },
              suffix: _eyeToggle(
                obscured: _obscureNewPassword,
                onPressed: () =>
                    setState(() => _obscureNewPassword = !_obscureNewPassword),
              ),
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
              label: 'Confirmer le nouveau mot de passe',
              hintText: 'Répétez le nouveau mot de passe',
              controller: _confirmPasswordController,
              validator: _validateConfirmPassword,
              obscureText: _obscureConfirmPassword,
              textInputAction: TextInputAction.done,
              prefixIcon: Icons.lock_outline_rounded,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              onChanged: (_) => setState(() {}),
              isSuccess: passwordsMatch,
              successText: l10n.signupPasswordsMatch,
              suffix: _eyeToggle(
                obscured: _obscureConfirmPassword,
                onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                ),
              ),
            ),
          ],
        ),
      ),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorMessage != null) ...[
            _ErrorBanner(message: _errorMessage!),
            const SizedBox(height: OmniSpacing.md),
          ],
          OmniPressable(
            borderRadius: _buttonRadius,
            builder: (context, states) => ElevatedButton(
              statesController: states,
              onPressed: isLoading
                  ? null
                  : OmniPressable.withHaptic(_changePassword),
              style: ButtonStyle(
                overlayColor: OmniPressable.overlay(OmniColors.textOnDark),
              ),
              child: isLoading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: OmniColors.textOnDark,
                      ),
                    )
                  : const Text(
                      'Mettre à jour',
                      style: TextStyle(
                        fontFamily: _bundledFont,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Same tooltips as before (« Afficher » / « Masquer »).
  Widget _eyeToggle({required bool obscured, required VoidCallback onPressed}) {
    return IconButton(
      tooltip: obscured ? 'Afficher' : 'Masquer',
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      onPressed: onPressed,
      icon: Icon(
        obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      ),
    );
  }
}

/// Inline failure message (alert role), same look as the login sheet's.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      role: SemanticsRole.alert,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(OmniSpacing.md),
        decoration: BoxDecoration(
          color: OmniColors.errorSoft,
          borderRadius: BorderRadius.circular(OmniRadii.field),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ExcludeSemantics(
              child: Icon(
                Icons.error_outline_rounded,
                size: 20,
                color: OmniColors.error,
              ),
            ),
            const SizedBox(width: OmniSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: _bundledFont,
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: OmniColors.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
