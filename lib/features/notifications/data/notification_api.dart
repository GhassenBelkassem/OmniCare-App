import 'package:dio/dio.dart';

import '../../../core/network/app_http_client.dart';
import '../domain/notification_models.dart';

abstract class NotificationApiContract {
  Future<Map<String, dynamic>> getNotifications(
    NotificationListQuery query, {
    CancelToken? cancelToken,
  });
  Future<Map<String, dynamic>> getUnreadCount({CancelToken? cancelToken});
  Future<void> markRead(String notificationId, {CancelToken? cancelToken});
  Future<Map<String, dynamic>> markAllRead({CancelToken? cancelToken});
}

class NotificationApi implements NotificationApiContract {
  NotificationApi(this._httpClient);

  final AppHttpClient _httpClient;

  @override
  Future<Map<String, dynamic>> getNotifications(
    NotificationListQuery query, {
    CancelToken? cancelToken,
  }) async {
    final response = await _httpClient.dio.get<dynamic>(
      '/notifications',
      queryParameters: query.toQueryParameters(),
      cancelToken: cancelToken,
    );
    return _object(response.data, 'notification list');
  }

  @override
  Future<Map<String, dynamic>> getUnreadCount({
    CancelToken? cancelToken,
  }) async {
    final response = await _httpClient.dio.get<dynamic>(
      '/notifications/unread-count',
      cancelToken: cancelToken,
    );
    return _object(response.data, 'notification unread count');
  }

  @override
  Future<void> markRead(
    String notificationId, {
    CancelToken? cancelToken,
  }) async {
    await _httpClient.dio.post<void>(
      '/notifications/$notificationId/read',
      cancelToken: cancelToken,
    );
  }

  @override
  Future<Map<String, dynamic>> markAllRead({CancelToken? cancelToken}) async {
    final response = await _httpClient.dio.post<dynamic>(
      '/notifications/read-all',
      cancelToken: cancelToken,
    );
    return _object(response.data, 'mark-all response');
  }

  Map<String, dynamic> _object(Object? value, String label) {
    if (value is Map) return value.cast<String, dynamic>();
    throw NotificationContractException('Invalid $label response.');
  }
}
