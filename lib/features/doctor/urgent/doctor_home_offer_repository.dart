import 'package:dio/dio.dart';

import '../../../core/network/app_http_client.dart';
import 'doctor_home_offer.dart';

abstract interface class DoctorHomeOfferRepositoryContract {
  Future<List<DoctorHomeOffer>> list({
    int limit = 20,
    DateTime? beforeUpdatedAt,
    String? beforeOfferId,
    CancelToken? cancelToken,
  });

  Future<DoctorHomeOffer> get(String offerId, {CancelToken? cancelToken});

  Future<DoctorHomeOffer> accept({
    required String offerId,
    required int expectedRevision,
    required String idempotencyKey,
    CancelToken? cancelToken,
  });

  Future<DoctorHomeOffer> decline({
    required String offerId,
    required int expectedRevision,
    required String idempotencyKey,
    CancelToken? cancelToken,
  });
}

class DoctorHomeOfferRepository implements DoctorHomeOfferRepositoryContract {
  const DoctorHomeOfferRepository(this._httpClient);

  static const path = '/me/urgent-home/offers';

  final AppHttpClient _httpClient;

  @override
  Future<List<DoctorHomeOffer>> list({
    int limit = 20,
    DateTime? beforeUpdatedAt,
    String? beforeOfferId,
    CancelToken? cancelToken,
  }) async {
    if (limit < 1 ||
        limit > 100 ||
        ((beforeUpdatedAt == null) != (beforeOfferId == null))) {
      throw ArgumentError('Invalid HOME offer page request.');
    }
    final cursorTime = beforeUpdatedAt?.toUtc().toIso8601String();
    final response = await _httpClient.dio.get<dynamic>(
      path,
      queryParameters: {
        'limit': limit,
        'beforeUpdatedAt': ?cursorTime,
        'beforeOfferId': ?beforeOfferId,
      },
      cancelToken: cancelToken,
      options: Options(headers: const {'Cache-Control': 'no-store'}),
    );
    final page = parseDoctorHomeOfferList(response.data);
    _validatePage(page, limit);
    return page;
  }

  @override
  Future<DoctorHomeOffer> get(
    String offerId, {
    CancelToken? cancelToken,
  }) async {
    final response = await _httpClient.dio.get<dynamic>(
      '$path/$offerId',
      cancelToken: cancelToken,
      options: Options(headers: const {'Cache-Control': 'no-store'}),
    );
    final offer = parseDoctorHomeOffer(response.data);
    if (offer.offerId != offerId) {
      throw const FormatException('Mismatched HOME offer detail identity.');
    }
    return offer;
  }

