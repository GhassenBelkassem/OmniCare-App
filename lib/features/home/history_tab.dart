import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'consultation_detail_screen.dart';

class Consultation {
  final String id;
  final String date;
  final String time;
  final String doctorName;
  final String specialty;
  final String patientName;
  final String reason;
  final String location;
  final String status;
  final List<String>? medications;
  final String? diagnosis;
  final String cost;

  Consultation({
    required this.id,
    required this.date,
    required this.time,
    required this.doctorName,
    required this.specialty,
    required this.patientName,
    required this.reason,
    required this.location,
    required this.status,
    this.medications,
    this.diagnosis,
    required this.cost,
  });
}

class HistoryTab extends StatefulWidget {
  const HistoryTab({Key? key}) : super(key: key);

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  String _searchQuery = '';
  String _selectedMonth = 'all';

  final List<Consultation> _consultations = [
    Consultation(
      id: '1',
      date: '2026-02-12',
      time: '14:30',
      doctorName: 'Dr. Karim Mansour',
      specialty: 'Médecin Généraliste',
      patientName: 'Sarah Ben Ahmed',
      reason: 'Contrôle de routine',
      location: 'Tunis, La Marsa',
      status: 'completed',
      medications: ['Paracétamol 500mg', 'Vitamine D 1000 UI'],
      diagnosis: 'Bilan de santé normal. Légère carence en vitamine D.',
      cost: '80 TND',
    ),
    Consultation(
      id: '2',
      date: '2026-02-08',
      time: '10:15',
      doctorName: 'Dr. Salma Gharbi',
      specialty: 'Pédiatre',
      patientName: 'Youssef Ben Ahmed',
      reason: 'Fièvre et toux',
      location: 'Tunis, Centre Ville',
      status: 'completed',
      medications: ['Doliprane Enfant 100mg', 'Sirop antitussif', 'Probiotiques'],
      diagnosis: 'Infection virale bénigne. Repos recommandé pendant 3 jours.',
      cost: '70 TND',
    ),
    Consultation(
      id: '3',
      date: '2026-02-05',
      time: '16:00',
      doctorName: 'Dr. Ahmed Trabelsi',
      specialty: 'Cardiologue',
      patientName: 'Mohamed Ben Ahmed',
      reason: 'Hypertension - Suivi',
      location: 'Tunis, Menzah',
      status: 'completed',
      medications: ['Lisinopril 10mg', 'Aspirine 81mg'],
      diagnosis: 'Tension artérielle bien contrôlée. Continuer le traitement actuel.',
      cost: '100 TND',
    ),
    Consultation(
      id: '4',
      date: '2026-01-28',
      time: '11:30',
      doctorName: 'Dr. Leila Ben Ali',
      specialty: 'Dermatologue',
      patientName: 'Amira Ben Ahmed',
      reason: 'Éruption cutanée',
      location: 'Ariana, Centre Ville',
      status: 'completed',
      medications: ['Crème hydrocortisone 1%', 'Lotion hydratante'],
      diagnosis: 'Eczéma atopique léger. Application de crème 2x/jour.',
      cost: '90 TND',
    ),
    Consultation(
      id: '5',
      date: '2026-01-22',
      time: '09:00',
      doctorName: 'Dr. Mehdi Khelifi',
      specialty: 'Médecin Généraliste',
      patientName: 'Fatma Ben Salem',
      reason: 'Grippe',
      location: 'Tunis, El Menzah',
      status: 'completed',
      medications: ['Paracétamol 1g', 'Vitamine C 500mg', 'Repos complet'],
      diagnosis: 'Syndrome grippal. Hydratation et repos pendant 5 jours.',
      cost: '75 TND',
    ),
    Consultation(
      id: '6',
      date: '2026-01-15',
      time: '15:45',
      doctorName: 'Dr. Karim Mansour',
      specialty: 'Médecin Généraliste',
      patientName: 'Sarah Ben Ahmed',
      reason: 'Vaccination',
      location: 'Tunis, La Marsa',
      status: 'completed',
      medications: ['Vaccin Grippe 2026'],
      diagnosis: 'Vaccination antigrippale administrée avec succès.',
      cost: '50 TND',
    ),
    Consultation(
      id: '7',
      date: '2026-01-10',
      time: '14:00',
      doctorName: 'Dr. Nadia Hamdi',
      specialty: 'Gynécologue',
      patientName: 'Sarah Ben Ahmed',
      reason: 'Consultation annuelle',
      location: 'Tunis, Lac 2',
      status: 'cancelled',
      cost: '0 TND',
    ),
  ];

  List<Consultation> get _filteredConsultations {
    return _consultations.where((consultation) {
      final matchesSearch = consultation.doctorName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          consultation.specialty.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          consultation.patientName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          consultation.reason.toLowerCase().contains(_searchQuery.toLowerCase());

      final consultationDate = DateTime.parse(consultation.date);
      final now = DateTime.now();
      
      bool matchesMonth = true;
      if (_selectedMonth == 'current') {
        matchesMonth = consultationDate.month == now.month && consultationDate.year == now.year;
      } else if (_selectedMonth == 'last') {
        final lastMonth = DateTime(now.year, now.month - 1);
        matchesMonth = consultationDate.month == lastMonth.month && consultationDate.year == lastMonth.year;
      }

      return matchesSearch && matchesMonth;
    }).toList();
  }

  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    final months = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
    final days = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
    
    final weekday = days[date.weekday - 1];
    final day = date.day;
    final month = months[date.month - 1];
    final year = date.year;
    
