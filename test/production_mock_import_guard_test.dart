// G-2 1b-3 guard: mock, fixture and demo data can never come back into the
// production app. Walks the import graph from lib/main.dart (import, export
// and part directives, every branch of conditional imports, multi-line
// directives) and fails on any reachable forbidden file. Logic only.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _package = 'omnicare_mobile';
const _entry = 'lib/main.dart';

/// Doctor-side code: other workstreams own it; G-2 reports what it reaches
/// instead of changing it (task rule). The patient graph stops here.
const _doctorRoot = 'lib/features/doctor/';

/// Mock, fixture and demo data: never reachable from production.
bool isForbiddenData(String path) =>
    path.startsWith('lib/mock_data/') ||
    path.startsWith('lib/demo/') ||
    path.endsWith('_fixture.dart') ||
    path.endsWith('_mock_data.dart');

/// Hardcoded content files: allowed only while listed in [toRemoveIn1c].
bool isStaticData(String path) => path.endsWith('_static_data.dart');

/// STATIC files still reachable today, to remove in Phase 1c. A new
/// `*_static_data.dart` file fails the guard until it is listed here (and it
/// should not be). Delete an entry as soon as its file is unreachable.
const toRemoveIn1c = <String>{};

/// The « Dossier médical » fixture (« Sarah Ben Ahmed »). Cut off from patient
/// code in G2-1b-3b; still imported by the doctor preview
/// (`lib/features/doctor/medical_record/doctor_medical_record_access.dart`,
/// G-1), so it is kept, and reported.
const passportFixture =
    'lib/features/patient_passport/data/patient_passport_static_data.dart';

/// `*_static_data.dart` files reached **only through** `lib/features/doctor/**`.
/// The list must match exactly, so a new one is noticed.
const reportedDoctorSideStaticData = <String>{passportFixture};

/// Forbidden files reached **only through** `lib/features/doctor/**`.
/// Reported in G2-1b-3 §2.4, not changed (doctor behaviour is out of scope).
/// The list must match exactly, so a new doctor-side mock is noticed too.
const reportedDoctorSideOnly = <String>{
  // lib/features/doctor/consultation_detail_screen.dart →
  // lib/core/api/consultations_api.dart:1
  'lib/mock_data/mock_consultations.dart',
};

final _directive = RegExp(
  r'^\s*(?:import|export|part)\b[^;]*;',
  multiLine: true,
);
final _quoted = RegExp(r'''['"]([^'"]+)['"]''');

/// The package-relative paths a Dart file imports, exports or includes.
/// Every URI of a conditional import counts: both branches ship.
List<String> directiveTargets(String fromPath, String source) {
  final targets = <String>[];
  for (final directive in _directive.allMatches(source)) {
    for (final uri in _quoted.allMatches(directive.group(0)!)) {
      final target = _resolve(fromPath, uri.group(1)!);
      if (target != null) targets.add(target);
    }
  }
  return targets;
}

String? _resolve(String fromPath, String uri) {
  if (uri.startsWith('dart:')) return null;
  if (uri.startsWith('package:')) {
    const prefix = 'package:$_package/';
    return uri.startsWith(prefix)
        ? 'lib/${uri.substring(prefix.length)}'
        : null;
  }
  final segments = fromPath.split('/')..removeLast();
  for (final part in uri.split('/')) {
    if (part == '..') {
      segments.removeLast();
    } else if (part != '.') {
      segments.add(part);
    }
  }
  return segments.join('/');
}

/// Reachable file → the file that first imported it (null for the entry).
/// O(files + directives). Files for which [read] returns null are kept as
/// reachable but not expanded.
Map<String, String?> reachableFrom(
  String entry,
  String? Function(String path) read, {
  bool Function(String path)? stopAt,
}) {
  final parentOf = <String, String?>{entry: null};
  final pending = <String>[entry];
  while (pending.isNotEmpty) {
    final path = pending.removeLast();
    final source = read(path);
    if (source == null) continue;
    for (final target in directiveTargets(path, source)) {
      if (stopAt != null && stopAt(target)) continue;
      if (parentOf.containsKey(target)) continue;
      parentOf[target] = path;
      pending.add(target);
    }
  }
  return parentOf;
}

String chainOf(String path, Map<String, String?> parentOf) {
  final chain = <String>[path];
  for (var next = parentOf[path]; next != null; next = parentOf[next]) {
    chain.add(next);
  }
  return chain.join(' <- ');
}

String? _readLib(String path) {
  final file = File(path);
  return file.existsSync() ? file.readAsStringSync() : null;
}

bool _isDoctor(String path) => path.startsWith(_doctorRoot);

