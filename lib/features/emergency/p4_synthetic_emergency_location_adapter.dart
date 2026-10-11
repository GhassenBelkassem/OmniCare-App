import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../urgent_journey/data/synthetic_home_location_gateway.dart';
import '../urgent_journey/domain/urgent_journey_models.dart';
import 'emergency_request_step3.dart';

/// Presents the deterministic P4 HOME-location fixture through the existing
/// emergency destination screen's location contract.
///
/// This adapter never creates a device location, geocoder, map, or Places
/// client. Every result is derived from [SyntheticHomeLocationGateway].
final class P4SyntheticEmergencyLocationAdapter
    extends EmergencyLocationGateway {
  P4SyntheticEmergencyLocationAdapter(this._gateway);

  final SyntheticHomeLocationGateway _gateway;

  HomeDestinationDraft get snapshot => _gateway.snapshot();

  @override
  Future<bool> isServiceEnabled() async =>
      snapshot.service == HomeLocationService.available;

  @override
  Future<ConsultationLocationPermission> checkPermission() async =>
      _legacyPermission(snapshot);

  @override
  Future<ConsultationLocationPermission> requestPermission() async {
    if (snapshot.service == HomeLocationService.unavailable) {
      return ConsultationLocationPermission.unavailable;
    }
    return _legacyPermission(_gateway.requestSyntheticPermission());
  }

  @override
  Future<LatLng> currentPosition() async {
    final draft = _gateway.acquireSyntheticFix();
    final latitude = draft.latitude;
    final longitude = draft.longitude;
    if (draft.service != HomeLocationService.available ||
        latitude == null ||
        longitude == null) {
      throw StateError('Synthetic HOME location is unavailable.');
    }
    return LatLng(latitude, longitude);
  }

  @override
  Future<SelectedConsultationLocation?> reverseGeocode(
    LatLng coordinate, {
    required ConsultationLocationSource source,
  }) async {
    var draft = snapshot;
    if (draft.service != HomeLocationService.available) return null;
    if (draft.displayAddress?.trim().isEmpty ?? true) {
      if (draft.permission != HomeLocationPermission.granted) return null;
      draft = _gateway.acquireSyntheticFix();
    }
    return selectedConsultationLocationFromHomeDestinationDraft(
      draft,
      source: source,
      latitude: coordinate.latitude,
      longitude: coordinate.longitude,
    );
  }

  @override
  Future<List<SelectedConsultationLocation>> search(String query) async {
    if (query.trim().isEmpty || !snapshot.mapSearchAvailable) return const [];
    final draft = _gateway.chooseSyntheticManualAddress();
    final location = selectedConsultationLocationFromHomeDestinationDraft(
      draft,
      source: ConsultationLocationSource.placesSearch,
    );
    return location == null ? const [] : [location];
  }

  /// Reattaches the P4 fixture metadata that the legacy presentation type does
  /// not carry, without confirming or dispatching the destination.
  HomeDestinationDraft toHomeDestinationDraft(
    SelectedConsultationLocation location, {
    HomeDestinationStatus status = HomeDestinationStatus.draft,
  }) => homeDestinationDraftFromSelectedConsultationLocation(
    location,
    metadata: snapshot,
    status: status,
  );

  /// Confirms through the deterministic fixture first, then carries the
  /// selected presentation address into the typed command value.
  HomeDestinationDraft confirm(SelectedConsultationLocation location) {
    final confirmed = _gateway.confirm();
    return homeDestinationDraftFromSelectedConsultationLocation(
      location,
      metadata: confirmed,
      status: confirmed.status,
    );
  }
}

/// API-free Places-shaped adapter for the legacy address-search presentation.
///
/// It exposes at most the deterministic HOME fixture and keeps its lookup map
/// in memory for the duration of a presentation session.
final class P4SyntheticEmergencyPlacesAdapter extends EmergencyPlacesGateway {
  P4SyntheticEmergencyPlacesAdapter(SyntheticHomeLocationGateway gateway)
    : _locationGateway = P4SyntheticEmergencyLocationAdapter(gateway);

  final P4SyntheticEmergencyLocationAdapter _locationGateway;
  final Map<String, SelectedConsultationLocation> _locations = {};

  @override
  Future<void> startSession() async {
    _locations.clear();
  }

