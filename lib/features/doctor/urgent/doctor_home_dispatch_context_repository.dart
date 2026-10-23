import 'package:dio/dio.dart';

import '../../../core/network/app_http_client.dart';
import 'doctor_home_dispatch_context.dart';

abstract interface class DoctorHomeDispatchContextRepositoryContract {
  Future<DoctorHomeDispatchContext> get(
    String commitmentId, {
    CancelToken? cancelToken,
  });
}

class DoctorHomeDispatchContextRepository
    implements DoctorHomeDispatchContextRepositoryContract {
  const DoctorHomeDispatchContextRepository(this._httpClient);

  static const commitmentsPath = '/me/urgent-home/commitments';

  final AppHttpClient _httpClient;

  @override
  Future<DoctorHomeDispatchContext> get(
    String commitmentId, {
    CancelToken? cancelToken,
  }) async {
    final response = await _httpClient.dio.get<dynamic>(
      '$commitmentsPath/$commitmentId/dispatch-context',
      cancelToken: cancelToken,
      options: Options(headers: const {'Cache-Control': 'no-store'}),
    );
    final context = parseDoctorHomeDispatchContext(response.data);
    if (context.commitmentId != commitmentId) {
      throw const FormatException(
        'Mismatched HOME dispatch-context commitment identity.',
      );
    }
    return context;
  }
}

enum DoctorHomeDispatchContextFailureKind {
  notFound,
  sessionRejected,
  unavailable,
  invalidResponse,
  unknown,
}

class DoctorHomeDispatchContextFailure implements Exception {
  const DoctorHomeDispatchContextFailure({
    required this.kind,
    required this.message,
  });

  final DoctorHomeDispatchContextFailureKind kind;
  final String message;

  static DoctorHomeDispatchContextFailure from(Object error) {
    if (error is FormatException) {
      return const DoctorHomeDispatchContextFailure(
        kind: DoctorHomeDispatchContextFailureKind.invalidResponse,
        message:
            'La destination HOME reçue est incompatible avec cette version.',
      );
    }
    if (error is! DioException) {
      return const DoctorHomeDispatchContextFailure(
        kind: DoctorHomeDispatchContextFailureKind.unknown,
        message: 'La destination HOME ne peut pas être vérifiée.',
      );
    }
    final status = error.response?.statusCode;
    final data = error.response?.data;
    final json = data is Map ? data.cast<Object?, Object?>() : null;
    final code = json?['code'];
    if (status == 401 || status == 403) {
      return const DoctorHomeDispatchContextFailure(
        kind: DoctorHomeDispatchContextFailureKind.sessionRejected,
        message: 'Votre session ne permet plus de consulter cette destination.',
      );
    }
    if (status == 404 && code == 'HOME_DISPATCH_CONTEXT_NOT_FOUND') {
      return const DoctorHomeDispatchContextFailure(
        kind: DoctorHomeDispatchContextFailureKind.notFound,
        message: 'La destination HOME n’est pas disponible.',
      );
    }
    if (status == 503 && code == 'HOME_DISPATCH_CONTEXT_UNAVAILABLE') {
      return const DoctorHomeDispatchContextFailure(
        kind: DoctorHomeDispatchContextFailureKind.unavailable,
        message: 'La destination HOME est temporairement indisponible.',
      );
    }
    if (status != null && status >= 500) {
      return const DoctorHomeDispatchContextFailure(
        kind: DoctorHomeDispatchContextFailureKind.unavailable,
        message: 'La destination HOME est temporairement indisponible.',
      );
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError ||
        error.response == null) {
      return const DoctorHomeDispatchContextFailure(
        kind: DoctorHomeDispatchContextFailureKind.unavailable,
        message:
            'Connexion impossible. La destination n’a pas pu être vérifiée.',
      );
    }
    return const DoctorHomeDispatchContextFailure(
      kind: DoctorHomeDispatchContextFailureKind.unknown,
      message: 'La destination HOME ne peut pas être vérifiée.',
    );
  }

  @override
  String toString() => message;
}
