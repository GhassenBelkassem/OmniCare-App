import '../core/api/reservations_api.dart';
import '../core/network/api_failure.dart';

/// Legacy reservation requests (not reachable from `main.dart`; deleted in
/// Phase 1c). Without an API every call fails with
/// [ApiFailure.featureUnavailable]: there is no mock mode (G-2 1b-3).
class ReservationRepository {
  ReservationsApi? _api;

  ReservationRepository({ReservationsApi? api}) : _api = api;

  void useApi(ReservationsApi api) {
    _api = api;
  }

  Future<Map<String, dynamic>> createReservationRequest({
    required String providerId,
    String? visitType,
    bool isEmergency = false,
    required DateTime searchStartDate,
    required DateTime searchEndDate,
    String? reason,
    required List<Map<String, dynamic>> intents,
  }) async {
    if (_api == null) throw ApiFailure.featureUnavailable;
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
    if (_api == null) throw ApiFailure.featureUnavailable;
    return _api!.listReservationRequests(status: status);
  }

  Future<Map<String, dynamic>> proposeSlots({
    required String requestId,
    required List<DateTime> slots,
  }) async {
    if (_api == null) throw ApiFailure.featureUnavailable;
    return _api!.proposeSlots(requestId: requestId, slots: slots);
  }
}
