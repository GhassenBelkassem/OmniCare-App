import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'doctor_selection_screen.dart';
import '../../core/api/consultations_api.dart';
import '../../core/api/doctors_api.dart';
import '../../core/utils/logger.dart';
import '../../core/api/api_error_utils.dart';
import '../../core/models/consultation.dart';

class ReviewConfirmScreen extends StatefulWidget {
  final Map<String, dynamic> requestData;

  const ReviewConfirmScreen({
    Key? key,
    required this.requestData,
  }) : super(key: key);

  @override
  State<ReviewConfirmScreen> createState() => _ReviewConfirmScreenState();
}

class _ReviewConfirmScreenState extends State<ReviewConfirmScreen> {
  String _paymentMethod = 'cash';
  bool _isSubmitting = false;

  Future<void> _handleConfirm() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final painLevel = widget.requestData['painLevel'] as int?;
      final bodyParts = (widget.requestData['bodyParts'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
      final symptoms = (widget.requestData['description'] ?? widget.requestData['symptoms'])?.toString() ?? '';

      final location = widget.requestData['location'] as Map<String, dynamic>?;
      double? latitude;
      double? longitude;
      String? streetAddress;
      String? apartmentSuite;
      String? city;

      if (location != null) {
        if (location['type'] == 'gps') {
          latitude = (location['latitude'] as num?)?.toDouble();
          longitude = (location['longitude'] as num?)?.toDouble();
          streetAddress = location['address']?.toString();
        } else if (location['type'] == 'manual') {
          streetAddress = location['street']?.toString();
          apartmentSuite = location['apartment']?.toString();
          city = location['city']?.toString();
        }
      }

      if (painLevel == null) {
        throw StateError('Missing painLevel');
      }
      if (bodyParts.isEmpty) {
        throw StateError('Missing affectedAreas');
      }
      if (symptoms.trim().isEmpty) {
        throw StateError('Missing symptoms');
      }
      if (latitude == null || longitude == null) {
        throw StateError('Missing latitude/longitude');
      }

      final doctors = await DoctorsApi().listDoctors();
      if (doctors.isEmpty) {
        throw StateError('No doctors returned from /api/doctors');
      }
      final doctorId = doctors.first['doctorId']?.toString();
      if (doctorId == null || doctorId.isEmpty) {
        throw StateError('Missing doctorId field in /api/doctors response');
      }

      final created = await ConsultationsApi().createConsultation(
        doctorId: doctorId,
        patientId: null,
        symptoms: symptoms.trim(),
        painLevel: painLevel,
        affectedAreas: bodyParts,
        latitude: latitude,
        longitude: longitude,
        streetAddress: streetAddress,
        apartmentSuite: apartmentSuite,
        city: city,
      );

      final createdId = created.id;
      if (createdId == null || createdId.isEmpty) {
        throw StateError('Missing consultationId in createConsultation response');
      }

      final Consultation fetched = await ConsultationsApi().getConsultation(
        consultationId: createdId,
      );

      if (!mounted) return;

      Navigator.pushNamed(
        context,
        '/doctor-calling',
        arguments: {
          ...widget.requestData,
          'consultationId': createdId,
          'consultation': fetched,
        },
      );
    } catch (e, st) {
      AppLogger.error('Failed to confirm emergency request', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit: ${apiErrorMessage(e)}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _handleBookAppointment() {
    // Get provider type from request data (default to 'doctor' if not set)
    final providerType = widget.requestData['providerType'] as String? ?? 'doctor';
    
    Navigator.pushNamed(
      context,
      '/provider-list',
      arguments: {'providerType': providerType},
    );
  }

  @override
  Widget build(BuildContext context) {
    final doctor = widget.requestData['doctor'] as Doctor;
    final patientType = widget.requestData['patientType'] as String;
    final bodyParts = widget.requestData['bodyParts'] as List<String>;
    final painLevel = widget.requestData['painLevel'] as int;
    final description = widget.requestData['description'] as String;
    final location = widget.requestData['location'] as Map<String, dynamic>;
    final consultationType = widget.requestData['consultationType'] as String? ?? 'home';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A202C)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Révision & Confirmation',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A202C),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Révision & Confirmation',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A202C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Veuillez vérifier vos informations avant de confirmer',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: const Color(0xFF667085),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  _buildDoctorCard(doctor),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    icon: Icons.person,
                    title: 'Informations Patient',
                    children: [
                      _buildInfoRow('Type de patient', _getPatientTypeLabel(patientType)),
                      if (widget.requestData['age'] != null)
                        _buildInfoRow('Âge', '${widget.requestData['age']} ans'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    icon: Icons.medical_services,
                    title: 'Symptômes',
                    children: [
                      _buildInfoRow('Zones affectées', '${bodyParts.length} zone(s)'),
                      _buildInfoRow('Niveau de douleur', '$painLevel/10'),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: const Color(0xFF1A202C),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    icon: Icons.location_on,
                    title: 'Lieu de Visite',
                    children: [
                      if (location['useGPS'] == true)
                        Text(
                          'Utilisation de la position GPS actuelle',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: const Color(0xFF667085),
                          ),
                        )
                      else ...[
                        Text(
                          location['street'] ?? '',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: const Color(0xFF1A202C),
                          ),
                        ),
                        if (location['apartment']?.isNotEmpty == true)
                          Text(
                            location['apartment'],
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: const Color(0xFF1A202C),
                            ),
                          ),
                        Text(
                          '${location['city']}, Tunisie',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A202C),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildPaymentMethodCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  String _getPatientTypeLabel(String type) {
    switch (type) {
      case 'me':
        return 'Moi-même';
      case 'child':
        return 'Enfant';
      case 'elderly':
        return 'Personne Âgée';
      default:
        return type;
    }
  }

  Widget _buildDoctorCard(Doctor doctor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1FBF9A).withOpacity(0.05),
            const Color(0xFF6BE3B2).withOpacity(0.05),
          ],
        ),
        border: Border.all(color: const Color(0xFF1FBF9A).withOpacity(0.2), width: 2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF1FBF9A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1FBF9A), width: 3),
            ),
            child: const Icon(Icons.person, color: Color(0xFF1FBF9A), size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        doctor.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1A202C),
                        ),
                      ),
                    ),
                    const Icon(Icons.verified, color: Color(0xFF1FBF9A), size: 18),
                  ],
                ),
                Text(
                  doctor.specialty,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${doctor.distance} km',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${doctor.eta} min ETA',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1FBF9A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${doctor.price} TND',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1FBF9A),
                ),
              ),
              Text(
                'Frais de consultation',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color: const Color(0xFF667085),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                child: Icon(icon, color: const Color(0xFF1FBF9A), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A202C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: const Color(0xFF667085),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A202C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                child: const Icon(Icons.payment, color: Color(0xFF1FBF9A), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Méthode de Paiement',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A202C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildPaymentOption('cash', Icons.money, 'Espèces'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPaymentOption('card', Icons.credit_card, 'Carte'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(String method, IconData icon, String label) {
    final isSelected = _paymentMethod == method;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = method),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1FBF9A).withOpacity(0.05) : Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFF1FBF9A) : const Color(0xFFE2E8F0),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF1FBF9A) : const Color(0xFF667085),
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? const Color(0xFF1FBF9A) : const Color(0xFF667085),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final consultationType = widget.requestData['consultationType'] as String? ?? 'home';
    final isHomeConsultation = consultationType == 'home';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: const Color(0xFFE2E8F0)),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : (isHomeConsultation ? _handleConfirm : _handleBookAppointment),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1FBF9A),
              disabledBackgroundColor: const Color(0xFF1FBF9A).withOpacity(0.5),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isHomeConsultation ? Icons.home : Icons.calendar_today,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isHomeConsultation 
                            ? 'CONFIRMER ET RECHERCHER UN MÉDECIN'
                            : 'RECHERCHER DES PROFESSIONNELS',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
