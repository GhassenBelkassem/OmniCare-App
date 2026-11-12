import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:omnicare_mobile/core/api/family_api.dart';
import 'package:omnicare_mobile/core/models/family_models.dart';
import 'package:omnicare_mobile/core/models/patient_profile.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_care_subject.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_clinical_intake_draft.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_doctor_detail.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_doctor_detail_screen.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_doctor_directory_screen.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_doctor_fixture.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_flow_controller.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_flow_shell.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_confirmation_screen.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_review.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_source.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_state.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_waiting_screen.dart';
import 'package:omnicare_mobile/providers/family_provider.dart';
import 'package:omnicare_mobile/providers/user_provider.dart';
import 'package:omnicare_mobile/repositories/family_repository.dart';
import 'package:omnicare_mobile/core/result/result.dart';

class _MutableFamilyRepository extends FamilyRepository {
  _MutableFamilyRepository({List<FamilyMember> members = const []})
    : members = List.of(members),
      super(api: FamilyApi());

  List<FamilyMember> members;

  @override
  Future<Result<List<FamilyMember>>> getFamilyMembers() async =>
      Ok(List.of(members));
}

class _ControlledSubmissionSource extends UrgentCabinetRequestSource {
  final completer = Completer<UrgentCabinetSubmissionOutcome>();
  int calls = 0;

  @override
  bool get isDevelopmentFixture => true;

  @override
  Future<UrgentCabinetSubmissionOutcome> submit(
    UrgentCabinetRequestReview review,
  ) {
    calls++;
    return completer.future;
  }
}

PatientProfile _profile() {
  return const PatientProfile(
    userId: 'patient-user-1',
    firstName: 'Sarah',
    lastName: 'Martin',
    displayName: 'Sarah Martin',
    dateOfBirth: null,
    gender: null,
    photoUrl: null,
    primaryPhone: VerifiedContact(value: '+21698123456', verified: true),
    primaryEmail: VerifiedContact(value: 'sarah@example.tn', verified: true),
    onboardingCompleted: true,
    onboardingStep: 4,
    preferredLanguage: 'fr',
    notifications: ProfileNotificationPreferences(
      medications: true,
      appointments: true,
      passport: true,
    ),
    updatedAt: null,
  );
}

FamilyMember _familyMember() {
  return FamilyMember(
    id: 'family-1',
    accountHolderId: 'patient-user-1',
    firstName: 'Aicha',
    lastName: 'Martin',
    dateOfBirth: DateTime(2014, 6, 15),
    gender: 'F',
    relationship: FamilyRelationships.parent,
    graduated: false,
  );
}

UrgentCabinetFlowController _selectedController({
  UrgentCabinetCareSubject subject = const UrgentCabinetCareSubject.self(),
  String doctorId = 'p4-demo-doctor-amine-ben-salah',
  String cabinetId = 'p4-demo-cabinet-lac-1',
}) {
  final controller = UrgentCabinetFlowController(accountId: 'patient-user-1')
    ..updateSubject(subject)
    ..selectDoctor(doctorId: doctorId, cabinetId: cabinetId);
  final detail = UrgentCabinetDoctorFixtureSource.developmentDoctorDetails
      .where((candidate) => candidate.doctorId == doctorId)
      .firstOrNull;
  if (detail != null && detail.cabinetById(cabinetId) != null) {
    controller.captureQuoteSnapshot(detail);
    controller.saveClinicalIntake(
      UrgentCabinetClinicalIntakeDraft(
        careSubject: subject,
        doctorId: doctorId,
        cabinetId: cabinetId,
        rawAnatomicalRegionIds: const ['front-head'],
        painScore: 6,
        shortDescription: 'Douleur aiguë depuis ce matin.',
      ),
    );
  }
  return controller;
}

UrgentCabinetDoctorDetail get _detail =>
    UrgentCabinetDoctorFixtureSource.developmentDoctorDetails.first;

UrgentCabinetFeeQuote get _fee =>
    UrgentCabinetDoctorFixtureSource.developmentFeeQuotes.first;

