import '../core/api/reservations_api.dart';
import '../mock_data/mock_reservations.dart';

class ReservationRepository {
  ReservationsApi? _api;

  ReservationRepository({ReservationsApi? api}) : _api = api;

  void useMock() {
    _api = null;
  }

  void useApi(ReservationsApi api) {
    _api = api;
  }

  bool get isMock => _api == null;

  Future<Map<String, dynamic>> createReservationRequest({
    required String providerId,
    String? visitType,
    bool isEmergency = false,
    required DateTime searchStartDate,
    required DateTime searchEndDate,
    String? reason,
    required List<Map<String, dynamic>> intents,
  }) async {
    if (_api == null) return createMockCreatedReservation();
    return _api!.createReservationRequest(
      providerId: providerId,
      visitType: visitType,
      isEmergency: isEmergency,
      searchStartDate: searchStartDate,
      searchEndDate: searchEndDate,
      reason: reason,
      intents: intents,
    );
  }

  Future<List<Map<String, dynamic>>> listReservationRequests({
    String? status,
  }) async {
    if (_api == null) return createMockReservationRequests();
    return _api!.listReservationRequests(status: status);
  }

  Future<Map<String, dynamic>> proposeSlots({
    required String requestId,
    required List<DateTime> slots,
  }) async {
    if (_api == null) return {'status': 'ok'};
    return _api!.proposeSlots(requestId: requestId, slots: slots);
  }
}
