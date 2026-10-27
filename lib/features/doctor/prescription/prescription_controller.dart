import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/utils/uuid_v4.dart';
import '../../scheduled_care/realtime/scheduled_care_event.dart';
import '../../scheduled_care/realtime/scheduled_care_realtime_coordinator.dart';
import 'prescription.dart';
import 'prescription_api.dart';

class PrescriptionController extends ChangeNotifier {
  PrescriptionController({
    required this.consultationId,
    required PrescriptionApiContract api,
  }) : _api = api;
  final String consultationId;
  final PrescriptionApiContract _api;
  PrescriptionEnvelope? authoritative;
  PrescriptionDraft draft = PrescriptionDraft();
  bool isLoading = false,
      isSaving = false,
      isFinalizing = false,
      conflict = false,
      newerVersionAvailable = false;
  String? failureCode,
      _pendingKey,
      _pendingFingerprint,
      _finalizeKey,
      _finalizeFingerprint;
  bool _disposed = false;
  bool get dirty =>
      authoritative != null &&
      draft.fingerprint() != authoritative!.content.fingerprint();
  Future<void> load({bool force = false}) async {
    if (isLoading || _disposed) return;
    if (dirty && !force) {
      newerVersionAvailable = true;
      notifyListeners();
      return;
    }
    isLoading = true;
    failureCode = null;
    notifyListeners();
    try {
      final value = await _api.read(consultationId);
      if (_disposed) return;
      authoritative = value;
      draft = value.content.copy();
      conflict = false;
      newerVersionAvailable = false;
      _pendingKey = null;
      _pendingFingerprint = null;
    } catch (error) {
      if (!_disposed) failureCode = _code(error);
    } finally {
      if (!_disposed) {
        isLoading = false;
        notifyListeners();
      }
    }
  }

  void update(void Function(PrescriptionDraft value) change) {
    change(draft);
    final fingerprint = draft.fingerprint();
    if (_pendingFingerprint != fingerprint) {
      _pendingKey = null;
      _pendingFingerprint = null;
    }
    failureCode = null;
    notifyListeners();
  }

  Future<void> save() async {
    final current = authoritative;
    if (current == null ||
        current.finalized ||
        !dirty ||
        isSaving ||
        _disposed) {
      return;
    }
    final fp = draft.fingerprint();
    if (_pendingKey == null || _pendingFingerprint != fp) {
      _pendingKey = 'prescription-save:${generateUuidV4()}';
      _pendingFingerprint = fp;
    }
    isSaving = true;
    failureCode = null;
    conflict = false;
    notifyListeners();
    try {
      final value = await _api.save(
        consultationId: consultationId,
        expectedPrescriptionVersion: current.prescriptionVersion,
        idempotencyKey: _pendingKey!,
        prescription: draft,
      );
      if (_disposed) return;
      authoritative = value;
      draft = value.content.copy();
      _pendingKey = null;
      _pendingFingerprint = null;
      newerVersionAvailable = false;
    } catch (error) {
      if (!_disposed) {
        failureCode = _code(error);
        conflict = failureCode == 'PRESCRIPTION_VERSION_CONFLICT';
        if (!_ambiguous(error)) {
          _pendingKey = null;
          _pendingFingerprint = null;
        }
      }
    } finally {
      if (!_disposed) {
        isSaving = false;
        notifyListeners();
      }
    }
  }

  Future<void> finalize() async {
    final current = authoritative;
    if (current == null ||
        current.finalized ||
        dirty ||
        isFinalizing ||
        _disposed) {
      return;
    }
    final fp =
        '${current.prescriptionVersion}:${current.clinicalRecordVersion}';
    if (_finalizeKey == null || _finalizeFingerprint != fp) {
      _finalizeKey = 'prescription-finalize:${generateUuidV4()}';
      _finalizeFingerprint = fp;
    }
    isFinalizing = true;
    failureCode = null;
    notifyListeners();
    try {
      final value = await _api.finalize(
        consultationId: consultationId,
        expectedPrescriptionVersion: current.prescriptionVersion,
        expectedClinicalRecordVersion: current.clinicalRecordVersion,
        idempotencyKey: _finalizeKey!,
      );
      if (_disposed) return;
      authoritative = value;
      draft = value.content.copy();
      _finalizeKey = null;
      _finalizeFingerprint = null;
    } catch (error) {
      if (!_disposed) {
        failureCode = _code(error);
        conflict =
            failureCode == 'PRESCRIPTION_VERSION_CONFLICT' ||
            failureCode == 'CLINICAL_RECORD_VERSION_CONFLICT';
        if (!_ambiguous(error)) {
          _finalizeKey = null;
          _finalizeFingerprint = null;
        }
      }
    } finally {
      if (!_disposed) {
        isFinalizing = false;
        notifyListeners();
      }
    }
  }

  Future<void> invalidate(ScheduledCareInvalidationEvent event) {
    final prescriptionEvent =
        event.resourceType == ScheduledCareResourceType.prescription &&
        (event.rawEventType == 'PRESCRIPTION_UPDATED' ||
            event.rawEventType == 'PRESCRIPTION_FINALIZED');
    final clinicalDecisionEvent =
        event.resourceType == ScheduledCareResourceType.consultation &&
        event.rawEventType == 'CONSULTATION_UPDATED';
    if (event.resourceId != consultationId.toLowerCase() ||
        (!prescriptionEvent && !clinicalDecisionEvent)) {
      return Future.value();
    }
    return load();
  }

  void clear() {
    authoritative = null;
    draft = PrescriptionDraft();
    isLoading = false;
    isSaving = false;
    isFinalizing = false;
    conflict = false;
    newerVersionAvailable = false;
    failureCode = null;
    _pendingKey = null;
    _pendingFingerprint = null;
    _finalizeKey = null;
    _finalizeFingerprint = null;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    clear();
    super.dispose();
  }

  static String _code(Object error) {
    if (error is DioException && error.response?.data is Map) {
      final map = error.response!.data as Map;
      final value =
          map['errorCode'] ??
          map['code'] ??
          (map['error'] is Map ? (map['error'] as Map)['code'] : null);
      if (value is String && value.length <= 80) return value;
    }
    return 'MRS_UNAVAILABLE';
  }

  static bool _ambiguous(Object error) =>
      error is DioException &&
      (error.response == null || (error.response?.statusCode ?? 0) >= 500);
}

class PrescriptionRealtimeTarget implements ScheduledCareRealtimeTarget {
  PrescriptionRealtimeTarget(this.controller);
  final PrescriptionController controller;
  bool _active = false;
  @override
  String get role => 'DOCTOR';
  @override
  void activate() => _active = true;
  @override
  void deactivate() {
    _active = false;
    controller.clear();
  }

  @override
  Future<void> invalidate(ScheduledCareInvalidationEvent event) =>
      _active ? controller.invalidate(event) : Future.value();
  @override
  Future<void> resync() => _active ? controller.load() : Future.value();
  @override
  void dispose() => _active = false;
}
