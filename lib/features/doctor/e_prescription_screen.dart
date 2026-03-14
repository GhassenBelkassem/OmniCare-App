import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:math';

class EPrescriptionScreen extends StatefulWidget {
  final Map<String, dynamic> patientData;

  const EPrescriptionScreen({
    super.key,
    required this.patientData,
  });

  @override
  State<EPrescriptionScreen> createState() => _EPrescriptionScreenState();
}

class _EPrescriptionScreenState extends State<EPrescriptionScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final List<Map<String, dynamic>> _prescribedMedications = [];
  List<Map<String, dynamic>> _filteredMedications = [];
  bool _showSuggestions = false;

  // Mock medication database
  final List<Map<String, dynamic>> _medicationDatabase = [
    {'name': 'Paracétamol', 'commonDosage': '500mg', 'type': 'Analgesic'},
    {'name': 'Ibuprofène', 'commonDosage': '400mg', 'type': 'Anti-inflammatory'},
    {'name': 'Amoxicilline', 'commonDosage': '500mg', 'type': 'Antibiotic'},
    {'name': 'Azithromycine', 'commonDosage': '250mg', 'type': 'Antibiotic'},
    {'name': 'Oméprazole', 'commonDosage': '20mg', 'type': 'Antacid'},
    {'name': 'Loratadine', 'commonDosage': '10mg', 'type': 'Antihistamine'},
    {'name': 'Cétirizine', 'commonDosage': '10mg', 'type': 'Antihistamine'},
    {'name': 'Metformine', 'commonDosage': '500mg', 'type': 'Antidiabetic'},
    {'name': 'Aspirine', 'commonDosage': '100mg', 'type': 'Antiplatelet'},
    {'name': 'Atorvastatine', 'commonDosage': '10mg', 'type': 'Statin'},
  ];

  // Quick templates
  final List<Map<String, dynamic>> _templates = [
    {
      'name': 'Rhume',
      'icon': Icons.ac_unit,
      'medications': [
        {'name': 'Paracétamol', 'dosage': '500mg', 'frequency': '3x/jour', 'duration': '5 jours'},
        {'name': 'Cétirizine', 'dosage': '10mg', 'frequency': '1x/jour', 'duration': '5 jours'},
      ],
    },
    {
      'name': 'Mal de tête',
      'icon': Icons.psychology,
      'medications': [
        {'name': 'Ibuprofène', 'dosage': '400mg', 'frequency': '2x/jour', 'duration': '3 jours'},
      ],
    },
    {
      'name': 'Fièvre',
      'icon': Icons.thermostat,
      'medications': [
        {'name': 'Paracétamol', 'dosage': '1g', 'frequency': '3x/jour', 'duration': '3 jours'},
      ],
    },
    {
      'name': 'Infection',
      'icon': Icons.coronavirus,
      'medications': [
        {'name': 'Amoxicilline', 'dosage': '500mg', 'frequency': '3x/jour', 'duration': '7 jours'},
      ],
    },
  ];

  void _searchMedications(String query) {
    if (query.isEmpty) {
      setState(() {
        _showSuggestions = false;
        _filteredMedications = [];
      });
      return;
    }

    setState(() {
      _showSuggestions = true;
      _filteredMedications = _medicationDatabase
          .where((med) => med['name'].toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _addMedication(String name, String dosage) {
    setState(() {
      _prescribedMedications.add({
        'name': name,
        'dosage': dosage,
        'frequency': '2x/jour',
        'duration': '5 jours',
      });
      _searchController.clear();
      _showSuggestions = false;
    });
  }

  void _applyTemplate(Map<String, dynamic> template) {
    setState(() {
      _prescribedMedications.clear();
      _prescribedMedications.addAll(List<Map<String, dynamic>>.from(template['medications']));
    });
  }

  void _removeMedication(int index) {
    setState(() {
      _prescribedMedications.removeAt(index);
    });
  }

  void _updateMedication(int index, String field, String value) {
    setState(() {
      _prescribedMedications[index][field] = value;
    });
  }

  void _generatePrescription() {
    if (_prescribedMedications.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Veuillez ajouter au moins un médicament',
            style: GoogleFonts.plusJakartaSans(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Generate unique QR code for this prescription (one-time use)
    final prescriptionId = 'RX-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrescriptionPDFScreen(
          patientData: widget.patientData,
          medications: _prescribedMedications,
          notes: _notesController.text,
          prescriptionId: prescriptionId,
          onComplete: () {
            // Save to consultation history and end consultation
            _completeConsultation();
          },
        ),
      ),
    );
  }

  void _completeConsultation() {
    // Show success dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              const SizedBox(height: 20),
              Text(
                'Consultation terminée',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1D2939),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'L\'ordonnance a été générée et ajoutée à l\'historique du patient.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: const Color(0xFF667085),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Close PDF screen
                    Navigator.pop(context); // Close e-prescription screen
                    Navigator.pop(context); // Close medical passport
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1FBF9A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Retour au tableau de bord',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
          icon: const Icon(Icons.close, color: Color(0xFF1D2939)),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text(
                  'Terminer la consultation?',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                content: Text(
                  'Voulez-vous terminer cette consultation sans créer d\'ordonnance?',
                  style: GoogleFonts.plusJakartaSans(),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Annuler',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF667085),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      Navigator.pop(context); // Close e-prescription screen
                      Navigator.pop(context); // Close medical passport
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1FBF9A),
                    ),
                    child: Text(
                      'Terminer',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        title: Text(
          'E-Ordonnance',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1D2939),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Patient info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1FBF9A), Color(0xFF0F6F73)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.person, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.patientData['name'] ?? 'Patient',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1D2939),
                                ),
                              ),
                              Text(
                                '${widget.patientData['age']} ans • ${widget.patientData['bloodType']}',
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
                  ),
                  const SizedBox(height: 20),

                  // Quick templates
                  Text(
                    'Modèles rapides',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1D2939),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _templates.map((template) => GestureDetector(
                      onTap: () => _applyTemplate(template),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF1FBF9A)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(template['icon'], size: 18, color: const Color(0xFF1FBF9A)),
                            const SizedBox(width: 8),
                            Text(
                              template['name'],
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1FBF9A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Search medications
                  Text(
                    'Rechercher médicament',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1D2939),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    onChanged: _searchMedications,
                    decoration: InputDecoration(
                      hintText: 'Tapez le nom du médicament...',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF667085),
                      ),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF667085)),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF1FBF9A)),
                      ),
                    ),
                  ),
                  
                  // Suggestions
                  if (_showSuggestions && _filteredMedications.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredMedications.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final med = _filteredMedications[index];
                          return ListTile(
                            title: Text(
                              med['name'],
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${med['type']} • ${med['commonDosage']}',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: const Color(0xFF667085),
                              ),
                            ),
                            onTap: () => _addMedication(med['name'], med['commonDosage']),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Prescribed medications
                  if (_prescribedMedications.isNotEmpty) ...[
                    Text(
                      'Médicaments prescrits (${_prescribedMedications.length})',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1D2939),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._prescribedMedications.asMap().entries.map((entry) {
                      final index = entry.key;
                      final med = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  med['name'],
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF1D2939),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                  onPressed: () => _removeMedication(index),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildQuickField(
                                    'Dosage',
                                    med['dosage'],
                                    ['250mg', '500mg', '1g'],
                                    (value) => _updateMedication(index, 'dosage', value),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildQuickField(
                                    'Fréquence',
                                    med['frequency'],
                                    ['1x/jour', '2x/jour', '3x/jour'],
                                    (value) => _updateMedication(index, 'frequency', value),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildQuickField(
                              'Durée',
                              med['duration'],
                              ['3 jours', '5 jours', '7 jours', '14 jours'],
                              (value) => _updateMedication(index, 'duration', value),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 20),
                  ],

                  // Doctor notes
                  Text(
                    'Notes du médecin',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1D2939),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Instructions supplémentaires...',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFF667085),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF1FBF9A)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // Submit button
          Container(
            padding: const EdgeInsets.all(16),
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
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _generatePrescription,
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
                    'Générer l\'ordonnance',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickField(
    String label,
    String currentValue,
    List<String> options,
    Function(String) onChanged,
  ) {
    return Column(
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
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: options.map((option) => GestureDetector(
            onTap: () => onChanged(option),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: currentValue == option
                    ? const Color(0xFF1FBF9A)
                    : const Color(0xFFF4F5F7),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: currentValue == option
                      ? const Color(0xFF1FBF9A)
                      : const Color(0xFFD0D5DD),
                ),
              ),
              child: Text(
                option,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: currentValue == option
                      ? Colors.white
                      : const Color(0xFF667085),
                ),
              ),
            ),
          )).toList(),
        ),
      ],
    );
  }
}

