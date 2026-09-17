import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/theme/omni_theme.dart';
import 'urgent_flow_mode.dart';

enum ConsultationLocationSource {
  currentLocation,
  placesSearch,
  mapPicker,
  manual,
}

enum ConsultationLocationPermission {
  granted,
  denied,
  deniedForever,
  unavailable,
}

class SelectedConsultationLocation {
  const SelectedConsultationLocation({
    required this.source,
    required this.formattedAddress,
    this.latitude,
    this.longitude,
    this.street,
    this.city,
    this.governorate,
    this.apartment,
  });

  final ConsultationLocationSource source;
  final double? latitude;
  final double? longitude;
  final String formattedAddress;
  final String? street;
  final String? city;
  final String? governorate;
  final String? apartment;

  static SelectedConsultationLocation? fromPayload(Object? raw) {
    if (raw is! Map) return null;
    final formattedAddress =
        (raw['address'] ?? raw['fullAddress'])?.toString().trim() ?? '';
    if (formattedAddress.isEmpty) return null;
    final sourceName = raw['source']?.toString();
    final source = ConsultationLocationSource.values.where(
      (value) => value.name == sourceName,
    );
    return SelectedConsultationLocation(
      source: source.isEmpty ? ConsultationLocationSource.manual : source.first,
      latitude: (raw['latitude'] as num?)?.toDouble(),
      longitude: (raw['longitude'] as num?)?.toDouble(),
      formattedAddress: formattedAddress,
      street: raw['street']?.toString(),
      city: raw['city']?.toString(),
      governorate: raw['governorate']?.toString(),
      apartment: raw['apartment']?.toString(),
    );
  }

  bool get hasCoordinates => latitude != null && longitude != null;

  bool get isDebugWebManualFallback =>
      kIsWeb &&
      kDebugMode &&
      source == ConsultationLocationSource.manual &&
      !hasCoordinates;

  bool get isUsable => hasCoordinates && formattedAddress.trim().isNotEmpty;

  bool get canContinue =>
      formattedAddress.trim().isNotEmpty &&
      (isUsable || isDebugWebManualFallback);

  Map<String, dynamic> toPayload({required String arrivalInstructions}) => {
    'type': source == ConsultationLocationSource.manual ? 'manual' : 'gps',
    'source': source.name,
    'latitude': latitude,
    'longitude': longitude,
    'address': formattedAddress,
    'fullAddress': formattedAddress,
    'street': street,
    'city': city,
    'governorate': governorate,
    'apartment': apartment,
    'arrivalInstructions': arrivalInstructions,
  };
}

class EmergencyPlacePrediction {
  const EmergencyPlacePrediction({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
  });

  final String placeId;
  final String primaryText;
  final String secondaryText;
}

abstract class EmergencyPlacesGateway {
  const EmergencyPlacesGateway();

  Future<void> startSession();
  Future<List<EmergencyPlacePrediction>> predictions(String query);
  Future<SelectedConsultationLocation> fetchPlace(
    EmergencyPlacePrediction prediction,
  );
  Future<void> endSession();
}

typedef EmergencyMapBuilder =
    Widget Function({
      required CameraPosition initialCameraPosition,
      required ValueChanged<CameraPosition> onCameraMove,
      required VoidCallback onCameraIdle,
    });

class AndroidEmergencyPlacesGateway extends EmergencyPlacesGateway {
  const AndroidEmergencyPlacesGateway();

  static const _channel = MethodChannel('omnicare/emergency_places');

  @override
  Future<void> startSession() => _channel.invokeMethod<void>('startSession');

  @override
  Future<List<EmergencyPlacePrediction>> predictions(String query) async {
    final raw = await _channel.invokeListMethod<dynamic>('predictions', {
      'query': query,
    });
    return (raw ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) {
          return EmergencyPlacePrediction(
            placeId: item['placeId'] as String,
            primaryText: item['primaryText'] as String,
            secondaryText: item['secondaryText'] as String? ?? '',
          );
        })
        .toList(growable: false);
  }

  @override
  Future<SelectedConsultationLocation> fetchPlace(
    EmergencyPlacePrediction prediction,
  ) async {
    final raw = await _channel.invokeMapMethod<String, dynamic>('fetchPlace', {
      'placeId': prediction.placeId,
    });
    if (raw == null) {
      throw const FormatException('Place details were unavailable.');
    }
    return _locationFromPlacePayload(raw);
  }

  @override
  Future<void> endSession() => _channel.invokeMethod<void>('endSession');
}

