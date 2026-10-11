import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../scheduled_care/data/scheduled_care_failure.dart';
import '../../scheduled_care/domain/scheduled_care_models.dart';
import '../../scheduled_care/realtime/scheduled_care_realtime.dart';
import '../agenda/doctor_agenda_controller.dart';
import 'doctor_home_scheduled_care_controller.dart';
import 'doctor_scheduled_care_repository.dart';

class DoctorScheduledCareCoordinator with WidgetsBindingObserver {
  DoctorScheduledCareCoordinator({
    required DoctorScheduledCareRepository repository,
    required ScheduledCareRealtime realtime,
    required String doctorId,
    DateTime? initialDate,
  }) : _realtime = realtime,
       home = DoctorHomeScheduledCareController(repository: repository),
       agenda = DoctorAgendaController(
         repository: repository,
         doctorId: doctorId,
         initialDate: initialDate,
       ) {
    agenda.onMutation = home.load;
    WidgetsBinding.instance.addObserver(this);
  }

  final ScheduledCareRealtime _realtime;
  final DoctorHomeScheduledCareController home;
  final DoctorAgendaController agenda;
  final Set<String> _seenEventIds = <String>{};
  final List<String> _eventOrder = <String>[];
  bool _started = false;
  bool _disposed = false;
  bool _suspended = false;
  bool _resyncQueued = false;
  Future<void>? _resyncInFlight;

  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;
    _suspended = false;
    await resync();
    if (!_canRun) return;
    await _connectRealtime();
  }

  Future<void> _connectRealtime() async {
    if (!_canRun) return;
    try {
      await _realtime.connect(
        _handleEvent,
        onConnected: () => unawaited(resync()),
      );
    } on ScheduledCareFailure catch (failure) {
      if (failure.isSessionBoundary) _suspend();
    } catch (_) {
      // Realtime transport failures leave REST state intact and are retried on
      // the next foreground transition. They must not escape UI callbacks.
    }
  }

  Future<void> resync() {
    if (!_canRun) return Future<void>.value();
    final current = _resyncInFlight;
    if (current != null) {
      _resyncQueued = true;
      return current;
    }

    final started = _performResync();
    _resyncInFlight = started;
    return started.whenComplete(() {
      if (identical(_resyncInFlight, started)) _resyncInFlight = null;
      if (_resyncQueued && _canRun) {
        _resyncQueued = false;
        unawaited(resync());
      }
    });
  }

  Future<void> _performResync() async {
    try {
      await Future.wait([home.load(), agenda.resync()]);
    } on ScheduledCareFailure catch (failure) {
      if (failure.isSessionBoundary) _suspend();
      return;
    }
    if (home.failure?.isSessionBoundary == true ||
        agenda.failure?.isSessionBoundary == true) {
      _suspend();
    }
  }

  void _handleEvent(ScheduledCareEvent event) {
    if (!_canRun) return;
    if (!_seenEventIds.add(event.eventId)) return;
    _eventOrder.add(event.eventId);
    if (_eventOrder.length > 128) {
      _seenEventIds.remove(_eventOrder.removeAt(0));
    }
    // Realtime payloads only invalidate projections. REST remains the sole
    // authority for state shown to the doctor.
    unawaited(resync());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_canRun) return;
    unawaited(_connectRealtime());
    unawaited(resync());
  }

  void clearSessionState() {
    _started = false;
    _suspended = true;
    _resyncQueued = false;
    _realtime.disconnect();
    _seenEventIds.clear();
    _eventOrder.clear();
    home.clearSessionState();
    agenda.clearSessionState();
  }

  bool get _canRun => _started && !_disposed && !_suspended;

  void _suspend() {
    if (_suspended) return;
    clearSessionState();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _realtime.disconnect();
    home.dispose();
    agenda.dispose();
  }
}
