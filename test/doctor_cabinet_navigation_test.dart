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
import 'package:omnicare_mobile/features/patient_clinic/presentation/clinic_directory_screen.dart';
import 'package:omnicare_mobile/features/patient_doctor/presentation/doctor_directory_screen.dart';
import 'package:omnicare_mobile/features/request_core/application/request_submission_controller.dart';
import 'package:omnicare_mobile/features/request_core/data/request_models.dart';
import 'package:omnicare_mobile/features/request_core/data/request_repository.dart';
import 'package:omnicare_mobile/features/request_core/domain/clinic_request_intent.dart';
import 'package:omnicare_mobile/features/request_core/domain/request_vocabulary.dart';
import 'package:omnicare_mobile/features/request_core/identity/request_operation_id.dart';
import 'package:omnicare_mobile/features/patient_doctor/application/doctor_directory_controller.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_directory_models.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_directory_repository.dart';
import 'package:omnicare_mobile/features/request_flow/screens/who_needs_care_screen.dart';
import 'package:omnicare_mobile/features/request_flow/screens/doctor_cabinet_entry_screen.dart';
import 'package:omnicare_mobile/features/scheduled_care_prototype/scheduled_care_controller.dart';
import 'package:omnicare_mobile/features/scheduled_care_prototype/scheduled_care_models.dart';
import 'package:omnicare_mobile/providers/family_provider.dart';
import 'package:omnicare_mobile/repositories/family_repository.dart';

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

class _FakeDoctorRepository implements DoctorDirectoryRepository {
  _FakeDoctorRepository({List<DoctorSearchCard> doctors = const []})
    : doctors = List.unmodifiable(doctors);

  final List<DoctorSearchCard> doctors;
  final List<DoctorSearchCriteria> criteria = [];

  @override
  Future<DoctorSearchPage> searchDoctors({
    required DoctorSearchCriteria criteria,
    CancelToken? cancelToken,
  }) async {
    this.criteria.add(criteria);
    return DoctorSearchPage(
      content: doctors,
      page: criteria.page,
      size: criteria.size,
      hasNext: false,
    );
  }

  @override
  Future<DoctorDirectoryDetail> getDoctor(
    String doctorId, {
    CancelToken? cancelToken,
  }) async => throw UnimplementedError();

  @override
  Future<List<AvailabilitySlotDto>> getSlots({
    required String doctorId,
    required String practiceLocationId,
    required DateTime from,
    required DateTime to,
    CancelToken? cancelToken,
  }) async => const [];
}

class _FakeClinicRepository implements PatientClinicRepository {
  @override
  Future<PatientClinicDirectoryPage> listClinics({
    String? query,
    String? city,
    int? page,
    int? pageSize,
    CancelToken? cancelToken,
  }) async => PatientClinicDirectoryPage(
    contractVersion: '1.0',
    items: const [],
    page: page ?? 0,
    pageSize: pageSize ?? 20,
    hasNext: false,
  );

  @override
  Future<PatientClinicDetail> getClinic(
    String clinicId, {
    CancelToken? cancelToken,
  }) async => PatientClinicDetail(
    clinicId: clinicId,
    displayName: 'Test clinic',
    about: 'About',
    gallery: const [],
    acceptingRequests: true,
  );
}

FamilyMember _member({
  String id = '1',
  String firstName = 'Aicha',
  String lastName = 'Ben Ali',
  String relationship = 'parent',
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
  );
}

Widget _buildApp({
  RequestKind requestKind = RequestKind.clinic,
  List<FamilyMember>? members,
  RequestSubmissionController? requestController,
  _FakeDoctorRepository? doctorRepository,
  Widget? home,
}) {
  final fp = FamilyProvider(
    repository: _FakeFamilyRepository(members: members ?? []),
  );
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
      ChangeNotifierProvider<DoctorDirectoryController>(
        create: (_) => DoctorDirectoryController(
          repository: doctorRepository ?? _FakeDoctorRepository(),
        ),
      ),
    ],
    child: MaterialApp(
      theme: buildOmniTheme(),
      home: home ?? WhoNeedsCareScreen(requestKind: requestKind),
    ),
  );
}

