import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;

class ProviderMapScreen extends StatefulWidget {
  final String providerType; // 'doctor' or 'kine'
  final List<Map<String, dynamic>> providers;

  const ProviderMapScreen({
    super.key,
    required this.providerType,
    required this.providers,
  });

  @override
  State<ProviderMapScreen> createState() => _ProviderMapScreenState();
}

class _ProviderMapScreenState extends State<ProviderMapScreen> {
  GoogleMapController? _mapController;
  Map<String, dynamic>? _selectedProvider;

  // User location (simulated - Tunis center)
  static const LatLng _userLocation = LatLng(36.8065, 10.1815);

  // Generate provider locations around user
  final Map<String, LatLng> _providerLocations = {};

  @override
  void initState() {
    super.initState();
    _generateProviderLocations();
  }

  void _generateProviderLocations() {
    // Generate locations based on distance from mock data
    for (var provider in widget.providers) {
      final distance = provider['distance'] as double;
      // Simple calculation: spread providers around user location
      final angle =
          widget.providers.indexOf(provider) * (360 / widget.providers.length);
      final radians = angle * math.pi / 180;

      // Approximate: 1 km ≈ 0.009 degrees
      final latOffset = distance * 0.009 * math.cos(radians);
      final lngOffset = distance * 0.009 * math.sin(radians);

      _providerLocations[provider['id']] = LatLng(
        _userLocation.latitude + latOffset,
        _userLocation.longitude + lngOffset,
      );
    }
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    // User marker (blue)
    markers.add(
      Marker(
        markerId: const MarkerId('user'),
        position: _userLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'Votre position'),
      ),
    );

    // Provider markers (green)
    for (var provider in widget.providers) {
      final location = _providerLocations[provider['id']];
      if (location != null) {
        markers.add(
          Marker(
            markerId: MarkerId(provider['id']),
            position: location,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
            infoWindow: InfoWindow(
              title: provider['name'],
              snippet: '${provider['distance']} km • ${provider['price']} DT',
            ),
            onTap: () {
              setState(() {
                _selectedProvider = provider;
              });
            },
          ),
        );
      }
    }

    return markers;
  }

  Set<Circle> _buildCircles() {
    final circles = <Circle>{};

    // Add circles around user location for distance reference
    for (var radius in [1.0, 2.0, 3.0]) {
      circles.add(
        Circle(
          circleId: CircleId('radius_$radius'),
          center: _userLocation,
          radius: radius * 1000, // Convert km to meters
          fillColor: const Color(0xFF1FBF9A).withOpacity(0.05),
          strokeColor: const Color(0xFF1FBF9A).withOpacity(0.3),
          strokeWidth: 1,
        ),
      );
    }

    return circles;
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.providerType == 'doctor'
        ? 'Carte des Docteurs'
        : 'Carte des Kinésithérapeutes';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1D2939)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1D2939),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _userLocation,
              zoom: 13.0,
            ),
            markers: _buildMarkers(),
            circles: _buildCircles(),
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            onTap: (_) {
              setState(() {
                _selectedProvider = null;
              });
            },
          ),

          // Legend
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLegendItem(color: Colors.blue, label: 'Vous'),
                  const SizedBox(width: 16),
                  _buildLegendItem(
                    color: Colors.green,
                    label: widget.providerType == 'doctor'
                        ? 'Docteurs'
                        : 'Kinés',
                  ),
                  const Spacer(),
                  Text(
                    '${widget.providers.length} disponibles',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Selected provider card
          if (_selectedProvider != null)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _buildProviderCard(_selectedProvider!),
            ),

          // My location button
          Positioned(
            bottom: _selectedProvider != null ? 180 : 100,
            right: 16,
            child: FloatingActionButton(
              onPressed: () {
                _mapController?.animateCamera(
                  CameraUpdate.newCameraPosition(
                    const CameraPosition(target: _userLocation, zoom: 13.0),
                  ),
                );
              },
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Color(0xFF1FBF9A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1D2939),
          ),
        ),
      ],
    );
  }

  Widget _buildProviderCard(Map<String, dynamic> provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1FBF9A), Color(0xFF0F6F73)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider['name'],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1D2939),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      provider['specialty'],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: const Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () {
                  setState(() {
                    _selectedProvider = null;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.star, color: Color(0xFFFBBF24), size: 16),
              const SizedBox(width: 4),
              Text(
                '${provider['rating']}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1D2939),
                ),
              ),
              Text(
                ' (${provider['reviews']})',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: const Color(0xFF667085),
                ),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.location_on, color: Color(0xFF1FBF9A), size: 16),
              const SizedBox(width: 4),
              Text(
                '${provider['distance']} km',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1FBF9A),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1FBF9A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${provider['price']} DT',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1FBF9A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Navigate to provider location
                final location = _providerLocations[provider['id']];
                if (location != null) {
                  _mapController?.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(target: location, zoom: 15.0),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1FBF9A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.navigation, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Centrer sur la carte',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
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
}
