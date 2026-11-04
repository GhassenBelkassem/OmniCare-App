import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/uuid_v4.dart';
import 'medical_share_qr.dart';
import 'medical_share_qr_api.dart';
import 'medical_sharing_models.dart';

class MedicalShareQrController extends ChangeNotifier {
  static const debugPreviewPayload = 'OMNICARE-DEMO-MEDICAL-QR-NOT-VALID';

  MedicalShareQrController(
    this._api, {
    DateTime Function()? now,
    String Function()? idempotencyKey,
    bool debugPreviewEnabled = true,
  }) : _now = now ?? DateTime.now,
       _idempotencyKey = idempotencyKey ?? generateUuidV4,
       _debugPreviewEnabled = kDebugMode && debugPreviewEnabled;

  final MedicalShareQrApiContract _api;
  final DateTime Function() _now;
  final String Function() _idempotencyKey;
  final bool _debugPreviewEnabled;

  MedicalShareQrStatus _status = MedicalShareQrStatus.idle;
  MedicalSharingSubject? _subject;
  MedicalShareQr? _qr;
  String? _previewPayload;
  String? _errorMessage;
  String? _retryKey;
  Timer? _expiryTimer;
  int _generation = 0;
  bool _disposed = false;

  MedicalShareQrStatus get status => _status;
  MedicalSharingSubject? get subject => _subject;
  MedicalShareQr? get qr => _qr;
  String? get previewPayload => _previewPayload;
  String? get errorMessage => _errorMessage;

  Future<void> issue(MedicalSharingSubject subject) =>
      _issue(subject, reuseAttempt: false);

  Future<void> retry() async {
    final selected = _subject;
    if (selected == null) return;
    await _issue(selected, reuseAttempt: true);
  }

  Future<void> regenerate() async {
    final selected = _subject;
    if (selected == null) return;
    await _issue(selected, reuseAttempt: false);
  }

  Future<void> _issue(
    MedicalSharingSubject subject, {
    required bool reuseAttempt,
  }) async {
    if (_status == MedicalShareQrStatus.loading) return;
    final generation = ++_generation;
    _expiryTimer?.cancel();
    _qr = null;
    _previewPayload = null;
    _subject = subject;
    _errorMessage = null;
    _status = MedicalShareQrStatus.loading;
    final key = reuseAttempt && _retryKey != null
        ? _retryKey!
        : _idempotencyKey();
    _retryKey = key;
    _notify();

    try {
      final issued = await _api.issueQr(subject, idempotencyKey: key);
      if (_disposed || generation != _generation) return;
      _retryKey = null;
      if (!issued.expiresAt.isAfter(_now().toUtc())) {
        _status = MedicalShareQrStatus.expired;
        _notify();
        return;
      }
      _qr = issued;
      _status = MedicalShareQrStatus.ready;
      _scheduleExpiry(issued, generation);
      _notify();
    } catch (error) {
      if (_disposed || generation != _generation) return;
      _qr = null;
      if (_canShowDebugPreview(error)) {
        _retryKey = null;
        _previewPayload = debugPreviewPayload;
        _status = MedicalShareQrStatus.preview;
      } else {
        _status = MedicalShareQrStatus.error;
        _errorMessage = _safeMessage(error);
      }
      _notify();
    }
  }

  bool _canShowDebugPreview(Object error) {
    return _debugPreviewEnabled &&
        error is ApiException &&
        error.statusCode == 404 &&
        error.code == 'RESOURCE_NOT_FOUND';
  }

  void _scheduleExpiry(MedicalShareQr issued, int generation) {
    final delay = issued.expiresAt.difference(_now().toUtc());
    _expiryTimer = Timer(delay, () {
      if (_disposed || generation != _generation) return;
      _qr = null;
      _retryKey = null;
      _status = MedicalShareQrStatus.expired;
      _notify();
    });
  }

  void clear({bool notify = true}) {
    _generation++;
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _subject = null;
    _qr = null;
    _previewPayload = null;
    _retryKey = null;
    _errorMessage = null;
    _status = MedicalShareQrStatus.idle;
    if (notify) _notify();
  }

  static String _safeMessage(Object error) {
    if (error is ApiException) {
      return switch (error.code) {
        'TOO_MANY_REQUESTS' =>
          'Trop de demandes. Patientez quelques minutes avant de réessayer.',
        'RESOURCE_NOT_FOUND' || 'CLINICAL_SUBJECT_UNAVAILABLE' =>
          'QR disponible pendant une consultation.',
        'UNAUTHORIZED' ||
        'AUTH_SESSION_EXPIRED' ||
        'AUTH_SESSION_INVALID' => 'Votre session a expiré. Reconnectez-vous.',
        _ => 'Le QR médical est temporairement indisponible. Réessayez.',
      };
    }
    return 'Le QR médical est temporairement indisponible. Réessayez.';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _generation++;
    _expiryTimer?.cancel();
    _qr = null;
    _previewPayload = null;
    _retryKey = null;
    _disposed = true;
    super.dispose();
  }
}
