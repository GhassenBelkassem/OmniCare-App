import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/utils/uuid_v4.dart';
import '../../scheduled_care/realtime/scheduled_care_event.dart';
import '../../scheduled_care/realtime/scheduled_care_realtime_coordinator.dart';
import 'clinical_record.dart';
import 'clinical_record_api.dart';

class ClinicalRecordController extends ChangeNotifier {
  ClinicalRecordController({
    required this.consultationId,
    required ClinicalRecordApiContract api,
  }) : _api = api;

  final String consultationId;
  final ClinicalRecordApiContract _api;
  ClinicalRecordEnvelope? authoritative;
  ClinicalRecordDraft draft = ClinicalRecordDraft();
  bool isLoading = false;
  bool isSaving = false;
  bool conflict = false;
  bool newerVersionAvailable = false;
  String? failureCode;
  String? _pendingKey;
  String? _pendingFingerprint;
  bool _disposed = false;

  bool get dirty =>
      authoritative != null &&
      draft.fingerprint() != authoritative!.record.fingerprint();

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
      draft = value.record.copy();
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

  void update(void Function(ClinicalRecordDraft value) change) {
    change(draft);
    final fingerprint = draft.fingerprint();
    if (_pendingFingerprint != null && _pendingFingerprint != fingerprint) {
      _pendingKey = null;
      _pendingFingerprint = null;
    }
    failureCode = null;
    notifyListeners();
  }

  Future<void> save() async {
    final current = authoritative;
    if (current == null || !dirty || isSaving || _disposed) return;
    final fingerprint = draft.fingerprint();
    if (_pendingKey == null || _pendingFingerprint != fingerprint) {
      _pendingKey = 'clinical-save:${generateUuidV4()}';
      _pendingFingerprint = fingerprint;
    }
    isSaving = true;
    conflict = false;
    failureCode = null;
    notifyListeners();
    try {
      final saved = await _api.save(
        consultationId: consultationId,
        expectedClinicalRecordVersion: current.clinicalRecordVersion,
        idempotencyKey: _pendingKey!,
        record: draft,
      );
      if (_disposed) return;
      authoritative = saved;
      draft = saved.record.copy();
      newerVersionAvailable = false;
      _pendingKey = null;
      _pendingFingerprint = null;
    } catch (error) {
      if (_disposed) return;
      failureCode = _code(error);
      conflict = failureCode == 'CLINICAL_RECORD_VERSION_CONFLICT';
      if (!_ambiguous(error)) {
        _pendingKey = null;
        _pendingFingerprint = null;
      }
    } finally {
      if (!_disposed) {
        isSaving = false;
        notifyListeners();
      }
    }
  }

  Future<void> invalidate(ScheduledCareInvalidationEvent event) {
    if (event.resourceType != ScheduledCareResourceType.consultation ||
        event.resourceId != consultationId.toLowerCase() ||
        event.rawEventType != 'CONSULTATION_UPDATED' ||
        (authoritative != null &&
            event.version <= authoritative!.clinicalRecordVersion)) {
      return Future<void>.value();
    }
    return load();
  }

  void clear() {
    authoritative = null;
    draft = ClinicalRecordDraft();
    isLoading = false;
    isSaving = false;
    conflict = false;
    newerVersionAvailable = false;
    failureCode = null;
    _pendingKey = null;
    _pendingFingerprint = null;
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
      final value = (error.response!.data as Map)['code'];
      if (value is String && value.length <= 80) return value;
    }
    return 'MRS_UNAVAILABLE';
  }

  static bool _ambiguous(Object error) =>
      error is DioException &&
      (error.response == null || (error.response?.statusCode ?? 0) >= 500);
}

class ClinicalRecordRealtimeTarget implements ScheduledCareRealtimeTarget {
  ClinicalRecordRealtimeTarget(this.controller);
  final ClinicalRecordController controller;
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
      _active ? controller.invalidate(event) : Future<void>.value();
  @override
  Future<void> resync() => _active ? controller.load() : Future<void>.value();
  @override
  void dispose() => _active = false;
}
