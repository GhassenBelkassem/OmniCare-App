import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../patient_passport/sharing/medical_share_qr.dart';
import '../patient_passport/sharing/medical_share_qr_controller.dart';
import '../patient_passport/sharing/medical_sharing_models.dart';

class QRCodeModal extends StatefulWidget {
  const QRCodeModal({
    super.key,
    required this.patientName,
    required this.subject,
    this.isFamilyMember = false,
  });

  final String patientName;
  final MedicalSharingSubject subject;
  final bool isFamilyMember;

  @override
  State<QRCodeModal> createState() => _QRCodeModalState();
}

class _QRCodeModalState extends State<QRCodeModal> {
  MedicalShareQrController? _controller;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _controller = context.read<MedicalShareQrController>();
    scheduleMicrotask(() => _controller?.issue(widget.subject));
  }

  @override
  void dispose() {
    _controller?.clear(notify: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _header(context),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _patientCard(),
                    const SizedBox(height: 24),
                    Consumer<MedicalShareQrController>(
                      builder: (context, controller, _) =>
                          _qrState(context, controller),
                    ),
                    const SizedBox(height: 24),
                    _instructions(),
                    const SizedBox(height: 20),
                    _securityNote(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1FBF9A), Color(0xFF0F6F73)],
      ),
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'QR Code Médical',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.isFamilyMember
                    ? 'Membre de la famille'
                    : 'Mon carnet de santé',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          key: const ValueKey('medical-share-qr-close'),
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: Colors.white),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.2),
          ),
        ),
      ],
    ),
  );

  Widget _patientCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFF4F5F7),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF1FBF9A).withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF1FBF9A), width: 2),
          ),
          child: const Icon(Icons.person, color: Color(0xFF1FBF9A), size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.patientName,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A202C),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Code temporaire sécurisé',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: const Color(0xFF667085),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _qrState(BuildContext context, MedicalShareQrController controller) {
    return switch (controller.status) {
      MedicalShareQrStatus.ready when controller.qr != null => _readyQr(
        context,
        controller.qr!,
      ),
      MedicalShareQrStatus.preview when controller.previewPayload != null =>
        _previewQr(controller.previewPayload!),
      MedicalShareQrStatus.expired => _stateCard(
        key: const ValueKey('medical-share-qr-expired'),
        icon: Icons.timer_off_outlined,
        title: 'QR expiré',
        message: 'Générez un nouveau code avant de le présenter au médecin.',
        actionLabel: 'Régénérer',
        onPressed: controller.regenerate,
      ),
      MedicalShareQrStatus.error => _stateCard(
        key: const ValueKey('medical-share-qr-error'),
        icon: Icons.cloud_off_outlined,
        title: 'QR indisponible',
        message: controller.errorMessage ?? 'Réessayez dans quelques instants.',
        actionLabel: 'Réessayer',
        onPressed: controller.retry,
      ),
      _ => Container(
        key: const ValueKey('medical-share-qr-loading'),
        height: 264,
        alignment: Alignment.center,
        decoration: _qrDecoration(),
        child: const CircularProgressIndicator(color: Color(0xFF1FBF9A)),
      ),
    };
  }

  Widget _readyQr(BuildContext context, MedicalShareQr qr) => Column(
    key: const ValueKey('medical-share-qr-ready'),
    children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: _qrDecoration(),
        child: _qrImage(qr.payload),
      ),
      const SizedBox(height: 10),
      Text(
        'Valable jusqu’à ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(qr.expiresAt.toLocal()))}',
        key: const ValueKey('medical-share-qr-expiry'),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF667085),
        ),
      ),
    ],
  );

  Widget _previewQr(String payload) => Column(
    key: const ValueKey('medical-share-qr-preview'),
    children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: _qrDecoration(),
        child: _qrImage(payload),
      ),
      const SizedBox(height: 10),
      Text(
        'Aperçu — QR non valide',
        key: const ValueKey('medical-share-qr-preview-label'),
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFB54708),
        ),
      ),
    ],
  );

  Widget _qrImage(String payload) => QrImageView(
    key: const ValueKey('medical-share-qr-image'),
    data: payload,
    version: QrVersions.auto,
    size: 220,
    backgroundColor: Colors.white,
    eyeStyle: const QrEyeStyle(
      eyeShape: QrEyeShape.square,
      color: Color(0xFF0F6F73),
    ),
    dataModuleStyle: const QrDataModuleStyle(
      dataModuleShape: QrDataModuleShape.square,
      color: Color(0xFF1FBF9A),
    ),
  );

  BoxDecoration _qrDecoration() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: const Color(0xFF1FBF9A).withValues(alpha: 0.3),
      width: 2,
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF1FBF9A).withValues(alpha: 0.1),
        blurRadius: 20,
        offset: const Offset(0, 4),
      ),
    ],
  );

  Widget _stateCard({
    required Key key,
    required IconData icon,
    required String title,
    required String message,
    required String actionLabel,
    required Future<void> Function() onPressed,
  }) => Container(
    key: key,
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: _qrDecoration(),
    child: Column(
      children: [
        Icon(icon, size: 52, color: const Color(0xFF0F6F73)),
        const SizedBox(height: 12),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A202C),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: const Color(0xFF667085),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1FBF9A),
            foregroundColor: Colors.white,
          ),
          child: Text(actionLabel),
        ),
      ],
    ),
  );

  Widget _instructions() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF1FBF9A).withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF1FBF9A).withValues(alpha: 0.2)),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline, color: Color(0xFF1FBF9A), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Présentez ce QR au médecin pendant la consultation. Il expire automatiquement.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: const Color(0xFF0F6F73),
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _securityNote() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.verified_user, color: Color(0xFF1FBF9A), size: 16),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          'Connexion sécurisée et cryptée',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF667085),
          ),
        ),
      ),
    ],
  );
}
