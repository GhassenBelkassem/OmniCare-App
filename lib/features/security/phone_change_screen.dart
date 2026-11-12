import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../auth/application/tunisian_phone_number.dart';
import 'account_security_api.dart';
import 'account_security_provider.dart';
import '../../l10n/omni_localizations.dart';

const _teal = Color(0xFF087A65);
const _muted = Color(0xFF667085);
const _line = Color(0xFFE1E7E5);
const _danger = Color(0xFFD92D20);

enum _PhoneChangeStep { start, currentOtp, newPhone, newOtp }

class PhoneChangeScreen extends StatefulWidget {
  const PhoneChangeScreen({super.key});

  @override
  State<PhoneChangeScreen> createState() => _PhoneChangeScreenState();
}

class _PhoneChangeScreenState extends State<PhoneChangeScreen> {
  final _otpFormKey = GlobalKey<FormState>();
  final _phoneFormKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _phoneController = TextEditingController();
  _PhoneChangeStep _step = _PhoneChangeStep.start;
  PhoneChangeChallenge? _challenge;
  String? _normalizedNewPhone;
  String? _localError;
  bool _submitted = false;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _clock?.cancel();
    _otpController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await context.read<AccountSecurityProvider>().loadPhoneChangeStatus();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AccountSecurityProvider>();
    final status = provider.phoneChangeStatus;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        title: const Text('Changer de numéro'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 36),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (provider.isPhoneActionBusy && status == null)
                      const LinearProgressIndicator(color: _teal),
                    if (provider.hasPhoneError || _localError != null) ...[
                      _PhoneError(
                        message:
                            _localError ??
                            provider.phoneErrorMessage(
                              OmniLocalizations.of(context),
                            )!,
                        onDismiss: () {
                          provider.clearPhoneError();
                          setState(() => _localError = null);
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (status?.active == true)
                      _TransitionStatus(
                        status: status!,
                        busy: provider.isPhoneActionBusy,
                        onReverse: _confirmReverse,
                      )
                    else
                      _buildFlow(provider),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlow(AccountSecurityProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepProgress(step: _step),
        const SizedBox(height: 18),
        switch (_step) {
          _PhoneChangeStep.start => _StartStep(
            activePhone: provider.phoneChangeStatus?.activePhoneMasked,
            busy: provider.isPhoneActionBusy,
            onStart: _start,
          ),
          _PhoneChangeStep.currentOtp => _OtpStep(
            formKey: _otpFormKey,
            controller: _otpController,
            title: 'Confirmez votre numéro actuel',
            description:
                'Saisissez le code envoyé au ${_challenge?.destinationMasked ?? 'numéro actuel'}.',
            submitted: _submitted,
            busy: provider.isPhoneActionBusy,
            onSubmit: _verifyCurrent,
            onResend: _start,
          ),
          _PhoneChangeStep.newPhone => _NewPhoneStep(
            formKey: _phoneFormKey,
            controller: _phoneController,
            submitted: _submitted,
            busy: provider.isPhoneActionBusy,
            onSubmit: _sendNewCode,
          ),
          _PhoneChangeStep.newOtp => _OtpStep(
            formKey: _otpFormKey,
            controller: _otpController,
            title: 'Confirmez le nouveau numéro',
            description:
                'Saisissez le code envoyé au ${_challenge?.destinationMasked ?? 'nouveau numéro'}.',
            submitted: _submitted,
            busy: provider.isPhoneActionBusy,
            onSubmit: _verifyNew,
            onResend: _resendNew,
          ),
        },
      ],
    );
  }

  Future<void> _start() async {
    setState(() {
      _submitted = false;
      _localError = null;
    });
    try {
      final challenge = await context
          .read<AccountSecurityProvider>()
          .initiateCurrentPhoneVerification();
      if (!mounted) return;
      _otpController.clear();
      setState(() {
        _challenge = challenge;
        _step = _PhoneChangeStep.currentOtp;
      });
    } catch (_) {}
  }

  Future<void> _verifyCurrent() async {
    setState(() {
      _submitted = true;
      _localError = null;
    });
    if (!(_otpFormKey.currentState?.validate() ?? false)) return;
    try {
      await context.read<AccountSecurityProvider>().verifyCurrentPhone(
        _otpController.text.trim(),
      );
      if (!mounted) return;
      _otpController.clear();
      setState(() {
        _submitted = false;
        _step = _PhoneChangeStep.newPhone;
      });
    } catch (_) {}
  }

  Future<void> _sendNewCode() async {
    setState(() {
      _submitted = true;
      _localError = null;
    });
    if (!(_phoneFormKey.currentState?.validate() ?? false)) return;
    String phone;
    try {
      phone = TunisianPhoneNumber.normalize(_phoneController.text);
    } on PhoneNumberFormatException catch (error) {
      setState(() => _localError = error.message);
      return;
    }
    try {
      final challenge = await context
          .read<AccountSecurityProvider>()
          .initiateNewPhone(phone);
      if (!mounted) return;
      _otpController.clear();
      setState(() {
        _normalizedNewPhone = phone;
        _challenge = challenge;
        _submitted = false;
        _step = _PhoneChangeStep.newOtp;
      });
    } catch (_) {}
  }

  Future<void> _resendNew() async {
    final phone = _normalizedNewPhone;
    if (phone == null) return;
    try {
      final challenge = await context
          .read<AccountSecurityProvider>()
          .initiateNewPhone(phone);
      if (mounted) setState(() => _challenge = challenge);
    } catch (_) {}
  }

  Future<void> _verifyNew() async {
    setState(() {
      _submitted = true;
      _localError = null;
    });
    if (!(_otpFormKey.currentState?.validate() ?? false)) return;
    try {
      await context.read<AccountSecurityProvider>().verifyNewPhone(
        _otpController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _submitted = false;
        _step = _PhoneChangeStep.start;
      });
    } catch (_) {}
  }

