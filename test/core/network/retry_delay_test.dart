import 'package:flutter_test/flutter_test.dart';

import '../../../lib/core/network/retry_delay.dart';

void main() {
  test('positive jitter never retries before the base delay', () {
    final policy = RetryDelayPolicy(
      maximumBaseDelay: const Duration(minutes: 1),
      jitterRatio: 0.20,
      randomDouble: () => 1,
    );

    expect(
      policy.jitter(const Duration(seconds: 10)),
      const Duration(seconds: 12),
    );
  });

  test('exponential delay is capped', () {
    final policy = RetryDelayPolicy(
      maximumBaseDelay: const Duration(minutes: 1),
      randomDouble: () => 0,
    );

    expect(
      policy.doubled(const Duration(seconds: 40)),
      const Duration(minutes: 1),
    );
  });

  test('Retry-After is treated as the minimum base delay', () {
    final policy = RetryDelayPolicy(
      maximumBaseDelay: const Duration(minutes: 1),
      jitterRatio: 0,
      randomDouble: () => 0,
    );

    expect(
      policy.atLeast(
        const Duration(seconds: 8),
        const Duration(minutes: 2),
      ),
      const Duration(minutes: 2),
    );
  });
}
