import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'maps_configuration.dart';

typedef MapsConfigurationLoader = Future<MapsConfigurationStatus> Function();
typedef SyntheticMapBuilder =
    Widget Function({
      required CameraPosition initialCameraPosition,
      required Set<Marker> markers,
      required void Function(GoogleMapController controller) onMapCreated,
    });

class SyntheticMapsSmokeScreen extends StatefulWidget {
  const SyntheticMapsSmokeScreen({
    super.key,
    this.configurationLoader = loadMapsConfiguration,
    this.mapBuilder = _defaultMapBuilder,
    this.initializationTimeout = const Duration(seconds: 8),
    this.onDisposed,
  });

  static const syntheticDestination = LatLng(0, 0);
  static const syntheticCamera = CameraPosition(
    target: syntheticDestination,
    zoom: 4,
  );

  final MapsConfigurationLoader configurationLoader;
  final SyntheticMapBuilder mapBuilder;
  final Duration initializationTimeout;

  @visibleForTesting
  final VoidCallback? onDisposed;

  static Widget _defaultMapBuilder({
    required CameraPosition initialCameraPosition,
    required Set<Marker> markers,
    required void Function(GoogleMapController controller) onMapCreated,
  }) => GoogleMap(
    initialCameraPosition: initialCameraPosition,
    markers: markers,
    onMapCreated: onMapCreated,
    myLocationEnabled: false,
    myLocationButtonEnabled: false,
    mapToolbarEnabled: false,
    zoomControlsEnabled: true,
  );

  @override
  State<SyntheticMapsSmokeScreen> createState() =>
      _SyntheticMapsSmokeScreenState();
}

enum _SyntheticMapsSmokeState {
  checkingConfiguration,
  initializingMap,
  ready,
  unavailable,
}

class _SyntheticMapsSmokeScreenState extends State<SyntheticMapsSmokeScreen> {
  static const _marker = Marker(
    markerId: MarkerId('synthetic-destination'),
    position: SyntheticMapsSmokeScreen.syntheticDestination,
    infoWindow: InfoWindow(title: 'Destination synthétique'),
  );

  final Stopwatch _initializationStopwatch = Stopwatch();
  _SyntheticMapsSmokeState _state =
      _SyntheticMapsSmokeState.checkingConfiguration;
  GoogleMapController? _mapController;
  Timer? _initializationTimer;
  int? _initializationMilliseconds;

  @override
  void initState() {
    super.initState();
    _initializationStopwatch.start();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final status = await widget.configurationLoader();
    if (!mounted) return;
    if (!status.configured) {
      _initializationStopwatch.stop();
      setState(() => _state = _SyntheticMapsSmokeState.unavailable);
      return;
    }
    setState(() => _state = _SyntheticMapsSmokeState.initializingMap);
    _initializationTimer = Timer(widget.initializationTimeout, () {
      if (!mounted || _state != _SyntheticMapsSmokeState.initializingMap) {
        return;
      }
      _initializationStopwatch.stop();
      setState(() => _state = _SyntheticMapsSmokeState.unavailable);
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    if (!mounted) {
      controller.dispose();
      return;
    }
    final previous = _mapController;
    _mapController = controller;
    if (previous != null && !identical(previous, controller)) {
      previous.dispose();
    }
    _initializationTimer?.cancel();
    _initializationStopwatch.stop();
    setState(() {
      _initializationMilliseconds =
          _initializationStopwatch.elapsedMilliseconds;
      _state = _SyntheticMapsSmokeState.ready;
    });
  }

  @override
  void dispose() {
    _initializationTimer?.cancel();
    _initializationStopwatch.stop();
    final controller = _mapController;
    _mapController = null;
    controller?.dispose();
    widget.onDisposed?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Google Maps — test synthétique')),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Harness développeur isolé',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'La coordonnée 0°, 0° est exclusivement synthétique. '
              'Aucune donnée Patient, route, distance ou ETA n’est utilisée.',
            ),
            const SizedBox(height: 20),
            Expanded(child: _mapArea()),
            const SizedBox(height: 12),
            _statusText(),
          ],
        ),
      ),
    ),
  );

  Widget _mapArea() => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xffeef3f4),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xffd5dfe1)),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: switch (_state) {
        _SyntheticMapsSmokeState.checkingConfiguration =>
          const _NeutralMapState(
            key: ValueKey('maps-smoke-loading'),
            icon: Icons.map_outlined,
            message: 'Vérification de la configuration Maps…',
            loading: true,
          ),
        _SyntheticMapsSmokeState.unavailable => const _NeutralMapState(
          key: ValueKey('maps-smoke-unavailable'),
          icon: Icons.map_outlined,
          message:
              'Google Maps n’est pas disponible. Vérifiez la clé restreinte, '
              'l’API activée et la connexion.',
        ),
        _SyntheticMapsSmokeState.initializingMap ||
        _SyntheticMapsSmokeState.ready => Stack(
          fit: StackFit.expand,
          children: [
            widget.mapBuilder(
              initialCameraPosition: SyntheticMapsSmokeScreen.syntheticCamera,
              markers: {_marker},
              onMapCreated: _onMapCreated,
            ),
            if (_state == _SyntheticMapsSmokeState.initializingMap)
              const ColoredBox(
                color: Color(0xccffffff),
                child: _NeutralMapState(
                  key: ValueKey('maps-smoke-initializing'),
                  icon: Icons.map_outlined,
                  message: 'Initialisation de Google Maps…',
                  loading: true,
                ),
              ),
          ],
        ),
      },
    ),
  );

  Widget _statusText() => Semantics(
    liveRegion: true,
    child: Text(
      switch (_state) {
        _SyntheticMapsSmokeState.checkingConfiguration =>
          'État : vérification de la configuration',
        _SyntheticMapsSmokeState.initializingMap =>
          'État : initialisation de la vue cartographique',
        _SyntheticMapsSmokeState.ready =>
          'État : carte prête en ${_initializationMilliseconds ?? 0} ms',
        _SyntheticMapsSmokeState.unavailable =>
          'État : indisponible, aucune donnée sensible affichée',
      },
      key: const ValueKey('maps-smoke-status'),
      textAlign: TextAlign.center,
    ),
  );
}

class _NeutralMapState extends StatelessWidget {
  const _NeutralMapState({
    super.key,
    required this.icon,
    required this.message,
    this.loading = false,
  });

  final IconData icon;
  final String message;
  final bool loading;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 38, color: const Color(0xff41656b)),
          const SizedBox(height: 12),
          if (loading) ...[
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 12),
          ],
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
