import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'qr_scanner_screen.dart';
import '../../core/models/patient_models.dart';
import 'patient_medical_passport_screen.dart';

class NavigationScreen extends StatefulWidget {
  final PatientSummary? patient;

  const NavigationScreen({super.key, this.patient});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  GoogleMapController? _mapController;

  // Patient location in Tunis (Avenue Habib Bourguiba)
  static const LatLng _patientLocation = LatLng(36.8065, 10.1815);

  // Doctor's starting position (simulated current location)
  static const LatLng _doctorLocation = LatLng(36.8265, 10.2015);

  // Route points for the polyline
  final List<LatLng> _routePoints = const [
    LatLng(36.8265, 10.2015), // Doctor location
    LatLng(36.8235, 10.1985),
    LatLng(36.8205, 10.1955),
    LatLng(36.8175, 10.1925),
    LatLng(36.8145, 10.1895),
    LatLng(36.8115, 10.1865),
    LatLng(36.8085, 10.1835),
    LatLng(36.8065, 10.1815), // Patient location
  ];

  // Patient data
  final Map<String, String> _patientData = {
    'name': 'Patient',
    'age': '32',
    'phone': '+216 98 765 432',
    'address': '15 Avenue Habib Bourguiba, Tunis',
    'distance': '1.8 km',
    'eta': '6 mins',
    'symptoms': 'Severe headache, Sensitivity to light, Nausea',
  };

  @override
  void initState() {
    super.initState();
    final name = widget.patient?.displayName;
    if (name != null && name.trim().isNotEmpty) {
      _patientData['name'] = name.trim();
    }
  }