SelectedConsultationLocation _locationFromPlacePayload(
  Map<String, dynamic> payload,
) {
  final latitude = (payload['latitude'] as num?)?.toDouble();
  final longitude = (payload['longitude'] as num?)?.toDouble();
  final formattedAddress = payload['formattedAddress'] as String?;
  if (latitude == null ||
      longitude == null ||
      formattedAddress == null ||
      formattedAddress.trim().isEmpty) {
    throw const FormatException('Place details were incomplete.');
  }
  return SelectedConsultationLocation(
    source: ConsultationLocationSource.placesSearch,
    latitude: latitude,
    longitude: longitude,
    formattedAddress: formattedAddress,
    street: payload['street'] as String?,
    city: payload['city'] as String?,
    governorate: payload['governorate'] as String?,
  );
}

class LegacyEmergencyPlacesGateway extends EmergencyPlacesGateway {
  LegacyEmergencyPlacesGateway(this._locationGateway);

  final EmergencyLocationGateway _locationGateway;
  final Map<String, SelectedConsultationLocation> _locations = {};
  int _nextId = 0;

  @override
  Future<void> startSession() async {}

  @override
  Future<List<EmergencyPlacePrediction>> predictions(String query) async {
    final locations = await _locationGateway.search(query);
    _locations.clear();
    final predictions = <EmergencyPlacePrediction>[];
    for (final location in locations) {
      final id = 'legacy-${_nextId++}';
      _locations[id] = location;
      predictions.add(
        EmergencyPlacePrediction(
          placeId: id,
          primaryText: location.street ?? location.formattedAddress,
          secondaryText: [
            location.city,
            location.governorate,
          ].whereType<String>().where((value) => value.isNotEmpty).join(', '),
        ),
      );
    }
    return predictions;
  }

  @override
  Future<SelectedConsultationLocation> fetchPlace(
    EmergencyPlacePrediction prediction,
  ) async {
    final location = _locations[prediction.placeId];
    if (location == null) {
      throw const FormatException('Place details were unavailable.');
    }
    return SelectedConsultationLocation(
      source: ConsultationLocationSource.placesSearch,
      latitude: location.latitude,
      longitude: location.longitude,
      formattedAddress: location.formattedAddress,
      street: location.street,
      city: location.city,
      governorate: location.governorate,
      apartment: location.apartment,
    );
  }

  @override
  Future<void> endSession() async {
    _locations.clear();
  }
}

abstract class EmergencyLocationGateway {
  const EmergencyLocationGateway();

  Future<bool> isServiceEnabled();
  Future<ConsultationLocationPermission> checkPermission();
  Future<ConsultationLocationPermission> requestPermission();
  Future<LatLng> currentPosition();
  Future<SelectedConsultationLocation?> reverseGeocode(
    LatLng coordinate, {
    required ConsultationLocationSource source,
  });
  Future<List<SelectedConsultationLocation>> search(String query);
}

class DeviceEmergencyLocationGateway extends EmergencyLocationGateway {
  const DeviceEmergencyLocationGateway();

  ConsultationLocationPermission _permission(LocationPermission value) =>
      switch (value) {
        LocationPermission.always ||
        LocationPermission.whileInUse => ConsultationLocationPermission.granted,
        LocationPermission.deniedForever =>
          ConsultationLocationPermission.deniedForever,
        LocationPermission.denied => ConsultationLocationPermission.denied,
        LocationPermission.unableToDetermine =>
          ConsultationLocationPermission.unavailable,
      };

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<ConsultationLocationPermission> checkPermission() async =>
      _permission(await Geolocator.checkPermission());

  @override
  Future<ConsultationLocationPermission> requestPermission() async =>
      _permission(await Geolocator.requestPermission());

