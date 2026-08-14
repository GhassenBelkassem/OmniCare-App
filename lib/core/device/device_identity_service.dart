import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../features/auth/data/models/auth_dtos.dart';
import '../storage/secure_token_store.dart';
import '../utils/uuid_v4.dart';

class DeviceIdentity {
  final String deviceFingerprint;
  final ClientPlatform platform;
  final String deviceLabel;
  final bool sharedDevice;

  const DeviceIdentity({
    required this.deviceFingerprint,
    required this.platform,
    required this.deviceLabel,
    this.sharedDevice = false,
  });
}

typedef PlatformResolver = TargetPlatform Function();
typedef WebPlatformResolver = bool Function();
typedef RandomByteGenerator = int Function(int max);

class DeviceIdentityService {
  DeviceIdentityService({
    required SecureTokenStore tokenStore,
    PlatformResolver? platformResolver,
    WebPlatformResolver? webPlatformResolver,
    RandomByteGenerator? randomByteGenerator,
  }) : _tokenStore = tokenStore,
       _platformResolver = platformResolver ?? (() => defaultTargetPlatform),
       _webPlatformResolver = webPlatformResolver ?? (() => kIsWeb),
       _randomByteGenerator = randomByteGenerator ?? Random.secure().nextInt;

  final SecureTokenStore _tokenStore;
  final PlatformResolver _platformResolver;
  final WebPlatformResolver _webPlatformResolver;
  final RandomByteGenerator _randomByteGenerator;

  Future<DeviceIdentity> getDeviceIdentity() async {
    final fingerprint = await _getOrCreateInstallationId();
    final platform = _clientPlatform();
    return DeviceIdentity(
      deviceFingerprint: fingerprint,
      platform: platform,
      deviceLabel: switch (platform) {
        ClientPlatform.android => 'Android device',
        ClientPlatform.ios => 'iPhone',
        ClientPlatform.web => 'Web browser',
      },
      sharedDevice: false,
    );
  }

  Future<String> _getOrCreateInstallationId() async {
    final existing = await _tokenStore.readDeviceInstallationId();
    if (existing != null && existing.trim().isNotEmpty) {
      return existing.trim();
    }

    final generated = _generateUuidV4();
    await _tokenStore.saveDeviceInstallationId(generated);
    return generated;
  }

  ClientPlatform _clientPlatform() {
    if (_webPlatformResolver()) return ClientPlatform.web;

    return switch (_platformResolver()) {
      TargetPlatform.iOS => ClientPlatform.ios,
      TargetPlatform.android => ClientPlatform.android,
      _ => throw UnsupportedError(
        'OmniCare patient auth supports Android, iOS, and web in this phase.',
      ),
    };
  }

  String _generateUuidV4() => generateUuidV4(nextByte: _randomByteGenerator);
}
