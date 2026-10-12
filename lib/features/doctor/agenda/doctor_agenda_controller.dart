import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../scheduled_care/data/scheduled_care_failure.dart';
import '../../scheduled_care/domain/patient_scheduled_care_models.dart';
import '../../scheduled_care/domain/scheduled_care_models.dart';
import '../scheduled_care/data/doctor_scheduled_care_repository.dart';
import '../scheduled_care/domain/doctor_scheduled_care_models.dart';

enum DoctorAgendaView { month, day }

enum DoctorAgendaLoadState { initial, loading, ready, failed }

class DoctorAgendaController extends ChangeNotifier {
  DoctorAgendaController({
    required DoctorScheduledCareRepositoryContract repository,
    DateTime? now,
    VoidCallback? onForbidden,
  }) : _repository = repository,
       _onForbidden = onForbidden {
    final today = doctorAgendaWallClock(
      now ?? DateTime.now(),
      timezone: 'Africa/Tunis',
    );
    _selectedDate = DateUtils.dateOnly(today);
    _focusedDate = DateUtils.dateOnly(today);
  }

  DoctorAgendaController.preview({
    List<PatientScheduledCareItem> items = const [],
    DateTime? now,
  }) : _repository = null,
       _onForbidden = null,
       _items = List.unmodifiable(items),
       _state = DoctorAgendaLoadState.ready {
    final today = doctorAgendaWallClock(
      now ?? DateTime.now(),
      timezone: 'Africa/Tunis',
    );
    _selectedDate = DateUtils.dateOnly(today);
    _focusedDate = DateUtils.dateOnly(today);
  }

  final DoctorScheduledCareRepositoryContract? _repository;
  final VoidCallback? _onForbidden;
  late DateTime _selectedDate;
  late DateTime _focusedDate;
  DoctorAgendaView _view = DoctorAgendaView.month;
  List<PatientScheduledCareItem> _items = const [];
  DoctorAgendaRange? _visibleRange;
  DoctorAgendaLoadState _state = DoctorAgendaLoadState.initial;
  ScheduledCareFailure? _failure;
  CancelToken? _token;
  int _generation = 0;
  bool _disposed = false;
  bool _realtimeActive = false;

  DateTime get selectedDate => _selectedDate;
  DateTime get focusedDate => _focusedDate;
  DoctorAgendaView get view => _view;
  List<PatientScheduledCareItem> get items => _items;
  DoctorAgendaRange? get visibleRange => _visibleRange;
  DoctorAgendaLoadState get state => _state;
  ScheduledCareFailure? get failure => _failure;
  bool get isRefreshing => _state == DoctorAgendaLoadState.loading;
  bool get hasLoaded => _state != DoctorAgendaLoadState.initial;
  bool get realtimeActive => _realtimeActive;

  void setRealtimeActive(bool value) {
    if (!_disposed) _realtimeActive = value;
  }

  List<PatientScheduledCareItem> itemsFor(DateTime date) => _items
      .where(
        (item) => DateUtils.isSameDay(
          doctorAgendaWallClock(item.start, timezone: item.timezone),
          date,
        ),
      )
      .toList(growable: false);

  Future<void> load() => loadVisibleMonth(_focusedDate);

  Future<void> refresh() => loadVisibleMonth(_focusedDate);

  Future<void> loadVisibleMonth(DateTime month) async {
    final repository = _repository;
    if (_disposed) return;
    if (repository == null) {
      _state = DoctorAgendaLoadState.ready;
      _notify();
      return;
    }
    final normalizedMonth = DateTime(month.year, month.month);
    final range = doctorAgendaRangeForMonth(normalizedMonth);
    final generation = ++_generation;
    _token?.cancel('doctor-agenda-range-replaced');
    final token = _token = CancelToken();
    _visibleRange = range;
    _state = DoctorAgendaLoadState.loading;
    _failure = null;
    _notify();
    try {
      final snapshot = await repository.getAgenda(range, cancelToken: token);
      if (!_isCurrent(generation, token)) return;
      if (snapshot.from.toUtc() != range.from.toUtc() ||
          snapshot.to.toUtc() != range.to.toUtc()) {
        throw const ScheduledCareContractException(
          'Doctor Agenda response range mismatch.',
        );
      }
      _items = List.unmodifiable(snapshot.items);
      _state = DoctorAgendaLoadState.ready;
    } catch (error) {
      if (!_isCurrent(generation, token)) return;
      _failure = ScheduledCareFailure.from(error);
      _state = DoctorAgendaLoadState.failed;
      if (_failure?.kind == ScheduledCareFailureKind.forbidden) {
        _onForbidden?.call();
      }
    }
    if (_isCurrent(generation, token)) _notify();
  }

  void selectDate(DateTime date, {DateTime? focusedDate}) {
    if (_disposed) return;
    final previousMonth = DateTime(_focusedDate.year, _focusedDate.month);
    _selectedDate = DateUtils.dateOnly(date);
    _focusedDate = DateUtils.dateOnly(focusedDate ?? date);
    _notify();
    final nextMonth = DateTime(_focusedDate.year, _focusedDate.month);
    if (nextMonth != previousMonth) unawaited(loadVisibleMonth(nextMonth));
  }

  void focusMonth(DateTime date) {
    if (_disposed) return;
    final next = DateTime(date.year, date.month);
    final current = DateTime(_focusedDate.year, _focusedDate.month);
    if (next == current) return;
    _focusedDate = next;
    _selectedDate = next;
    _notify();
    unawaited(loadVisibleMonth(next));
  }

  void setView(DoctorAgendaView view) {
    if (_disposed || _view == view) return;
    _view = view;
    _notify();
  }

  void changeDay(int delta) =>
      selectDate(_selectedDate.add(Duration(days: delta)));

  void clear() {
    if (_disposed) return;
    _token?.cancel('doctor-agenda-session-cleared');
    _generation++;
    _items = const [];
    _visibleRange = null;
    _failure = null;
    _state = DoctorAgendaLoadState.initial;
    _realtimeActive = false;
    _notify();
  }

  bool _isCurrent(int generation, CancelToken token) =>
      !_disposed &&
      !token.isCancelled &&
      generation == _generation &&
      identical(token, _token);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _token?.cancel('doctor-agenda-controller-disposed');
    super.dispose();
  }
}

DoctorAgendaRange doctorAgendaRangeForMonth(DateTime displayedMonth) {
  final from = DateTime.utc(
    displayedMonth.year,
    displayedMonth.month,
  ).subtract(const Duration(hours: 1));
  final to = DateTime.utc(
    displayedMonth.year,
    displayedMonth.month + 1,
  ).subtract(const Duration(hours: 1));
  return DoctorAgendaRange(from: from, to: to);
}

DateTime doctorAgendaWallClock(DateTime instant, {required String timezone}) =>
    timezone == 'Africa/Tunis'
    ? instant.toUtc().add(const Duration(hours: 1))
    : instant.toUtc();
