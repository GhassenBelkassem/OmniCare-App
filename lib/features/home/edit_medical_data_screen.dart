import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Medication {
  String name;
  String dosage;
  String frequency;

  Medication({
    required this.name,
    required this.dosage,
    required this.frequency,
  });
}

class MedicalDocument {
  String id;
  String name;
  String type;
  String date;
  String fileUrl;

  MedicalDocument({
    required this.id,
    required this.name,
    required this.type,
    required this.date,
    required this.fileUrl,
  });
}

class EditMedicalDataScreen extends StatefulWidget {
  final String bloodType;
  final List<String> chronicConditions;
  final List<Medication> medications;
  final List<MedicalDocument> documents;
  final Function(String, List<String>, List<Medication>, List<MedicalDocument>) onSave;

  const EditMedicalDataScreen({
    Key? key,
    required this.bloodType,
    required this.chronicConditions,
    required this.medications,
    required this.documents,
    required this.onSave,
  }) : super(key: key);

  @override
  State<EditMedicalDataScreen> createState() => _EditMedicalDataScreenState();
}

class _EditMedicalDataScreenState extends State<EditMedicalDataScreen> {
  late String _bloodType;
  late List<String> _chronicConditions;
  late List<Medication> _medications;
  late List<MedicalDocument> _documents;

