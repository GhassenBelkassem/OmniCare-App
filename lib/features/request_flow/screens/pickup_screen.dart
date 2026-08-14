import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../request_core/application/request_submission_controller.dart';
import '../../request_core/domain/pickup_location.dart';
import '../../request_core/domain/request_vocabulary.dart';
import 'review_screen.dart';

/// Step 4 — Ambulance pickup location (AMBULANCE only).
///
/// The configured Google Maps integration provides `MAP_SELECTION` alongside
/// explicit device GPS and manual-address sources.
///
/// Privacy: location permission is requested only on an explicit user tap,
/// never in [initState]; coordinates are never logged; the position is captured
/// once (no stream) and shown only as a confirmation the patient must approve.
class PickupScreen extends StatefulWidget {
  const PickupScreen({super.key});

  @override
  State<PickupScreen> createState() => _PickupScreenState();
}

class _PickupScreenState extends State<PickupScreen> {
  static const int _addressLineMax = 160;
  static const int _addressDetailsMax = 160;
  static const int _cityMax = 80;
  static const int _governorateMax = 80;

  _PickupMode _mode = _PickupMode.choice;
  GeoPoint? _capturedPoint;
  LatLng? _selectedMapPoint;
  bool _locating = false;
  String? _locationError;

  final _addressLineController = TextEditingController();
  final _addressDetailsController = TextEditingController();
  final _cityController = TextEditingController();
  final _governorateController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _addressLineController.dispose();
    _addressDetailsController.dispose();
    _cityController.dispose();
    _governorateController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _fail('Location services are off. Enter the address manually.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _fail('Location permission was denied. Enter the address manually.');
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _fail(
          'Location permission is permanently denied. Enter the address '
          'manually in settings or use manual entry.',
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      // The coordinates are used only to build the frozen pickup payload; they
      // are never logged, printed or stored outside the secure in-flight store.
      final accuracy = position.accuracy.isFinite ? position.accuracy : null;
      if (!mounted) return;
      setState(() {
        _capturedPoint = GeoPoint.fromCapturedCoordinates(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMeters: accuracy,
        );
        _mode = _PickupMode.gpsConfirm;
        _locating = false;
      });
    } on LocationServiceDisabledException {
      _fail('Could not read location. Enter the address manually.');
    } catch (_) {
      // Raw exceptions may contain sensitive GPS context; surface a safe line.
      _fail('Could not read location. Enter the address manually.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _locationError = message;
      _locating = false;
    });
  }

  void _confirmGps(BuildContext context) {
    final point = _capturedPoint;
    if (point == null) return;
    context.read<RequestSubmissionController>().setPickupLocation(
      PickupLocationSelection(
        source: PickupLocationSource.deviceGps,
        geoPoint: point,
        capturedAt: DateTime.now(),
      ),
    );
    _proceed(context);
  }

  void _confirmMap(BuildContext context) {
    final point = _selectedMapPoint;
    if (point == null) return;
    context.read<RequestSubmissionController>().setPickupLocation(
      PickupLocationSelection(
        source: PickupLocationSource.mapSelection,
        geoPoint: GeoPoint.fromCapturedCoordinates(
          latitude: point.latitude,
          longitude: point.longitude,
        ),
        capturedAt: DateTime.now(),
      ),
    );
    _proceed(context);
  }

  void _confirmManual(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    final address = PostalAddress(
      addressLine: _addressLineController.text.trim(),
      addressDetails: _addressDetailsController.text.trim(),
      city: _cityController.text.trim(),
      governorate: _governorateController.text.trim(),
    );
    context.read<RequestSubmissionController>().setPickupLocation(
      PickupLocationSelection(
        source: PickupLocationSource.manualAddress,
        postalAddress: address,
        capturedAt: DateTime.now(),
      ),
    );
    _proceed(context);
  }

  void _proceed(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ReviewScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Pickup location',
          style: TextStyle(
            color: Color(0xFF1D2939),
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: const BackButton(color: Color(0xFF1D2939)),
      ),
      body: _mode == _PickupMode.gpsConfirm && _capturedPoint != null
          ? _GpsConfirmView(
              onConfirm: () => _confirmGps(context),
              onRetry: () {
                setState(() {
                  _mode = _PickupMode.choice;
                  _capturedPoint = null;
                });
              },
              locating: _locating,
            )
          : _mode == _PickupMode.manual
          ? _ManualAddressForm(
              formKey: _formKey,
              addressLineController: _addressLineController,
              addressDetailsController: _addressDetailsController,
              cityController: _cityController,
              governorateController: _governorateController,
              addressLineMax: _addressLineMax,
              addressDetailsMax: _addressDetailsMax,
              cityMax: _cityMax,
              governorateMax: _governorateMax,
              onConfirm: () => _confirmManual(context),
              onBack: () => setState(() => _mode = _PickupMode.choice),
            )
          : _mode == _PickupMode.map
          ? _MapSelectionView(
              selectedPoint: _selectedMapPoint,
              onPointChanged: (point) =>
                  setState(() => _selectedMapPoint = point),
              onConfirm: () => _confirmMap(context),
            )
          : _ChoiceView(
              locating: _locating,
              error: _locationError,
              onUseGps: _useCurrentLocation,
              onManual: () => setState(() => _mode = _PickupMode.manual),
              onMap: () => setState(() => _mode = _PickupMode.map),
            ),
    );
  }
}

