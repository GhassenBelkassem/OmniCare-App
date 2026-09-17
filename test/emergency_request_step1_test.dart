import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:omnicare_mobile/core/api/family_api.dart';
import 'package:omnicare_mobile/core/models/family_models.dart';
import 'package:omnicare_mobile/core/models/patient_profile.dart';
import 'package:omnicare_mobile/core/network/api_exception.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/emergency/emergency_request_step1.dart';
import 'package:omnicare_mobile/features/home/add_family_member_screen.dart';
import 'package:omnicare_mobile/features/request_flow/widgets/care_subject_card.dart';
import 'package:omnicare_mobile/providers/family_provider.dart';
import 'package:omnicare_mobile/providers/user_provider.dart';
import 'package:omnicare_mobile/repositories/family_repository.dart';

class _FakeFamilyRepository extends FamilyRepository {
  _FakeFamilyRepository({this.members = const [], this.createError})
    : super(api: FamilyApi());

  final List<FamilyMember> members;
  final Object? createError;
  int createCalls = 0;

  @override
  Future<List<FamilyMember>> getFamilyMembers() async => members;

  @override
  Future<FamilyMember> createFamilyMember({
    required String firstName,
    required String lastName,
    required DateTime dateOfBirth,
    required String gender,
    required String relationship,
    String? photoUrl,
  }) async {
    createCalls++;
    final error = createError;
    if (error != null) throw error;
    return FamilyMember(
      id: 'created-$createCalls',
      accountHolderId: 'holder',
      firstName: firstName,
      lastName: lastName,
      dateOfBirth: dateOfBirth,
      gender: gender,
      relationship: relationship,
      graduated: false,
      patientId: 'backend-created-$createCalls',
      photoUrl: photoUrl,
    );
  }
}

class _RecordingObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
    super.didPush(route, previousRoute);
  }
}

FamilyMember _member({
  required String id,
  required String firstName,
  required String lastName,
  String relationship = FamilyRelationships.parent,
  String? patientId,
}) {
  return FamilyMember(
    id: id,
    accountHolderId: 'holder',
    firstName: firstName,
    lastName: lastName,
    dateOfBirth: DateTime(2014, 6, 15),
    gender: 'F',
    relationship: relationship,
    graduated: false,
    patientId: patientId,
  );
}

UserProvider _userProvider() {
  return UserProvider()..setPatientProfile(
    const PatientProfile(
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
    ),
  );
}

Widget _buildApp({
  _FakeFamilyRepository? repository,
  _RecordingObserver? observer,
}) {
  final familyRepository = repository ?? _FakeFamilyRepository();
  final family = FamilyProvider(repository: familyRepository);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<UserProvider>.value(value: _userProvider()),
      ChangeNotifierProvider<FamilyProvider>.value(value: family),
    ],
    child: MaterialApp(
      theme: buildOmniTheme(),
      navigatorObservers: observer == null ? const [] : [observer],
      home: const Scaffold(body: EmergencyRequestStep1()),
      onGenerateRoute: (settings) {
        if (settings.name == '/emergency-step2') {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => const Scaffold(body: Text('Step 2')),
          );
        }
        return null;
      },
    ),
  );
}

Future<void> _openOther(WidgetTester tester) async {
  await tester.tap(find.text('Autre personne'));
  await tester.pumpAndSettle();
}

