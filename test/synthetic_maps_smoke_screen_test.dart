import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:omnicare_mobile/core/maps/maps_configuration.dart';
import 'package:omnicare_mobile/core/maps/synthetic_maps_smoke_screen.dart';

void main() {
  testWidgets('shows a neutral state when platform configuration is absent', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SyntheticMapsSmokeScreen(
          configurationLoader: () async =>
              const MapsConfigurationStatus.unavailable(
                'test',
                MapsConfigurationFailure.missingOrInvalidKey,
              ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('maps-smoke-unavailable')),
      findsOneWidget,
    );
    expect(find.textContaining('aucune donnée sensible'), findsOneWidget);
    expect(find.byType(GoogleMap), findsNothing);
  });

  testWidgets('passes exactly one synthetic marker and camera to renderer', (
    tester,
  ) async {
    CameraPosition? camera;
    Set<Marker>? capturedMarkers;

    await tester.pumpWidget(
      MaterialApp(
        home: SyntheticMapsSmokeScreen(
          configurationLoader: () async =>
              const MapsConfigurationStatus.ready('test'),
          mapBuilder:
              ({
                required initialCameraPosition,
                required markers,
                required onMapCreated,
              }) {
                camera = initialCameraPosition;
                capturedMarkers = markers;
                return const ColoredBox(
                  key: ValueKey('synthetic-map-renderer'),
                  color: Colors.blueGrey,
                );
              },
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('synthetic-map-renderer')),
      findsOneWidget,
    );
    expect(camera?.target, SyntheticMapsSmokeScreen.syntheticDestination);
    final renderedMarkers = capturedMarkers;
    expect(renderedMarkers, hasLength(1));
    expect(renderedMarkers!.single.markerId.value, 'synthetic-destination');
    expect(renderedMarkers.single.position, const LatLng(0, 0));
    expect(
      find.textContaining('Aucune donnée Patient, route, distance ou ETA'),
      findsOneWidget,
    );
  });

  testWidgets('turns an initialization timeout into a neutral failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SyntheticMapsSmokeScreen(
          configurationLoader: () async =>
              const MapsConfigurationStatus.ready('test'),
          initializationTimeout: const Duration(milliseconds: 100),
          mapBuilder:
              ({
                required initialCameraPosition,
                required markers,
                required onMapCreated,
              }) => const SizedBox.expand(),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('maps-smoke-initializing')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 101));

    expect(
      find.byKey(const ValueKey('maps-smoke-unavailable')),
      findsOneWidget,
    );
  });

  testWidgets('ignores a late configuration result after disposal', (
    tester,
  ) async {
    final configuration = Completer<MapsConfigurationStatus>();
    var disposed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SyntheticMapsSmokeScreen(
          configurationLoader: () => configuration.future,
          onDisposed: () => disposed = true,
        ),
      ),
    );

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    configuration.complete(const MapsConfigurationStatus.ready('test'));
    await tester.pump();

    expect(disposed, isTrue);
    expect(tester.takeException(), isNull);
  });
}
