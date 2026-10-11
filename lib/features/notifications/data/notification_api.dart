import '../../../core/network/app_http_client.dart';
import 'notification_models.dart';

class NotificationApi {
  const NotificationApi(this._client);
  final AppHttpClient _client;

  Future<NotificationPage> list({
    String? category,
    bool unreadOnly = false,
    int page = 0,
    int pageSize = 20,
  }) async {
    final queryParameters = <String, Object?>{
      'unreadOnly': unreadOnly,
      'page': page,
      'pageSize': pageSize,
    };
    if (category != null) {
      queryParameters['category'] = category;
    }
    final response = await _client.dio.get<Object?>(
      '/notifications',
      queryParameters: queryParameters,
    );
    return NotificationPage.fromJson(_object(response.data));
  }

  Future<int> unreadCount() async {
    final response = await _client.dio.get<Object?>(
      '/notifications/unread-count',
    );
    return _int(_object(response.data), 'unreadCount');
  }

  Future<void> markRead(String id) async {
    await _client.dio.post<void>('/notifications/$id/read');
  }

  Future<int> markAllRead() async {
    final response = await _client.dio.post<Object?>('/notifications/read-all');
    return _int(_object(response.data), 'updated');
  }
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map) {
    throw const FormatException('Expected an object response.');
  }
  return value.cast<String, dynamic>();
}

int _int(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num) throw FormatException('Missing $key.');
  return value.toInt();
}
