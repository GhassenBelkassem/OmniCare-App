import 'package:flutter/foundation.dart';

class AppEnvironmentException implements Exception {
  final String message;

  const AppEnvironmentException(this.message);

  @override
  String toString() => message;
}

class AppEnvironment {
  static const _definedBaseUrl = String.fromEnvironment(
    'OMNICARE_API_BASE_URL',
  );
  static const _hasDefinedBaseUrl = bool.hasEnvironment(
    'OMNICARE_API_BASE_URL',
  );

  const AppEnvironment._();

  static String get apiBaseUrl {
    final defined = _definedBaseUrl.trim();
    if (_hasDefinedBaseUrl && defined.isNotEmpty) {
      return normalizeBaseUrl(defined);
    }

    if (kDebugMode) {
      if (kIsWeb) return 'http://localhost:8080';

      return switch (defaultTargetPlatform) {
        TargetPlatform.iOS => 'http://localhost:8080',
        TargetPlatform.android => 'http://10.0.2.2:8080',
        _ => throw const AppEnvironmentException(
          'Set OMNICARE_API_BASE_URL with --dart-define for this platform.',
        ),
      };
    }

    throw const AppEnvironmentException(
      'OMNICARE_API_BASE_URL must be configured with --dart-define.',
    );
  }

  static String get apiV1BaseUrl {
    final base = apiBaseUrl;
    if (base.endsWith('/api/v1')) return base;
    return '$base/api/v1';
  }

  static String normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      throw const AppEnvironmentException('API base URL cannot be empty.');
    }

    final parsed = Uri.tryParse(trimmed);
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
      throw AppEnvironmentException('Invalid API base URL: $trimmed');
    }

    return trimmed.replaceAll(RegExp(r'/+$'), '');
  }
}
