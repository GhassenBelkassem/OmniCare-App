import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  TokenStorage._();

  static const _storage = FlutterSecureStorage();

  static const _jwtKey = 'jwt_token';
  static const _onboardingCompleteKey = 'onboarding_complete';

  static Future<void> saveJwt(String token) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_jwtKey, token);
      return;
    }
    await _storage.write(key: _jwtKey, value: token);
  }

  static Future<void> saveOnboardingComplete(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompleteKey, value);
  }

  static Future<bool?> readOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_onboardingCompleteKey)) {
      return null;
    }
    return prefs.getBool(_onboardingCompleteKey);
  }

  static Future<String?> readJwt() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_jwtKey);
    }
    return _storage.read(key: _jwtKey);
  }

  static Future<void> clearJwt() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_jwtKey);
      await prefs.remove(_onboardingCompleteKey);
      return;
    }
    await _storage.delete(key: _jwtKey);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_onboardingCompleteKey);
  }
}
