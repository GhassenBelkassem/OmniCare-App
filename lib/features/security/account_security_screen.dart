import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../../core/auth/google_web_sign_in_button.dart';
import '../auth/application/auth_controller.dart';
import 'account_security_provider.dart';
import 'app_lock_service.dart';
import 'phone_change_screen.dart';

const _teal = Color(0xFF087A65);
const _mintSurface = Color(0xFFE8F8F3);
const _line = Color(0xFFE1E7E5);
const _muted = Color(0xFF667085);
const _danger = Color(0xFFD92D20);

class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      await context.read<AccountSecurityProvider>().load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final security = context.watch<AccountSecurityProvider>();
    final lock = context.watch<AppLockService>();
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        title: const Text('Sécurité du compte'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (security.isLoading && security.devices.isEmpty)
              const LinearProgressIndicator(color: _teal),
            if (security.error != null) ...[
              _ErrorPanel(message: security.error!, onRetry: _load),
              const SizedBox(height: 14),
            ],
            _SecurityPanel(
              icon: security.phoneChangeStatus?.active == true
                  ? Icons.schedule_rounded
                  : Icons.phone_iphone_rounded,
              title: 'Numéro de téléphone',
              description: security.phoneChangeStatus?.active == true
                  ? '${security.phoneChangeStatus!.activePhoneMasked} · Période de sécurité en cours'
                  : '${security.phoneChangeStatus?.activePhoneMasked ?? 'Numéro vérifié'} · Protégé par double vérification',
              actionLabel: security.phoneChangeStatus?.active == true
                  ? 'Voir le statut'
                  : 'Modifier',
              onPressed: security.isPhoneActionBusy
                  ? null
                  : () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PhoneChangeScreen(),
                        ),
                      );
                      if (mounted) await _load();
                    },
            ),
            const SizedBox(height: 14),
            _SecurityPanel(
              icon: Icons.password_rounded,
              title: security.hasPassword
                  ? 'Mot de passe'
                  : 'Ajouter un mot de passe',
              description: security.hasPassword
                  ? 'Modifiez votre mot de passe. Les autres sessions seront fermées.'
                  : 'Votre compte utilise Google. Confirmez votre identité Google pour créer un mot de passe.',
              actionLabel: security.hasPassword ? 'Modifier' : 'Ajouter',
              onPressed: security.isSavingPassword
                  ? null
                  : () => _openPasswordForm(security),
            ),
            const SizedBox(height: 14),
            _SecurityPanel(
              icon: lock.method == AppLockMethod.biometric
                  ? Icons.fingerprint_rounded
                  : Icons.lock_outline_rounded,
              title: 'Verrouillage de l’application',
              description: lock.enabled
                  ? 'Actif · ${lock.method == AppLockMethod.biometric ? 'Biométrie' : 'Code PIN'}'
                  : 'Protégez l’application lorsqu’elle quitte le premier plan.',
              actionLabel: lock.enabled ? 'Gérer' : 'Configurer',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AppLockSettingsScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPasswordForm(AccountSecurityProvider security) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (_) =>
          ChangeAccountPasswordSheet(hasPassword: security.hasPassword),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Mot de passe enregistré.')));
    }
  }
}

class ChangeAccountPasswordSheet extends StatefulWidget {
  const ChangeAccountPasswordSheet({super.key, required this.hasPassword});

  final bool hasPassword;

  @override
  State<ChangeAccountPasswordSheet> createState() =>
      _ChangeAccountPasswordSheetState();
}

