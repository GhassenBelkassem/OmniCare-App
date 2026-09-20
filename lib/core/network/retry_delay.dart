import 'dart:math';

/// Central retry timing policy used by reconnect and polling paths.
///
/// Jitter is positive-only: a server supplied Retry-After value remains a
/// true minimum, while clients are spread over time to avoid retry storms.
class RetryDelayPolicy {
  RetryDelayPolicy({
    required this.maximumBaseDelay,
    this.jitterRatio = 0.20,
    double Function()? randomDouble,
  }) : assert(!maximumBaseDelay.isNegative),
       assert(jitterRatio >= 0 && jitterRatio <= 0.50),
       _randomDouble = randomDouble ?? Random.secure().nextDouble;

  final Duration maximumBaseDelay;
  final double jitterRatio;
  final double Function() _randomDouble;

  Duration cap(Duration delay) {
    if (delay.isNegative) return Duration.zero;
    return delay > maximumBaseDelay ? maximumBaseDelay : delay;
  }

  Duration doubled(Duration current) {
    return cap(Duration(microseconds: current.inMicroseconds * 2));
  }

  Duration atLeast(Duration delay, Duration minimum) {
    // Retry-After is a server instruction and must not be shortened by the
    // client's normal exponential-backoff cap.
    return delay > minimum ? delay : minimum;
  }

  Duration jitter(Duration delay) {
    final base = delay.isNegative ? Duration.zero : delay;
    if (base == Duration.zero || jitterRatio == 0) return base;

    final random = _randomDouble().clamp(0.0, 1.0);
    final maximumExtraMicros = (base.inMicroseconds * jitterRatio).round();
    final extraMicros = (maximumExtraMicros * random).round();
    return base + Duration(microseconds: extraMicros);
  }
}