    return '${weekday.substring(0, 1).toUpperCase()}${weekday.substring(1)} $day $month $year';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildSearchBar(),
          const SizedBox(height: 16),
          _buildMonthFilters(),
          const SizedBox(height: 20),
          _buildResultsCount(),
          const SizedBox(height: 16),
          _buildConsultationsList(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Historique Médical',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A202C),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Toutes vos consultations passées',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: const Color(0xFF667085),
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1FBF9A), Color(0xFF0F6F73)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ElevatedButton.icon(
            onPressed: () {
              // Share medical history
            },
            icon: const Icon(Icons.qr_code, size: 18),
            label: Text(
              'Partager',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      decoration: InputDecoration(
        hintText: 'Rechercher une consultation...',
        hintStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: const Color(0xFF667085),
        ),
        prefixIcon: const Icon(Icons.search, color: Color(0xFF667085)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1FBF9A), width: 2),
        ),
      ),
      style: GoogleFonts.plusJakartaSans(fontSize: 14),
    );
  }

  Widget _buildMonthFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('Tous', 'all'),
          const SizedBox(width: 8),
          _buildFilterChip('Ce mois', 'current'),
          const SizedBox(width: 8),
          _buildFilterChip('Mois dernier', 'last'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedMonth == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMonth = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1FBF9A) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF1FBF9A) : const Color(0xFFE2E8F0),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1FBF9A).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF1A202C),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsCount() {
    return Row(
      children: [
        const Icon(Icons.description, color: Color(0xFF1FBF9A), size: 20),
        const SizedBox(width: 8),
        Text(
          '${_filteredConsultations.length} consultation${_filteredConsultations.length != 1 ? 's' : ''}',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A202C),
          ),
        ),
      ],
    );
  }

  Widget _buildConsultationsList() {
    if (_filteredConsultations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.description_outlined,
                size: 64,
                color: const Color(0xFF667085).withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Aucune consultation trouvée',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A202C),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Essayez de modifier vos filtres',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: const Color(0xFF667085),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _filteredConsultations.map((consultation) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: _buildConsultationCard(consultation),
        );
      }).toList(),
    );
  }

  Widget _buildConsultationCard(Consultation consultation) {
    final isCompleted = consultation.status == 'completed';
    
    return GestureDetector(
      onTap: () {
        // Navigate to consultation detail
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConsultationDetailScreen(consultation: consultation),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isCompleted ? Colors.white : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isCompleted ? const Color(0xFFE2E8F0) : const Color(0xFFFECACA),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConsultationHeader(consultation),
            const SizedBox(height: 16),
            _buildDoctorPatientInfo(consultation),
            const SizedBox(height: 16),
            _buildReasonLocation(consultation),
            if (isCompleted && consultation.diagnosis != null) ...[
              const SizedBox(height: 16),
              _buildDiagnosis(consultation.diagnosis!),
            ],
            if (isCompleted && consultation.medications != null && consultation.medications!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildMedications(consultation.medications!),
            ],
            const SizedBox(height: 16),
            _buildFooter(consultation),
          ],
        ),
      ),
    );
  }

  Widget _buildConsultationHeader(Consultation consultation) {
    final isCompleted = consultation.status == 'completed';
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isCompleted ? const Color(0xFF1FBF9A).withOpacity(0.1) : const Color(0xFFFECACA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.calendar_today,
            color: isCompleted ? const Color(0xFF1FBF9A) : const Color(0xFFDC2626),
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatDate(consultation.date),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A202C),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: Color(0xFF667085)),
                  const SizedBox(width: 4),
                  Text(
                    consultation.time,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: const Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isCompleted ? const Color(0xFF10B981).withOpacity(0.1) : const Color(0xFFFECACA),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isCompleted ? Icons.check_circle : Icons.cancel,
                size: 14,
                color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFDC2626),
              ),
              const SizedBox(width: 4),
              Text(
                isCompleted ? 'Terminée' : 'Annulée',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isCompleted ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDoctorPatientInfo(Consultation consultation) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF1FBF9A).withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF1FBF9A).withOpacity(0.3), width: 2),
                ),
                child: const Icon(Icons.person, color: Color(0xFF1FBF9A), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      consultation.doctorName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A202C),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      consultation.specialty,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFF667085),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F6F73).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_outline, color: Color(0xFF0F6F73), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Patient',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFF667085),
                      ),
                    ),
                    Text(
                      consultation.patientName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A202C),
                      ),
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

  Widget _buildReasonLocation(Consultation consultation) {
    return Column(
      children: [
        Row(
          children: [
            const Icon(Icons.description, color: Color(0xFF1FBF9A), size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Motif',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: const Color(0xFF667085),
                    ),
                  ),
                  Text(
                    consultation.reason,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A202C),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.location_on, color: Color(0xFF1FBF9A), size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lieu',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: const Color(0xFF667085),
                    ),
                  ),
                  Text(
                    consultation.location,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A202C),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDiagnosis(String diagnosis) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1FBF9A).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DIAGNOSTIC',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1FBF9A),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            diagnosis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: const Color(0xFF1A202C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedications(List<String> medications) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.medication, color: Color(0xFF0F6F73), size: 16),
            const SizedBox(width: 8),
            Text(
              'MÉDICAMENTS PRESCRITS',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF667085),
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: medications.map((med) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0F6F73).withOpacity(0.1),
                border: Border.all(color: const Color(0xFF0F6F73).withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                med,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F6F73),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFooter(Consultation consultation) {
    return Container(
      padding: const EdgeInsets.only(top: 16),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Coût total',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: const Color(0xFF667085),
                ),
              ),
              Text(
                consultation.cost,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1FBF9A),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                'Voir détails',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1FBF9A),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Color(0xFF1FBF9A), size: 20),
            ],
          ),
        ],
      ),
    );
  }
}
