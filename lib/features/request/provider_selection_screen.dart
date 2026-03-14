import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProviderSelectionScreen extends StatelessWidget {
  const ProviderSelectionScreen({super.key});

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
          'Choose Provider',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1D2939),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What type of care do you need?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1D2939),
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Select the healthcare professional you need at home',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  color: const Color(0xFF667085),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              
              // Doctor Card
              _buildProviderCard(
                context: context,
                title: 'Doctor',
                subtitle: 'Medical consultation & diagnosis',
                icon: Icons.medical_services,
                color: const Color(0xFF1FBF9A),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/emergency-step0',
                    arguments: {'providerType': 'doctor'},
                  );
                },
              ),
              const SizedBox(height: 16),
              
              // Nurse Card (Coming Soon)
              _buildProviderCard(
                context: context,
                title: 'Nurse',
                subtitle: 'Injections, wound care & medical procedures',
                icon: Icons.local_hospital,
                color: const Color(0xFF8B5CF6),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Nurse services coming soon!',
                        style: GoogleFonts.plusJakartaSans(),
                      ),
                      backgroundColor: const Color(0xFF8B5CF6),
                    ),
                  );
                },
                isComingSoon: true,
              ),
              const SizedBox(height: 16),
              
              // Kine Card
              _buildProviderCard(
                context: context,
                title: 'Physiotherapist',
                subtitle: 'Physical therapy & rehabilitation',
                icon: Icons.accessibility_new,
                color: const Color(0xFFEF4444),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/emergency-step0',
                    arguments: {'providerType': 'kine'},
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProviderCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isComingSoon = false,
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
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: color,
                size: 32,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1D2939),
                          ),
                        ),
                      ),
                      if (isComingSoon) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'SOON',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFF59E0B),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: const Color(0xFF667085),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward,
                color: color,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
