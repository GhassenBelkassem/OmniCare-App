import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'request_accepted_screen.dart';
import '../../core/api/consultations_api.dart';
import '../../core/api/api_error_utils.dart';
import '../../core/api/family_api.dart';
import '../../core/api/patients_api.dart';
import '../../core/api/provider_me_api.dart';
import '../../core/models/patient_models.dart';
import '../../providers/user_provider.dart';
import '../../core/models/consultation.dart' as api;
import 'consultation_detail_screen.dart';
import 'patient_medical_passport_screen.dart';
import 'provider_reservations_screen.dart';

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

// Patient list screen (opens passport)
class PatientHistoryScreen extends StatelessWidget {
  const PatientHistoryScreen({super.key});

  Widget _buildPatientCard({required String name}) {
    final initials = name
        .split(RegExp(r'\s+'))
        .where((p) => p.trim().isNotEmpty)
        .take(2)
        .map((p) => p.trim()[0].toUpperCase())
        .join();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF1FBF9A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                initials,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1FBF9A),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1D2939),
              ),
            ),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFF98A2B3)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final api = PatientsApi();
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Patients',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1D2939),
          ),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<List<PatientSummary>>(
          future: api.getPatientsForProfessional(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Failed to load patients: ${snapshot.error}',
                  style: GoogleFonts.plusJakartaSans(),
                  textAlign: TextAlign.center,
                ),
              );
            }

            final patients = snapshot.data ?? const <PatientSummary>[];
            if (patients.isEmpty) {
              return Center(
                child: Text(
                  'No patients found',
                  style: GoogleFonts.plusJakartaSans(),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: patients.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final p = patients[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PatientMedicalPassportScreen(
                          patientId: p.patientId,
                          patientName: p.displayName,
                        ),
                      ),
                    );
                  },
                  child: _buildPatientCard(name: p.displayName),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const CommandCenterScreen(),
    const RevenueHubScreen(),
    const DoctorHistoryScreen(),
    const DoctorProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: _buildNavItem(
                    icon: Icons.home_rounded,
                    label: 'Command',
                    index: 0,
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    icon: Icons.trending_up_rounded,
                    label: 'Revenue',
                    index: 1,
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    icon: Icons.people_rounded,
                    label: 'History',
                    index: 2,
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    icon: Icons.person_rounded,
                    label: 'Profile',
                    index: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isActive = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF1FBF9A).withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive
                  ? const Color(0xFF1FBF9A)
                  : const Color(0xFF667085),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive
                    ? const Color(0xFF1FBF9A)
                    : const Color(0xFF667085),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Command Center Screen
class CommandCenterScreen extends StatefulWidget {
  const CommandCenterScreen({super.key});

  @override
  State<CommandCenterScreen> createState() => _CommandCenterScreenState();
}

class _CommandCenterScreenState extends State<CommandCenterScreen> {
  bool _isLive = false;
  bool _showMapModal = false;
  bool _hasIncomingRequest = false;
  int _countdown = 26;
  Timer? _timer;
  Timer? _pollTimer;

  Position? _doctorPosition;
  bool _locationServiceDisabled = false;
  bool _locationPermissionDenied = false;

  late final TextEditingController _feeController;
  bool _isSavingFee = false;

  String? _familyRelationship;

  PatientSummary? _requestPatient;
  api.Consultation? _incomingConsultation;

  PatientPassport? _requestPassport;
  bool _isLoadingPassport = false;
  String? _passportError;

  String? get _requestPatientId {
    final id = (_incomingConsultation?.patientId ?? _requestPatient?.patientId)
        ?.toString()
        .trim();
    if (id == null || id.isEmpty) return null;
    return id;
  }

  String _displayOrDash(String? v) {
    final t = (v ?? '').trim();
    return t.isEmpty ? '--' : t;
  }

  String _vitalText(num? v, {String? unit}) {
    if (v == null) return 'Not Recorded';
    final u = (unit ?? '').trim();
    if (u.isEmpty) return v.toString();
    return '${v.toString()} $u';
  }

  Future<void> _showPatientLocationSheet() async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Color(0xFF1FBF9A)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Patient Location',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1D2939),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _requestAddress,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: const Color(0xFF667085),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: Color(0xFF667085)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 380,
                    child: kIsWeb
                        ? Center(
                            child: Text(
                              'Map preview is not available on web',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: const Color(0xFF667085),
                              ),
                            ),
                          )
                        : GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: _requestLocation,
                              zoom: 15.0,
                            ),
                            markers: {
                              Marker(
                                markerId: const MarkerId('patient_location'),
                                position: _requestLocation,
                                infoWindow: InfoWindow(
                                  title: requestPatientName,
                                  snippet: _requestAddress,
                                ),
                                icon: BitmapDescriptor.defaultMarkerWithHue(
                                  BitmapDescriptor.hueRed,
                                ),
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
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1FBF9A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Close',
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
        );
      },
    );
  }

  String get requestPatientName => _requestPatient?.displayName ?? 'Patient';

  String get _incomingPatientName {
    final c = _incomingConsultation;
    final name = (c?.patientName ?? '').trim();
    if (name.isNotEmpty) return name;
    return _requestPatient?.displayName ?? 'Unknown Patient';
  }

  String? get _incomingRelationshipText {
    final c = _incomingConsultation;
    final rel = (c?.relationship ?? '').trim();
    if (rel.isEmpty) {
      return _relationshipText;
    }
    return "Patient's ${_capitalize(rel)}";
  }

  @override
  void initState() {
    super.initState();
    _feeController = TextEditingController(
      text: _suggestedFee().toStringAsFixed(0),
    );
  }

  Future<void> _loadRequestPassportIfNeeded() async {
    final patientId = _requestPatientId;
    if (patientId == null) return;

    setState(() {
      _isLoadingPassport = true;
      _passportError = null;
    });

    try {
      final passport = await PatientsApi().getPatientPassportTyped(patientId);
      if (!mounted) return;
      setState(() {
        _requestPassport = passport;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _passportError = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingPassport = false;
      });
    }
  }

  double _suggestedFee() {
    return 250;
  }

  static String _capitalize(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return v;
    return v[0].toUpperCase() + v.substring(1);
  }

  String? get _relationshipText {
    final rel = (_familyRelationship ?? '').trim();
    if (rel.isEmpty) return null;
    return "Patient's ${_capitalize(rel)}";
  }

  Future<void> _loadFamilyRelationshipIfNeeded() async {
    final familyMemberId = _requestPatient?.familyMemberId;
    if (familyMemberId == null || familyMemberId.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _familyRelationship = null;
      });
      return;
    }

    try {
      final list = await FamilyApi().getFamilyMembers();
      if (!mounted) return;
      final match = list.where((m) => m.id == familyMemberId.trim()).toList();
      if (match.isEmpty) return;
      final rel = (match.first.relationship).trim();
      if (rel.isEmpty) return;
      setState(() {
        _familyRelationship = rel;
      });
    } catch (_) {
      // Non-fatal.
    }
  }

  Future<void> _saveFeeIfPossible() async {
    final consultationId = _incomingConsultation?.id;
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

    if (consultationId == null || consultationId.trim().isEmpty) {
      return;
    }

    setState(() {
      _isSavingFee = true;
    });
    try {
      await ConsultationsApi().patchConsultation(
        consultationId: consultationId.trim(),
        fee: fee,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fee updated', style: GoogleFonts.plusJakartaSans()),
        ),
      );
      setState(() {
        _incomingConsultation = api.Consultation(
          id: _incomingConsultation?.id,
          doctorId: _incomingConsultation?.doctorId,
          doctorName: _incomingConsultation?.doctorName,
          doctorSpecialty: _incomingConsultation?.doctorSpecialty,
          providerId: _incomingConsultation?.providerId,
          providerType: _incomingConsultation?.providerType,
          patientId: _incomingConsultation?.patientId,
          patientName: _incomingConsultation?.patientName,
          symptoms: _incomingConsultation?.symptoms,
          diagnosis: _incomingConsultation?.diagnosis,
          treatment: _incomingConsultation?.treatment,
          status: _incomingConsultation?.status,
          painLevel: _incomingConsultation?.painLevel,
          affectedAreas: _incomingConsultation?.affectedAreas,
          streetAddress: _incomingConsultation?.streetAddress,
          apartmentSuite: _incomingConsultation?.apartmentSuite,
          city: _incomingConsultation?.city,
          latitude: _incomingConsultation?.latitude,
          longitude: _incomingConsultation?.longitude,
          fee: fee.toDouble(),
          netAmount: _incomingConsultation?.netAmount,
          omnicareFee: _incomingConsultation?.omnicareFee,
          timestamp: _incomingConsultation?.timestamp,
          allergyWarning: _incomingConsultation?.allergyWarning,
        );
      });
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

  Future<void> _acceptRequest() async {
    try {
      await _saveFeeIfPossible();
      if (!mounted) return;

      final consultationId = _incomingConsultation?.id;
      if (consultationId == null || consultationId.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Missing consultation ID. Please go live again.',
              style: GoogleFonts.plusJakartaSans(),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      await ConsultationsApi().patchConsultation(
        consultationId: consultationId.trim(),
        status: 'ACCEPTED',
      );
      if (!mounted) return;

      setState(() {
        _hasIncomingRequest = false;
        _incomingConsultation = null;
        _countdown = 0;
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RequestAcceptedScreen(
            patient: _requestPatient,
            consultationId: consultationId.trim(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to accept request: ${apiErrorMessage(e)}',
            style: GoogleFonts.plusJakartaSans(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _simulateIncomingRequest() async {
    _startPollingForIncomingRequests();
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isLive) {
        _timer?.cancel();
        return;
      }

      if (_countdown <= 1) {
        setState(() {
          _countdown = 0;
          _hasIncomingRequest = false;
          _incomingConsultation = null;
        });
        _timer?.cancel();
        return;
      }

      setState(() {
        _countdown -= 1;
      });
    });
  }

  void _clearIncomingRequestContext() {
    _requestPatient = null;
    _requestPassport = null;
    _familyRelationship = null;
    _passportError = null;
    _isLoadingPassport = false;
  }

  Future<void> _rejectRequest() async {
    final consultationId = (_incomingConsultation?.id ?? '').trim();
    if (consultationId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _hasIncomingRequest = false;
        _incomingConsultation = null;
        _clearIncomingRequestContext();
        _countdown = 0;
      });
      _timer?.cancel();
      return;
    }

    try {
      await ConsultationsApi().patchConsultation(
        consultationId: consultationId,
        status: 'CANCELLED',
      );
    } catch (_) {
      // Non-fatal: still clear local UI state.
    }

    if (!mounted) return;
    setState(() {
      _hasIncomingRequest = false;
      _incomingConsultation = null;
      _clearIncomingRequestContext();
      _countdown = 0;
    });
    _timer?.cancel();

    ProviderMeApi.invalidateConsultationsCache();

    // Immediately check if there's another pending request.
    await _fetchIncomingRequestOnce();
  }

  Future<void> _loadRequestPatient({String? patientId}) async {
    try {
      final list = await PatientsApi().getPatientsForProfessional();
      if (!mounted) return;
      if (list.isEmpty) return;

      if (patientId != null && patientId.trim().isNotEmpty) {
        final match = list.where((p) => p.patientId == patientId).toList();
        if (match.isNotEmpty) {
          setState(() {
            _requestPatient = match.first;
          });
          await _loadFamilyRelationshipIfNeeded();
          return;
        }

        // If we have a consultation patientId but couldn't resolve it in the
        // professional patient list, do NOT randomly pick a different patient.
        // That leads to conflicting UI (wrong name/passport fetched).
        setState(() {
          _requestPatient = null;
          _familyRelationship = null;
        });
        return;
      }

      final randomPick = list[Random().nextInt(list.length)];
      setState(() {
        _requestPatient = randomPick;
      });
      await _loadFamilyRelationshipIfNeeded();
    } catch (_) {
      // Leave request patient null; UI will fallback gracefully.
    }
  }

  GoogleMapController? _mapController;

  // Patient location in Tunis (Avenue Habib Bourguiba)
  static const LatLng _patientLocation = LatLng(36.8065, 10.1815);

  LatLng get _requestLocation {
    final c = _incomingConsultation;
    final lat = c?.latitude;
    final lng = c?.longitude;
    if (lat == null || lng == null) return _patientLocation;
    return LatLng(lat, lng);
  }

  String get _requestAddress {
    final c = _incomingConsultation;
    final street = (c?.streetAddress ?? '').trim();
    final city = (c?.city ?? '').trim();
    final combined = [street, city].where((e) => e.isNotEmpty).join(', ');
    return combined.isEmpty ? 'Location unavailable' : combined;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pollTimer?.cancel();
    _feeController.dispose();
    super.dispose();
  }

  void _startPollingForIncomingRequests() {
    _pollTimer?.cancel();

    if (!_isLive) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_isLive) {
        _pollTimer?.cancel();
        return;
      }
      if (_hasIncomingRequest) return;
      _fetchIncomingRequestOnce();
    });

    _fetchIncomingRequestOnce();
  }

  Future<void> _fetchIncomingRequestOnce() async {
    if (!mounted || !_isLive) return;

    try {
      final pos = _doctorPosition;
      if (pos == null) {
        await _ensureDoctorLocation();
      }
      final pos2 = _doctorPosition;
      if (pos2 == null) {
        if (!mounted || !_isLive) return;
        setState(() {
          _hasIncomingRequest = false;
          _incomingConsultation = null;
        });
        return;
      }

      final pending = await ProviderMeApi().listMyConsultations(
        status: 'PENDING',
        lat: pos2.latitude,
        lng: pos2.longitude,
      );
      print(
        '[CommandCenter] Found ${pending.length} PENDING consultations (live=$_isLive)',
      );

      if (!mounted || !_isLive) return;
      if (pending.isEmpty) {
        if (_hasIncomingRequest) {
          setState(() {
            _hasIncomingRequest = false;
            _incomingConsultation = null;
            _clearIncomingRequestContext();
          });
        }
        return;
      }

      // New incoming request: clear cached patient/passport so we don't show stale data while loading.
      setState(() {
        _clearIncomingRequestContext();
      });

      setState(() {
        _incomingConsultation = pending.first;
      });

      final existingFee = num.tryParse(
        (_incomingConsultation?.fee ?? '').toString(),
      );
      _feeController.text = (existingFee == null || existingFee <= 0)
          ? _suggestedFee().toStringAsFixed(0)
          : existingFee.toStringAsFixed(0);
    } catch (e) {
      print('[CommandCenter] Poll failed: $e');
      if (!mounted || !_isLive) return;
      setState(() {
        _hasIncomingRequest = false;
        _incomingConsultation = null;
        _clearIncomingRequestContext();
      });
      return;
    }

    await _loadRequestPatient(patientId: _incomingConsultation?.patientId);
    await _loadRequestPassportIfNeeded();
    if (!mounted || !_isLive) return;

    setState(() {
      _hasIncomingRequest = true;
      _countdown = 60;
    });
    _startCountdown();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF4F5F7),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: Image.asset(
              'assets/images/logo.png',
              height: 40,
              errorBuilder: (context, error, stackTrace) {
                return Text(
                  'OmniCare',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1FBF9A),
                  ),
                );
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.language, color: Color(0xFF667085)),
                onPressed: () {
                  // Language selection
                },
              ),
              IconButton(
                icon: const Icon(Icons.support_agent, color: Color(0xFF667085)),
                onPressed: () {
                  // Contact support
                },
              ),
              IconButton(
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: Color(0xFF667085),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProviderReservationsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Doctor Info Card
                  _buildDoctorInfoCard(),
                  const SizedBox(height: 20),

                  // Live Status Toggle
                  _buildLiveStatusCard(),
                  const SizedBox(height: 20),

                  // Incoming Request or Idle State
                  _buildIncomingRequestCard(),
                  const SizedBox(height: 20),

                  // Quick Stats
                  _buildQuickStats(),
                ],
              ),
            ),
          ),
        ),

        // Map Modal Overlay
        if (_showMapModal) _buildMapModal(),
      ],
    );
  }

  Widget _buildLiveStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isLive ? 'Live' : 'Offline',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1D2939),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isLive
                      ? 'You are receiving requests'
                      : 'Go live to receive requests',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: const Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isLive,
            activeColor: const Color(0xFF1FBF9A),
            onChanged: (value) async {
              setState(() {
                _isLive = value;
                _hasIncomingRequest = false;
                _incomingConsultation = null;
                _countdown = 0;
                if (!value) {
                  _doctorPosition = null;
                  _locationServiceDisabled = false;
                  _locationPermissionDenied = false;
                }
              });

              _timer?.cancel();
              _pollTimer?.cancel();
              if (!value) return;

              await _ensureDoctorLocation();
              if (!mounted) return;
              if (_doctorPosition == null) return;

              _startPollingForIncomingRequests();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _ensureDoctorLocation() async {
    setState(() {
      _locationServiceDisabled = false;
      _locationPermissionDenied = false;
    });

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      setState(() {
        _doctorPosition = null;
        _locationServiceDisabled = true;
      });
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      setState(() {
        _doctorPosition = null;
        _locationPermissionDenied = true;
      });
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    if (!mounted) return;
    setState(() {
      _doctorPosition = pos;
    });
  }

  Widget _buildDoctorInfoCard() {
    final doctorName = context.watch<UserProvider>().user?.displayName;
    final providerType = context.watch<UserProvider>().user?.providerType;
    final resolvedName = (doctorName != null && doctorName.trim().isNotEmpty)
        ? doctorName.trim()
        : 'Doctor';
    final initials = resolvedName
        .split(RegExp(r'\s+'))
        .where((p) => p.trim().isNotEmpty)
        .take(2)
        .map((p) => p.trim()[0].toUpperCase())
        .join();

    final resolvedType =
        (providerType != null && providerType.trim().isNotEmpty)
        ? providerType.trim()
        : 'Provider';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1FBF9A), Color(0xFF0F6F73)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1FBF9A).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                initials.isEmpty ? 'P' : initials,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resolvedName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  resolvedType,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingRequestCard() {
    if (!_isLive || !_hasIncomingRequest) {
      if (_isLive && (_locationServiceDisabled || _locationPermissionDenied)) {
        return _buildLocationRequiredCard();
      }
      return _buildIdleStateCard();
    }

    final c = _incomingConsultation;
    final rawSymptoms = (c?.symptoms ?? '').trim();
    final symptoms = rawSymptoms.isEmpty
        ? 'Debug: No symptoms returned (pending consultation may be missing symptoms)'
        : rawSymptoms;

    final passport = _requestPassport;
    final ageText = (c?.patientAge != null)
        ? c!.patientAge.toString()
        : ((passport?.age != null) ? passport!.age.toString() : '--');
    final genderText = _displayOrDash(c?.patientGender ?? passport?.gender);
    final heightText = _vitalText(c?.height ?? passport?.height, unit: 'cm');
    final weightText = _vitalText(c?.weight ?? passport?.weight, unit: 'kg');
    final meds =
        passport?.currentMedicines ?? const <PatientMedicationSummary>[];
    final chronic = passport?.chronicDiseases ?? const <String>[];
    final allergies = passport?.allergies ?? const <String>[];
    final past =
        passport?.pastConsultations ?? const <PastConsultationSummary>[];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'URGENT REQUEST',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$_countdown',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _incomingPatientName,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1D2939),
            ),
          ),
          if (_incomingRelationshipText != null) ...[
            const SizedBox(height: 4),
            Text(
              _incomingRelationshipText!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: const Color(0xFF667085),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: Color(0xFF667085),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _requestAddress,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: const Color(0xFF667085),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFECDCA)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Symptoms',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  symptoms,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1D2939),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (_) {
                  return SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Request details',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1D2939),
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_isLoadingPassport)
                              Text(
                                'Loading patient details...',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: const Color(0xFF667085),
                                ),
                              ),
                            if (!_isLoadingPassport && _passportError != null)
                              Text(
                                _passportError!,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: const Color(0xFFDC2626),
                                ),
                              ),
                            _buildDetailRow(
                              icon: Icons.person,
                              label: 'Patient',
                              value: _incomingPatientName,
                            ),
                            if (_incomingRelationshipText != null)
                              _buildDetailRow(
                                icon: Icons.family_restroom,
                                label: 'Relationship',
                                value: _incomingRelationshipText!,
                              ),
                            _buildDetailRow(
                              icon: Icons.location_on_outlined,
                              label: 'Address',
                              value: _requestAddress,
                              isClickable: !kIsWeb,
                            ),
                            if (!kIsWeb)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _showPatientLocationSheet();
                                  },
                                  icon: const Icon(
                                    Icons.map_outlined,
                                    size: 18,
                                  ),
                                  label: Text(
                                    'Open map',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF1FBF9A),
                                    side: const BorderSide(
                                      color: Color(0xFFE5E7EB),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),
                            _buildDetailRow(
                              icon: Icons.medical_information_outlined,
                              label: 'Symptoms',
                              value: symptoms,
                            ),
                            _buildDetailRow(
                              icon: Icons.confirmation_number_outlined,
                              label: 'Consultation ID',
                              value: (_incomingConsultation?.id ?? '--')
                                  .toString(),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Vitals',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1D2939),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _buildDetailRow(
                                    icon: Icons.cake,
                                    label: 'Age',
                                    value: ageText,
                                  ),
                                  _buildDetailRow(
                                    icon: Icons.wc,
                                    label: 'Gender',
                                    value: genderText,
                                  ),
                                  _buildDetailRow(
                                    icon: Icons.height,
                                    label: 'Height',
                                    value: heightText,
                                  ),
                                  _buildDetailRow(
                                    icon: Icons.monitor_weight_outlined,
                                    label: 'Weight',
                                    value: weightText,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Current medications',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1D2939),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  if (meds.isEmpty)
                                    Text(
                                      'No current medications reported',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontStyle: FontStyle.italic,
                                        color: const Color(0xFF667085),
                                      ),
                                    )
                                  else
                                    ...meds.take(6).map((m) {
                                      final name = _displayOrDash(m.name);
                                      final dose = _displayOrDash(m.dosage);
                                      final freq = _displayOrDash(m.frequency);
                                      final text =
                                          ([name, dose, freq]
                                                  .where((e) => e != '--')
                                                  .toList())
                                              .join(' • ');
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Icon(
                                              Icons.medication_outlined,
                                              size: 16,
                                              color: Color(0xFF667085),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                text.isEmpty ? name : text,
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                      fontSize: 13,
                                                      color: const Color(
                                                        0xFF1D2939,
                                                      ),
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                ],
                              ),
                            ),
                            if (chronic.isNotEmpty || allergies.isNotEmpty)
                              const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Chronic illnesses',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1D2939),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (chronic.isEmpty)
                                    Text(
                                      'No chronic illnesses reported',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontStyle: FontStyle.italic,
                                        color: const Color(0xFF667085),
                                      ),
                                    )
                                  else
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: chronic.take(10).map((e) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF3F2),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFFFECDCA),
                                            ),
                                          ),
                                          child: Text(
                                            e,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              color: const Color(0xFF7A271A),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Allergies',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1D2939),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (allergies.isEmpty)
                                    Text(
                                      'No known allergies reported',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontStyle: FontStyle.italic,
                                        color: const Color(0xFF667085),
                                      ),
                                    )
                                  else
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: allergies.take(10).map((e) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFFAEB),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFFFEC84B),
                                            ),
                                          ),
                                          child: Text(
                                            e,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              color: const Color(0xFF7A2E0E),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Theme(
                              data: Theme.of(
                                context,
                              ).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                childrenPadding: EdgeInsets.zero,
                                title: Text(
                                  'Past consultations',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1D2939),
                                  ),
                                ),
                                children: [
                                  const SizedBox(height: 8),
                                  if (past.isEmpty)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'No past consultations recorded',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 13,
                                          fontStyle: FontStyle.italic,
                                          color: const Color(0xFF667085),
                                        ),
                                      ),
                                    )
                                  else
                                    ...past.take(6).map((pc) {
                                      final id = _displayOrDash(pc.id);
                                      final status = _displayOrDash(pc.status);
                                      final time = _displayOrDash(pc.timestamp);
                                      final diag = _displayOrDash(pc.diagnosis);
                                      return Container(
                                        width: double.infinity,
                                        margin: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFE5E7EB),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '#$id',
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: const Color(
                                                      0xFF1D2939,
                                                    ),
                                                  ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              [status, time]
                                                  .where((e) => e != '--')
                                                  .join(' • '),
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    fontSize: 12,
                                                    color: const Color(
                                                      0xFF667085,
                                                    ),
                                                  ),
                                            ),
                                            if (diag != '--') ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                diag,
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                      fontSize: 12,
                                                      color: const Color(
                                                        0xFF1D2939,
                                                      ),
                                                    ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    }),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
            icon: const Icon(Icons.info_outline, size: 18),
            label: Text(
              'Details',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1FBF9A),
              side: const BorderSide(color: Color(0xFFE5E7EB)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set your fee',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 8),
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
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _rejectRequest,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'REJECT',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSavingFee ? null : _acceptRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1FBF9A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'ACCEPT',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isClickable = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF667085), size: 18),
          const SizedBox(width: 8),
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
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isClickable
                        ? const Color(0xFF1FBF9A)
                        : const Color(0xFF1D2939),
                    decoration: isClickable ? TextDecoration.underline : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdleStateCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            _isLive ? Icons.radar : Icons.power_settings_new,
            size: 64,
            color: _isLive ? const Color(0xFF1FBF9A) : const Color(0xFF667085),
          ),
          const SizedBox(height: 16),
          Text(
            _isLive ? 'No Tasks Found' : 'Go Live to Receive Requests',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1D2939),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isLive
                ? 'No pending consultations right now.'
                : 'Toggle the switch above to start accepting urgent care requests',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: const Color(0xFF667085),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRequiredCard() {
    final title = _locationServiceDisabled
        ? 'Location Services Disabled'
        : 'Location Required';
    final body = _locationServiceDisabled
        ? 'Enable location services to receive nearby requests.'
        : 'Allow location permission to receive nearby requests.';

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.location_off, size: 64, color: Color(0xFFDC2626)),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1D2939),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: const Color(0xFF667085),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                await _ensureDoctorLocation();
                if (!mounted || !_isLive) return;
                if (_doctorPosition != null) {
                  _startPollingForIncomingRequests();
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1FBF9A),
                side: const BorderSide(color: Color(0xFF1FBF9A)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Retry',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapModal() {
    return Material(
      color: Colors.black.withOpacity(0.5),
      child: GestureDetector(
        onTap: () {
          setState(() => _showMapModal = false);
        },
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Map Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1FBF9A),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Patient Location',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                _requestAddress,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () {
                            setState(() => _showMapModal = false);
                          },
                        ),
                      ],
                    ),
                  ),

                  // Google Map View
                  Container(
                    height: 400,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFD0D5DD)),
                    ),
                    child: Stack(
                      children: [
                        if (kIsWeb)
                          Center(
                            child: Text(
                              'Map preview is not available on web',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF667085),
                              ),
                            ),
                          )
                        else
                          GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: _requestLocation,
                              zoom: 15.0,
                            ),
                            markers: {
                              Marker(
                                markerId: const MarkerId('patient_location'),
                                position: _requestLocation,
                                infoWindow: InfoWindow(
                                  title: requestPatientName,
                                  snippet: _requestAddress,
                                ),
                                icon: BitmapDescriptor.defaultMarkerWithHue(
                                  BitmapDescriptor.hueRed,
                                ),
                              ),
                            },
                            onMapCreated: (GoogleMapController controller) {
                              _mapController = controller;
                            },
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: false,
                            mapToolbarEnabled: false,
                          ),

                        // Map Controls
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: Column(
                            children: [
                              _buildMapControlButton(
                                Icons.add,
                                'Zoom In',
                                onPressed: () async {
                                  final controller = _mapController;
                                  if (controller != null) {
                                    final zoom = await controller
                                        .getZoomLevel();
                                    controller.animateCamera(
                                      CameraUpdate.zoomTo(zoom + 1),
                                    );
                                  }
                                },
                              ),
                              const SizedBox(height: 8),
                              _buildMapControlButton(
                                Icons.remove,
                                'Zoom Out',
                                onPressed: () async {
                                  final controller = _mapController;
                                  if (controller != null) {
                                    final zoom = await controller
                                        .getZoomLevel();
                                    controller.animateCamera(
                                      CameraUpdate.zoomTo(zoom - 1),
                                    );
                                  }
                                },
                              ),
                              const SizedBox(height: 8),
                              _buildMapControlButton(
                                Icons.my_location,
                                'Center',
                                onPressed: () {
                                  _mapController?.animateCamera(
                                    CameraUpdate.newLatLng(_requestLocation),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        // Distance Indicator
                        Positioned(
                          top: 16,
                          left: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
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
                                const Icon(
                                  Icons.social_distance,
                                  color: Color(0xFF1FBF9A),
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '--',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1D2939),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Close Button
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() => _showMapModal = false);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1FBF9A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Close',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapControlButton(
    IconData icon,
    String tooltip, {
    VoidCallback? onPressed,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: const Color(0xFF1FBF9A)),
        onPressed: onPressed ?? () {},
        tooltip: tooltip,
      ),
    );
  }

  Widget _buildQuickStats() {
    final today = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Stats',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1D2939),
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<api.Consultation>>(
          future: ProviderMeApi().listMyConsultations(status: 'COMPLETED'),
          builder: (context, snapshot) {
            final items = snapshot.data ?? const <api.Consultation>[];

            int completedToday = 0;
            double earningsToday = 0;

            for (final c in items) {
              final ts = (c.timestamp ?? '').trim();
              final when = ts.isEmpty ? null : DateTime.tryParse(ts);
              if (when == null) continue;
              if (when.year == today.year &&
                  when.month == today.month &&
                  when.day == today.day) {
                completedToday++;
                final net = double.tryParse((c.netAmount ?? '').toString());
                if (net != null) {
                  earningsToday += net;
                }
              }
            }

            return Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.check_circle_outline,
                    label: 'Completed',
                    value: completedToday.toString(),
                    color: const Color(0xFF1FBF9A),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.attach_money,
                    label: 'Earnings',
                    value: '${earningsToday.toStringAsFixed(0)} TND',
                    color: const Color(0xFF0F6F73),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1D2939),
            ),
          ),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: const Color(0xFF667085),
            ),
          ),
        ],
      ),
    );
  }
}

