import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'navigation_screen.dart';
import '../../core/api/consultations_api.dart';
import '../../core/api/api_error_utils.dart';
import '../../core/api/family_api.dart';
import '../../core/network/app_http_client.dart';
import '../../core/api/patients_api.dart';
import '../../core/models/consultation.dart';
import '../../core/models/patient_models.dart';

class RequestAcceptedScreen extends StatefulWidget {
  final PatientSummary? patient;
  final String consultationId;

  const RequestAcceptedScreen({
    super.key,
    this.patient,
    required this.consultationId,
  });

  @override
  State<RequestAcceptedScreen> createState() => _RequestAcceptedScreenState();
}

class _RequestAcceptedScreenState extends State<RequestAcceptedScreen> {
  bool _showWaiting = true;
  GoogleMapController? _mapController;

  late final TextEditingController _feeController;
  bool _isSavingFee = false;

  Consultation? _consultation;
  String? _familyRelationship;
  PatientPassport? _passport;

  // Patient location fallback (Tunis)
  static const LatLng _fallbackPatientLocation = LatLng(36.8065, 10.1815);

  // Doctor's starting position (simulated current location)
  static const LatLng _doctorLocation = LatLng(36.8265, 10.2015);

  String get _patientName {
    final alt = _consultation?.patientName;
    if (alt != null && alt.trim().isNotEmpty) return alt.trim();

    final passport = _passport;
    if (passport != null) {
      final familyMemberId = widget.patient?.familyMemberId;
      if (familyMemberId != null && familyMemberId.trim().isNotEmpty) {
        final name = passport.fullName.trim();
        if (name.isNotEmpty) return name;
      }

      final name = passport.displayName.trim();
      if (name.isNotEmpty) return name;
    }

    final name = widget.patient?.displayName;
    if (name != null && name.trim().isNotEmpty) return name.trim();
    return 'Patient';
  }

  String? get _patientId {
    final alt = _consultation?.patientId;
    if (alt != null && alt.trim().isNotEmpty) return alt.trim();
    final id = widget.patient?.patientId;
    if (id != null && id.trim().isNotEmpty) return id.trim();
    return null;
  }

  String get _phoneNumber {
    final phone = (_passport?.phoneNumber ?? '').trim();
    return phone.isEmpty ? '--' : phone;
  }

  int? get _ageYears {
    return _consultation?.patientAge ?? _passport?.age;
  }

  String get _ageText {
    final age = _ageYears;
    return age == null ? '--' : age.toString();
  }

  String get _genderText {
    final g = (_consultation?.patientGender ?? _passport?.gender ?? '').trim();
    return g.isEmpty ? '--' : g;
  }

  String get _heightText {
    final h = _consultation?.height ?? _passport?.height;
    if (h == null) return 'Not Recorded';
    return h.toString();
  }

  String get _weightText {
    final w = _consultation?.weight ?? _passport?.weight;
    if (w == null) return 'Not Recorded';
    return w.toString();
  }

  String get _bloodGroupText {
    final b = (_consultation?.bloodGroup ?? _passport?.bloodGroup ?? '').trim();
    return b.isEmpty ? '--' : b;
  }

  String get _medicalInfoText {
    final mi = _passport?.medicalInfo;
    if (mi == null) return '--';

    final cleaned = mi.entries
        .where((e) => e.key.toString().trim().isNotEmpty)
        .map((e) => '${e.key}: ${e.value}')
        .take(6)
        .join('\n');
    return cleaned.trim().isEmpty ? '--' : cleaned;
  }

  LatLng get _patientLocation {
    final c = _consultation;
    final lat = c?.latitude;
    final lng = c?.longitude;
    if (lat == null || lng == null) return _fallbackPatientLocation;
    return LatLng(lat, lng);
  }

  String get _address {
    final c = _consultation;
    final street = (c?.streetAddress ?? '').trim();
    final city = (c?.city ?? '').trim();
    final combined = [street, city].where((e) => e.isNotEmpty).join(', ');
    return combined.isEmpty ? 'Location unavailable' : combined;
  }

  @override
  void initState() {
    super.initState();
    final suggested = _suggestedFee();
    _feeController = TextEditingController(text: suggested.toStringAsFixed(0));
    _loadConsultation();
    _loadFamilyRelationship();
    _loadPassport();
  }

  static String _capitalize(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return v;
    return v[0].toUpperCase() + v.substring(1);
  }

  String get _relationshipText {
    final rel =
        (_consultation?.relationship ??
                _passport?.relationship ??
                _familyRelationship ??
                '')
            .trim();
    if (rel.isEmpty) return '---';
    if (rel.toUpperCase() == 'SELF') return 'Patient';
    return "Main patient's ${_capitalize(rel)}";
  }

