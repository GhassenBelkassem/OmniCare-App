import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/realtime/authenticated_realtime_transport.dart';
import '../../doctor/agenda/doctor_agenda_controller.dart';
import '../../doctor/scheduled_care/application/doctor_appointment_controller.dart';
import '../../doctor/scheduled_care/application/doctor_booking_request_controller.dart';
import '../../doctor/scheduled_care/application/doctor_home_controller.dart';
import '../application/patient_booking_controller.dart';
import '../application/patient_scheduled_care_controller.dart';
import 'coalesced_refresh.dart';
import 'recent_event_deduper.dart';
import 'scheduled_care_event.dart';

abstract class ScheduledCareRealtimeTarget {
  String get role;
  void activate();
  void deactivate();
  Future<void> invalidate(ScheduledCareInvalidationEvent event);
  Future<void> resync();
  void dispose();
}

class ScheduledCareRefreshBinding {
  ScheduledCareRefreshBinding({
    required Listenable listenable,
    required bool Function() shouldRefresh,
    required bool Function() isBusy,
    required Future<void> Function() refresh,
  }) : _listenable = listenable,
       _shouldRefresh = shouldRefresh,
       _isBusy = isBusy,
       _refresh = refresh {
    _listenable.addListener(_onChanged);
  }

  final Listenable _listenable;
  final bool Function() _shouldRefresh;
  final bool Function() _isBusy;
  final Future<void> Function() _refresh;
  final CoalescedRefresh _coalescer = CoalescedRefresh();
  bool _active = false;
  bool _deferredUntilIdle = false;
  bool _disposed = false;

  void activate() => _active = true;

  void deactivate() {
    _active = false;
    _deferredUntilIdle = false;
    _coalescer.reset();
  }

  Future<void> invalidate() {
    if (_disposed || !_active || !_shouldRefresh()) {
      return Future<void>.value();
    }
    if (_isBusy()) {
      _deferredUntilIdle = true;
      return Future<void>.value();
    }
    return _coalescer.request(() async {
      if (!_disposed && _active && _shouldRefresh()) await _refresh();
    });
  }

  void _onChanged() {
    if (!_deferredUntilIdle || _isBusy()) return;
    _deferredUntilIdle = false;
    unawaited(invalidate());
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _listenable.removeListener(_onChanged);
    _coalescer.dispose();
  }
}

class PatientScheduledCareRealtimeTarget
    implements ScheduledCareRealtimeTarget {
  PatientScheduledCareRealtimeTarget({
    required PatientBookingController bookingController,
    required PatientScheduledCareController listController,
  }) : this.bindings(
         requestId: () => bookingController.realtimeRequestId,
         appointmentId: () => bookingController.realtimeAppointmentId,
         request: ScheduledCareRefreshBinding(
           listenable: bookingController,
           shouldRefresh: () => bookingController.realtimeRequestId != null,
           isBusy: () =>
               bookingController.isLifecycleBusy ||
               bookingController.isSubmitting,
           refresh: bookingController.refresh,
         ),
         appointment: ScheduledCareRefreshBinding(
           listenable: bookingController,
           shouldRefresh: () => bookingController.realtimeAppointmentId != null,
           isBusy: () => bookingController.isLifecycleBusy,
           refresh: () {
             final id = bookingController.realtimeAppointmentId;
             return id == null
                 ? Future<void>.value()
                 : bookingController.openAppointment(id);
           },
         ),
         list: ScheduledCareRefreshBinding(
           listenable: listController,
           shouldRefresh: () =>
               listController.realtimeActive && listController.hasLoaded,
           isBusy: () =>
               listController.isLoading || listController.isLoadingMore,
           refresh: listController.refresh,
         ),
       );

  PatientScheduledCareRealtimeTarget.bindings({
    required String? Function() requestId,
    required String? Function() appointmentId,
    required ScheduledCareRefreshBinding request,
    required ScheduledCareRefreshBinding appointment,
    required ScheduledCareRefreshBinding list,
  }) : _requestId = requestId,
       _appointmentId = appointmentId,
       _request = request,
       _appointment = appointment,
       _list = list;

  final String? Function() _requestId;
  final String? Function() _appointmentId;
  final ScheduledCareRefreshBinding _request;
  final ScheduledCareRefreshBinding _appointment;
  final ScheduledCareRefreshBinding _list;

  @override
  String get role => 'PATIENT';

  @override
  void activate() {
    _request.activate();
    _appointment.activate();
    _list.activate();
  }

  @override
  void deactivate() {
    _request.deactivate();
    _appointment.deactivate();
    _list.deactivate();
  }

  @override
  Future<void> invalidate(ScheduledCareInvalidationEvent event) async {
    if (event.resourceType == ScheduledCareResourceType.consultation) return;
    final operations = <Future<void>>[_list.invalidate()];
    switch (event.resourceType) {
      case ScheduledCareResourceType.bookingRequest:
        if (_requestId()?.toLowerCase() == event.resourceId) {
          operations.add(_request.invalidate());
        }
      case ScheduledCareResourceType.appointment:
        if (_appointmentId()?.toLowerCase() == event.resourceId) {
          operations.add(_appointment.invalidate());
        }
      case ScheduledCareResourceType.consultation:
        break;
    }
    await Future.wait(operations);
  }

  @override
  Future<void> resync() => Future.wait(<Future<void>>[
    _list.invalidate(),
    _request.invalidate(),
    _appointment.invalidate(),
  ]);

  @override
  void dispose() {
    _request.dispose();
    _appointment.dispose();
    _list.dispose();
  }
}