Future<FamilyProvider> _familyProvider(
  _MutableFamilyRepository repository,
) async {
  final provider = FamilyProvider(repository: repository);
  await provider.loadFamilyMembers();
  return provider;
}

Widget _buildConfirmation({
  required UrgentCabinetFlowController controller,
  required FamilyProvider familyProvider,
  UrgentCabinetDoctorSource source = const UrgentCabinetDoctorFixtureSource(),
  UrgentCabinetRequestSource? requestSource,
  double textScale = 1,
}) {
  final user = UserProvider()..setPatientProfile(_profile());
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<UserProvider>.value(value: user),
      ChangeNotifierProvider<FamilyProvider>.value(value: familyProvider),
      ChangeNotifierProvider<UrgentCabinetFlowController>.value(
        value: controller,
      ),
    ],
    child: MaterialApp(
      theme: buildOmniTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: UrgentCabinetRequestConfirmationScreen(
        source: source,
        requestSource:
            requestSource ?? const UrgentCabinetDevelopmentRequestSource(),
      ),
    ),
  );
}

Widget _buildFlow({
  required FamilyProvider familyProvider,
  UrgentCabinetDoctorSource source = const UrgentCabinetDoctorFixtureSource(),
  UrgentCabinetRequestSource requestSource =
      const UrgentCabinetDevelopmentRequestSource(),
}) {
  final user = UserProvider()..setPatientProfile(_profile());
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<UserProvider>.value(value: user),
      ChangeNotifierProvider<FamilyProvider>.value(value: familyProvider),
    ],
    child: MaterialApp(
      theme: buildOmniTheme(),
      home: Scaffold(
        body: UrgentCabinetFlowShell(
          doctorSource: source,
          requestSource: requestSource,
        ),
      ),
    ),
  );
}

Future<void> _completeSymptomIntake(WidgetTester tester) async {
  final body = find.byKey(const ValueKey('emergency-body-front'));
  await tester.ensureVisible(body);
  final bodyRect = tester.getRect(body);
  await tester.tapAt(
    Offset(
      bodyRect.left + bodyRect.width * .42,
      bodyRect.top + bodyRect.height * .2,
    ),
  );
  await tester.pump();
  final painSlider = find.byType(Slider);
  await tester.ensureVisible(painSlider);
  await tester.drag(painSlider, const Offset(24, 0));
  await tester.pump();
  final description = find.byKey(const ValueKey('emergency-description'));
  await tester.ensureVisible(description);
  await tester.enterText(description, 'Douleur aiguë depuis ce matin.');
  await tester.pump();
  final continueButton = find.byKey(const ValueKey('emergency-continue'));
  await tester.ensureVisible(continueButton);
  await tester.tap(continueButton);
  await tester.pumpAndSettle();
}

