import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/utils/uuid_v4.dart';
import 'availability_request_range.dart';
import '../data/scheduled_care_failure.dart';
import '../data/scheduled_care_repository.dart';
import '../domain/scheduled_care_models.dart';
import '../realtime/scheduled_care_realtime.dart';

class ScheduledBookingDraft {
  const ScheduledBookingDraft({
    this.subject,
    this.doctorId,
    this.doctorName,
    this.doctorSpecialty,
    this.consultationPriceTnd,
    this.cabinet,
    this.slot,
  });

  final CareSubject? subject;
  final String? doctorId;
  final String? doctorName;
  final String? doctorSpecialty;
  final double? consultationPriceTnd;
  final ScheduledCareCabinet? cabinet;
  final ScheduledCareSlot? slot;

  bool get canReview =>
      subject != null && doctorId != null && cabinet != null && slot != null;

  ScheduledBookingDraft copyWith({
    CareSubject? subject,
    String? doctorId,
    String? doctorName,
    String? doctorSpecialty,
    double? consultationPriceTnd,
    ScheduledCareCabinet? cabinet,
    ScheduledCareSlot? slot,
    bool clearProvider = false,
    bool clearSlot = false,
  }) => ScheduledBookingDraft(
    subject: subject ?? this.subject,
    doctorId: clearProvider ? null : doctorId ?? this.doctorId,
    doctorName: clearProvider ? null : doctorName ?? this.doctorName,
    doctorSpecialty: clearProvider
        ? null
        : doctorSpecialty ?? this.doctorSpecialty,
    consultationPriceTnd: clearProvider
        ? null
        : consultationPriceTnd ?? this.consultationPriceTnd,
    cabinet: clearProvider ? null : cabinet ?? this.cabinet,
    slot: clearProvider || clearSlot ? null : slot ?? this.slot,
  );
}

class ScheduledCareListCriteria {
  const ScheduledCareListCriteria({
    this.bucket = ScheduledCareBucket.upcoming,
    this.query,
    this.from,
    this.to,
    this.subjectType,
    this.familyMemberId,
    this.city,
  });
  final ScheduledCareBucket bucket;
  final String? query;
  final DateTime? from;
  final DateTime? to;
  final CareSubjectType? subjectType;
  final String? familyMemberId;
  final String? city;
}