// Revenue Hub Screen
class RevenueHubScreen extends StatelessWidget {
  const RevenueHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final doctorName = context.watch<UserProvider>().user?.displayName;
    final providerType = context.watch<UserProvider>().user?.providerType;
    final resolvedName = (doctorName != null && doctorName.trim().isNotEmpty)
        ? doctorName.trim()
        : 'Doctor';
    final resolvedType =
        (providerType != null && providerType.trim().isNotEmpty)
        ? providerType.trim()
        : 'Professional';
    final initials = resolvedName
        .split(RegExp(r'\s+'))
        .where((p) => p.trim().isNotEmpty)
        .take(2)
        .map((p) => p.trim()[0].toUpperCase())
        .join();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Revenue Hub',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1D2939),
          ),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<List<api.Consultation>>(
          future: ProviderMeApi().listMyConsultations(status: 'COMPLETED'),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Failed to load revenue: ${snapshot.error}',
                  style: GoogleFonts.plusJakartaSans(),
                  textAlign: TextAlign.center,
                ),
              );
            }

            final items = snapshot.data ?? const <api.Consultation>[];
            final today = DateTime.now();

            double todayNet = 0;
            for (final c in items) {
              final ts = (c.timestamp ?? '').trim();
              final when = ts.isEmpty ? null : DateTime.tryParse(ts);
              if (when == null) continue;
              if (when.year == today.year &&
                  when.month == today.month &&
                  when.day == today.day) {
                todayNet += (c.netAmount ?? 0);
              }
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Today\'s Revenue',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${todayNet.toStringAsFixed(0)} TND',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Net earnings after platform fee',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Recent Transactions',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1D2939),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (items.isEmpty)
                    Text(
                      'No completed consultations yet',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF667085),
                      ),
                    )
                  else
                    ...items.take(10).map((c) {
                      final patient = (c.patientName ?? '').trim().isEmpty
                          ? 'Patient'
                          : c.patientName!.trim();
                      final ts = (c.timestamp ?? '').trim();
                      final when = ts.isEmpty ? null : DateTime.tryParse(ts);
                      final date = (when ?? DateTime.now())
                          .toIso8601String()
                          .split('T')
                          .first;

                      final gross =
                          double.tryParse((c.fee ?? '').toString()) ?? 0;
                      final platformFee =
                          double.tryParse((c.omnicareFee ?? '').toString()) ??
                          0;
                      final net =
                          double.tryParse((c.netAmount ?? '').toString()) ?? 0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildTransactionCard(
                          patient: patient,
                          date: date,
                          type: '',
                          gross: gross,
                          fee: platformFee,
                          net: net,
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTransactionCard({
    required String patient,
    required String date,
    required String type,
    required double gross,
    required double fee,
    required double net,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  patient,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1D2939),
                  ),
                ),
              ),
              if (type.trim().isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF8FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    type,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F6F73),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            date,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: const Color(0xFF667085),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gross',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFF667085),
                      ),
                    ),
                    Text(
                      '$gross TND',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1D2939),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fee (15%)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFF667085),
                      ),
                    ),
                    Text(
                      '$fee TND',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Net',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFF667085),
                      ),
                    ),
                    Text(
                      '$net TND',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1FBF9A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Doctor History Screen
class DoctorHistoryScreen extends StatelessWidget {
  const DoctorHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Consultation History',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1D2939),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search consultations...',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF98A2B3),
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF667085),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF1FBF9A),
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),

            // Consultation List
            Expanded(
              child: FutureBuilder<List<api.Consultation>>(
                future: ProviderMeApi().listMyConsultations(
                  status: 'COMPLETED',
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Failed to load consultations: ${snapshot.error}',
                        style: GoogleFonts.plusJakartaSans(),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final items = snapshot.data ?? const <api.Consultation>[];
                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        'No consultations found',
                        style: GoogleFonts.plusJakartaSans(),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final c = items[index];
                      final patientName = (c.patientName ?? '').trim().isEmpty
                          ? 'Patient'
                          : c.patientName!.trim();
                      final ts = (c.timestamp ?? '').trim();
                      final when = ts.isEmpty ? null : DateTime.tryParse(ts);
                      final date = (when ?? DateTime.now())
                          .toIso8601String()
                          .split('T')
                          .first;
                      final time = (when == null)
                          ? '--:--'
                          : '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ConsultationDetailScreen(
                                consultation: c.toCreateJson()
                                  ..addAll({
                                    'id': c.id,
                                    'doctorName': c.doctorName,
                                    'doctorSpecialty': c.doctorSpecialty,
                                    'patientName': c.patientName,
                                    'symptoms': c.symptoms,
                                    'diagnosis': c.diagnosis,
                                    'treatment': c.treatment,
                                    'status': c.status,
                                    'timestamp': c.timestamp,
                                    'fee': c.fee,
                                  }),
                                consultationId: (c.id ?? '').toString(),
                              ),
                            ),
                          );
                        },
                        child: _buildPatientCard(
                          name: patientName,
                          date: date,
                          time: time,
                          diagnosis: (c.diagnosis ?? '').toString(),
                          treatment: (c.treatment ?? '').toString(),
                          payment: (c.fee ?? '').toString().isEmpty
                              ? ''
                              : '${c.fee} TND',
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientCard({
    required String name,
    required String date,
    required String time,
    required String diagnosis,
    required String treatment,
    required String payment,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF1FBF9A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    name.split(' ').map((n) => n[0]).join(''),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1FBF9A),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1D2939),
                      ),
                    ),
                    Text(
                      '$date • $time',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                payment,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1FBF9A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.medical_services_outlined,
                      size: 14,
                      color: Color(0xFF667085),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Diagnosis:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        diagnosis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: const Color(0xFF1D2939),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.medication_outlined,
                      size: 14,
                      color: Color(0xFF667085),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Treatment:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        treatment,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: const Color(0xFF1D2939),
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
}

