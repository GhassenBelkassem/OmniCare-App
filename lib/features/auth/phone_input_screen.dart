import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_environment.dart';
import '../../core/theme/omni_theme.dart';
import '../../core/widgets/omni_pressable.dart';
import '../../core/widgets/omni_step_progress.dart';
import '../../core/widgets/omni_text_field.dart';
import '../../providers/user_onboarding_provider.dart';
import 'application/auth_controller.dart';
import 'application/auth_flow_models.dart';
import 'application/post_auth_navigation.dart';
import 'application/tunisian_phone_number.dart';
import 'otp_verification_screen.dart';
import 'widgets/auth_flow_frame.dart';
import '../../l10n/omni_localizations.dart';

/// Bundled family (pubspec, weights 500–800). The theme's google_fonts
/// text styles keep their 400 face when only the weight changes.
const String _bundledFont = 'Plus Jakarta Sans';

/// Phone step, used by three flows (behaviour unchanged, G3-P2b restyle):
/// * e-mail sign-up ([signupDraft] present): step 3/3 « Téléphone » with a
///   summary of the draft (« Modifier » pops with 0 / 1 so the sign-up
///   reopens step 1 / 2, values kept), « Créer mon compte » (« Recevoir le
///   code » when phone verification is on, G3-P2b-fix);
/// * Google sign-up: same frame, no step bar, no summary;
/// * both sign-up flows: the terms pinned above the button (G3-P2c);
/// * phone login: same frame, no step bar, no summary, no terms.
/// Titles and button labels of the last two flows are unchanged.
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
  static const double _buttonRadius = 14;

  final TextEditingController _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  bool get _isEmailSignup => widget.signupDraft != null;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  // Same rule as before; the French texts replace the English ones.
  String? _validatePhone(String? value) {
    final l10n = OmniLocalizations.of(context);
    if (value == null || value.trim().isEmpty) {
      return l10n.phoneRequired;
    }
    try {
      TunisianPhoneNumber.normalize(value);
      return null;
    } on PhoneNumberFormatException {
      return l10n.phoneDigitsInvalid;
    }
  }

  // ── Unchanged submit logic (only the English fallback became French) ────

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
          SnackBar(
            content: Text(
              auth.errorMessage(OmniLocalizations.of(context)) ??
                  OmniLocalizations.of(context).phoneUnableToContinue,
              style: const TextStyle(
                fontFamily: _bundledFont,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      }
    }
  }

  /// Back to the welcome screen (first route).
  void _close() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = OmniLocalizations.of(context);
    final isLogin = widget.mode == AuthFlowMode.login;
    final title = isLogin
        ? l10n.phoneLoginTitle
        : AppEnvironment.phoneVerificationEnabled
        ? l10n.phoneVerifyTitle
        : l10n.phoneContactTitle;
    final subtitle = isLogin
        ? l10n.phoneLoginSubtitle
        : AppEnvironment.phoneVerificationEnabled
        ? l10n.phoneVerifySubtitle
        : l10n.phoneContactSubtitle;
    final buttonLabel = _isEmailSignup
        ? (AppEnvironment.phoneVerificationEnabled
              ? l10n.signupReceiveCode
              : l10n.signupCreateAccount)
        : AppEnvironment.phoneVerificationEnabled
        ? l10n.sendCode
        : l10n.authContinue;
    final submit = _isEmailSignup
        ? OmniPressable.withHaptic(_submitPhone)
        : _submitPhone;

    return AuthFlowFrame(
      title: _isEmailSignup ? l10n.signupTitle : l10n.phoneScreenTitle,
      onBack: _isLoading ? null : () => Navigator.pop(context),
      onClose: _isLoading ? null : _close,
      progress: _isEmailSignup
          ? OmniStepProgress(
              current: 3,
              total: 3,
              stepName: l10n.signupStepPhone,
            )
          : null,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
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
              subtitle,
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
              label: l10n.phoneScreenTitle,
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.telephoneNumberNational],
              hintText: l10n.phoneHint,
              prefixIcon: Icons.phone_outlined,
              prefixText: l10n.phonePrefix,
              helperText: l10n.phoneFormatHelper,
              validator: _validatePhone,
              // UI guard: no second submit from the keyboard while loading.
              onFieldSubmitted: _isLoading ? null : (_) => _submitPhone(),
            ),
            if (_isEmailSignup) ...[
              const SizedBox(height: OmniSpacing.xl),
              _SignupSummaryCard(
                draft: widget.signupDraft!,
                onEdit: _isLoading
                    ? null
                    : (step) => Navigator.pop<int>(context, step),
              ),
            ],
          ],
        ),
      ),
      // Terms pinned directly above the button in both sign-up flows
      // (e-mail and Google), never in phone login (G3-P2c).
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isLogin) ...[
            const _TermsText(),
            const SizedBox(height: OmniSpacing.md),
          ],
          OmniPressable(
            borderRadius: _buttonRadius,
            builder: (context, states) => ElevatedButton(
              statesController: states,
              onPressed: _isLoading ? null : submit,
              style: ButtonStyle(
                overlayColor: OmniPressable.overlay(OmniColors.textOnDark),
              ),
              child: _isLoading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: OmniColors.textOnDark,
                      ),
                    )
                  : Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }
}

