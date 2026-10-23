import 'dart:collection';

class RecentEventDeduper {
  RecentEventDeduper({this.capacity = 256})
    : assert(capacity > 0, 'capacity must be positive');

  final int capacity;
  final Queue<String> _order = Queue<String>();
  final Set<String> _ids = <String>{};

  int get length => _ids.length;

  bool accept(String eventId) {
    if (_ids.contains(eventId)) return false;
    _ids.add(eventId);
    _order.addLast(eventId);
    while (_order.length > capacity) {
      _ids.remove(_order.removeFirst());
    }
    return true;
  }

  void clear() {
    _order.clear();
    _ids.clear();
  }
}
