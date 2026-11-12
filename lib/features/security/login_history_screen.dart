import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'account_security_api.dart';
import 'account_security_provider.dart';
import '../../l10n/omni_localizations.dart';

const _teal = Color(0xFF087A65);
const _ink = Color(0xFF111827);
const _muted = Color(0xFF667085);
const _line = Color(0xFFE1E7E5);
const _danger = Color(0xFFD92D20);

class LoginHistoryScreen extends StatefulWidget {
  const LoginHistoryScreen({super.key});

  @override
  State<LoginHistoryScreen> createState() => _LoginHistoryScreenState();
}

class _LoginHistoryScreenState extends State<LoginHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      await context.read<AccountSecurityProvider>().loadHistory();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AccountSecurityProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        title: const Text('Historique de connexion'),
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
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _PrivacyNotice(),
                    if (provider.isHistoryLoading && provider.history.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 18),
                        child: LinearProgressIndicator(color: _teal),
                      ),
                    if (provider.hasHistoryError) ...[
                      const SizedBox(height: 14),
                      _HistoryError(
                        message: provider.historyErrorMessage(
                          OmniLocalizations.of(context),
                        )!,
                        onRetry: _load,
                      ),
                    ],
                    if (!provider.isHistoryLoading &&
                        provider.history.isEmpty &&
                        !provider.hasHistoryError)
                      const _EmptyHistory(),
                    if (provider.history.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      for (final event in provider.history) ...[
                        _HistoryEventTile(
                          event: event,
                          reporting: provider.reportingEventId == event.id,
                          onReport: () => _confirmReport(event),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                    if (provider.historyHasNext) ...[
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: provider.isHistoryLoading
                              ? null
                              : () async {
                                  try {
                                    await provider.loadMoreHistory();
                                  } catch (_) {}
                                },
                          icon: provider.isHistoryLoading
                              ? const SizedBox.square(
                                  dimension: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.expand_more_rounded),
                          label: const Text('Afficher plus'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmReport(AuthHistoryEvent event) async {
    final hasPassword = context.read<AccountSecurityProvider>().hasPassword;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.gpp_maybe_outlined, color: _danger),
        title: const Text('Ce n’était pas vous ?'),
        content: Text(
          hasPassword
              ? 'Toutes les sessions seront fermées immédiatement. À votre prochaine connexion, OmniCare vous demandera de remplacer votre mot de passe.'
              : 'Toutes les sessions seront fermées immédiatement. Reconnectez-vous avec Google, puis vérifiez la sécurité de votre compte.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: _danger),
            icon: const Icon(Icons.report_outlined),
            label: const Text('Signaler et sécuriser'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<AccountSecurityProvider>().reportHistoryEvent(event);
    } catch (_) {}
  }
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F8F3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.privacy_tip_outlined, color: _teal, size: 21),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'Activité des 30 derniers jours. Les adresses IP et les données '
              'de localisation précises ne sont jamais affichées.',
              style: TextStyle(color: _ink, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryEventTile extends StatelessWidget {
  const _HistoryEventTile({
    required this.event,
    required this.reporting,
    required this.onReport,
  });

  final AuthHistoryEvent event;
  final bool reporting;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final color = event.succeeded ? _teal : _danger;
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_eventIcon(event), color: color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.label,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat(
                        'dd/MM/yyyy · HH:mm',
                      ).format(event.timestamp.toLocal()),
                      style: const TextStyle(color: _muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  event.succeeded ? 'Réussie' : 'Refusée',
                  style: TextStyle(
                    color: color,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          _DetailLine(icon: Icons.devices_outlined, text: event.device),
          const SizedBox(height: 7),
          _DetailLine(
            icon: Icons.location_on_outlined,
            text: event.location.label,
          ),
          const SizedBox(height: 7),
          _DetailLine(
            icon: Icons.key_outlined,
            text: _methodLabel(event.authenticationMethod),
          ),
          if (event.failureReason != null) ...[
            const SizedBox(height: 9),
            Text(
              event.failureReason!,
              style: const TextStyle(color: _danger, fontSize: 12.5),
            ),
          ],
          if (event.reported) ...[
            const SizedBox(height: 11),
            const Row(
              children: [
                Icon(Icons.flag_outlined, size: 17, color: _muted),
                SizedBox(width: 7),
                Text(
                  'Activité signalée',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ] else if (event.reportable) ...[
            const SizedBox(height: 7),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: reporting ? null : onReport,
                style: TextButton.styleFrom(foregroundColor: _danger),
                icon: reporting
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.gpp_maybe_outlined, size: 18),
                label: const Text('Ce n’était pas moi'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _eventIcon(AuthHistoryEvent event) {
    if (event.type.contains('PHONE_CHANGE')) return Icons.phone_iphone_rounded;
    if (event.type.contains('PASSWORD')) return Icons.password_rounded;
    if (event.type.contains('LOGOUT') || event.type.contains('REVOKED')) {
      return Icons.logout_rounded;
    }
    return event.succeeded
        ? Icons.verified_user_outlined
        : Icons.shield_outlined;
  }

  String _methodLabel(String method) {
    return switch (method) {
      'PASSWORD' => 'Mot de passe',
      'GOOGLE' => 'Google',
      'PHONE' => 'Code SMS',
      _ => 'Méthode non disponible',
    };
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 17, color: _muted),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _muted, fontSize: 13),
        ),
      ),
    ],
  );
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 64),
    child: Column(
      children: [
        Icon(Icons.verified_user_outlined, color: _teal, size: 44),
        SizedBox(height: 14),
        Text(
          'Tout est normal',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 6),
        Text(
          'Aucune activité de connexion à afficher.',
          style: TextStyle(color: _muted),
        ),
      ],
    ),
  );
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.message, required this.onRetry});
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
