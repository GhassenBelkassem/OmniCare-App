import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'account_security_provider.dart';
import '../../l10n/omni_localizations.dart';

const _teal = Color(0xFF087A65);
const _tealSoft = Color(0xFFE8F5F1);
const _ink = Color(0xFF17201E);
const _muted = Color(0xFF667085);
const _line = Color(0xFFE1E7E5);
const _danger = Color(0xFFB42318);
const _dangerSoft = Color(0xFFFFF1F0);

class PhoneChangeReversalScreen extends StatefulWidget {
  const PhoneChangeReversalScreen({super.key, required this.token});

  final String token;

  @override
  State<PhoneChangeReversalScreen> createState() =>
      _PhoneChangeReversalScreenState();
}

class _PhoneChangeReversalScreenState extends State<PhoneChangeReversalScreen> {
  bool _completed = false;

  bool get _hasToken => widget.token.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AccountSecurityProvider>().clearPhoneError();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AccountSecurityProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      width: 60,
                      height: 60,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: _line),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _completed
                        ? const _SuccessContent()
                        : _hasToken
                        ? _ConfirmationContent(
                            busy: provider.isPhoneActionBusy,
                            error: provider.phoneErrorMessage(
                              OmniLocalizations.of(context),
                            ),
                            onConfirm: _reverse,
                            onLogin: _openLogin,
                          )
                        : _InvalidLinkContent(onLogin: _openLogin),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'OmniCare protège les changements sensibles de votre compte.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _muted,
                      height: 1.45,
                    ),
                  ),
                  if (_completed) ...[
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _openLogin,
                      style: FilledButton.styleFrom(
                        backgroundColor: _teal,
                        minimumSize: const Size.fromHeight(52),
                      ),
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('Se connecter'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _reverse() async {
    final provider = context.read<AccountSecurityProvider>();
    provider.clearPhoneError();
    try {
      await provider.reversePhoneChangeWithToken(widget.token.trim());
      if (mounted) setState(() => _completed = true);
    } catch (_) {
      // The provider exposes a safe, localized message to the screen.
    }
  }

  void _openLogin() {
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }
}

class _ConfirmationContent extends StatelessWidget {
  const _ConfirmationContent({
    required this.busy,
    required this.error,
    required this.onConfirm,
    required this.onLogin,
  });

  final bool busy;
  final String? error;
  final VoidCallback onConfirm;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StatusIcon(
          icon: Icons.shield_outlined,
          foreground: _danger,
          background: _dangerSoft,
        ),
        const SizedBox(height: 20),
        Text(
          'Rétablir l’ancien numéro',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: _ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Cette action annule le changement de numéro en cours et sécurise immédiatement le compte.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, height: 1.5),
        ),
        const SizedBox(height: 24),
        const _ConsequenceRow(
          icon: Icons.phone_iphone_rounded,
          text: 'L’ancien numéro redevient le numéro actif.',
        ),
        const _ConsequenceRow(
          icon: Icons.phonelink_erase_rounded,
          text: 'Le nouveau numéro est retiré du compte.',
        ),
        const _ConsequenceRow(
          icon: Icons.logout_rounded,
          text: 'Toutes les sessions sont fermées.',
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _dangerSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline_rounded, color: _danger),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    error!,
                    style: const TextStyle(color: _danger, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: busy ? null : onConfirm,
          style: FilledButton.styleFrom(
            backgroundColor: _danger,
            minimumSize: const Size.fromHeight(52),
          ),
          icon: busy
              ? const SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.undo_rounded),
          label: Text(busy ? 'Sécurisation en cours…' : 'Rétablir le numéro'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: busy ? null : onLogin,
          child: const Text('Annuler'),
        ),
      ],
    );
  }
}

class _SuccessContent extends StatelessWidget {
  const _SuccessContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _StatusIcon(
          icon: Icons.check_rounded,
          foreground: _teal,
          background: _tealSoft,
        ),
        const SizedBox(height: 20),
        Text(
          'Numéro rétabli',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: _ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'L’ancien numéro est de nouveau actif. Toutes les sessions ont été fermées par mesure de sécurité.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, height: 1.5),
        ),
      ],
    );
  }
}

class _InvalidLinkContent extends StatelessWidget {
  const _InvalidLinkContent({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _StatusIcon(
          icon: Icons.link_off_rounded,
          foreground: _danger,
          background: _dangerSoft,
        ),
        const SizedBox(height: 20),
        Text(
          'Lien incomplet',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: _ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Utilisez le lien complet reçu par e-mail ou SMS. Aucun changement n’a été effectué.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, height: 1.5),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onLogin,
          style: FilledButton.styleFrom(
            backgroundColor: _teal,
            minimumSize: const Size.fromHeight(52),
          ),
          icon: const Icon(Icons.login_rounded),
          label: const Text('Se connecter'),
        ),
      ],
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({
    required this.icon,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Icon(icon, color: foreground, size: 32),
      ),
    );
  }
}

class _ConsequenceRow extends StatelessWidget {
  const _ConsequenceRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 21, color: _teal),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(color: _ink, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
