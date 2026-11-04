import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';
import 'doctor_urgent_controller.dart';

enum DoctorUrgentQrScannerState { ready, scanning, verifying, success, invalid }

/// Static D6 QR-verification workflow.
///
/// This screen deliberately verifies no QR payload and creates no medical
/// access grant. Production QR signing, nonce use, and access authorization
/// remain server-side concerns.
class DoctorUrgentQrScannerScreen extends StatefulWidget {
  const DoctorUrgentQrScannerScreen({
    super.key,
    required this.request,
    this.initialState = DoctorUrgentQrScannerState.ready,
    this.verificationDelay = const Duration(milliseconds: 450),
    this.embedded = false,
    this.onBack,
    this.onOpenMedicalRecord,
  });

  final DoctorUrgentRequest request;
  final DoctorUrgentQrScannerState initialState;
  final Duration verificationDelay;
  final bool embedded;
  final VoidCallback? onBack;
  final VoidCallback? onOpenMedicalRecord;

  @override
  State<DoctorUrgentQrScannerScreen> createState() =>
      _DoctorUrgentQrScannerScreenState();
}

class _DoctorUrgentQrScannerScreenState
    extends State<DoctorUrgentQrScannerScreen> {
  late DoctorUrgentQrScannerState _state;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
  }

  Future<void> _simulateValidQr() async {
    if (_state == DoctorUrgentQrScannerState.verifying ||
        _state == DoctorUrgentQrScannerState.success) {
      return;
    }
    setState(() => _state = DoctorUrgentQrScannerState.verifying);
    final delay = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : widget.verificationDelay;
    await Future<void>.delayed(delay);
    if (!mounted || _state != DoctorUrgentQrScannerState.verifying) return;
    setState(() => _state = DoctorUrgentQrScannerState.success);
  }

  void _retry() => setState(() => _state = DoctorUrgentQrScannerState.ready);

  void _openMedicalRecord() {
    final callback = widget.onOpenMedicalRecord;
    if (callback != null) {
      callback();
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Dossier médical indisponible.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final motion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    final content = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.embedded) ...[
            _ContextNavigationRow(
              title: 'Scanner le QR',
              onBack: widget.onBack!,
            ),
            const SizedBox(height: 12),
          ],
          AnimatedSwitcher(
            duration: motion,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            child: switch (_state) {
              DoctorUrgentQrScannerState.success => KeyedSubtree(
                key: const ValueKey('urgent-qr-success'),
                child: _successContent(context),
              ),
              DoctorUrgentQrScannerState.invalid => KeyedSubtree(
                key: const ValueKey('urgent-qr-invalid'),
                child: _invalidContent(context),
              ),
              DoctorUrgentQrScannerState.ready ||
              DoctorUrgentQrScannerState.scanning ||
              DoctorUrgentQrScannerState.verifying => KeyedSubtree(
                key: ValueKey('urgent-qr-${_state.name}'),
                child: _scannerContent(context),
              ),
            },
          ),
        ],
      ),
    );
    if (widget.embedded) return content;
    return Scaffold(
      backgroundColor: OmniColors.pageBackground,
      appBar: AppBar(
        title: const Text('Scanner le QR'),
        leading: IconButton(
          tooltip: 'Retour',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(top: false, child: content),
    );
  }

  Widget _scannerContent(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Scannez le QR affiché par le patient.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: OmniColors.textSecondary),
      ),
      const SizedBox(height: 20),
      _ScannerSurface(state: _state),
      const SizedBox(height: 20),
      Text(
        'Placez le QR du patient dans le cadre',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      Text(
        'La vérification permet un accès temporaire au dossier médical pour cette consultation.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: OmniColors.textSecondary),
      ),
      if (_state == DoctorUrgentQrScannerState.verifying) ...[
        const SizedBox(height: 16),
        const Row(
          children: [
            SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Vérification du QR...'),
          ],
        ),
      ],
      const SizedBox(height: 20),
      _PatientContextCard(request: widget.request),
      if (kDebugMode && _state == DoctorUrgentQrScannerState.ready) ...[
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _simulateValidQr,
            child: const Text('Simuler un QR valide'),
          ),
        ),
      ],
    ],
  );

  Widget _successContent(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        label: 'QR vérifié',
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(OmniRadii.cardLarge),
            border: Border.all(color: OmniColors.borderLight),
            boxShadow: const [OmniColors.shadowCard],
          ),
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: OmniColors.mintSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  color: OmniColors.deepTeal,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'QR vérifié',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Accès médical autorisé pour cette consultation.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OmniColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: OmniColors.mintSoft,
                  borderRadius: BorderRadius.circular(OmniRadii.pill),
                ),
                child: Text(
                  'Accès temporaire',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: OmniColors.deepTeal,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      _PatientContextCard(request: widget.request),
      const SizedBox(height: 20),
      Semantics(
        button: true,
        label: 'Voir le dossier médical',
        child: FilledButton(
          onPressed: _openMedicalRecord,
          child: const Text('Voir le dossier médical'),
        ),
      ),
    ],
  );

  Widget _invalidContent(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(OmniRadii.cardLarge),
          border: Border.all(color: OmniColors.borderLight),
          boxShadow: const [OmniColors.shadowCard],
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: OmniColors.errorSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.qr_code_2_rounded,
                color: OmniColors.error,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'QR invalide ou expiré',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Demandez au patient d’afficher un nouveau QR.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: OmniColors.textSecondary),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      OutlinedButton(onPressed: _retry, child: const Text('Réessayer')),
    ],
  );
}

