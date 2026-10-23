import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../scheduled_care/realtime/coalesced_refresh.dart';
import '../data/notification_repository.dart';
import '../domain/notification_models.dart';

enum NotificationCenterLoadState { initial, loading, ready, failed }

class NotificationCenterController extends ChangeNotifier {
  NotificationCenterController({
    required NotificationRepositoryContract repository,
    this.pageSize = 20,
  }) : _repository = repository;

  final NotificationRepositoryContract _repository;
  final int pageSize;
  final CoalescedRefresh _countRefresh = CoalescedRefresh();
  final CoalescedRefresh _inboxRefresh = CoalescedRefresh();
  final Map<String, CancelToken> _readTokens = <String, CancelToken>{};

  List<InboxNotification> _items = const [];
  NotificationCenterLoadState _state = NotificationCenterLoadState.initial;
  NotificationFailure? _failure;
  int? _unreadCount;
  int _page = 0;
  int _totalElements = 0;
  bool _loadingMore = false;
  bool _refreshing = false;
  bool _markingAll = false;
  bool _inboxVisible = false;
  bool _inboxInvalidated = false;
  String? _sessionOwnerKey;
  int _sessionGeneration = 0;
  int _listGeneration = 0;
  int _countGeneration = 0;
  CancelToken? _listToken;
  CancelToken? _moreToken;
  CancelToken? _countToken;
  CancelToken? _markAllToken;
  bool _disposed = false;

  List<InboxNotification> get items => _items;
  NotificationCenterLoadState get state => _state;
  NotificationFailure? get failure => _failure;
  int? get unreadCount => _unreadCount;
  int get page => _page;
  int get totalElements => _totalElements;
  bool get isLoading => _state == NotificationCenterLoadState.loading;
  bool get isLoadingMore => _loadingMore;
  bool get isRefreshing => _refreshing;
  bool get isMarkingAll => _markingAll;
  bool get hasLoaded => _state != NotificationCenterLoadState.initial;
  bool get hasMore => _items.length < _totalElements;
  bool get inboxVisible => _inboxVisible;
  Set<String> get markingReadIds => Set.unmodifiable(_readTokens.keys);

  Future<void> startSession(String ownerKey) async {
    final normalized = ownerKey.trim();
    if (_disposed || normalized.isEmpty) return;
    if (_sessionOwnerKey != normalized) {
      clearForSession();
      _sessionOwnerKey = normalized;
    }
    await refreshUnreadCount();
  }

  Future<void> load() => _replaceFirstPage(refreshing: false);

  Future<void> refresh() => _replaceFirstPage(refreshing: true);

  Future<void> loadMore() async {
    if (_disposed || _loadingMore || !hasMore || isLoading || _refreshing) {
      return;
    }
    final sessionGeneration = _sessionGeneration;
    final nextPage = _page + 1;
    final token = _moreToken = CancelToken();
    _loadingMore = true;
    _failure = null;
    _notify();
    try {
      final result = await _repository.getNotifications(
        NotificationListQuery(page: nextPage, pageSize: pageSize),
        cancelToken: token,
      );
      if (!_isSessionCurrent(sessionGeneration) || token.isCancelled) return;
      _items = _dedupe(<InboxNotification>[..._items, ...result.items]);
      _page = result.page;
      _totalElements = result.totalElements;
      _unreadCount = result.unreadCount;
      _state = NotificationCenterLoadState.ready;
    } catch (error) {
      if (!_isSessionCurrent(sessionGeneration) || token.isCancelled) return;
      _failure = NotificationFailure.from(error);
    }
    if (_isSessionCurrent(sessionGeneration) && !token.isCancelled) {
      _loadingMore = false;
      _notify();
    }
  }

  Future<void> _replaceFirstPage({required bool refreshing}) async {
    if (_disposed) return;
    final sessionGeneration = _sessionGeneration;
    final listGeneration = ++_listGeneration;
    _listToken?.cancel('notification-list-replaced');
    _moreToken?.cancel('notification-list-replaced');
    final token = _listToken = CancelToken();
    _loadingMore = false;
    _refreshing = refreshing && _items.isNotEmpty;
    if (!_refreshing) _state = NotificationCenterLoadState.loading;
    _failure = null;
    _notify();
    try {
      final result = await _repository.getNotifications(
        NotificationListQuery(pageSize: pageSize),
        cancelToken: token,
      );
      if (!_isListCurrent(sessionGeneration, listGeneration, token)) return;
      _items = _dedupe(result.items);
      _page = result.page;
      _totalElements = result.totalElements;
      _unreadCount = result.unreadCount;
      _state = NotificationCenterLoadState.ready;
      _inboxInvalidated = false;
    } catch (error) {
      if (!_isListCurrent(sessionGeneration, listGeneration, token)) return;
      _failure = NotificationFailure.from(error);
      if (_items.isEmpty) _state = NotificationCenterLoadState.failed;
    }
    if (_isListCurrent(sessionGeneration, listGeneration, token)) {
      _refreshing = false;
      _notify();
    }
  }

  Future<void> refreshUnreadCount() => _countRefresh.request(_fetchUnreadCount);

  Future<void> _fetchUnreadCount() async {
    if (_disposed || _sessionOwnerKey == null) return;
    final sessionGeneration = _sessionGeneration;
    final countGeneration = ++_countGeneration;
    _countToken?.cancel('notification-count-replaced');
    final token = _countToken = CancelToken();
    try {
      final count = await _repository.getUnreadCount(cancelToken: token);
      if (!_isCountCurrent(sessionGeneration, countGeneration, token)) return;
      _unreadCount = count;
      _notify();
    } catch (_) {
      // Badge freshness is retried on reconnect, foreground, manual refresh,
      // or the next event. Inbox REST remains independently usable.
    }
  }

