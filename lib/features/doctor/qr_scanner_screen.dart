import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../core/network/app_http_client.dart';
import 'medical_access/doctor_medical_access.dart';
import 'medical_access/doctor_medical_access_api.dart';
import 'medical_access/doctor_medical_access_controller.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({
    super.key,
    required this.consultationId,
    this.controller,
    this.cameraEnabled = true,
    this.onActivated,
  });

  final String consultationId;
  final DoctorMedicalAccessController? controller;

  /// Tests can disable the platform camera while exercising the scan boundary.
  final bool cameraEnabled;
  final FutureOr<void> Function()? onActivated;

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  late DoctorMedicalAccessController _controller;
  bool _ownsController = false;
  bool _initialized = false;
  final TextEditingController _manualCodeController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final injected = widget.controller;
    if (injected != null) {
      _controller = injected;
    } else {
      _ownsController = true;
      _controller = DoctorMedicalAccessController(
        api: DoctorMedicalAccessApi(context.read<AppHttpClient>()),
        consultationId: widget.consultationId,
      );
    }
  }

  @override
  void dispose() {
    _manualCodeController.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _handleCapture(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        unawaited(_consume(value));
        return;
      }
    }
  }

  void _submitDevelopmentToken() {
    final value = _manualCodeController.text.trim();
    if (value.isEmpty) return;
    FocusScope.of(context).unfocus();
    unawaited(_consume(value));
  }

  Future<void> _consume(String value) async {
    if (await _controller.consume(value)) await widget.onActivated?.call();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _mainContent(),
            _topBar(),
            if (_controller.status == DoctorMedicalAccessStatus.ready)
              _bottomInstructions(),
          ],
        ),
      ),
    );
  }

  Widget _mainContent() => switch (_controller.status) {
    DoctorMedicalAccessStatus.ready => _scannerSurface(),
    DoctorMedicalAccessStatus.submitting => _statusPanel(
      key: const ValueKey('medical-access-submitting'),
      icon: const SizedBox(
        width: 46,
        height: 46,
        child: CircularProgressIndicator(color: Color(0xFF1FBF9A)),
      ),
      title: 'Vérification du QR…',
      message: 'Activation sécurisée de l’accès pour cette consultation.',
    ),
    DoctorMedicalAccessStatus.active => _successPanel(),
    DoctorMedicalAccessStatus.error => _errorPanel(),
  };

  Widget _scannerSurface() {
    if (!widget.cameraEnabled) {
      return const ColoredBox(
        key: ValueKey('medical-access-camera-test-boundary'),
        color: Colors.black,
        child: Center(
          child: Icon(
            Icons.qr_code_scanner,
            size: 96,
            color: Color(0xFF1FBF9A),
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          key: const ValueKey('medical-access-camera'),
          onDetect: _handleCapture,
          errorBuilder: (context, error) => _cameraFailure(error),
          placeholderBuilder: (_) => const ColoredBox(
            color: Colors.black,
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF1FBF9A)),
            ),
          ),
        ),
        IgnorePointer(child: CustomPaint(painter: ScannerOverlayPainter())),
      ],
    );
  }

  Widget _cameraFailure(MobileScannerException error) {
    final permissionDenied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    final unsupported = error.errorCode == MobileScannerErrorCode.unsupported;
    return _statusPanel(
      key: const ValueKey('medical-access-camera-error'),
      icon: Icon(
        permissionDenied
            ? Icons.no_photography_outlined
            : Icons.camera_alt_outlined,
        size: 54,
        color: const Color(0xFF1FBF9A),
      ),
      title: permissionDenied
          ? 'Autorisation caméra refusée'
          : unsupported
          ? 'Caméra indisponible'
          : 'Impossible de démarrer le scanner',
      message: permissionDenied
          ? 'Autorisez la caméra dans les réglages de l’appareil, puis revenez sur cet écran.'
          : 'Vérifiez qu’une caméra est disponible, puis réessayez.',
    );
  }

  Widget _topBar() => Positioned(
    top: 0,
    left: 0,
    right: 0,
    child: Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.75), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scanner le QR du patient',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Consultation active sécurisée',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _bottomInstructions() => Positioned(
    bottom: 0,
    left: 0,
    right: 0,
    child: Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
        top: 20,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1FBF9A).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.qr_code_scanner,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Placez le QR médical dans le cadre',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('medical-access-debug-token-input'),
              controller: _manualCodeController,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Développement local — payload QR opaque',
                labelStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.code, color: Colors.white70),
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.45),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) => _submitDevelopmentToken(),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const ValueKey('medical-access-debug-submit'),
                onPressed: _submitDevelopmentToken,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                ),
                child: const Text('Tester ce payload opaque'),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_user, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Vérification sécurisée — aucune identité décodée',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _successPanel() => _statusPanel(
    key: const ValueKey('medical-access-active'),
    icon: const Icon(
      Icons.verified_rounded,
      size: 72,
      color: Color(0xFF1FBF9A),
    ),
    title: 'Accès médical activé',
    message:
        'Le QR a été vérifié pour cette consultation. Les préférences du patient restent applicables.',
    actions: [
      ElevatedButton(
        key: const ValueKey('medical-access-continue'),
        onPressed: () => Navigator.pop(context, _controller.activation),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1FBF9A),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
        child: const Text('Continuer la consultation'),
      ),
    ],
  );

  Widget _errorPanel() => _statusPanel(
    key: const ValueKey('medical-access-error'),
    icon: const Icon(
      Icons.qr_code_2_outlined,
      size: 64,
      color: Color(0xFFFFB020),
    ),
    title: 'QR non vérifié',
    message:
        _controller.errorMessage ?? 'Présentez un autre QR puis réessayez.',
    actions: [
      if (_controller.canRetrySameCommand)
        ElevatedButton(
          key: const ValueKey('medical-access-retry-same-command'),
          onPressed: () => unawaited(_controller.retry()),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1FBF9A),
            foregroundColor: Colors.white,
          ),
          child: const Text('Réessayer'),
        ),
      OutlinedButton(
        key: const ValueKey('medical-access-scan-again'),
        onPressed: () {
          _manualCodeController.clear();
          _controller.scanAgain();
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white70),
        ),
        child: const Text('Scanner un autre QR'),
      ),
    ],
  );

  Widget _statusPanel({
    required Key key,
    required Widget icon,
    required String title,
    required String message,
    List<Widget> actions = const [],
  }) => ColoredBox(
    color: Colors.black,
    child: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 110, 28, 32),
          child: Column(
            key: key,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  height: 1.45,
                  color: Colors.white70,
                ),
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 24),
                Wrap(spacing: 12, runSpacing: 12, children: actions),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scanAreaSize = size.width * 0.7;
    final left = (size.width - scanAreaSize) / 2;
    final top = (size.height - scanAreaSize) / 2;
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.5);

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, top), overlayPaint);
    canvas.drawRect(Rect.fromLTWH(0, top, left, scanAreaSize), overlayPaint);
    canvas.drawRect(
      Rect.fromLTWH(left + scanAreaSize, top, left, scanAreaSize),
      overlayPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        top + scanAreaSize,
        size.width,
        size.height - top - scanAreaSize,
      ),
      overlayPaint,
    );

    final framePaint = Paint()
      ..color = const Color(0xFF1FBF9A)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    const cornerLength = 30.0;
    canvas.drawLine(
      Offset(left, top),
      Offset(left + cornerLength, top),
      framePaint,
    );
    canvas.drawLine(
      Offset(left, top),
      Offset(left, top + cornerLength),
      framePaint,
    );
    canvas.drawLine(
      Offset(left + scanAreaSize - cornerLength, top),
      Offset(left + scanAreaSize, top),
      framePaint,
    );
    canvas.drawLine(
      Offset(left + scanAreaSize, top),
      Offset(left + scanAreaSize, top + cornerLength),
      framePaint,
    );
    canvas.drawLine(
      Offset(left, top + scanAreaSize - cornerLength),
      Offset(left, top + scanAreaSize),
      framePaint,
    );
    canvas.drawLine(
      Offset(left, top + scanAreaSize),
      Offset(left + cornerLength, top + scanAreaSize),
      framePaint,
    );
    canvas.drawLine(
      Offset(left + scanAreaSize - cornerLength, top + scanAreaSize),
      Offset(left + scanAreaSize, top + scanAreaSize),
      framePaint,
    );
    canvas.drawLine(
      Offset(left + scanAreaSize, top + scanAreaSize - cornerLength),
      Offset(left + scanAreaSize, top + scanAreaSize),
      framePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
