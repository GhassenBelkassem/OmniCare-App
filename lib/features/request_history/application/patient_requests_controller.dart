import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../request_core/data/request_failure.dart';
import '../../request_core/data/request_models.dart';
import '../../request_core/data/request_repository.dart';
import '../../request_core/domain/request_vocabulary.dart';
import '../../request_core/identity/request_operation_id.dart';

enum PatientRequestsStatus { idle, loading, populated, empty, error }

/// Owns bounded request history and one authoritative request detail.
class PatientRequestsController extends ChangeNotifier {
  PatientRequestsController({
    required PatientRequestGateway repository,
    int pageSize = 20,
  }) : _repository = repository,
       pageSize = pageSize < 1 ? 1 : (pageSize > 50 ? 50 : pageSize);

  final PatientRequestGateway _repository;
  final int pageSize;
  List<PatientRequestListItem> _items = const [];
  int _page = 0;
  bool _hasNext = false;
  bool _loading = false;
  bool _loadingMore = false;
  RequestFailure? _listFailure;
  PatientRequest? _detail;
  RequestFailure? _detailFailure;
  bool _loadingDetail = false;
  bool _cancelling = false;
  bool _submittingInformation = false;
  String? _cancellationNotice;
  int _listGeneration = 0;
  int _detailGeneration = 0;
  CancelToken? _listToken;
  CancelToken? _detailToken;
  bool _disposed = false;
  PatientRequestListFilter _filter = PatientRequestListFilter.all;

  List<PatientRequestListItem> get items => _items;
  PatientRequestListFilter get filter => _filter;
  bool get hasNext => _hasNext;
  bool get isLoadingMore => _loadingMore;
  RequestFailure? get listFailure => _listFailure;
  PatientRequest? get detail => _detail;
  RequestFailure? get detailFailure => _detailFailure;
  bool get isLoadingDetail => _loadingDetail;
  bool get isCancelling => _cancelling;
  bool get isSubmittingInformation => _submittingInformation;
  String? get cancellationNotice => _cancellationNotice;
  PatientRequestsStatus get status => _status;
  PatientRequestsStatus _status = PatientRequestsStatus.idle;

  Future<void> loadFirst({bool preserveItems = false}) async {
    final generation = ++_listGeneration;
    _listToken?.cancel('request-list-superseded');
    final token = _listToken = CancelToken();
    _loading = true;
    _status = _items.isEmpty ? PatientRequestsStatus.loading : PatientRequestsStatus.populated;
    _loadingMore = false;
    _listFailure = null;
    _notify();
    try {
      final page = await _repository.listRequests(
        page: 0,
        pageSize: pageSize,
        filter: _filter,
        cancelToken: token,
      );
      if (_staleList(token, generation)) return;
      _items = List.unmodifiable(page.items.map(_asListItem));
      _page = page.page;
      _hasNext = page.hasNext;
      _status = _items.isEmpty ? PatientRequestsStatus.empty : PatientRequestsStatus.populated;
    } on RequestFailure catch (failure) {
      if (_staleList(token, generation)) return;
      _listFailure = failure;
      if (!preserveItems) {
        _items = const [];
        _status = PatientRequestsStatus.error;
      }
    } finally {
      if (!_staleList(token, generation)) {
        _loading = false;
        _notify();
      }
    }
  }

  Future<void> selectFilter(PatientRequestListFilter filter) async {
    if (_filter == filter) return;
    _filter = filter;
    await loadFirst();
  }

  Future<void> loadMore() async {
    if (_loading || _loadingMore || !_hasNext || _disposed) return;
    final generation = ++_listGeneration;
    _listToken?.cancel('request-list-superseded');
    final token = _listToken = CancelToken();
    _loadingMore = true;
    _notify();
    try {
      final page = await _repository.listRequests(
        page: _page + 1,
        pageSize: pageSize,
        filter: _filter,
        cancelToken: token,
      );
      if (_staleList(token, generation)) return;
      final known = _items.map((item) => item.requestId.value).toSet();
      _items = List.unmodifiable([
        ..._items,
        ...page.items.map(_asListItem).where((item) => known.add(item.requestId.value)),
      ]);
      _page = page.page;
      _hasNext = page.hasNext;
      _status = PatientRequestsStatus.populated;
    } on RequestFailure catch (failure) {
      if (!_staleList(token, generation)) _listFailure = failure;
    } finally {
      if (!_staleList(token, generation)) {
        _loadingMore = false;
        _notify();
      }
    }
  }

