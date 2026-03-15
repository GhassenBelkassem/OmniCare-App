import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BookingConfirmedScreen extends StatelessWidget {
  final Map<String, dynamic> bookingData;

  const BookingConfirmedScreen({
    super.key,
    required this.bookingData,
  });

  @override
  Widget build(BuildContext context) {
    final doctor = bookingData['doctor'] as Map<String, dynamic>;
    final location = bookingData['location'] as Map<String, dynamic>;
    final date = bookingData['date'] as String;
    final time = bookingData['time'] as String;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const SizedBox.shrink(),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF1D2939)),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              
              // Success Illustration
              Image.asset(
                'assets/images/Confirmed-bro.png',
                height: 240,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 240,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF1FBF9A).withOpacity(0.1),
                          const Color(0xFF0F6F73).withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.check_circle_outline,
                        size: 100,
                        color: const Color(0xFF1FBF9A).withOpacity(0.5),
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 32),
              
              // Success Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF1FBF9A).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF1FBF9A),
                  size: 50,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Title
              Text(
                'Rendez-vous Confirmé !',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1D2939),
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 12),
              
              // Subtitle
              Text(
                'Votre rendez-vous a été confirmé avec succès',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  color: const Color(0xFF667085),
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 32),
              
              // Booking Details Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
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
                    // Doctor Info
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1FBF9A), Color(0xFF0F6F73)],
                            ),
                            borderRadius: BorderRadius.circular(12),
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
                                doctor['name'] ?? 'Dr. Ahmed Mansour',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1D2939),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                doctor['specialty'] ?? 'Médecin Généraliste',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: const Color(0xFF667085),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    const Divider(height: 1, color: Color(0xFFE5E7EB)),
                    const SizedBox(height: 20),
                    
                    // Date & Time
                    _buildDetailRow(
                      Icons.calendar_today,
                      'Date & Heure',
                      '${_formatDate(date)} à $time',
                    ),
                    const SizedBox(height: 16),
                    
                    // Location
                    _buildDetailRow(
                      Icons.location_on,
                      'Lieu',
                      '${location['name']}\n${location['address']}',
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Reminder Card
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
                      Icons.notifications_active,
                      color: Color(0xFF1FBF9A),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Vous recevrez un rappel 24h avant votre rendez-vous',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: const Color(0xFF0F6F73),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // TODO: Add to calendar
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Ajouté au calendrier',
                              style: GoogleFonts.plusJakartaSans(),
                            ),
                            backgroundColor: const Color(0xFF1FBF9A),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1FBF9A),
                        side: const BorderSide(color: Color(0xFF1FBF9A)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calendar_month, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Ajouter au Calendrier',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
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
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1FBF9A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Retour à l\'Accueil',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1D2939),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(String date) {
    // Simple date formatting - in production use intl package
    final parts = date.split('-');
    if (parts.length == 3) {
      final months = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'];
      final month = int.tryParse(parts[1]) ?? 1;
      return '${parts[2]} ${months[month - 1]} ${parts[0]}';
    }
    return date;
  }
}
