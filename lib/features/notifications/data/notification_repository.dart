import 'notification_api.dart';
import 'notification_models.dart';

abstract interface class NotificationRepositoryContract {
  Future<NotificationPage> list({int page, int pageSize});
  Future<int> unreadCount();
  Future<void> markRead(String id);
  Future<int> markAllRead();
}

class NotificationRepository implements NotificationRepositoryContract {
  const NotificationRepository(this._api);
  final NotificationApi _api;

  @override
  Future<NotificationPage> list({int page = 0, int pageSize = 20}) =>
      _api.list(page: page, pageSize: pageSize);
  @override
  Future<int> unreadCount() => _api.unreadCount();
  @override
  Future<void> markRead(String id) => _api.markRead(id);
  @override
  Future<int> markAllRead() => _api.markAllRead();
}
