import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'navigation_screen.dart';

class RequestAcceptedScreen extends StatefulWidget {
  const RequestAcceptedScreen({super.key});

  @override
  State<RequestAcceptedScreen> createState() => _RequestAcceptedScreenState();
}

class _RequestAcceptedScreenState extends State<RequestAcceptedScreen> {
  bool _showWaiting = true;
  GoogleMapController? _mapController;
  
  // Patient location in Tunis (Avenue Habib Bourguiba)
  static const LatLng _patientLocation = LatLng(36.8065, 10.1815);
  
  // Doctor's starting position (simulated current location)
  static const LatLng _doctorLocation = LatLng(36.8265, 10.2015);

  // Patient data
  final Map<String, String> _patientData = {
    'name': 'Amina Chaari',
    'age': '32',
    'phone': '+216 98 765 432',
    'address': '15 Avenue Habib Bourguiba, Tunis',
    'distance': '1.8 km',
    'eta': '6 mins',
  };

  Future<void> _callPatient() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: _patientData['phone']);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not launch phone dialer',
              style: GoogleFonts.plusJakartaSans(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openNavigation() {
    // Open in-app navigation screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NavigationScreen(),
      ),
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
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1D2939)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _showWaiting ? 'Waiting for Patient' : 'Request Accepted',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1D2939),
          ),
        ),
      ),
      body: _showWaiting ? _buildWaitingState() : _buildAcceptedState(),
    );
  }

  Widget _buildWaitingState() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated waiting icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF1FBF9A).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.hourglass_empty,
                  size: 60,
                  color: Color(0xFF1FBF9A),
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            Text(
              'Waiting for Patient Selection',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1D2939),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            Text(
              'The patient is reviewing available doctors. You will be notified once they select you.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                color: const Color(0xFF667085),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            
            // Next button (static simulation)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() => _showWaiting = false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1FBF9A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Next (Simulate Selection)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcceptedState() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Success Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1FBF9A), Color(0xFF0F6F73)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Color(0xFF1FBF9A),
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'REQUEST ACCEPTED',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Patient selected you',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Patient Information Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Patient Information',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1D2939),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildInfoRow(Icons.person, 'Name', _patientData['name']!),
                  _buildInfoRow(Icons.cake, 'Age', '${_patientData['age']} years'),
                  _buildInfoRow(Icons.phone, 'Phone', _patientData['phone']!),
                  _buildInfoRow(Icons.location_on, 'Address', _patientData['address']!),
                  _buildInfoRow(Icons.social_distance, 'Distance', '${_patientData['distance']} • ${_patientData['eta']} ETA'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _callPatient,
                    icon: const Icon(Icons.phone, size: 20),
                    label: Text(
                      'Call Patient',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1FBF9A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openNavigation,
                    icon: const Icon(Icons.navigation, size: 20),
                    label: Text(
                      'Navigate',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F6F73),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Map Preview
            Container(
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD0D5DD)),
              ),
              clipBehavior: Clip.antiAlias,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _patientLocation,
                  zoom: 13.0,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('patient'),
                    position: _patientLocation,
                    infoWindow: InfoWindow(
                      title: _patientData['name'],
                      snippet: _patientData['address'],
                    ),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueRed,
                    ),
                  ),
                  Marker(
                    markerId: const MarkerId('doctor'),
                    position: _doctorLocation,
                    infoWindow: const InfoWindow(
                      title: 'Your Location',
                    ),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen,
                    ),
                  ),
                },
                polylines: {
                  Polyline(
                    polylineId: const PolylineId('route'),
                    points: [_doctorLocation, _patientLocation],
                    color: const Color(0xFF1FBF9A),
                    width: 4,
                  ),
                },
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                  // Fit bounds to show both markers
                  Future.delayed(const Duration(milliseconds: 500), () {
                    _mapController?.animateCamera(
                      CameraUpdate.newLatLngBounds(
                        LatLngBounds(
                          southwest: LatLng(
                            _patientLocation.latitude < _doctorLocation.latitude
                                ? _patientLocation.latitude
                                : _doctorLocation.latitude,
                            _patientLocation.longitude < _doctorLocation.longitude
                                ? _patientLocation.longitude
                                : _doctorLocation.longitude,
                          ),
                          northeast: LatLng(
                            _patientLocation.latitude > _doctorLocation.latitude
                                ? _patientLocation.latitude
                                : _doctorLocation.latitude,
                            _patientLocation.longitude > _doctorLocation.longitude
                                ? _patientLocation.longitude
                                : _doctorLocation.longitude,
                          ),
                        ),
                        50,
                      ),
                    );
                  });
                },
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
              ),
            ),
            const SizedBox(height: 16),
            
            // Map Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF8FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF0F6F73).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF0F6F73), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tap "Navigate" to open Google Maps with the fastest route to the patient',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: const Color(0xFF0F6F73),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF667085), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1D2939),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