  final List<String> _bloodTypes = ['-', 'A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];
  final List<String> _availableConditions = [
    'Diabète Type 2',
    'Diabète Type 1',
    'Hypertension',
    'Asthme',
    'Allergie Pénicilline',
    'Maladie Cardiaque',
    'Cholestérol Élevé',
    'Arthrite',
    'Migraine',
    'Thyroïde',
  ];

  final List<Map<String, dynamic>> _documentTypes = [
    {'value': 'blood-test', 'label': 'Analyse de Sang'},
    {'value': 'xray', 'label': 'Radio / Radiographie'},
    {'value': 'scan', 'label': 'Scanner / IRM'},
    {'value': 'prescription', 'label': 'Ordonnance'},
    {'value': 'report', 'label': 'Rapport Médical'},
    {'value': 'other', 'label': 'Autre'},
  ];

  @override
  void initState() {
    super.initState();
    _bloodType = widget.bloodType;
    if (_bloodType.trim().isEmpty || !_bloodTypes.contains(_bloodType)) {
      _bloodType = '-';
    }
    _chronicConditions = List.from(widget.chronicConditions);
    _medications = List.from(widget.medications);
    _documents = List.from(widget.documents);
  }

  void _toggleCondition(String condition) {
    setState(() {
      if (_chronicConditions.contains(condition)) {
        _chronicConditions.remove(condition);
      } else {
        _chronicConditions.add(condition);
      }
    });
  }

  void _addMedication() {
    setState(() {
      _medications.add(Medication(name: '', dosage: '', frequency: ''));
    });
  }

  void _removeMedication(int index) {
    setState(() {
      _medications.removeAt(index);
    });
  }

  void _addDocument() {
    setState(() {
      _documents.add(MedicalDocument(
        id: 'doc-${DateTime.now().millisecondsSinceEpoch}',
        name: '',
        type: 'other',
        date: '',
        fileUrl: '',
      ));
    });
  }

  void _removeDocument(int index) {
    setState(() {
      _documents.removeAt(index);
    });
  }

  void _handleSave() {
    final validMedications = _medications.where((med) => med.name.trim().isNotEmpty).toList();
    widget.onSave(_bloodType, _chronicConditions, validMedications, _documents);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1A202C)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Modifier Mes Données Médicales',
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBloodTypeSection(),
                  const SizedBox(height: 24),
                  _buildChronicConditionsSection(),
                  const SizedBox(height: 24),
                  _buildMedicationsSection(),
                  const SizedBox(height: 24),
                  _buildDocumentsSection(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildBloodTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Groupe Sanguin *',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A202C),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonFormField<String>(
            value: _bloodTypes.contains(_bloodType) ? _bloodType : '-',
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: InputBorder.none,
            ),
            hint: Text(
              'Sélectionner',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: const Color(0xFF667085),
              ),
            ),
            items: _bloodTypes.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(
                  type,
                  style: GoogleFonts.plusJakartaSans(fontSize: 14),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _bloodType = (value == null || value.trim().isEmpty) ? '-' : value;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChronicConditionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Conditions Chroniques',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A202C),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Sélectionnez toutes les conditions applicables',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: const Color(0xFF667085),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableConditions.map((condition) {
            final isSelected = _chronicConditions.contains(condition);
            return GestureDetector(
              onTap: () => _toggleCondition(condition),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0F6F73) : const Color(0xFFF4F5F7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF0F6F73) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  condition,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF1A202C),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMedicationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Médicaments Actuels',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A202C),
              ),
            ),
            TextButton.icon(
              onPressed: _addMedication,
              icon: const Icon(Icons.add, size: 18, color: Color(0xFF1FBF9A)),
              label: Text(
                'Ajouter',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1FBF9A),
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF1FBF9A).withOpacity(0.1),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_medications.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0), style: BorderStyle.solid),
            ),
            child: Center(
              child: Text(
                'Aucun médicament. Cliquez sur "Ajouter" pour commencer.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFF667085),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          Column(
            children: _medications.asMap().entries.map((entry) {
              final index = entry.key;
              final med = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nom du Médicament',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: TextEditingController(text: med.name)
                        ..selection = TextSelection.collapsed(offset: med.name.length),
                      onChanged: (value) => med.name = value,
                      decoration: InputDecoration(
                        hintText: 'Ex: Metformine',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: const Color(0xFF667085),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF1FBF9A), width: 2),
                        ),
                      ),
                      style: GoogleFonts.plusJakartaSans(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dosage',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF667085),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: TextEditingController(text: med.dosage)
                                  ..selection = TextSelection.collapsed(offset: med.dosage.length),
                                onChanged: (value) => med.dosage = value,
                                decoration: InputDecoration(
                                  hintText: 'Ex: 500mg',
                                  hintStyle: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    color: const Color(0xFF667085),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFF1FBF9A), width: 2),
                                  ),
                                ),
                                style: GoogleFonts.plusJakartaSans(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Fréquence',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF667085),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: TextEditingController(text: med.frequency)
                                  ..selection = TextSelection.collapsed(offset: med.frequency.length),
                                onChanged: (value) => med.frequency = value,
                                decoration: InputDecoration(
                                  hintText: 'Ex: 2x/jour',
                                  hintStyle: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    color: const Color(0xFF667085),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFF1FBF9A), width: 2),
                                  ),
                                ),
                                style: GoogleFonts.plusJakartaSans(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => _removeMedication(index),
                      icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
                      label: Text(
                        'Supprimer ce médicament',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildDocumentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Documents Médicaux',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A202C),
              ),
            ),
            TextButton.icon(
              onPressed: _addDocument,
              icon: const Icon(Icons.add, size: 18, color: Color(0xFF1FBF9A)),
              label: Text(
                'Ajouter',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1FBF9A),
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF1FBF9A).withOpacity(0.1),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_documents.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0), style: BorderStyle.solid),
            ),
            child: Center(
              child: Text(
                'Aucun document. Cliquez sur "Ajouter" pour commencer.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFF667085),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          Column(
            children: _documents.asMap().entries.map((entry) {
              final index = entry.key;
              final doc = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nom du Document',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: TextEditingController(text: doc.name)
                        ..selection = TextSelection.collapsed(offset: doc.name.length),
                      onChanged: (value) => doc.name = value,
                      decoration: InputDecoration(
                        hintText: 'Ex: Rapport d\'Analyse de Sang',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: const Color(0xFF667085),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF1FBF9A), width: 2),
                        ),
                      ),
                      style: GoogleFonts.plusJakartaSans(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Type de Document',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: doc.type,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: InputBorder.none,
                        ),
                        items: _documentTypes.map((type) {
                          return DropdownMenuItem<String>(
                            value: type['value'] as String,
                            child: Text(
                              type['label'] as String,
                              style: GoogleFonts.plusJakartaSans(fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            doc.type = value ?? 'other';
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Date du Document',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: TextEditingController(text: doc.date)
                        ..selection = TextSelection.collapsed(offset: doc.date.length),
                      onChanged: (value) => doc.date = value,
                      decoration: InputDecoration(
                        hintText: 'JJ/MM/AAAA',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: const Color(0xFF667085),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF1FBF9A), width: 2),
                        ),
                        suffixIcon: const Icon(Icons.calendar_today, size: 18, color: Color(0xFF667085)),
                      ),
                      style: GoogleFonts.plusJakartaSans(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => _removeDocument(index),
                      icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
                      label: Text(
                        'Supprimer ce document',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildSaveButton() {
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
          height: 52,
          child: ElevatedButton(
            onPressed: _handleSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1FBF9A),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.save, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Enregistrer les Modifications',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
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
