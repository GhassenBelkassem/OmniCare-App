import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../core/theme/omni_theme.dart';
import 'application/auth_controller.dart';

enum GoogleAccountLinkAction { linked, cancelled, retryGoogle }

class GoogleAccountLinkSheet extends StatefulWidget {
  const GoogleAccountLinkSheet({super.key});

  @override
  State<GoogleAccountLinkSheet> createState() => _GoogleAccountLinkSheetState();
}

class _GoogleAccountLinkSheetState extends State<GoogleAccountLinkSheet> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _password.clear();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final auth = context.read<AuthController>();
    final linked = await auth.linkGoogleAccount(_password.text);
    if (!mounted || !linked) return;
    _password.clear();
    Navigator.of(context).pop(GoogleAccountLinkAction.linked);
  }

  void _cancel() {
    context.read<AuthController>().cancelGoogleAccountLink();
    _password.clear();
    Navigator.of(context).pop(GoogleAccountLinkAction.cancelled);
  }

  void _retryGoogle() {
    context.read<AuthController>().cancelGoogleAccountLink();
    _password.clear();
    Navigator.of(context).pop(GoogleAccountLinkAction.retryGoogle);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final challengeExpired =
        auth.errorCode == 'AUTH_GOOGLE_LINK_EXPIRED' ||
        auth.errorCode == 'AUTH_GOOGLE_LINK_INVALID';

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && result == null && auth.hasPendingGoogleAccountLink) {
          auth.cancelGoogleAccountLink();
        }
      },
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            OmniSpacing.pageHorizontal,
            OmniSpacing.sm,
            OmniSpacing.pageHorizontal,
            OmniSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: OmniColors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(OmniRadii.field),
                      ),
                      child: SvgPicture.asset('assets/icons/google_logo.svg'),
                    ),
                    const SizedBox(width: OmniSpacing.md),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Associer votre compte Google',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                                color: OmniColors.textPrimary,
                                letterSpacing: -0.3,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: OmniSpacing.base),
                Text(
                  'Un compte OmniCare existe déjà avec cette adresse.\n\n'
                  'Confirmez votre mot de passe OmniCare pour associer Google à votre compte.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    height: 1.45,
                    color: OmniColors.textSecondary,
                  ),
                ),
                if (auth.pendingGoogleEmailHint != null) ...[
                  const SizedBox(height: OmniSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: OmniSpacing.md,
                      vertical: OmniSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: OmniColors.slateSoft,
                      borderRadius: BorderRadius.circular(OmniRadii.field),
                    ),
                    child: Text(
                      auth.pendingGoogleEmailHint!,
                      key: const Key('google-link-email-hint'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: OmniColors.slateBlue,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: OmniSpacing.lg),
                TextFormField(
                  key: const Key('google-link-password'),
                  controller: _password,
                  obscureText: _obscurePassword,
                  enabled: !auth.isSubmitting && !challengeExpired,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      size: 20,
                      color: OmniColors.textSecondary,
                    ),
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? 'Afficher le mot de passe'
                          : 'Masquer le mot de passe',
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Mot de passe requis'
                      : null,
                  onFieldSubmitted: challengeExpired ? null : (_) => _submit(),
                ),
                if (auth.errorMessage != null) ...[
                  const SizedBox(height: OmniSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(OmniSpacing.md),
                    decoration: BoxDecoration(
                      color: OmniColors.errorSoft,
                      borderRadius: BorderRadius.circular(OmniRadii.field),
                    ),
                    child: Text(
                      auth.errorMessage!,
                      key: const Key('google-link-error'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: OmniColors.error,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: OmniSpacing.lg),
                if (challengeExpired)
                  ElevatedButton(
                    key: const Key('google-link-retry'),
                    onPressed: _retryGoogle,
                    child: const Text('Réessayer avec Google'),
                  )
                else
                  ElevatedButton(
                    key: const Key('google-link-submit'),
                    onPressed: auth.isSubmitting ? null : _submit,
                    child: auth.isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Associer et continuer'),
                  ),
                const SizedBox(height: OmniSpacing.sm),
                TextButton(
                  key: const Key('google-link-cancel'),
                  onPressed: auth.isSubmitting ? null : _cancel,
                  child: const Text('Annuler'),
                ),
                const SizedBox(height: OmniSpacing.sm),
                Text(
                  'Vous pourrez ensuite utiliser Google pour vos prochaines connexions.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: OmniColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