Future<void> _fillFamilyForm(WidgetTester tester) async {
  final textFields = find.byType(TextFormField);
  await tester.enterText(textFields.at(0), 'Aicha');
  await tester.enterText(textFields.at(1), 'Martin');
  await tester.tap(find.text('Choisir une date'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('7').last);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Femme'));
  final form = find.byKey(const ValueKey('family-member-form-scroll'));
  for (var index = 0; index < 5; index++) {
    await tester.fling(form, const Offset(0, -900), 5000);
    await tester.pump();
  }
  final relationship = find.byWidgetPredicate(
    (widget) => widget is DropdownButtonFormField<String>,
    description: 'family relationship dropdown',
  );
  await tester.ensureVisible(relationship);
  await tester.tap(relationship);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Parent').last);
  await tester.pump();
}

Future<void> _scrollFormToSubmit(WidgetTester tester) async {
  for (var index = 0; index < 4; index++) {
    await tester.drag(
      find.byKey(const ValueKey('family-member-form-scroll')),
      const Offset(0, -320),
    );
    await tester.pump();
  }
}

Future<void> _tapAdd(WidgetTester tester) async {
  final add = find.text('Ajouter', skipOffstage: false);
  await tester.ensureVisible(add);
  await tester.tap(add);
}

void main() {
  group('EmergencyRequestStep1 subject selection', () {
    testWidgets('renders self, family members, and Autre personne', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildApp(
          repository: _FakeFamilyRepository(
            members: [
              _member(id: 'f1', firstName: 'Aicha', lastName: 'Martin'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sarah Martin'), findsOneWidget);
      expect(find.text('Aicha Martin'), findsOneWidget);
      expect(find.text('Autre personne'), findsOneWidget);
      expect(find.text('Qui a besoin de soins ?'), findsOneWidget);
    });

    testWidgets('Continue is disabled until a subject is selected', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
    });

    testWidgets('self selection is explicit and does not auto-navigate', (
      tester,
    ) async {
      final observer = _RecordingObserver();
      await tester.pumpWidget(_buildApp(observer: observer));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sarah Martin'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        observer.pushedRoutes.where(
          (route) => route.settings.name == '/emergency-step2',
        ),
        isEmpty,
      );
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull,
      );
      final cards = tester
          .widgetList<CareSubjectCard>(find.byType(CareSubjectCard))
          .toList();
      expect(cards.where((card) => card.selected), hasLength(1));
      expect(cards.singleWhere((card) => card.selected).title, 'Sarah Martin');
    });

    testWidgets('existing family selection forwards the legacy payload', (
      tester,
    ) async {
      final observer = _RecordingObserver();
      final member = _member(
        id: 'f1',
        firstName: 'Aicha',
        lastName: 'Martin',
        patientId: 'backend-f1',
      );
      await tester.pumpWidget(
        _buildApp(
          repository: _FakeFamilyRepository(members: [member]),
          observer: observer,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aicha Martin'));
      await tester.pump();
      tester
          .widget<ElevatedButton>(find.byType(ElevatedButton))
          .onPressed!
          .call();
      await tester.pumpAndSettle();

      final route = observer.pushedRoutes.lastWhere(
        (route) => route.settings.name == '/emergency-step2',
      );
      final args = route.settings.arguments! as Map<String, dynamic>;
      expect(args['patientId'], 'f1');
      expect(args['backendPatientId'], 'backend-f1');
      expect(args['patientName'], 'Aicha Martin');
      expect(args['patientType'], 'family');
    });

    testWidgets('Autre personne opens the shared family-member form', (
      tester,
    ) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();
      await _openOther(tester);

      expect(find.byType(AddFamilyMemberScreen), findsOneWidget);
      expect(find.text('Ajouter un proche'), findsOneWidget);
      expect(find.text('Prénom'), findsOneWidget);
      expect(find.text('Nom'), findsOneWidget);
      expect(find.text('Date de naissance'), findsOneWidget);
      expect(find.text('Genre'), findsOneWidget);
      expect(find.text('Lien familial'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.text('Ajouter', skipOffstage: false), findsOneWidget);
    });

    testWidgets('incomplete form cannot submit', (tester) async {
      final repository = _FakeFamilyRepository();
      await tester.pumpWidget(_buildApp(repository: repository));
      await tester.pumpAndSettle();
      await _openOther(tester);
      await _scrollFormToSubmit(tester);
      await _tapAdd(tester);
      await tester.pumpAndSettle();

      expect(repository.createCalls, 0);
      expect(find.text('Ajouter un proche'), findsOneWidget);
      expect(find.textContaining('Saisissez'), findsWidgets);
    });

    testWidgets(
      'successful creation persists and auto-selects the new member',
      (tester) async {
        final repository = _FakeFamilyRepository();
        await tester.pumpWidget(_buildApp(repository: repository));
        await tester.pumpAndSettle();
        await _openOther(tester);
        await _fillFamilyForm(tester);
        await _scrollFormToSubmit(tester);
        await _tapAdd(tester);
        await tester.pumpAndSettle();

        expect(repository.createCalls, 1);
        expect(find.text('Aicha Martin'), findsOneWidget);
        final cards = tester
            .widgetList<CareSubjectCard>(find.byType(CareSubjectCard))
            .toList();
        expect(
          cards.singleWhere((card) => card.selected).title,
          'Aicha Martin',
        );
        expect(
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
          isNotNull,
        );
      },
    );

    testWidgets('newly-created member uses the existing family payload path', (
      tester,
    ) async {
      final observer = _RecordingObserver();
      await tester.pumpWidget(
        _buildApp(repository: _FakeFamilyRepository(), observer: observer),
      );
      await tester.pumpAndSettle();
      await _openOther(tester);
      await _fillFamilyForm(tester);
      await _scrollFormToSubmit(tester);
      await _tapAdd(tester);
      await tester.pumpAndSettle();

      tester
          .widget<ElevatedButton>(find.byType(ElevatedButton))
          .onPressed!
          .call();
      await tester.pumpAndSettle();
      final route = observer.pushedRoutes.lastWhere(
        (route) => route.settings.name == '/emergency-step2',
      );
      final args = route.settings.arguments! as Map<String, dynamic>;
      expect(args['patientId'], 'created-1');
      expect(args['backendPatientId'], 'backend-created-1');
      expect(args['patientName'], 'Aicha Martin');
      expect(args['patientType'], 'family');
    });

    testWidgets('failed creation preserves data and exposes safe retry state', (
      tester,
    ) async {
      final repository = _FakeFamilyRepository(
        createError: const ApiException('Impossible d’enregistrer le membre.'),
      );
      await tester.pumpWidget(_buildApp(repository: repository));
      await tester.pumpAndSettle();
      await _openOther(tester);
      await _fillFamilyForm(tester);
      await _scrollFormToSubmit(tester);
      await _tapAdd(tester);
      await tester.pumpAndSettle();

      expect(repository.createCalls, 1);
      expect(find.text('Ajouter un proche'), findsOneWidget);
      expect(find.text('Impossible d’enregistrer le membre.'), findsOneWidget);
      expect(find.text('Aicha'), findsOneWidget);
      expect(find.text('Martin'), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
    });

    testWidgets('double-tapping Ajouter does not duplicate creation', (
      tester,
    ) async {
      final repository = _FakeFamilyRepository();
      await tester.pumpWidget(_buildApp(repository: repository));
      await tester.pumpAndSettle();
      await _openOther(tester);
      await _fillFamilyForm(tester);
      await _scrollFormToSubmit(tester);
      final addButton = find.text('Ajouter', skipOffstage: false);
      await tester.ensureVisible(addButton);
      await tester.tap(addButton);
      await tester.tap(addButton, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(repository.createCalls, 1);
      expect(find.text('Aicha Martin'), findsOneWidget);
    });

    testWidgets('cancelling creation leaves the previous selection unchanged', (
      tester,
    ) async {
      final repository = _FakeFamilyRepository();
      await tester.pumpWidget(_buildApp(repository: repository));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sarah Martin'));
      await tester.pump();
      await _openOther(tester);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(repository.createCalls, 0);
      final cards = tester
          .widgetList<CareSubjectCard>(find.byType(CareSubjectCard))
          .toList();
      expect(cards.singleWhere((card) => card.selected).title, 'Sarah Martin');
    });

    testWidgets('many family members remain scrollable without overflow', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 560));
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      final members = List.generate(
        7,
        (index) =>
            _member(id: 'f$index', firstName: 'Family', lastName: '$index'),
      );
      await tester.pumpWidget(
        _buildApp(repository: _FakeFamilyRepository(members: members)),
      );
      await tester.pumpAndSettle();
      for (var index = 0; index < 8; index++) {
        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await tester.pump();
      }

      expect(find.byType(ListView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
