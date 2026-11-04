import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_foreground_refresh.dart';

void main() {
  test('continues reconciling and discovers work after five minutes', () async {
    final clock = _ManualRefreshClock();
    var calls = 0;
    var requestVisible = false;
    final refresh = DoctorUrgentCabinetForegroundRefresh(
      timerFactory: clock.createTimer,
      refresh: () async {
        calls++;
        if (clock.elapsed > const Duration(minutes: 5)) {
          requestVisible = true;
        }
        return true;
      },
    );
    addTearDown(refresh.dispose);

    refresh.start();
    await _flushAsyncWork();
    for (var cycle = 0; cycle < 16; cycle++) {
      clock.elapse(const Duration(seconds: 20));
      await _flushAsyncWork();
    }

    expect(clock.elapsed, const Duration(minutes: 5, seconds: 20));
    expect(calls, 17);
    expect(requestVisible, isTrue);
    expect(refresh.isActive, isTrue);
  });

  test(
    'background suspends polling and resume refreshes exactly once',
    () async {
      final clock = _ManualRefreshClock();
      var calls = 0;
      final refresh = DoctorUrgentCabinetForegroundRefresh(
        timerFactory: clock.createTimer,
        refresh: () async {
          calls++;
          return true;
        },
      );
      addTearDown(refresh.dispose);

      refresh.start();
      await _flushAsyncWork();
      expect(calls, 1);

      refresh.pause();
      clock.elapse(const Duration(minutes: 10));
      await _flushAsyncWork();
      expect(calls, 1);
      expect(refresh.isActive, isFalse);

      refresh.start();
      await _flushAsyncWork();
      expect(calls, 2);
      expect(refresh.isActive, isTrue);
    },
  );

  test('network failures use bounded backoff and success resets it', () async {
    final clock = _ManualRefreshClock();
    var calls = 0;
    final refresh = DoctorUrgentCabinetForegroundRefresh(
      interval: const Duration(seconds: 20),
      maximumFailureBackoff: const Duration(minutes: 5),
      timerFactory: clock.createTimer,
      refresh: () async {
        calls++;
        if (calls == 1) throw StateError('synthetic network failure');
        return calls >= 5;
      },
    );
    addTearDown(refresh.dispose);

    refresh.start();
    await _flushAsyncWork();
    expect(clock.latestDelay, const Duration(seconds: 40));

    clock.elapse(const Duration(seconds: 40));
    await _flushAsyncWork();
    expect(clock.latestDelay, const Duration(seconds: 80));

    clock.elapse(const Duration(seconds: 80));
    await _flushAsyncWork();
    expect(clock.latestDelay, const Duration(seconds: 160));

    clock.elapse(const Duration(seconds: 160));
    await _flushAsyncWork();
    expect(clock.latestDelay, const Duration(minutes: 5));

    clock.elapse(const Duration(minutes: 5));
    await _flushAsyncWork();
    expect(calls, 5);
    expect(refresh.consecutiveFailures, 0);
    expect(clock.latestDelay, const Duration(seconds: 20));
  });

  test('lifecycle refreshes never overlap an in-flight read', () async {
    final clock = _ManualRefreshClock();
    final first = Completer<bool>();
    final second = Completer<bool>();
    var calls = 0;
    var concurrent = 0;
    var maximumConcurrent = 0;
    final refresh = DoctorUrgentCabinetForegroundRefresh(
      timerFactory: clock.createTimer,
      refresh: () {
        calls++;
        concurrent++;
        maximumConcurrent = concurrent > maximumConcurrent
            ? concurrent
            : maximumConcurrent;
        final operation = calls == 1 ? first.future : second.future;
        return operation.whenComplete(() => concurrent--);
      },
    );
    addTearDown(refresh.dispose);

    refresh.start();
    refresh.start();
    clock.elapse(const Duration(minutes: 10));
    expect(calls, 1);

    first.complete(true);
    await _flushAsyncWork();
    expect(calls, 2);
    expect(maximumConcurrent, 1);

    clock.elapse(const Duration(minutes: 10));
    expect(calls, 2);
    second.complete(true);
    await _flushAsyncWork();
    expect(maximumConcurrent, 1);
  });

  test('pause rejects late completion and disposal prevents restart', () async {
    final clock = _ManualRefreshClock();
    final pending = Completer<bool>();
    var calls = 0;
    final refresh = DoctorUrgentCabinetForegroundRefresh(
      timerFactory: clock.createTimer,
      refresh: () {
        calls++;
        return pending.future;
      },
    );

    refresh.start();
    refresh.pause();
    pending.complete(true);
    await _flushAsyncWork();
    clock.elapse(const Duration(minutes: 10));
    expect(calls, 1);
    expect(clock.hasActiveTimer, isFalse);

    refresh.dispose();
    refresh.start();
    await _flushAsyncWork();
    expect(calls, 1);
  });
}

Future<void> _flushAsyncWork() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _ManualRefreshClock {
  Duration elapsed = Duration.zero;
  final List<_ManualTimer> _timers = [];
  final List<Duration> scheduledDelays = [];

  Duration? get latestDelay =>
      scheduledDelays.isEmpty ? null : scheduledDelays.last;

  bool get hasActiveTimer => _timers.any((timer) => timer.isActive);

  Timer createTimer(Duration delay, void Function() callback) {
    scheduledDelays.add(delay);
    final timer = _ManualTimer(this, elapsed + delay, callback);
    _timers.add(timer);
    return timer;
  }

  void elapse(Duration duration) {
    final target = elapsed + duration;
    while (true) {
      _ManualTimer? next;
      for (final timer in _timers) {
        if (!timer.isActive || timer.dueAt > target) continue;
        if (next == null || timer.dueAt < next.dueAt) next = timer;
      }
      if (next == null) break;
      elapsed = next.dueAt;
      next.fire();
    }
    elapsed = target;
    _timers.removeWhere((timer) => !timer.isActive);
  }
}

class _ManualTimer implements Timer {
  _ManualTimer(this.clock, this.dueAt, this.callback);

  final _ManualRefreshClock clock;
  final Duration dueAt;
  final void Function() callback;
  bool _active = true;
  int _tick = 0;

  @override
  bool get isActive => _active;

  @override
  int get tick => _tick;

  @override
  void cancel() => _active = false;

  void fire() {
    if (!_active) return;
    _active = false;
    _tick = 1;
    callback();
  }
}
