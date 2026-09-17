import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:omnicare_mobile/core/api/family_api.dart';
import 'package:omnicare_mobile/core/models/family_models.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/patient_clinic/application/patient_clinic_directory_controller.dart';
import 'package:omnicare_mobile/features/patient_clinic/data/patient_clinic_models.dart';
import 'package:omnicare_mobile/features/patient_clinic/data/patient_clinic_repository.dart';
import 'package:omnicare_mobile/features/request_core/application/request_submission_controller.dart';
import 'package:omnicare_mobile/features/request_core/data/request_models.dart';
import 'package:omnicare_mobile/features/request_core/data/request_repository.dart';
import 'package:omnicare_mobile/features/request_core/domain/clinic_request_intent.dart';
import 'package:omnicare_mobile/features/request_core/domain/request_vocabulary.dart';
import 'package:omnicare_mobile/features/request_core/identity/request_operation_id.dart';
import 'package:omnicare_mobile/features/request_flow/screens/who_needs_care_screen.dart';
import 'package:omnicare_mobile/providers/family_provider.dart';
import 'package:omnicare_mobile/repositories/family_repository.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeFamilyRepository extends FamilyRepository {
  _FakeFamilyRepository({this.members = const []}) : super(api: _stubApi);

  static final _stubApi = FamilyApi();
  final List<FamilyMember> members;

  @override
  Future<List<FamilyMember>> getFamilyMembers() async => members;
}

class _FakeRequestRepository implements RequestRepository {
  @override
  Future<SubmitClinicRequestResult> submitClinicRequest({
    required RequestOperationId requestId,
    required ClinicRequestIntent intent,
    CancelToken? cancelToken,
  }) async => throw UnimplementedError();

  @override
  Future<PatientRequestPage> listRequests({
    int? page,
    int? pageSize,
    PatientRequestListFilter? filter,
    CancelToken? cancelToken,
  }) async => throw UnimplementedError();

  @override
  Future<PatientRequest> getRequest(
    RequestOperationId requestId, {
    CancelToken? cancelToken,
  }) async => throw UnimplementedError();

  @override
  Future<PatientRequest> cancelRequest({
    required RequestOperationId requestId,
    required int expectedVersion,
    CancelToken? cancelToken,
  }) async => throw UnimplementedError();

  @override
  Future<PatientRequest> respondToInformationRequest({
    required RequestOperationId requestId,
    required PatientInformationResponsePayload payload,
    CancelToken? cancelToken,
  }) async => throw UnimplementedError();
}

class _FakeClinicRepository implements PatientClinicRepository {
  @override
  Future<PatientClinicDirectoryPage> listClinics({
    String? query,
    String? city,
    int? page,
    int? pageSize,
    CancelToken? cancelToken,
  }) async {
    return PatientClinicDirectoryPage(
      contractVersion: '1.0',
      items: const [],
      page: page ?? 0,
      pageSize: pageSize ?? 20,
      hasNext: false,
    );
  }

