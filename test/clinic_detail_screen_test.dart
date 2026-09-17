import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/patient_clinic/application/patient_clinic_directory_controller.dart';
import 'package:omnicare_mobile/features/patient_clinic/data/patient_clinic_failure.dart';
import 'package:omnicare_mobile/features/patient_clinic/data/patient_clinic_models.dart';
import 'package:omnicare_mobile/features/patient_clinic/data/patient_clinic_repository.dart';
import 'package:omnicare_mobile/features/patient_clinic/presentation/clinic_detail_screen.dart';
import 'package:omnicare_mobile/features/patient_clinic/presentation/clinic_presentation_metadata.dart';
import 'package:omnicare_mobile/features/request_core/application/request_submission_controller.dart';
import 'package:omnicare_mobile/features/request_core/data/request_models.dart';
import 'package:omnicare_mobile/features/request_core/data/request_repository.dart';
import 'package:omnicare_mobile/features/request_core/domain/clinic_request_intent.dart';
import 'package:omnicare_mobile/features/request_core/domain/request_vocabulary.dart';
import 'package:omnicare_mobile/features/request_core/identity/request_operation_id.dart';

const _clinicId = 'clinic-cardiology-001';

class _FakeRequestRepository implements RequestRepository {
  @override
  Future<SubmitClinicRequestResult> submitClinicRequest({
    required RequestOperationId requestId,
    required ClinicRequestIntent intent,
    CancelToken? cancelToken,
  }) async =>
      throw UnimplementedError();

  @override
  Future<PatientRequestPage> listRequests({
    int? page,
    int? pageSize,
    PatientRequestListFilter? filter,
    CancelToken? cancelToken,
  }) async =>
      throw UnimplementedError();

  @override
  Future<PatientRequest> getRequest(
    RequestOperationId requestId, {
    CancelToken? cancelToken,
  }) async =>
      throw UnimplementedError();

  @override
  Future<PatientRequest> cancelRequest({
    required RequestOperationId requestId,
    required int expectedVersion,
    CancelToken? cancelToken,
  }) async =>
      throw UnimplementedError();

  @override
  Future<PatientRequest> respondToInformationRequest({
    required RequestOperationId requestId,
    required PatientInformationResponsePayload payload,
    CancelToken? cancelToken,
  }) async =>
      throw UnimplementedError();
}

class _FakePatientClinicRepository implements PatientClinicRepository {
  _FakePatientClinicRepository({PatientClinicDetail? detail})
      : detail = detail ?? _defaultDetail();

  PatientClinicDetail detail;
  PatientClinicFailure? failureToThrow;
  final List<String> getClinicIds = <String>[];

  @override
  Future<PatientClinicDirectoryPage> listClinics({
    String? query,
    String? city,
    int? page,
    int? pageSize,
    CancelToken? cancelToken,
  }) async =>
      throw UnimplementedError();

  @override
  Future<PatientClinicDetail> getClinic(
    String clinicId, {
    CancelToken? cancelToken,
  }) async {
    getClinicIds.add(clinicId);
    final failure = failureToThrow;
    if (failure != null) throw failure;
    return detail;
  }
}

PatientClinicDetail _detail({
  String clinicId = _clinicId,
  String displayName = 'Clinique Cardiologie El Amen',
  String? about,
  String? address,
  String? city,
  String? governorate,
  String? primaryImageUrl,
  bool acceptingRequests = true,
  List<PatientClinicImage> gallery = const [],
}) {
  return PatientClinicDetail(
    clinicId: clinicId,
    displayName: displayName,
    about: about,
    city: city,
    governorate: governorate,
    address: address,
    primaryImageUrl: primaryImageUrl,
    acceptingRequests: acceptingRequests,
    gallery: gallery,
  );
}

PatientClinicDetail _defaultDetail() {
  return _detail(
    about: 'A trusted cardiology centre in the city centre.',
    address: 'Avenue Habib Bourguiba 12',
    city: 'Tunis',
    governorate: 'Tunis',
  );
}

Future<RequestSubmissionController> _pumpDetail(
  WidgetTester tester, {
  PatientClinicDetail? detail,
  PatientClinicFailure? failure,
}) async {
  final repository = _FakePatientClinicRepository(detail: detail)
    ..failureToThrow = failure;
  final directory = PatientClinicDirectoryController(repository: repository);
  final request = RequestSubmissionController(
    repository: _FakeRequestRepository(),
  );

  _useTallViewport(tester);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PatientClinicDirectoryController>.value(
          value: directory,
        ),
        ChangeNotifierProvider<RequestSubmissionController>.value(
          value: request,
        ),
      ],
      child: MaterialApp(
        theme: buildOmniTheme(),
        home: ClinicDetailScreen(clinicId: _clinicId),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return request;
}

