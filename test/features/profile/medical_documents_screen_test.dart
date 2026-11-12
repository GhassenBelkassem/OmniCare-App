import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/api/account_api.dart';
import 'package:omnicare_mobile/core/api/documents_api.dart';
import 'package:omnicare_mobile/core/models/patient_profile.dart';
import 'package:omnicare_mobile/features/profile/medical_documents_screen.dart';
import 'package:omnicare_mobile/features/profile/medical_document_upload_controller.dart';
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
  _DocumentsApi(
    this.statuses, {
    this.initiallyEmpty = false,
    this.waitForUploadCancellation = false,
  });
  final List<String> statuses;
  final bool initiallyEmpty;
  final bool waitForUploadCancellation;
  final List<String> listedPatientIds = [];
  final List<String> uploadKeys = [];
  DocumentUploadOperation? lastUploadOperation;
  CancelToken? lastUploadCancelToken;
  int statusCalls = 0;
  int recoveryCalls = 0;

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
    DocumentUploadOperation operation, {
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    void Function()? onRequestDispatched,
  }) async {
    uploadKeys.add(operation.idempotencyKey);
    lastUploadOperation = operation;
    lastUploadCancelToken = cancelToken;
    onRequestDispatched?.call();
    onSendProgress?.call(5, 10);
    if (waitForUploadCancellation) {
      throw await cancelToken!.whenCancel;
    }
    return _record('SCAN_PENDING');
  }

  @override
  Future<DocumentUploadRecoveryResult> recoverUpload({
    required String patientId,
    required String idempotencyKey,
  }) async {
    recoveryCalls++;
    return DocumentUploadRecoveryResult(
      state: DocumentUploadRecoveryState.inProgress,
      document: _record('SCAN_PENDING'),
    );
  }

  @override
  Stream<DocumentStatusEvent> watchDocumentStatus({
    required String patientId,
    required String documentId,
    String? lastEventId,
  }) => const Stream<DocumentStatusEvent>.empty();
}

class _ReceiptStore implements MedicalDocumentUploadReceiptStore {
  MedicalDocumentUploadReceipt? receipt;

  @override
  Future<void> save(MedicalDocumentUploadReceipt value) async {
    receipt = value;
  }

  @override
  Future<MedicalDocumentUploadReceipt?> readForAccount(String accountId) async {
    return receipt?.accountId == accountId ? receipt : null;
  }

  @override
  Future<void> clearIfMatches(MedicalDocumentUploadReceipt value) async {
    if (receipt?.accountId == value.accountId &&
        receipt?.idempotencyKey == value.idempotencyKey) {
      receipt = null;
    }
  }

  @override
  Future<void> clearForAccount(String accountId) async {
    if (receipt?.accountId == accountId) receipt = null;
  }
}

MedicalDocumentUploadController _uploadController(_DocumentsApi api) =>
    MedicalDocumentUploadController(api: api, receiptStore: _ReceiptStore());

Widget _app(
  _DocumentsApi api, {
  Future<PlatformFile?> Function()? pickDocumentFile,
}) => ChangeNotifierProvider(
  create: (_) => UserOnboardingProvider(),
  child: MaterialApp(
    home: MedicalDocumentsScreen(
      uploadController: _uploadController(api),
      accountApi: _AccountApi(),
      initialAccountId: 'account-1',
      pickDocumentFile: pickDocumentFile,
      pollDelay: const Duration(milliseconds: 10),
      maximumPolls: 5,
    ),
  ),
);