  @override
  Future<LatLng> currentPosition() async {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 12),
    );
    return LatLng(position.latitude, position.longitude);
  }

  @override
  Future<SelectedConsultationLocation?> reverseGeocode(
    LatLng coordinate, {
    required ConsultationLocationSource source,
  }) async {
    final places = await placemarkFromCoordinates(
      coordinate.latitude,
      coordinate.longitude,
    );
    if (places.isEmpty) return null;
    final place = places.first;
    final street = [place.street, place.subLocality]
        .whereType<String>()
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .join(', ');
    final city = (place.locality ?? place.subAdministrativeArea ?? '').trim();
    final governorate = (place.administrativeArea ?? '').trim();
    final formattedAddress = [
      street,
      city,
      governorate,
    ].where((item) => item.isNotEmpty).join(', ');
    return SelectedConsultationLocation(
      source: source,
      latitude: coordinate.latitude,
      longitude: coordinate.longitude,
      formattedAddress: formattedAddress.isEmpty
          ? 'Adresse détectée'
          : formattedAddress,
      street: street.isEmpty ? null : street,
      city: city.isEmpty ? null : city,
      governorate: governorate.isEmpty ? null : governorate,
    );
  }

  @override
  Future<List<SelectedConsultationLocation>> search(String query) async {
    if (query.trim().isEmpty) return const [];
    final coordinates = await locationFromAddress(query.trim());
    final results = <SelectedConsultationLocation>[];
    for (final coordinate in coordinates.take(5)) {
      final result = await reverseGeocode(
        LatLng(coordinate.latitude, coordinate.longitude),
        source: ConsultationLocationSource.placesSearch,
      );
      if (result != null) results.add(result);
    }
    return results;
  }
}

class EmergencyRequestStep3 extends StatefulWidget {
  const EmergencyRequestStep3({
    super.key,
    required this.previousData,
    this.locationGateway = const DeviceEmergencyLocationGateway(),
    this.placesGateway,
    this.mapsEnabled = true,
    this.mapBuilder,
    this.flowMode = UrgentFlowMode.create,
  });

  final Map<String, dynamic> previousData;
  final EmergencyLocationGateway locationGateway;
  final EmergencyPlacesGateway? placesGateway;
  final bool mapsEnabled;
  final EmergencyMapBuilder? mapBuilder;
  final UrgentFlowMode flowMode;

  @override
  State<EmergencyRequestStep3> createState() => _EmergencyRequestStep3State();
}

class _EmergencyRequestStep3State extends State<EmergencyRequestStep3> {
  final _arrivalInstructions = TextEditingController();
  SelectedConsultationLocation? _location;
  _LocationState _state = _LocationState.unselected;
  String? _status;

  @override
  void initState() {
    super.initState();
    final location = SelectedConsultationLocation.fromPayload(
      widget.previousData['location'],
    );
    if (location?.canContinue == true) {
      _location = location;
      _state = _LocationState.resolved;
      _arrivalInstructions.text =
          ((widget.previousData['location'] as Map?)?['arrivalInstructions'])
              ?.toString() ??
          '';
    }
  }

  EmergencyPlacesGateway get _placesGateway =>
      widget.placesGateway ??
      (widget.locationGateway is DeviceEmergencyLocationGateway
          ? const AndroidEmergencyPlacesGateway()
          : LegacyEmergencyPlacesGateway(widget.locationGateway));

  @override
  void dispose() {
    _arrivalInstructions.dispose();
    super.dispose();
  }

  void _setUnavailable(String message) {
    if (!mounted) return;
    setState(() {
      _state = _LocationState.unavailable;
      _status = message;
    });
  }

  Future<void> _requestAndRefreshLocation() async {
    setState(() => _state = _LocationState.resolving);
    try {
      if (!await widget.locationGateway.isServiceEnabled()) {
        _setUnavailable('La localisation est désactivée sur cet appareil.');
        return;
      }
      var permission = await widget.locationGateway.checkPermission();
      if (permission != ConsultationLocationPermission.granted) {
        permission = await widget.locationGateway.requestPermission();
      }
      if (!mounted) return;
      if (permission != ConsultationLocationPermission.granted) {
        setState(() {
          _state = permission == ConsultationLocationPermission.deniedForever
              ? _LocationState.deniedForever
              : _LocationState.denied;
        });
        return;
      }
      await _refreshCurrentLocation();
    } catch (_) {
      _setUnavailable('La localisation n’a pas pu être obtenue.');
    }
  }

