import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('production legacy API call sites use the bootstrap shared client', () {
    final paths = <String>[
      'lib/features/onboarding/conversational_onboarding_screen.dart',
      'lib/features/home/new_home_screen.dart',
      'lib/features/doctor/request_accepted_screen.dart',
      'lib/features/doctor/doctor_dashboard_screen.dart',
      'lib/features/home/consultation_detail_screen.dart',
    ];

    for (final path in paths) {
      final text = source(path);
      expect(text, isNot(contains('AccountApi()')), reason: path);
      expect(text, isNot(contains('FamilyApi()')), reason: path);
      expect(text, isNot(contains('FilesApi()')), reason: path);
    }

    final main = source('lib/main.dart');
    expect(main, contains('Provider<AppHttpClient>.value'));
    expect(
      main,
      contains('accountApi: AccountApi(httpClient: resolvedHttpClient)'),
    );
    expect(
      main,
      contains(
        'final documentsApi = DocumentsApi(httpClient: resolvedHttpClient)',
      ),
    );
    expect(main, contains('MedicalDocumentUploadController('));
    expect(main, contains('uploadController: context'));
  });

  test('document recovery receipt is opaque and production-owned', () {
    final recovery = source(
      'lib/features/profile/medical_document_upload_controller.dart',
    );
    final main = source('lib/main.dart');

    expect(recovery, contains("'accountScope'"));
    expect(recovery, contains("'patientId'"));
    expect(recovery, contains("'operationKey'"));
    expect(recovery, contains("'createdAt'"));
    expect(recovery, isNot(contains("'filename'")));
    expect(recovery, isNot(contains("'filePath'")));
    expect(recovery, isNot(contains("'fileBytes'")));
    expect(recovery, isNot(contains("'accessToken'")));
    expect(recovery, isNot(contains("'refreshToken'")));
    expect(main, contains('SecureMedicalDocumentUploadReceiptStore()'));
    expect(main, contains('authController: authController'));
  });

  test('production library creates Dio only in the shared client', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final relative = entity.path.replaceFirst(
        '${Directory.current.path}/',
        '',
      );
      if (relative == 'lib/core/network/app_http_client.dart' ||
          relative == 'lib/main_demo.dart') {
        continue;
      }
      if (RegExp(r'\bDio\s*\(').hasMatch(entity.readAsStringSync())) {
        offenders.add(relative);
      }
    }

    expect(offenders, isEmpty);
  });

  test('multipart owners explicitly prohibit interceptor replay', () {
    final documents = source('lib/core/api/documents_api.dart');
    final avatars = source('lib/core/api/files_api.dart');

    expect(
      documents,
      contains('requestReplayExtra(RequestReplayPolicy.never)'),
    );
    expect(avatars, contains('requestReplayExtra(RequestReplayPolicy.never)'));
  });
}