/// « Récapitulatif » of the e-mail sign-up draft with « Modifier » links.
class _SignupSummaryCard extends StatelessWidget {
  const _SignupSummaryCard({required this.draft, required this.onEdit});

  final PhoneSignupDraft draft;

  /// Receives 0 (step 1, account) or 1 (step 2, identity); null disables.
  final ValueChanged<int>? onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = OmniLocalizations.of(context);
    final birthDate = DateFormat('dd/MM/yyyy').format(draft.dateOfBirth);
    final gender = switch (draft.gender) {
      'M' => l10n.signupGenderMale,
      'F' => l10n.signupGenderFemale,
      _ => draft.gender,
    };
    final edit = onEdit;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.base,
        OmniSpacing.md,
        OmniSpacing.xs,
        OmniSpacing.md,
      ),
      decoration: BoxDecoration(
        color: OmniColors.slateSoft,
        borderRadius: BorderRadius.circular(OmniRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.signupSummaryTitle,
            style: const TextStyle(
              fontFamily: _bundledFont,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: OmniColors.textPrimary,
            ),
          ),
          const SizedBox(height: OmniSpacing.xs),
          _SummaryRow(
            lines: [draft.email],
            editLabel: l10n.signupEdit,
            editSemanticLabel: l10n.signupEditAccount,
            onEdit: edit == null ? null : () => edit(0),
          ),
          const Divider(),
          _SummaryRow(
            lines: [
              '${draft.firstName} ${draft.lastName}',
              '$birthDate · $gender',
            ],
            editLabel: l10n.signupEdit,
            editSemanticLabel: l10n.signupEditIdentity,
            onEdit: edit == null ? null : () => edit(1),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.lines,
    required this.editLabel,
    required this.editSemanticLabel,
    required this.onEdit,
  });

  final List<String> lines;
  final String editLabel;
  final String editSemanticLabel;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in lines)
                Text(
                  line,
                  style: const TextStyle(
                    fontFamily: _bundledFont,
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                    color: OmniColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        OmniPressable(
          borderRadius: OmniRadii.field,
          builder: (context, states) => Semantics(
            label: editSemanticLabel,
            button: true,
            excludeSemantics: true,
            child: TextButton(
              statesController: states,
              onPressed: onEdit,
              style: ButtonStyle(
                minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
                overlayColor: OmniPressable.overlay(OmniColors.deepTeal),
              ),
              child: Text(
                editLabel,
                style: const TextStyle(
                  fontFamily: _bundledFont,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The former sign-up terms sentence (same words, highlighted words as
/// before, no links: no terms/privacy pages exist yet). Pinned above the
/// main button, 13 w500 textSecondary (G3-P2c).
class _TermsText extends StatelessWidget {
  const _TermsText();

  @override
  Widget build(BuildContext context) {
    final l10n = OmniLocalizations.of(context);
    const base = TextStyle(
      fontFamily: _bundledFont,
      fontSize: 13,
      height: 1.45,
      fontWeight: FontWeight.w500,
      color: OmniColors.textSecondary,
    );
    const highlight = TextStyle(color: OmniColors.deepTeal);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: '${l10n.signupTermsIntro} '),
          TextSpan(text: l10n.signupTermsConditions, style: highlight),
          TextSpan(text: ' ${l10n.signupTermsAnd} '),
          TextSpan(text: l10n.signupTermsPrivacy, style: highlight),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
