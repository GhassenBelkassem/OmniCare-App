import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../scheduled_care/realtime/scheduled_care_realtime.dart';
import '../data/notification_models.dart';
import '../data/notification_repository.dart';

class NotificationController extends ChangeNotifier
    with WidgetsBindingObserver {
  NotificationController({
    required NotificationRepositoryContract repository,
    required ScheduledCareRealtime realtime,
  }) : _repository = repository,
       _realtime = realtime {
    WidgetsBinding.instance.addObserver(this);
  }

  static const pageSize = 20;
  final NotificationRepositoryContract _repository;
  final ScheduledCareRealtime _realtime;
  List<InboxNotification> _items = const [];
  int _unreadCount = 0;
  int _nextPage = 0;
  int _totalElements = 0;
  bool _started = false;
  bool _visible = false;
  bool _loading = false;
  bool _loadingMore = false;
  bool _refreshing = false;
  String? _error;

  List<InboxNotification> get items => _items;
  int get unreadCount => _unreadCount;
  bool get isLoading => _loading;
  bool get isLoadingMore => _loadingMore;
  bool get isRefreshing => _refreshing;
  bool get canLoadMore => _items.length < _totalElements;
  String? get error => _error;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    await Future.wait([refreshCount(), refresh()]);
    await _realtime.connectNotifications(
      _onInvalidation,
      onConnected: () => unawaited(resync()),
    );
  }

  Future<void> refresh({bool silent = false}) async {
    if (_loading || _refreshing) return;
    if (_items.isEmpty && !silent) {
      _loading = true;
    } else {
      _refreshing = true;
    }
    _error = null;
    notifyListeners();
    try {
      final response = await _repository.list(page: 0, pageSize: pageSize);
      _items = response.items;
      _unreadCount = response.unreadCount;
      _totalElements = response.totalElements;
      _nextPage = 1;
    } catch (_) {
      _error = 'Impossible de charger les notifications.';
    } finally {
      _loading = false;
      _refreshing = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_loadingMore || !canLoadMore) return;
    _loadingMore = true;
    notifyListeners();
    try {
      final response = await _repository.list(
        page: _nextPage,
        pageSize: pageSize,
      );
      final known = _items.map((item) => item.id).toSet();
      _items = [
        ..._items,
        ...response.items.where((item) => known.add(item.id)),
      ];
      _unreadCount = response.unreadCount;
      _totalElements = response.totalElements;
      _nextPage++;
    } catch (_) {
      _error = 'Impossible de charger plus de notifications.';
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> refreshCount() async {
    try {
      _unreadCount = await _repository.unreadCount();
      notifyListeners();
    } catch (_) {
      // Preserve the last durable count until the next successful REST sync.
    }
  }

  Future<void> markRead(InboxNotification notification) async {
    if (notification.read) return;
    _items = _items
        .map(
          (item) =>
              item.id == notification.id ? item.copyWith(read: true) : item,
        )
        .toList(growable: false);
    _unreadCount = (_unreadCount - 1).clamp(0, 1 << 31);
    notifyListeners();
    try {
      await _repository.markRead(notification.id);
    } catch (_) {
      await refreshCount();
      if (_visible) await refresh(silent: true);
    }
  }

  Future<void> markAllRead() async {
    final previousItems = _items;
    final previousCount = _unreadCount;
    _items = _items
        .map((item) => item.copyWith(read: true))
        .toList(growable: false);
    _unreadCount = 0;
    notifyListeners();
    try {
      await _repository.markAllRead();
    } catch (_) {
      _items = previousItems;
      _unreadCount = previousCount;
      _error = 'Impossible de marquer les notifications comme lues.';
      notifyListeners();
    }
  }

  void setCenterVisible(bool value) {
    _visible = value;
    if (value) unawaited(refresh(silent: _items.isNotEmpty));
  }

  Future<void> resync() async {
    await refreshCount();
    if (_visible) await refresh(silent: true);
  }

  void _onInvalidation(NotificationInvalidation _) => unawaited(resync());

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_started) return;
    unawaited(
      _realtime.connectNotifications(
        _onInvalidation,
        onConnected: () => unawaited(resync()),
      ),
    );
    unawaited(resync());
  }

  void clearSessionState() {
    _started = false;
    _visible = false;
    _items = const [];
    _unreadCount = 0;
    _nextPage = 0;
    _totalElements = 0;
    _error = null;
    _realtime.disconnectNotifications();
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _realtime.disconnectNotifications();
    super.dispose();
  }
}
