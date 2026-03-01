import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FamilyMemberData {
  String? photo;
  String name;
  String birthDate;
  String relationship;
  String bloodType;
  List<String> chronicConditions;
  String criticalAlert;

  FamilyMemberData({
    this.photo,
    required this.name,
    required this.birthDate,
    required this.relationship,
    required this.bloodType,
    required this.chronicConditions,
    required this.criticalAlert,
  });
}

class AddFamilyMemberScreen extends StatefulWidget {
  final Function(FamilyMemberData) onSave;

  const AddFamilyMemberScreen({
    Key? key,
    required this.onSave,
  }) : super(key: key);

  @override
  State<AddFamilyMemberScreen> createState() => _AddFamilyMemberScreenState();
}

class _AddFamilyMemberScreenState extends State<AddFamilyMemberScreen> {
  int _currentStep = 0;
  String? _photoPath;
  
  // Step 1: Identity
  final _nameController = TextEditingController();
  final _birthDateController = TextEditingController();
  
  // Step 2: Relationship
  String _selectedRelationship = '';
  
  // Step 3: Medical Info
  String _selectedBloodType = '';
  List<String> _selectedConditions = [];
  final _criticalAlertController = TextEditingController();

  final List<String> _bloodTypes = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];
  
  final List<Map<String, String>> _relationships = [
    {'value': 'Baba', 'label': 'Baba (Père)', 'icon': '👨'},
    {'value': 'Maman', 'label': 'Maman (Mère)', 'icon': '👩'},
    {'value': 'Enfant', 'label': 'Enfant', 'icon': '👶'},
    {'value': 'Grand-père', 'label': 'Grand-père', 'icon': '👴'},
    {'value': 'Grand-mère', 'label': 'Grand-mère', 'icon': '👵'},
    {'value': 'Frère', 'label': 'Frère', 'icon': '👦'},
    {'value': 'Sœur', 'label': 'Sœur', 'icon': '👧'},
    {'value': 'Autre', 'label': 'Autre', 'icon': '👤'},
  ];

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

  bool get _canProceedStep1 => _nameController.text.trim().isNotEmpty && _birthDateController.text.isNotEmpty;
  bool get _canProceedStep2 => _selectedRelationship.isNotEmpty;

  void _toggleCondition(String condition) {
    setState(() {
      if (_selectedConditions.contains(condition)) {
        _selectedConditions.remove(condition);
      } else {
        _selectedConditions.add(condition);
      }
    });
  }

  void _handleNext() {
    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
    }
  }

  void _handleBack() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  void _handleSubmit() {
    final data = FamilyMemberData(
      photo: _photoPath,
      name: _nameController.text,
      birthDate: _birthDateController.text,
      relationship: _selectedRelationship,
      bloodType: _selectedBloodType,
      chronicConditions: _selectedConditions,
      criticalAlert: _criticalAlertController.text,
    );
    
    widget.onSave(data);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthDateController.dispose();
    _criticalAlertController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1A202C)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_add, color: Color(0xFF1FBF9A), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ajouter un Membre de la Famille',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A202C),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Étape ${_currentStep + 1} sur 3',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: const Color(0xFF667085),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Progress Bar
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: List.generate(3, (index) {
                return Expanded(
                  child: Container(
                    height: 8,
                    margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
                    decoration: BoxDecoration(
                      color: index <= _currentStep ? const Color(0xFF1FBF9A) : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }),
            ),
          ),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildStepContent(),
            ),
          ),
          
          // Navigation Buttons
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Identity();
      case 1:
        return _buildStep2Relationship();
      case 2:
        return _buildStep3MedicalInfo();
      default:
        return Container();
    }
  }

  Widget _buildStep1Identity() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Text(
          'Identité du Membre',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A202C),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Commencez par les informations de base',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: const Color(0xFF667085),
          ),
        ),
        const SizedBox(height: 32),
        
        // Photo Placeholder
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF1FBF9A).withOpacity(0.3),
              width: 3,
              style: BorderStyle.solid,
            ),
            color: const Color(0xFF1FBF9A).withOpacity(0.05),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person,
                size: 48,
                color: const Color(0xFF1FBF9A),
              ),
              const SizedBox(height: 8),
              Text(
                'Photo',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: const Color(0xFF667085),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        
        // Name
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: Color(0xFF1FBF9A), size: 18),
                const SizedBox(width: 8),
                Text(
                  'Nom Complet *',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A202C),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Ex: Mohamed Ben Ahmed',
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: const Color(0xFF667085),
                ),
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
              onChanged: (value) => setState(() {}),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Birth Date
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Color(0xFF1FBF9A), size: 18),
                const SizedBox(width: 8),
                Text(
                  'Date de Naissance *',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A202C),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _birthDateController,
              decoration: InputDecoration(
                hintText: 'JJ/MM/AAAA',
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: const Color(0xFF667085),
                ),
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
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() {
                    _birthDateController.text = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
                  });
                }
              },
              readOnly: true,
            ),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildStep2Relationship() {
    return Column(
      children: [
        const SizedBox(height: 20),
        Text(
          'Lien de Parenté',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A202C),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Sélectionnez la relation avec ce membre',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: const Color(0xFF667085),
          ),
        ),
        const SizedBox(height: 32),
        
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          itemCount: _relationships.length,
          itemBuilder: (context, index) {
            final rel = _relationships[index];
            final isSelected = _selectedRelationship == rel['value'];
            
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedRelationship = rel['value']!;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF1FBF9A).withOpacity(0.05) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF1FBF9A) : const Color(0xFFE2E8F0),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF1FBF9A).withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      rel['icon']!,
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      rel['label']!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A202C),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildStep3MedicalInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Center(
          child: Column(
            children: [
              Text(
                'Informations Médicales',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A202C),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Renseignez les données de santé initiales',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: const Color(0xFF667085),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        
        // Blood Type
        Text(
          'Groupe Sanguin',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A202C),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedBloodType.isEmpty ? null : _selectedBloodType,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: InputBorder.none,
            ),
            hint: Text(
              'Sélectionner (optionnel)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: const Color(0xFF667085),
              ),
            ),
            items: _bloodTypes.map((type) {
              return DropdownMenuItem<String>(
                value: type,
                child: Text(
                  type,
                  style: GoogleFonts.plusJakartaSans(fontSize: 14),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedBloodType = value ?? '';
              });
            },
          ),
        ),
        const SizedBox(height: 24),
        
        // Critical Alert
        Text(
          'Alerte Critique (Optionnel)',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A202C),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _criticalAlertController,
          decoration: InputDecoration(
            hintText: 'Ex: Allergie Pénicilline, Asthme Sévère',
            hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: const Color(0xFF667085),
            ),
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
        ),
        const SizedBox(height: 4),
        Text(
          'Cette information apparaîtra sur la carte du membre',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: const Color(0xFF667085),
          ),
        ),
        const SizedBox(height: 24),
        
        // Chronic Conditions
        Text(
          'Conditions Chroniques',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A202C),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableConditions.map((condition) {
            final isSelected = _selectedConditions.contains(condition);
            return GestureDetector(
              onTap: () => _toggleCondition(condition),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF1A202C),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: const Color(0xFFE2E8F0)),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _handleBack,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE2E8F0), width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.chevron_left, color: Color(0xFF1A202C)),
                        Text(
                          'Retour',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A202C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _currentStep < 2
                      ? ((_currentStep == 0 && _canProceedStep1) || (_currentStep == 1 && _canProceedStep2)
                          ? _handleNext
                          : null)
                      : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1FBF9A),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFE2E8F0),
                    disabledForegroundColor: const Color(0xFF667085),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_currentStep < 2)
                        Text(
                          'Suivant',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      if (_currentStep < 2) const SizedBox(width: 8),
                      if (_currentStep < 2)
                        const Icon(Icons.chevron_right, size: 20)
                      else ...[
                        const Icon(Icons.person_add, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Ajouter',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
