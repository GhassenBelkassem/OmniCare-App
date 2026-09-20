import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/api/account_api.dart';
import 'package:omnicare_mobile/core/api/documents_api.dart';
import 'package:omnicare_mobile/core/models/patient_profile.dart';
import 'package:omnicare_mobile/features/profile/medical_documents_screen.dart';
import 'package:omnicare_mobile/providers/user_onboarding_provider.dart';
import 'package:provider/provider.dart';

const _patientId = '22222222-2222-2222-2222-222222222222';

PatientProfile _profile() => const PatientProfile(
  patientId: _patientId,
  userId: 'user',
  firstName: 'A',
  lastName: 'B',
  displayName: 'A B',
  dateOfBirth: null,
  gender: null,
  photoUrl: null,
  primaryPhone: null,
  primaryEmail: null,
  onboardingCompleted: true,
  onboardingStep: 3,
  preferredLanguage: 'en',
  notifications: ProfileNotificationPreferences(
    medications: true,
    appointments: true,
    passport: true,
  ),
  updatedAt: null,
);

MedicalDocumentRecord _record(String status) => MedicalDocumentRecord(
  id: '11111111-1111-1111-1111-111111111111',
  patientId: _patientId,
  documentType: 'LAB_RESULT',
  status: status,
  createdAt: DateTime(2026, 8, 24),
);

class _AccountApi extends AccountApi {
  @override
  Future<PatientProfile> getPatientProfile() async => _profile();
}

class _DocumentsApi extends DocumentsApi {
  _DocumentsApi(this.statuses, {this.initiallyEmpty = false});
  final List<String> statuses;
  final bool initiallyEmpty;
  final List<String> listedPatientIds = [];
  final List<String> uploadKeys = [];
  int statusCalls = 0;

  @override
  Future<MedicalDocumentPage> listDocuments(String patientId) async {
    listedPatientIds.add(patientId);
    if (initiallyEmpty) return const MedicalDocumentPage(documents: []);
    final index = statusCalls.clamp(0, statuses.length - 1);
    return MedicalDocumentPage(documents: [_record(statuses[index])]);
  }

  @override
  Future<MedicalDocumentRecord> getStatus({
    required String patientId,
    required String documentId,
  }) async {
    statusCalls++;
    final index = statusCalls.clamp(1, statuses.length - 1);
    return _record(statuses[index]);
  }

  @override
  Future<MedicalDocumentRecord> upload(
    DocumentUploadOperation operation,
  ) async {
    uploadKeys.add(operation.idempotencyKey);
    return _record('SCAN_PENDING');
  }
}

Widget _app(
  _DocumentsApi api, {
  Future<PlatformFile?> Function()? pickDocumentFile,
}) => ChangeNotifierProvider(
  create: (_) => UserOnboardingProvider(),
  child: MaterialApp(
    home: MedicalDocumentsScreen(
      documentsApi: api,
      accountApi: _AccountApi(),
      pickDocumentFile: pickDocumentFile,
      pollDelay: const Duration(milliseconds: 10),
      maximumPolls: 5,
    ),
  ),
);

void main() {
  testWidgets('add dialog separates file selection from upload submission', (
    tester,
  ) async {
    final api = _DocumentsApi(['AVAILABLE']);
    await tester.pumpWidget(_app(api));
    await tester.pump();

    await tester.tap(find.text('Add Document'));
    await tester.pumpAndSettle();

    expect(find.text('Choose File'), findsOneWidget);
    expect(find.text('Submit'), findsOneWidget);
  });

  testWidgets('accepted upload immediately appears once with returned status', (
    tester,
  ) async {
    final api = _DocumentsApi([
      'SCAN_PENDING',
      'SCAN_PENDING',
    ], initiallyEmpty: true);
    await tester.pumpWidget(
      _app(
        api,
        pickDocumentFile: () async => PlatformFile(
          name: 'document.pdf',
          size: 4,
          bytes: Uint8List.fromList([1, 2, 3, 4]),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Add Document'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Laboratory result');
    await tester.tap(find.text('Choose File'));
    await tester.pump();
    expect(find.text('File selected'), findsOneWidget);

    await tester.tap(find.text('Submit'));
    await tester.pump();
    await tester.pump();

    expect(api.uploadKeys, hasLength(1));
    expect(find.text('LAB_RESULT'), findsOneWidget);
    expect(find.textContaining('SCAN_PENDING'), findsWidgets);
  });

  testWidgets(
    'authenticated profile supplies operational patient ID and pending starts polling',
    (tester) async {
      final api = _DocumentsApi(['SCAN_PENDING', 'AVAILABLE']);
      await tester.pumpWidget(_app(api));
      await tester.pump();
      expect(api.listedPatientIds, [_patientId]);
      expect(
        find.byType(TextField),
        findsNothing,
        reason: 'No patient ID override control exists.',
      );
      await tester.pump(const Duration(milliseconds: 11));
      expect(api.statusCalls, 1);
    },
  );

  testWidgets('polling stops for AVAILABLE', (tester) async {
    final api = _DocumentsApi(['SCAN_PENDING', 'AVAILABLE']);
    await tester.pumpWidget(_app(api));
    await tester.pump(const Duration(milliseconds: 30));
    final calls = api.statusCalls;
    await tester.pump(const Duration(milliseconds: 100));
    expect(api.statusCalls, calls);
    expect(find.textContaining('AVAILABLE'), findsOneWidget);
  });

  testWidgets('polling stops for SCAN_FAILED', (tester) async {
    final api = _DocumentsApi(['SCAN_PENDING', 'SCAN_FAILED']);
    await tester.pumpWidget(_app(api));
    await tester.pump(const Duration(milliseconds: 30));
    final calls = api.statusCalls;
    await tester.pump(const Duration(milliseconds: 100));
    expect(api.statusCalls, calls);
    expect(find.textContaining('SCAN_FAILED'), findsOneWidget);
  });

  testWidgets('polling is cleaned up when component is destroyed', (
    tester,
  ) async {
    final api = _DocumentsApi(['SCAN_PENDING', 'SCAN_PENDING']);
    await tester.pumpWidget(_app(api));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(api.statusCalls, 0);
  });
}
