import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock notifications data
    final notifications = [
      {
        'id': '1',
        'type': 'appointment_confirmed',
        'title': 'Rendez-vous Confirmé',
        'message': 'Dr. Ahmed Mansour a accepté votre demande et propose des créneaux disponibles',
        'doctor': {
          'name': 'Dr. Ahmed Mansour',
          'specialty': 'Médecin Généraliste',
          'rating': 4.8,
          'experience': '10 ans',
        },
        'time': '2h',
        'isRead': false,
      },
      {
        'id': '2',
        'type': 'appointment_confirmed',
        'title': 'Rendez-vous Confirmé',
        'message': 'Dr. Sarah Benali a accepté votre demande et propose des créneaux disponibles',
        'doctor': {
          'name': 'Dr. Sarah Benali',
          'specialty': 'Cardiologue',
          'rating': 4.9,
          'experience': '15 ans',
        },
        'time': '5h',
        'isRead': false,
      },
      {
        'id': '3',
        'type': 'appointment_reminder',
        'title': 'Rappel de Rendez-vous',
        'message': 'Votre rendez-vous avec Dr. Karim Alami est demain à 10:00',
        'doctor': {
          'name': 'Dr. Karim Alami',
          'specialty': 'Kinésithérapeute',
          'rating': 4.7,
          'experience': '8 ans',
        },
        'time': '1j',
        'isRead': true,
      },
    ];

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
          'Notifications',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1D2939),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Mark all as read
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Toutes les notifications marquées comme lues',
                    style: GoogleFonts.plusJakartaSans(),
                  ),
                  backgroundColor: const Color(0xFF1FBF9A),
                ),
              );
            },
            child: Text(
              'Tout lire',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1FBF9A),
              ),
            ),
          ),
        ],
      ),
      body: notifications.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _buildNotificationCard(context, notification);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF1FBF9A).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none,
              size: 60,
              color: Color(0xFF1FBF9A),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Aucune Notification',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1D2939),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vous n\'avez pas de nouvelles notifications',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: const Color(0xFF667085),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, Map<String, dynamic> notification) {
    final isRead = notification['isRead'] as bool;
    final type = notification['type'] as String;
    
    return GestureDetector(
      onTap: () {
        if (type == 'appointment_confirmed') {
          Navigator.pushNamed(
            context,
            '/appointment-confirmation',
            arguments: notification['doctor'],
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xFF1FBF9A).withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead ? const Color(0xFFE5E7EB) : const Color(0xFF1FBF9A).withOpacity(0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _getNotificationColor(type).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getNotificationIcon(type),
                color: _getNotificationColor(type),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification['title'],
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1D2939),
                          ),
                        ),
                      ),
                      if (!isRead)
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
                    notification['message'],
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: const Color(0xFF667085),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: const Color(0xFF667085),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Il y a ${notification['time']}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: const Color(0xFF667085),
                        ),
                      ),
                      if (type == 'appointment_confirmed') ...[
                        const Spacer(),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: const Color(0xFF1FBF9A),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'appointment_confirmed':
        return Icons.check_circle;
      case 'appointment_reminder':
        return Icons.notifications_active;
      default:
        return Icons.info;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'appointment_confirmed':
        return const Color(0xFF1FBF9A);
      case 'appointment_reminder':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF3B82F6);
    }
  }
}
