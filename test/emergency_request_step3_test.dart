import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/emergency/emergency_request_step3.dart';

const _step2Payload = <String, dynamic>{
  'patientId': 'family-1',
  'patientName': 'Amira',
  'bodyParts': <String>['front-chest-pectoral-left'],
  'painLevel': 5,
  'description': 'Douleur persistante',
  'shareMedicalRecord': false,
};

const _location = SelectedConsultationLocation(
  source: ConsultationLocationSource.currentLocation,
  latitude: 36.8712,
  longitude: 10.3418,
  formattedAddress: '12 Rue des Jasmins, La Marsa, Tunis',
  street: '12 Rue des Jasmins',
  city: 'La Marsa',
  governorate: 'Tunis',
);

class _FakeLocationGateway extends EmergencyLocationGateway {
  const _FakeLocationGateway({
    this.permission = ConsultationLocationPermission.granted,
    this.serviceEnabled = true,
    this.location = _location,
    this.searchResults = const [_location],
  });

  final ConsultationLocationPermission permission;
  final bool serviceEnabled;
  final SelectedConsultationLocation? location;
  final List<SelectedConsultationLocation> searchResults;
  static int currentPositionRequests = 0;

  @override
  Future<ConsultationLocationPermission> checkPermission() async => permission;

  @override
  Future<LatLng> currentPosition() async {
    currentPositionRequests++;
    return const LatLng(36.8712, 10.3418);
  }

  @override
  Future<bool> isServiceEnabled() async => serviceEnabled;

  @override
  Future<ConsultationLocationPermission> requestPermission() async =>
      permission;

  @override
  Future<SelectedConsultationLocation?> reverseGeocode(
    LatLng coordinate, {
    required ConsultationLocationSource source,
  }) async => location == null
      ? null
      : SelectedConsultationLocation(
          source: source,
          latitude: coordinate.latitude,
          longitude: coordinate.longitude,
          formattedAddress: location!.formattedAddress,
          street: location!.street,
          city: location!.city,
          governorate: location!.governorate,
        );

  @override
  Future<List<SelectedConsultationLocation>> search(String query) async =>
      searchResults;
}

class _FakePlacesGateway extends EmergencyPlacesGateway {
  _FakePlacesGateway({this.pendingPredictions = false});

  final bool pendingPredictions;
  final List<String> queries = [];
  final List<Completer<List<EmergencyPlacePrediction>>> pending = [];
  int startSessions = 0;
  int endSessions = 0;
  int fetches = 0;

  static const prediction = EmergencyPlacePrediction(
    placeId: 'place-1',
    primaryText: '12 Rue des Jasmins',
    secondaryText: 'La Marsa, Tunis',
  );

  @override
  Future<void> startSession() async {
    startSessions++;
  }

  @override
  Future<List<EmergencyPlacePrediction>> predictions(String query) {
    queries.add(query);
    if (!pendingPredictions) return Future.value(const [prediction]);
    final completer = Completer<List<EmergencyPlacePrediction>>();
    pending.add(completer);
    return completer.future;
  }

  @override
  Future<SelectedConsultationLocation> fetchPlace(
    EmergencyPlacePrediction prediction,
  ) async {
    fetches++;
    return const SelectedConsultationLocation(
      source: ConsultationLocationSource.placesSearch,
      latitude: 36.8712,
      longitude: 10.3418,
      formattedAddress: '12 Rue des Jasmins, La Marsa, Tunis',
      street: '12 Rue des Jasmins',
      city: 'La Marsa',
      governorate: 'Tunis',
    );
  }

  @override
  Future<void> endSession() async {
    endSessions++;
  }
}

