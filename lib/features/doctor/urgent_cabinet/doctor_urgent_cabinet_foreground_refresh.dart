import 'dart:async';

typedef DoctorUrgentCabinetRefreshTimerFactory =
    Timer Function(Duration delay, void Function() callback);

/// Foreground-only reconciliation owner for the Doctor CABINET inbox.
///
/// It deliberately has no realtime/push semantics. A successful read schedules
/// the next normal poll; failures use bounded exponential backoff. Because the
/// next one-shot timer is armed only after the current read completes, network
/// requests can never overlap.
class DoctorUrgentCabinetForegroundRefresh {
  DoctorUrgentCabinetForegroundRefresh({
    required Future<bool> Function() refresh,
    this.interval = const Duration(seconds: 20),
    this.maximumFailureBackoff = const Duration(minutes: 5),
    DoctorUrgentCabinetRefreshTimerFactory? timerFactory,
  }) : assert(interval > Duration.zero),
       assert(maximumFailureBackoff >= interval),
       _refresh = refresh,
       _timerFactory = timerFactory ?? _defaultTimerFactory;

  final Future<bool> Function() _refresh;
  final DoctorUrgentCabinetRefreshTimerFactory _timerFactory;
  final Duration interval;
  final Duration maximumFailureBackoff;

  Timer? _timer;
  Future<void>? _inFlight;
  bool _foreground = false;
  bool _disposed = false;
  int _activationEpoch = 0;
  int _consecutiveFailures = 0;

  bool get isActive => _foreground && !_disposed;

  int get consecutiveFailures => _consecutiveFailures;

  /// Activates the owner for a view entry or application resume and performs
  /// one immediate reconciliation. If an older generation is still finishing,
  /// exactly one new-generation read follows it.
  void start() {
    if (_disposed) return;
    _cancelTimer();
    _foreground = true;
    _consecutiveFailures = 0;
    final epoch = ++_activationEpoch;
    final active = _inFlight;
    if (active == null) {
      unawaited(_beginRefresh(epoch));
    } else {
      active.whenComplete(() {
        if (isActive && epoch == _activationEpoch) {
          unawaited(_beginRefresh(epoch));
        }
      });
    }
  }

  void pause() {
    _activationEpoch++;
    _foreground = false;
    _consecutiveFailures = 0;
    _cancelTimer();
  }

  Future<void> refreshNow() {
    if (!isActive) return Future<void>.value();
    _cancelTimer();
    return _beginRefresh(_activationEpoch);
  }

  Future<void> _beginRefresh(int epoch) {
    if (!isActive || epoch != _activationEpoch) {
      return Future<void>.value();
    }
    final active = _inFlight;
    if (active != null) return active;
    final started = _executeRefresh(epoch);
    _inFlight = started;
    started.whenComplete(() {
      if (identical(_inFlight, started)) _inFlight = null;
    });
    return started;
  }

  Future<void> _executeRefresh(int epoch) async {
    var succeeded = false;
    try {
      succeeded = await _refresh();
    } catch (_) {
      succeeded = false;
    }
    if (!isActive || epoch != _activationEpoch) return;
    if (succeeded) {
      _consecutiveFailures = 0;
    } else {
      _consecutiveFailures++;
    }
    _scheduleNext(epoch, _nextDelay());
  }

  Duration _nextDelay() {
    var delay = interval;
    for (var attempt = 0; attempt < _consecutiveFailures; attempt++) {
      final doubled = delay * 2;
      if (doubled >= maximumFailureBackoff) {
        return maximumFailureBackoff;
      }
      delay = doubled;
    }
    return delay;
  }

  void _scheduleNext(int epoch, Duration delay) {
    _cancelTimer();
    _timer = _timerFactory(delay, () {
      _timer = null;
      if (isActive && epoch == _activationEpoch) {
        unawaited(_beginRefresh(epoch));
      }
    });
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _activationEpoch++;
    _foreground = false;
    _cancelTimer();
    _inFlight = null;
  }

  static Timer _defaultTimerFactory(Duration delay, void Function() callback) =>
      Timer(delay, callback);
}
