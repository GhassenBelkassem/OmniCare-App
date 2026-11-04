import 'package:flutter/material.dart';

import '../core/nav/app_nav.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/application/post_auth_navigation.dart';
import 'demo_auth_repository.dart';

class DemoToolbar extends StatefulWidget {
  const DemoToolbar({
    super.key,
    required this.authController,
    required this.authRepository,
  });

  final AuthController authController;
  final DemoAuthRepository authRepository;

  @override
  State<DemoToolbar> createState() => _DemoToolbarState();
}

class _DemoToolbarState extends State<DemoToolbar> {
  bool _switching = false;

  Future<void> _switchTo(DemoRole role) async {
    if (_switching) return;
    setState(() => _switching = true);
    try {
      widget.authRepository.selectRole(role);
      final success = await widget.authController.loginWithEmailPassword(
        '${role.name}@demo.omnicare.tn',
        'demo',
      );
      if (!success) return;
      final context = AppNav.navigatorKey.currentContext;
      if (context != null && context.mounted) {
        await navigateAfterAuthentication(
          context,
          widget.authController,
          dismissKeyboard: false,
        );
      }
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  Future<void> _showAuthentication() async {
    if (_switching) return;
    setState(() => _switching = true);
    try {
      await widget.authController.logout();
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.all(12),
      child: Align(
        alignment: Alignment.topRight,
        child: Material(
          elevation: 8,
          color: const Color(0xFF103D38),
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: PopupMenuButton<_DemoAction>(
            enabled: !_switching,
            tooltip: 'Changer l’espace de démonstration',
            onSelected: (action) {
              switch (action) {
                case _DemoAction.patient:
                  _switchTo(DemoRole.patient);
                case _DemoAction.doctor:
                  _switchTo(DemoRole.doctor);
                case _DemoAction.clinic:
                  _switchTo(DemoRole.clinic);
                case _DemoAction.authentication:
                  _showAuthentication();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _DemoAction.patient,
                child: _DemoMenuItem(
                  icon: Icons.person_outline_rounded,
                  label: 'Espace patient',
                ),
              ),
              PopupMenuItem(
                value: _DemoAction.doctor,
                child: _DemoMenuItem(
                  icon: Icons.medical_services_outlined,
                  label: 'Espace médecin',
                ),
              ),
              PopupMenuItem(
                value: _DemoAction.clinic,
                child: _DemoMenuItem(
                  icon: Icons.local_hospital_outlined,
                  label: 'Espace clinique',
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: _DemoAction.authentication,
                child: _DemoMenuItem(
                  icon: Icons.login_rounded,
                  label: 'Écrans de connexion',
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_switching)
                    const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    const Icon(
                      Icons.science_outlined,
                      size: 18,
                      color: Colors.white,
                    ),
                  const SizedBox(width: 8),
                  const Text(
                    'DÉMO STATIQUE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(
                    Icons.expand_more_rounded,
                    size: 18,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _DemoAction { patient, doctor, clinic, authentication }

class _DemoMenuItem extends StatelessWidget {
  const _DemoMenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [Icon(icon, size: 20), const SizedBox(width: 10), Text(label)],
    );
  }
}
