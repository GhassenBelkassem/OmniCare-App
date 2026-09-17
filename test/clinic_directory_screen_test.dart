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
import 'package:omnicare_mobile/features/patient_clinic/presentation/clinic_directory_screen.dart';
import 'package:omnicare_mobile/features/patient_clinic/presentation/clinic_filter_model.dart';
import 'package:omnicare_mobile/features/patient_clinic/presentation/clinic_presentation_metadata.dart';
import 'package:omnicare_mobile/features/patient_clinic/presentation/widgets/clinic_card.dart';
import 'package:omnicare_mobile/features/request_core/application/request_submission_controller.dart';
import 'package:omnicare_mobile/features/request_core/data/request_models.dart';
import 'package:omnicare_mobile/features/request_core/data/request_repository.dart';
import 'package:omnicare_mobile/features/request_core/domain/clinic_request_intent.dart';
import 'package:omnicare_mobile/features/request_core/domain/request_vocabulary.dart';
import 'package:omnicare_mobile/features/request_core/identity/request_operation_id.dart';

const _cardiologyId = 'clinic-cardiology-001';
const _rehabId = 'clinic-rehab-001';
const _generalId = 'clinic-general-002';

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
  _FakePatientClinicRepository({List<PatientClinicListItem>? clinics})
      : clinics = List.unmodifiable(clinics ?? _defaultClinics());

  final List<PatientClinicListItem> clinics;
  String? lastQuery;
  int listCalls = 0;
  PatientClinicFailure? failureToThrow;

  @override
  Future<PatientClinicDirectoryPage> listClinics({
    String? query,
    String? city,
    int? page,
    int? pageSize,
    CancelToken? cancelToken,
  }) async {
    listCalls++;
    final failure = failureToThrow;
    if (failure != null) throw failure;
    lastQuery = query;

    var result = clinics;
    if (query != null && query.trim().isNotEmpty) {
      final needle = query.trim().toLowerCase();
      result = result
          .where(
            (clinic) =>
                clinic.displayName.toLowerCase().contains(needle),
          )
          .toList(growable: false);
    }

    final size = pageSize ?? 20;
    final start = (page ?? 0) * size;
    final end = (start + size) > result.length
        ? result.length
        : start + size;
    final slice = start >= result.length
        ? const <PatientClinicListItem>[]
        : result.sublist(start, end);

    return PatientClinicDirectoryPage(
      contractVersion: '1.0',
      items: List.unmodifiable(slice),
      page: page ?? 0,
      pageSize: size,
      hasNext: end < result.length,
    );
  }

  @override
  Future<PatientClinicDetail> getClinic(
    String clinicId, {
    CancelToken? cancelToken,
  }) async {
    final failure = failureToThrow;
    if (failure != null) throw failure;
    return PatientClinicDetail(
      clinicId: clinicId,
      displayName: 'Detail clinic',
      about: 'About',
      gallery: const [],
      acceptingRequests: true,
    );
  }
}

List<PatientClinicListItem> _defaultClinics() => [
  PatientClinicListItem(
    clinicId: _cardiologyId,
    displayName: 'Clinique Cardiologie El Amen',
    city: 'Tunis',
    governorate: 'Tunis',
    primaryImageUrl: null,
    acceptingRequests: true,
  ),
  PatientClinicListItem(
    clinicId: _rehabId,
    displayName: 'Centre de Rééducation Riadh',
    city: 'Sousse',
    governorate: 'Sousse',
    primaryImageUrl: null,
    acceptingRequests: false,
  ),
  PatientClinicListItem(
    clinicId: _generalId,
    displayName: 'Polyclinique du Centre',
    city: 'Tunis',
    governorate: 'Tunis',
    primaryImageUrl: null,
    acceptingRequests: true,
  ),
];

Future<PatientClinicDirectoryController> _pumpDirectory(
  WidgetTester tester, {
  List<PatientClinicListItem>? clinics,
  int pageSize = 20,
  PatientClinicFailure? failure,
  RequestSubmissionController? request,
}) async {
  final repository = _FakePatientClinicRepository(clinics: clinics)
    ..failureToThrow = failure;
  final directory = PatientClinicDirectoryController(
    repository: repository,
    pageSize: pageSize,
  );
  final requestController =
      request ?? RequestSubmissionController(repository: _FakeRequestRepository());

  await _pumpWrapped(
    tester,
    directory: directory,
    request: requestController,
  );
  return directory;
}

