import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ConsultationTypeScreen extends StatelessWidget {
  final String providerType; // 'doctor' or 'kine'

  const ConsultationTypeScreen({
    super.key,
    required this.providerType,
  });

  @override
  Widget build(BuildContext context) {
    final String title = providerType == 'doctor' ? 'Doctor' : 'Physiotherapist';
    
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
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1D2939),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How would you like to consult?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1D2939),
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Choose between urgent home visit or scheduled appointment',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  color: const Color(0xFF667085),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              
              // Home Consultation Card
              _buildConsultationTypeCard(
                context: context,
                title: 'Home Consultation',
                subtitle: 'Urgent care at your location',
                description: 'A verified professional will come to your home',
                icon: Icons.home,
                color: const Color(0xFF1FBF9A),
                badge: 'URGENT',
                badgeColor: const Color(0xFFEF4444),
                onTap: () {
                  // Navigate to existing urgent flow
                  Navigator.pushNamed(context, '/emergency-step1');
                },
              ),
              const SizedBox(height: 16),
              
              // Book Appointment Card
              _buildConsultationTypeCard(
                context: context,
                title: 'Book Appointment',
                subtitle: 'Schedule for later',
                description: 'Browse and select from available professionals',
                icon: Icons.calendar_today,
                color: const Color(0xFF8B5CF6),
                badge: 'SCHEDULED',
                badgeColor: const Color(0xFF8B5CF6),
                onTap: () {
                  // Navigate to provider list
                  Navigator.pushNamed(
                    context,
                    '/provider-list',
                    arguments: {'providerType': providerType},
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConsultationTypeCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required Color color,
    required String badge,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFE5E7EB),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
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
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 28,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: badgeColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1D2939),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: const Color(0xFF667085),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'Continue',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward,
                  color: color,
                  size: 18,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
