import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/utils/uuid_v4.dart';
import '../../scheduled_care/data/scheduled_care_failure.dart';
import '../../scheduled_care/domain/scheduled_care_models.dart';
import '../scheduled_care/doctor_scheduled_care_models.dart';
import '../scheduled_care/doctor_scheduled_care_repository.dart';

enum DoctorAgendaView { month, day }

class DoctorAgendaController extends ChangeNotifier {
  DoctorAgendaController({
    required DoctorScheduledCareRepository repository,
    required String doctorId,
    DateTime? initialDate,
    DateTime Function()? clock,
    String Function()? uuidFactory,
    Future<void> Function()? onMutation,
  }) : _repository = repository,
       _doctorId = doctorId,
       _clock = clock ?? DateTime.now,
       _uuidFactory = uuidFactory ?? generateUuidV4,
       _onMutation = onMutation,
       _selectedDate = DateUtils.dateOnly(initialDate ?? DateTime.now()),
       _focusedDate = DateUtils.dateOnly(initialDate ?? DateTime.now());

  final DoctorScheduledCareRepository _repository;
  final String _doctorId;
  final DateTime Function() _clock;
  final String Function() _uuidFactory;
  Future<void> Function()? _onMutation;
  final Map<String, String> _commandKeys = <String, String>{};

  DateTime _selectedDate;
  DateTime _focusedDate;
  DoctorAgendaView _view = DoctorAgendaView.month;
  List<DoctorScheduledCareItem> _records = const [];
  AvailabilityWindow? _proposalAvailability;
  ScheduledCareFailure? _failure;
  bool _loading = false;
  bool _loadingDetail = false;
  bool _loadingAvailability = false;
  bool _submitting = false;
  bool _disposed = false;
  int _rangeGeneration = 0;
  int _sessionGeneration = 0;

  DateTime get selectedDate => _selectedDate;
  DateTime get focusedDate => _focusedDate;
  DoctorAgendaView get view => _view;
  List<DoctorScheduledCareItem> get records => _records;
  AvailabilityWindow? get proposalAvailability => _proposalAvailability;
  List<ScheduledCareSlot> get proposalSlots =>
      _proposalAvailability?.slots ?? const [];
  ScheduledCareFailure? get failure => _failure;
  bool get isLoading => _loading;
  bool get isLoadingDetail => _loadingDetail;
  bool get isLoadingAvailability => _loadingAvailability;
  bool get isSubmitting => _submitting;

  set onMutation(Future<void> Function()? value) => _onMutation = value;

  List<DoctorScheduledCareItem> recordsFor(DateTime date) =>
      _records.where((item) {
          final local = displayInTimeZone(
            item.activeSlot.start,
            item.cabinet.timezone,
          );
          return local.year == date.year &&
              local.month == date.month &&
              local.day == date.day;
        }).toList()
        ..sort((a, b) => a.activeSlot.start.compareTo(b.activeSlot.start));

  Future<void> loadFocusedMonth() async {
    final from = DateTime.utc(_focusedDate.year, _focusedDate.month);
    final to = DateTime.utc(_focusedDate.year, _focusedDate.month + 1);
    final generation = ++_rangeGeneration;
    _loading = true;
    _failure = null;
    _notify();
    try {
      final agenda = await _repository.getAgenda(from: from, to: to);
      if (generation != _rangeGeneration) return;
      _records = agenda.items;
    } on ScheduledCareFailure catch (failure) {
      if (generation == _rangeGeneration) _failure = failure;
    } finally {
      if (generation == _rangeGeneration) {
        _loading = false;
        _notify();
      }
    }
  }

  Future<void> resync() => loadFocusedMonth();

  Future<DoctorScheduledCareItem?> refreshItem(
    DoctorScheduledCareItem item,
  ) async {
    final sessionGeneration = _sessionGeneration;
    _loadingDetail = true;
    _failure = null;
    _notify();
    try {
      final refreshed = switch (item.resourceType) {
        ScheduledCareResourceType.bookingRequest =>
          DoctorScheduledCareItem.fromRequest(
            await _repository.getRequest(item.requestId!),
          ),
        ScheduledCareResourceType.appointment =>
          DoctorScheduledCareItem.fromAppointment(
            await _repository.getAppointment(item.appointmentId!),
          ),
      };
      if (sessionGeneration != _sessionGeneration) return null;
      _upsert(refreshed);
      return refreshed;
    } on ScheduledCareFailure catch (failure) {
      if (sessionGeneration == _sessionGeneration) _failure = failure;
      return null;
    } finally {
      if (sessionGeneration == _sessionGeneration) {
        _loadingDetail = false;
        _notify();
      }
    }
  }

  DoctorScheduledCareItem? itemByIdentity(
    ScheduledCareResourceType type,
    String id,
  ) {
    for (final item in _records) {
      if (item.resourceType == type && item.resourceId == id) return item;
    }
    return null;
  }