class _ContextNavigationRow extends StatelessWidget {
  const _ContextNavigationRow({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: 'Retour',
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    ],
  );
}

class _PatientContextCard extends StatelessWidget {
  const _PatientContextCard({required this.request});

  final DoctorUrgentRequest request;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '${request.patientName}, visite urgente',
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(color: OmniColors.borderLight),
        boxShadow: const [OmniColors.shadowSm],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: OmniColors.mintSoft,
            child: Text(
              'AC',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: OmniColors.deepTeal,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${request.patientName} · ${request.age} ans',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  'Visite urgente à domicile',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: OmniColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  request.id,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: OmniColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ScannerSurface extends StatelessWidget {
  const _ScannerSurface({required this.state});

  final DoctorUrgentQrScannerState state;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Zone de scan QR',
    child: Container(
      height: 250,
      decoration: BoxDecoration(
        color: OmniColors.slateBlue,
        borderRadius: BorderRadius.circular(OmniRadii.cardLarge),
      ),
      child: Center(
        child: SizedBox(
          width: 188,
          height: 188,
          child: Stack(
            children: [
              const Positioned(
                top: 0,
                left: 0,
                child: _ScannerCorner(top: true, left: true),
              ),
              const Positioned(
                top: 0,
                right: 0,
                child: _ScannerCorner(top: true, left: false),
              ),
              const Positioned(
                bottom: 0,
                left: 0,
                child: _ScannerCorner(top: false, left: true),
              ),
              const Positioned(
                bottom: 0,
                right: 0,
                child: _ScannerCorner(top: false, left: false),
              ),
              Center(
                child: Icon(
                  state == DoctorUrgentQrScannerState.verifying
                      ? Icons.shield_outlined
                      : Icons.qr_code_scanner_rounded,
                  color: Colors.white.withValues(alpha: .88),
                  size: 42,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ScannerCorner extends StatelessWidget {
  const _ScannerCorner({required this.top, required this.left});

  final bool top;
  final bool left;

  @override
  Widget build(BuildContext context) => Container(
    width: 32,
    height: 32,
    decoration: BoxDecoration(
      border: Border(
        top: top
            ? const BorderSide(color: OmniColors.freshMint, width: 3)
            : BorderSide.none,
        bottom: top
            ? BorderSide.none
            : const BorderSide(color: OmniColors.freshMint, width: 3),
        left: left
            ? const BorderSide(color: OmniColors.freshMint, width: 3)
            : BorderSide.none,
        right: left
            ? BorderSide.none
            : const BorderSide(color: OmniColors.freshMint, width: 3),
      ),
      borderRadius: BorderRadius.only(
        topLeft: top && left ? const Radius.circular(8) : Radius.zero,
        topRight: top && !left ? const Radius.circular(8) : Radius.zero,
        bottomLeft: !top && left ? const Radius.circular(8) : Radius.zero,
        bottomRight: !top && !left ? const Radius.circular(8) : Radius.zero,
      ),
    ),
  );
}
