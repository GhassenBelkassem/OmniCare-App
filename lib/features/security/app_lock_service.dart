import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

enum AppLockMethod { none, pin, biometric }

class AppLockService extends ChangeNotifier {
  AppLockService({
    FlutterSecureStorage? storage,
    LocalAuthentication? localAuthentication,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _localAuthentication = localAuthentication ?? LocalAuthentication();

  static const _ownerKey = 'omnicare_app_lock_owner';
  static const _methodKey = 'omnicare_app_lock_method';
  static const _pinSaltKey = 'omnicare_app_lock_pin_salt';
  static const _pinHashKey = 'omnicare_app_lock_pin_hash';
  static const _pinFailureCountKey = 'omnicare_app_lock_pin_failures';
  static const _pinBlockedUntilKey = 'omnicare_app_lock_pin_blocked_until';
  static const _iterations = 120000;

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuthentication;
  final Pbkdf2 _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _iterations,
    bits: 256,
  );

  AppLockMethod _method = AppLockMethod.none;
  String? _ownerUserId;
  bool _locked = false;
  bool _ready = false;
  bool _authenticating = false;
  String? _error;

  AppLockMethod get method => _method;
  bool get enabled => _method != AppLockMethod.none;
  bool get locked => enabled && _locked;
  bool get ready => _ready;
  bool get authenticating => _authenticating;
  String? get error => _error;

  Future<void> initialize() async {
    _ownerUserId = await _storage.read(key: _ownerKey);
    _method = _parseMethod(await _storage.read(key: _methodKey));
    _locked = enabled;
    _ready = true;
    notifyListeners();
  }

  Future<void> bindUser(String? userId) async {
    if (!_ready || userId == null || userId.trim().isEmpty) return;
    if (_ownerUserId == null && !enabled) return;
    if (_ownerUserId == userId) return;
    await _clearConfiguration();
  }

  Future<bool> biometricAvailable() async {
    if (kIsWeb) return false;
    try {
      return await _localAuthentication.canCheckBiometrics &&
          await _localAuthentication.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<void> enablePin(String ownerUserId, String pin) async {
    _validatePin(pin);
    await _resetPinFailures();
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final hash = await _derivePin(pin, salt);
    await _storage.write(key: _ownerKey, value: ownerUserId);
    await _storage.write(key: _pinSaltKey, value: base64Encode(salt));
    await _storage.write(key: _pinHashKey, value: base64Encode(hash));
    await _storage.write(key: _methodKey, value: AppLockMethod.pin.name);
    _ownerUserId = ownerUserId;
    _method = AppLockMethod.pin;
    _locked = false;
    _error = null;
    notifyListeners();
  }

  Future<void> enableBiometric(String ownerUserId) async {
    if (!await biometricAvailable()) {
      throw StateError('La biométrie n’est pas disponible sur cet appareil.');
    }
    final verified = await _authenticateBiometric(
      'Confirmez votre identité pour activer le verrouillage OmniCare.',
    );
    if (!verified) throw StateError('Authentification biométrique annulée.');
    await _storage.write(key: _ownerKey, value: ownerUserId);
    await _storage.write(key: _methodKey, value: AppLockMethod.biometric.name);
    await _storage.delete(key: _pinSaltKey);
    await _storage.delete(key: _pinHashKey);
    await _resetPinFailures();
    _ownerUserId = ownerUserId;
    _method = AppLockMethod.biometric;
    _locked = false;
    _error = null;
    notifyListeners();
  }

  Future<bool> unlockWithPin(String pin) async {
    final blockedUntil = DateTime.tryParse(
      await _storage.read(key: _pinBlockedUntilKey) ?? '',
    );
    if (blockedUntil != null && blockedUntil.isAfter(DateTime.now().toUtc())) {
      final seconds =
          blockedUntil.difference(DateTime.now().toUtc()).inSeconds + 1;
      _error = 'Trop de tentatives. Réessayez dans $seconds s.';
      notifyListeners();
      return false;
    }
    final saltValue = await _storage.read(key: _pinSaltKey);
    final hashValue = await _storage.read(key: _pinHashKey);
    if (saltValue == null || hashValue == null) return false;
    try {
      final expected = base64Decode(hashValue);
      final actual = await _derivePin(pin, base64Decode(saltValue));
      final valid = _constantTimeEquals(expected, actual);
      if (valid) {
        await _resetPinFailures();
        _locked = false;
        _error = null;
      } else {
        await _recordPinFailure();
      }
      notifyListeners();
      return valid;
    } catch (_) {
      _error = 'Impossible de vérifier le code.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> unlockWithBiometric() async {
    _authenticating = true;
    _error = null;
    notifyListeners();
    try {
      final verified = await _authenticateBiometric(
        'Déverrouillez OmniCare pour continuer.',
      );
      if (verified) _locked = false;
      return verified;
    } catch (_) {
      _error = 'Authentification biométrique impossible.';
      return false;
    } finally {
      _authenticating = false;
      notifyListeners();
    }
  }

  Future<bool> disable({String? pin}) async {
    bool verified = false;
    if (_method == AppLockMethod.pin) {
      verified = pin != null && await unlockWithPin(pin);
    } else if (_method == AppLockMethod.biometric) {
      verified = await _authenticateBiometric(
        'Confirmez votre identité pour désactiver le verrouillage.',
      );
    }
    if (!verified) return false;
    await _clearConfiguration();
    return true;
  }

  void lock() {
    if (!enabled || _locked) return;
    _locked = true;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<List<int>> _derivePin(String pin, List<int> salt) async {
    final key = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: salt,
    );
    return key.extractBytes();
  }

  Future<bool> _authenticateBiometric(String reason) {
    return _localAuthentication.authenticate(
      localizedReason: reason,
      biometricOnly: true,
      persistAcrossBackgrounding: true,
    );
  }

  Future<void> _clearConfiguration() async {
    await Future.wait([
      _storage.delete(key: _ownerKey),
      _storage.delete(key: _methodKey),
      _storage.delete(key: _pinSaltKey),
      _storage.delete(key: _pinHashKey),
      _storage.delete(key: _pinFailureCountKey),
      _storage.delete(key: _pinBlockedUntilKey),
    ]);
    _ownerUserId = null;
    _method = AppLockMethod.none;
    _locked = false;
    _error = null;
    notifyListeners();
  }

  AppLockMethod _parseMethod(String? value) {
    return AppLockMethod.values.firstWhere(
      (method) => method.name == value,
      orElse: () => AppLockMethod.none,
    );
  }

  void _validatePin(String pin) {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw ArgumentError('Le code doit contenir exactement 6 chiffres.');
    }
    const weakPins = {'000000', '111111', '123456', '654321'};
    if (weakPins.contains(pin) || pin.split('').toSet().length == 1) {
      throw ArgumentError('Choisissez un code moins facile à deviner.');
    }
  }

  Future<void> _recordPinFailure() async {
    final previous =
        int.tryParse(await _storage.read(key: _pinFailureCountKey) ?? '') ?? 0;
    final failures = previous + 1;
    await _storage.write(key: _pinFailureCountKey, value: '$failures');
    if (failures < 3) {
      _error = 'Code incorrect.';
      return;
    }
    final delaySeconds = switch (failures) {
      3 => 15,
      4 => 30,
      5 => 60,
      _ => 300,
    };
    final blockedUntil = DateTime.now().toUtc().add(
      Duration(seconds: delaySeconds),
    );
    await _storage.write(
      key: _pinBlockedUntilKey,
      value: blockedUntil.toIso8601String(),
    );
    _error = 'Trop de tentatives. Réessayez dans $delaySeconds s.';
  }

  Future<void> _resetPinFailures() {
    return Future.wait([
      _storage.delete(key: _pinFailureCountKey),
      _storage.delete(key: _pinBlockedUntilKey),
    ]).then((_) {});
  }

  bool _constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left[index] ^ right[index];
    }
    return difference == 0;
  }
}