Widget _ownedApp(
  _DocumentsApi api, {
  required String owner,
  Future<PlatformFile?> Function()? pickDocumentFile,
}) => ChangeNotifierProvider(
  create: (_) => UserOnboardingProvider(),
  child: MaterialApp(
    home: MedicalDocumentsScreen(
      key: const ValueKey('medical-documents'),
      uploadController: _uploadController(api),
      accountApi: _AccountApi(),
      initialAccountId: 'account-$owner',
      initialPatientId: owner,
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
    expect(find.text('document.pdf'), findsOneWidget);

    await tester.tap(find.text('Submit'));
    await tester.pump();
    await tester.pump();

    expect(api.uploadKeys, hasLength(1));
    expect(find.text('LAB_RESULT'), findsOneWidget);
    expect(find.textContaining('SCAN_PENDING'), findsWidgets);
  });

  testWidgets('native upload keeps a file path instead of buffering bytes', (
    tester,
  ) async {
    final api = _DocumentsApi(['SCAN_PENDING'], initiallyEmpty: true);
    await tester.pumpWidget(
      _app(
        api,
        pickDocumentFile: () async => PlatformFile(
          name: 'document.pdf',
          size: 4,
          path: '/tmp/document.pdf',
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Add Document'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Path based document');
    await tester.tap(find.text('Choose File'));
    await tester.pump();
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(api.lastUploadOperation!.filePath, '/tmp/document.pdf');
    expect(api.lastUploadOperation!.bytes, isNull);
    expect(api.lastUploadOperation!.fileSizeBytes, 4);
  });

  testWidgets('oversized file is rejected before an upload operation exists', (
    tester,
  ) async {
    final api = _DocumentsApi(['AVAILABLE'], initiallyEmpty: true);
    await tester.pumpWidget(
      _app(
        api,
        pickDocumentFile: () async => PlatformFile(
          name: 'too-large.pdf',
          size: DocumentsApi.maximumUploadBytes + 1,
          path: '/tmp/too-large.pdf',
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Add Document'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose File'));
    await tester.pump();

    expect(find.textContaining('larger than the 20 MB limit'), findsOneWidget);
    expect(api.uploadKeys, isEmpty);
    expect(api.lastUploadOperation, isNull);
  });

  testWidgets('cancel after dispatch recovers before any multipart resend', (
    tester,
  ) async {
    final api = _DocumentsApi(
      ['SCAN_PENDING'],
      initiallyEmpty: true,
      waitForUploadCancellation: true,
    );
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
    await tester.enterText(find.byType(TextField), 'Cancelable document');
    await tester.tap(find.text('Choose File'));
    await tester.pump();
    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(find.text('Uploading 50%'), findsOneWidget);
    expect(find.text('Cancel upload'), findsOneWidget);

    await tester.tap(find.text('Cancel upload'));
    await tester.pumpAndSettle();

    expect(api.lastUploadCancelToken!.isCancelled, isTrue);
    expect(api.uploadKeys, hasLength(1));
    expect(api.recoveryCalls, 1);
    expect(find.textContaining('SCAN_PENDING'), findsWidgets);
  });

  testWidgets('disposing the screen cancels an active local upload', (
    tester,
  ) async {
    final api = _DocumentsApi(
      ['SCAN_PENDING'],
      initiallyEmpty: true,
      waitForUploadCancellation: true,
    );
    await tester.pumpWidget(
      _app(
        api,
        pickDocumentFile: () async => PlatformFile(
          name: 'document.pdf',
          size: 1,
          bytes: Uint8List.fromList([1]),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Add Document'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Disposable upload');
    await tester.tap(find.text('Choose File'));
    await tester.pump();
    await tester.tap(find.text('Submit'));
    await tester.pump();

    final token = api.lastUploadCancelToken!;
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();

    expect(token.isCancelled, isTrue);
  });

  testWidgets('account owner change cancels and clears active upload state', (
    tester,
  ) async {
    final api = _DocumentsApi(
      ['SCAN_PENDING'],
      initiallyEmpty: true,
      waitForUploadCancellation: true,
    );
    Future<PlatformFile?> picker() async => PlatformFile(
      name: 'document.pdf',
      size: 1,
      bytes: Uint8List.fromList([1]),
    );
    await tester.pumpWidget(
      _ownedApp(api, owner: 'patient-owner-1', pickDocumentFile: picker),
    );
    await tester.pump();
    await tester.tap(find.text('Add Document'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Owner scoped upload');
    await tester.tap(find.text('Choose File'));
    await tester.pump();
    await tester.tap(find.text('Submit'));
    await tester.pump();

    final token = api.lastUploadCancelToken!;
    await tester.pumpWidget(
      _ownedApp(api, owner: 'patient-owner-2', pickDocumentFile: picker),
    );
    await tester.pump();

    expect(token.isCancelled, isTrue);
    expect(api.listedPatientIds, contains('patient-owner-2'));
  });

  testWidgets(
    'authenticated profile supplies patient ID without watching old pending work',
    (tester) async {
      final api = _DocumentsApi(['SCAN_PENDING', 'AVAILABLE']);
      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();
      expect(api.listedPatientIds, [_patientId]);
      expect(
        find.byType(TextField),
        findsNothing,
        reason: 'No patient ID override control exists.',
      );
      expect(api.statusCalls, 0);
    },
  );

  testWidgets('initial AVAILABLE status renders without polling', (
    tester,
  ) async {
    final api = _DocumentsApi(['AVAILABLE']);
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();
    expect(api.statusCalls, 0);
    expect(find.textContaining('AVAILABLE'), findsOneWidget);
  });

  testWidgets('initial SCAN_FAILED status renders without polling', (
    tester,
  ) async {
    final api = _DocumentsApi(['SCAN_FAILED']);
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();
    expect(api.statusCalls, 0);
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