  Future<void> _callPatient() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: _patientData['phone']);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Google Map with route
          if (kIsWeb)
            Container(
              color: const Color(0xFFEFF8FF),
              child: Center(
                child: Text(
                  'Map preview is not available on web',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF667085),
                  ),
                ),
              ),
            )
          else
            GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: _patientLocation,
                zoom: 13.0,
              ),
              markers: {
                // Patient marker (destination - red)
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
                // Doctor marker (current location - green)
                Marker(
                  markerId: const MarkerId('doctor'),
                  position: _doctorLocation,
                  infoWindow: const InfoWindow(title: 'Your Location'),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen,
                  ),
                ),
              },
              polylines: {
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: _routePoints,
                  color: const Color(0xFF1FBF9A),
                  width: 5,
                  geodesic: true,
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
                      80,
                    ),
                  );
                });
              },
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),

          // Top overlay - ETA Card
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ETA
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          color: Color(0xFF1FBF9A),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _patientData['eta']!,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1D2939),
                              ),
                            ),
                            Text(
                              'To patient',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: const Color(0xFF667085),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      color: const Color(0xFFD0D5DD),
                    ),
                    // Distance
                    Row(
                      children: [
                        const Icon(
                          Icons.navigation,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _patientData['distance']!,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1D2939),
                              ),
                            ),
                            Text(
                              'Distance',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                color: const Color(0xFF667085),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF1D2939)),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Draggable Bottom sheet - Patient info
          DraggableScrollableSheet(
            initialChildSize: 0.5, // Start at 50% of screen
            minChildSize:
                0.15, // Can minimize to 15% (just show drag handle and name)
            maxChildSize: 0.85, // Can expand to 85% of screen
            builder: (BuildContext context, ScrollController scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  children: [
                    // Drag handle
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12, bottom: 20),
                      alignment: Alignment.center,
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD0D5DD),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          // Patient info header
                          Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Colors.red, Colors.orange],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _patientData['name']!,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1D2939),
                                      ),
                                    ),
                                    Text(
                                      '${_patientData['age']} years old',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        color: const Color(0xFF667085),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  'HIGH PRIORITY',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Address
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 16,
                                color: Color(0xFF667085),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _patientData['address']!,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    color: const Color(0xFF667085),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1FBF9A).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF1FBF9A).withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1FBF9A),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Navigating to patient',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1FBF9A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Symptoms alert
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.amber.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber,
                                  color: Colors.amber,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Reported Symptoms',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.amber.shade900,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _patientData['symptoms']!,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          color: Colors.amber.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Safety & Emergency Section
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.shield,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Doctor Safety & Emergency',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.red.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Report any safety concerns or emergencies immediately',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    color: Colors.red.shade800,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            barrierDismissible: false,
                                            builder: (context) => Dialog(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  24,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    // Icon
                                                    Container(
                                                      width: 80,
                                                      height: 80,
                                                      decoration: BoxDecoration(
                                                        color: Colors.red
                                                            .withOpacity(0.1),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(
                                                        Icons.local_police,
                                                        color: Colors.red,
                                                        size: 40,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 20),
                                                    // Title
                                                    Text(
                                                      'Call Emergency Services',
                                                      style:
                                                          GoogleFonts.plusJakartaSans(
                                                            fontSize: 20,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: const Color(
                                                              0xFF1D2939,
                                                            ),
                                                          ),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                    const SizedBox(height: 12),
                                                    // Description
                                                    Text(
                                                      'This will immediately call the local police/emergency services (197). Use only in case of emergency or safety threat.',
                                                      style:
                                                          GoogleFonts.plusJakartaSans(
                                                            fontSize: 14,
                                                            color: const Color(
                                                              0xFF667085,
                                                            ),
                                                            height: 1.5,
                                                          ),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                    const SizedBox(height: 24),
                                                    // Buttons
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: OutlinedButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  context,
                                                                ),
                                                            style: OutlinedButton.styleFrom(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    vertical:
                                                                        14,
                                                                  ),
                                                              side: const BorderSide(
                                                                color: Color(
                                                                  0xFFD0D5DD,
                                                                ),
                                                              ),
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      12,
                                                                    ),
                                                              ),
                                                            ),
                                                            child: Text(
                                                              'Cancel',
                                                              style: GoogleFonts.plusJakartaSans(
                                                                fontSize: 15,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color:
                                                                    const Color(
                                                                      0xFF667085,
                                                                    ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 12,
                                                        ),
                                                        Expanded(
                                                          child: ElevatedButton(
                                                            onPressed: () async {
                                                              Navigator.pop(
                                                                context,
                                                              );
                                                              final Uri
                                                              emergencyUri =
                                                                  Uri(
                                                                    scheme:
                                                                        'tel',
                                                                    path: '197',
                                                                  );
                                                              if (await canLaunchUrl(
                                                                emergencyUri,
                                                              )) {
                                                                await launchUrl(
                                                                  emergencyUri,
                                                                );
                                                              }
                                                            },
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor:
                                                                  Colors.red,
                                                              foregroundColor:
                                                                  Colors.white,
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    vertical:
                                                                        14,
                                                                  ),
                                                              elevation: 0,
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      12,
                                                                    ),
                                                              ),
                                                            ),
                                                            child: Text(
                                                              'Call 197',
                                                              style: GoogleFonts.plusJakartaSans(
                                                                fontSize: 15,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.local_police,
                                          size: 16,
                                        ),
                                        label: Text(
                                          'Call Police',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: BorderSide(
                                            color: Colors.red.shade300,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            barrierDismissible: false,
                                            builder: (context) => Dialog(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  24,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    // Icon
                                                    Container(
                                                      width: 80,
                                                      height: 80,
                                                      decoration: BoxDecoration(
                                                        color: Colors.orange
                                                            .withOpacity(0.1),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(
                                                        Icons.report_problem,
                                                        color: Colors.orange,
                                                        size: 40,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 20),
                                                    // Title
                                                    Text(
                                                      'Report Patient Issue',
                                                      style:
                                                          GoogleFonts.plusJakartaSans(
                                                            fontSize: 20,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: const Color(
                                                              0xFF1D2939,
                                                            ),
                                                          ),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                    const SizedBox(height: 12),
                                                    // Description
                                                    Text(
                                                      'This will notify OmniCare support that the patient is unresponsive or there is a safety concern. Our team will investigate and take appropriate action to protect you.',
                                                      style:
                                                          GoogleFonts.plusJakartaSans(
                                                            fontSize: 14,
                                                            color: const Color(
                                                              0xFF667085,
                                                            ),
                                                            height: 1.5,
                                                          ),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                    const SizedBox(height: 24),
                                                    // Buttons
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: OutlinedButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  context,
                                                                ),
                                                            style: OutlinedButton.styleFrom(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    vertical:
                                                                        14,
                                                                  ),
                                                              side: const BorderSide(
                                                                color: Color(
                                                                  0xFFD0D5DD,
                                                                ),
                                                              ),
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      12,
                                                                    ),
                                                              ),
                                                            ),
                                                            child: Text(
                                                              'Cancel',
                                                              style: GoogleFonts.plusJakartaSans(
                                                                fontSize: 15,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color:
                                                                    const Color(
                                                                      0xFF667085,
                                                                    ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 12,
                                                        ),
                                                        Expanded(
                                                          child: ElevatedButton(
                                                            onPressed: () {
                                                              Navigator.pop(
                                                                context,
                                                              );
                                                              ScaffoldMessenger.of(
                                                                context,
                                                              ).showSnackBar(
                                                                SnackBar(
                                                                  content: Row(
                                                                    children: [
                                                                      const Icon(
                                                                        Icons
                                                                            .check_circle,
                                                                        color: Colors
                                                                            .white,
                                                                      ),
                                                                      const SizedBox(
                                                                        width:
                                                                            12,
                                                                      ),
                                                                      Expanded(
                                                                        child: Text(
                                                                          'Report submitted. OmniCare support has been notified.',
                                                                          style: GoogleFonts.plusJakartaSans(
                                                                            fontWeight:
                                                                                FontWeight.w600,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  backgroundColor:
                                                                      const Color(
                                                                        0xFF1FBF9A,
                                                                      ),
                                                                  behavior:
                                                                      SnackBarBehavior
                                                                          .floating,
                                                                  shape: RoundedRectangleBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          12,
                                                                        ),
                                                                  ),
                                                                  duration:
                                                                      const Duration(
                                                                        seconds:
                                                                            4,
                                                                      ),
                                                                ),
                                                              );
                                                            },
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor:
                                                                  Colors.orange,
                                                              foregroundColor:
                                                                  Colors.white,
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    vertical:
                                                                        14,
                                                                  ),
                                                              elevation: 0,
                                                              shape: RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      12,
                                                                    ),
                                                              ),
                                                            ),
                                                            child: Text(
                                                              'Submit Report',
                                                              style: GoogleFonts.plusJakartaSans(
                                                                fontSize: 15,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.report_problem,
                                          size: 16,
                                        ),
                                        label: Text(
                                          'Report Issue',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.orange,
                                          side: BorderSide(
                                            color: Colors.orange.shade300,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Action buttons
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _callPatient,
                                  icon: const Icon(Icons.phone, size: 20),
                                  label: Text(
                                    'Call',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1FBF9A),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    final p = widget.patient;
                                    if (p != null &&
                                        p.patientId.trim().isNotEmpty) {
                                      Navigator.pushReplacement(
                                        context,
                                        PageRouteBuilder(
                                          pageBuilder: (context, a1, a2) {
                                            return PatientMedicalPassportScreen(
                                              patientId: p.patientId,
                                              patientName: p.displayName,
                                            );
                                          },
                                          transitionsBuilder:
                                              (
                                                context,
                                                animation,
                                                secondaryAnimation,
                                                child,
                                              ) {
                                                final slide =
                                                    Tween<Offset>(
                                                      begin: const Offset(
                                                        0,
                                                        0.06,
                                                      ),
                                                      end: Offset.zero,
                                                    ).animate(
                                                      CurvedAnimation(
                                                        parent: animation,
                                                        curve:
                                                            Curves.easeOutCubic,
                                                      ),
                                                    );
                                                final fade = CurvedAnimation(
                                                  parent: animation,
                                                  curve: Curves.easeOut,
                                                );
                                                return FadeTransition(
                                                  opacity: fade,
                                                  child: SlideTransition(
                                                    position: slide,
                                                    child: child,
                                                  ),
                                                );
                                              },
                                          transitionDuration: const Duration(
                                            milliseconds: 260,
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const QRScannerScreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.check_circle,
                                    size: 20,
                                  ),
                                  label: Text(
                                    'Arrived',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