class DoctorScheduledCareRealtimeTarget implements ScheduledCareRealtimeTarget {
  DoctorScheduledCareRealtimeTarget({
    required DoctorHomeController homeController,
    required DoctorBookingRequestController bookingController,
    required DoctorAgendaController agendaController,
    required DoctorAppointmentController appointmentController,
  }) : this.bindings(
         requestId: () => bookingController.realtimeRequestId,
         appointmentId: () => appointmentController.realtimeAppointmentId,
         home: ScheduledCareRefreshBinding(
           listenable: homeController,
           shouldRefresh: () =>
               homeController.realtimeActive || homeController.hasLoaded,
           isBusy: () => homeController.isLoading,
           refresh: homeController.refresh,
         ),
         request: ScheduledCareRefreshBinding(
           listenable: bookingController,
           shouldRefresh: () => bookingController.realtimeRequestId != null,
           isBusy: () =>
               bookingController.state ==
                   DoctorBookingRequestLoadState.loading ||
               bookingController.isMutating,
           refresh: bookingController.refresh,
         ),
         agenda: ScheduledCareRefreshBinding(
           listenable: agendaController,
           shouldRefresh: () =>
               agendaController.realtimeActive && agendaController.hasLoaded,
           isBusy: () => agendaController.isRefreshing,
           refresh: agendaController.refresh,
         ),
         appointment: ScheduledCareRefreshBinding(
           listenable: appointmentController,
           shouldRefresh: () =>
               appointmentController.realtimeAppointmentId != null,
           isBusy: () =>
               appointmentController.state ==
                   DoctorAppointmentLoadState.loading ||
               appointmentController.isCancelling,
           refresh: appointmentController.refresh,
         ),
       );

  DoctorScheduledCareRealtimeTarget.bindings({
    required String? Function() requestId,
    required String? Function() appointmentId,
    required ScheduledCareRefreshBinding home,
    required ScheduledCareRefreshBinding request,
    required ScheduledCareRefreshBinding agenda,
    required ScheduledCareRefreshBinding appointment,
  }) : _requestId = requestId,
       _appointmentId = appointmentId,
       _home = home,
       _request = request,
       _agenda = agenda,
       _appointment = appointment;

  final String? Function() _requestId;
  final String? Function() _appointmentId;
  final ScheduledCareRefreshBinding _home;
  final ScheduledCareRefreshBinding _request;
  final ScheduledCareRefreshBinding _agenda;
  final ScheduledCareRefreshBinding _appointment;

  @override
  String get role => 'DOCTOR';

  @override
  void activate() {
    _home.activate();
    _request.activate();
    _agenda.activate();
    _appointment.activate();
  }

  @override
  void deactivate() {
    _home.deactivate();
    _request.deactivate();
    _agenda.deactivate();
    _appointment.deactivate();
  }

  @override
  Future<void> invalidate(ScheduledCareInvalidationEvent event) async {
    if (event.resourceType == ScheduledCareResourceType.consultation) return;
    final operations = <Future<void>>[_home.invalidate(), _agenda.invalidate()];
    switch (event.resourceType) {
      case ScheduledCareResourceType.bookingRequest:
        if (_requestId()?.toLowerCase() == event.resourceId) {
          operations.add(_request.invalidate());
        }
      case ScheduledCareResourceType.appointment:
        if (_appointmentId()?.toLowerCase() == event.resourceId) {
          operations.add(_appointment.invalidate());
        }
      case ScheduledCareResourceType.consultation:
        break;
    }
    await Future.wait(operations);
  }