// PDF Preview Screen
class PrescriptionPDFScreen extends StatelessWidget {
  final Map<String, dynamic> patientData;
  final List<Map<String, dynamic>> medications;
  final String notes;
  final String prescriptionId;
  final VoidCallback onComplete;

  const PrescriptionPDFScreen({
    super.key,
    required this.patientData,
    required this.medications,
    required this.notes,
    required this.prescriptionId,
    required this.onComplete,
  });

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
          'Ordonnance',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1D2939),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Color(0xFF1FBF9A)),
            onPressed: () {
              // Complete consultation and save to history
              onComplete();
            },
            tooltip: 'Terminer la consultation',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OmniCare',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1FBF9A),
                        ),
                      ),
                      Text(
                        'Ordonnance Médicale',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: const Color(0xFF667085),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    DateTime.now().toString().substring(0, 10),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: const Color(0xFF667085),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),

              // Patient info
              Text(
                'Patient',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF667085),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                patientData['name'] ?? 'N/A',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1D2939),
                ),
              ),
              Text(
                '${patientData['age']} ans • ${patientData['bloodType']}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: const Color(0xFF667085),
                ),
              ),
              const SizedBox(height: 24),

              // Medications
              Text(
                'Prescription',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1D2939),
                ),
              ),
              const SizedBox(height: 16),
              ...medications.asMap().entries.map((entry) {
                final index = entry.key;
                final med = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F5F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1FBF9A),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              med['name'],
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1D2939),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${med['dosage']} • ${med['frequency']} • ${med['duration']}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: const Color(0xFF667085),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),

              // Notes
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Instructions',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1D2939),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  notes,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: const Color(0xFF667085),
                    height: 1.5,
                  ),
                ),
              ],

              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 24),

              // QR Code signature
              Center(
                child: Column(
                  children: [
                    Text(
                      'Signature électronique du médecin',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1FBF9A)),
                      ),
                      child: QrImageView(
                        data: prescriptionId,
                        version: QrVersions.auto,
                        size: 150,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Color(0xFF0F6F73),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF1FBF9A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'ID: $prescriptionId',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1FBF9A).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified, color: Color(0xFF1FBF9A), size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'Usage unique',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
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
            ],
          ),
        ),
      ),
    );
  }
}