class ScheduledCareController extends ChangeNotifier
    with WidgetsBindingObserver {
  ScheduledCareController({
    required ScheduledCareRepository repository,
    ScheduledCareRealtime realtime = const NoopScheduledCareRealtime(),
    String Function()? uuidFactory,
    DateTime Function()? clock,
  }) : _repository = repository,
       _realtime = realtime,
       _uuidFactory = uuidFactory ?? generateUuidV4,
       _clock = clock ?? DateTime.now {
    WidgetsBinding.instance.addObserver(this);
  }

  final ScheduledCareRepository _repository;
  final ScheduledCareRealtime _realtime;
  final String Function() _uuidFactory;
  final DateTime Function() _clock;

  ScheduledBookingDraft _draft = const ScheduledBookingDraft();
  AvailabilityWindow? _availability;
  PatientBookingRequest? _request;
  ConfirmedScheduledAppointment? _appointment;
  List<ScheduledCareListItem> _items = const [];
  ScheduledCareListCriteria _criteria = const ScheduledCareListCriteria();
  String? _nextCursor;
  String? _pendingCreateId;
  final Map<String, String> _commandKeys = {};
  final Set<String> _seenEventIds = <String>{};
  final List<String> _eventOrder = <String>[];
  ScheduledCareFailure? _failure;
  bool _loadingAvailability = false;
  bool _submitting = false;
  bool _loadingList = false;
  bool _loadingMore = false;
  bool _disposed = false;
  bool _sessionEnabled = false;
  int _listGeneration = 0;
  int _availabilityGeneration = 0;

  ScheduledBookingDraft get draft => _draft;
  AvailabilityWindow? get availability => _availability;
  PatientBookingRequest? get request => _request;
  ConfirmedScheduledAppointment? get appointment => _appointment;
  List<ScheduledCareListItem> get items => _items;
  ScheduledCareListCriteria get criteria => _criteria;
  String? get nextCursor => _nextCursor;
  ScheduledCareFailure? get failure => _failure;
  bool get isLoadingAvailability => _loadingAvailability;
  bool get isSubmitting => _submitting;
  bool get isLoadingList => _loadingList;
  bool get isLoadingMore => _loadingMore;
  bool get canLoadMore => _nextCursor != null && !_loadingMore;
  DateTime get currentTime => _clock();

  void selectSelf({required String displayName}) {
    _draft = ScheduledBookingDraft(
      subject: CareSubject(
        type: CareSubjectType.self,
        displayName: displayName.trim().isEmpty ? 'Moi' : displayName.trim(),
        relationship: 'Moi-même',
      ),
    );
    _resetCreateIdentity();
    _notify();
  }

  void selectFamilyMember({
    required String familyMemberId,
    required String displayName,
    required String relationshipLabel,
  }) {
    _draft = ScheduledBookingDraft(
      subject: CareSubject(
        type: CareSubjectType.familyMember,
        familyMemberId: familyMemberId,
        displayName: displayName,
        relationship: relationshipLabel,
      ),
    );
    _resetCreateIdentity();
    _notify();
  }

  void selectDoctorAndCabinet({
    required String doctorId,
    required String doctorName,
    required String doctorSpecialty,
    double? consultationPriceTnd,
    required ScheduledCareCabinet cabinet,
  }) {
    _draft = _draft.copyWith(
      doctorId: doctorId,
      doctorName: doctorName,
      doctorSpecialty: doctorSpecialty,
      consultationPriceTnd: consultationPriceTnd,
      cabinet: cabinet,
      clearSlot: true,
    );
    _availability = null;
    _resetCreateIdentity();
    _notify();
  }

  void selectSlot(ScheduledCareSlot slot) {
    final exact = _availability?.slots.any(
      (candidate) =>
          candidate.start.isAtSameMomentAs(slot.start) &&
          candidate.end.isAtSameMomentAs(slot.end),
    );
    if (exact != true) return;
    _draft = _draft.copyWith(slot: slot);
    _resetCreateIdentity();
    _notify();
  }

  Future<void> loadAvailability({DateTime? month}) async {
    final doctorId = _draft.doctorId;
    final locationId = _draft.cabinet?.practiceLocationId;
    if (doctorId == null || locationId == null) return;
    final generation = ++_availabilityGeneration;
    final now = _clock();
    final schedulingNow = displayInTimeZone(now, scheduledCareTimezone);
    final displayedMonth = month ?? schedulingNow;
    final range = AvailabilityRequestRange.forMonth(
      month: displayedMonth,
      now: now,
    );
    _loadingAvailability = true;
    _failure = null;
    _notify();
    try {
      final result = await _repository.getAvailability(
        doctorId: doctorId,
        practiceLocationId: locationId,
        from: range.from,
        to: range.to,
      );
      if (generation != _availabilityGeneration) return;
      if (_draft.doctorId != result.doctorId ||
          _draft.cabinet?.practiceLocationId != result.practiceLocationId) {
        return;
      }
      _availability = result;
      final selected = _draft.slot;
      if (selected != null &&
          !result.slots.any(
            (candidate) =>
                candidate.start.isAtSameMomentAs(selected.start) &&
                candidate.end.isAtSameMomentAs(selected.end),
          )) {
        _draft = _draft.copyWith(clearSlot: true);
        _resetCreateIdentity();
      }
    } on ScheduledCareFailure catch (failure) {
      if (generation != _availabilityGeneration) return;
      _failure = failure;
    } finally {
      if (generation == _availabilityGeneration) {
        _loadingAvailability = false;
        _notify();
      }
    }
  }

  Future<PatientBookingRequest?> submitDraft() async {
    if (!_draft.canReview || _submitting) return null;
    final id = _pendingCreateId ??= _uuidFactory();
    _submitting = true;
    _failure = null;
    _notify();
    try {
      final result = await _repository.createRequest(
        requestId: id,
        doctorId: _draft.doctorId!,
        practiceLocationId: _draft.cabinet!.practiceLocationId,
        subject: _draft.subject!,
        slot: _draft.slot!,
      );
      _request = result;
      _pendingCreateId = null;
      _draft = const ScheduledBookingDraft();
      return result;
    } on ScheduledCareFailure catch (failure) {
      if (failure.unknownOutcome) {
        final reconciled = await _reconcileCreatedRequest(id);
        if (reconciled != null) return reconciled;
      }
      _failure = failure;
      if (failure.errorCode == 'SLOT_NO_LONGER_AVAILABLE' ||
          failure.errorCode == 'SLOT_NOT_AVAILABLE') {
        _draft = _draft.copyWith(clearSlot: true);
        await loadAvailability();
        _failure = failure;
      }
      return null;
    } finally {
      _submitting = false;
      _notify();
    }
  }

  Future<PatientBookingRequest?> _reconcileCreatedRequest(String id) async {
    try {
      final result = await _repository.getRequest(id);
      _request = result;
      _pendingCreateId = null;
      _draft = const ScheduledBookingDraft();
      _failure = null;
      return result;
    } on ScheduledCareFailure {
      return null;
    }
  }

  Future<void> loadRequest(String requestId) async {
    _failure = null;
    _notify();
    try {
      _request = await _repository.getRequest(requestId);
    } on ScheduledCareFailure catch (failure) {
      _failure = failure;
    }
    _notify();
  }

  Future<void> loadAppointment(String appointmentId) async {
    _failure = null;
    _notify();
    try {
      _appointment = await _repository.getAppointment(appointmentId);
    } on ScheduledCareFailure catch (failure) {
      _failure = failure;
    }
    _notify();
  }

  Future<bool> cancelRequest({String reasonCode = 'CHANGE_OF_PLANS'}) async {
    final value = _request;
    if (value == null || !value.can('CANCEL_REQUEST')) return false;
    return _requestCommand(
      identity: 'cancel-request:${value.requestId}:${value.version}',
      operation: (key) => _repository.cancelRequest(
        requestId: value.requestId,
        expectedVersion: value.version,
        reasonCode: reasonCode,
        idempotencyKey: key,
      ),
    );
  }

  Future<bool> acceptProposal() async {
    final value = _request;
    final proposal = value?.proposedSlot;
    if (value == null ||
        proposal == null ||
        !value.can('ACCEPT_PROPOSED_TIME')) {
      return false;
    }
    final identity =
        'accept-proposal:${value.requestId}:${proposal.proposalId}:${value.version}';
    final key = _commandKeys.putIfAbsent(identity, _uuidFactory);
    _submitting = true;
    _failure = null;
    _notify();
    try {
      final result = await _repository.acceptProposal(
        requestId: value.requestId,
        proposalId: proposal.proposalId,
        expectedVersion: value.version,
        idempotencyKey: key,
      );
      _request = result.request;
      _appointment = result.appointment;
      _commandKeys.remove(identity);
      return true;
    } on ScheduledCareFailure catch (failure) {
      await _handleCommandFailure(failure, value.requestId, null);
      if (!failure.unknownOutcome &&
          failure.errorCode != 'IDEMPOTENCY_CONFLICT') {
        _commandKeys.remove(identity);
      }
      return false;
    } finally {
      _submitting = false;
      _notify();
    }
  }

  Future<bool> declineProposal({
    String reasonCode = 'PROPOSAL_DECLINED',
  }) async {
    final value = _request;
    final proposal = value?.proposedSlot;
    if (value == null ||
        proposal == null ||
        !value.can('DECLINE_PROPOSED_TIME')) {
      return false;
    }
    return _requestCommand(
      identity:
          'decline-proposal:${value.requestId}:${proposal.proposalId}:${value.version}',
      operation: (key) => _repository.declineProposal(
        requestId: value.requestId,
        proposalId: proposal.proposalId,
        expectedVersion: value.version,
        reasonCode: reasonCode,
        idempotencyKey: key,
      ),
    );
  }

  Future<bool> _requestCommand({
    required String identity,
    required Future<PatientBookingRequest> Function(String key) operation,
  }) async {
    final id = _request?.requestId;
    if (id == null || _submitting) return false;
    final key = _commandKeys.putIfAbsent(identity, _uuidFactory);
    _submitting = true;
    _failure = null;
    _notify();
    try {
      _request = await operation(key);
      _commandKeys.remove(identity);
      return true;
    } on ScheduledCareFailure catch (failure) {
      await _handleCommandFailure(failure, id, null);
      if (!failure.unknownOutcome &&
          failure.errorCode != 'IDEMPOTENCY_CONFLICT') {
        _commandKeys.remove(identity);
      }
      return false;
    } finally {
      _submitting = false;
      _notify();
    }
  }

  Future<bool> cancelAppointment({
    String reasonCode = 'CHANGE_OF_PLANS',
  }) async {
    final value = _appointment;
    if (value == null || !value.can('CANCEL_APPOINTMENT') || _submitting) {
      return false;
    }
    final identity =
        'cancel-appointment:${value.appointmentId}:${value.version}';
    final key = _commandKeys.putIfAbsent(identity, _uuidFactory);
    _submitting = true;
    _failure = null;
    _notify();
    try {
      _appointment = await _repository.cancelAppointment(
        appointmentId: value.appointmentId,
        expectedVersion: value.version,
        reasonCode: reasonCode,
        idempotencyKey: key,
      );
      _commandKeys.remove(identity);
      return true;
    } on ScheduledCareFailure catch (failure) {
      await _handleCommandFailure(failure, null, value.appointmentId);
      if (!failure.unknownOutcome &&
          failure.errorCode != 'IDEMPOTENCY_CONFLICT') {
        _commandKeys.remove(identity);
      }
      return false;
    } finally {
      _submitting = false;
      _notify();
    }
  }

  Future<void> _handleCommandFailure(
    ScheduledCareFailure failure,
    String? requestId,
    String? appointmentId,
  ) async {
    _failure = failure;
    if (failure.unknownOutcome ||
        failure.versionConflict ||
        (failure.statusCode == 409 &&
            failure.errorCode != 'IDEMPOTENCY_CONFLICT')) {
      if (requestId != null) await loadRequest(requestId);
      if (appointmentId != null) await loadAppointment(appointmentId);
    }
  }

  Future<void> loadList(
    ScheduledCareListCriteria criteria, {
    bool append = false,
  }) async {
    if (append && !canLoadMore) return;
    final generation = append ? _listGeneration : ++_listGeneration;
    _criteria = criteria;
    if (append) {
      _loadingMore = true;
    } else {
      _loadingList = true;
      _nextCursor = null;
    }
    _failure = null;
    _notify();
    try {
      final page = await _repository.list(
        bucket: criteria.bucket,
        cursor: append ? _nextCursor : null,
        query: criteria.query,
        from: criteria.from,
        to: criteria.to,
        subjectType: criteria.subjectType,
        familyMemberId: criteria.familyMemberId,
        city: criteria.city,
      );
      if (generation != _listGeneration) return;
      _items = append
          ? List.unmodifiable([..._items, ...page.items])
          : page.items;
      _nextCursor = page.nextCursor;
    } on ScheduledCareFailure catch (failure) {
      if (generation != _listGeneration) return;
      _failure = failure;
    } finally {
      if (generation == _listGeneration) {
        _loadingList = false;
        _loadingMore = false;
        _notify();
      }
    }
  }

  Future<void> resync() async {
    final futures = <Future<void>>[loadList(_criteria)];
    final requestId = _request?.requestId;
    final appointmentId = _appointment?.appointmentId;
    if (requestId != null) futures.add(loadRequest(requestId));
    if (appointmentId != null) futures.add(loadAppointment(appointmentId));
    await Future.wait(futures);
  }

  Future<void> connectRealtime() {
    _sessionEnabled = true;
    return _realtime.connect(
      _handleEvent,
      onConnected: () => unawaited(resync()),
    );
  }

  void disconnectRealtime() {
    _sessionEnabled = false;
    _realtime.disconnect();
  }

  void clearSessionState() {
    disconnectRealtime();
    _listGeneration++;
    _availabilityGeneration++;
    _draft = const ScheduledBookingDraft();
    _availability = null;
    _request = null;
    _appointment = null;
    _items = const [];
    _criteria = const ScheduledCareListCriteria();
    _nextCursor = null;
    _pendingCreateId = null;
    _commandKeys.clear();
    _seenEventIds.clear();
    _eventOrder.clear();
    _failure = null;
    _loadingAvailability = false;
    _submitting = false;
    _loadingList = false;
    _loadingMore = false;
    _notify();
  }

  void _handleEvent(ScheduledCareEvent event) {
    if (!_seenEventIds.add(event.eventId)) return;
    _eventOrder.add(event.eventId);
    if (_eventOrder.length > 128) {
      _seenEventIds.remove(_eventOrder.removeAt(0));
    }
    // A realtime event is only an invalidation hint. The following REST reads
    // remain the sole source of state shown to the patient.
    unawaited(loadList(_criteria));
    if (event.resourceType == ScheduledCareResourceType.bookingRequest &&
        _request?.requestId == event.resourceId &&
        event.version > _request!.version) {
      unawaited(loadRequest(event.resourceId));
    }
    if (event.resourceType == ScheduledCareResourceType.appointment &&
        _appointment?.appointmentId == event.resourceId &&
        event.version > _appointment!.version) {
      unawaited(loadAppointment(event.resourceId));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_sessionEnabled) return;
      unawaited(connectRealtime());
      unawaited(resync());
    }
  }

  void clearDraft() {
    _draft = const ScheduledBookingDraft();
    _availability = null;
    _resetCreateIdentity();
    _notify();
  }

  void _resetCreateIdentity() => _pendingCreateId = null;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _realtime.disconnect();
    super.dispose();
  }
}
