import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web Maps uses the dedicated build-time key contract', () {
    final provider = File(
      'lib/core/maps/maps_configuration_provider_web.dart',
    ).readAsStringSync();
    final dockerfile = File('Dockerfile').readAsStringSync();
    final example = File('.env.example').readAsStringSync();

    for (final source in [provider, dockerfile, example]) {
      expect(source, contains('GOOGLE_MAPS_WEB_API_KEY'));
      expect(source, isNot(contains('OMNICARE_HOME_DISCOVERY_GOOGLE_API_KEY')));
    }
    expect(example, contains('\nGOOGLE_MAPS_WEB_API_KEY=\n'));
    expect(provider, isNot(contains("fromEnvironment('GOOGLE_MAPS_API_KEY')")));
  });

  test('tracked HTML and Dart source have exactly one Maps script loader', () {
    final index = File('web/index.html').readAsStringSync();
    final loader = File(
      'lib/core/maps/maps_javascript_loader_web.dart',
    ).readAsStringSync();

    expect(index, isNot(contains('maps.googleapis.com/maps/api/js')));
    expect(_occurrences(loader, "'/maps/api/js'"), 1);
    expect(_occurrences(loader, 'data-omnicare-google-maps'), 2);
    expect(loader, contains('_loadFuture ??='));
  });

  test('application initializes Maps before runApp', () {
    final main = File('lib/main.dart').readAsStringSync();

    final initialization = main.indexOf('loadMapsConfiguration()');
    final applicationStart = main.indexOf('runApp(');
    expect(initialization, greaterThanOrEqualTo(0));
    expect(applicationStart, greaterThan(initialization));
  });

  test('Android Maps configuration remains on its native key contract', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(gradle, contains('manifestPlaceholders["MAPS_API_KEY"]'));
    expect(gradle, isNot(contains('GOOGLE_MAPS_WEB_API_KEY')));
    expect(manifest, contains(r'android:value="${MAPS_API_KEY}"'));
    expect(manifest, isNot(contains('GOOGLE_MAPS_WEB_API_KEY')));
  });

  test('client source does not contain backend Routes configuration', () {
    final roots = ['lib', 'web', 'android', 'config'];
    final forbidden = 'OMNICARE_HOME_DISCOVERY_GOOGLE_API_KEY';

    for (final root in roots) {
      for (final entity in Directory(root).listSync(recursive: true)) {
        if (entity is! File || _isGeneratedOrBinary(entity.path)) continue;
        final content = entity.readAsStringSync();
        expect(
          content.contains(forbidden),
          isFalse,
          reason: 'backend Routes configuration found in ${entity.path}',
        );
      }
    }
  });
}

int _occurrences(String source, String needle) =>
    needle.allMatches(source).length;

bool _isGeneratedOrBinary(String path) {
  const ignoredSegments = ['/build/', '/.dart_tool/', '/.gradle/'];
  const textExtensions = {
    '.dart',
    '.html',
    '.json',
    '.kt',
    '.kts',
    '.xml',
    '.yaml',
    '.yml',
    '.properties',
  };
  if (ignoredSegments.any(path.contains)) return true;
  return !textExtensions.any(path.endsWith);
}
