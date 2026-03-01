import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../../services/notification_service.dart';

class Doctor {
  final int id;
  final String name;
  final String specialty;
  final String avatar;
  final bool verified;
  final double distance;
  final int eta;
  final int price;
  final double rating;
  final int reviewCount;
  final List<String> tags;
  final String description;
  final List<String> education;
  final List<String> certifications;
  final List<DoctorReview> reviews;
  final String phoneNumber;
  String status; // 'checking', 'viewing', 'ready'

  Doctor({
    required this.id,
    required this.name,
    required this.specialty,
    required this.avatar,
    required this.verified,
    required this.distance,
    required this.eta,
    required this.price,
    required this.rating,
    required this.reviewCount,
    required this.tags,
    required this.description,
    required this.education,
    required this.certifications,
    required this.reviews,
    required this.phoneNumber,
    this.status = 'checking',
  });
}

class DoctorReview {
  final String patientName;
  final double rating;
  final String comment;
  final String date;

  DoctorReview({
    required this.patientName,
    required this.rating,
    required this.comment,
    required this.date,
  });
}

class DoctorSelectionScreen extends StatefulWidget {
  final Map<String, dynamic> emergencyData;

  const DoctorSelectionScreen({
    Key? key,
    required this.emergencyData,
  }) : super(key: key);

  @override
  State<DoctorSelectionScreen> createState() => _DoctorSelectionScreenState();
}

class _DoctorSelectionScreenState extends State<DoctorSelectionScreen> {
  bool _isSearching = true;
  final List<Doctor> _visibleDoctors = [];
  final List<Timer> _timers = [];

