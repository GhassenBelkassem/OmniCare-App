import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EmergencyReviewScreen extends StatelessWidget {
  final Map<String, dynamic> requestData;

  const EmergencyReviewScreen({
    super.key,
    required this.requestData,
  });

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
                  _buildTopImage(),
                  const SizedBox(height: 16),
                  _buildCompactInfo(),
                  const SizedBox(height: 16),
                  _buildImportantNotice(),
                ],
              ),
            ),
          ),
          _buildBottomBar(context),
        ],
      ),
    );
  }

  Widget _buildTopImage() {
    return Image.asset(
      'assets/images/Confirmed-bro.png',
      height: 280,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          height: 280,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1FBF9A).withOpacity(0.1),
                const Color(0xFF0F6F73).withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Icon(
              Icons.medical_services_rounded,
              size: 60,
              color: const Color(0xFF1FBF9A).withOpacity(0.5),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          Text(
            'Résumé de la Demande',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A202C),
            ),
          ),
          const SizedBox(height: 16),
          _buildCompactRow(
            Icons.person,
            const Color(0xFF1FBF9A),
            requestData['patientName'] ?? 'N/A',
            requestData['age'] != null ? '${requestData['age']} ans' : null,
          ),
          const SizedBox(height: 12),
          _buildCompactRow(
            Icons.phone,
            const Color(0xFF10B981),
            'Téléphone',
            requestData['phoneNumber'] ?? requestData['phone'] ?? 'Non fourni',
          ),
          const SizedBox(height: 12),
          if (requestData['bodyParts'] != null && (requestData['bodyParts'] as List).isNotEmpty)
            _buildCompactSymptoms(requestData['bodyParts'] as List),
          if (requestData['symptoms'] != null && requestData['symptoms'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildCompactRow(
              Icons.description,
              const Color(0xFF3B82F6),
              'Symptômes',
              requestData['symptoms'],
            ),
          ],
          const SizedBox(height: 12),
          _buildCompactRow(
            Icons.location_on,
            const Color(0xFFEF4444),
            'Localisation',
            requestData['address'] ?? 'GPS activé',
          ),
        ],
      ),
    );
  }

  Widget _buildCompactRow(IconData icon, Color color, String title, String? subtitle) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
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
                  color: const Color(0xFF1A202C),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: const Color(0xFF667085),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactSymptoms(List bodyParts) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.healing, color: Color(0xFF3B82F6), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: bodyParts.map((part) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1FBF9A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFF1FBF9A).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  part.toString(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F6F73),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1FBF9A), Color(0xFF0F6F73)],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.medical_services,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Résumé de la Demande',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Vérifiez vos informations',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildInfoSection(
                  'Patient',
                  Icons.person,
                  const Color(0xFF1FBF9A),
                  [
                    _buildInfoRow('Nom', requestData['patientName'] ?? 'N/A'),
                    if (requestData['age'] != null)
                      _buildInfoRow('Âge', '${requestData['age']} ans'),
                    if (requestData['relationship'] != null)
                      _buildInfoRow('Relation', requestData['relationship']),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 24),
                _buildInfoSection(
                  'Symptômes',
                  Icons.healing,
                  const Color(0xFF3B82F6),
                  [
                    if (requestData['bodyParts'] != null && (requestData['bodyParts'] as List).isNotEmpty)
                      _buildBodyPartsRow(requestData['bodyParts'] as List),
                    if (requestData['symptoms'] != null && requestData['symptoms'].toString().isNotEmpty)
                      _buildInfoRow('Description', requestData['symptoms']),
                    if (requestData['voiceMessage'] != null)
                      _buildVoiceMessageRow(),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 24),
                _buildInfoSection(
                  'Localisation',
                  Icons.location_on,
                  const Color(0xFFEF4444),
                  [
                    if (requestData['address'] != null)
                      _buildInfoRow('Adresse', requestData['address']),
                    if (requestData['location'] != null)
                      _buildInfoRow(
                        'Coordonnées GPS',
                        'Lat: ${requestData['location']['latitude'].toStringAsFixed(4)}, '
                        'Lng: ${requestData['location']['longitude'].toStringAsFixed(4)}',
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

  Widget _buildInfoSection(String title, IconData icon, Color color, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A202C),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF667085),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: const Color(0xFF1A202C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyPartsRow(List bodyParts) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Zones affectées',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF667085),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: bodyParts.map((part) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1FBF9A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF1FBF9A).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  part.toString(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F6F73),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceMessageRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.mic, color: Color(0xFF3B82F6), size: 18),
                const SizedBox(width: 8),
                Text(
                  'Message vocal enregistré',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF3B82F6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportantNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withOpacity(0.05),
        border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF3B82F6), size: 20),
              const SizedBox(width: 8),
              Text(
                'Ce qui se passe ensuite',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A202C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildNoticeItem('1', 'Recherche de médecins disponibles'),
          _buildNoticeItem('2', 'Sélection du médecin'),
          _buildNoticeItem('3', 'Le médecin se dirige vers vous'),
        ],
      ),
    );
  }

  Widget _buildNoticeItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF1FBF9A),
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
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: const Color(0xFF667085),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final consultationType = requestData['consultationType'] as String? ?? 'home';
    final isHomeConsultation = consultationType == 'home';
    final providerType = requestData['providerType'] as String? ?? 'doctor';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Toutes les informations sont correctes',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  if (isHomeConsultation) {
                    // Navigate to doctor selection for urgent home consultation
                    Navigator.pushNamed(
                      context,
                      '/doctor-selection',
                      arguments: requestData,
                    );
                  } else {
                    // Navigate to provider list for book appointment
                    Navigator.pushNamed(
                      context,
                      '/provider-list',
                      arguments: {'providerType': providerType},
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1FBF9A),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  shadowColor: const Color(0xFF1FBF9A).withOpacity(0.3),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isHomeConsultation ? Icons.search : Icons.calendar_today,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        isHomeConsultation 
                            ? 'Confirmer et Rechercher un Médecin'
                            : 'Rechercher des Professionnels',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