  @override
  Future<void> resync() => Future.wait(<Future<void>>[
    _home.invalidate(),
    _request.invalidate(),
    _agenda.invalidate(),
    _appointment.invalidate(),
  ]);

  @override
  void dispose() {
    _home.dispose();
    _request.dispose();
    _agenda.dispose();
    _appointment.dispose();
  }
}

class ScheduledCareRealtimeCoordinator {
  ScheduledCareRealtimeCoordinator({
    required ScheduledCareRealtimeTransport transport,
    RecentEventDeduper? deduper,
  }) : _transport = transport,
       _deduper = deduper ?? RecentEventDeduper() {
    _messageSubscription = _transport.messages.listen(_onMessage);
    _epochSubscription = _transport.connectedEpochs.listen(_onConnectedEpoch);
  }

  final ScheduledCareRealtimeTransport _transport;
  final RecentEventDeduper _deduper;
  final Set<ScheduledCareRealtimeTarget> _targets =
      <ScheduledCareRealtimeTarget>{};
  late final StreamSubscription<String> _messageSubscription;
  late final StreamSubscription<int> _epochSubscription;
  RealtimeSessionOwner? _owner;
  int _sessionGeneration = 0;
  bool _disposed = false;

  RealtimeSessionOwner? get owner => _owner;

  VoidCallback registerTarget(ScheduledCareRealtimeTarget target) {
    if (_disposed) return () {};
    _targets.add(target);
    if (_matchesActiveRole(target)) target.activate();
    return () {
      if (_targets.remove(target)) target.deactivate();
    };
  }

  Future<void> startSession(RealtimeSessionOwner owner) async {
    if (_disposed) return;
    final isSameOwner = _owner == owner;
    if (!isSameOwner) {
      _sessionGeneration++;
      _deduper.clear();
      for (final target in _targets) {
        target.deactivate();
      }
      _owner = owner;
      for (final target in _targets) {
        if (_matchesActiveRole(target)) target.activate();
      }
    }
    await _transport.startSession(owner);
  }

  Future<void> foregroundResync() async {
    if (_disposed || _owner == null) return;
    final generation = _sessionGeneration;
    await _transport.ensureConnected();
    if (_disposed || generation != _sessionGeneration || _owner == null) return;
    await _resyncActiveTargets(generation);
  }

  /// Re-evaluates the stored credential without coupling token storage to
  /// STOMP. A changed token tears down the old socket; the resulting new
  /// connection epoch performs the normal bounded REST resync.
  Future<void> credentialsChanged() async {
    if (_disposed || _owner == null) return;
    await _transport.ensureConnected();
  }

  void _onMessage(String body) {
    final event = ScheduledCareInvalidationEvent.tryParse(body);
    if (event == null || !_deduper.accept(event.eventId)) return;
    final generation = _sessionGeneration;
    for (final target in List<ScheduledCareRealtimeTarget>.of(_targets)) {
      if (_matchesActiveRole(target) && generation == _sessionGeneration) {
        unawaited(target.invalidate(event));
      }
    }
  }

  void _onConnectedEpoch(int _) {
    if (_owner == null || _disposed) return;
    unawaited(_resyncActiveTargets(_sessionGeneration));
  }

  Future<void> _resyncActiveTargets(int generation) async {
    final active = _targets.where(_matchesActiveRole).toList(growable: false);
    for (final target in active) {
      if (_disposed || generation != _sessionGeneration) return;
      await target.resync();
    }
  }

  bool _matchesActiveRole(ScheduledCareRealtimeTarget target) =>
      _owner != null &&
      target.role.trim().toUpperCase() == _owner!.normalizedRole;

  Future<void> stopSession() async {
    _sessionGeneration++;
    _owner = null;
    _deduper.clear();
    for (final target in _targets) {
      target.deactivate();
    }
    await _transport.stopSession();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stopSession();
    await _messageSubscription.cancel();
    await _epochSubscription.cancel();
    for (final target in _targets) {
      target.dispose();
    }
    _targets.clear();
  }
}