  Future<void> _refreshCurrentLocation() async {
    setState(() {
      _state = _LocationState.resolving;
      _status = 'Recherche de votre position…';
    });
    try {
      final coordinate = await widget.locationGateway.currentPosition();
      if (!mounted) return;
      setState(() => _status = 'Recherche de l’adresse…');
      final location = await widget.locationGateway.reverseGeocode(
        coordinate,
        source: ConsultationLocationSource.currentLocation,
      );
      if (!mounted) return;
      setState(() {
        _location = location;
        _state = location?.isUsable == true
            ? _LocationState.resolved
            : _LocationState.unavailable;
        _status = location == null
            ? 'Nous n’avons pas pu trouver une adresse lisible.'
            : null;
      });
    } catch (_) {
      _setUnavailable('La localisation n’a pas pu être obtenue.');
    }
  }

  Future<void> _openModifySheet() async {
    final option = await showModalBottomSheet<_LocationOption>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: OmniColors.surfacePrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (_) => const _ModifyLocationSheet(),
    );
    if (!mounted || option == null) return;
    if (option == _LocationOption.current) {
      await _requestAndRefreshLocation();
      return;
    }
    final result = await Navigator.of(context)
        .push<SelectedConsultationLocation>(
          MaterialPageRoute(
            builder: (_) => switch (option) {
              _LocationOption.search => _AddressSearchScreen(
                gateway: _placesGateway,
              ),
              _LocationOption.map => _MapPickerScreen(
                gateway: widget.locationGateway,
                initial: _location,
                mapsEnabled: widget.mapsEnabled,
                mapBuilder: widget.mapBuilder,
              ),
              _LocationOption.manual => _ManualAddressScreen(
                gateway: widget.locationGateway,
              ),
              _LocationOption.current => const SizedBox.shrink(),
            },
          ),
        );
    if (mounted && result != null) {
      setState(() {
        _location = result;
        _state = _LocationState.resolved;
      });
    }
  }

  void _continue() {
    final location = _location;
    if (location == null || !location.canContinue) return;
    final locationPayload = location.toPayload(
      arrivalInstructions: _arrivalInstructions.text.trim(),
    );
    final data = {
      ...widget.previousData,
      'address': location.formattedAddress,
      'location': locationPayload,
    };
    if (widget.flowMode == UrgentFlowMode.editFromReview) {
      Navigator.pop(context, data);
      return;
    }
    Navigator.pushNamed(context, '/emergency-review', arguments: data);
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const ValueKey('emergency-step3-page-surface'),
    color: OmniColors.pageBackground,
    child: GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          _StepHeader(onBack: () => Navigator.maybePop(context)),
          Expanded(
            child: SingleChildScrollView(
              key: const ValueKey('emergency-step3-scroll'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Où doit venir le médecin ?',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: OmniColors.textPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _location == null
                            ? 'Choisissez le lieu où le médecin doit rejoindre le patient.'
                            : 'Vérifiez le lieu où le médecin doit rejoindre le patient.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: OmniColors.textSecondary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_state == _LocationState.resolved &&
                          _location != null) ...[
                        if (_location!.isDebugWebManualFallback)
                          const _DebugWebManualSurface()
                        else
                          _MapPreview(
                            location: _location!,
                            mapsEnabled: widget.mapsEnabled,
                          ),
                        const SizedBox(height: 16),
                        _SelectedLocationSurface(location: _location!),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton(
                            onPressed: _openModifySheet,
                            child: const Text('Modifier le lieu'),
                          ),
                        ),
                      ] else
                        _LocationStatePanel(
                          state: _state,
                          status: _status,
                          onAuthorize: _requestAndRefreshLocation,
                          onChoose: _openModifySheet,
                          onAlternatives: _openModifySheet,
                        ),
                      const _SectionDivider(),
                      Text(
                        'Instructions pour le médecin',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: OmniColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Facultatif',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: OmniColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const ValueKey('emergency-arrival-instructions'),
                        controller: _arrivalInstructions,
                        minLines: 3,
                        maxLines: 5,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          hintText:
                              'Appartement, étage, porte, point de repère...',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _ContinueFooter(
            enabled: _location?.canContinue == true,
            onPressed: _continue,
          ),
        ],
      ),
    ),
  );
}