  Future<void> _confirmReverse() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.undo_rounded, color: _danger),
        title: const Text('Rétablir l’ancien numéro ?'),
        content: const Text(
          'Le nouveau numéro sera retiré et toutes vos sessions seront fermées '
          'pour protéger le compte.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Garder le nouveau numéro'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: _danger),
            icon: const Icon(Icons.undo_rounded),
            label: const Text('Rétablir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<AccountSecurityProvider>().reversePhoneChange();
    } catch (_) {}
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.step});
  final _PhoneChangeStep step;

  @override
  Widget build(BuildContext context) {
    final value = switch (step) {
      _PhoneChangeStep.start => 0.0,
      _PhoneChangeStep.currentOtp => 0.33,
      _PhoneChangeStep.newPhone => 0.66,
      _PhoneChangeStep.newOtp => 1.0,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Vérification en 3 étapes',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              step == _PhoneChangeStep.start
                  ? 'Prêt'
                  : '${(value * 3).ceil()}/3',
              style: const TextStyle(
                color: _teal,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        LinearProgressIndicator(
          value: value,
          minHeight: 5,
          borderRadius: BorderRadius.circular(3),
          color: _teal,
          backgroundColor: const Color(0xFFDDE5E2),
        ),
      ],
    );
  }
}

class _StartStep extends StatelessWidget {
  const _StartStep({
    required this.activePhone,
    required this.busy,
    required this.onStart,
  });
  final String? activePhone;
  final bool busy;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.phone_iphone_rounded, size: 38, color: _teal),
        const SizedBox(height: 14),
        const Text(
          'Protégeons les deux numéros',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Nous vérifierons d’abord ${activePhone ?? 'votre numéro actuel'}, puis le nouveau numéro. Le changement restera réversible pendant 48 heures.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, height: 1.45),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 50,
          child: FilledButton.icon(
            onPressed: busy ? null : onStart,
            style: FilledButton.styleFrom(backgroundColor: _teal),
            icon: busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sms_outlined),
            label: const Text('Envoyer le code'),
          ),
        ),
      ],
    ),
  );
}

class _OtpStep extends StatelessWidget {
  const _OtpStep({
    required this.formKey,
    required this.controller,
    required this.title,
    required this.description,
    required this.submitted,
    required this.busy,
    required this.onSubmit,
    required this.onResend,
  });
  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final String title;
  final String description;
  final bool submitted;
  final bool busy;
  final VoidCallback onSubmit;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) => _FlowSurface(
    child: Form(
      key: formKey,
      autovalidateMode: submitted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          Text(description, style: const TextStyle(color: _muted, height: 1.4)),
          const SizedBox(height: 18),
          TextFormField(
            controller: controller,
            enabled: !busy,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: const InputDecoration(
              labelText: 'Code à 6 chiffres',
              prefixIcon: Icon(Icons.password_rounded),
              border: OutlineInputBorder(),
            ),
            validator: (value) => RegExp(r'^\d{6}$').hasMatch(value ?? '')
                ? null
                : 'Saisissez les 6 chiffres du code.',
            onFieldSubmitted: (_) => busy ? null : onSubmit(),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: busy ? null : onSubmit,
              style: FilledButton.styleFrom(backgroundColor: _teal),
              icon: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.arrow_forward_rounded),
              label: const Text('Continuer'),
            ),
          ),
          TextButton(
            onPressed: busy ? null : onResend,
            child: const Text('Renvoyer le code'),
          ),
        ],
      ),
    ),
  );
}