  @override
  Future<List<EmergencyPlacePrediction>> predictions(String query) async {
    final locations = await _locationGateway.search(query);
    _locations.clear();
    final predictions = <EmergencyPlacePrediction>[];
    for (var index = 0; index < locations.length; index++) {
      final location = locations[index];
      final placeId = 'p4-synthetic-home-$index';
      _locations[placeId] = location;
      final addressParts = location.formattedAddress
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
      predictions.add(
        EmergencyPlacePrediction(
          placeId: placeId,
          primaryText: addressParts.isEmpty
              ? location.formattedAddress
              : addressParts.first,
          secondaryText: addressParts.skip(1).join(', '),
        ),
      );
    }
    return List.unmodifiable(predictions);
  }

  @override
  Future<SelectedConsultationLocation> fetchPlace(
    EmergencyPlacePrediction prediction,
  ) async {
    final location = _locations[prediction.placeId];
    if (location == null) {
      throw const FormatException('Synthetic place details were unavailable.');
    }
    return location;
  }

  @override
  Future<void> endSession() async {
    _locations.clear();
  }
}

/// Converts a complete or address-only P4 draft into the legacy presentation
/// value. Incomplete drafts without a display address intentionally return
/// `null` rather than inventing data.
SelectedConsultationLocation?
selectedConsultationLocationFromHomeDestinationDraft(
  HomeDestinationDraft draft, {
  ConsultationLocationSource? source,
  double? latitude,
  double? longitude,
}) {
  final address = draft.displayAddress?.trim();
  if (address == null || address.isEmpty) return null;
  return SelectedConsultationLocation(
    source:
        source ??
        switch (draft.source) {
          HomeDestinationSource.manualAddress =>
            ConsultationLocationSource.manual,
          HomeDestinationSource.syntheticGps ||
          null => ConsultationLocationSource.currentLocation,
        },
    latitude: latitude ?? draft.latitude,
    longitude: longitude ?? draft.longitude,
    formattedAddress: address,
  );
}

/// Converts the legacy destination-screen value back to the typed P4 draft.
///
/// [metadata] preserves fixture-only quality, accuracy, capture time, and
/// map-search availability. The conversion defaults to `draft`; callers must
/// make confirmation an explicit typed action.
HomeDestinationDraft homeDestinationDraftFromSelectedConsultationLocation(
  SelectedConsultationLocation location, {
  HomeDestinationDraft? metadata,
  HomeDestinationStatus status = HomeDestinationStatus.draft,
}) {
  final hasCoordinates = location.hasCoordinates;
  final quality = switch (metadata?.quality) {
    HomeLocationQuality.fresh => HomeLocationQuality.fresh,
    HomeLocationQuality.lowAccuracy => HomeLocationQuality.lowAccuracy,
    HomeLocationQuality.stale => HomeLocationQuality.stale,
    _ => hasCoordinates ? HomeLocationQuality.fresh : HomeLocationQuality.none,
  };
  final address = location.formattedAddress.trim();
  return HomeDestinationDraft(
    permission: metadata?.permission ?? HomeLocationPermission.granted,
    service: metadata?.service ?? HomeLocationService.available,
    quality: quality,
    status: status,
    source: location.source == ConsultationLocationSource.manual
        ? HomeDestinationSource.manualAddress
        : HomeDestinationSource.syntheticGps,
    displayAddress: address.isEmpty ? null : address,
    latitude: location.latitude,
    longitude: location.longitude,
    accuracyMeters: metadata?.accuracyMeters,
    capturedAt: metadata?.capturedAt,
    mapSearchAvailable: metadata?.mapSearchAvailable ?? true,
  );
}

ConsultationLocationPermission _legacyPermission(HomeDestinationDraft draft) {
  if (draft.service == HomeLocationService.unavailable) {
    return ConsultationLocationPermission.unavailable;
  }
  return switch (draft.permission) {
    HomeLocationPermission.granted => ConsultationLocationPermission.granted,
    HomeLocationPermission.denied => ConsultationLocationPermission.denied,
    HomeLocationPermission.deniedForever =>
      ConsultationLocationPermission.deniedForever,
    HomeLocationPermission.notRequested =>
      ConsultationLocationPermission.denied,
  };
}
