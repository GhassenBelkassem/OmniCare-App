import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'account_security_api.dart';
import 'account_security_provider.dart';

class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      await context.read<AccountSecurityProvider>().load(devicesOnly: true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AccountSecurityProvider>();
    final others = provider.devices.where((device) => !device.current).length;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(title: const Text('Mes appareils')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (provider.isLoading)
              const LinearProgressIndicator(color: Color(0xFF087A65)),
            if (provider.error != null) ...[
              const SizedBox(height: 12),
              Text(
                provider.error!,
                style: const TextStyle(color: Color(0xFFD92D20)),
              ),
            ],
            const SizedBox(height: 12),
            for (final device in provider.devices) ...[
              _DeviceTile(
                device: device,
                busy: provider.revokingDeviceId == device.id,
                onRevoke: () => _confirmRevoke(device),
              ),
              const SizedBox(height: 10),
            ],
            if (!provider.isLoading && provider.devices.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: Text('Aucun appareil actif.')),
              ),
            if (others > 0) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: provider.isRevokingOthers
                    ? null
                    : _confirmRevokeOthers,
                icon: const Icon(Icons.devices_other_rounded),
                label: Text(
                  provider.isRevokingOthers
                      ? 'Révocation…'
                      : 'Révoquer tous les autres appareils',
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _confirmLogoutAll,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFD92D20),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Fermer toutes les sessions'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRevoke(AccountDevice device) async {
    final confirmed = await _confirm(
      device.current ? 'Déconnecter cet appareil ?' : 'Révoquer cet appareil ?',
      device.current
          ? 'Vous serez immédiatement redirigé vers la connexion.'
          : 'Toutes ses sessions seront fermées.',
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<AccountSecurityProvider>().revokeDevice(device);
    } catch (_) {}
  }

  Future<void> _confirmRevokeOthers() async {
    final confirmed = await _confirm(
      'Révoquer les autres appareils ?',
      'Votre session actuelle restera ouverte.',
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<AccountSecurityProvider>().revokeOtherDevices();
    } catch (_) {}
  }

  Future<void> _confirmLogoutAll() async {
    final confirmed = await _confirm(
      'Fermer toutes les sessions ?',
      'Vous serez également déconnecté de cet appareil.',
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<AccountSecurityProvider>().logoutAll();
    } catch (_) {}
  }

  Future<bool?> _confirm(String title, String message) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Confirmer'),
        ),
      ],
    ),
  );
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.busy,
    required this.onRevoke,
  });
  final AccountDevice device;
  final bool busy;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final seen = device.lastSeenAt == null
        ? 'Activité inconnue'
        : 'Vu ${DateFormat('dd/MM/yyyy · HH:mm').format(device.lastSeenAt!.toLocal())}';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: ListTile(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFE1E7E5)),
        ),
        contentPadding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
        leading: Icon(
          device.platform.toLowerCase().contains('web')
              ? Icons.language_rounded
              : Icons.phone_iphone_rounded,
          color: const Color(0xFF087A65),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                device.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (device.current)
              const Text(
                'Cet appareil',
                style: TextStyle(
                  color: Color(0xFF087A65),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        subtitle: Text(
          '$seen · ${device.activeSessionCount} session${device.activeSessionCount == 1 ? '' : 's'} active${device.activeSessionCount == 1 ? '' : 's'}',
        ),
        trailing: busy
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : IconButton(
                tooltip: device.current ? 'Déconnecter' : 'Révoquer',
                onPressed: onRevoke,
                icon: const Icon(Icons.logout_rounded),
              ),
      ),
    );
  }
}