class _ChangeAccountPasswordSheetState
    extends State<ChangeAccountPasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitted = false;
  bool _obscure = true;
  bool _googleStepReady = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saving = context.watch<AccountSecurityProvider>().isSavingPassword;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          autovalidateMode: _submitted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.hasPassword
                          ? 'Modifier le mot de passe'
                          : 'Ajouter un mot de passe',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.hasPassword
                    ? 'Utilisez au moins 12 caractères.'
                    : 'Créez votre mot de passe, puis confirmez que ce compte Google vous appartient.',
                style: const TextStyle(color: _muted),
              ),
              const SizedBox(height: 20),
              if (widget.hasPassword) ...[
                TextFormField(
                  controller: _currentController,
                  obscureText: _obscure,
                  enabled: !saving,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(
                    labelText: 'Mot de passe actuel',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value ?? '').isEmpty
                      ? 'Saisissez votre mot de passe actuel.'
                      : null,
                ),
                const SizedBox(height: 14),
              ],
              TextFormField(
                controller: _newController,
                obscureText: _obscure,
                enabled: !saving,
                maxLength: 128,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'Nouveau mot de passe',
                  prefixIcon: const Icon(Icons.password_rounded),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Afficher' : 'Masquer',
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) => (value ?? '').length < 12
                    ? 'Utilisez au moins 12 caractères.'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirmController,
                obscureText: _obscure,
                enabled: !saving,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(
                  labelText: 'Confirmer le mot de passe',
                  prefixIcon: Icon(Icons.check_circle_outline_rounded),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value != _newController.text
                    ? 'Les mots de passe ne correspondent pas.'
                    : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: _danger)),
              ],
              const SizedBox(height: 20),
              if (!widget.hasPassword && kIsWeb && _googleStepReady) ...[
                const Text(
                  'Confirmez maintenant votre identité Google pour créer le mot de passe.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                IgnorePointer(
                  ignoring: saving,
                  child: Opacity(
                    opacity: saving ? 0.55 : 1,
                    child: GoogleWebSignInButton(
                      onIdToken: (token) => _submit(googleIdToken: token),
                    ),
                  ),
                ),
                if (saving) ...[
                  const SizedBox(height: 12),
                  const Center(child: CircularProgressIndicator()),
                ],
              ] else
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: saving
                        ? null
                        : (!widget.hasPassword && kIsWeb)
                        ? _prepareGoogleStep
                        : _submit,
                    style: FilledButton.styleFrom(backgroundColor: _teal),
                    icon: saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            widget.hasPassword
                                ? Icons.save_outlined
                                : Icons.verified_user_outlined,
                          ),
                    label: Text(
                      saving
                          ? 'Enregistrement…'
                          : widget.hasPassword
                          ? 'Enregistrer'
                          : 'Confirmer avec Google et créer',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _prepareGoogleStep() {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _googleStepReady = true);
  }

  Future<void> _submit({String? googleIdToken}) async {
    setState(() {
      _submitted = true;
      _error = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;
    try {
      await context.read<AccountSecurityProvider>().savePassword(
        currentPassword: widget.hasPassword ? _currentController.text : null,
        newPassword: _newController.text,
        googleIdToken: googleIdToken,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }
}

class _SecurityPanel extends StatelessWidget {
  const _SecurityPanel({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _mintSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _teal),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 5),
                Text(description, style: const TextStyle(color: _muted)),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: onPressed, child: Text(actionLabel)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFFFF4ED),
    borderRadius: BorderRadius.circular(8),
    child: ListTile(
      leading: const Icon(Icons.error_outline_rounded, color: _danger),
      title: Text(message),
      trailing: IconButton(
        tooltip: 'Réessayer',
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
      ),
    ),
  );
}

class AppLockSettingsScreen extends StatefulWidget {
  const AppLockSettingsScreen({super.key});

  @override
  State<AppLockSettingsScreen> createState() => _AppLockSettingsScreenState();
}

class _AppLockSettingsScreenState extends State<AppLockSettingsScreen> {
  bool _biometricAvailable = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    context.read<AppLockService>().biometricAvailable().then((value) {
      if (mounted) setState(() => _biometricAvailable = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<AppLockService>();
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(title: const Text('Verrouillage de l’application')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: _danger)),
            const SizedBox(height: 12),
          ],
          if (_biometricAvailable)
            _LockOption(
              icon: Icons.fingerprint_rounded,
              title: 'Biométrie',
              subtitle: 'Face ID, Touch ID ou empreinte de l’appareil',
              selected: lock.method == AppLockMethod.biometric,
              onTap: _busy ? null : _enableBiometric,
            ),
          if (_biometricAvailable) const SizedBox(height: 10),
          _LockOption(
            icon: Icons.pin_outlined,
            title: 'Code PIN',
            subtitle: 'Code OmniCare à 6 chiffres',
            selected: lock.method == AppLockMethod.pin,
            onTap: _busy ? null : _configurePin,
          ),
          if (lock.enabled) ...[
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: _busy ? null : _disable,
              style: OutlinedButton.styleFrom(foregroundColor: _danger),
              icon: const Icon(Icons.lock_open_rounded),
              label: const Text('Désactiver le verrouillage'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _enableBiometric() async {
    final userId = context.read<AuthController>().currentUser?.id;
    if (userId == null) return;
    await _run(() => context.read<AppLockService>().enableBiometric(userId));
  }

  Future<void> _configurePin() async {
    final pin = await _askPin(confirm: true);
    if (!mounted || pin == null) return;
    final userId = context.read<AuthController>().currentUser?.id;
    if (userId == null) return;
    await _run(() => context.read<AppLockService>().enablePin(userId, pin));
  }

  Future<void> _disable() async {
    final lock = context.read<AppLockService>();
    final pin = lock.method == AppLockMethod.pin
        ? await _askPin(confirm: false)
        : null;
    if (lock.method == AppLockMethod.pin && pin == null) return;
    await _run(() async {
      final disabled = await lock.disable(pin: pin);
      if (!disabled) throw StateError('Confirmation incorrecte.');
    });
  }

  Future<String?> _askPin({required bool confirm}) async {
    final first = TextEditingController();
    final second = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(confirm ? 'Créer un code PIN' : 'Confirmer votre code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: first,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'Code à 6 chiffres'),
            ),
            if (confirm)
              TextField(
                controller: second,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'Confirmer'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (!RegExp(r'^\d{6}$').hasMatch(first.text)) return;
              if (confirm && first.text != second.text) return;
              Navigator.pop(dialogContext, first.text);
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    first.dispose();
    second.dispose();
    return result;
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _LockOption extends StatelessWidget {
  const _LockOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? _mintSurface : Colors.white,
    borderRadius: BorderRadius.circular(8),
    child: ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: selected ? _teal : _line),
      ),
      onTap: onTap,
      leading: Icon(icon, color: _teal),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: Icon(
        selected ? Icons.check_circle_rounded : Icons.circle_outlined,
        color: selected ? _teal : _muted,
      ),
    ),
  );
}
