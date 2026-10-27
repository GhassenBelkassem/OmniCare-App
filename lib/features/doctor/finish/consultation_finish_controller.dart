import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/utils/uuid_v4.dart';
import '../../scheduled_care/realtime/scheduled_care_event.dart';
import '../../scheduled_care/realtime/scheduled_care_realtime_coordinator.dart';
import '../clinical_record/clinical_record_controller.dart';
import 'consultation_finish.dart';
import 'consultation_finish_api.dart';

class ConsultationFinishController extends ChangeNotifier {
  ConsultationFinishController({
    required this.consultationId,
    required ConsultationFinishApiContract api,
    required ClinicalRecordController clinical,
  }) : _api = api,
       _clinical = clinical;
  final String consultationId;
  final ConsultationFinishApiContract _api;
  final ClinicalRecordController _clinical;
  ConsultationOperationalState? consultation;
  bool loading = false;
  bool submitting = false;
  String? failureCode;
  String? _key;
  int? _expectedConsultationVersion;
  int? _expectedClinicalRecordVersion;
  bool _disposed = false;
  Future<void> load() async {
    if (loading || _disposed) return;
    loading = true;
    notifyListeners();
    try {
      consultation = await _api.read(consultationId);
      failureCode = null;
    } catch (e) {
      failureCode = _code(e);
    } finally {
      if (!_disposed) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> finish() async {
    final current = consultation;
    final clinical = _clinical.authoritative;
    if (current == null || clinical == null || submitting) return;
    if (_clinical.dirty) {
      failureCode = 'UNSAVED_CLINICAL_CHANGES';
      notifyListeners();
      return;
    }
    if (_key == null) {
      _key = 'consultation-finish:${generateUuidV4()}';
      _expectedConsultationVersion = current.version;
      _expectedClinicalRecordVersion = clinical.clinicalRecordVersion;
    }
    submitting = true;
    failureCode = null;
    notifyListeners();
    try {
      consultation = await _api.finish(
        consultationId: consultationId,
        expectedConsultationVersion: _expectedConsultationVersion!,
        expectedClinicalRecordVersion: _expectedClinicalRecordVersion!,
        idempotencyKey: _key!,
      );
      if (consultation!.status == 'COMPLETED') _clearOperation();
    } catch (e) {
      failureCode = _code(e);
      if (!_ambiguous(e)) _clearOperation();
      await load();
    } finally {
      if (!_disposed) {
        submitting = false;
        notifyListeners();
      }
    }
  }

  void _clearOperation() {
    _key = null;
    _expectedConsultationVersion = null;
    _expectedClinicalRecordVersion = null;
  }

  Future<void> invalidate(ScheduledCareInvalidationEvent event) =>
      event.resourceType == ScheduledCareResourceType.consultation &&
          event.resourceId == consultationId.toLowerCase()
      ? load()
      : Future<void>.value();
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  static String _code(Object e) {
    if (e is DioException && e.response?.data is Map) {
      final body = e.response!.data as Map;
      final value = body['errorCode'] ?? body['code'];
      if (value is String && value.length <= 80) return value;
    }
    return 'FINISH_RECONCILIATION_REQUIRED';
  }

  static bool _ambiguous(Object e) =>
      e is DioException &&
      (e.response == null || (e.response?.statusCode ?? 0) >= 500);
}

class ConsultationFinishRealtimeTarget implements ScheduledCareRealtimeTarget {
  ConsultationFinishRealtimeTarget(this.controller);
  final ConsultationFinishController controller;
  bool _active = false;
  @override
  String get role => 'DOCTOR';
  @override
  void activate() => _active = true;
  @override
  void deactivate() => _active = false;
  @override
  Future<void> invalidate(ScheduledCareInvalidationEvent e) =>
      _active ? controller.invalidate(e) : Future<void>.value();
  @override
  Future<void> resync() => _active ? controller.load() : Future<void>.value();
  @override
  void dispose() => _active = false;
}