void main() {
  group('Doctor Cabinet navigation', () {
    testWidgets(
      'Cabinet entry initial request carries required discovery constraints',
      (tester) async {
        final repository = _FakeDoctorRepository();
        await tester.pumpWidget(
          _buildApp(
            doctorRepository: repository,
            home: const DoctorCabinetEntryScreen(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        expect(find.byType(DoctorDirectoryScreen), findsOneWidget);
        expect(repository.criteria, hasLength(1));
        expect(
          repository.criteria.single.careCapability,
          DoctorCareCapability.cabinet,
        );
        expect(repository.criteria.single.acceptingNewPatients, isTrue);
        expect(repository.criteria.single.page, 0);
        expect(repository.criteria.single.size, 20);
      },
    );

    testWidgets('direct Doctor directory flow remains generic', (tester) async {
      final repository = _FakeDoctorRepository();
      await tester.pumpWidget(
        _buildApp(
          requestKind: RequestKind.doctor,
          doctorRepository: repository,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(repository.criteria.single.careCapability, isNull);
      expect(repository.criteria.single.acceptingNewPatients, isNull);
    });

    testWidgets(
      'Continue with RequestKind.doctor navigates to DoctorDirectoryScreen',
      (tester) async {
        await tester.pumpWidget(_buildApp(requestKind: RequestKind.doctor));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        expect(find.byType(DoctorDirectoryScreen), findsOneWidget);
        expect(find.byType(ClinicDirectoryScreen), findsNothing);
      },
    );

    testWidgets(
      'Continue with RequestKind.clinic navigates to ClinicDirectoryScreen',
      (tester) async {
        await tester.pumpWidget(_buildApp(requestKind: RequestKind.clinic));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        expect(find.byType(ClinicDirectoryScreen), findsOneWidget);
        expect(find.byType(DoctorDirectoryScreen), findsNothing);
      },
    );

    testWidgets(
      'Family member with RequestKind.doctor navigates to DoctorDirectoryScreen',
      (tester) async {
        final member = _member(id: 'test-id');
        final request = RequestSubmissionController(
          repository: _FakeRequestRepository(),
        );
        await tester.pumpWidget(
          _buildApp(
            requestKind: RequestKind.doctor,
            members: [member],
            requestController: request,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Aicha Ben Ali'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        expect(find.byType(DoctorDirectoryScreen), findsOneWidget);
        expect(find.byType(ClinicDirectoryScreen), findsNothing);
        expect(request.subject.isSelf, isFalse);
        expect(request.subject.familyMemberId, 'test-id');
        final workflow = Provider.of<ScheduledCarePrototypeController>(
          tester.element(find.byType(DoctorDirectoryScreen)),
          listen: false,
        );
        expect(workflow.records, isEmpty);
        expect(workflow.draft.patient?.familyMemberId, 'test-id');
        expect(
          workflow.draft.patient?.type,
          ScheduledPatientSubjectType.familyMember,
        );
      },
    );

    testWidgets('SELF selection commits correctly with RequestKind.doctor', (
      tester,
    ) async {
      final request = RequestSubmissionController(
        repository: _FakeRequestRepository(),
      );
      await tester.pumpWidget(
        _buildApp(requestKind: RequestKind.doctor, requestController: request),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(request.subject.isSelf, isTrue);
      final workflow = Provider.of<ScheduledCarePrototypeController>(
        tester.element(find.byType(DoctorDirectoryScreen)),
        listen: false,
      );
      expect(workflow.records, isEmpty);
      expect(workflow.draft.patient?.type, ScheduledPatientSubjectType.self);
    });

    testWidgets('generic Doctor directory has no prototype dependency', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp(home: const DoctorDirectoryScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(DoctorDirectoryScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('WhoNeedsCareScreen renders with RequestKind.doctor', (
      tester,
    ) async {
      final member = _member();
      await tester.pumpWidget(
        _buildApp(requestKind: RequestKind.doctor, members: [member]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Who needs care?'), findsOneWidget);
      expect(find.text('Choose who this request is for.'), findsOneWidget);
      expect(find.text('Me'), findsOneWidget);
      expect(find.text('Aicha Ben Ali'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('Default requestKind is clinic', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.byType(ClinicDirectoryScreen), findsOneWidget);
      expect(find.byType(DoctorDirectoryScreen), findsNothing);
    });
  });
}
