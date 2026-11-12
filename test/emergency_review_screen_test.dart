import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import 'package:omnicare_mobile/core/api/family_api.dart';
import 'package:omnicare_mobile/core/models/family_models.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/emergency/emergency_request_step3.dart';
import 'package:omnicare_mobile/features/emergency/emergency_review_screen.dart';
import 'package:omnicare_mobile/providers/family_provider.dart';
import 'package:omnicare_mobile/providers/user_provider.dart';
import 'package:omnicare_mobile/repositories/family_repository.dart';
import 'package:omnicare_mobile/core/result/result.dart';

const _locationPayload = <String, dynamic>{
  'type': 'manual',
  'source': 'manual',
  'latitude': 36.8712,
  'longitude': 10.3418,
  'address': '12 Rue des Jasmins, La Marsa, Tunis',
  'fullAddress': '12 Rue des Jasmins, La Marsa, Tunis',
  'street': '12 Rue des Jasmins',
  'city': 'La Marsa',
  'governorate': 'Tunis',
  'arrivalInstructions': '2e étage, porte à gauche',
};

const _reviewData = <String, dynamic>{
  'patientId': 'family-1',
  'backendPatientId': 'patient-1',
  'patientName': 'Aicha Ben Ali',
  'patientType': 'family',
  'relationship': 'Sœur',
  'providerType': 'doctor',
  'consultationType': 'home',
  'bodyParts': <String>['Dos', 'Poitrine gauche'],
  'painLevel': 8,
  'description': 'Douleur lombaire persistante',
  'symptoms': 'Douleur lombaire persistante',
  'shareMedicalRecord': true,
  'location': _locationPayload,
  'address': '12 Rue des Jasmins, La Marsa, Tunis',
};

class _ReviewFamilyRepository extends FamilyRepository {
  _ReviewFamilyRepository() : super(api: FamilyApi());

  @override
  Future<Result<List<FamilyMember>>> getFamilyMembers() async => Ok([
    FamilyMember(
      id: 'family-1',
      accountHolderId: 'holder',
      firstName: 'Aicha',
      lastName: 'Ben Ali',
      dateOfBirth: DateTime(2014, 6, 15),
      gender: 'F',
      relationship: FamilyRelationships.frereSoeur,
      graduated: false,
      patientId: 'patient-1',
    ),
  ]);
}

class _ReviewLocationGateway extends EmergencyLocationGateway {
  const _ReviewLocationGateway({this.searchResult});

  final SelectedConsultationLocation? searchResult;

  @override
  Future<ConsultationLocationPermission> checkPermission() async =>
      ConsultationLocationPermission.granted;

  @override
  Future<LatLng> currentPosition() async => const LatLng(36.8, 10.18);

  @override
  Future<bool> isServiceEnabled() async => true;

  @override
  Future<ConsultationLocationPermission> requestPermission() async =>
      ConsultationLocationPermission.granted;

  @override
  Future<SelectedConsultationLocation?> reverseGeocode(
    LatLng coordinate, {
    required ConsultationLocationSource source,
  }) async => searchResult;

  @override
  Future<List<SelectedConsultationLocation>> search(String query) async =>
      searchResult == null ? const [] : [searchResult!];
}

const _updatedLocation = SelectedConsultationLocation(
  source: ConsultationLocationSource.manual,
  latitude: 36.82,
  longitude: 10.16,
  formattedAddress: '5 Avenue Habib Bourguiba, Tunis, Tunis',
  street: '5 Avenue Habib Bourguiba',
  city: 'Tunis',
  governorate: 'Tunis',
);