void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(600, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  group('ClinicDetailScreen', () {
    testWidgets('fetchDetail receives the correct clinicId', (tester) async {
      final repository = _FakePatientClinicRepository();
      final directory = PatientClinicDirectoryController(repository: repository);
      final request = RequestSubmissionController(
        repository: _FakeRequestRepository(),
      );
      _useTallViewport(tester);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PatientClinicDirectoryController>.value(
              value: directory,
            ),
            ChangeNotifierProvider<RequestSubmissionController>.value(
              value: request,
            ),
          ],
          child: MaterialApp(
            theme: buildOmniTheme(),
            home: const ClinicDetailScreen(clinicId: _clinicId),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.getClinicIds, [_clinicId]);
    });

    testWidgets('no DraggableScrollableSheet exists for Clinic Detail', (tester) async {
      await _pumpDetail(tester);
      expect(find.byType(DraggableScrollableSheet), findsNothing);
    });

    testWidgets('real backend displayName renders unchanged', (tester) async {
      await _pumpDetail(
        tester,
        detail: _detail(displayName: 'Clinique Cardiologie El Amen'),
      );
      expect(find.text('Clinique Cardiologie El Amen'), findsWidgets);
    });

    testWidgets('real backend about renders when provided', (tester) async {
      await _pumpDetail(
        tester,
        detail: _detail(about: 'Real backend paragraph.'),
      );
      expect(find.text('About this clinic'), findsOneWidget);
      expect(find.text('Real backend paragraph.'), findsOneWidget);
    });

    testWidgets(
      'static shortDescription is used only when about is absent',
      (tester) async {
        await _pumpDetail(tester, detail: _detail(about: null));
        const expected =
            'Cardiology-focused consultations and cardiac follow-up.';
        final about =
            ClinicPresentationCatalog.forClinic(_clinicId).shortDescription;
        expect(about, expected);
        expect(find.text('About this clinic'), findsOneWidget);
        expect(find.text(expected), findsOneWidget);
      },
    );

    testWidgets('real address/city/governorate renders', (tester) async {
      await _pumpDetail(
        tester,
        detail: _detail(
          address: 'Avenue Habib Bourguiba 12',
          city: 'Tunis',
          governorate: 'Tunis',
        ),
      );
      expect(find.text('Avenue Habib Bourguiba 12'), findsWidgets);
      expect(find.text('Location'), findsOneWidget);
    });

    testWidgets('location has no malformed empty punctuation', (tester) async {
      await _pumpDetail(
        tester,
        detail: _detail(address: null, city: 'Sousse', governorate: null),
      );
      expect(find.text('Sousse'), findsWidgets);
      expect(find.text('Sousse, '), findsNothing);
      expect(find.text(', '), findsNothing);
    });

    testWidgets(
      'accepting requests state renders for an accepting clinic',
      (tester) async {
        await _pumpDetail(tester, detail: _detail(acceptingRequests: true));
        expect(find.text('Accepting requests'), findsWidgets);
        expect(find.text('Not accepting requests'), findsNothing);
      },
    );

    testWidgets('not-accepting state is clear and cannot be selected', (
      tester,
    ) async {
      final request = await _pumpDetail(
        tester,
        detail: _detail(acceptingRequests: false),
      );

      expect(find.text('Not accepting requests'), findsWidgets);
      final ctaButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Select this clinic'),
      );
      expect(ctaButton.onPressed, isNull);
      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Select this clinic'),
      );
      await tester.pumpAndSettle();
      expect(request.selectedClinicId, isNull);
    });

    testWidgets('hero PageView renders for gallery images', (tester) async {
      await _pumpDetail(
        tester,
        detail: _detail(
          gallery: const [
            PatientClinicImage(imageUrl: 'https://cdn.example/a.jpg'),
            PatientClinicImage(imageUrl: 'https://cdn.example/b.jpg'),
          ],
        ),
      );
      // Hero gallery renders backend images + local demo images combined
      expect(find.byType(PageView), findsWidgets);
      final metadata =
          ClinicPresentationCatalog.forClinic(_clinicId);
      final expectedTotal = 2 + metadata.localDemoImages.length;
      expect(find.text('1 / $expectedTotal'), findsOneWidget);
    });

    testWidgets(
      'no fake rating/review/recommendation UI exists',
      (tester) async {
        await _pumpDetail(tester);
        expect(find.byIcon(Icons.star_rounded), findsNothing);
        expect(find.byIcon(Icons.star_border_rounded), findsNothing);
        expect(find.textContaining('recommended'), findsNothing);
        expect(find.textContaining('Recommended'), findsNothing);
        expect(find.textContaining('rating'), findsNothing);
        expect(find.textContaining('rated'), findsNothing);
        expect(find.textContaining('award'), findsNothing);
        expect(find.textContaining('Top match'), findsNothing);
      },
    );

    testWidgets('pricing is NOT rendered', (tester) async {
      await _pumpDetail(tester);
      expect(find.text('Pricing'), findsNothing);
      expect(find.textContaining('TND'), findsNothing);
      expect(find.textContaining('Consultation fees'), findsNothing);
    });

    testWidgets('specialties & expertise section renders', (tester) async {
      await _pumpDetail(tester);
      expect(find.text('Specialties & expertise'), findsOneWidget);
    });

    testWidgets('primary expertise renders', (tester) async {
      await _pumpDetail(tester);
      final metadata =
          ClinicPresentationCatalog.forClinic(_clinicId);
      expect(find.text(metadata.primarySpecialty), findsWidgets);
    });

    testWidgets('supporting specialty summary renders', (tester) async {
      await _pumpDetail(tester);
      final metadata =
          ClinicPresentationCatalog.forClinic(_clinicId);
      // At least one supporting specialty should render
      expect(find.text(metadata.specialties.first), findsWidgets);
    });

    testWidgets('V2 availability section renders time slots', (tester) async {
      await _pumpDetail(tester);
      expect(find.text('Next availability'), findsOneWidget);
      expect(find.text('Today'), findsWidgets);
      expect(find.text('Tomorrow'), findsWidgets);
    });

    testWidgets('V2 doctors section renders doctor profiles', (tester) async {
      await _pumpDetail(tester);
      expect(find.text('Doctors'), findsOneWidget);
      expect(find.text('Dr. Habib Mansour'), findsOneWidget);
      expect(find.text('Cardiology'), findsWidgets);
      expect(find.text('20+ years, interventional cardiology'), findsOneWidget);
      expect(find.text('Dr. Nadia Khlifi'), findsOneWidget);
    });

    testWidgets('V2 insurance section renders accepted insurers', (
      tester,
    ) async {
      await _pumpDetail(tester);
      expect(find.text('Accepted insurance'), findsOneWidget);
      expect(find.text('CNAM'), findsWidgets);
      expect(find.text('CNSS'), findsWidgets);
    });

    testWidgets('V2 facilities section renders facility chips', (tester) async {
      await _pumpDetail(tester);
      expect(find.text('Facilities'), findsOneWidget);
      expect(find.text('Echocardiography'), findsOneWidget);
    });

    testWidgets('V2 hours section renders opening hours', (tester) async {
      await _pumpDetail(tester);
      expect(find.text('Hours'), findsOneWidget);
      expect(find.text('Open now'), findsWidgets);
    });

    testWidgets('V2 verification section renders badges', (tester) async {
      await _pumpDetail(tester);
      expect(find.text('Clinic information'), findsOneWidget);
      expect(find.text('Licensed clinic'), findsWidgets);
    });

    testWidgets('V2 accessibility and languages render', (tester) async {
      await _pumpDetail(tester);
      // Scroll the page content to reveal bottom sections
      final scrollable = find.byType(ListView);
      await tester.drag(scrollable, const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(find.text('Accessibility & Languages'), findsOneWidget);
      expect(find.text('Wheelchair accessible'), findsOneWidget);
      // Languages render as a joined string
      expect(find.textContaining('Arabic'), findsWidgets);
    });

    testWidgets(
      'what happens next section renders the three workflow steps',
      (tester) async {
        await _pumpDetail(tester);
        // Scroll the page content to reveal bottom sections
        final scrollable = find.byType(ListView);
        await tester.drag(scrollable, const Offset(0, -1200));
        await tester.pumpAndSettle();
        expect(find.text('What happens next'), findsOneWidget);
        expect(find.text('Send your request'), findsOneWidget);
        expect(
          find.text('Share the care details needed by the clinic.'),
          findsOneWidget,
        );
        expect(find.text('Administrative review'), findsWidgets);
        expect(
          find.text('The clinic team reviews your request.'),
          findsOneWidget,
        );
        expect(find.text('Receive next steps'), findsOneWidget);
        expect(
          find.text("You'll get the next update in OmniCare."),
          findsOneWidget,
        );
      },
    );

    testWidgets('Select this clinic CTA renders when appropriate', (
      tester,
    ) async {
      await _pumpDetail(tester);
      expect(find.text('Select this clinic'), findsWidgets);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Select this clinic'),
            )
            .onPressed,
        isNotNull,
      );
    });

    testWidgets(
      'CTA records selection on RequestSubmissionController and pops',
      (tester) async {
        final request = await _pumpDetail(tester);

        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Select this clinic'),
        );
        await tester.pumpAndSettle();

        expect(request.selectedClinicId, _clinicId);
      },
    );

    testWidgets('error state renders a safe mapped message', (tester) async {
      await _pumpDetail(
        tester,
        failure: PatientClinicFailure.serverUnavailable,
      );
      expect(
        find.text(
          'The clinic directory is temporarily unavailable. Please try again.',
        ),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('retry calls fetchDetail again', (tester) async {
      final repository = _FakePatientClinicRepository()
        ..failureToThrow = PatientClinicFailure.networkUnavailable;
      final directory =
          PatientClinicDirectoryController(repository: repository);
      _useTallViewport(tester);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PatientClinicDirectoryController>.value(
              value: directory,
            ),
            ChangeNotifierProvider<RequestSubmissionController>.value(
              value: RequestSubmissionController(
                repository: _FakeRequestRepository(),
              ),
            ),
          ],
          child: MaterialApp(
            theme: buildOmniTheme(),
            home: const ClinicDetailScreen(clinicId: _clinicId),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.getClinicIds, hasLength(1));
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(repository.getClinicIds, hasLength(2));
    });

    testWidgets('no fetch is triggered repeatedly across rebuilds', (
      tester,
    ) async {
      final repository = _FakePatientClinicRepository();
      final directory = PatientClinicDirectoryController(
        repository: repository,
      );
      final request = RequestSubmissionController(
        repository: _FakeRequestRepository(),
      );
      _useTallViewport(tester);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PatientClinicDirectoryController>.value(
              value: directory,
            ),
            ChangeNotifierProvider<RequestSubmissionController>.value(
              value: request,
            ),
          ],
          child: MaterialApp(
            theme: buildOmniTheme(),
            home: const ClinicDetailScreen(clinicId: _clinicId),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.getClinicIds, hasLength(1));

      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(repository.getClinicIds, hasLength(1));
    });

    testWidgets('presentation metadata does not mutate the backend detail', (
      tester,
    ) async {
      final detail = _detail(
        displayName: 'Clinique Cardiologie El Amen',
        about: 'Backend about.',
        city: 'Tunis',
        governorate: 'Tunis',
      );
      final displayNameBefore = detail.displayName;
      final aboutBefore = detail.about;

      await _pumpDetail(tester, detail: detail);

      expect(detail.displayName, displayNameBefore);
      expect(detail.about, aboutBefore);
      expect(detail.clinicId, _clinicId);
      final metadata = ClinicPresentationCatalog.forClinic(_clinicId);
      expect(metadata.specialties, isNotEmpty);
      expect(detail.gallery, isEmpty);
    });

    test('metadata catalog maps a known clinic id deterministically', () {
      expect(
        ClinicPresentationCatalog.forClinic('clinic-cardiology-001')
            .clinicType,
        'Specialty clinic',
      );
    });

    test('V2 presentation models are populated for default clinic', () {
      final metadata =
          ClinicPresentationCatalog.forClinic('unknown-clinic');
      expect(metadata.availability, isNotEmpty);
      expect(metadata.doctors, isNotEmpty);
      expect(metadata.insurance, isNotEmpty);
      expect(metadata.facilities, isNotEmpty);
      expect(metadata.hours, isNotNull);
      expect(metadata.languages, isNotEmpty);
      expect(metadata.accessibility, isNotEmpty);
      expect(metadata.verification, isNotNull);
      expect(metadata.primarySpecialty, isNotEmpty);
    });

    test('V2 presentation models are populated for cardiology clinic', () {
      final metadata =
          ClinicPresentationCatalog.forClinic('clinic-cardiology-001');
      expect(metadata.clinicType, 'Specialty clinic');
      expect(metadata.primarySpecialty, 'Cardiology');
      expect(metadata.availability, hasLength(3));
      expect(metadata.doctors, hasLength(3));
      expect(metadata.insurance, contains('Intertropical'));
      expect(metadata.facilities, hasLength(4));
      expect(metadata.hours?.weekday, '09:00 – 17:00');
      expect(metadata.languages, contains('Arabic'));
      expect(metadata.accessibility, contains('Wheelchair accessible'));
      expect(metadata.verification?.badges, hasLength(3));
    });

    test('V2 presentation models contain no pricing', () {
      final metadata =
          ClinicPresentationCatalog.forClinic('clinic-cardiology-001');
      // Pricing was removed; verify no pricing-related data
      expect(metadata.toString(), isNot(contains('TND')));
    });

    testWidgets('hero gallery renders local demo images for demo clinics', (
      tester,
    ) async {
      await _pumpDetail(
        tester,
        detail: _detail(gallery: const [], primaryImageUrl: null),
      );
      // The hero gallery should render using local demo assets
      expect(find.byType(PageView), findsWidgets);
    });
  });
}