// Doctor Profile Screen
class DoctorProfileScreen extends StatelessWidget {
  const DoctorProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final doctorName = context.watch<UserProvider>().user?.displayName;
    final providerType = context.watch<UserProvider>().user?.providerType;
    final resolvedName = (doctorName != null && doctorName.trim().isNotEmpty)
        ? doctorName.trim()
        : 'Doctor';
    final resolvedType =
        (providerType != null && providerType.trim().isNotEmpty)
        ? providerType.trim()
        : 'Professional';
    final initials = resolvedName
        .split(RegExp(r'\s+'))
        .where((p) => p.trim().isNotEmpty)
        .take(2)
        .map((p) => p.trim()[0].toUpperCase())
        .join();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Profile',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1D2939),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF667085)),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Profile Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1FBF9A), Color(0xFF0F6F73)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          initials.isEmpty ? 'D' : initials,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      resolvedName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      resolvedType,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        FutureBuilder<List<api.Consultation>>(
                          future: ProviderMeApi().listMyConsultations(
                            status: 'COMPLETED',
                          ),
                          builder: (context, snapshot) {
                            final count =
                                (snapshot.data ?? const <api.Consultation>[])
                                    .length;
                            return Text(
                              '$count Consultations',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Menu Items
              _buildMenuItem(
                icon: Icons.person_outline,
                title: 'Personal Information',
                onTap: () {},
              ),
              const SizedBox(height: 12),
              _buildMenuItem(
                icon: Icons.medical_information_outlined,
                title: 'Professional Details',
                onTap: () {},
              ),
              const SizedBox(height: 12),
              _buildMenuItem(
                icon: Icons.notifications_outlined,
                title: 'Reservations',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProviderReservationsScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildMenuItem(
                icon: Icons.help_outline,
                title: 'Help & Support',
                onTap: () {},
              ),
              const SizedBox(height: 12),
              _buildMenuItem(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                onTap: () {},
              ),
              const SizedBox(height: 20),

              // Logout Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFEF3F2),
                    foregroundColor: Colors.red,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.logout, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Logout',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF1FBF9A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF1FBF9A), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1D2939),
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF667085)),
          ],
        ),
      ),
    );
  }
}