Future<void> _pump(
  WidgetTester tester, {
  EmergencyLocationGateway gateway = const _FakeLocationGateway(),
  EmergencyPlacesGateway? placesGateway,
  EmergencyMapBuilder? mapBuilder,
  ValueChanged<Map<String, dynamic>>? onNext,
  Size size = const Size(390, 844),
  double scale = 1,
  bool mapsEnabled = false,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  _FakeLocationGateway.currentPositionRequests = 0;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildOmniTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: EmergencyRequestStep3(
          previousData: _step2Payload,
          locationGateway: gateway,
          placesGateway: placesGateway,
          mapBuilder: mapBuilder,
          mapsEnabled: mapsEnabled,
        ),
      ),
      onGenerateRoute: (settings) {
        onNext?.call(settings.arguments! as Map<String, dynamic>);
        return MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Emergency review')),
        );
      },
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final next = find.byKey(const ValueKey('emergency-continue'));

  Future<void> chooseCurrentLocation(WidgetTester tester) async {
    await tester.tap(find.text('Choisir le lieu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Utiliser ma position actuelle'));
    await tester.pumpAndSettle();
  }

  Future<void> openAddressSearch(WidgetTester tester) async {
    final trigger = find.text('Modifier le lieu').evaluate().isNotEmpty
        ? find.text('Modifier le lieu')
        : find.text('Choisir le lieu');
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rechercher une adresse'));
    await tester.pumpAndSettle();
  }

  testWidgets('does not infer a consultation destination on page open', (
    tester,
  ) async {
    await _pump(tester);
    expect(_FakeLocationGateway.currentPositionRequests, 0);
    expect(find.text('Aucun lieu sélectionné'), findsOneWidget);
    expect(find.text('Choisir le lieu'), findsOneWidget);
    expect(find.text('Localisation indisponible'), findsNothing);
    expect(tester.widget<ElevatedButton>(next).onPressed, isNull);
  });

  testWidgets('uses a white tracker-free location page', (tester) async {
    await _pump(tester);
    final surface = tester.widget<ColoredBox>(
      find.byKey(const ValueKey('emergency-step3-page-surface')),
    );
    expect(surface.color, Colors.white);
    expect(find.text('Où doit venir le médecin ?'), findsOneWidget);
    expect(
      find.text('Choisissez le lieu où le médecin doit rejoindre le patient.'),
      findsOneWidget,
    );
    expect(find.textContaining('Étape 3'), findsNothing);
    expect(find.text('Patient'), findsNothing);
  });

  testWidgets('modify sheet lists all location methods', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Choisir le lieu'));
    await tester.pumpAndSettle();
    expect(find.text('Utiliser ma position actuelle'), findsOneWidget);
    expect(find.text('Rechercher une adresse'), findsOneWidget);
    expect(find.text('Choisir sur la carte'), findsOneWidget);
    expect(find.text("Saisir l'adresse manuellement"), findsOneWidget);
  });

  testWidgets('chooser scrolls safely on a short large-text screen', (
    tester,
  ) async {
    await _pump(tester, size: const Size(320, 500), scale: 1.8);
    await tester.ensureVisible(find.text('Choisir le lieu'));
    await tester.tap(find.text('Choisir le lieu'));
    await tester.pumpAndSettle();
    expect(find.text('Utiliser ma position actuelle'), findsOneWidget);
    expect(find.text("Saisir l'adresse manuellement"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('current-location option refreshes the selected location', (
    tester,
  ) async {
    await _pump(tester);
    await chooseCurrentLocation(tester);
    expect(_FakeLocationGateway.currentPositionRequests, 1);
    expect(find.text('Lieu de consultation'), findsOneWidget);
  });

  testWidgets('permission-needed state keeps manual alternatives available', (
    tester,
  ) async {
    await _pump(
      tester,
      gateway: const _FakeLocationGateway(
        permission: ConsultationLocationPermission.denied,
      ),
    );
    expect(find.text('Aucun lieu sélectionné'), findsOneWidget);
    await tester.tap(find.text('Choisir le lieu'));
    await tester.pumpAndSettle();
    expect(find.text('Modifier le lieu'), findsOneWidget);
    await tester.tap(find.text('Utiliser ma position actuelle'));
    await tester.pumpAndSettle();
    expect(find.text('Localisation indisponible'), findsOneWidget);
    expect(find.text('Choisir une autre adresse'), findsOneWidget);
  });

  testWidgets('disabled location service remains recoverable', (tester) async {
    await _pump(
      tester,
      gateway: const _FakeLocationGateway(serviceEnabled: false),
    );
    await tester.tap(find.text('Choisir le lieu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Utiliser ma position actuelle'));
    await tester.pumpAndSettle();
    expect(find.text('Localisation indisponible'), findsOneWidget);
    expect(find.text('Choisir une autre adresse'), findsOneWidget);
  });

  testWidgets(
    'arrival instructions are optional and forwarded with Step2 data',
    (tester) async {
      Map<String, dynamic>? payload;
      await _pump(tester, onNext: (value) => payload = value);
      await chooseCurrentLocation(tester);
      await tester.enterText(
        find.byKey(const ValueKey('emergency-arrival-instructions')),
        'Bâtiment B, 3e étage',
      );
      await tester.tap(next);
      await tester.pumpAndSettle();
      final location = payload!['location'] as Map<String, dynamic>;
      expect(payload!['bodyParts'], _step2Payload['bodyParts']);
      expect(payload!['description'], 'Douleur persistante');
      expect(location['arrivalInstructions'], 'Bâtiment B, 3e étage');
      expect(location['source'], 'currentLocation');
    },
  );

  testWidgets('map picker does not select its default Tunisia viewport', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('Choisir le lieu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choisir sur la carte'));
    await tester.pumpAndSettle();
    expect(
      find.text('Déplacez la carte pour choisir le point exact.'),
      findsOneWidget,
    );
    final confirm = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Confirmer cette position'),
    );
    expect(confirm.onPressed, isNull);
  });

  testWidgets('map picker resolves a moved camera before confirmation', (
    tester,
  ) async {
    await _pump(
      tester,
      mapBuilder:
          ({
            required initialCameraPosition,
            required onCameraMove,
            required onCameraIdle,
          }) => Center(
            child: ElevatedButton(
              key: const ValueKey('simulate-map-move'),
              onPressed: () {
                onCameraMove(
                  const CameraPosition(
                    target: LatLng(36.8219, 10.1658),
                    zoom: 16,
                  ),
                );
                onCameraIdle();
              },
              child: const Text('Déplacer la carte'),
            ),
          ),
    );
    await tester.tap(find.text('Choisir le lieu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choisir sur la carte'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('simulate-map-move')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text(_location.formattedAddress), findsOneWidget);
    final confirm = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Confirmer cette position'),
    );
    expect(confirm.onPressed, isNotNull);
    await tester.tap(
      find.widgetWithText(ElevatedButton, 'Confirmer cette position'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lieu de consultation'), findsOneWidget);
  });

  testWidgets(
    'Places search debounces, ignores stale results, and ends its session',
    (tester) async {
      final places = _FakePlacesGateway(pendingPredictions: true);
      await _pump(tester, placesGateway: places);
      await openAddressSearch(tester);

      await tester.enterText(
        find.byKey(const ValueKey('location-search-field')),
        'La',
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(places.startSessions, 0);
      expect(places.queries, isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey('location-search-field')),
        'La Marsa',
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(places.queries, ['La Marsa']);

      await tester.enterText(
        find.byKey(const ValueKey('location-search-field')),
        'Tunis',
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(places.queries, ['La Marsa', 'Tunis']);

      places.pending[0].complete(const [
        EmergencyPlacePrediction(
          placeId: 'old',
          primaryText: 'Ancien résultat',
          secondaryText: 'La Marsa',
        ),
      ]);
      await tester.pump();
      expect(find.text('Ancien résultat'), findsNothing);

      places.pending[1].complete(const [_FakePlacesGateway.prediction]);
      await tester.pumpAndSettle();
      expect(find.text('12 Rue des Jasmins'), findsOneWidget);

      await tester.tap(find.text('12 Rue des Jasmins'));
      await tester.pumpAndSettle();
      expect(places.startSessions, 1);
      expect(places.fetches, 1);
      expect(places.endSessions, 1);
      expect(find.text('Lieu de consultation'), findsOneWidget);
    },
  );

  testWidgets(
    'selected destination keeps arrival instructions after changing method',
    (tester) async {
      final places = _FakePlacesGateway();
      await _pump(tester, placesGateway: places);
      await chooseCurrentLocation(tester);
      await tester.enterText(
        find.byKey(const ValueKey('emergency-arrival-instructions')),
        'Entrée côté jardin',
      );
      await openAddressSearch(tester);
      await tester.enterText(
        find.byKey(const ValueKey('location-search-field')),
        'La Marsa',
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      await tester.tap(find.text('12 Rue des Jasmins'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('emergency-arrival-instructions')),
            )
            .controller!
            .text,
        'Entrée côté jardin',
      );
    },
  );

  testWidgets('unresolved manual address never creates coordinates', (
    tester,
  ) async {
    if (kIsWeb && kDebugMode) return;
    await _pump(
      tester,
      gateway: const _FakeLocationGateway(location: null, searchResults: []),
    );
    await tester.tap(find.text('Choisir le lieu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Saisir l'adresse manuellement"));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Tunis');
    await tester.enterText(fields.at(1), 'Tunis');
    await tester.enterText(fields.at(2), 'Rue inconnue');
    await tester.tap(find.text('Utiliser cette adresse'));
    await tester.pumpAndSettle();
    expect(find.textContaining("n’a pas pu être localisée"), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Aucun lieu sélectionné'), findsOneWidget);
  });

  testWidgets(
    'manual form validates and a search selection updates the main page',
    (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Choisir le lieu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Saisir l'adresse manuellement"));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Utiliser cette adresse'));
      await tester.pump();
      expect(find.text('Ce champ est requis.'), findsNWidgets(3));
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choisir le lieu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rechercher une adresse'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('location-search-field')),
        'La Marsa',
      );
      await tester.tap(find.byTooltip('Rechercher'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('12 Rue des Jasmins'));
      await tester.pumpAndSettle();
      expect(find.text('Lieu de consultation'), findsOneWidget);
    },
  );

  testWidgets(
    'narrow and large-text layouts retain one primary scroll and footer CTA',
    (tester) async {
      await _pump(tester, size: const Size(320, 700), scale: 1.8);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(tester.getSize(next).height, 50);
      expect(tester.takeException(), isNull);
    },
  );

  if (kIsWeb && kDebugMode) {
    testWidgets(
      'debug web manual address remains unresolved but can continue',
      (tester) async {
        Map<String, dynamic>? nextPayload;
        await _pump(
          tester,
          gateway: const _FakeLocationGateway(
            location: null,
            searchResults: [],
          ),
          mapsEnabled: true,
          onNext: (payload) => nextPayload = payload,
        );
        await tester.tap(find.text('Choisir le lieu'));
        await tester.pumpAndSettle();
        await tester.tap(find.text("Saisir l'adresse manuellement"));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField).at(0), 'Tunis');
        await tester.enterText(find.byType(TextFormField).at(1), 'La Marsa');
        await tester.enterText(
          find.byType(TextFormField).at(2),
          '12 Rue des Jasmins',
        );
        await tester.enterText(
          find.byType(TextFormField).at(3),
          'Résidence Les Oliviers',
        );
        await tester.tap(find.text('Utiliser cette adresse'));
        await tester.pumpAndSettle();

        expect(find.text('Adresse saisie manuellement'), findsOneWidget);
        expect(
          find.text('La position exacte sera résolue sur Android.'),
          findsOneWidget,
        );
        expect(find.byType(GoogleMap), findsNothing);
        expect(tester.widget<ElevatedButton>(next).onPressed, isNotNull);

        await tester.tap(next);
        await tester.pumpAndSettle();
        final location = nextPayload!['location'] as Map<String, dynamic>;
        expect(nextPayload!['address'], contains('12 Rue des Jasmins'));
        expect(location['source'], 'manual');
        expect(location['latitude'], isNull);
        expect(location['longitude'], isNull);
        expect(location['address'], contains('Résidence Les Oliviers'));
        expect(find.text('Emergency review'), findsOneWidget);
      },
    );
  }
}