void main() {
  group('production import guard (lib/main.dart)', () {
    final patientGraph = reachableFrom(_entry, _readLib, stopAt: _isDoctor);
    final fullGraph = reachableFrom(_entry, _readLib);

    test('the walk really covers the app', () {
      // Sanity: a broken walker would "pass" by reaching nothing.
      expect(patientGraph.length, greaterThan(200));
      expect(patientGraph, contains('lib/features/home/new_home_screen.dart'));
      expect(
        patientGraph,
        contains('lib/core/maps/maps_configuration_provider_web.dart'),
        reason: 'conditional-import branches must be walked',
      );
    });

    test('no mock, fixture or demo file is reachable from patient code', () {
      final violations = [
        for (final path in patientGraph.keys)
          if (isForbiddenData(path)) chainOf(path, patientGraph),
      ];
      expect(violations, isEmpty, reason: violations.join('\n'));
    });

    test('every reachable *_static_data.dart file is on the 1c list', () {
      final unlisted = [
        for (final path in patientGraph.keys)
          if (isStaticData(path) && !toRemoveIn1c.contains(path))
            chainOf(path, patientGraph),
      ];
      expect(unlisted, isEmpty, reason: unlisted.join('\n'));
    });

    test('the 1c list has no stale entry', () {
      for (final path in toRemoveIn1c) {
        expect(
          patientGraph,
          contains(path),
          reason: '$path is no longer reachable: remove it from toRemoveIn1c',
        );
      }
    });

    test(
      'the « Dossier médical » fixture is not reachable from patient code',
      () {
        expect(
          patientGraph,
          isNot(contains(passportFixture)),
          reason: patientGraph.containsKey(passportFixture)
              ? chainOf(passportFixture, patientGraph)
              : '',
        );
      },
    );

    test('doctor-side static data is exactly the reported one', () {
      final doctorOnly = {
        for (final path in fullGraph.keys)
          if (isStaticData(path) && !patientGraph.containsKey(path)) path,
      };
      expect(
        doctorOnly,
        reportedDoctorSideStaticData,
        reason: [
          for (final path in doctorOnly) chainOf(path, fullGraph),
        ].join('\n'),
      );
    });

    test('doctor-side mock imports are exactly the reported ones', () {
      final doctorOnly = {
        for (final path in fullGraph.keys)
          if (isForbiddenData(path) && !patientGraph.containsKey(path)) path,
      };
      expect(
        doctorOnly,
        reportedDoctorSideOnly,
        reason: [
          for (final path in doctorOnly) chainOf(path, fullGraph),
        ].join('\n'),
      );
    });
  });

  group('the walker itself', () {
    // A synthetic tree proves the guard would catch a new mock import.
    const files = {
      'lib/main.dart': '''
import 'package:flutter/material.dart';
import 'package:omnicare_mobile/features/a.dart';
import 'features/doctor/shell.dart';
''',
      'lib/features/a.dart': '''
/// import 'ignored_in_comment.dart';
import 'b.dart'
    if (dart.library.io) 'b_io.dart';
export '../core/c.dart';
''',
      'lib/features/b.dart': '',
      'lib/features/b_io.dart': "import '../mock_data/mock_users.dart';",
      'lib/core/c.dart': "part 'c_part.dart';",
      'lib/core/c_part.dart': "import 'x_fixture.dart';",
      'lib/core/x_fixture.dart': '',
      'lib/mock_data/mock_users.dart': '',
      'lib/features/doctor/shell.dart':
          "import '../../demo/demo_toolbar.dart';",
      'lib/demo/demo_toolbar.dart': '',
    };

    test('follows package, relative, conditional, export and part URIs', () {
      final graph = reachableFrom('lib/main.dart', (p) => files[p]);
      expect(graph.keys, containsAll(files.keys));
      expect(
        graph.keys,
        isNot(contains('lib/features/ignored_in_comment.dart')),
      );
      expect(
        chainOf('lib/mock_data/mock_users.dart', graph),
        'lib/mock_data/mock_users.dart <- lib/features/b_io.dart '
        '<- lib/features/a.dart <- lib/main.dart',
      );
    });

    test('detects every forbidden kind and stops at the doctor boundary', () {
      final graph = reachableFrom(
        'lib/main.dart',
        (p) => files[p],
        stopAt: _isDoctor,
      );
      expect(graph.keys.where(isForbiddenData).toSet(), {
        'lib/mock_data/mock_users.dart',
        'lib/core/x_fixture.dart',
      });
      expect(graph, isNot(contains('lib/demo/demo_toolbar.dart')));
      expect(
        isForbiddenData('lib/features/x/patient_appointment_mock_data.dart'),
        isTrue,
      );
      expect(isForbiddenData('lib/demo/anything.dart'), isTrue);
      expect(
        isStaticData('lib/features/home/new_home_static_data.dart'),
        isTrue,
      );
    });
  });
}
