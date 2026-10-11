import '../domain/urgent_journey_models.dart';
import 'synthetic_urgent_journey_fixture_source.dart';

enum SyntheticHomeLocationScenario {
  permissionNotRequested,
  permissionDenied,
  permissionDeniedForever,
  gpsUnavailable,
  acquiring,
  fresh,
  lowAccuracy,
  stale,
  manual,
  mapSearchUnavailable,
  confirmed,
  offlineUnsent,
}

/// Deterministic UI-only location boundary. It never imports or invokes a
/// platform location, map, geocoder, routing, or Places dependency.
abstract interface class SyntheticHomeLocationGateway {
  HomeDestinationDraft snapshot();
  HomeDestinationDraft requestSyntheticPermission();
  HomeDestinationDraft acquireSyntheticFix();
  HomeDestinationDraft chooseSyntheticManualAddress();
  HomeDestinationDraft confirm();
}

final class InMemorySyntheticHomeLocationGateway
    implements SyntheticHomeLocationGateway {
  InMemorySyntheticHomeLocationGateway({
    this.scenario = SyntheticHomeLocationScenario.permissionNotRequested,
    UrgentFixtureClock? clock,
  }) : _clock = clock ?? FixedUrgentFixtureClock(DateTime.utc(2026, 10, 10, 9)),
       _value = _initial(scenario);

  final SyntheticHomeLocationScenario scenario;
  final UrgentFixtureClock _clock;
  HomeDestinationDraft _value;

  @override
  HomeDestinationDraft snapshot() => _value;

  @override
  HomeDestinationDraft requestSyntheticPermission() {
    if (scenario == SyntheticHomeLocationScenario.permissionDeniedForever) {
      return _value = _empty(permission: HomeLocationPermission.deniedForever);
    }
    if (scenario == SyntheticHomeLocationScenario.permissionDenied) {
      return _value = _empty(permission: HomeLocationPermission.denied);
    }
    return _value = _empty(permission: HomeLocationPermission.granted);
  }

  @override
  HomeDestinationDraft acquireSyntheticFix() {
    if (_value.permission != HomeLocationPermission.granted) return _value;
    if (scenario == SyntheticHomeLocationScenario.gpsUnavailable) {
      return _value = _empty(
        permission: HomeLocationPermission.granted,
        service: HomeLocationService.unavailable,
      );
    }
    final quality = switch (scenario) {
      SyntheticHomeLocationScenario.lowAccuracy =>
        HomeLocationQuality.lowAccuracy,
      SyntheticHomeLocationScenario.stale => HomeLocationQuality.stale,
      _ => HomeLocationQuality.fresh,
    };
    return _value = _draft(
      quality: quality,
      accuracyMeters: quality == HomeLocationQuality.lowAccuracy ? 180 : 12,
      capturedAt: quality == HomeLocationQuality.stale
          ? _clock.now().subtract(const Duration(minutes: 20))
          : _clock.now(),
      mapSearchAvailable:
          scenario != SyntheticHomeLocationScenario.mapSearchUnavailable,
    );
  }

  @override
  HomeDestinationDraft chooseSyntheticManualAddress() => _value = _draft(
    source: HomeDestinationSource.manualAddress,
    quality: HomeLocationQuality.fresh,
    accuracyMeters: null,
    capturedAt: _clock.now(),
    mapSearchAvailable:
        scenario != SyntheticHomeLocationScenario.mapSearchUnavailable,
  );

  @override
  HomeDestinationDraft confirm() {
    if (!_value.canConfirm) return _value;
    return _value = HomeDestinationDraft(
      permission: _value.permission,
      service: _value.service,
      quality: _value.quality,
      status: scenario == SyntheticHomeLocationScenario.offlineUnsent
          ? HomeDestinationStatus.offlineUnsent
          : HomeDestinationStatus.confirmed,
      source: _value.source,
      displayAddress: _value.displayAddress,
      latitude: _value.latitude,
      longitude: _value.longitude,
      accuracyMeters: _value.accuracyMeters,
      capturedAt: _value.capturedAt,
      mapSearchAvailable: _value.mapSearchAvailable,
    );
  }

  static HomeDestinationDraft _initial(SyntheticHomeLocationScenario scenario) {
    switch (scenario) {
      case SyntheticHomeLocationScenario.permissionDenied:
        return _empty(permission: HomeLocationPermission.denied);
      case SyntheticHomeLocationScenario.permissionDeniedForever:
        return _empty(permission: HomeLocationPermission.deniedForever);
      case SyntheticHomeLocationScenario.gpsUnavailable:
        return _empty(
          permission: HomeLocationPermission.granted,
          service: HomeLocationService.unavailable,
        );
      case SyntheticHomeLocationScenario.acquiring:
        return const HomeDestinationDraft(
          permission: HomeLocationPermission.granted,
          service: HomeLocationService.available,
          quality: HomeLocationQuality.acquiring,
          status: HomeDestinationStatus.empty,
        );
      case SyntheticHomeLocationScenario.fresh:
      case SyntheticHomeLocationScenario.lowAccuracy:
      case SyntheticHomeLocationScenario.stale:
      case SyntheticHomeLocationScenario.mapSearchUnavailable:
        return _empty(permission: HomeLocationPermission.granted);
      case SyntheticHomeLocationScenario.manual:
        return _draft(
          source: HomeDestinationSource.manualAddress,
          quality: HomeLocationQuality.fresh,
          capturedAt: DateTime.utc(2026, 10, 10, 9),
        );
      case SyntheticHomeLocationScenario.confirmed:
        final draft = _draft(
          quality: HomeLocationQuality.fresh,
          accuracyMeters: 12,
          capturedAt: DateTime.utc(2026, 10, 10, 9),
        );
        return HomeDestinationDraft(
          permission: draft.permission,
          service: draft.service,
          quality: draft.quality,
          status: HomeDestinationStatus.confirmed,
          source: draft.source,
          displayAddress: draft.displayAddress,
          latitude: draft.latitude,
          longitude: draft.longitude,
          accuracyMeters: draft.accuracyMeters,
          capturedAt: draft.capturedAt,
        );
      case SyntheticHomeLocationScenario.offlineUnsent:
      case SyntheticHomeLocationScenario.permissionNotRequested:
        return _empty();
    }
  }

  static HomeDestinationDraft _empty({
    HomeLocationPermission permission = HomeLocationPermission.notRequested,
    HomeLocationService service = HomeLocationService.available,
  }) => HomeDestinationDraft(
    permission: permission,
    service: service,
    quality: HomeLocationQuality.none,
    status: HomeDestinationStatus.empty,
  );

  static HomeDestinationDraft _draft({
    HomeDestinationSource source = HomeDestinationSource.syntheticGps,
    required HomeLocationQuality quality,
    double? accuracyMeters,
    required DateTime capturedAt,
    bool mapSearchAvailable = true,
  }) => HomeDestinationDraft(
    permission: HomeLocationPermission.granted,
    service: HomeLocationService.available,
    quality: quality,
    status: HomeDestinationStatus.draft,
    source: source,
    displayAddress: 'Adresse HOME synthétique, Tunis',
    latitude: 36.8065,
    longitude: 10.1815,
    accuracyMeters: accuracyMeters,
    capturedAt: capturedAt,
    mapSearchAvailable: mapSearchAvailable,
  );
}
