import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DocumentViewerScreen extends StatelessWidget {
  final String documentName;
  final String documentDate;
  final String documentType;

  const DocumentViewerScreen({
    super.key,
    required this.documentName,
    required this.documentDate,
    required this.documentType,
  });

  Color _getDocumentColor() {
    switch (documentType) {
      case 'blood-test':
        return const Color(0xFFDC2626);
      case 'xray':
      case 'scan':
        return const Color(0xFF8B5CF6);
      case 'prescription':
        return const Color(0xFF1FBF9A);
      default:
        return const Color(0xFF667085);
    }
  }

  IconData _getDocumentIcon() {
    switch (documentType) {
      case 'blood-test':
        return Icons.bloodtype;
      case 'xray':
      case 'scan':
        return Icons.medical_services;
      case 'prescription':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    final docColor = _getDocumentColor();
    final docIcon = _getDocumentIcon();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A202C)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Document Médical',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A202C),
              ),
            ),
            Text(
              documentDate,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: const Color(0xFF667085),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Color(0xFF1FBF9A)),
            onPressed: () {
              // Share functionality
            },
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Color(0xFF1FBF9A)),
            onPressed: () {
              // Download functionality
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Document Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: const Color(0xFFE2E8F0)),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: docColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(docIcon, size: 40, color: docColor),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    documentName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1A202C),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: docColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: docColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      _getDocumentTypeLabel(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: docColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Document Preview/Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 400),
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.insert_drive_file_outlined,
                      size: 80,
                      color: docColor.withOpacity(0.3),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Aperçu du Document',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A202C),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'Le document médical sera affiché ici. Cette fonctionnalité nécessite l\'intégration avec un système de stockage de documents.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: const Color(0xFF667085),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Document Info
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F5F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _buildInfoRow('Type', _getDocumentTypeLabel()),
                          const SizedBox(height: 12),
                          _buildInfoRow('Date', documentDate),
                          const SizedBox(height: 12),
                          _buildInfoRow('Format', 'PDF / Image'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // Print functionality
                      },
                      icon: const Icon(Icons.print, size: 20),
                      label: Text(
                        'Imprimer',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1FBF9A),
                        side: const BorderSide(
                          color: Color(0xFF1FBF9A),
                          width: 2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Open in external viewer
                      },
                      icon: const Icon(Icons.open_in_new, size: 20),
                      label: Text(
                        'Ouvrir',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1FBF9A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
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
    );
  }

  String _getDocumentTypeLabel() {
    switch (documentType) {
      case 'blood-test':
        return 'Analyse de Sang';
      case 'xray':
        return 'Radiographie';
      case 'scan':
        return 'Scanner / IRM';
      case 'prescription':
        return 'Ordonnance';
      case 'report':
        return 'Rapport Médical';
      default:
        return 'Autre';
    }
  }
}