  @override
  Future<DoctorHomeOffer> accept({
    required String offerId,
    required int expectedRevision,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) => _command(
    action: DoctorHomeOfferAction.accept,
    offerId: offerId,
    expectedRevision: expectedRevision,
    idempotencyKey: idempotencyKey,
    cancelToken: cancelToken,
  );

  @override
  Future<DoctorHomeOffer> decline({
    required String offerId,
    required int expectedRevision,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) => _command(
    action: DoctorHomeOfferAction.decline,
    offerId: offerId,
    expectedRevision: expectedRevision,
    idempotencyKey: idempotencyKey,
    cancelToken: cancelToken,
  );

  Future<DoctorHomeOffer> _command({
    required DoctorHomeOfferAction action,
    required String offerId,
    required int expectedRevision,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    final key = idempotencyKey.trim();
    if (expectedRevision < 0 || key.isEmpty || key.length > 128) {
      throw ArgumentError('Invalid HOME offer command.');
    }
    final response = await _httpClient.dio.post<dynamic>(
      '$path/$offerId/${action.pathSegment}',
      data: {'expectedRevision': expectedRevision},
      cancelToken: cancelToken,
      options: Options(
        headers: {'Cache-Control': 'no-store', 'Idempotency-Key': key},
      ),
    );
    final offer = parseDoctorHomeOffer(response.data);
    if (offer.offerId != offerId || offer.isPending) {
      throw const FormatException('Invalid HOME offer command response.');
    }
    return offer;
  }

  static void _validatePage(List<DoctorHomeOffer> page, int limit) {
    if (page.length > limit) {
      throw const FormatException('Oversized HOME offer page.');
    }
    final identities = <String>{};
    for (var index = 0; index < page.length; index++) {
      final offer = page[index];
      if (!identities.add(offer.offerId) ||
          (!offer.isPending && !offer.isAcceptedHold)) {
        throw const FormatException('Invalid current HOME offer page.');
      }
      if (index == 0) continue;
      final previous = page[index - 1];
      final ordered =
          previous.updatedAt.isAfter(offer.updatedAt) ||
          (previous.updatedAt == offer.updatedAt &&
              previous.offerId.compareTo(offer.offerId) > 0);
      if (!ordered) {
        throw const FormatException('Unstable HOME offer page order.');
      }
    }
  }
}

enum DoctorHomeOfferAction {
  accept,
  decline;

  String get pathSegment => switch (this) {
    accept => 'accept',
    decline => 'decline',
  };

  String get frenchInfinitive => switch (this) {
    accept => 'accepter',
    decline => 'décliner',
  };
}

enum DoctorHomeOfferFailureKind {
  rolloutUnavailable,
  notFound,
  sessionRejected,
  network,
  serverUnavailable,
  invalidResponse,
  unknown,
}

class DoctorHomeOfferFailure implements Exception {
  const DoctorHomeOfferFailure({required this.kind, required this.message});

  final DoctorHomeOfferFailureKind kind;
  final String message;

  static DoctorHomeOfferFailure from(Object error) {
    if (error is FormatException) {
      return const DoctorHomeOfferFailure(
        kind: DoctorHomeOfferFailureKind.invalidResponse,
        message:
            'La réponse des offres HOME est incompatible avec cette version.',
      );
    }
    if (error is! DioException) {
      return const DoctorHomeOfferFailure(
        kind: DoctorHomeOfferFailureKind.unknown,
        message: 'Les offres HOME sont momentanément indisponibles.',
      );
    }
    final status = error.response?.statusCode;
    final data = error.response?.data;
    final json = data is Map ? data.cast<Object?, Object?>() : null;
    final code = json?['code'];
    if (status == 401 || status == 403) {
      return const DoctorHomeOfferFailure(
        kind: DoctorHomeOfferFailureKind.sessionRejected,
        message: 'Votre session ne permet plus de consulter ces offres.',
      );
    }
    if (status == 404 && code == 'URGENT_RUNTIME_UNAVAILABLE') {
      return const DoctorHomeOfferFailure(
        kind: DoctorHomeOfferFailureKind.rolloutUnavailable,
        message:
            'La lecture des offres HOME n’est pas activée sur cet environnement.',
      );
    }
    if (status == 404) {
      return const DoctorHomeOfferFailure(
        kind: DoctorHomeOfferFailureKind.notFound,
        message: 'Cette offre HOME n’est plus disponible.',
      );
    }
    if (status != null && status >= 500) {
      return const DoctorHomeOfferFailure(
        kind: DoctorHomeOfferFailureKind.serverUnavailable,
        message: 'Le service des offres HOME est temporairement indisponible.',
      );
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError ||
        error.response == null) {
      return const DoctorHomeOfferFailure(
        kind: DoctorHomeOfferFailureKind.network,
        message:
            'Connexion impossible. Réessayez lorsque le réseau est disponible.',
      );
    }
    return const DoctorHomeOfferFailure(
      kind: DoctorHomeOfferFailureKind.unknown,
      message: 'Les offres HOME sont momentanément indisponibles.',
    );
  }

  @override
  String toString() => message;
}

enum DoctorHomeOfferCommandFailureKind {
  stateConflict,
  notActionable,
  idempotencyConflict,
  commandInProgress,
  holdBudgetFull,
  capacityConflict,
  eligibilityChanged,
  locationUnavailable,
  routeUnavailable,
  rolloutUnavailable,
  notFound,
  sessionRejected,
  ambiguous,
  rejected,
}

class DoctorHomeOfferCommandFailure implements Exception {
  const DoctorHomeOfferCommandFailure({
    required this.kind,
    required this.message,
    this.code,
  });

  final DoctorHomeOfferCommandFailureKind kind;
  final String message;
  final String? code;

  bool get hasAmbiguousOutcome =>
      kind == DoctorHomeOfferCommandFailureKind.ambiguous ||
      kind == DoctorHomeOfferCommandFailureKind.commandInProgress;

  static DoctorHomeOfferCommandFailure from(Object error) {
    if (error is FormatException) {
      return const DoctorHomeOfferCommandFailure(
        kind: DoctorHomeOfferCommandFailureKind.ambiguous,
        message:
            'La réponse du serveur est incompatible. Vérifiez le statut avant toute nouvelle action.',
      );
    }
    if (error is! DioException) {
      return const DoctorHomeOfferCommandFailure(
        kind: DoctorHomeOfferCommandFailureKind.ambiguous,
        message:
            'Le résultat de la commande est inconnu. Vérifiez le statut de l’offre.',
      );
    }
    final status = error.response?.statusCode;
    final data = error.response?.data;
    final json = data is Map ? data.cast<Object?, Object?>() : null;
    final code = json?['code'] is String ? json!['code'] as String : null;
    if (status == 401 || status == 403) {
      return DoctorHomeOfferCommandFailure(
        kind: DoctorHomeOfferCommandFailureKind.sessionRejected,
        code: code,
        message: 'Votre session ne permet plus de répondre à cette offre.',
      );
    }
    if (status == 404 && code == 'URGENT_RUNTIME_UNAVAILABLE') {
      return DoctorHomeOfferCommandFailure(
        kind: DoctorHomeOfferCommandFailureKind.rolloutUnavailable,
        code: code,
        message:
            'Les réponses aux offres HOME ne sont pas activées sur cet environnement.',
      );
    }
    if (status == 404) {
      return DoctorHomeOfferCommandFailure(
        kind: DoctorHomeOfferCommandFailureKind.notFound,
        code: code,
        message: 'Cette offre HOME n’est plus disponible.',
      );
    }
    final mapped = switch (code) {
      'RESOURCE_STATE_CONFLICT' => (
        DoctorHomeOfferCommandFailureKind.stateConflict,
        'L’offre a changé. Son statut actuel a été rechargé.',
      ),
      'HOME_OFFER_NOT_ACTIONABLE' => (
        DoctorHomeOfferCommandFailureKind.notActionable,
        'Cette offre ne peut plus recevoir de réponse.',
      ),
      'HOME_OFFER_IDEMPOTENCY_CONFLICT' => (
        DoctorHomeOfferCommandFailureKind.idempotencyConflict,
        'La clé de commande ne correspond plus à cette réponse. Le statut doit être vérifié.',
      ),
      'HOME_OFFER_COMMAND_IN_PROGRESS' => (
        DoctorHomeOfferCommandFailureKind.commandInProgress,
        'La même commande est encore en cours sur le serveur.',
      ),
      'HOME_HOLD_BUDGET_FULL' => (
        DoctorHomeOfferCommandFailureKind.holdBudgetFull,
        'Le nombre maximal de maintiens temporaires est déjà atteint.',
      ),
      'HOME_DOCTOR_CAPACITY_CONFLICT' => (
        DoctorHomeOfferCommandFailureKind.capacityConflict,
        'Une autre responsabilité opérationnelle empêche cette acceptation.',
      ),
      'HOME_OFFER_ELIGIBILITY_CHANGED' || 'PROFESSIONAL_NOT_ELIGIBLE' => (
        DoctorHomeOfferCommandFailureKind.eligibilityChanged,
        'Votre éligibilité professionnelle ne permet plus cette réponse.',
      ),
      'LOCATION_PRESENCE_UNAVAILABLE' ||
      'LOCATION_OBSERVATION_TOO_OLD' ||
      'LOCATION_OBSERVATION_INVALID' => (
        DoctorHomeOfferCommandFailureKind.locationUnavailable,
        'Votre présence GPS actuelle ne peut pas être vérifiée.',
      ),
      'HOME_ROUTE_VERIFICATION_UNAVAILABLE' => (
        DoctorHomeOfferCommandFailureKind.routeUnavailable,
        'La distance routière actuelle ne peut pas être vérifiée.',
      ),
      _ => null,
    };
    if (mapped != null) {
      return DoctorHomeOfferCommandFailure(
        kind: mapped.$1,
        code: code,
        message: mapped.$2,
      );
    }
    if (status != null && status >= 500 ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError ||
        error.response == null) {
      return DoctorHomeOfferCommandFailure(
        kind: DoctorHomeOfferCommandFailureKind.ambiguous,
        code: code,
        message:
            'Le résultat de la commande est inconnu. Vérifiez le statut avant de réessayer.',
      );
    }
    return DoctorHomeOfferCommandFailure(
      kind: DoctorHomeOfferCommandFailureKind.rejected,
      code: code,
      message: 'La commande a été refusée par le serveur.',
    );
  }

  @override
  String toString() => message;
}