enum _LocationState {
  unselected,
  resolving,
  resolved,
  denied,
  deniedForever,
  unavailable,
}

enum _LocationOption { current, search, map, manual }

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Retour',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        Expanded(
          child: Text(
            'Demande urgente',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: OmniColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _LocationStatePanel extends StatelessWidget {
  const _LocationStatePanel({
    required this.state,
    required this.status,
    required this.onAuthorize,
    required this.onChoose,
    required this.onAlternatives,
  });
  final _LocationState state;
  final String? status;
  final VoidCallback onAuthorize;
  final VoidCallback onChoose;
  final VoidCallback onAlternatives;

  @override
  Widget build(BuildContext context) {
    final loading = state == _LocationState.resolving;
    final unselected = state == _LocationState.unselected;
    final title = unselected
        ? 'Aucun lieu sélectionné'
        : loading
        ? 'Recherche de votre position'
        : 'Localisation indisponible';
    final copy = unselected
        ? 'Indiquez précisément où le médecin doit se rendre.'
        : loading
        ? status ?? 'Préparation de la localisation…'
        : status ?? 'Vous pouvez choisir un autre moyen d’indiquer le lieu.';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OmniColors.surfaceSecondary,
        border: Border.all(color: OmniColors.borderLight),
        borderRadius: BorderRadius.circular(OmniRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                loading
                    ? Icons.location_searching_rounded
                    : Icons.location_on_outlined,
                color: OmniColors.infoBlue,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: OmniColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (loading)
                const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            copy,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: OmniColors.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          if (!loading) ...[
            const SizedBox(height: 16),
            if (unselected)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: onChoose,
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Choisir le lieu'),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: onAlternatives,
                  icon: const Icon(Icons.edit_location_alt_outlined),
                  label: const Text('Choisir une autre adresse'),
                ),
              ),
            if (!unselected)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: onAuthorize,
                  child: const Text('Réessayer la localisation'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({required this.location, required this.mapsEnabled});
  final SelectedConsultationLocation location;
  final bool mapsEnabled;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Aperçu de la position sélectionnée',
    child: ClipRRect(
      borderRadius: BorderRadius.circular(OmniRadii.card),
      child: Container(
        height: 280,
        decoration: BoxDecoration(
          border: Border.all(color: OmniColors.borderLight),
          borderRadius: BorderRadius.circular(OmniRadii.card),
        ),
        child: !mapsEnabled
            ? const _MapUnavailable()
            : GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(location.latitude!, location.longitude!),
                  zoom: 16,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('consultation-location'),
                    position: LatLng(location.latitude!, location.longitude!),
                  ),
                },
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                myLocationButtonEnabled: false,
                rotateGesturesEnabled: false,
                scrollGesturesEnabled: false,
                tiltGesturesEnabled: false,
              ),
      ),
    ),
  );
}

class _MapUnavailable extends StatelessWidget {
  const _MapUnavailable();
  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: OmniColors.surfaceSecondary,
    child: Center(
      child: Icon(Icons.map_outlined, color: OmniColors.infoBlue, size: 36),
    ),
  );
}

class _DebugWebManualSurface extends StatelessWidget {
  const _DebugWebManualSurface();

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 160),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: OmniColors.surfaceSecondary,
      border: Border.all(color: OmniColors.borderLight),
      borderRadius: BorderRadius.circular(OmniRadii.card),
    ),
    child: const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.edit_location_alt_outlined, color: OmniColors.infoBlue),
        SizedBox(height: 12),
        Text(
          'Adresse saisie manuellement',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 4),
        Text(
          'La position exacte sera résolue sur Android.',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class _SelectedLocationSurface extends StatelessWidget {
  const _SelectedLocationSurface({required this.location});
  final SelectedConsultationLocation location;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: OmniColors.mintSoft,
      border: Border.all(color: OmniColors.freshMint),
      borderRadius: BorderRadius.circular(OmniRadii.card),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.location_on_outlined, color: OmniColors.deepTeal),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lieu de consultation',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: OmniColors.deepTeal,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                location.formattedAddress,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OmniColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    color: OmniColors.deepTeal,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Localisation sélectionnée',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: OmniColors.deepTeal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 24),
    child: Divider(height: 1, color: OmniColors.borderLight),
  );
}