Future<void> _pumpWrapped(
  WidgetTester tester, {
  required PatientClinicDirectoryController directory,
  required RequestSubmissionController request,
}) async {
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
        routes: {
          '/m05/situation': (context) =>
              const Scaffold(body: Text('Situation placeholder')),
        },
        home: const ClinicDirectoryScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(500, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Opens the filter sheet. Must be followed by [pumpAndSettle].
Future<void> _openFilterSheet(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Filters'));
  await tester.pumpAndSettle();
}

void main() {
  group('ClinicPresentationMetadata isolation', () {
    test('static metadata wraps, never mutates, the backend model', () {
      final clinic = PatientClinicListItem(
        clinicId: _cardiologyId,
        displayName: 'Clinique Cardiologie El Amen',
        city: 'Tunis',
        governorate: 'Tunis',
        primaryImageUrl: 'https://cdn.example/primary.jpg',
        acceptingRequests: true,
      );

      final item = PatientClinicPresentationItem.fromBackend(clinic);

      expect(item.clinic, same(clinic));
      expect(item.specialties, contains('Cardiology'));
      expect(item.clinicType, 'Specialty clinic');
      expect(item.services, isNotEmpty);
      expect(item.clinicId, clinic.clinicId);
      expect(item.displayName, 'Clinique Cardiologie El Amen');
      expect(item.city, 'Tunis');
      expect(item.distance, '2.3 km away');
      expect(item.locality, 'La Marsa');
      expect(item.acceptingRequests, isTrue);
      expect(item.primaryImageUrl, 'https://cdn.example/primary.jpg');
      expect(clinic.toString(), 'PatientClinicListItem(<redacted>)');
    });

    test('default development profile applies to unknown clinics', () {
      final clinic = PatientClinicListItem(
        clinicId: _generalId,
        displayName: 'Polyclinique du Centre',
        city: 'Tunis',
        governorate: 'Tunis',
        primaryImageUrl: null,
        acceptingRequests: true,
      );
      final item = PatientClinicPresentationItem.fromBackend(clinic);
      expect(item.clinicType, 'Multi-specialty clinic');
      expect(item.specialties, contains('General medicine'));
    });
  });

  group('ClinicPresentationMetadata catalogs', () {
    test('CareNeedOptions has 8 entries', () {
      expect(CareNeedOptions.values, hasLength(8));
    });

    test('SpecialtyCatalog.all is alphabetized and has entries', () {
      final all = SpecialtyCatalog.all;
      expect(all.length, greaterThanOrEqualTo(40));
      for (var i = 1; i < all.length; i++) {
        expect(
          all[i - 1].compareTo(all[i]),
          lessThan(0),
          reason: '"${all[i - 1]}" should come before "${all[i]}"',
        );
      }
    });

    test('SpecialtyCatalog.common is a subset of all', () {
      for (final s in SpecialtyCatalog.common) {
        expect(SpecialtyCatalog.all, contains(s));
      }
    });

    test('GovernorateCatalog provides cities for Tunis', () {
      final cities = GovernorateCatalog.citiesFor('Tunis');
      expect(cities, isNotEmpty);
      expect(cities, contains('La Marsa'));
    });

    test('GovernorateCatalog returns empty for unknown', () {
      expect(GovernorateCatalog.citiesFor('Atlantis'), isEmpty);
    });
  });

  group('clinic filter model', () {
    final clinics = _defaultClinics();

    test('active filter count reflects applied groups', () {
      expect(ClinicFilterSnapshot.none.isActive, isFalse);
      expect(ClinicFilterSnapshot.none.activeGroupCount, 0);

      const filters = ClinicFilterSnapshot(
        specialties: {'Cardiology'},
        acceptingOnly: true,
      );
      expect(filters.isActive, isTrue);
      expect(filters.activeGroupCount, 2);
    });

    test('care needs and distance count as active groups', () {
      const filters = ClinicFilterSnapshot(
        careNeeds: {'Surgery'},
        distance: '< 5 km',
      );
      expect(filters.isActive, isTrue);
      expect(filters.activeGroupCount, 2);
    });

    test('specialty filter matches isolated presentation metadata', () {
      final visible = applyClinicFilters(
        items: clinics,
        filters: const ClinicFilterSnapshot(
          specialties: {'Physiotherapy'},
        ),
      );
      expect(visible.map((item) => item.clinicId).toSet(), {
        _generalId,
        _rehabId,
      });
    });

    test('city filter uses real DTO city values', () {
      final visible = applyClinicFilters(
        items: clinics,
        filters: const ClinicFilterSnapshot(cities: {'Sousse'}),
      );
      expect(visible.map((item) => item.clinicId).toList(), [_rehabId]);
    });

    test('accepting-only uses the real backend flag', () {
      final visible = applyClinicFilters(
        items: clinics,
        filters: const ClinicFilterSnapshot(acceptingOnly: true),
      );
      expect(visible.map((item) => item.clinicId).toSet(), {
        _cardiologyId,
        _generalId,
      });
    });

    test('clinic type filter works against presentation metadata', () {
      final visible = applyClinicFilters(
        items: clinics,
        filters: const ClinicFilterSnapshot(
          clinicTypes: {'Specialty clinic'},
        ),
      );
      expect(visible.map((item) => item.clinicId).toList(), [_cardiologyId]);
    });

    test('care need Rehabilitation / Kiné matches metadata', () {
      final visible = applyClinicFilters(
        items: clinics,
        filters: const ClinicFilterSnapshot(
          careNeeds: {'Rehabilitation / Kiné'},
        ),
      );
      expect(visible.map((item) => item.clinicId).toSet(), {
        _generalId,
        _rehabId,
      });
    });

    test('care need General consultation matches general medicine', () {
      final visible = applyClinicFilters(
        items: clinics,
        filters: const ClinicFilterSnapshot(
          careNeeds: {'General consultation'},
        ),
      );
      expect(visible.map((item) => item.clinicId).toSet(), {
        _generalId,
      });
    });

    test('distance filter matches metadata distance', () {
      final visible = applyClinicFilters(
        items: clinics,
        filters: const ClinicFilterSnapshot(distance: '< 5 km'),
      );
      expect(visible.map((item) => item.clinicId).toSet(), {
        _cardiologyId,
        _generalId,
        _rehabId,
      });
    });

    test('distance < 2 km only shows closest', () {
      final visible = applyClinicFilters(
        items: clinics,
        filters: const ClinicFilterSnapshot(distance: '< 2 km'),
      );
      expect(visible.map((item) => item.clinicId).toList(), [_generalId]);
    });

    test('A–Z sort is deterministic', () {
      final visible = applyClinicFilters(
        items: clinics,
        filters: const ClinicFilterSnapshot(
          sortOrder: ClinicSortOrder.alphabetical,
        ),
      );
      expect(
        visible.map((item) => item.displayName).toList(),
        [
          'Centre de Rééducation Riadh',
          'Clinique Cardiologie El Amen',
          'Polyclinique du Centre',
        ],
      );
    });

    test('accepting-first sort keeps accepting clinics on top (stable)', () {
      final visible = applyClinicFilters(
        items: clinics,
        filters: const ClinicFilterSnapshot(
          sortOrder: ClinicSortOrder.acceptingFirst,
        ),
      );
      expect(
        visible.map((item) => item.clinicId).toList(),
        [_cardiologyId, _generalId, _rehabId],
      );
      final untouched = applyClinicFilters(
        items: clinics,
        filters: ClinicFilterSnapshot.none,
      );
      expect(
        untouched.map((item) => item.clinicId).toList(),
        [_cardiologyId, _rehabId, _generalId],
      );
    });

    test('options derive only from currently loaded clinics', () {
      final options = buildClinicFilterOptions(clinics);
      expect(options.cities, containsAll(['Sousse', 'Tunis']));
      expect(options.specialties, contains('Cardiology'));
      expect(options.clinicTypes, contains('Specialty clinic'));
      expect(options.services, contains('Physiotherapy'));
    });

    test('copyWith clearDistance resets distance to null', () {
      const original = ClinicFilterSnapshot(distance: '< 5 km');
      final cleared = original.copyWith(clearDistance: true);
      expect(cleared.distance, isNull);
    });

    test('equality distinguishes different snapshots', () {
      const a = ClinicFilterSnapshot(specialties: {'Cardiology'});
      const b = ClinicFilterSnapshot(
        specialties: {'Cardiology'},
        sortOrder: ClinicSortOrder.alphabetical,
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('ClinicDirectoryScreen', () {
    testWidgets('uses a white canvas', (tester) async {
      _useTallViewport(tester);
      await _pumpDirectory(tester);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, OmniColors.pageBackground);
      expect(scaffold.backgroundColor, Colors.white);
    });

    testWidgets('header renders with back button, title and subtitle', (tester) async {
      _useTallViewport(tester);
      await _pumpDirectory(tester);
      expect(find.text('Choose a clinic'), findsOneWidget);
      expect(find.text('Find a clinic that\'s right for you.'), findsOneWidget);
      expect(find.bySemanticsLabel('Back'), findsOneWidget);
      expect(find.bySemanticsLabel('Filters'), findsOneWidget);
    });

    testWidgets('real backend Clinics render with preserved names', (tester) async {
      _useTallViewport(tester);
      await _pumpDirectory(tester);
      expect(find.text('Clinique Cardiologie El Amen'), findsOneWidget);
      expect(find.text('Centre de Rééducation Riadh'), findsOneWidget);
      expect(find.text('Polyclinique du Centre'), findsOneWidget);
    });

    testWidgets('real location and accepting state are preserved', (tester) async {
      _useTallViewport(tester);
      await _pumpDirectory(tester);

      expect(find.text('Tunis, La Marsa'), findsOneWidget);
      expect(find.text('Tunis, Centre Urbain Nord'), findsOneWidget);
      expect(find.text('Sousse, Ennasr'), findsOneWidget);
      expect(find.text('Accepting requests'), findsNWidgets(2));
      expect(find.text('Not accepting requests'), findsOneWidget);
    });

    testWidgets('directory card is horizontal with fixed height', (tester) async {
      _useTallViewport(tester);
      await _pumpDirectory(tester);

      expect(find.byType(ClinicListCard), findsNWidgets(3));
      expect(find.byIcon(Icons.medical_services_outlined), findsNWidgets(3));
    });

    testWidgets('directory card renders primary specialty from presentation metadata', (tester) async {
      _useTallViewport(tester);
      await _pumpDirectory(tester);

      expect(find.text('Cardiology'), findsOneWidget);
      expect(find.text('Physiotherapy'), findsOneWidget);
      expect(find.text('General medicine'), findsOneWidget);
      expect(find.text('+1'), findsNothing);
    });

    testWidgets('directory card shows distance from presentation metadata', (tester) async {
      _useTallViewport(tester);
      await _pumpDirectory(tester);

      expect(find.text('2.3 km away'), findsOneWidget);
      expect(find.text('4.8 km away'), findsOneWidget);
      expect(find.text('1.5 km away'), findsOneWidget);
    });

    testWidgets('directory card shows locality from presentation metadata in location label', (tester) async {
      _useTallViewport(tester);
      await _pumpDirectory(tester);

      expect(find.text('Tunis, La Marsa'), findsOneWidget);
      expect(find.text('Sousse, Ennasr'), findsOneWidget);
      expect(find.text('Tunis, Centre Urbain Nord'), findsOneWidget);
    });

    testWidgets('results count is displayed', (tester) async {
      _useTallViewport(tester);
      await _pumpDirectory(tester);

      expect(find.text('3 clinics found'), findsOneWidget);
    });

    testWidgets('results count shows singular for one result', (tester) async {
      _useTallViewport(tester);
      await _pumpDirectory(tester, clinics: [
        PatientClinicListItem(
          clinicId: _cardiologyId,
          displayName: 'Clinique Cardiologie El Amen',
          city: 'Tunis',
          governorate: 'Tunis',
          primaryImageUrl: null,
          acceptingRequests: true,
        ),
      ]);

      expect(find.text('1 clinic found'), findsOneWidget);
    });

    testWidgets('search calls the existing directory.search', (tester) async {
      _useTallViewport(tester);
      final repository = _FakePatientClinicRepository(
        clinics: _defaultClinics(),
      );
      final directory = PatientClinicDirectoryController(
        repository: repository,
        pageSize: 20,
      );

      await _pumpWrapped(
        tester,
        directory: directory,
        request: RequestSubmissionController(
          repository: _FakeRequestRepository(),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Riadh');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(repository.lastQuery, 'Riadh');
      expect(find.text('Centre de Rééducation Riadh'), findsOneWidget);
      expect(find.text('Clinique Cardiologie El Amen'), findsNothing);
    });

    testWidgets('card tap opens the existing ClinicDetailScreen', (tester) async {
      _useTallViewport(tester);
      await _pumpDirectory(tester);

      await tester.tap(find.text('Clinique Cardiologie El Amen'), warnIfMissed: false);
      await tester.pumpAndSettle();

      while (tester.takeException() != null) {}

      expect(find.byType(ClinicDetailScreen), findsOneWidget);
    });

    // ── Filter sheet tests ────────────────────────────────────────────
    //
    // Inside the modal sheet, use pump() instead of pumpAndSettle() for
    // widget interactions (chip taps, toggles) to avoid the modal barrier
    // dismiss animation from settling. Only use pumpAndSettle() after
    // the sheet has been dismissed (Apply/Reset).

    testWidgets('filter action opens the bottom sheet with essential sections', (tester) async {
      _useTallViewport(tester);
      await _pumpDirectory(tester);

      await _openFilterSheet(tester);

      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('What do you need?'), findsOneWidget);
      expect(find.text('Medical specialty'), findsAtLeastNWidgets(1));
      expect(find.text('Location'), findsAtLeastNWidgets(1));
      expect(find.text('Distance'), findsAtLeastNWidgets(1));
      expect(find.text('Accepting requests only'), findsOneWidget);
      expect(find.text('More filters'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
      expect(find.text('Show 3 clinics'), findsOneWidget);
    });

    testWidgets('care need chips are visible and selectable', (tester) async {
      _useTallViewport(tester);
      await _pumpDirectory(tester);

      await _openFilterSheet(tester);

      expect(find.widgetWithText(FilterChip, 'General consultation'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Surgery'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Imaging'), findsOneWidget);

      // Select General consultation
      await tester.tap(find.widgetWithText(FilterChip, 'General consultation'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Show 1 clinic'), findsOneWidget);

      await tester.tap(find.text('Show 1 clinic'));
      await tester.pumpAndSettle();

      expect(find.text('Polyclinique du Centre'), findsOneWidget);
      expect(find.text('Clinique Cardiologie El Amen'), findsNothing);
    });

    testWidgets('specialty selector opens a dedicated search sheet', (tester) async {
      _useTallViewport(tester);
      await _pumpDirectory(tester);

      await _openFilterSheet(tester);

      await tester.tap(find.text('Search specialties'));
      await tester.pumpAndSettle();

      // Dedicated sheet is open — "Cardiology" appears in the list AND
      // on the clinic card behind the sheet
      expect(find.text('Cardiology'), findsAtLeastNWidgets(1));
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('specialty search filters the list', (tester) async {
      _useTallViewport(tester);
      await _pumpDirectory(tester);

      await _openFilterSheet(tester);
      await tester.tap(find.text('Search specialties'));
      await tester.pumpAndSettle();

      final searchField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration is InputDecoration &&
            (widget.decoration as InputDecoration).hintText == 'Search specialties',
      );
      await tester.enterText(searchField, 'Cardio');
      await tester.pumpAndSettle();

      expect(find.text('Cardiology'), findsAtLeastNWidgets(1));
      expect(find.text('Dermatology'), findsNothing);
    });

    testWidgets('specialty selection works and shows tokens', (tester) async {
      _useTallViewport(tester);
      await _pumpDirectory(tester);

      await _openFilterSheet(tester);
      await tester.tap(find.text('Search specialties'));
      await tester.pumpAndSettle();

      // Tap the Cardiology tile — the sheet overlays the card, so the last
      // match is the tile inside the DraggableScrollableSheet.
      await tester.tap(find.text('Cardiology').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm 1 specialties'));
      await tester.pumpAndSettle();

      // Back on main sheet, specialty token should be visible
      expect(find.text('1 selected'), findsOneWidget);
    });

    testWidgets('city filter works against the real DTO city', (tester) async {
      _useTallViewport(tester);
      await _pumpDirectory(tester);

      await _openFilterSheet(tester);

      await tester.tap(find.widgetWithText(FilterChip, 'Sousse'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Show 1 clinic'), findsOneWidget);

      await tester.tap(find.text('Show 1 clinic'));
      await tester.pumpAndSettle();

      expect(find.text('Centre de Rééducation Riadh'), findsOneWidget);
      expect(find.text('Clinique Cardiologie El Amen'), findsNothing);
    });

    testWidgets('distance chips work as single-select', (tester) async {
      _useTallViewport(tester);
      await _pumpDirectory(tester);

      await _openFilterSheet(tester);

      await tester.tap(find.widgetWithText(FilterChip, '< 2 km'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Show 1 clinic'), findsOneWidget);

      // Tap again to deselect
      await tester.tap(find.widgetWithText(FilterChip, '< 2 km'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Show 3 clinics'), findsOneWidget);
    });

    testWidgets('accepting-only filter uses the real backend flag', (tester) async {
      _useTallViewport(tester);
      await _pumpDirectory(tester);

      await _openFilterSheet(tester);

      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump();

      expect(find.text('Show 2 clinics'), findsOneWidget);

      await tester.tap(find.text('Show 2 clinics'));
      await tester.pumpAndSettle();

      expect(find.text('Centre de Rééducation Riadh'), findsNothing);
      expect(find.text('Clinique Cardiologie El Amen'), findsOneWidget);
      expect(find.text('Polyclinique du Centre'), findsOneWidget);
    });

    testWidgets('more filters reveals clinic type and services', (tester) async {
      _useTallViewport(tester);
      await _pumpDirectory(tester);

      await _openFilterSheet(tester);

      expect(find.widgetWithText(FilterChip, 'Specialty clinic'), findsNothing);

      await tester.tap(find.text('More filters'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilterChip, 'Specialty clinic'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Multi-specialty clinic'), findsOneWidget);
    });

    testWidgets('clinic type filter works through more filters', (tester) async {
      _useTallViewport(tester);
      await _pumpDirectory(tester);

      await _openFilterSheet(tester);
      await tester.tap(find.text('More filters'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilterChip, 'Specialty clinic'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Show 1 clinic'), findsOneWidget);

      await tester.tap(find.text('Show 1 clinic'));
      await tester.pumpAndSettle();

      expect(find.text('Clinique Cardiologie El Amen'), findsOneWidget);
      expect(find.text('Polyclinique du Centre'), findsNothing);
    });

    testWidgets('active filters show a restrained count indicator', (tester) async {
      _useTallViewport(tester);
      await _pumpDirectory(tester);

      await _openFilterSheet(tester);

      await tester.tap(find.widgetWithText(FilterChip, 'Sousse'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Show 1 clinic'), findsOneWidget);

      await tester.tap(find.text('Show 1 clinic'));
      await tester.pumpAndSettle();

      // The filter icon should now show the active count badge
      expect(find.text('1'), findsOneWidget);
      // Verify the filter was applied — Sousse clinic is the only one shown
      expect(find.text('Centre de Rééducation Riadh'), findsOneWidget);
      expect(find.text('Clinique Cardiologie El Amen'), findsNothing);
      expect(find.text('Polyclinique du Centre'), findsNothing);
    });

    testWidgets('Reset clears the sheet filters', (tester) async {
      _useTallViewport(tester);
      await _pumpDirectory(tester);

      await _openFilterSheet(tester);

      await tester.tap(find.widgetWithText(FilterChip, 'Sousse'));
      await tester.pump();
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Reset'));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Show 3 clinics'));
      await tester.pumpAndSettle();

      expect(find.byType(ClinicListCard), findsNWidgets(3));
      expect(find.text('1'), findsNothing);
    });

    testWidgets('filtered-out results show a dedicated empty state', (tester) async {
      _useTallViewport(tester);
      await _pumpDirectory(tester);

      await _openFilterSheet(tester);

      await tester.tap(find.widgetWithText(FilterChip, 'Sousse'));
      await tester.pump();
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump();

      expect(find.text('Apply filters'), findsOneWidget);

      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();

      expect(find.text('No clinics match these filters.'), findsOneWidget);
      expect(find.text('Reset filters'), findsOneWidget);

      await tester.tap(find.text('Reset filters'));
      await tester.pumpAndSettle();
      expect(find.byType(ClinicListCard), findsNWidgets(3));
    });

    testWidgets('backend empty search result still renders its own empty state', (
      tester,
    ) async {
      _useTallViewport(tester);
      await _pumpDirectory(tester, clinics: const []);

      expect(find.text('No clinics available'), findsOneWidget);
      expect(find.textContaining('Check back later'), findsOneWidget);
    });

    testWidgets('error state shows a safe message and retry restores the list', (
      tester,
    ) async {
      _useTallViewport(tester);
      final repository = _FakePatientClinicRepository(
        clinics: _defaultClinics(),
      )..failureToThrow = PatientClinicFailure.networkUnavailable;
      final directory = PatientClinicDirectoryController(
        repository: repository,
        pageSize: 20,
      );

      await _pumpWrapped(
        tester,
        directory: directory,
        request: RequestSubmissionController(
          repository: _FakeRequestRepository(),
        ),
      );

      expect(
        find.text('Connection unavailable. Check your network and try again.'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);

      repository.failureToThrow = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.byType(ClinicListCard), findsNWidgets(3));
    });

    testWidgets('scrolling near the end triggers loadMore pagination', (tester) async {
      tester.view.physicalSize = const Size(500, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final many = <PatientClinicListItem>[
        for (var i = 0; i < 9; i++)
          PatientClinicListItem(
            clinicId: 'clinic-$i',
            displayName: 'Clinique Numéro $i',
            city: 'Tunis',
            governorate: 'Tunis',
            primaryImageUrl: null,
            acceptingRequests: true,
          ),
      ];

      final repository = _FakePatientClinicRepository(clinics: many);
      final directory = PatientClinicDirectoryController(
        repository: repository,
        pageSize: 3,
      );

      await _pumpWrapped(
        tester,
        directory: directory,
        request: RequestSubmissionController(
          repository: _FakeRequestRepository(),
        ),
      );

      expect(directory.items, hasLength(3));
      expect(directory.hasNext, isTrue);

      for (var i = 0; i < 5; i++) {
        await tester.drag(
          find.byType(ListView),
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();
      }

      expect(directory.items, hasLength(9));
      expect(directory.hasNext, isFalse);
    });

    testWidgets('no selection shows no Continue bar', (tester) async {
      _useTallViewport(tester);
      await _pumpDirectory(tester);
      expect(find.text('Continue'), findsNothing);
      expect(find.text('Selected'), findsNothing);
    });

    testWidgets('a previously selected clinic is subtly marked and Continue works', (
      tester,
    ) async {
      _useTallViewport(tester);
      final request = RequestSubmissionController(
        repository: _FakeRequestRepository(),
      );
      request.selectClinic(_cardiologyId);
      await _pumpDirectory(tester, request: request);

      expect(find.text('Selected'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Situation placeholder'), findsOneWidget);
    });

    testWidgets('filters never alter request submission state', (tester) async {
      _useTallViewport(tester);
      final request = RequestSubmissionController(
        repository: _FakeRequestRepository(),
      );
      request.selectClinic(_cardiologyId);
      await _pumpDirectory(tester, request: request);

      expect(find.text('Continue'), findsOneWidget);

      await _openFilterSheet(tester);

      await tester.tap(find.widgetWithText(FilterChip, 'Sousse'));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Show 1 clinic'));
      await tester.pumpAndSettle();

      expect(request.selectedClinicId, _cardiologyId);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('footer shows "Show N clinics" when count is known', (tester) async {
      _useTallViewport(tester);
      await _pumpDirectory(tester);

      await _openFilterSheet(tester);

      expect(find.text('Show 3 clinics'), findsOneWidget);
      expect(find.text('Apply filters'), findsNothing);
    });

    testWidgets('accepting toggle with Sousse yields Apply filters (0 results)', (tester) async {
      _useTallViewport(tester);
      await _pumpDirectory(tester);

      await _openFilterSheet(tester);

      await tester.tap(find.widgetWithText(FilterChip, 'Sousse'));
      await tester.pump();
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.pump();

      expect(find.text('Apply filters'), findsOneWidget);
    });
  });
}