  Future<void> _loadFamilyRelationship() async {
    final familyMemberId = widget.patient?.familyMemberId;
    if (familyMemberId == null || familyMemberId.trim().isEmpty) return;
    try {
      final list = await FamilyApi(
        httpClient: context.read<AppHttpClient>(),
      ).getFamilyMembers();
      if (!mounted) return;
      final match = list.where((m) => m.id == familyMemberId.trim()).toList();
      if (match.isEmpty) return;
      final rel = (match.first.relationship).trim();
      if (rel.isEmpty) return;
      setState(() {
        _familyRelationship = rel;
      });
    } catch (_) {
      // Non-fatal; relationship will remain unknown.
    }
  }

  Future<void> _loadConsultation() async {
    final id = widget.consultationId.trim();
    if (id.isEmpty) {
      throw StateError('consultationId is required');
    }
    try {
      final c = await ConsultationsApi().getConsultation(consultationId: id);
      if (!mounted) return;
      setState(() {
        _consultation = c;
      });
      await _loadPassport();
    } catch (_) {
      // Non-fatal; screen can still render with fallbacks.
    }
  }

  Future<void> _loadPassport() async {
    final pid = _patientId;
    if (pid == null || pid.trim().isEmpty) return;

    try {
      final passport = await PatientsApi().getPatientPassportTyped(pid);
      if (!mounted) return;
      setState(() {
        _passport = passport;
      });
    } catch (_) {
      // Non-fatal; UI will keep fallbacks.
    }
  }

  @override
  void dispose() {
    _feeController.dispose();
    super.dispose();
  }

  double _suggestedFee() {
    // Temporary heuristic until provider pricing is wired.
    // Use a stable default for now.
    return 250;
  }

  Future<void> _saveFee() async {
    final consultationId = widget.consultationId.trim();
    final fee = num.tryParse(_feeController.text);
    if (fee == null || fee <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter a valid fee',
            style: GoogleFonts.plusJakartaSans(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (consultationId.isEmpty) {
      throw StateError('consultationId is required');
    }

    setState(() {
      _isSavingFee = true;
    });
    try {
      await ConsultationsApi().patchConsultation(
        consultationId: consultationId,
        fee: fee,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fee updated', style: GoogleFonts.plusJakartaSans()),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update fee: ${apiErrorMessage(e)}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingFee = false;
        });
      }
    }
  }

  Future<void> _callPatient() async {
    final phone = _phoneNumber;
    if (phone == '--') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Patient phone number is not available',
            style: GoogleFonts.plusJakartaSans(),
          ),
        ),
      );
      return;
    }

    final uri = Uri.parse('tel:$phone');
    if (!await canLaunchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot start phone call on this device',
            style: GoogleFonts.plusJakartaSans(),
          ),
        ),
      );
      return;
    }

    await launchUrl(uri);
  }

  void _openNavigation() {
    // Open in-app navigation screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NavigationScreen(
          patient: widget.patient,
          consultationId: widget.consultationId,
        ),
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

            // Fee Card (provider sets price)
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
                    'Set your fee',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1D2939),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _feeController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: 'Fee (DT)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(
                              Icons.payments_outlined,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: _isSavingFee
                            ? null
                            : () {
                                _feeController.text = _suggestedFee()
                                    .toStringAsFixed(0);
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1FBF9A),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Auto',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSavingFee ? null : _saveFee,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1FBF9A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSavingFee
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              'Save fee',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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

                  _buildInfoRow(Icons.person, 'Name', _patientName),
                  if (_familyRelationship != null)
                    _buildInfoRow(
                      Icons.family_restroom,
                      'Relationship',
                      _relationshipText,
                    ),
                  _buildInfoRow(Icons.cake, 'Age', _ageText),
                  _buildInfoRow(Icons.wc, 'Gender', _genderText),
                  _buildInfoRow(Icons.phone, 'Phone', _phoneNumber),
                  _buildInfoRow(Icons.height, 'Height', _heightText),
                  _buildInfoRow(
                    Icons.monitor_weight_outlined,
                    'Weight',
                    _weightText,
                  ),
                  _buildInfoRow(
                    Icons.bloodtype,
                    'Blood Group',
                    _bloodGroupText,
                  ),
                  _buildInfoRow(
                    Icons.medical_information_outlined,
                    'Medical Info',
                    _medicalInfoText,
                  ),
                  _buildInfoRow(Icons.location_on, 'Address', _address),
                  _buildInfoRow(Icons.social_distance, 'Distance', '--'),
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
              child: kIsWeb
                  ? Center(
                      child: Text(
                        'Map preview is not available on web',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF667085),
                        ),
                      ),
                    )
                  : GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _patientLocation,
                        zoom: 13.0,
                      ),
                      markers: {
                        Marker(
                          markerId: const MarkerId('patient'),
                          position: _patientLocation,
                          infoWindow: InfoWindow(
                            title: _patientName,
                            snippet: _address,
                          ),
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueRed,
                          ),
                        ),
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
                          points: [_doctorLocation, _patientLocation],
                          color: const Color(0xFF1FBF9A),
                          width: 4,
                        ),
                      },
                      onMapCreated: (GoogleMapController controller) {
                        _mapController = controller;
                      },
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                    ),
            ),
            const SizedBox(height: 16),

            // Map Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF8FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF0F6F73).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Color(0xFF0F6F73),
                    size: 20,
                  ),
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
