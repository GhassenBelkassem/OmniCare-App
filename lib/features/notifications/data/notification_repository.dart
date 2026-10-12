import 'package:dio/dio.dart';

import '../domain/notification_models.dart';
import 'notification_api.dart';

enum NotificationFailureKind {
  unauthenticated,
  forbidden,
  notFound,
  network,
  contract,
  unknown,
}

class NotificationFailure implements Exception {
  const NotificationFailure(this.kind, this.message);

  final NotificationFailureKind kind;
  final String message;

  static NotificationFailure from(Object error) {
    if (error is NotificationFailure) return error;
    if (error is NotificationContractException || error is TypeError) {
      return const NotificationFailure(
        NotificationFailureKind.contract,
        'Les notifications reçues sont invalides.',
      );
    }
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 401) {
        return const NotificationFailure(
          NotificationFailureKind.unauthenticated,
          'Votre session a expiré.',
        );
      }
      if (status == 403) {
        return const NotificationFailure(
          NotificationFailureKind.forbidden,
          'Accès aux notifications refusé.',
        );
      }
      if (status == 404) {
        return const NotificationFailure(
          NotificationFailureKind.notFound,
          'Cette notification n’existe plus.',
        );
      }
      if (error.response == null) {
        return const NotificationFailure(
          NotificationFailureKind.network,
          'Connexion impossible. Réessayez.',
        );
      }
    }
    return const NotificationFailure(
      NotificationFailureKind.unknown,
      'Impossible de charger les notifications.',
    );
  }
}

abstract class NotificationRepositoryContract {
  Future<NotificationPage> getNotifications(
    NotificationListQuery query, {
    CancelToken? cancelToken,
  });
  Future<int> getUnreadCount({CancelToken? cancelToken});
  Future<void> markRead(String notificationId, {CancelToken? cancelToken});
  Future<int> markAllRead({CancelToken? cancelToken});
}

class NotificationRepository implements NotificationRepositoryContract {
  NotificationRepository(this._api);

  final NotificationApiContract _api;

  @override
  Future<NotificationPage> getNotifications(
    NotificationListQuery query, {
    CancelToken? cancelToken,
  }) async {
    try {
      return NotificationPage.fromJson(
        await _api.getNotifications(query, cancelToken: cancelToken),
      );
    } catch (error) {
      throw NotificationFailure.from(error);
    }
  }

  @override
  Future<int> getUnreadCount({CancelToken? cancelToken}) async {
    try {
      final json = await _api.getUnreadCount(cancelToken: cancelToken);
      final value = json['unreadCount'];
      if (value is! int || value < 0) {
        throw const NotificationContractException('Invalid unread count.');
      }
      return value;
    } catch (error) {
      throw NotificationFailure.from(error);
    }
  }

  @override
  Future<void> markRead(
    String notificationId, {
    CancelToken? cancelToken,
  }) async {
    try {
      await _api.markRead(notificationId, cancelToken: cancelToken);
    } catch (error) {
      throw NotificationFailure.from(error);
    }
  }

  @override
  Future<int> markAllRead({CancelToken? cancelToken}) async {
    try {
      final json = await _api.markAllRead(cancelToken: cancelToken);
      final value = json['updated'];
      if (value is! int || value < 0) {
        throw const NotificationContractException('Invalid updated count.');
      }
      return value;
    } catch (error) {
      throw NotificationFailure.from(error);
    }
  }
}