Future<void> _pumpReview(
  WidgetTester tester, {
  Map<String, dynamic> data = _reviewData,
  EmergencyLocationGateway locationGateway = const _ReviewLocationGateway(),
  bool mapsEnabled = false,
  Size size = const Size(390, 844),
  double scale = 1,
  ValueChanged<String>? onRoute,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => FamilyProvider(repository: _ReviewFamilyRepository()),
        ),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: MaterialApp(
        theme: buildOmniTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: EmergencyReviewScreen(
            requestData: data,
            locationGateway: locationGateway,
            mapsEnabled: mapsEnabled,
          ),
        ),
        onGenerateRoute: (settings) {
          onRoute?.call(settings.name ?? '');
          return MaterialPageRoute<void>(
            builder: (_) => Scaffold(body: Text(settings.name ?? '')),
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _editPatient(WidgetTester tester) async {
  await tester.tap(find.text('Modifier').at(0));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Moi'));
  await tester.tap(find.widgetWithText(ElevatedButton, 'Continuer'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders urgent review data without clinic legacy content', (
    tester,
  ) async {
    await _pumpReview(tester);
    expect(find.text('Demande urgente'), findsOneWidget);
    expect(find.text('Vérifiez votre demande'), findsOneWidget);
    expect(find.text('Aicha Ben Ali'), findsOneWidget);
    expect(find.text('Sœur'), findsOneWidget);
    expect(find.text('Dos'), findsOneWidget);
    expect(find.text('Douleur : 8/10'), findsOneWidget);
    expect(find.text('Douleur lombaire persistante'), findsOneWidget);
    expect(find.text('12 Rue des Jasmins, La Marsa, Tunis'), findsOneWidget);
    expect(find.text('2e étage, porte à gauche'), findsOneWidget);
    expect(find.text('Après l’envoi'), findsNothing);
    expect(find.text("Après l'envoi"), findsOneWidget);
    expect(find.text('Accepting requests'), findsNothing);
    expect(find.text('Planned care'), findsNothing);
    expect(find.text('The clinic reviews your request'), findsNothing);
    expect(find.text('Envoyer la demande urgente'), findsOneWidget);
  });

  testWidgets('editing patient returns directly to the existing review', (
    tester,
  ) async {
    await _pumpReview(tester);
    await _editPatient(tester);
    expect(find.text('Aicha Ben Ali'), findsNothing);
    expect(find.text('Moi'), findsOneWidget);
    expect(find.text('Douleur : 8/10'), findsOneWidget);
    expect(find.text('12 Rue des Jasmins, La Marsa, Tunis'), findsOneWidget);
  });

  testWidgets('editing symptoms updates only symptoms and preserves location', (
    tester,
  ) async {
    await _pumpReview(tester);
    await tester.tap(find.text('Modifier').at(1));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('emergency-description')),
      'Douleur moins intense',
    );
    await tester.tap(find.byKey(const ValueKey('emergency-continue')));
    await tester.pumpAndSettle();
    expect(find.text('Douleur moins intense'), findsOneWidget);
    expect(find.text('Douleur : 8/10'), findsOneWidget);
    expect(find.text('Aicha Ben Ali'), findsOneWidget);
    expect(find.text('12 Rue des Jasmins, La Marsa, Tunis'), findsOneWidget);
    expect(find.text('2e étage, porte à gauche'), findsOneWidget);
  });

  testWidgets('editing location returns directly and preserves instructions', (
    tester,
  ) async {
    await _pumpReview(
      tester,
      locationGateway: const _ReviewLocationGateway(
        searchResult: _updatedLocation,
      ),
    );
    await tester.tap(find.text('Modifier').at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modifier le lieu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Saisir l'adresse manuellement"));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Tunis');
    await tester.enterText(fields.at(1), 'Tunis');
    await tester.enterText(fields.at(2), '5 Avenue Habib Bourguiba');
    await tester.tap(find.text('Utiliser cette adresse'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('emergency-continue')));
    await tester.pumpAndSettle();
    expect(find.text('5 Avenue Habib Bourguiba, Tunis, Tunis'), findsOneWidget);
    expect(find.text('2e étage, porte à gauche'), findsOneWidget);
    expect(find.text('Douleur : 8/10'), findsOneWidget);
    expect(find.text('Aicha Ben Ali'), findsOneWidget);
  });

  testWidgets('canceling an edit returns without duplicating review', (
    tester,
  ) async {
    await _pumpReview(tester);
    await tester.tap(find.text('Modifier').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    expect(find.byType(EmergencyReviewScreen), findsOneWidget);
    expect(find.text('Aicha Ben Ali'), findsOneWidget);
    expect(find.text('Douleur lombaire persistante'), findsOneWidget);
  });

  testWidgets('review stays usable on narrow large-text layouts', (
    tester,
  ) async {
    await _pumpReview(tester, size: const Size(320, 700), scale: 1.8);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  if (kIsWeb && kDebugMode) {
    testWidgets('debug web manual location renders without a map', (
      tester,
    ) async {
      var route = '';
      await _pumpReview(
        tester,
        data: {
          ..._reviewData,
          'location': {
            ..._locationPayload,
            'type': 'manual',
            'source': 'manual',
            'latitude': null,
            'longitude': null,
          },
        },
        mapsEnabled: true,
        onRoute: (value) => route = value,
      );
      expect(find.text('12 Rue des Jasmins, La Marsa, Tunis'), findsOneWidget);
      expect(
        find.text('La position exacte sera résolue sur Android.'),
        findsOneWidget,
      );
      expect(find.byType(GoogleMap), findsNothing);
      await tester.tap(find.text('Envoyer la demande urgente'));
      await tester.pumpAndSettle();
      expect(route, '/clinical-request-unavailable');
    });
  }
}