void main() {
  group('UrgentCabinetFeeQuote and review validation', () {
    test('uses integer milli-TND formatting and permits zero', () {
      expect(formatUrgentCabinetFee(_fee), '75,000 DT');
      const zero = UrgentCabinetFeeQuote(
        doctorId: 'doctor-1',
        cabinetId: 'cabinet-1',
        amountMilliTnd: 0,
        currencyCode: 'TND',
        provenance: UrgentCabinetFeeProvenance.service,
      );
      expect(zero.isStructurallyValid(), isTrue);
      expect(formatUrgentCabinetFee(zero), '0,000 DT');
    });

    test('rejects mismatched, negative, and expired fee quotes', () {
      final cabinet = _detail.cabinetById('p4-demo-cabinet-lac-1');

      UrgentCabinetReviewValidation validate(UrgentCabinetFeeQuote quote) {
        return validateUrgentCabinetRequestReview(
          careSubject: const UrgentCabinetCareSubject.self(),
          patientDisplayName: 'Sarah Martin',
          selectedDoctorId: _detail.doctorId,
          selectedCabinetId: cabinet!.cabinetId,
          doctor: _detail,
          cabinet: cabinet,
          feeQuote: quote,
          developmentFixturesEnabled: true,
          now: DateTime.utc(2026, 10, 12),
        );
      }

      expect(
        validate(
          UrgentCabinetFeeQuote(
            doctorId: 'another-doctor',
            cabinetId: _fee.cabinetId,
            amountMilliTnd: 75000,
            currencyCode: 'TND',
            provenance: UrgentCabinetFeeProvenance.developmentFixture,
          ),
        ).issue,
        UrgentCabinetReviewIssue.feeDoctorMismatch,
      );
      expect(
        validate(
          UrgentCabinetFeeQuote(
            doctorId: _fee.doctorId,
            cabinetId: _fee.cabinetId,
            amountMilliTnd: -1,
            currencyCode: 'TND',
            provenance: UrgentCabinetFeeProvenance.developmentFixture,
          ),
        ).issue,
        UrgentCabinetReviewIssue.invalidFee,
      );
      expect(
        validate(
          UrgentCabinetFeeQuote(
            doctorId: _fee.doctorId,
            cabinetId: _fee.cabinetId,
            amountMilliTnd: 75000,
            currencyCode: 'TND',
            provenance: UrgentCabinetFeeProvenance.developmentFixture,
            expiresAt: DateTime.utc(2026, 10, 12),
          ),
        ).issue,
        UrgentCabinetReviewIssue.expiredFee,
      );
    });
  });

  testWidgets('renders a valid SELF review with an enabled submit action', (
    tester,
  ) async {
    final family = await _familyProvider(_MutableFamilyRepository());
    final controller = _selectedController();
    await tester.pumpWidget(
      _buildConfirmation(controller: controller, familyProvider: family),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Vérifier la demande'), findsOneWidget);
    expect(find.text('Votre demande urgente au cabinet'), findsOneWidget);
    expect(find.text('Sarah Martin'), findsOneWidget);
    expect(find.text('Dr. Amine Ben Salah'), findsOneWidget);
    expect(find.text('Médecine générale'), findsOneWidget);
    expect(find.text('Cabinet Les Berges du Lac'), findsOneWidget);
    expect(find.text('75,000 DT'), findsOneWidget);
    expect(find.text('Tarif de démonstration'), findsOneWidget);
    expect(find.text('Attendez la confirmation du médecin'), findsOneWidget);
    expect(find.text('Envoyer la demande'), findsOneWidget);
    expect(find.text('Envoi disponible avec P4-CAB-02'), findsNothing);

    final submit = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('urgent-cabinet-confirmation-submit')),
    );
    expect(submit.onPressed, isNotNull);
    controller.selectDoctor(
      doctorId: 'p4-demo-doctor-ines-trabelsi',
      cabinetId: 'p4-demo-cabinet-menzah-1',
    );
    await tester.pump();
    expect(
      tester
          .widget<ElevatedButton>(
            find.byKey(const ValueKey('urgent-cabinet-confirmation-submit')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('confirmation replaces itself with the static waiting route', (
    tester,
  ) async {
    final family = await _familyProvider(_MutableFamilyRepository());
    await tester.pumpWidget(_buildFlow(familyProvider: family));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sarah Martin'));
    await tester.pump();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dr. Amine Ben Salah'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cabinet'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('urgent-cabinet-detail-continue')),
    );
    await tester.pumpAndSettle();
    await _completeSymptomIntake(tester);

    await tester.tap(
      find.byKey(const ValueKey('urgent-cabinet-confirmation-submit')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(UrgentCabinetRequestConfirmationScreen), findsNothing);
    expect(find.byType(UrgentCabinetRequestWaitingScreen), findsOneWidget);
    expect(find.text('En attente de la réponse du médecin'), findsOneWidget);
  });

  testWidgets('submitting disables actions and blocks route back', (
    tester,
  ) async {
    final family = await _familyProvider(_MutableFamilyRepository());
    final controller = _selectedController();
    final requestSource = _ControlledSubmissionSource();
    await tester.pumpWidget(
      _buildConfirmation(
        controller: controller,
        familyProvider: family,
        requestSource: requestSource,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('urgent-cabinet-confirmation-submit')),
    );
    await tester.pump();

    expect(controller.isSubmitting, isTrue);
    expect(requestSource.calls, 1);
    expect(
      tester
          .widget<ElevatedButton>(
            find.byKey(const ValueKey('urgent-cabinet-confirmation-submit')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.arrow_back_rounded),
          )
          .onPressed,
      isNull,
    );

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(UrgentCabinetRequestConfirmationScreen), findsOneWidget);
    expect(controller.isSubmitting, isTrue);

    controller.ensureAccount('patient-user-2');
    requestSource.completer.complete(
      const UrgentCabinetSubmissionAcknowledged(),
    );
    await tester.pump();
    expect(controller.requestPhase, UrgentCabinetRequestPhase.draft);
  });

  testWidgets('shows a real family member and blocks after deletion', (
    tester,
  ) async {
    final repository = _MutableFamilyRepository(members: [_familyMember()]);
    final family = await _familyProvider(repository);
    final controller = _selectedController(
      subject: UrgentCabinetCareSubject.familyMember('family-1'),
    );
    await tester.pumpWidget(
      _buildConfirmation(controller: controller, familyProvider: family),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aicha Martin'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(
            find.byKey(const ValueKey('urgent-cabinet-confirmation-submit')),
          )
          .onPressed,
      isNotNull,
    );

    repository.members = const [];
    await family.loadFamilyMembers();
    await tester.pumpAndSettle();

    expect(
      find.textContaining('La personne sélectionnée n’est plus disponible'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<ElevatedButton>(
            find.byKey(const ValueKey('urgent-cabinet-confirmation-submit')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('a missing captured fee blocks the primary action', (
    tester,
  ) async {
    final family = await _familyProvider(_MutableFamilyRepository());
    final controller = UrgentCabinetFlowController(accountId: 'patient-user-1')
      ..selectSelf()
      ..selectDoctor(
        doctorId: 'p4-demo-doctor-amine-ben-salah',
        cabinetId: 'p4-demo-cabinet-lac-1',
      );
    await tester.pumpWidget(
      _buildConfirmation(controller: controller, familyProvider: family),
    );
    await tester.pumpAndSettle();

    expect(find.text('Indisponible'), findsOneWidget);
    expect(
      tester
          .widget<ElevatedButton>(
            find.byKey(const ValueKey('urgent-cabinet-confirmation-submit')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('source-unavailable state never exposes a synthetic price', (
    tester,
  ) async {
    final family = await _familyProvider(_MutableFamilyRepository());
    await tester.pumpWidget(
      _buildConfirmation(
        controller: _selectedController(),
        familyProvider: family,
        source: const UrgentCabinetDoctorUnavailableSource(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('urgent-cabinet-confirmation-unavailable')),
      findsOneWidget,
    );
    expect(find.text('75,000 DT'), findsNothing);
    expect(
      tester
          .widget<ElevatedButton>(
            find.byKey(const ValueKey('urgent-cabinet-confirmation-submit')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'details push confirmation and back preserves detail and search',
    (tester) async {
      final family = await _familyProvider(_MutableFamilyRepository());
      await tester.pumpWidget(_buildFlow(familyProvider: family));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sarah Martin'));
      await tester.pump();
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      expect(find.byType(UrgentCabinetDoctorDirectoryScreen), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'amine');
      await tester.pump();
      await tester.tap(find.text('Dr. Amine Ben Salah'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cabinet'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('urgent-cabinet-detail-continue')),
      );
      await tester.pumpAndSettle();
      await _completeSymptomIntake(tester);

      expect(
        find.byType(UrgentCabinetRequestConfirmationScreen),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('urgent-cabinet-confirmation-next-dialog')),
        findsNothing,
      );

      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();
      expect(find.byType(UrgentCabinetDoctorDetailScreen), findsOneWidget);
      expect(
        find.byKey(
          const PageStorageKey('urgent-cabinet-detail-cabinet-scroll'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('urgent-cabinet-detail-back')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(UrgentCabinetDoctorDirectoryScreen), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'amine',
      );
    },
  );

  testWidgets('small screen and large text remain overflow-free', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final family = await _familyProvider(_MutableFamilyRepository());
    await tester.pumpWidget(
      _buildConfirmation(
        controller: _selectedController(),
        familyProvider: family,
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('urgent-cabinet-confirmation-submit')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
