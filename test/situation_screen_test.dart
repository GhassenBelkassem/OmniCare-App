import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

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
import 'package:omnicare_mobile/features/request_flow/screens/situation_screen.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

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
  }) async =>
      PatientClinicDetail(
        clinicId: clinicId,
        displayName: 'Clinique Les Oliviers',
        about: 'A test clinic.',
        gallery: const [],
        acceptingRequests: true,
      );
}

// ---------------------------------------------------------------------------
// Pump helper
// ---------------------------------------------------------------------------

Future<void> _pumpSituationScreen(
  WidgetTester tester, {
  RequestSubmissionController? request,
  PatientClinicDirectoryController? directory,
}) async {
  final requestController =
      request ?? RequestSubmissionController(repository: _FakeRequestRepository());
  final directoryController = directory ??
      PatientClinicDirectoryController(
        repository: _FakePatientClinicRepository(),
      );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<RequestSubmissionController>.value(
          value: requestController,
        ),
        ChangeNotifierProvider<PatientClinicDirectoryController>.value(
          value: directoryController,
        ),
      ],
      child: MaterialApp(
        theme: buildOmniTheme(),
        home: const SituationScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SituationScreen — Page 04 Care Type UI', () {
    testWidgets('new title renders', (tester) async {
      await _pumpSituationScreen(tester);
      expect(
        find.text('What kind of care do you need?'),
        findsOneWidget,
      );
    });

    testWidgets('white canvas', (tester) async {
      await _pumpSituationScreen(tester);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, OmniColors.pageBackground);
    });

    testWidgets('Planned care renders', (tester) async {
      await _pumpSituationScreen(tester);
      expect(find.text('Planned care'), findsOneWidget);
      expect(
        find.text('I can visit the clinic and my situation is not urgent.'),
        findsOneWidget,
      );
    });

    testWidgets('Urgent care renders', (tester) async {
      await _pumpSituationScreen(tester);
      expect(find.text('Urgent care'), findsOneWidget);
      expect(
        find.text(
            'I need medical attention soon and can safely reach the clinic.'),
        findsOneWidget,
      );
    });

    testWidgets('I need medical transport renders', (tester) async {
      await _pumpSituationScreen(tester);
      expect(find.text('I need medical transport'), findsOneWidget);
      expect(
        find.text(
            'I need help reaching medical care because I cannot travel normally.'),
        findsOneWidget,
      );
    });

    testWidgets('old user-facing labels are removed', (tester) async {
      await _pumpSituationScreen(tester);
      expect(find.text('Appointment'), findsNothing);
      expect(find.text('Transport assistance'), findsNothing);
      // "Urgent" alone should not appear (only "Urgent care")
      expect(find.text('Urgent'), findsNothing);
    });

    testWidgets('each UI option maps to the correct domain value',
        (tester) async {
      final request = RequestSubmissionController(
        repository: _FakeRequestRepository(),
      );
      await _pumpSituationScreen(tester, request: request);

      // Tap Planned care
      await tester.tap(find.text('Planned care'));
      await tester.pumpAndSettle();
      expect(request.selectedSituation, RequestSituation.appointment);

      // Tap Urgent care
      await tester.tap(find.text('Urgent care'));
      await tester.pumpAndSettle();
      expect(request.selectedSituation, RequestSituation.urgent);

      // Scroll to and tap I need medical transport
      await tester.scrollUntilVisible(
        find.text('I need medical transport'),
        100,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('I need medical transport'));
      await tester.pumpAndSettle();
      expect(request.selectedSituation, RequestSituation.ambulance);
    });

    testWidgets('no option selected initially', (tester) async {
      final request = RequestSubmissionController(
        repository: _FakeRequestRepository(),
      );
      await _pumpSituationScreen(tester, request: request);
      expect(request.selectedSituation, isNull);
    });

    testWidgets('Continue disabled before selection', (tester) async {
      await _pumpSituationScreen(tester);
      final continueButton = tester.widget<ElevatedButton>(
        find.byWidgetPredicate(
          (w) => w is ElevatedButton && (w.child as Text?)?.data == 'Continue',
        ),
      );
      expect(continueButton.onPressed, isNull);
    });

    testWidgets('selecting Planned enables Continue', (tester) async {
      final request = RequestSubmissionController(
        repository: _FakeRequestRepository(),
      );
      await _pumpSituationScreen(tester, request: request);

      await tester.tap(find.text('Planned care'));
      await tester.pumpAndSettle();

      final continueButton = tester.widget<ElevatedButton>(
        find.byWidgetPredicate(
          (w) => w is ElevatedButton && (w.child as Text?)?.data == 'Continue',
        ),
      );
      expect(continueButton.onPressed, isNotNull);
    });

    testWidgets('selecting Urgent enables Continue', (tester) async {
      final request = RequestSubmissionController(
        repository: _FakeRequestRepository(),
      );
      await _pumpSituationScreen(tester, request: request);

      await tester.tap(find.text('Urgent care'));
      await tester.pumpAndSettle();

      final continueButton = tester.widget<ElevatedButton>(
        find.byWidgetPredicate(
          (w) => w is ElevatedButton && (w.child as Text?)?.data == 'Continue',
        ),
      );
      expect(continueButton.onPressed, isNotNull);
    });

    testWidgets('selecting Transport enables Continue', (tester) async {
      final request = RequestSubmissionController(
        repository: _FakeRequestRepository(),
      );
      await _pumpSituationScreen(tester, request: request);

      // Scroll to transport option before tapping
      await tester.scrollUntilVisible(
        find.text('I need medical transport'),
        100,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('I need medical transport'));
      await tester.pumpAndSettle();

      final continueButton = tester.widget<ElevatedButton>(
        find.byWidgetPredicate(
          (w) => w is ElevatedButton && (w.child as Text?)?.data == 'Continue',
        ),
      );
      expect(continueButton.onPressed, isNotNull);
    });

    testWidgets('tapping selection does not navigate immediately',
        (tester) async {
      await _pumpSituationScreen(tester);

      await tester.tap(find.text('Planned care'));
      await tester.pumpAndSettle();

      // Still on the situation screen (title should still be visible)
      expect(
        find.text('What kind of care do you need?'),
        findsOneWidget,
      );
    });

    testWidgets('Help me choose opens bottom sheet', (tester) async {
      await _pumpSituationScreen(tester);

      // Scroll to Help me choose before tapping
      await tester.scrollUntilVisible(
        find.text('Help me choose'),
        100,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Help me choose'));
      await tester.pumpAndSettle();

      expect(find.text('Which option fits best?'), findsOneWidget);
    });

    testWidgets('Help sheet does not mutate request situation', (tester) async {
      final request = RequestSubmissionController(
        repository: _FakeRequestRepository(),
      );
      await _pumpSituationScreen(tester, request: request);

      // Scroll to Help me choose before tapping
      await tester.scrollUntilVisible(
        find.text('Help me choose'),
        100,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Help me choose'));
      await tester.pumpAndSettle();

      // Situation should still be null (no automatic selection)
      expect(request.selectedSituation, isNull);
    });

    testWidgets('Got it closes sheet', (tester) async {
      // Use a taller viewport so the full sheet is visible
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pumpSituationScreen(tester);

      // Scroll to Help me choose before tapping
      await tester.scrollUntilVisible(
        find.text('Help me choose'),
        100,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Help me choose'));
      await tester.pumpAndSettle();

      expect(find.text('Which option fits best?'), findsOneWidget);

      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();

      expect(find.text('Which option fits best?'), findsNothing);
    });

    testWidgets('all three explanations render in help sheet', (tester) async {
      await _pumpSituationScreen(tester);

      // Scroll to Help me choose before tapping
      await tester.scrollUntilVisible(
        find.text('Help me choose'),
        100,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Help me choose'));
      await tester.pumpAndSettle();

      expect(find.text('Planned care'), findsWidgets);
      expect(find.text('Urgent care'), findsWidgets);
      expect(find.text('Medical transport'), findsOneWidget);
    });

    testWidgets('emergency safety note renders', (tester) async {
      // Use a taller viewport so the full sheet is visible
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _pumpSituationScreen(tester);

      // Scroll to Help me choose before tapping
      await tester.scrollUntilVisible(
        find.text('Help me choose'),
        100,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Help me choose'));
      await tester.pumpAndSettle();

      expect(
        find.text('Need immediate emergency help?'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Use emergency services for immediate danger instead of waiting for a clinic request.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('subtitle renders', (tester) async {
      await _pumpSituationScreen(tester);
      expect(
        find.text(
            'This helps the clinic prepare and route your request.'),
        findsOneWidget,
      );
    });

    testWidgets('request context shows for self when clinic detail available',
        (tester) async {
      await _pumpSituationScreen(tester);
      expect(find.textContaining('For Me'), findsOneWidget);
    });

    testWidgets('page 01/02/03 behavior unaffected — SituationScreen is standalone',
        (tester) async {
      // Verify the screen builds without errors and has its own Scaffold
      await _pumpSituationScreen(tester);
      expect(find.byType(SituationScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('no backend/API changes — controller uses same domain values',
        (tester) async {
      final request = RequestSubmissionController(
        repository: _FakeRequestRepository(),
      );
      await _pumpSituationScreen(tester, request: request);

      // Select each and verify exact wire values
      await tester.tap(find.text('Planned care'));
      await tester.pumpAndSettle();
      expect(request.selectedSituation!.wireValue, 'APPOINTMENT');

      await tester.tap(find.text('Urgent care'));
      await tester.pumpAndSettle();
      expect(request.selectedSituation!.wireValue, 'URGENT');

      // Scroll to transport before tapping
      await tester.scrollUntilVisible(
        find.text('I need medical transport'),
        100,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('I need medical transport'));
      await tester.pumpAndSettle();
      expect(request.selectedSituation!.wireValue, 'AMBULANCE');
    });

    testWidgets('semantic labels include selected state', (tester) async {
      await _pumpSituationScreen(tester);

      // Check Planned care semantics before selection
      final plannedSemantics = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label?.contains('Planned care') == true,
      );
      expect(plannedSemantics, findsOneWidget);

      // Select Planned care
      await tester.tap(find.text('Planned care'));
      await tester.pumpAndSettle();

      // Check that selected state is reflected
      final selectedSemantics = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label?.contains('Selected') == true,
      );
      expect(selectedSemantics, findsWidgets);
    });
  });
}
