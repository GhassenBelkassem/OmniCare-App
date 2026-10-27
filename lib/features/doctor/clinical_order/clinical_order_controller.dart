import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/utils/uuid_v4.dart';
import '../../scheduled_care/realtime/scheduled_care_event.dart';
import '../../scheduled_care/realtime/scheduled_care_realtime_coordinator.dart';
import 'clinical_order.dart';
import 'clinical_order_api.dart';

class ClinicalOrderEditor {
  ClinicalOrderEditor({
    required this.category,
    required this.original,
    this.orderId,
  }) : draft = original;
  final String? orderId;
  final ClinicalOrderCategory category;
  final ClinicalOrderDefinition original;
  ClinicalOrderDefinition draft;
  bool get dirty => original.fingerprint() != draft.fingerprint();
}

class ClinicalOrderController extends ChangeNotifier {
  ClinicalOrderController({
    required this.consultationId,
    required ClinicalOrderApiContract api,
  }) : _api = api;
  final String consultationId;
  final ClinicalOrderApiContract _api;
  List<ClinicalOrder> orders = const [];
  ClinicalOrderEditor? editor;
  bool isLoading = false,
      isSaving = false,
      conflict = false,
      newerVersionAvailable = false;
  String? finalizingId,
      failureCode,
      _pendingKey,
      _pendingFingerprint,
      _finalizeKey,
      _finalizeFingerprint;
  bool _disposed = false;
  bool get dirty => editor?.dirty ?? false;

  Future<void> load({bool force = false}) async {
    if (isLoading || _disposed) return;
    if (!force && (dirty || isSaving)) {
      newerVersionAvailable = true;
      notifyListeners();
      return;
    }
    isLoading = true;
    failureCode = null;
    notifyListeners();
    try {
      final values = await _api.list(consultationId);
      if (_disposed) return;
      orders = values;
      editor = null;
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

  void beginCreate(ClinicalOrderCategory category) {
    editor = ClinicalOrderEditor(
      category: category,
      original: const ClinicalOrderDefinition(),
    );
    _reset();
    notifyListeners();
  }

  void beginEdit(ClinicalOrder order) {
    if (order.status != ClinicalOrderStatus.draft) return;
    editor = ClinicalOrderEditor(
      orderId: order.id,
      category: order.category,
      original: order.definition,
    );
    _reset();
    notifyListeners();
  }

  void cancelEdit() {
    editor = null;
    _reset();
    notifyListeners();
  }

  void updateValue(String value) {
    final valueEditor = editor;
    if (valueEditor == null) return;
    valueEditor.draft = ClinicalOrderDefinition.forValue(
      valueEditor.category,
      value,
    );
    if (_pendingFingerprint != valueEditor.draft.fingerprint()) {
      _pendingKey = null;
      _pendingFingerprint = null;
    }
    failureCode = null;
    notifyListeners();
  }

  Future<void> save() async {
    final valueEditor = editor;
    if (valueEditor == null ||
        isSaving ||
        _disposed ||
        valueEditor.draft.value(valueEditor.category).trim().isEmpty) {
      return;
    }
    final fp =
        '${valueEditor.orderId ?? 'new'}:${valueEditor.category.wire}:${valueEditor.draft.fingerprint()}';
    if (_pendingKey == null || _pendingFingerprint != fp) {
      _pendingKey = 'order-save:${generateUuidV4()}';
      _pendingFingerprint = fp;
    }
    isSaving = true;
    failureCode = null;
    conflict = false;
    notifyListeners();
    try {
      final ClinicalOrder saved;
      if (valueEditor.orderId == null) {
        saved = await _api.create(
          consultationId: consultationId,
          idempotencyKey: _pendingKey!,
          category: valueEditor.category,
          definition: valueEditor.draft,
        );
      } else {
        final current = orders
            .where((value) => value.id == valueEditor.orderId)
            .firstOrNull;
        if (current == null) return;
        saved = await _api.update(
          consultationId: consultationId,
          idempotencyKey: _pendingKey!,
          order: current,
          definition: valueEditor.draft,
        );
      }
      if (_disposed) return;
      orders = [...orders.where((value) => value.id != saved.id), saved];
      editor = null;
      newerVersionAvailable = false;
      _pendingKey = null;
      _pendingFingerprint = null;
    } catch (error) {
      if (!_disposed) {
        failureCode = _code(error);
        conflict = failureCode == 'CLINICAL_ORDER_VERSION_CONFLICT';
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

  Future<void> finalize(ClinicalOrder order) async {
    if (_disposed ||
        order.status != ClinicalOrderStatus.draft ||
        finalizingId != null) {
      return;
    }
    final fp = '${order.id}:${order.version}:${order.definition.fingerprint()}';
    if (_finalizeKey == null || _finalizeFingerprint != fp) {
      _finalizeKey = 'order-finalize:${generateUuidV4()}';
      _finalizeFingerprint = fp;
    }
    finalizingId = order.id;
    failureCode = null;
    notifyListeners();
    try {
      final saved = await _api.finalize(
        consultationId: consultationId,
        idempotencyKey: _finalizeKey!,
        order: order,
      );
      if (_disposed) return;
      orders = orders
          .map((value) => value.id == saved.id ? saved : value)
          .toList(growable: false);
      if (editor?.orderId == saved.id) editor = null;
      _finalizeKey = null;
      _finalizeFingerprint = null;
    } catch (error) {
      if (!_disposed) {
        failureCode = _code(error);
        conflict = failureCode == 'CLINICAL_ORDER_VERSION_CONFLICT';
        if (!_ambiguous(error)) {
          _finalizeKey = null;
          _finalizeFingerprint = null;
        }
      }
    } finally {
      if (!_disposed) {
        finalizingId = null;
        notifyListeners();
      }
    }
  }

  Future<void> invalidate(ScheduledCareInvalidationEvent event) {
    if (event.resourceType != ScheduledCareResourceType.clinicalOrder ||
        event.rawEventType != 'CLINICAL_ORDER_UPDATED') {
      return Future.value();
    }
    return load();
  }

  void clear() {
    orders = const [];
    editor = null;
    isLoading = false;
    isSaving = false;
    conflict = false;
    newerVersionAvailable = false;
    finalizingId = null;
    failureCode = null;
    _pendingKey = null;
    _pendingFingerprint = null;
    _finalizeKey = null;
    _finalizeFingerprint = null;
    if (!_disposed) notifyListeners();
  }

  void _reset() {
    failureCode = null;
    conflict = false;
    newerVersionAvailable = false;
    _pendingKey = null;
    _pendingFingerprint = null;
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

class ClinicalOrderRealtimeTarget implements ScheduledCareRealtimeTarget {
  ClinicalOrderRealtimeTarget(this.controller);
  final ClinicalOrderController controller;
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
