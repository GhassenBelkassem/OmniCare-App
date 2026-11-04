import 'package:dio/dio.dart';

import '../../../core/network/app_http_client.dart';
import 'doctor_home_commitment.dart';

abstract interface class DoctorHomeCommitmentRepositoryContract {
  Future<DoctorHomeActiveCommitment> findActive({CancelToken? cancelToken});

  Future<DoctorHomeCommitment> get(
    String commitmentId, {
    CancelToken? cancelToken,
  });
}

class DoctorHomeCommitmentRepository
    implements DoctorHomeCommitmentRepositoryContract {
  const DoctorHomeCommitmentRepository(this._httpClient);

  static const path = '/me/urgent-home/commitments';

  final AppHttpClient _httpClient;

  @override
  Future<DoctorHomeActiveCommitment> findActive({
    CancelToken? cancelToken,
  }) async {
    final response = await _httpClient.dio.get<dynamic>(
      '$path/active',
      cancelToken: cancelToken,
      options: Options(headers: const {'Cache-Control': 'no-store'}),
    );
    return parseDoctorHomeActiveCommitment(response.data);
  }

  @override
  Future<DoctorHomeCommitment> get(
    String commitmentId, {
    CancelToken? cancelToken,
  }) async {
    final response = await _httpClient.dio.get<dynamic>(
      '$path/$commitmentId',
      cancelToken: cancelToken,
      options: Options(headers: const {'Cache-Control': 'no-store'}),
    );
    final commitment = parseDoctorHomeCommitment(response.data);
    if (commitment.commitmentId != commitmentId) {
      throw const FormatException(
        'Mismatched HOME commitment detail identity.',
      );
    }
    return commitment;
  }
}

enum DoctorHomeCommitmentFailureKind {
  notFound,
  sessionRejected,
  unavailable,
  invalidResponse,
  unknown,
}

class DoctorHomeCommitmentFailure implements Exception {
  const DoctorHomeCommitmentFailure({
    required this.kind,
    required this.message,
  });

  final DoctorHomeCommitmentFailureKind kind;
  final String message;

  static DoctorHomeCommitmentFailure from(Object error) {
    if (error is FormatException) {
      return const DoctorHomeCommitmentFailure(
        kind: DoctorHomeCommitmentFailureKind.invalidResponse,
        message:
            'La réponse de l’engagement HOME est incompatible avec cette version.',
      );
    }
    if (error is! DioException) {
      return const DoctorHomeCommitmentFailure(
        kind: DoctorHomeCommitmentFailureKind.unknown,
        message: 'L’engagement HOME ne peut pas être vérifié.',
      );
    }
    final status = error.response?.statusCode;
    final data = error.response?.data;
    final json = data is Map ? data.cast<Object?, Object?>() : null;
    final code = json?['code'];
    if (status == 401 || status == 403) {
      return const DoctorHomeCommitmentFailure(
        kind: DoctorHomeCommitmentFailureKind.sessionRejected,
        message: 'Votre session ne permet plus de consulter cet engagement.',
      );
    }
    if (status == 404 && code == 'HOME_COMMITMENT_NOT_FOUND') {
      return const DoctorHomeCommitmentFailure(
        kind: DoctorHomeCommitmentFailureKind.notFound,
        message: 'Cet engagement HOME n’est plus disponible.',
      );
    }
    if (status == 503 && code == 'HOME_COMMITMENT_READ_UNAVAILABLE') {
      return const DoctorHomeCommitmentFailure(
        kind: DoctorHomeCommitmentFailureKind.unavailable,
        message: 'La responsabilité HOME est temporairement indisponible.',
      );
    }
    if (status != null && status >= 500) {
      return const DoctorHomeCommitmentFailure(
        kind: DoctorHomeCommitmentFailureKind.unavailable,
        message: 'La responsabilité HOME est temporairement indisponible.',
      );
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError ||
        error.response == null) {
      return const DoctorHomeCommitmentFailure(
        kind: DoctorHomeCommitmentFailureKind.unavailable,
        message:
            'Connexion impossible. La responsabilité HOME n’a pas pu être vérifiée.',
      );
    }
    return const DoctorHomeCommitmentFailure(
      kind: DoctorHomeCommitmentFailureKind.unknown,
      message: 'L’engagement HOME ne peut pas être vérifié.',
    );
  }

  @override
  String toString() => message;
}
