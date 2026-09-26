import 'package:dio/dio.dart';

import 'doctor_directory_api.dart';
import 'doctor_directory_failure.dart';
import 'doctor_directory_models.dart';

/// Outcome of a booking attempt, in UI-actionable terms.
enum DoctorBookingStatus { success, conflict, failure }

/// A booking result. Only one payload is ever set per instance.
class DoctorBookingResult {
  const DoctorBookingResult._({
    required this.status,
    this.booking,
    this.conflictMessage,
    this.failure,
  });

  factory DoctorBookingResult.success(AppointmentBooking booking) {
    return DoctorBookingResult._(
      status: DoctorBookingStatus.success,
      booking: booking,
    );
  }

  factory DoctorBookingResult.conflict(String message) {
    return DoctorBookingResult._(
      status: DoctorBookingStatus.conflict,
      conflictMessage: message,
    );
  }

  factory DoctorBookingResult.failure(DoctorDirectoryFailure failure) {
    return DoctorBookingResult._(
      status: DoctorBookingStatus.failure,
      failure: failure,
    );
  }

  final DoctorBookingStatus status;
  final AppointmentBooking? booking;
  final String? conflictMessage;
  final DoctorDirectoryFailure? failure;

  bool get succeeded => status == DoctorBookingStatus.success;
  bool get isConflict => status == DoctorBookingStatus.conflict;

  @override
  String toString() =>
      'DoctorBookingResult(${status.name}, booking=${booking != null})';
}

/// Repository boundary for the patient doctor directory.
///
/// Turns the transport layer into typed models and every failure into a
/// [DoctorDirectoryFailure] (or a [DoctorBookingResult] for the write path),
/// so no screen ever sees a `DioException` or a raw backend error.
class DoctorDirectoryRepository {
  const DoctorDirectoryRepository(this._api);

  final DoctorDirectoryApi _api;

  Future<List<DoctorDirectoryListItem>> listDoctors({
    String? query,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.listDoctors(query: query, cancelToken: cancelToken);
    } catch (error) {
      throw DoctorDirectoryFailure.from(error);
    }
  }

  Future<DoctorDirectoryDetail> getDoctor(
    String doctorId, {
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.getDoctor(doctorId, cancelToken: cancelToken);
    } catch (error) {
      throw DoctorDirectoryFailure.from(error);
    }
  }

  Future<List<AvailabilitySlotDto>> getSlots({
    required String doctorId,
    required DateTime from,
    required DateTime to,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.getSlots(
        doctorId: doctorId,
        from: from,
        to: to,
        cancelToken: cancelToken,
      );
    } catch (error) {
      throw DoctorDirectoryFailure.from(error);
    }
  }

  /// Books a slot. A 409 conflict (the slot was just taken) is a normal,
  /// recoverable outcome — the picker stays open so the patient can choose
  /// another slot. Everything else maps to a [DoctorDirectoryFailure].
  Future<DoctorBookingResult> bookAppointment({
    required String doctorId,
    required String startTime,
    required String endTime,
    String? notes,
    CancelToken? cancelToken,
  }) async {
    try {
      final booking = await _api.bookAppointment(
        doctorId: doctorId,
        startTime: startTime,
        endTime: endTime,
        notes: notes,
        cancelToken: cancelToken,
      );
      return DoctorBookingResult.success(booking);
    } catch (error) {
      if (error is DioException && error.response?.statusCode == 409) {
        return DoctorBookingResult.conflict(
          'Ce créneau vient d\'être réservé par un autre patient. '
          'Veuillez en choisir un autre.',
        );
      }
      return DoctorBookingResult.failure(DoctorDirectoryFailure.from(error));
    }
  }
}