  final List<Doctor> _mockDoctors = [
    Doctor(
      id: 1,
      name: 'Dr. Sami Ben Ali',
      specialty: 'Médecin Généraliste',
      avatar: 'https://via.placeholder.com/150',
      verified: true,
      distance: 2.4,
      eta: 12,
      price: 100,
      rating: 4.8,
      reviewCount: 142,
      tags: ['ECG Portable', 'Urgences', 'Arabe/Français'],
      description: 'Médecin généraliste expérimenté avec plus de 15 ans de pratique. Spécialisé dans les soins d\'urgence à domicile et équipé d\'un ECG portable pour les diagnostics cardiaques.',
      education: [
        'Doctorat en Médecine - Faculté de Médecine de Tunis (2008)',
        'Résidence en Médecine Générale - CHU La Rabta (2008-2012)',
      ],
      certifications: [
        'Certification en Médecine d\'Urgence',
        'Formation ECG et Cardiologie',
        'Certification en Soins Intensifs',
      ],
      reviews: [
        DoctorReview(
          patientName: 'Ahmed K.',
          rating: 5.0,
          comment: 'Excellent médecin, très professionnel et à l\'écoute. Il a pris le temps d\'expliquer mon diagnostic.',
          date: 'Il y a 2 semaines',
        ),
        DoctorReview(
          patientName: 'Fatma M.',
          rating: 4.5,
          comment: 'Très bon service, arrivé rapidement. Diagnostic précis et traitement efficace.',
          date: 'Il y a 1 mois',
        ),
        DoctorReview(
          patientName: 'Mohamed S.',
          rating: 5.0,
          comment: 'Je recommande vivement! Très compétent et rassurant.',
          date: 'Il y a 2 mois',
        ),
      ],
      phoneNumber: '+216 98 123 456',
    ),
    Doctor(
      id: 2,
      name: 'Dr. Amira Mansouri',
      specialty: 'Pédiatre',
      avatar: 'https://via.placeholder.com/150',
      verified: true,
      distance: 3.1,
      eta: 15,
      price: 150,
      rating: 4.9,
      reviewCount: 203,
      tags: ['Spécialiste Pédiatrique', 'Vaccinations'],
      description: 'Pédiatre certifiée avec une approche douce et rassurante pour les enfants. Spécialisée dans les soins pédiatriques d\'urgence et les vaccinations.',
      education: [
        'Doctorat en Médecine - Faculté de Médecine de Sousse (2010)',
        'Spécialisation en Pédiatrie - CHU Farhat Hached (2010-2014)',
      ],
      certifications: [
        'Certification en Pédiatrie d\'Urgence',
        'Formation en Néonatologie',
        'Certification en Vaccination Pédiatrique',
      ],
      reviews: [
        DoctorReview(
          patientName: 'Leila B.',
          rating: 5.0,
          comment: 'Excellente avec les enfants! Ma fille était très à l\'aise. Merci Dr. Mansouri!',
          date: 'Il y a 1 semaine',
        ),
        DoctorReview(
          patientName: 'Karim H.',
          rating: 5.0,
          comment: 'Très professionnelle et patiente. Elle a bien expliqué le traitement.',
          date: 'Il y a 3 semaines',
        ),
      ],
      phoneNumber: '+216 22 456 789',
    ),
    Doctor(
      id: 3,
      name: 'Dr. Youssef Trabelsi',
      specialty: 'Médecine Interne',
      avatar: 'https://via.placeholder.com/150',
      verified: true,
      distance: 1.8,
      eta: 8,
      price: 80,
      rating: 4.7,
      reviewCount: 95,
      tags: ['Maladies Chroniques', 'Diabète'],
      description: 'Spécialiste en médecine interne avec expertise dans la gestion des maladies chroniques, notamment le diabète et l\'hypertension.',
      education: [
        'Doctorat en Médecine - Faculté de Médecine de Monastir (2012)',
        'Spécialisation en Médecine Interne - CHU Monastir (2012-2016)',
      ],
      certifications: [
        'Certification en Diabétologie',
        'Formation en Gestion des Maladies Chroniques',
        'Certification en Hypertension Artérielle',
      ],
      reviews: [
        DoctorReview(
          patientName: 'Nadia T.',
          rating: 4.5,
          comment: 'Très bon suivi pour mon diabète. Médecin compétent et disponible.',
          date: 'Il y a 2 semaines',
        ),
        DoctorReview(
          patientName: 'Ali R.',
          rating: 5.0,
          comment: 'Excellent médecin, très à l\'écoute et professionnel.',
          date: 'Il y a 1 mois',
        ),
      ],
      phoneNumber: '+216 55 789 123',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startDoctorDiscovery();
    
    // Send test notification to verify notifications work
    Future.delayed(const Duration(seconds: 2), () {
      NotificationService().showTestNotification();
    });
  }

  @override
  void dispose() {
    for (var timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }

  void _startDoctorDiscovery() {
    // Phase 1: Searching (2 seconds)
    _timers.add(Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }));

    // Phase 2: Doctors appear one by one
    for (int i = 0; i < _mockDoctors.length; i++) {
      final doctor = _mockDoctors[i];
      final appearDelay = 2500 + (i * 1500);

      _timers.add(Timer(Duration(milliseconds: appearDelay), () {
        if (mounted) {
          setState(() {
            doctor.status = 'checking';
            _visibleDoctors.add(doctor);
          });

          // Change to 'viewing' after 1-2 seconds
          _timers.add(Timer(Duration(milliseconds: 1000 + (i * 200)), () {
            if (mounted) {
              setState(() {
                doctor.status = 'viewing';
              });
            }
          }));

          // Change to 'ready' after another 1-2 seconds
          _timers.add(Timer(Duration(milliseconds: 2500 + (i * 300)), () {
            if (mounted) {
              setState(() {
                doctor.status = 'ready';
              });
              
              // Send notification when all 3 doctors are ready
              final readyDoctors = _visibleDoctors.where((d) => d.status == 'ready').length;
              if (readyDoctors == 3) {
                NotificationService().showDoctorsFoundNotification();
              }
            }
          }));
        }
      }));
    }
  }

  void _handleConfirmDoctor(Doctor doctor) {
    Navigator.pushNamed(
      context,
      '/doctor-arriving',
      arguments: {
        ...widget.emergencyData,
        'doctor': doctor,
      },
    );
  }

