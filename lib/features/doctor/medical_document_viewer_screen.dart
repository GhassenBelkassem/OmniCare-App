import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MedicalDocumentViewerScreen extends StatelessWidget {
  final Map<String, dynamic> document;

  const MedicalDocumentViewerScreen({
    super.key,
    required this.document,
  });

  @override
  Widget build(BuildContext context) {
    final String docType = document['type'] ?? 'report';
    
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
          document['name'] ?? 'Medical Document',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1D2939),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Color(0xFF1FBF9A)),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Share functionality coming soon',
                    style: GoogleFonts.plusJakartaSans(),
                  ),
                  backgroundColor: const Color(0xFF1FBF9A),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Document Info Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1FBF9A), Color(0xFF0F6F73)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getDocumentIcon(docType),
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              document['name'] ?? 'Document',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              _getDocumentTypeLabel(docType),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        document['date'] ?? 'Date unknown',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.person, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          document['uploadedBy'] ?? 'Unknown',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Document Preview/Content
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.description, color: Color(0xFF1FBF9A), size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Document Preview',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1D2939),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Simulated document content based on type
                  _buildDocumentContent(docType),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Document metadata
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFF1FBF9A), size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Document Information',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1D2939),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('Type', _getDocumentTypeLabel(docType)),
                  _buildInfoRow('Date', document['date'] ?? 'N/A'),
                  _buildInfoRow('Uploaded by', document['uploadedBy'] ?? 'N/A'),
                  _buildInfoRow('Status', 'Verified'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getDocumentIcon(String type) {
    switch (type) {
      case 'blood-test':
        return Icons.bloodtype;
      case 'scan':
        return Icons.medical_information;
      case 'report':
        return Icons.assignment;
      default:
        return Icons.description;
    }
  }

  String _getDocumentTypeLabel(String type) {
    switch (type) {
      case 'blood-test':
        return 'Blood Test Results';
      case 'scan':
        return 'Medical Scan';
      case 'report':
        return 'Medical Report';
      default:
        return 'Document';
    }
  }

  Widget _buildDocumentContent(String type) {
    switch (type) {
      case 'blood-test':
        return _buildBloodTestContent();
      case 'scan':
        return _buildScanContent();
      case 'report':
        return _buildReportContent();
      default:
        return _buildGenericContent();
    }
  }

  Widget _buildBloodTestContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Complete Blood Count (CBC)',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1D2939),
          ),
        ),
        const SizedBox(height: 16),
        // Document image/PDF preview
        Container(
          height: 400,
          decoration: BoxDecoration(
            color: const Color(0xFFF4F5F7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD0D5DD)),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.description, size: 80, color: Color(0xFF667085)),
                const SizedBox(height: 16),
                Text(
                  'Blood Test Results Document',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'PDF/Image preview would appear here',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: const Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1FBF9A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF1FBF9A)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.zoom_in, color: Color(0xFF1FBF9A), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Tap to view full document',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1FBF9A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF8FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF0F6F73).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF0F6F73), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Original document uploaded by ${document['uploadedBy']}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: const Color(0xFF0F6F73),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScanContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: const Color(0xFFF4F5F7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD0D5DD)),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.medical_information, size: 60, color: Color(0xFF667085)),
                const SizedBox(height: 12),
                Text(
                  'Brain Scan Image',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF667085),
                  ),
                ),
                Text(
                  '(Image preview would appear here)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Radiologist Report:',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1D2939),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Brain MRI scan shows no abnormalities. No evidence of acute infarction, hemorrhage, or mass effect. Ventricles and sulci are normal in size and configuration. No midline shift detected.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: const Color(0xFF1D2939),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildReportContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Electrocardiogram (ECG) Report',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1D2939),
          ),
        ),
        const SizedBox(height: 16),
        _buildReportSection('Heart Rate', '72 bpm'),
        _buildReportSection('Rhythm', 'Normal sinus rhythm'),
        _buildReportSection('PR Interval', '160 ms'),
        _buildReportSection('QRS Duration', '90 ms'),
        _buildReportSection('QT/QTc', '400/420 ms'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF8FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF0F6F73).withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Interpretation:',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1D2939),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Normal ECG. No evidence of ischemia, arrhythmia, or conduction abnormalities.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
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

  Widget _buildGenericContent() {
    return Text(
      'Document content preview not available. This is a placeholder for the actual document content.',
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        color: const Color(0xFF667085),
      ),
    );
  }

  Widget _buildTestResult(String name, String value, String status, bool isNormal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1D2939),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: const Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isNormal 
                ? const Color(0xFF1FBF9A).withOpacity(0.1)
                : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isNormal ? const Color(0xFF1FBF9A) : Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportSection(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF667085),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1D2939),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF667085),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1D2939),
            ),
          ),
        ],
      ),
    );
  }
}
