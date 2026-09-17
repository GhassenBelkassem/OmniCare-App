import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'doctor_matching.dart';
import '../../core/api/consultations_api.dart';
import '../../core/models/consultation.dart';
import '../../services/notification_service.dart';

class DoctorCallingScreen extends StatefulWidget {
  final Map<String, dynamic> requestData;

  const DoctorCallingScreen({super.key, required this.requestData});

  @override
  State<DoctorCallingScreen> createState() => _DoctorCallingScreenState();
}

class _DoctorCallingScreenState extends State<DoctorCallingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _navigationTimer;
  Timer? _pollTimer;

  String? _consultationId;
  Consultation? _consultation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _consultationId = widget.requestData['consultationId']?.toString();
    final c = widget.requestData['consultation'];
    if (c is Consultation) {
      _consultation = c;
    }

    _startPolling();

    // Send notification that doctor is on the way
    final doctor = widget.requestData['doctor'] as Doctor?;
    if (doctor != null) {
      NotificationService().showDoctorOnWayNotification(doctor.name);
    }

    _navigationTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/doctor-arriving',
          arguments: {
            ...widget.requestData,
            'consultationId': _consultationId,
            'consultation': _consultation,
          },
        );
      }
    });
  }

  void _startPolling() {
    if (_consultationId == null || _consultationId!.isEmpty) {
      return;
    }

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (t) async {
      if (!mounted) {
        t.cancel();
        return;
      }

      try {
        final latest = await ConsultationsApi().getConsultation(
          consultationId: _consultationId!,
        );

        if (!mounted) return;

        setState(() {
          _consultation = latest;
        });

        final status = (latest.status ?? '').toUpperCase();
        if (status == 'COMPLETED' || status == 'CANCELLED') {
          t.cancel();
          _navigationTimer?.cancel();
          if (!mounted) return;
          Navigator.pushReplacementNamed(
            context,
            '/consultation-complete',
            arguments: {
              ...widget.requestData,
              'consultationId': _consultationId,
              'consultation': latest,
            },
          );
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _navigationTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final doctor = widget.requestData['doctor'] as Doctor?;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
          child: Row(
            children: [
              const SizedBox(width: 40),
              Text(
                'Demande Confirmée',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A202C),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildAnimatedPhone(),
                    const SizedBox(height: 32),
                    Text(
                      'Le Médecin Vous Appellera Bientôt',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1A202C),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${doctor?.name ?? "Votre médecin"} vous appellera dans les prochaines minutes pour confirmer la visite et discuter de tout détail urgent.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        color: const Color(0xFF667085),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    _buildInfoCard(
                      icon: Icons.phone,
                      color: const Color(0xFF3B82F6),
                      title: 'Appel de Confirmation',
                      description:
                          'Le médecin vérifiera votre emplacement et confirmera l\'heure d\'arrivée estimée.',
                    ),
                    const SizedBox(height: 16),
                    _buildInfoCard(
                      icon: Icons.check_circle,
                      color: const Color(0xFF10B981),
                      title: 'Que Préparer',
                      description:
                          'Ayez votre passeport médical prêt et assurez un accès facile à votre emplacement.',
                    ),
                    const SizedBox(height: 16),
                    _buildInfoCard(
                      icon: Icons.access_time,
                      color: const Color(0xFFFFA500),
                      title: 'Après Confirmation',
                      description:
                          'Une fois confirmé, vous pourrez suivre l\'arrivée du médecin en temps réel sur la carte.',
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF1FBF9A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'En attente de l\'appel du médecin...',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF667085),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F5F7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border(
                          left: BorderSide(
                            color: const Color(0xFF1FBF9A),
                            width: 4,
                          ),
                        ),
                      ),
                      child: Text(
                        'Gardez votre téléphone à proximité et le volume activé',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: const Color(0xFF667085),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedPhone() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Pulsing rings
        ...List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final delay = index * 0.4;
              final value = (_pulseController.value + delay) % 1.0;
              return Container(
                width: 96 + (value * 104),
                height: 96 + (value * 104),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(
                      0xFF1FBF9A,
                    ).withOpacity(0.6 - (value * 0.6)),
                    width: 2,
                  ),
                ),
              );
            },
          );
        }),
        // Phone icon
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: const Color(0xFF1FBF9A).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.phone, color: Color(0xFF1FBF9A), size: 48),
        ),
      ],
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        border: Border.all(color: color.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: color.withOpacity(0.8),
                    height: 1.4,
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
