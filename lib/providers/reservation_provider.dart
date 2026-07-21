import 'package:flutter/foundation.dart';

import '../repositories/reservation_repository.dart';

class ReservationProvider extends ChangeNotifier {
  final ReservationRepository _repository;

  ReservationProvider({ReservationRepository? repository})
    : _repository = repository ?? ReservationRepository()..useMock();

  bool _loading = false;
  String? _error;

  List<Map<String, dynamic>> _requests = const [];
  Map<String, dynamic>? _lastCreated;

  bool get isLoading => _loading;
  String? get error => _error;
  List<Map<String, dynamic>> get requests => _requests;
  Map<String, dynamic>? get lastCreated => _lastCreated;

  Future<void> refresh({String? status}) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _requests = await _repository.listReservationRequests(status: status);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> submitRequest({
    required String providerId,
    String? visitType,
    bool isEmergency = false,
    required DateTime searchStartDate,
    required DateTime searchEndDate,
    String? reason,
    required List<Map<String, dynamic>> intents,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final created = await _repository.createReservationRequest(
        providerId: providerId,
        visitType: visitType,
        isEmergency: isEmergency,
        searchStartDate: searchStartDate,
        searchEndDate: searchEndDate,
        reason: reason,
        intents: intents,
      );
      _lastCreated = created;
      await refresh();
      return created;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