  Future<void> loadProposalAvailability(DoctorScheduledCareItem item) async {
    final sessionGeneration = _sessionGeneration;
    if (!item.can(ScheduledCareAction.proposeNewTime)) return;
    var current = item;
    if (current.cabinet.practiceLocationId == null) {
      final refreshed = await refreshItem(current);
      if (refreshed == null) return;
      current = refreshed;
    }
    final locationId = current.cabinet.practiceLocationId;
    if (locationId == null) return;
    _loadingAvailability = true;
    _proposalAvailability = null;
    _failure = null;
    _notify();
    try {
      final from = _clock().toUtc();
      final result = await _repository.getProposalAvailability(
        doctorId: _doctorId,
        practiceLocationId: locationId,
        from: from,
        to: from.add(const Duration(days: 21)),
      );
      if (sessionGeneration != _sessionGeneration) return;
      if (result.doctorId != _doctorId ||
          result.practiceLocationId != locationId) {
        throw const ScheduledCareFailure(
          message: 'La réponse du serveur est invalide.',
          errorCode: 'INVALID_RESPONSE',
        );
      }
      _proposalAvailability = result;
    } on ScheduledCareFailure catch (failure) {
      if (sessionGeneration == _sessionGeneration) _failure = failure;
    } finally {
      if (sessionGeneration == _sessionGeneration) {
        _loadingAvailability = false;
        _notify();
      }
    }
  }

  Future<bool> accept(DoctorScheduledCareItem item) async {
    if (item.resourceType != ScheduledCareResourceType.bookingRequest ||
        !item.can(ScheduledCareAction.acceptRequest) ||
        _submitting) {
      return false;
    }
    final identity = 'accept:${item.requestId}:${item.version}';
    final key = _commandKeys.putIfAbsent(identity, _uuidFactory);
    return _runCommand(
      identity: identity,
      operation: (sessionGeneration) async {
        final result = await _repository.acceptRequest(
          requestId: item.requestId!,
          expectedVersion: item.version,
          idempotencyKey: key,
        );
        if (sessionGeneration != _sessionGeneration) return;
        _removeIdentity(item);
        _upsert(DoctorScheduledCareItem.fromAppointment(result.appointment));
      },
      reconcile: () => _reconcile(item),
    );
  }

  Future<bool> propose(
    DoctorScheduledCareItem item,
    ScheduledCareSlot slot,
  ) async {
    if (item.resourceType != ScheduledCareResourceType.bookingRequest ||
        !item.can(ScheduledCareAction.proposeNewTime) ||
        _submitting) {
      return false;
    }
    final available = _proposalAvailability;
    final locationId = item.cabinet.practiceLocationId;
    final exact = available?.slots.any(
      (candidate) =>
          candidate.start.isAtSameMomentAs(slot.start) &&
          candidate.end.isAtSameMomentAs(slot.end),
    );
    if (locationId == null ||
        available?.practiceLocationId != locationId ||
        exact != true) {
      return false;
    }
    final identity = 'propose:${item.requestId}:${item.version}';
    final key = _commandKeys.putIfAbsent(identity, _uuidFactory);
    final succeeded = await _runCommand(
      identity: identity,
      operation: (sessionGeneration) async {
        final result = await _repository.proposeNewTime(
          requestId: item.requestId!,
          expectedVersion: item.version,
          practiceLocationId: locationId,
          proposedSlot: slot,
          idempotencyKey: key,
        );
        if (sessionGeneration != _sessionGeneration) return;
        _upsert(DoctorScheduledCareItem.fromRequest(result));
        _proposalAvailability = null;
      },
      reconcile: () => _reconcile(item),
    );
    if (!succeeded &&
        (_failure?.errorCode == 'SLOT_NO_LONGER_AVAILABLE' ||
            _failure?.errorCode == 'SLOT_NOT_AVAILABLE')) {
      final commandFailure = _failure;
      final current =
          itemByIdentity(item.resourceType, item.resourceId) ?? item;
      await loadProposalAvailability(current);
      _failure = commandFailure;
      _notify();
    }
    return succeeded;
  }

  Future<bool> decline(
    DoctorScheduledCareItem item,
    DoctorDeclineReason reason,
  ) async {
    if (item.resourceType != ScheduledCareResourceType.bookingRequest ||
        !item.can(ScheduledCareAction.declineRequest) ||
        _submitting) {
      return false;
    }
    final identity = 'decline:${item.requestId}:${item.version}';
    final key = _commandKeys.putIfAbsent(identity, _uuidFactory);
    return _runCommand(
      identity: identity,
      operation: (sessionGeneration) async {
        final result = await _repository.declineRequest(
          requestId: item.requestId!,
          expectedVersion: item.version,
          reasonCode: reason.wireName,
          idempotencyKey: key,
        );
        if (sessionGeneration != _sessionGeneration) return;
        _upsert(DoctorScheduledCareItem.fromRequest(result));
      },
      reconcile: () => _reconcile(item),
    );
  }

