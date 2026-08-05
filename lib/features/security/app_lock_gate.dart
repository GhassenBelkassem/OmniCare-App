import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/application/auth_controller.dart';
import 'app_lock_service.dart';

class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  DateTime? _backgroundedAt;
  String? _boundUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _backgroundedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final elapsed = _backgroundedAt == null
          ? Duration.zero
          : DateTime.now().difference(_backgroundedAt!);
      _backgroundedAt = null;
      if (elapsed >= const Duration(seconds: 10) && mounted) {
        context.read<AppLockService>().lock();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final lock = context.watch<AppLockService>();
    final userId = auth.currentUser?.id;
    if (auth.isAuthenticated && userId != null && _boundUserId != userId) {
      _boundUserId = userId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<AppLockService>().bindUser(userId);
      });
    }

    if (!auth.isAuthenticated || !lock.ready || !lock.locked) {
      return widget.child;
    }
    return Stack(
      children: [
        const ColoredBox(color: Color(0xFFF4F5F7)),
        Positioned.fill(child: _UnlockView(lock: lock)),
      ],
    );
  }
}

class _UnlockView extends StatefulWidget {
  const _UnlockView({required this.lock});

  final AppLockService lock;

  @override
  State<_UnlockView> createState() => _UnlockViewState();
}

class _UnlockViewState extends State<_UnlockView> {
  final _pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.lock.method == AppLockMethod.biometric) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.lock.unlockWithBiometric();
      });
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final biometric = widget.lock.method == AppLockMethod.biometric;
    return Material(
      color: const Color(0xFFF4F5F7),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F8F3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      biometric
                          ? Icons.fingerprint_rounded
                          : Icons.lock_outline_rounded,
                      size: 36,
                      color: const Color(0xFF087A65),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'OmniCare est verrouillé',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    biometric
                        ? 'Confirmez votre identité pour continuer.'
                        : 'Saisissez votre code à 6 chiffres.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF667085)),
                  ),
                  const SizedBox(height: 24),
                  if (biometric)
                    FilledButton.icon(
                      onPressed: widget.lock.authenticating
                          ? null
                          : widget.lock.unlockWithBiometric,
                      icon: const Icon(Icons.fingerprint_rounded),
                      label: const Text('Déverrouiller'),
                    )
                  else ...[
                    TextField(
                      controller: _pinController,
                      autofocus: true,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        counterText: '',
                        hintText: '••••••',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: widget.lock.unlockWithPin,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () =>
                            widget.lock.unlockWithPin(_pinController.text),
                        child: const Text('Déverrouiller'),
                      ),
                    ),
                  ],
                  if (widget.lock.error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      widget.lock.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFD92D20)),
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
}
