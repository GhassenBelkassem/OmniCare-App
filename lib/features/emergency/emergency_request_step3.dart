import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class EmergencyRequestStep3 extends StatefulWidget {
  final Map<String, dynamic> previousData;

  const EmergencyRequestStep3({
    Key? key,
    required this.previousData,
  }) : super(key: key);

  @override
  State<EmergencyRequestStep3> createState() => _EmergencyRequestStep3State();
}

class _EmergencyRequestStep3State extends State<EmergencyRequestStep3> {
  GoogleMapController? _mapController;
  LatLng _selectedLocation = const LatLng(36.8065, 10.1815); // Tunis default
  String _selectedAddress = '';
  bool _isLoadingLocation = false;
  bool _useManualAddress = false;
  
  final TextEditingController _streetController = TextEditingController();
  final TextEditingController _apartmentController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _streetController.dispose();
    _apartmentController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationServiceDialog();
        setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      print('📍 GPS Location: ${position.latitude}, ${position.longitude}');

      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_selectedLocation, 15),
      );

      await _getAddressFromLatLng(_selectedLocation);
    } catch (e) {
      print('Error getting location: $e');
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _selectedAddress = '${place.street}, ${place.locality}, ${place.country}';
        });
      }
    } catch (e) {
      print('Error getting address: $e');
      setState(() {
        _selectedAddress = 'Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}';
      });
    }
  }

  void _showLocationServiceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Service de localisation désactivé',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Veuillez activer le service de localisation pour utiliser cette fonctionnalité.',
          style: GoogleFonts.plusJakartaSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: GoogleFonts.plusJakartaSans()),
          ),
        ],
      ),
    );
  }

  bool _canProceed() {
    if (_useManualAddress) {
      return _streetController.text.isNotEmpty && _cityController.text.isNotEmpty;
    }
    return _selectedAddress.isNotEmpty;
  }

  void _handleNext() {
    if (!_canProceed()) return;

    final data = {
      ...widget.previousData,
      'location': _useManualAddress
          ? {
              'type': 'manual',
              'street': _streetController.text,
              'apartment': _apartmentController.text,
              'city': _cityController.text,
              'fullAddress': '${_streetController.text}, ${_apartmentController.text}, ${_cityController.text}',
            }
          : {
              'type': 'gps',
              'latitude': _selectedLocation.latitude,
              'longitude': _selectedLocation.longitude,
              'address': _selectedAddress,
            },
    };

    Navigator.pushNamed(
      context,
      '/doctor-selection',
      arguments: data,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A202C)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Demande Urgente',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A202C),
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            _buildProgressBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lieu de la Visite',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A202C),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Indiquez où le médecin doit vous rencontrer',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              color: const Color(0xFF667085),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildLocationTypeToggle(),
                          const SizedBox(height: 24),
                          if (!_useManualAddress) ...[
                            _buildMapSection(),
                          ] else ...[
                            _buildManualAddressForm(),
                          ],
                          const SizedBox(height: 24),
                          _buildActionButtons(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildProgressStep(1, true)),
              const SizedBox(width: 8),
              Expanded(child: _buildProgressStep(2, true)),
              const SizedBox(width: 8),
              Expanded(child: _buildProgressStep(3, true)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Étape 3 sur 3',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF667085),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStep(int step, bool isActive) {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF1FBF9A) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildLocationTypeToggle() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _useManualAddress = false),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: !_useManualAddress
                    ? const Color(0xFF1FBF9A)
                    : Colors.white,
                border: Border.all(
                  color: !_useManualAddress
                      ? const Color(0xFF1FBF9A)
                      : const Color(0xFFE2E8F0),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map,
                    color: !_useManualAddress
                        ? Colors.white
                        : const Color(0xFF667085),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Carte',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: !_useManualAddress
                          ? Colors.white
                          : const Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _useManualAddress = true),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _useManualAddress
                    ? const Color(0xFF1FBF9A)
                    : Colors.white,
                border: Border.all(
                  color: _useManualAddress
                      ? const Color(0xFF1FBF9A)
                      : const Color(0xFFE2E8F0),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.edit_location_alt,
                    color: _useManualAddress
                        ? Colors.white
                        : const Color(0xFF667085),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Manuelle',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _useManualAddress
                          ? Colors.white
                          : const Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _selectedLocation,
                  zoom: 15,
                ),
                onMapCreated: (controller) {
                  _mapController = controller;
                },
                onTap: (position) {
                  setState(() {
                    _selectedLocation = position;
                  });
                  _getAddressFromLatLng(position);
                },
                markers: {
                  Marker(
                    markerId: const MarkerId('selected_location'),
                    position: _selectedLocation,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen,
                    ),
                  ),
                },
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
              ),
              if (_isLoadingLocation)
                Container(
                  color: Colors.white.withOpacity(0.8),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF1FBF9A),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                icon: const Icon(Icons.my_location, size: 18),
                label: Text(
                  'Ma Position',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1FBF9A),
                  side: const BorderSide(color: Color(0xFF1FBF9A)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_selectedAddress.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1FBF9A).withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF1FBF9A).withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: Color(0xFF1FBF9A),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Adresse Sélectionnée',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF667085),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedAddress,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A202C),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildManualAddressForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _streetController,
          label: 'Rue',
          hint: 'Ex: 123 Avenue Habib Bourguiba',
          icon: Icons.home,
          required: true,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _apartmentController,
          label: 'Appartement / Étage',
          hint: 'Ex: Appartement 4, 2ème étage',
          icon: Icons.apartment,
          required: false,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _cityController,
          label: 'Ville',
          hint: 'Ex: Tunis',
          icon: Icons.location_city,
          required: true,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool required,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A202C),
              ),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(color: Color(0xFFEF4444), fontSize: 14),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF9CA3AF),
            ),
            prefixIcon: Icon(icon, color: const Color(0xFF667085), size: 20),
            filled: true,
            fillColor: const Color(0xFFF4F5F7),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1FBF9A), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: const Color(0xFF1A202C),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1A202C),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.arrow_back, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Retour',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _canProceed() ? _handleNext : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1FBF9A),
              disabledBackgroundColor: const Color(0xFFE2E8F0),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Continuer',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _canProceed() ? Colors.white : const Color(0xFF9CA3AF),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