  Future<bool> cancel(
    DoctorScheduledCareItem item,
    DoctorAppointmentCancellationReason reason,
  ) async {
    if (item.resourceType != ScheduledCareResourceType.appointment ||
        !item.can(ScheduledCareAction.cancelAppointment) ||
        _submitting) {
      return false;
    }
    final identity = 'cancel:${item.appointmentId}:${item.version}';
    final key = _commandKeys.putIfAbsent(identity, _uuidFactory);
    return _runCommand(
      identity: identity,
      operation: (sessionGeneration) async {
        final result = await _repository.cancelAppointment(
          appointmentId: item.appointmentId!,
          expectedVersion: item.version,
          reasonCode: reason.wireName,
          idempotencyKey: key,
        );
        if (sessionGeneration != _sessionGeneration) return;
        _upsert(DoctorScheduledCareItem.fromAppointment(result));
      },
      reconcile: () => _reconcile(item),
    );
  }

  Future<bool> _runCommand({
    required String identity,
    required Future<void> Function(int sessionGeneration) operation,
    required Future<void> Function() reconcile,
  }) async {
    final sessionGeneration = _sessionGeneration;
    _submitting = true;
    _failure = null;
    _notify();
    try {
      await operation(sessionGeneration);
      if (sessionGeneration != _sessionGeneration) return false;
      _commandKeys.remove(identity);
      await _onMutation?.call();
      if (sessionGeneration != _sessionGeneration) return false;
      return true;
    } on ScheduledCareFailure catch (failure) {
      if (sessionGeneration != _sessionGeneration) return false;
      _failure = failure;
      final slotRace =
          failure.errorCode == 'SLOT_NO_LONGER_AVAILABLE' ||
          failure.errorCode == 'SLOT_NOT_AVAILABLE';
      if (failure.unknownOutcome ||
          failure.versionConflict ||
          slotRace ||
          (failure.statusCode == 409 && !_isIdempotencyConflict(failure))) {
        await reconcile();
      }
      if (!failure.unknownOutcome && !_isIdempotencyConflict(failure)) {
        _commandKeys.remove(identity);
      }
      return false;
    } finally {
      if (sessionGeneration == _sessionGeneration) {
        _submitting = false;
        _notify();
      }
    }
  }

  Future<void> _reconcile(DoctorScheduledCareItem item) async {
    final sessionGeneration = _sessionGeneration;
    try {
      final refreshed = switch (item.resourceType) {
        ScheduledCareResourceType.bookingRequest =>
          DoctorScheduledCareItem.fromRequest(
            await _repository.getRequest(item.requestId!),
          ),
        ScheduledCareResourceType.appointment =>
          DoctorScheduledCareItem.fromAppointment(
            await _repository.getAppointment(item.appointmentId!),
          ),
      };
      if (sessionGeneration != _sessionGeneration) return;
      _upsert(refreshed);
      await _onMutation?.call();
    } on ScheduledCareFailure {
      // Keep the original command failure visible and the key reusable.
    }
  }

  void selectDate(DateTime date, {DateTime? focusedDate}) {
    _selectedDate = DateUtils.dateOnly(date);
    final previousMonth = _focusedDate.month;
    final previousYear = _focusedDate.year;
    _focusedDate = DateUtils.dateOnly(focusedDate ?? date);
    _notify();
    if (_focusedDate.month != previousMonth ||
        _focusedDate.year != previousYear) {
      unawaited(loadFocusedMonth());
    }
  }

  void focusMonth(DateTime date) {
    final normalized = DateUtils.dateOnly(date);
    if (_focusedDate.year == normalized.year &&
        _focusedDate.month == normalized.month) {
      return;
    }
    _focusedDate = normalized;
    _notify();
    unawaited(loadFocusedMonth());
  }

  void setView(DoctorAgendaView view) {
    if (_view == view) return;
    _view = view;
    _notify();
  }

  void changeDay(int delta) =>
      selectDate(_selectedDate.add(Duration(days: delta)));

  void clearSessionState() {
    _sessionGeneration++;
    _rangeGeneration++;
    _records = const [];
    _proposalAvailability = null;
    _failure = null;
    _commandKeys.clear();
    _loading = false;
    _loadingDetail = false;
    _loadingAvailability = false;
    _submitting = false;
    _notify();
  }

  void _upsert(DoctorScheduledCareItem item) {
    final values =
        _records
            .where(
              (existing) =>
                  existing.resourceType != item.resourceType ||
                  existing.resourceId != item.resourceId,
            )
            .toList()
          ..add(item)
          ..sort((a, b) => a.sortAt.compareTo(b.sortAt));
    _records = List.unmodifiable(values);
    _notify();
  }

  void _removeIdentity(DoctorScheduledCareItem item) {
    _records = List.unmodifiable(
      _records.where(
        (existing) =>
            existing.resourceType != item.resourceType ||
            existing.resourceId != item.resourceId,
      ),
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

bool _isIdempotencyConflict(ScheduledCareFailure failure) {
  final code = failure.errorCode ?? '';
  return code.contains('IDEMPOTENCY') && code.contains('CONFLICT');
}
