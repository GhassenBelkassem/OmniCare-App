import 'dart:async';

class CoalescedRefresh {
  bool _running = false;
  bool _pending = false;
  bool _disposed = false;
  int _generation = 0;
  Future<void>? _inFlight;

  bool get isRunning => _running;

  Future<void> request(Future<void> Function() refresh) {
    if (_disposed) return Future<void>.value();
    if (_running) {
      _pending = true;
      return _inFlight ?? Future<void>.value();
    }
    final generation = _generation;
    final operation = _drain(refresh, generation);
    _inFlight = operation;
    return operation;
  }

  Future<void> _drain(Future<void> Function() refresh, int generation) async {
    _running = true;
    try {
      do {
        _pending = false;
        await refresh();
      } while (!_disposed && generation == _generation && _pending);
    } finally {
      if (generation == _generation) {
        _running = false;
        _inFlight = null;
      }
    }
  }

  void reset() {
    _generation++;
    _pending = false;
    _running = false;
    _inFlight = null;
  }

  void dispose() {
    _disposed = true;
    reset();
  }
}
