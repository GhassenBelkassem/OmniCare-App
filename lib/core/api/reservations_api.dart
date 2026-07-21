import '../../mock_data/mock_reservations.dart';

class ReservationApiException implements Exception {
  final String code;
  final String message;

  ReservationApiException(this.code, this.message);

  @override
  String toString() => message;
}

class ReservationsApi {
  ReservationsApi({Object? dio});

  Future<Map<String, dynamic>> createReservationRequest({
    required String providerId,
    String? visitType,
    bool isEmergency = false,
    required DateTime searchStartDate,
    required DateTime searchEndDate,
    String? reason,
    required List<Map<String, dynamic>> intents,
  }) async {
    return createMockCreatedReservation();
  }

  Future<List<Map<String, dynamic>>> listReservationRequests({
    String? status,
  }) async {
    return createMockReservationRequests();
  }

  Future<Map<String, dynamic>> proposeSlots({
    required String requestId,
    required List<DateTime> slots,
  }) async {
    return {'status': 'ok'};
  }
}