enum _PickupMode { choice, gpsConfirm, manual, map }

class _ChoiceView extends StatelessWidget {
  const _ChoiceView({
    required this.locating,
    this.error,
    required this.onUseGps,
    required this.onManual,
    required this.onMap,
  });

  final bool locating;
  final String? error;
  final VoidCallback onUseGps;
  final VoidCallback onManual;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (error != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFD92D20).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              error!,
              style: const TextStyle(color: Color(0xFFD92D20), fontSize: 13),
            ),
          ),
        ],
        _SourceTile(
          icon: Icons.my_location,
          title: 'Use my current location',
          subtitle: 'Share your device location as the pickup point.',
          enabled: !locating,
          trailing: locating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: onUseGps,
        ),
        const SizedBox(height: 12),
        _SourceTile(
          icon: Icons.edit_location_alt_outlined,
          title: 'Enter address manually',
          subtitle: 'Type the pickup address yourself.',
          onTap: onManual,
        ),
        const SizedBox(height: 12),
        _SourceTile(
          icon: Icons.map_outlined,
          title: 'Choose on map',
          subtitle: 'Tap a point on the map and confirm it.',
          onTap: onMap,
        ),
      ],
    );
  }
}

class _MapSelectionView extends StatelessWidget {
  const _MapSelectionView({
    required this.selectedPoint,
    required this.onPointChanged,
    required this.onConfirm,
  });

  final LatLng? selectedPoint;
  final ValueChanged<LatLng> onPointChanged;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final point = selectedPoint;
    return Column(
      children: [
        Expanded(
          child: Semantics(
            label: 'Pickup location map. Tap a point to select it.',
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: point ?? const LatLng(36.8065, 10.1815),
                zoom: point == null ? 11 : 15,
              ),
              onTap: onPointChanged,
              markers: point == null
                  ? const <Marker>{}
                  : <Marker>{
                      Marker(
                        markerId: const MarkerId('ambulance-pickup'),
                        position: point,
                      ),
                    },
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Tap the map to set the pickup point, then confirm it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF475467)),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: point == null ? null : onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1FBF9A),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFD0D5DD),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Confirm location'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.enabled = true,
    this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.withOpacity(0.18)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1FBF9A).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: const Color(0xFF1FBF9A)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1D2939),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF667085),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GpsConfirmView extends StatelessWidget {
  const _GpsConfirmView({
    required this.onConfirm,
    required this.onRetry,
    required this.locating,
  });

  final VoidCallback onConfirm;
  final VoidCallback onRetry;
  final bool locating;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1FBF9A).withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                Icon(Icons.location_on, size: 64, color: Color(0xFF1FBF9A)),
                SizedBox(height: 16),
                Text(
                  'Location captured',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D2939),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Confirm this as your pickup location.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF667085)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: locating ? null : onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1FBF9A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Confirm location',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class _ManualAddressForm extends StatelessWidget {
  const _ManualAddressForm({
    required this.formKey,
    required this.addressLineController,
    required this.addressDetailsController,
    required this.cityController,
    required this.governorateController,
    required this.addressLineMax,
    required this.addressDetailsMax,
    required this.cityMax,
    required this.governorateMax,
    required this.onConfirm,
    required this.onBack,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController addressLineController;
  final TextEditingController addressDetailsController;
  final TextEditingController cityController;
  final TextEditingController governorateController;
  final int addressLineMax;
  final int addressDetailsMax;
  final int cityMax;
  final int governorateMax;
  final VoidCallback onConfirm;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: addressLineController,
            maxLength: addressLineMax,
            decoration: const InputDecoration(
              labelText: 'Address line',
              hintText: 'Street and number',
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Address is required'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: addressDetailsController,
            maxLength: addressDetailsMax,
            decoration: const InputDecoration(
              labelText: 'Additional details (optional)',
              hintText: 'Apartment, floor, landmark',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: cityController,
            maxLength: cityMax,
            decoration: const InputDecoration(labelText: 'City'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'City is required'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: governorateController,
            maxLength: governorateMax,
            decoration: const InputDecoration(
              labelText: 'Governorate (optional)',
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1FBF9A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Confirm address',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onBack, child: const Text('Back')),
        ],
      ),
    );
  }
}
