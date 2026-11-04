import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/uuid_v4.dart';
import 'doctor_medical_access.dart';
import 'doctor_medical_access_api.dart';

class DoctorMedicalAccessController extends ChangeNotifier {
  DoctorMedicalAccessController({
    required DoctorMedicalAccessApiContract api,
    required String consultationId,
    String Function()? idempotencyKey,
  }) : _api = api,
       consultationId = _requiredConsultationId(consultationId),
       _idempotencyKey = idempotencyKey ?? generateUuidV4;

  final DoctorMedicalAccessApiContract _api;
  final String consultationId;
  final String Function() _idempotencyKey;

  DoctorMedicalAccessStatus _status = DoctorMedicalAccessStatus.ready;
  DoctorMedicalAccessActivation? _activation;
  String? _errorCode;
  String? _errorMessage;
  String? _attemptPayload;
  String? _attemptKey;
  bool _disposed = false;

  DoctorMedicalAccessStatus get status => _status;
  DoctorMedicalAccessActivation? get activation => _activation;
  String? get errorCode => _errorCode;
  String? get errorMessage => _errorMessage;

  Future<bool> consume(String candidate) async {
    if (_status == DoctorMedicalAccessStatus.submitting ||
        _status == DoctorMedicalAccessStatus.active) {
      return false;
    }
    final payload = candidate.trim();
    if (payload.isEmpty) return false;
    _attemptPayload = payload;
    _attemptKey = _idempotencyKey();
    return _submit();
  }

  Future<bool> retry() async {
    if (_attemptPayload == null || _attemptKey == null) return false;
    if (_status == DoctorMedicalAccessStatus.submitting ||
        _status == DoctorMedicalAccessStatus.active) {
      return false;
    }
    return _submit();
  }

  Future<bool> _submit() async {
    final payload = _attemptPayload;
    final key = _attemptKey;
    if (payload == null || key == null) return false;
    _status = DoctorMedicalAccessStatus.submitting;
    _activation = null;
    _errorCode = null;
    _errorMessage = null;
    _notify();
    try {
      final result = await _api.consumeQr(
        consultationId: consultationId,
        qrPayload: payload,
        idempotencyKey: key,
      );
      if (_disposed) return false;
      _activation = result;
      _attemptPayload = null;
      _attemptKey = null;
      _status = DoctorMedicalAccessStatus.active;
      _notify();
      return true;
    } catch (error) {
      if (_disposed) return false;
      _activation = null;
      _errorCode = error is ApiException ? error.code : null;
      _errorMessage = _safeMessage(error);
      _status = DoctorMedicalAccessStatus.error;
      _notify();
      return false;
    }
  }

  void scanAgain() {
    if (_status == DoctorMedicalAccessStatus.submitting) return;
    _activation = null;
    _attemptPayload = null;
    _attemptKey = null;
    _errorCode = null;
    _errorMessage = null;
    _status = DoctorMedicalAccessStatus.ready;
    _notify();
  }

  void clear() {
    _activation = null;
    _attemptPayload = null;
    _attemptKey = null;
    _errorCode = null;
    _errorMessage = null;
    _status = DoctorMedicalAccessStatus.ready;
    _notify();
  }

  bool get canRetrySameCommand => switch (_errorCode) {
    'MRS_CONTEXT_PENDING' || 'MRS_UNAVAILABLE' => true,
    _ => false,
  };

  static String _safeMessage(Object error) {
    final code = error is ApiException ? error.code : null;
    return switch (code) {
      'MEDICAL_QR_EXPIRED' =>
        'Code expiré. Demandez au patient de générer un nouveau QR.',
      'MEDICAL_QR_INVALID' => 'Code invalide. Présentez un QR médical valide.',
      'MEDICAL_QR_ALREADY_USED' =>
        'Ce code a déjà été utilisé. Demandez un nouveau QR.',
      'MEDICAL_QR_CONTEXT_DENIED' =>
        'Ce QR ne correspond pas à la consultation active.',
      'MRS_CONTEXT_PENDING' =>
        'L’activation de la consultation est en préparation. Réessayez.',
      'MRS_CONTEXT_FAILED' =>
        'La consultation ne peut pas activer l’accès médical.',
      'PROFESSIONAL_NOT_ELIGIBLE' =>
        'L’accès médical n’est pas disponible pour ce professionnel.',
      'IDEMPOTENCY_KEY_REUSED' =>
        'Cette tentative est en conflit. Scannez à nouveau le QR.',
      'UNAUTHORIZED' ||
      'AUTH_SESSION_EXPIRED' ||
      'AUTH_SESSION_INVALID' => 'Votre session a expiré. Reconnectez-vous.',
      'TOO_MANY_REQUESTS' =>
        'Trop de tentatives. Patientez avant de réessayer.',
      _ => 'Le service médical est temporairement indisponible. Réessayez.',
    };
  }

  static String _requiredConsultationId(String value) {
    final id = value.trim();
    if (id.isEmpty) throw ArgumentError.value(value, 'consultationId');
    return id;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _attemptPayload = null;
    _attemptKey = null;
    _disposed = true;
    super.dispose();
  }
}
