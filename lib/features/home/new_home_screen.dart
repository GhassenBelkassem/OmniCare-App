import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/api/account_api.dart';
import '../../core/models/family_models.dart' as core_models;
import '../../providers/user_onboarding_provider.dart' hide MedicalDocument;
import '../../providers/user_provider.dart';
import '../../providers/family_provider.dart';
import 'edit_medical_data_screen.dart';
import 'add_family_member_screen.dart';
import 'family_member_detail_screen.dart';
import 'document_viewer_screen.dart';
import 'qr_code_modal.dart';
import 'history_tab.dart';

class NewHomeScreen extends StatefulWidget {
  const NewHomeScreen({super.key});

  @override
  State<NewHomeScreen> createState() => _NewHomeScreenState();
}

class _NewHomeScreenState extends State<NewHomeScreen> {
  int _selectedIndex = 0;

  FamilyMember _toDetailMember(core_models.FamilyMember member) {
    final medicalInfo = member.medicalInfo ?? const <String, dynamic>{};
    final chronic = (medicalInfo['chronicConditions'] is List)
        ? (medicalInfo['chronicConditions'] as List)
              .map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList()
        : const <String>[];

    final meds = (medicalInfo['currentMedications'] is List)
        ? (medicalInfo['currentMedications'] as List)
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .map(
                (m) => Medication(
                  medicationId: m['medicationId']?.toString(),
                  name: (m['name'] ?? m['medicationId'] ?? 'Medication')
                      .toString(),
                  dosage: (m['dosage'] ?? m['catalogDosage'] ?? '-').toString(),
                  frequency: (m['frequency'] ?? '-').toString(),
                ),
              )
              .toList()
        : const <Medication>[];

    final age = member.ageYears ?? 0;
    final blood = (member.bloodGroup ?? '-').trim();

    return FamilyMember(
      id: member.id,
      name: member.fullName,
      age: age,
      relationship: member.relationship,
      avatar: '',
      bloodType: blood.isEmpty ? '-' : blood,
      chronicConditions: chronic,
      currentMedications: meds,
      documents: const <MedicalDocument>[],
      criticalAlert: null,
      phoneNumber: null,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final familyProvider = Provider.of<FamilyProvider>(
        context,
        listen: false,
      );
      if (familyProvider.members.isEmpty && !familyProvider.isLoading) {
        familyProvider.loadFamilyMembers();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final onboarding = Provider.of<UserOnboardingProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);

    if (userProvider.profile == null) {
      if (!userProvider.isLoading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          context.read<UserProvider>().loadIfLoggedIn();
        });
      }

      return Scaffold(
        backgroundColor: const Color(0xFFF4F5F7),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text(
                  'Loading profile...',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final resolvedDisplayName = (userProvider.user?.displayName ?? '').trim();
    final userName = resolvedDisplayName.isNotEmpty
        ? resolvedDisplayName
        : (onboarding.email?.split('@')[0] ?? 'User');

    final String firstName = (userProvider.user?.derivedFirstName ?? '').trim();
    final String lastName = (userProvider.user?.derivedLastName ?? '').trim();

    final String healthCardPatientName;
    if (userProvider.isLoading && userProvider.user == null) {
      healthCardPatientName = 'Loading...';
    } else if (firstName.isNotEmpty || lastName.isNotEmpty) {
      healthCardPatientName = [
        firstName,
        lastName,
      ].where((e) => e.trim().isNotEmpty).join(' ');
    } else if ((onboarding.email ?? '').isNotEmpty) {
      healthCardPatientName = onboarding.email!.split('@')[0];
    } else {
      healthCardPatientName = 'User';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildStickyHeader(userName),
            Expanded(child: _getSelectedTabContent()),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _getSelectedTabContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return _buildProfileTab();
      case 3:
        return _buildNotificationsTab();
      case 4:
        return _buildHistoryTab();
      default:
        return _buildHomeTab();
    }
  }

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 24),
          _buildUrgentCareCard(),
          const SizedBox(height: 16),
          _buildQuickActionsCards(),
          const SizedBox(height: 32),
          _buildTrustSection(),
          const SizedBox(height: 32),
          _buildHowItWorksSection(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildUrgentCareCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1FBF9A), Color(0xFF0F9D7E)],
          ),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1FBF9A).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.access_time,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Urgent Care',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Need a Doctor Right Now?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.2,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'A verified doctor at your door within minutes.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Colors.white.withOpacity(0.9),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () async {
                  final familyProvider = Provider.of<FamilyProvider>(
                    context,
                    listen: false,
                  );
                  if (familyProvider.members.isEmpty &&
                      !familyProvider.isLoading) {
                    await familyProvider.loadFamilyMembers();
                  }
                  if (!mounted) return;
                  Navigator.pushNamed(context, '/emergency-step0');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1FBF9A),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Request Urgent Doctor',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
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
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.videocam,
                      color: Color(0xFF8B5CF6),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Start Live Call',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A202C),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Psychologist',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.phone,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Call Ambulance',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SAMU - 190',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.9),
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

  Widget _buildTrustSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
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
        child: Row(
          children: [
            // Image placeholder for doctors
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F5F7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/images/Doctors-bro.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF1FBF9A).withOpacity(0.1),
                            const Color(0xFF6BE3B2).withOpacity(0.1),
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.groups,
                        size: 48,
                        color: Color(0xFF1FBF9A),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trusted by over',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A202C),
                    ),
                  ),
                  Text(
                    '100 doctors',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A202C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Licensed & verified across Tunisia',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF667085),
                      height: 1.4,
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

  Widget _buildHowItWorksSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            'How it works',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A202C),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 32),
          _buildStepCard(
            number: '1',
            title: 'Describe your symptoms',
            description: 'Tell us what\'s wrong and select the affected area.',
            icon: Icons.edit_note_rounded,
            color: const Color(0xFF1FBF9A),
          ),
          const SizedBox(height: 16),
          _buildStepCard(
            number: '2',
            title: 'Get matched instantly',
            description: 'We connect you with the nearest available doctor.',
            icon: Icons.person_search_rounded,
            color: const Color(0xFF8B5CF6),
          ),
          const SizedBox(height: 16),
          _buildStepCard(
            number: '3',
            title: 'Receive care at home',
            description: 'Your doctor arrives and provides quality treatment.',
            icon: Icons.home_rounded,
            color: const Color(0xFF0F6F73),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required String number,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(child: Icon(icon, color: color, size: 28)),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          number,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A202C),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF667085),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCTAButton({
    required IconData icon,
    required String label,
    required Color color,
    bool outlined = false,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: outlined ? Colors.white : color,
        foregroundColor: outlined ? color : Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: outlined ? BorderSide(color: color, width: 2) : BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildSearchFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Find a Doctor',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1D2939),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search doctors...',
                hintStyle: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF9CA3AF),
                ),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF667085)),
                filled: true,
                fillColor: const Color(0xFFF4F5F7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.black.withOpacity(0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.black.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFF1FBF9A),
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorsList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Doctors (0)',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1D2939),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              'No doctors available yet.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF667085),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorCard(Map<String, dynamic> doctor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Stack(
              children: [
                Container(
                  height: 160,
                  width: double.infinity,
                  color: const Color(0xFFF4F5F7),
                  child: const Icon(
                    Icons.person,
                    size: 60,
                    color: Color(0xFF667085),
                  ),
                ),
                if (doctor['verified'] == true)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor['name'],
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1D2939),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  doctor['specialty'],
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: const Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 14,
                      color: Color(0xFF667085),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${doctor['distance']} km',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.star, size: 14, color: Color(0xFFFBBF24)),
                    const SizedBox(width: 4),
                    Text(
                      '${doctor['rating']}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1D2939),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${doctor['experience']} years experience',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1FBF9A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Request Visit',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
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

  Widget _buildProfileTab() {
    final onboarding = Provider.of<UserOnboardingProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final resolvedDisplayName = (userProvider.user?.displayName ?? '').trim();
    final userName = resolvedDisplayName.isNotEmpty
        ? resolvedDisplayName
        : (onboarding.email?.split('@')[0] ?? 'User');

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // Section 1: Personal Medical Passport
            _buildMedicalPassportSection(userName),

            const SizedBox(height: 32),

            // Section 2: Medical Documents
            _buildMedicalDocumentsSection(),

            const SizedBox(height: 32),

            // Section 3: Family Circle
            _buildFamilyCircleSection(),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalPassportSection(String userName) {
    final onboarding = Provider.of<UserOnboardingProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);

    final Map<String, dynamic> medicalInfo =
        userProvider.user?.medicalInfo ?? const <String, dynamic>{};
    final List<String> chronicConditions =
        (medicalInfo['chronicConditions'] is List)
        ? (medicalInfo['chronicConditions'] as List)
              .map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList()
        : const <String>[];
    final List<Map<String, dynamic>> currentMedications =
        (medicalInfo['currentMedications'] is List)
        ? (medicalInfo['currentMedications'] as List)
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList()
        : const <Map<String, dynamic>>[];
    final String bloodGroup = (userProvider.user?.bloodGroup ?? '').trim();

    final String patientName;
    if (userProvider.isLoading && userProvider.user == null) {
      patientName = 'Loading...';
    } else if ((userProvider.user?.displayName ?? '').trim().isNotEmpty) {
      patientName = userProvider.user!.displayName;
    } else if ((onboarding.email ?? '').isNotEmpty) {
      patientName = onboarding.email!.split('@')[0];
    } else {
      patientName = 'User';
    }

    final String patientId = (userProvider.user?.email.isNotEmpty == true)
        ? userProvider.user!.email
        : (onboarding.email ?? '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mon Carnet de Santé Digital',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A202C),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Votre passeport médical pour un accès rapide',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF667085),
          ),
        ),
        const SizedBox(height: 20),

        // Digital ID Card
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1FBF9A).withOpacity(0.05),
                Colors.white,
                const Color(0xFF6BE3B2).withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => QRCodeModal(
                        patientName: patientName,
                        patientId: patientId,
                        isFamilyMember: false,
                      ),
                    );
                  },
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF1FBF9A).withOpacity(0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1FBF9A).withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.qr_code_2,
                          size: 64,
                          color: Color(0xFF1FBF9A),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Cliquez pour afficher',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF667085),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  patientName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A202C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pour scan médecin',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Blood Type
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GROUPE SANGUIN',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF667085),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                border: Border.all(color: const Color(0xFFFECACA)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.favorite,
                    color: Color(0xFFDC2626),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    bloodGroup.isNotEmpty ? bloodGroup : '-',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Chronic Conditions
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CONDITIONS CHRONIQUES',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF667085),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            if (chronicConditions.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  'Aucune condition',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF667085),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: chronicConditions.map(_buildConditionChip).toList(),
              ),
          ],
        ),

        const SizedBox(height: 24),

        // Current Medications
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MÉDICAMENTS ACTUELS',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF667085),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            if (currentMedications.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  'Aucun médicament',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF667085),
                  ),
                ),
              )
            else
              Column(
                children: [
                  for (int i = 0; i < currentMedications.length; i++) ...[
                    _buildMedicationItem(
                      (() {
                        final m = currentMedications[i];
                        final name = (m['name'] ?? '').toString().trim();
                        final fallback = (m['medicationId'] ?? 'Medication')
                            .toString();
                        final form = (m['form'] ?? '').toString().trim();
                        final soluble = m['soluble'] == true;
                        final base = name.isNotEmpty ? name : fallback;
                        final extras = <String>[];
                        if (form.isNotEmpty) extras.add(form);
                        if (soluble) extras.add('Soluble');
                        if (extras.isEmpty) return base;
                        return '$base (${extras.join(' • ')})';
                      })(),
                      (currentMedications[i]['dosage'] ??
                              currentMedications[i]['catalogDosage'] ??
                              '-')
                          .toString(),
                      (currentMedications[i]['frequency'] ?? '-').toString(),
                    ),
                    if (i != currentMedications.length - 1)
                      const SizedBox(height: 8),
                  ],
                ],
              ),
          ],
        ),

        // Edit Button
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: const Color(0xFFE2E8F0))),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                final editMedications = currentMedications.map((m) {
                  return Medication(
                    medicationId: m['medicationId']?.toString(),
                    name: (m['name'] ?? m['medicationId'] ?? 'Medication')
                        .toString(),
                    dosage: (m['dosage'] ?? '-').toString(),
                    frequency: (m['frequency'] ?? '-').toString(),
                  );
                }).toList();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditMedicalDataScreen(
                      bloodType: bloodGroup.isNotEmpty ? bloodGroup : '-',
                      chronicConditions: chronicConditions,
                      medications: editMedications,
                      documents: [],
                      onSave:
                          (
                            bloodType,
                            conditions,
                            medications,
                            documents,
                          ) async {
                            final medsJson = medications
                                .map(
                                  (m) => {
                                    'medicationId': m.medicationId,
                                    'name': m.name,
                                    'dosage': m.dosage,
                                    'frequency': m.frequency,
                                  },
                                )
                                .toList();

                            await AccountApi().patchMedicalPassport(
                              bloodGroup: bloodType,
                              medicalInfo: {
                                'chronicConditions': conditions,
                                'currentMedications': medsJson,
                              },
                            );

                            if (!context.mounted) return;
                            await Provider.of<UserProvider>(
                              context,
                              listen: false,
                            ).refresh();
                          },
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1FBF9A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Modifier Mes Données',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildConditionChip(String condition) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF6BE3B2).withOpacity(0.1),
        border: Border.all(color: const Color(0xFF6BE3B2).withOpacity(0.3)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: const Color(0xFF0F6F73),
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            condition,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F6F73),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationItem(String name, String dosage, String frequency) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF1FBF9A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.medication,
              color: const Color(0xFF1FBF9A),
              size: 20,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A202C),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$dosage • $frequency',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalDocumentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mes Documents Médicaux',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1A202C),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Analyses et ordonnances',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditMedicalDataScreen(
                      bloodType: 'A+',
                      chronicConditions: ['Diabète Type 2', 'Hypertension'],
                      medications: [
                        Medication(
                          name: 'Metformine',
                          dosage: '500mg',
                          frequency: '2x par jour',
                        ),
                        Medication(
                          name: 'Lisinopril',
                          dosage: '10mg',
                          frequency: '1x par jour',
                        ),
                        Medication(
                          name: 'Aspirine',
                          dosage: '81mg',
                          frequency: '1x par jour',
                        ),
                      ],
                      documents: [],
                      onSave:
                          (
                            bloodType,
                            conditions,
                            medications,
                            documents,
                          ) async {
                            setState(() {
                              // Update profile data here
                            });
                          },
                    ),
                  ),
                );
              },
              icon: Icon(
                Icons.add_circle_outline,
                color: const Color(0xFF1FBF9A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildDocumentItem(
                'Analyse de Sang Complète',
                '10 Fév 2026',
                Icons.bloodtype,
                const Color(0xFFDC2626),
              ),
              const SizedBox(height: 12),
              _buildDocumentItem(
                'Radio Thorax - Contrôle',
                '28 Jan 2026',
                Icons.medical_services,
                const Color(0xFF8B5CF6),
              ),
              const SizedBox(height: 12),
              _buildDocumentItem(
                'Ordonnance Janvier 2026',
                '15 Jan 2026',
                Icons.description,
                const Color(0xFF1FBF9A),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1FBF9A).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1FBF9A).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.info_outline,
                        color: const Color(0xFF1FBF9A),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Vos documents sont stockés de manière sécurisée',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF667085),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentItem(
    String name,
    String date,
    IconData icon,
    Color color,
  ) {
    String docType = 'other';
    if (icon == Icons.bloodtype) {
      docType = 'blood-test';
    } else if (icon == Icons.medical_services) {
      docType = 'xray';
    } else if (icon == Icons.description) {
      docType = 'prescription';
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DocumentViewerScreen(
              documentName: name,
              documentDate: date,
              documentType: docType,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A202C),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: const Color(0xFF667085), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyCircleSection() {
    final familyProvider = Provider.of<FamilyProvider>(context);
    final family = familyProvider.members;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cercle Familial',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A202C),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Gérez les carnets de santé de vos proches',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF667085),
          ),
        ),
        const SizedBox(height: 16),

        if (family.isEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aucun membre de famille pour le moment',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A202C),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ajoutez un proche pour gérer son carnet de santé.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Family Members Grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.85,
          children: [
            ...family.map((m) {
              final age = m.ageYears == null ? '' : '${m.ageYears} ans';
              final alert = null;
              return _buildFamilyMemberCard(
                m.fullName,
                m.relationship,
                age,
                alert,
                memberId: m.id,
              );
            }),
            _buildAddFamilyMemberCard(),
          ],
        ),

        const SizedBox(height: 20),

        // Info Banner
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1FBF9A).withOpacity(0.1),
                const Color(0xFF6BE3B2).withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1FBF9A).withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1FBF9A).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.family_restroom,
                  color: const Color(0xFF1FBF9A),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Chef de Famille - Accès Complet',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A202C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Gérez les carnets de santé de vos proches',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF667085),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFamilyMemberCard(
    String name,
    String relationship,
    String age,
    String? alert, {
    String? memberId,
  }) {
    return GestureDetector(
      onTap: () {
        final familyProvider = Provider.of<FamilyProvider>(
          context,
          listen: false,
        );
        final core = (memberId == null)
            ? null
            : familyProvider.members
                  .cast<core_models.FamilyMember?>()
                  .firstWhere(
                    (m) => m != null && m.id == memberId,
                    orElse: () => null,
                  );
        if (core == null) {
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                FamilyMemberDetailScreen(member: _toDetailMember(core)),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF1FBF9A).withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF1FBF9A), width: 2),
              ),
              child: Icon(
                Icons.person,
                color: const Color(0xFF1FBF9A),
                size: 26,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF0F6F73),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                relationship,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A202C),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              age,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF667085),
              ),
            ),
            if (alert != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  border: Border.all(color: const Color(0xFFFECACA)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: const Color(0xFFDC2626),
                      size: 12,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        alert,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFDC2626),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              'Voir le carnet',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF667085),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddFamilyMemberCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1FBF9A).withOpacity(0.3),
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddFamilyMemberScreen(
                  onSave: (data) {
                    setState(() {
                      // Add new family member to list
                    });
                  },
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF1FBF9A).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add,
                  color: const Color(0xFF1FBF9A),
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Ajouter Membre',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A202C),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Ajoutez un proche',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF667085),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(
              'Notifications',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A202C),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Restez informé de vos rendez-vous et résultats',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: const Color(0xFF667085),
              ),
            ),
            const SizedBox(height: 24),
            _buildNotificationCard(
              icon: Icons.calendar_today,
              iconColor: const Color(0xFF1FBF9A),
              title: 'Rendez-vous confirmé',
              message:
                  'Votre rendez-vous avec Dr. Ahmed Ben Salem est confirmé pour demain à 10h',
              time: 'Il y a 2h',
              isUnread: true,
            ),
            _buildNotificationCard(
              icon: Icons.medication,
              iconColor: const Color(0xFF0F6F73),
              title: 'Rappel médicament',
              message: 'N\'oubliez pas de prendre vos médicaments du soir',
              time: 'Il y a 5h',
              isUnread: true,
            ),
            _buildNotificationCard(
              icon: Icons.description,
              iconColor: const Color(0xFF8B5CF6),
              title: 'Résultats disponibles',
              message:
                  'Vos résultats d\'analyse de sang sont maintenant disponibles',
              time: 'Hier',
              isUnread: false,
            ),
            _buildNotificationCard(
              icon: Icons.favorite,
              iconColor: const Color(0xFFDC2626),
              title: 'Suivi de santé',
              message: 'Pensez à mettre à jour votre carnet de santé',
              time: 'Il y a 2 jours',
              isUnread: false,
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String time,
    required bool isUnread,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnread
            ? const Color(0xFF1FBF9A).withOpacity(0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnread
              ? const Color(0xFF1FBF9A).withOpacity(0.2)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A202C),
                        ),
                      ),
                    ),
                    if (isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF1FBF9A),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: const Color(0xFF667085),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  time,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrgentDoctorModal() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1FBF9A), Color(0xFF0F6F73)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1FBF9A).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.medical_services_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Demande Urgente',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A202C),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Besoin d\'un médecin en urgence ?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: const Color(0xFF667085),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    // Handle urgent doctor request
                  },
                  icon: const Icon(Icons.phone, size: 24),
                  label: Text(
                    'Appeler un Médecin',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    // Handle video consultation request
                  },
                  icon: const Icon(Icons.videocam, size: 24),
                  label: Text(
                    'Consultation Vidéo',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1FBF9A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    // Handle chat request
                  },
                  icon: const Icon(Icons.chat_bubble, size: 24),
                  label: Text(
                    'Chat avec un Médecin',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1FBF9A),
                    side: const BorderSide(color: Color(0xFF1FBF9A), width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Annuler',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF667085),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageCard({
    required String name,
    required String message,
    required String time,
    required bool isUnread,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnread ? const Color(0xFFF0FDF9) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnread
              ? const Color(0xFF1FBF9A).withOpacity(0.3)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF1FBF9A).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Color(0xFF1FBF9A), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A202C),
                      ),
                    ),
                    Text(
                      time,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                    color: isUnread
                        ? const Color(0xFF1A202C)
                        : const Color(0xFF667085),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return HistoryTab();
  }

  Widget _buildStickyHeader(String userName) {
    final provider = Provider.of<UserOnboardingProvider>(context);
    final currentLanguage = provider.language ?? 'en';

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            border: Border(
              bottom: BorderSide(
                color: Colors.black.withOpacity(0.08),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo from assets only
              Image.asset(
                'assets/images/logo.png',
                height: 48,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1FBF9A), Color(0xFF6BE3B2)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.local_hospital,
                      size: 20,
                      color: Colors.white,
                    ),
                  );
                },
              ),
              // Language Selector
              GestureDetector(
                onTap: () => _showLanguageSelector(provider),
                child: Row(
                  children: [
                    Icon(
                      Icons.language_rounded,
                      color: const Color(0xFF1D2939).withOpacity(0.7),
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      currentLanguage.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1D2939),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageSelector(UserOnboardingProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Select Language',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1D2939),
                ),
              ),
              const SizedBox(height: 24),
              _buildLanguageOption(provider, 'en', 'English', '🇬🇧'),
              const SizedBox(height: 12),
              _buildLanguageOption(provider, 'fr', 'Français', '🇫🇷'),
              const SizedBox(height: 12),
              _buildLanguageOption(provider, 'ar', 'العربية', '🇸🇦'),
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(
    UserOnboardingProvider provider,
    String languageCode,
    String languageName,
    String flag,
  ) {
    final isSelected = (provider.language ?? 'en') == languageCode;

    return GestureDetector(
      onTap: () {
        provider.setLanguage(languageCode);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1FBF9A).withOpacity(0.08)
              : const Color(0xFFF4F5F7),
          border: Border.all(
            color: isSelected ? const Color(0xFF1FBF9A) : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(flag, style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                languageName,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1D2939),
                ),
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFF1FBF9A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: _buildUrgentRequestCard()),
          const SizedBox(width: 16),
          Expanded(child: _buildBrowseDoctorsCard()),
        ],
      ),
    );
  }

  Widget _buildUrgentRequestCard() {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1FBF9A), Color(0xFF6BE3B2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1FBF9A).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.add_alert_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Demande\nUrgente',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Médecin à domicile',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrowseDoctorsCard() {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFF1FBF9A), width: 2),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1FBF9A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.search,
                color: Color(0xFF1FBF9A),
                size: 24,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Parcourir les\nMédecins',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1FBF9A),
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Trouver un spécialiste',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF667085),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingAppointment() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_today,
                color: Color(0xFF1FBF9A),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Rendez-vous à venir',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A202C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1FBF9A).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Color(0xFF1FBF9A),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Dr. Ahmed Ben Salem',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1A202C),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified,
                                color: Color(0xFF1FBF9A),
                                size: 16,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1FBF9A).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Cardiologue',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF1FBF9A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      color: Color(0xFF667085),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Lundi, 15 Mars 2024 • 10:00 AM',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Color(0xFF667085),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Clinique Centrale, Tunis',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.phone, size: 18),
                        label: Text(
                          'Appeler',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1FBF9A),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.message, size: 18),
                        label: Text(
                          'Message',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1FBF9A),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.location_on, size: 18),
                        label: Text(
                          'Lieu',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1FBF9A),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
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

  Widget _buildHealthMetrics() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mes Indicateurs de Santé',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A202C),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.3,
            children: [
              _buildMetricCard(
                icon: Icons.favorite,
                label: 'Fréquence Cardiaque',
                value: '72',
                unit: 'bpm',
                color: const Color(0xFFEF4444),
              ),
              _buildMetricCard(
                icon: Icons.water_drop,
                label: 'Tension Artérielle',
                value: '120/80',
                unit: 'mmHg',
                color: const Color(0xFF1FBF9A),
              ),
              _buildMetricCard(
                icon: Icons.monitor_weight,
                label: 'Poids',
                value: '65',
                unit: 'kg',
                color: const Color(0xFF0F6F73),
              ),
              _buildMetricCard(
                icon: Icons.thermostat,
                label: 'Température',
                value: '36.8',
                unit: '°C',
                color: const Color(0xFFF59E0B),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF667085),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A202C),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      unit,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF667085),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          height: 65,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.home_rounded,
                label: 'Accueil',
                index: 0,
                hasNotification: false,
              ),
              _buildNavItem(
                icon: Icons.person_rounded,
                label: 'Profil',
                index: 1,
                hasNotification: false,
              ),
              _buildCenterNavItem(),
              _buildNavItem(
                icon: Icons.notifications_rounded,
                label: 'Notifications',
                index: 3,
                hasNotification: true,
              ),
              _buildNavItem(
                icon: Icons.history_rounded,
                label: 'Historique',
                index: 4,
                hasNotification: false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterNavItem() {
    return GestureDetector(
      onTap: () async {
        final familyProvider = Provider.of<FamilyProvider>(
          context,
          listen: false,
        );
        if (familyProvider.members.isEmpty && !familyProvider.isLoading) {
          await familyProvider.loadFamilyMembers();
        }
        if (!mounted) return;
        Navigator.pushNamed(context, '/emergency-step0');
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1FBF9A), Color(0xFF0F6F73)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1FBF9A).withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.medical_services_rounded,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required bool hasNotification,
  }) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        child: Container(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    color: isSelected
                        ? const Color(0xFF1FBF9A)
                        : const Color(0xFF9CA3AF),
                    size: 26,
                  ),
                  if (hasNotification)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF1FBF9A)
                      : const Color(0xFF9CA3AF),
                  letterSpacing: 0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