class _NewPhoneStep extends StatelessWidget {
  const _NewPhoneStep({
    required this.formKey,
    required this.controller,
    required this.submitted,
    required this.busy,
    required this.onSubmit,
  });
  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final bool submitted;
  final bool busy;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => _FlowSurface(
    child: Form(
      key: formKey,
      autovalidateMode: submitted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Votre nouveau numéro',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          const Text(
            'Ce numéro recevra tous les prochains codes OmniCare dès sa confirmation.',
            style: TextStyle(color: _muted, height: 1.4),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: controller,
            enabled: !busy,
            autofocus: true,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            decoration: const InputDecoration(
              labelText: 'Nouveau numéro',
              prefixText: '+216  ',
              prefixIcon: Icon(Icons.phone_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (value) => RegExp(r'^\d{8}$').hasMatch(value ?? '')
                ? null
                : 'Saisissez les 8 chiffres du numéro.',
            onFieldSubmitted: (_) => busy ? null : onSubmit(),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: busy ? null : onSubmit,
              style: FilledButton.styleFrom(backgroundColor: _teal),
              icon: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sms_outlined),
              label: const Text('Envoyer le code'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _TransitionStatus extends StatelessWidget {
  const _TransitionStatus({
    required this.status,
    required this.busy,
    required this.onReverse,
  });
  final PhoneChangeStatus status;
  final bool busy;
  final VoidCallback onReverse;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final end = status.completesAt?.toLocal();
    final start = status.startedAt?.toLocal();
    final remaining = end?.difference(now) ?? Duration.zero;
    final total = end != null && start != null
        ? end.difference(start).inSeconds
        : 1;
    final elapsed = end == null
        ? 0
        : total - remaining.inSeconds.clamp(0, total);
    final progress = total <= 0 ? 1.0 : (elapsed / total).clamp(0.0, 1.0);
    final hours = remaining.isNegative ? 0 : remaining.inHours;
    final minutes = remaining.isNegative
        ? 0
        : remaining.inMinutes.remainder(60);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.schedule_rounded, color: _teal),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Période de sécurité en cours',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            '$hours h $minutes min avant validation définitive',
            style: const TextStyle(color: _muted),
          ),
          const SizedBox(height: 13),
          LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
            color: _teal,
            backgroundColor: const Color(0xFFDDE5E2),
          ),
          const SizedBox(height: 18),
          _NumberLine(
            label: 'Numéro actif',
            value: status.activePhoneMasked,
            icon: Icons.check_circle_outline_rounded,
            color: _teal,
          ),
          if (status.previousPhoneMasked != null) ...[
            const SizedBox(height: 11),
            _NumberLine(
              label: 'Ancien numéro protégé',
              value: status.previousPhoneMasked!,
              icon: Icons.shield_outlined,
              color: _muted,
            ),
          ],
          if (end != null) ...[
            const SizedBox(height: 13),
            Text(
              'Finalisation le ${DateFormat('dd/MM/yyyy à HH:mm').format(end)}',
              style: const TextStyle(color: _muted, fontSize: 12.5),
            ),
          ],
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFAEB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'L’ancien numéro et votre adresse e-mail reçoivent un lien de recours pendant cette période.',
              style: TextStyle(color: Color(0xFF7A2E0E), height: 1.4),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: busy || !status.canReverse ? null : onReverse,
            style: OutlinedButton.styleFrom(foregroundColor: _danger),
            icon: busy
                ? const SizedBox.square(
                    dimension: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.undo_rounded),
            label: const Text('Ce n’était pas moi, rétablir'),
          ),
        ],
      ),
    );
  }
}

class _NumberLine extends StatelessWidget {
  const _NumberLine({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: color),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    ],
  );
}

class _FlowSurface extends StatelessWidget {
  const _FlowSurface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _line),
    ),
    child: child,
  );
}

class _PhoneError extends StatelessWidget {
  const _PhoneError({required this.message, required this.onDismiss});
  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFFFF4ED),
    borderRadius: BorderRadius.circular(8),
    child: ListTile(
      leading: const Icon(Icons.error_outline_rounded, color: _danger),
      title: Text(message),
      trailing: IconButton(
        tooltip: 'Fermer',
        onPressed: onDismiss,
        icon: const Icon(Icons.close_rounded),
      ),
    ),
  );
}