class _ContinueFooter extends StatelessWidget {
  const _ContinueFooter({required this.enabled, required this.onPressed});
  final bool enabled;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: OmniColors.surfacePrimary,
      border: Border(top: BorderSide(color: OmniColors.borderLight)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                key: const ValueKey('emergency-continue'),
                onPressed: enabled ? onPressed : null,
                child: const Text('Continuer'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ModifyLocationSheet extends StatelessWidget {
  const _ModifyLocationSheet();
  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.86;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const SizedBox(width: 48),
                Expanded(
                  child: Text(
                    'Modifier le lieu',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Fermer',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _LocationOptionRow(
              icon: Icons.my_location_rounded,
              title: 'Utiliser ma position actuelle',
              subtitle: 'Détecter ma position avec le GPS',
              option: _LocationOption.current,
            ),
            _LocationOptionRow(
              icon: Icons.search_rounded,
              title: 'Rechercher une adresse',
              subtitle: 'Rechercher une rue, un bâtiment ou un lieu',
              option: _LocationOption.search,
            ),
            _LocationOptionRow(
              icon: Icons.map_outlined,
              title: 'Choisir sur la carte',
              subtitle: 'Placer précisément le point de rendez-vous',
              option: _LocationOption.map,
            ),
            _LocationOptionRow(
              icon: Icons.edit_location_alt_outlined,
              title: "Saisir l'adresse manuellement",
              subtitle: 'Ville, rue et informations complémentaires',
              option: _LocationOption.manual,
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationOptionRow extends StatelessWidget {
  const _LocationOptionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.option,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final _LocationOption option;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    minVerticalPadding: 10,
    leading: Icon(icon, color: OmniColors.infoBlue),
    title: Text(
      title,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: OmniColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
    ),
    subtitle: Text(
      subtitle,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: OmniColors.textSecondary),
    ),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: () => Navigator.pop(context, option),
  );
}

class _AddressSearchScreen extends StatefulWidget {
  const _AddressSearchScreen({required this.gateway});
  final EmergencyPlacesGateway gateway;

  @override
  State<_AddressSearchScreen> createState() => _AddressSearchScreenState();
}

class _AddressSearchScreenState extends State<_AddressSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<EmergencyPlacePrediction> _results = const [];
  bool _loading = false;
  String? _error;
  bool _sessionStarted = false;
  int _requestId = 0;

  static const _minimumQueryLength = 3;

  @override
  void dispose() {
    _debounce?.cancel();
    if (_sessionStarted) unawaited(widget.gateway.endSession());
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    final requestId = ++_requestId;
    if (query.length < _minimumQueryLength) {
      setState(() {
        _results = const [];
        _loading = false;
        _error = null;
      });
      unawaited(_endSession());
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    _debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_search(query, requestId));
    });
  }

  Future<void> _endSession() async {
    if (!_sessionStarted) return;
    _sessionStarted = false;
    await widget.gateway.endSession();
  }

  Future<void> _search(String query, int requestId) async {
    try {
      if (!_sessionStarted) {
        await widget.gateway.startSession();
        _sessionStarted = true;
      }
      if (!mounted || requestId != _requestId) return;
      final results = await widget.gateway.predictions(query);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _results = results;
        _loading = false;
        _error = results.isEmpty
            ? 'Aucune adresse trouvée. Essayez avec plus de détails.'
            : null;
      });
    } catch (_) {
      if (mounted && requestId == _requestId) {
        setState(() {
          _loading = false;
          _error = 'La recherche est momentanément indisponible.';
        });
      }
    }
  }

  Future<void> _searchImmediately() async {
    final query = _controller.text.trim();
    if (query.length < _minimumQueryLength) {
      setState(() {
        _results = const [];
        _loading = false;
        _error = query.isEmpty
            ? null
            : 'Saisissez au moins $_minimumQueryLength caractères.';
      });
      return;
    }
    _debounce?.cancel();
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    await _search(query, requestId);
  }

  Future<void> _select(EmergencyPlacePrediction prediction) async {
    _debounce?.cancel();
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final location = await widget.gateway.fetchPlace(prediction);
      if (!mounted || requestId != _requestId) return;
      await widget.gateway.endSession();
      _sessionStarted = false;
      if (mounted) Navigator.pop(context, location);
    } catch (_) {
      if (mounted && requestId == _requestId) {
        setState(() {
          _loading = false;
          _error = 'Cette adresse n’a pas pu être sélectionnée. Réessayez.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: OmniColors.pageBackground,
    appBar: AppBar(title: const Text('Rechercher une adresse')),
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          TextField(
            key: const ValueKey('location-search-field'),
            controller: _controller,
            autofocus: true,
            onSubmitted: (_) => _searchImmediately(),
            onChanged: _onQueryChanged,
            decoration: InputDecoration(
              hintText: 'Rue, bâtiment ou lieu',
              suffixIcon: IconButton(
                tooltip: 'Rechercher',
                onPressed: _searchImmediately,
                icon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                _error!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OmniColors.textSecondary,
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final result = _results[index];
                return ListTile(
                  leading: const Icon(
                    Icons.location_on_outlined,
                    color: OmniColors.infoBlue,
                  ),
                  title: Text(result.primaryText),
                  subtitle: result.secondaryText.isEmpty
                      ? null
                      : Text(result.secondaryText),
                  onTap: _loading ? null : () => _select(result),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _ManualAddressScreen extends StatefulWidget {
  const _ManualAddressScreen({required this.gateway});
  final EmergencyLocationGateway gateway;

  @override
  State<_ManualAddressScreen> createState() => _ManualAddressScreenState();
}

class _ManualAddressScreenState extends State<_ManualAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _governorate = TextEditingController();
  final _city = TextEditingController();
  final _street = TextEditingController();
  final _extra = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _governorate.dispose();
    _city.dispose();
    _street.dispose();
    _extra.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final governorate = _governorate.text.trim();
    final city = _city.text.trim();
    final street = _street.text.trim();
    final extra = _extra.text.trim();
    final address = [
      street,
      city,
      governorate,
      if (extra.isNotEmpty) extra,
    ].join(', ');

    // This is intentionally limited to Chrome development. Native platforms
    // must still resolve a manual address before it can be selected.
    final isDebugWebManualFallback = kIsWeb && kDebugMode;
    if (isDebugWebManualFallback) {
      Navigator.pop(
        context,
        SelectedConsultationLocation(
          source: ConsultationLocationSource.manual,
          formattedAddress: address,
          street: street,
          city: city,
          governorate: governorate,
          apartment: extra.isEmpty ? null : extra,
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await widget.gateway.search(address);
      if (!mounted) return;
      if (results.isEmpty) {
        setState(() {
          _loading = false;
          _error =
              'Cette adresse n’a pas pu être localisée. Vérifiez les informations ou choisissez sur la carte.';
        });
        return;
      }
      final result = results.first;
      Navigator.pop(
        context,
        SelectedConsultationLocation(
          source: ConsultationLocationSource.manual,
          latitude: result.latitude,
          longitude: result.longitude,
          formattedAddress: address,
          street: street,
          city: city,
          governorate: governorate,
          apartment: extra.isEmpty ? null : extra,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error =
              'Cette adresse n’a pas pu être localisée. Vérifiez les informations ou choisissez sur la carte.';
        });
      }
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = true,
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
      ),
      validator: required
          ? (value) => value == null || value.trim().isEmpty
                ? 'Ce champ est requis.'
                : null
          : null,
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: OmniColors.pageBackground,
    appBar: AppBar(title: const Text("Saisir l'adresse")),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _field(_governorate, 'Gouvernorat'),
                      _field(_city, 'Ville / Localité'),
                      _field(
                        _street,
                        'Rue / Adresse',
                        hint: 'Rue, bâtiment ou résidence',
                      ),
                      _field(_extra, 'N° / Résidence', required: false),
                      if (_error != null)
                        Text(
                          _error!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: OmniColors.urgentCoral),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: 50,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _save,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Utiliser cette adresse'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _MapPickerScreen extends StatefulWidget {
  const _MapPickerScreen({
    required this.gateway,
    required this.mapsEnabled,
    this.initial,
    this.mapBuilder,
  });
  final EmergencyLocationGateway gateway;
  final bool mapsEnabled;
  final SelectedConsultationLocation? initial;
  final EmergencyMapBuilder? mapBuilder;

  @override
  State<_MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<_MapPickerScreen> {
  Timer? _debounce;
  late LatLng _center;
  SelectedConsultationLocation? _resolved;
  bool _resolving = false;
  bool _hasUserMoved = false;
  String? _resolutionError;
  int _resolutionRequestId = 0;

  static const _minimumCameraDelta = 0.0001;

  @override
  void initState() {
    super.initState();
    _center = LatLng(
      widget.initial?.latitude ?? 36.8065,
      widget.initial?.longitude ?? 10.1815,
    );
    _hasUserMoved = widget.initial != null;
    if (_hasUserMoved) _resolve();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _cameraMove(CameraPosition position) {
    final movedFromInitial =
        (position.target.latitude - _initialCenter.latitude).abs() >
            _minimumCameraDelta ||
        (position.target.longitude - _initialCenter.longitude).abs() >
            _minimumCameraDelta;
    _center = position.target;
    if (movedFromInitial && !_hasUserMoved) {
      _hasUserMoved = true;
    }
    if (movedFromInitial &&
        (_resolved != null || _resolutionError != null) &&
        mounted) {
      setState(() {
        _resolved = null;
        _resolutionError = null;
      });
    }
  }

  void _cameraIdle() {
    if (!_hasUserMoved) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _resolve);
  }

  Future<void> _resolve() async {
    final requestId = ++_resolutionRequestId;
    final center = _center;
    setState(() {
      _resolving = true;
      _resolutionError = null;
    });
    try {
      final result = await widget.gateway.reverseGeocode(
        center,
        source: ConsultationLocationSource.mapPicker,
      );
      if (mounted && requestId == _resolutionRequestId) {
        setState(() {
          _resolved = result;
          _resolutionError = result == null
              ? 'Adresse indisponible. Déplacez la carte et réessayez.'
              : null;
        });
      }
    } catch (_) {
      if (mounted && requestId == _resolutionRequestId) {
        setState(() {
          _resolved = null;
          _resolutionError =
              'Adresse indisponible. Déplacez la carte et réessayez.';
        });
      }
    } finally {
      if (mounted && requestId == _resolutionRequestId) {
        setState(() => _resolving = false);
      }
    }
  }

  LatLng get _initialCenter => LatLng(
    widget.initial?.latitude ?? 36.8065,
    widget.initial?.longitude ?? 10.1815,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: OmniColors.pageBackground,
    appBar: AppBar(title: const Text('Choisir sur la carte')),
    body: Column(
      children: [
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              widget.mapBuilder != null
                  ? widget.mapBuilder!(
                      initialCameraPosition: CameraPosition(
                        target: _center,
                        zoom: 16,
                      ),
                      onCameraMove: _cameraMove,
                      onCameraIdle: _cameraIdle,
                    )
                  : !widget.mapsEnabled
                  ? const _MapUnavailable()
                  : GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _center,
                        zoom: 16,
                      ),
                      onCameraMove: _cameraMove,
                      onCameraIdle: _cameraIdle,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                    ),
              const IgnorePointer(
                child: Icon(
                  Icons.location_pin,
                  color: OmniColors.urgentCoral,
                  size: 48,
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _resolving
                      ? 'Recherche de l’adresse…'
                      : _resolved?.formattedAddress ??
                            _resolutionError ??
                            (_hasUserMoved
                                ? 'Adresse indisponible'
                                : 'Déplacez la carte pour choisir le point exact.'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _resolved?.isUsable == true
                        ? () => Navigator.pop(context, _resolved)
                        : null,
                    child: const Text('Confirmer cette position'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