  Future<void> loadDetail(RequestOperationId requestId) async {
    final generation = ++_detailGeneration;
    _detailToken?.cancel('request-detail-superseded');
    final token = _detailToken = CancelToken();
    _loadingDetail = true;
    _detailFailure = null;
    _detail = null;
    _notify();
    try {
      final request = await _repository.getRequest(
        requestId,
        cancelToken: token,
      );
      if (_staleDetail(token, generation)) return;
      _detail = request;
    } on RequestFailure catch (failure) {
      if (!_staleDetail(token, generation)) _detailFailure = failure;
    } finally {
      if (!_staleDetail(token, generation)) {
        _loadingDetail = false;
        _notify();
      }
    }
  }

  Future<void> cancelDetail() async {
    final current = _detail;
    if (current == null ||
        !current.availableActions.contains(PatientRequestAction.cancel) ||
        _cancelling) {
      return;
    }
    _cancelling = true;
    _detailFailure = null;
    _cancellationNotice = null;
    _notify();
    try {
      final updated = await _repository.cancelRequest(
        requestId: current.requestId,
        expectedVersion: current.version,
      );
      _detail = updated;
      await loadFirst(preserveItems: true);
    } on RequestFailure catch (failure) {
      _detailFailure = failure;
      if (failure.requiresRefresh) {
        _cancellationNotice =
            "This request was updated. We've refreshed the latest status.";
        await loadDetail(current.requestId);
      } else if (failure.retryable) {
        _cancellationNotice =
            'We could not confirm the cancellation. Refresh to check the latest status.';
      }
    } finally {
      if (!_disposed) {
        _cancelling = false;
        _notify();
      }
    }
  }

  Future<void> submitInformationResponse({
    PatientInformationResponsePayload? payload,
    bool confirmed = true,
    Set<OperationalWeekday> availabilityWeekdays = const {},
  }) async {
    final current = _detail;
    final informationRequest = current?.informationRequest;
    if (current == null ||
        informationRequest == null ||
        !current.canProvideInformation ||
        _submittingInformation) {
      return;
    }
    final resolvedPayload = payload ?? _legacyPayload(
      informationRequest,
      current.version,
      confirmed,
      availabilityWeekdays,
    );
    _submittingInformation = true;
    _detailFailure = null;
    _cancellationNotice = null;
    _notify();
    try {
      final updated = await _repository.respondToInformationRequest(
        requestId: current.requestId,
          payload: resolvedPayload,
      );
      _detail = updated;
      await loadFirst(preserveItems: true);
    } on RequestFailure catch (failure) {
      _detailFailure = failure;
      if (failure.requiresRefresh) {
        _cancellationNotice =
            "This request was updated. We've refreshed the latest status.";
        await loadDetail(current.requestId);
      }
    } finally {
      if (!_disposed) {
        _submittingInformation = false;
        _notify();
      }
    }
  }

  PatientInformationResponsePayload _legacyPayload(
    PatientInformationRequest request,
    int expectedVersion,
    bool confirmed,
    Set<OperationalWeekday> weekdays,
  ) {
    if (request.responseType == InformationResponseType.availabilityWindows || request.responseType == InformationResponseType.weekdayAvailability) {
      return AvailabilityInformationResponsePayload(informationRequestId: request.informationRequestId, expectedVersion: expectedVersion,
        availabilityWindows: weekdays.map((day) => AvailabilityWindow(dayOfWeek: day, startLocalTime: const AvailabilityLocalTime(9, 0), endLocalTime: const AvailabilityLocalTime(17, 0))).toList());
    }
    return ConfirmationInformationResponsePayload(informationRequestId: request.informationRequestId, expectedVersion: expectedVersion, confirmed: confirmed);
  }

  PatientRequestListItem _asListItem(Object value) {
    if (value is PatientRequestListItem) return value;
    if (value is PatientRequest) return PatientRequestListItem(requestId: value.requestId, clinicDisplayName: 'Clinic', subjectType: value.subjectType, subjectDisplayName: value.subjectType == RequestSubjectType.self ? 'Me' : 'Family member', relationship: null, situation: value.situation, patientStatus: value.patientStatus, submittedAt: value.submittedAt, requiresPatientAction: value.patientStatus == PatientRequestStatus.informationRequired || value.patientStatus == PatientRequestStatus.waitingForConfirmation, version: value.version);
    throw const RequestContractException('Request list entry is malformed.');
  }

  bool _staleList(CancelToken token, int generation) =>
      _disposed || token.isCancelled || generation != _listGeneration;
  bool _staleDetail(CancelToken token, int generation) =>
      _disposed || token.isCancelled || generation != _detailGeneration;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _listToken?.cancel('request-history-disposed');
    _detailToken?.cancel('request-history-disposed');
    super.dispose();
  }
}
