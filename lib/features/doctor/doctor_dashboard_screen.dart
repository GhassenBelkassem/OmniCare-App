import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math';
import 'request_accepted_screen.dart';
import '../../core/api/patients_api.dart';
import '../../core/models/patient_models.dart';
import '../../providers/user_provider.dart';
import '../../core/api/consultations_api.dart';
import '../../core/models/consultation.dart' as api;
import 'consultation_detail_screen.dart';
import 'patient_medical_passport_screen.dart';

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
          future: api.getPatientsForDoctor(),
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
                _buildNavItem(
                  icon: Icons.home_rounded,
                  label: 'Command',
                  index: 0,
                ),
                _buildNavItem(
                  icon: Icons.trending_up_rounded,
                  label: 'Revenue',
                  index: 1,
                ),
                _buildNavItem(
                  icon: Icons.people_rounded,
                  label: 'History',
                  index: 2,
                ),
                _buildNavItem(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  index: 3,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  PatientSummary? _requestPatient;

  String get requestPatientName => _requestPatient?.displayName ?? 'Patient';

  @override
  void initState() {
    super.initState();
  }

  void _simulateIncomingRequest() {
    if (!mounted || !_isLive) return;
    setState(() {
      _hasIncomingRequest = true;
      _countdown = 60;
    });
    _loadRequestPatient();
    _startCountdown();
  }

  Future<void> _loadRequestPatient() async {
    try {
      final list = await PatientsApi().getPatientsForDoctor();
      if (!mounted) return;
      if (list.isEmpty) return;

      final randomPick = list[Random().nextInt(list.length)];
      setState(() {
        _requestPatient = randomPick;
      });
    } catch (_) {
      // Leave request patient null; UI will fallback gracefully.
    }
  }

  GoogleMapController? _mapController;

  // Patient location in Tunis (Avenue Habib Bourguiba)
  static const LatLng _patientLocation = LatLng(36.8065, 10.1815);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
                onPressed: () {},
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

  Widget _buildDoctorInfoCard() {
    final doctorName = context.watch<UserProvider>().user?.displayName;
    final resolvedName = (doctorName != null && doctorName.trim().isNotEmpty)
        ? doctorName.trim()
        : 'Doctor';
    final initials = resolvedName
        .split(RegExp(r'\s+'))
        .where((p) => p.trim().isNotEmpty)
        .take(2)
        .map((p) => p.trim()[0].toUpperCase())
        .join();

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
                initials,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
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
                  'Doctor',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '4.98 Rating',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
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

  Widget _buildLiveStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isLive ? const Color(0xFF1FBF9A) : const Color(0xFFD0D5DD),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _isLive ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isLive ? 'You are LIVE' : 'You are Offline',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1D2939),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isLive
                      ? 'Accepting urgent requests'
                      : 'Toggle to start receiving requests',
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
            onChanged: (value) {
              setState(() {
                _isLive = value;
                if (!value) {
                  _hasIncomingRequest = false;
                  _showMapModal = false;
                  _timer?.cancel();
                  _requestPatient = null;
                }
                if (value) {
                  // Simulate incoming request after 3 seconds
                  Future.delayed(const Duration(seconds: 3), () {
                    if (mounted && _isLive) {
                      _simulateIncomingRequest();
                    }
                  });
                }
              });
            },
            activeThumbColor: const Color(0xFF1FBF9A),
          ),
        ],
      ),
    );
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
      }
    });
  }

  Widget _buildIncomingRequestCard() {
    if (!_isLive || !_hasIncomingRequest) {
      return _buildIdleStateCard();
    }
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
            _requestPatient?.displayName ?? 'Unknown Patient',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1D2939),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.person_outline,
                size: 16,
                color: Color(0xFF667085),
              ),
              const SizedBox(width: 4),
              Text(
                '32 years • Female',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: const Color(0xFF667085),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: Color(0xFF667085),
              ),
              const SizedBox(width: 4),
              Text(
                '1.8 km away • 6 mins ETA',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: const Color(0xFF667085),
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
                  'Chief Complaint',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Acute Migraine',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1D2939),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Symptoms: Severe headache, Sensitivity to light, Nausea',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: const Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // View Details Button
          GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) {
                  return SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Request Details',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1D2939),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => Navigator.pop(context),
                                    icon: const Icon(
                                      Icons.close,
                                      color: Color(0xFF667085),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildDetailedRequestInfo(),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1FBF9A),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
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
                      ),
                    ),
                  );
                },
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1FBF9A)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.visibility,
                    color: const Color(0xFF1FBF9A),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'View Details',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1FBF9A),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // No-op: request details are shown in a modal bottom sheet.
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red,
                    elevation: 0,
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
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            RequestAcceptedScreen(patient: _requestPatient),
                      ),
                    );
                  },
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

  Widget _buildDetailedRequestInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD0D5DD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Complete Request Details',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1D2939),
            ),
          ),
          const SizedBox(height: 16),

          // Patient Information
          _buildDetailRow(
            icon: Icons.person,
            label: 'Name',
            value: requestPatientName,
          ),
          _buildDetailRow(icon: Icons.cake, label: 'Age', value: '32 years'),
          _buildDetailRow(
            icon: Icons.phone,
            label: 'Phone',
            value: '+216 98 765 432',
            isClickable: true,
          ),

          const Divider(height: 24),

          // Location Information
          GestureDetector(
            onTap: () {
              setState(() => _showMapModal = true);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1FBF9A).withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF1FBF9A)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: Color(0xFF1FBF9A),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Location',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF667085),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '15 Avenue Habib Bourguiba, Tunis',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1FBF9A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.map, color: Color(0xFF1FBF9A), size: 20),
                ],
              ),
            ),
          ),
          _buildDetailRow(
            icon: Icons.social_distance,
            label: 'Distance',
            value: '1.8 km away',
          ),

          const Divider(height: 24),

          // Medical Information
          _buildDetailRow(
            icon: Icons.healing,
            label: 'Areas of Hurt',
            value: 'Head (Frontal & Temporal regions)',
          ),

          // Pain Intensity
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.warning_amber,
                color: Color(0xFF667085),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Pain Intensity',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF667085),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        color: Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'High (8/10)',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const Divider(height: 24),

          // Brief Description - Text
          Row(
            children: [
              const Icon(Icons.description, color: Color(0xFF667085), size: 18),
              const SizedBox(width: 8),
              Text(
                'Brief Description (Text)',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF667085),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFD0D5DD)),
            ),
            child: Text(
              'Experiencing severe migraine with intense throbbing pain on both sides of head. Started 3 hours ago. Very sensitive to light and sound. Feeling nauseous.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: const Color(0xFF1D2939),
                height: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Brief Description - Vocal
          Row(
            children: [
              const Icon(Icons.mic, color: Color(0xFF667085), size: 18),
              const SizedBox(width: 8),
              Text(
                'Voice Message',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF667085),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1FBF9A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1FBF9A)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1FBF9A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Voice Description',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1D2939),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '0:45 seconds',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: const Color(0xFF667085),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.volume_up, color: Color(0xFF1FBF9A), size: 20),
              ],
            ),
          ),

          const Divider(height: 24),

          // Date & Time
          _buildDetailRow(
            icon: Icons.calendar_today,
            label: 'Date & Time',
            value: 'Feb 14, 2026 • 2:45 PM',
          ),

          // User Tenure
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF8FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF0F6F73).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_user,
                  color: Color(0xFF0F6F73),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'User since: January 2024 (2 years)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F6F73),
                    ),
                  ),
                ),
              ],
            ),
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
            _isLive ? 'Waiting for Requests...' : 'Go Live to Receive Requests',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1D2939),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isLive
                ? 'You will be notified when a patient needs urgent care nearby'
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
                                '15 Avenue Habib Bourguiba, Tunis',
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
                              target: _patientLocation,
                              zoom: 15.0,
                            ),
                            markers: {
                              Marker(
                                markerId: const MarkerId('patient_location'),
                                position: _patientLocation,
                                infoWindow: InfoWindow(
                                  title: requestPatientName,
                                  snippet: '15 Avenue Habib Bourguiba, Tunis',
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
                                    CameraUpdate.newLatLng(_patientLocation),
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
                                  '1.8 km away',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Overview',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1D2939),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.check_circle_outline,
                label: 'Completed',
                value: '8',
                color: const Color(0xFF1FBF9A),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.attach_money,
                label: 'Earnings',
                value: '240 TND',
                color: const Color(0xFF0F6F73),
              ),
            ),
          ],
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Total Revenue Card
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
                      '240 TND',
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

              // Recent Transactions
              Text(
                'Recent Transactions',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1D2939),
                ),
              ),
              const SizedBox(height: 12),

              _buildTransactionCard(
                patient: 'Sarah Ben Ahmed',
                date: '2026-02-08',
                type: 'Cash',
                gross: 100,
                fee: 15,
                net: 85,
              ),
              const SizedBox(height: 12),
              _buildTransactionCard(
                patient: 'Mohamed Trabelsi',
                date: '2026-02-08',
                type: 'Digital',
                gross: 120,
                fee: 18,
                net: 102,
              ),
              const SizedBox(height: 12),
              _buildTransactionCard(
                patient: 'Amira Mahjoub',
                date: '2026-02-07',
                type: 'Cash',
                gross: 80,
                fee: 12,
                net: 68,
              ),
            ],
          ),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: type == 'Cash'
                      ? const Color(0xFFF0FDF9)
                      : const Color(0xFFEFF8FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  type,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: type == 'Cash'
                        ? const Color(0xFF1FBF9A)
                        : const Color(0xFF0F6F73),
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
                future: ConsultationsApi().listConsultations(
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
                          'AM',
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
                      'Dr. Ahmed Mansour',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cardiologist',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          '4.98 Rating',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '•',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          '156 Consultations',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
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
                title: 'Notifications',
                onTap: () {},
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