  void _showDoctorDetails(Doctor doctor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Doctor Header
                    Row(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1FBF9A).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF1FBF9A),
                              width: 3,
                            ),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Color(0xFF1FBF9A),
                            size: 40,
                          ),
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
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF1A202C),
                                      ),
                                    ),
                                  ),
                                  if (doctor.verified)
                                    const Icon(
                                      Icons.verified,
                                      color: Color(0xFF1FBF9A),
                                      size: 24,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                doctor.specialty,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF667085),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  ...List.generate(5, (index) {
                                    return Icon(
                                      index < doctor.rating.floor()
                                          ? Icons.star
                                          : Icons.star_border,
                                      color: const Color(0xFFFFA500),
                                      size: 16,
                                    );
                                  }),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${doctor.rating} (${doctor.reviewCount} avis)',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1A202C),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 24),
                    
                    // Quick Info Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickInfoCard(
                            Icons.location_on,
                            '${doctor.distance} km',
                            'Distance',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildQuickInfoCard(
                            Icons.access_time,
                            '${doctor.eta} min',
                            'Arrivée',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildQuickInfoCard(
                            Icons.payments,
                            '${doctor.price} TND',
                            'Tarif',
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // About Section
                    _buildSectionTitle('À Propos', Icons.info_outline),
                    const SizedBox(height: 12),
                    Text(
                      doctor.description,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        height: 1.6,
                        color: const Color(0xFF667085),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Education Section
                    _buildSectionTitle('Formation Médicale', Icons.school),
                    const SizedBox(height: 12),
                    ...doctor.education.map((edu) => _buildListItem(edu)),
                    
                    const SizedBox(height: 24),
                    
                    // Certifications Section
                    _buildSectionTitle('Certifications', Icons.workspace_premium),
                    const SizedBox(height: 12),
                    ...doctor.certifications.map((cert) => _buildListItem(cert)),
                    
                    const SizedBox(height: 24),
                    
                    // Skills
                    _buildSectionTitle('Compétences', Icons.medical_services),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: doctor.tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6BE3B2).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF1FBF9A).withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            tag,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0F6F73),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Reviews Section
                    _buildSectionTitle('Avis des Patients', Icons.rate_review),
                    const SizedBox(height: 12),
                    ...doctor.reviews.map((review) => _buildReviewCard(review)),
                    
                    const SizedBox(height: 32),
                    
                    // Confirm Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          if (doctor.status == 'ready') {
                            _handleConfirmDoctor(doctor);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1FBF9A),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          doctor.status == 'ready' ? 'Confirmer ce Médecin' : 'En attente...',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildQuickInfoCard(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF1FBF9A), size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A202C),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: const Color(0xFF667085),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF1FBF9A), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A202C),
          ),
        ),
      ],
    );
  }
  
  Widget _buildListItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF1FBF9A),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                height: 1.5,
                color: const Color(0xFF667085),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildReviewCard(DoctorReview review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(12),
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
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    review.patientName[0],
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
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
                      review.patientName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A202C),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          return Icon(
                            index < review.rating.floor()
                                ? Icons.star
                                : Icons.star_border,
                            color: const Color(0xFFFFA500),
                            size: 14,
                          );
                        }),
                        const SizedBox(width: 8),
                        Text(
                          review.date,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: const Color(0xFF667085),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review.comment,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              height: 1.5,
              color: const Color(0xFF667085),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
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
            child: Icon(
              icon,
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
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A202C),
                  ),
                ),
              ],
            ),
          ),
        ],
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
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A202C)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Sélection du Médecin',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A202C),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            ..._visibleDoctors.map((doctor) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildDoctorCard(doctor),
            )),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _isSearching
          ? Column(
              key: const ValueKey('searching'),
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1FBF9A).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.people,
                        color: Color(0xFF1FBF9A),
                        size: 40,
                      ),
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            const Color(0xFF1FBF9A).withOpacity(0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Recherche de médecins disponibles...',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A202C),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Recherche de médecins près de vous',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: const Color(0xFF667085),
                  ),
                ),
              ],
            )
          : Column(
              key: const ValueKey('found'),
              children: [
                Text(
                  '${_visibleDoctors.length} ${_visibleDoctors.length == 1 ? "médecin examine" : "médecins examinent"} votre demande',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A202C),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Choisissez votre médecin préféré',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: const Color(0xFF667085),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDoctorCard(Doctor doctor) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 500),
      opacity: 1.0,
      child: Container(
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
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1FBF9A).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF1FBF9A),
                            width: 3,
                          ),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Color(0xFF1FBF9A),
                          size: 40,
                        ),
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
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF1A202C),
                                    ),
                                  ),
                                ),
                                if (doctor.verified)
                                  const Icon(
                                    Icons.verified,
                                    color: Color(0xFF1FBF9A),
                                    size: 20,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              doctor.specialty,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: const Color(0xFF667085),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                ...List.generate(5, (index) {
                                  return Icon(
                                    index < doctor.rating.floor()
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: const Color(0xFFFFA500),
                                    size: 14,
                                  );
                                }),
                                const SizedBox(width: 4),
                                Text(
                                  '${doctor.rating}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1A202C),
                                  ),
                                ),
                                Text(
                                  ' (${doctor.reviewCount})',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: const Color(0xFF667085),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${doctor.price} TND',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1A202C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: doctor.tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6BE3B2).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          tag,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F6F73),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Color(0xFF667085)),
                      const SizedBox(width: 4),
                      Text(
                        '${doctor.distance} km',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: const Color(0xFF667085),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.access_time, size: 16, color: Color(0xFF0F6F73)),
                      const SizedBox(width: 4),
                      Text(
                        'Arrive en ${doctor.eta} min',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F6F73),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildStatusBadgeInline(doctor.status),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF1FBF9A).withOpacity(0.1),
                                const Color(0xFF6BE3B2).withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF1FBF9A),
                              width: 1.5,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _showDoctorDetails(doctor),
                              borderRadius: BorderRadius.circular(12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    size: 20,
                                    color: Color(0xFF1FBF9A),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Détails',
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
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: doctor.status == 'ready'
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF1FBF9A),
                                      Color(0xFF0F6F73),
                                    ],
                                  )
                                : null,
                            color: doctor.status != 'ready' ? const Color(0xFFE2E8F0) : null,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: doctor.status == 'ready'
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF1FBF9A).withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: doctor.status == 'ready'
                                  ? () => _handleConfirmDoctor(doctor)
                                  : null,
                              borderRadius: BorderRadius.circular(12),
                              child: Center(
                                child: Text(
                                  doctor.status == 'ready' ? 'Confirmer' : 'Patienter...',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: doctor.status == 'ready'
                                        ? Colors.white
                                        : const Color(0xFF9CA3AF),
                                  ),
                                ),
                              ),
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
      ),
    );
  }

  Widget _buildStatusBadgeInline(String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'checking':
        bgColor = const Color(0xFFFFA500).withOpacity(0.1);
        textColor = const Color(0xFFFFA500);
        label = 'Vérification en cours...';
        break;
      case 'viewing':
        bgColor = const Color(0xFF3B82F6).withOpacity(0.1);
        textColor = const Color(0xFF3B82F6);
        label = 'Consultation de votre demande...';
        break;
      case 'ready':
        bgColor = const Color(0xFF10B981).withOpacity(0.1);
        textColor = const Color(0xFF10B981);
        label = '✓ Prêt à accepter votre demande';
        break;
      default:
        bgColor = const Color(0xFFE2E8F0);
        textColor = const Color(0xFF667085);
        label = 'En attente';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: textColor.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status != 'ready')
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(textColor),
              ),
            ),
          if (status == 'ready')
            Icon(Icons.check_circle, color: textColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    IconData icon;
    String label;

    switch (status) {
      case 'checking':
        bgColor = const Color(0xFFFFA500).withOpacity(0.1);
        textColor = const Color(0xFFFFA500);
        icon = Icons.hourglass_empty;
        label = 'Vérification...';
        break;
      case 'viewing':
        bgColor = const Color(0xFF3B82F6).withOpacity(0.1);
        textColor = const Color(0xFF3B82F6);
        icon = Icons.visibility;
        label = 'Consultation...';
        break;
      default:
        bgColor = const Color(0xFFE2E8F0);
        textColor = const Color(0xFF667085);
        icon = Icons.info;
        label = 'En attente';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: textColor.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(textColor),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