  Future<void> markRead(String notificationId) async {
    final normalized = notificationId.trim().toLowerCase();
    if (_disposed || _readTokens.containsKey(normalized)) return;
    final index = _items.indexWhere((item) => item.id == normalized);
    if (index < 0) return;
    final sessionGeneration = _sessionGeneration;
    final wasUnread = !_items[index].isRead;
    if (wasUnread) {
      final updated = List<InboxNotification>.of(_items);
      updated[index] = updated[index].copyWith(isRead: true);
      _items = List.unmodifiable(updated);
      if (_unreadCount != null && _unreadCount! > 0) {
        _unreadCount = _unreadCount! - 1;
      }
    }
    final token = CancelToken();
    _readTokens[normalized] = token;
    _notify();
    try {
      await _repository.markRead(normalized, cancelToken: token);
      if (!_isSessionCurrent(sessionGeneration) || token.isCancelled) return;
      await Future.wait(<Future<void>>[
        if (_inboxVisible) _inboxRefresh.request(refresh),
        refreshUnreadCount(),
      ]);
    } catch (error) {
      if (!_isSessionCurrent(sessionGeneration) || token.isCancelled) return;
      _failure = NotificationFailure.from(error);
      await Future.wait(<Future<void>>[
        _inboxRefresh.request(refresh),
        refreshUnreadCount(),
      ]);
    } finally {
      if (_isSessionCurrent(sessionGeneration) &&
          identical(_readTokens[normalized], token)) {
        _readTokens.remove(normalized);
        _notify();
      }
    }
  }

  Future<void> markAllRead() async {
    if (_disposed ||
        _markingAll ||
        (_items.every((item) => item.isRead) && (_unreadCount ?? 0) == 0)) {
      return;
    }
    final sessionGeneration = _sessionGeneration;
    final token = _markAllToken = CancelToken();
    _markingAll = true;
    _items = List.unmodifiable(
      _items.map((item) => item.copyWith(isRead: true)),
    );
    _unreadCount = 0;
    _notify();
    try {
      await _repository.markAllRead(cancelToken: token);
      if (!_isSessionCurrent(sessionGeneration) || token.isCancelled) return;
      await Future.wait(<Future<void>>[
        if (_inboxVisible) _inboxRefresh.request(refresh),
        refreshUnreadCount(),
      ]);
    } catch (error) {
      if (!_isSessionCurrent(sessionGeneration) || token.isCancelled) return;
      _failure = NotificationFailure.from(error);
      await Future.wait(<Future<void>>[
        _inboxRefresh.request(refresh),
        refreshUnreadCount(),
      ]);
    }
    if (_isSessionCurrent(sessionGeneration) &&
        identical(_markAllToken, token)) {
      _markingAll = false;
      _notify();
    }
  }

  Future<void> onRealtimeInvalidation() => _resync(invalidateInbox: true);

  Future<void> onReconnect() => _resync(invalidateInbox: true);

  Future<void> onForeground() => _resync(invalidateInbox: true);

  Future<void> _resync({required bool invalidateInbox}) async {
    if (_disposed || _sessionOwnerKey == null) return;
    if (invalidateInbox && !_inboxVisible) _inboxInvalidated = true;
    final operations = <Future<void>>[refreshUnreadCount()];
    if (_inboxVisible) operations.add(_inboxRefresh.request(refresh));
    await Future.wait(operations);
  }

  void setInboxVisible(bool visible) {
    if (_disposed || _inboxVisible == visible) return;
    _inboxVisible = visible;
    if (visible && _inboxInvalidated && hasLoaded) {
      unawaited(_inboxRefresh.request(refresh));
    }
  }

  void clearForSession() => _clearForSession(notify: true);

  void _clearForSession({required bool notify}) {
    if (_disposed) return;
    _sessionGeneration++;
    _listGeneration++;
    _countGeneration++;
    _listToken?.cancel('notification-session-cleared');
    _moreToken?.cancel('notification-session-cleared');
    _countToken?.cancel('notification-session-cleared');
    _markAllToken?.cancel('notification-session-cleared');
    for (final token in _readTokens.values) {
      token.cancel('notification-session-cleared');
    }
    _readTokens.clear();
    _countRefresh.reset();
    _inboxRefresh.reset();
    _items = const [];
    _state = NotificationCenterLoadState.initial;
    _failure = null;
    _unreadCount = null;
    _page = 0;
    _totalElements = 0;
    _loadingMore = false;
    _refreshing = false;
    _markingAll = false;
    _inboxVisible = false;
    _inboxInvalidated = false;
    _sessionOwnerKey = null;
    if (notify) _notify();
  }

  static List<InboxNotification> _dedupe(Iterable<InboxNotification> values) {
    final seen = <String>{};
    return List.unmodifiable(values.where((item) => seen.add(item.id)));
  }

  bool _isSessionCurrent(int generation) =>
      !_disposed && generation == _sessionGeneration;

  bool _isListCurrent(
    int sessionGeneration,
    int listGeneration,
    CancelToken token,
  ) =>
      _isSessionCurrent(sessionGeneration) &&
      listGeneration == _listGeneration &&
      identical(token, _listToken) &&
      !token.isCancelled;

  bool _isCountCurrent(
    int sessionGeneration,
    int countGeneration,
    CancelToken token,
  ) =>
      _isSessionCurrent(sessionGeneration) &&
      countGeneration == _countGeneration &&
      identical(token, _countToken) &&
      !token.isCancelled;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _clearForSession(notify: false);
    _disposed = true;
    _countRefresh.dispose();
    _inboxRefresh.dispose();
    super.dispose();
  }
}