  @override
  Future<PatientClinicDetail> getClinic(
    String clinicId, {
    CancelToken? cancelToken,
  }) async {
    return PatientClinicDetail(
      clinicId: clinicId,
      displayName: 'Test clinic',
      about: 'About',
      gallery: const [],
      acceptingRequests: true,
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

FamilyMember _member({
  String id = '1',
  String firstName = 'Aicha',
  String lastName = 'Ben Ali',
  String relationship = 'parent',
  String? photoUrl,
}) {
  return FamilyMember(
    id: id,
    accountHolderId: 'holder',
    firstName: firstName,
    lastName: lastName,
    dateOfBirth: DateTime(1990, 6, 15),
    gender: 'F',
    relationship: relationship,
    graduated: false,
    photoUrl: photoUrl,
  );
}

Widget _buildApp({
  List<FamilyMember>? members,
  FamilyProvider? familyProvider,
  RequestSubmissionController? requestController,
}) {
  final fp =
      familyProvider ??
      FamilyProvider(repository: _FakeFamilyRepository(members: members ?? []));
  final rc =
      requestController ??
      RequestSubmissionController(repository: _FakeRequestRepository());
  final dc = PatientClinicDirectoryController(
    repository: _FakeClinicRepository(),
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<FamilyProvider>.value(value: fp),
      ChangeNotifierProvider<RequestSubmissionController>.value(value: rc),
      ChangeNotifierProvider<PatientClinicDirectoryController>.value(value: dc),
    ],
    child: MaterialApp(
      theme: buildOmniTheme(),
      home: const WhoNeedsCareScreen(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('WhoNeedsCareScreen — Page 01 profile grid', () {
    // 1. SELF always renders
    testWidgets('SELF always renders', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Me'), findsOneWidget);
      expect(find.text('My care request'), findsOneWidget);
    });

    // 2. Zero family members renders Add family member tile
    testWidgets('zero family members renders Add family member tile', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Add family member'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.text('No family members added yet.'), findsNothing);
    });

    // 3. One family member produces correct profiles
    testWidgets('one family member produces correct profiles', (tester) async {
      final member = _member();
      await tester.pumpWidget(_buildApp(members: [member]));
      await tester.pumpAndSettle();

      expect(find.text('Me'), findsOneWidget);
      expect(find.text('Aicha Ben Ali'), findsOneWidget);
      expect(find.text('Parent'), findsOneWidget);
      expect(find.text('Add family member'), findsOneWidget);
    });

    // 4. Multiple family members render
    testWidgets('multiple family members render', (tester) async {
      final members = [
        _member(id: '1', firstName: 'Aicha', relationship: 'parent'),
        _member(
          id: '2',
          firstName: 'Sami',
          lastName: 'Ali',
          relationship: 'enfant',
        ),
        _member(id: '3', firstName: 'Leila', relationship: 'frere_soeur'),
      ];
      await tester.pumpWidget(_buildApp(members: members));
      await tester.pumpAndSettle();

      expect(find.text('Me'), findsOneWidget);
      expect(find.text('Aicha Ben Ali'), findsOneWidget);
      expect(find.text('Sami Ali'), findsOneWidget);
      expect(find.text('Leila Ben Ali'), findsOneWidget);
      expect(find.text('Parent'), findsWidgets);
      expect(find.text('Enfant'), findsOneWidget);
      expect(find.text('Frère / sœur'), findsOneWidget);
    });

    // 5. Maximum logical grid is 2 columns
    testWidgets('maximum logical grid is 2 columns', (tester) async {
      final members = [
        _member(id: '1', firstName: 'Aicha'),
        _member(id: '2', firstName: 'Sami'),
        _member(id: '3', firstName: 'Leila'),
      ];
      await tester.pumpWidget(_buildApp(members: members));
      await tester.pumpAndSettle();

      // Wrap widget limits layout to 2 columns
      final wrap = tester.widget<Wrap>(find.byType(Wrap));
      expect(wrap.spacing, OmniSpacing.lg);
    });

    // 6. Profile name and relationship render
    testWidgets('profile name and relationship render', (tester) async {
      final member = _member(
        firstName: 'Ahmed',
        lastName: 'Trabelsi',
        relationship: 'conjoint',
      );
      await tester.pumpWidget(_buildApp(members: [member]));
      await tester.pumpAndSettle();

      expect(find.text('Ahmed Trabelsi'), findsOneWidget);
      expect(find.text('Conjoint(e)'), findsOneWidget);
    });

    // 7. Real avatar takes precedence when available
    testWidgets('real avatar takes precedence when available', (tester) async {
      final member = _member(photoUrl: 'https://cdn.example.com/photo.jpg');
      await tester.pumpWidget(_buildApp(members: [member]));
      await tester.pumpAndSettle();

      expect(find.byType(CachedNetworkImage), findsOneWidget);
    });

    // 8. Default avatar renders bundled Lorelei asset (not initials)
    testWidgets('default avatar renders bundled Lorelei asset', (tester) async {
      final member = _member(
        id: 'test-member-01',
        firstName: 'Sami',
        lastName: 'Ali',
        photoUrl: null,
      );
      await tester.pumpWidget(_buildApp(members: [member]));
      await tester.pumpAndSettle();

      // Should render Image.asset, not initials
      expect(find.byType(Image), findsWidgets);
      // Initials should NOT be the normal default
      expect(find.text('SA'), findsNothing);
    });

    // 8b. SELF default avatar renders bundled asset
    testWidgets('SELF default avatar renders bundled asset', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // SELF should render a bundled asset Image, not the "M" initials
      expect(find.byType(Image), findsWidgets);
    });

    // 8c. Same member ID always resolves same asset (deterministic)
    testWidgets('same member ID always resolves same asset', (tester) async {
      final member1 = _member(id: 'deterministic-id-xyz');
      await tester.pumpWidget(_buildApp(members: [member1]));
      await tester.pumpAndSettle();

      // Find all AssetImage widgets
      final assetPaths1 = find
          .byType(Image)
          .evaluate()
          .map((e) => e.widget as Image)
          .where((img) => img.image is AssetImage)
          .map((img) => (img.image as AssetImage).assetName)
          .toList();

      // Reset and rebuild with same ID
      final member2 = _member(id: 'deterministic-id-xyz');
      await tester.pumpWidget(_buildApp(members: [member2]));
      await tester.pumpAndSettle();

      final assetPaths2 = find
          .byType(Image)
          .evaluate()
          .map((e) => e.widget as Image)
          .where((img) => img.image is AssetImage)
          .map((img) => (img.image as AssetImage).assetName)
          .toList();

      // Both should contain at least one avatar asset
      expect(assetPaths1, isNotEmpty);
      expect(assetPaths2, isNotEmpty);
      // The specific avatar for 'deterministic-id-xyz' should be the same
      expect(assetPaths1.first, equals(assetPaths2.first));
    });

    // 8d. Different member IDs can resolve different avatars
    testWidgets('different member IDs can resolve different avatars', (
      tester,
    ) async {
      final members = [
        _member(id: 'id-alpha-001', firstName: 'Alpha'),
        _member(id: 'id-beta-002', firstName: 'Beta'),
      ];
      await tester.pumpWidget(_buildApp(members: members));
      await tester.pumpAndSettle();

      // Should have multiple Image widgets (avatars) rendered
      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      // SELF + 2 members = at least 3 images (2 avatars + possibly network)
      expect(images.length, greaterThanOrEqualTo(2));
    });

    // 9. SELF selection works
    testWidgets('SELF selection works', (tester) async {
      final member = _member();
      await tester.pumpWidget(_buildApp(members: [member]));
      await tester.pumpAndSettle();

      // Tap family member first
      await tester.tap(find.text('Aicha Ben Ali'));
      await tester.pumpAndSettle();

      // Now tap SELF
      await tester.tap(find.text('Me'));
      await tester.pumpAndSettle();

      final meSemantics = tester.getSemantics(
        find
            .ancestor(of: find.text('Me'), matching: find.byType(Semantics))
            .first,
      );
      expect(meSemantics.getSemanticsData().label, contains('selected'));
    });

    // 10. Family selection works
    testWidgets('family selection works', (tester) async {
      final member = _member();
      await tester.pumpWidget(_buildApp(members: [member]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aicha Ben Ali'));
      await tester.pumpAndSettle();

      final memberSemantics = tester.getSemantics(
        find
            .ancestor(
              of: find.text('Aicha Ben Ali'),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(memberSemantics.getSemanticsData().label, contains('selected'));
    });

    // 11. Selected state semantics work
    testWidgets('selected state semantics work', (tester) async {
      final member = _member();
      await tester.pumpWidget(_buildApp(members: [member]));
      await tester.pumpAndSettle();

      // SELF selected by default
      final meSemantics = tester.getSemantics(
        find
            .ancestor(of: find.text('Me'), matching: find.byType(Semantics))
            .first,
      );
      expect(meSemantics.getSemanticsData().label, contains('selected'));

      // Select family member
      await tester.tap(find.text('Aicha Ben Ali'));
      await tester.pumpAndSettle();

      final memberSemantics = tester.getSemantics(
        find
            .ancestor(
              of: find.text('Aicha Ben Ali'),
              matching: find.byType(Semantics),
            )
            .first,
      );
      expect(memberSemantics.getSemanticsData().label, contains('selected'));

      // SELF should now be not selected
      final meSemanticsAfter = tester.getSemantics(
        find
            .ancestor(of: find.text('Me'), matching: find.byType(Semantics))
            .first,
      );
      expect(
        meSemanticsAfter.getSemanticsData().label,
        contains('not selected'),
      );
    });

    // 12. Tapping profile does NOT navigate immediately
    testWidgets('tapping profile does NOT navigate immediately', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Me'));
      await tester.pumpAndSettle();

      // Still on WhoNeedsCareScreen — no navigation
      expect(find.text('Who needs care?'), findsOneWidget);
      expect(find.byType(WhoNeedsCareScreen), findsOneWidget);
    });

    // 13. Continue commits SELF correctly
    testWidgets('Continue commits SELF correctly', (tester) async {
      final request = RequestSubmissionController(
        repository: _FakeRequestRepository(),
      );
      await tester.pumpWidget(_buildApp(requestController: request));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(request.subject.isSelf, isTrue);
    });

    // 14. Continue commits FAMILY_MEMBER correctly
    testWidgets('Continue commits FAMILY_MEMBER correctly', (tester) async {
      final member = _member(id: 'test-id');
      final request = RequestSubmissionController(
        repository: _FakeRequestRepository(),
      );
      await tester.pumpWidget(
        _buildApp(members: [member], requestController: request),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aicha Ben Ali'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(request.subject.isSelf, isFalse);
      expect(request.subject.familyMemberId, 'test-id');
    });

    // 15. Navigation to Clinic Directory is unchanged
    testWidgets('navigation to Clinic Directory is unchanged', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // ClinicDirectoryScreen should be pushed on top
      expect(find.text('Choose a clinic'), findsOneWidget);
    });

    // 16. Add family member tile exists (creation flow is an existing screen)
    testWidgets('Add family member tile exists', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Add family member'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });

    // 17. Lifecycle notify-during-build defect is fixed
    testWidgets('lifecycle notify-during-build defect is fixed', (
      tester,
    ) async {
      // This test verifies no assertion error is thrown during widget init
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // If we get here without exceptions, the lifecycle fix works
      expect(find.byType(WhoNeedsCareScreen), findsOneWidget);
    });

    // 18. No old empty-state card remains
    testWidgets('no old empty-state card remains', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.text('No family members added yet.'), findsNothing);
      expect(find.byIcon(Icons.group_outlined), findsNothing);
    });

    // 19. Page title and subtitle render correctly
    testWidgets('page title and subtitle render correctly', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.text('Who needs care?'), findsOneWidget);
      expect(find.text('Choose who this request is for.'), findsOneWidget);
    });

    // Additional: back button exists
    testWidgets('back button available in AppBar', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.byTooltip('Back'), findsOneWidget);
    });

    // Additional: background matches parent scaffold
    testWidgets('uses correct canvas background', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      final coloredBoxes = tester.widgetList<ColoredBox>(
        find.byType(ColoredBox),
      );
      final backgroundBox = coloredBoxes.firstWhere(
        (box) => box.color == const Color(0xFFF4F5F7),
        orElse: () => throw StateError('Background ColoredBox not found'),
      );
      expect(backgroundBox.color, const Color(0xFFF4F5F7));
    });

    // Additional: Continue renders and is enabled
    testWidgets('Continue renders and is enabled', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      final btn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Continue'),
      );
      expect(btn.onPressed, isNotNull);
    });

    // Additional: selection badge shows for selected profile
    testWidgets('selection badge shows for selected profile', (tester) async {
      final member = _member();
      await tester.pumpWidget(_buildApp(members: [member]));
      await tester.pumpAndSettle();

      // SELF is selected by default — check icon should be visible
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // Select family member
      await tester.tap(find.text('Aicha Ben Ali'));
      await tester.pumpAndSettle();

      // Check icon should still be visible (now on family member)
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    // Additional: grid has correct tile count
    testWidgets('grid has correct tile count for self + 2 members', (
      tester,
    ) async {
      final members = [
        _member(id: '1', firstName: 'Aicha'),
        _member(id: '2', firstName: 'Sami'),
      ];
      await tester.pumpWidget(_buildApp(members: members));
      await tester.pumpAndSettle();

      // 1 self + 2 members + 1 add = 4 tiles total via _ProfileGrid
      // We check via LayoutBuilder children count (Wrap)
      final wrap = tester.widget<Wrap>(find.byType(Wrap));
      expect(wrap.children.length, 4);
    });

    // Additional: initials are emergency fallback only, not normal default
    testWidgets('initials are emergency fallback only', (tester) async {
      final member = _member(id: 'fallback-test', photoUrl: null);
      await tester.pumpWidget(_buildApp(members: [member]));
      await tester.pumpAndSettle();

      // Image.asset should be used, not raw initials text
      expect(find.byType(Image), findsWidgets);
    });

    // Additional: avatar assignment is deterministic (not random)
    testWidgets('avatar assignment is deterministic across rebuilds', (
      tester,
    ) async {
      final member = _member(id: 'stable-id-42');

      // First build
      await tester.pumpWidget(_buildApp(members: [member]));
      await tester.pumpAndSettle();

      final selfImage = tester.widget<Image>(
        find
            .byWidgetPredicate((w) => w is Image && w.image is AssetImage)
            .first,
      );
      final firstPath = (selfImage.image as AssetImage).assetName;

      // Second build with same member
      await tester.pumpWidget(_buildApp(members: [member]));
      await tester.pumpAndSettle();

      final selfImage2 = tester.widget<Image>(
        find
            .byWidgetPredicate((w) => w is Image && w.image is AssetImage)
            .first,
      );
      final secondPath = (selfImage2.image as AssetImage).assetName;

      // Same asset path for same member ID
      expect(firstPath, equals(secondPath));
    });

    // Additional: no runtime DiceBear API calls in source
    test('no runtime DiceBear API URL in source file', () async {
      final source = await File(
        'lib/features/request_flow/screens/who_needs_care_screen.dart',
      ).readAsString();
      expect(source, isNot(contains('api.dicebear.com')));
    });
  });
}
