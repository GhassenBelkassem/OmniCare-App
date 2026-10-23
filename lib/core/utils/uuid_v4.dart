/// Shared RFC 4122 version 4 UUID helpers.
///
/// Extracted from `DeviceIdentityService` so the device installation id and the
/// Module 05 request operation id use one audited implementation instead of two
/// copies of the same bit-twiddling. No package dependency is added for this: a
/// v4 UUID is 16 secure-random bytes plus two masked nibbles, and pulling in a
/// third-party generator would add supply-chain surface for no benefit.
library;

import 'dart:math';

/// Bytes are drawn from [nextByte], which must return a value in `[0, max)`.
/// Defaults to `Random.secure()`, the only acceptable source in production;
/// tests inject a deterministic generator.
String generateUuidV4({int Function(int max)? nextByte}) {
  final random = nextByte ?? Random.secure().nextInt;
  final bytes = List<int>.generate(16, (_) => random(256));

  // Version 4 (random) and IETF variant, per RFC 4122 §4.4.
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');
  final value = bytes.map(hex).join();
  return '${value.substring(0, 8)}-'
      '${value.substring(8, 12)}-'
      '${value.substring(12, 16)}-'
      '${value.substring(16, 20)}-'
      '${value.substring(20)}';
}

final RegExp _canonicalUuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

/// True when [value] is a lowercase canonical 8-4-4-4-12 UUID.
///
/// Used to reject a persisted or server-supplied identifier that is not a UUID
/// at all, before it is ever placed in a URL path or a request body.
bool isCanonicalUuid(String value) => _canonicalUuid.hasMatch(value);
