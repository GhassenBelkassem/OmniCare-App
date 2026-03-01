import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PatientOption {
  final String id;
  final String name;
  final String type; // 'me', 'family', 'other'
  final int? age;
  final String? relationship;
  final String? avatar;

  PatientOption({
    required this.id,
    required this.name,
    required this.type,
    this.age,
    this.relationship,
    this.avatar,
  });
}

class EmergencyRequestStep1 extends StatefulWidget {
  const EmergencyRequestStep1({Key? key}) : super(key: key);

  @override
  State<EmergencyRequestStep1> createState() => _EmergencyRequestStep1State();
}

class _EmergencyRequestStep1State extends State<EmergencyRequestStep1> {
  String? _selectedPatientId;
  final TextEditingController _otherNameController = TextEditingController();
  final TextEditingController _otherAgeController = TextEditingController();
  
  // Mock data - in production, this would come from provider/database
  List<PatientOption> _patientOptions = [];

  @override
  void initState() {
    super.initState();
    _initializePatientOptions();
  }

  void _initializePatientOptions() {
    _patientOptions = [
      // User profile (Moi)
      PatientOption(
        id: 'me',
        name: 'Moi',
        type: 'me',
        age: 28,
      ),
      // Family members - these would come from the family members list
      PatientOption(
        id: 'family_1',
        name: 'Baba',
        type: 'family',
        age: 65,
        relationship: 'Père',
      ),
      PatientOption(
        id: 'family_2',
        name: 'Maman',
        type: 'family',
        age: 60,
        relationship: 'Mère',
      ),
      PatientOption(
        id: 'family_3',
        name: 'Ahmed',
        type: 'family',
        age: 8,
        relationship: 'Enfant',
      ),
      // Other option
      PatientOption(
        id: 'other',
        name: 'Autre Personne',
        type: 'other',
      ),
    ];
  }

  @override
  void dispose() {
    _otherNameController.dispose();
    _otherAgeController.dispose();
    super.dispose();
  }

  bool _canProceed() {
    if (_selectedPatientId == null) return false;
    if (_selectedPatientId == 'other') {
      return _otherNameController.text.isNotEmpty && _otherAgeController.text.isNotEmpty;
    }
    return true;
  }

  void _handleNext() {
    if (!_canProceed()) return;

    final selectedOption = _patientOptions.firstWhere((opt) => opt.id == _selectedPatientId);
    
    final data = {
      'patientId': _selectedPatientId,
      'patientName': _selectedPatientId == 'other' ? _otherNameController.text : selectedOption.name,
      'patientType': selectedOption.type,
      'age': _selectedPatientId == 'other' 
          ? int.tryParse(_otherAgeController.text) 
          : selectedOption.age,
      if (selectedOption.relationship != null) 'relationship': selectedOption.relationship,
    };

    Navigator.pushNamed(
      context,
      '/emergency-step2',
      arguments: data,
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
          icon: const Icon(Icons.close, color: Color(0xFF1A202C)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Demande Urgente',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A202C),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildProgressBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
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
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Qui a besoin d\'attention médicale ?',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A202C),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sélectionnez la personne qui nécessite des soins médicaux',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: const Color(0xFF667085),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ..._patientOptions.map((option) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildPatientOptionCard(option),
                    )),
                    if (_selectedPatientId == 'other') ...[
                      const SizedBox(height: 8),
                      _buildOtherPersonForm(),
                    ],
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _canProceed() ? _handleNext : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1FBF9A),
                          disabledBackgroundColor: const Color(0xFFE2E8F0),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Étape Suivante',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _canProceed() ? Colors.white : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildProgressStep(1, true)),
              const SizedBox(width: 8),
              Expanded(child: _buildProgressStep(2, false)),
              const SizedBox(width: 8),
              Expanded(child: _buildProgressStep(3, false)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Étape 1 sur 3',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF667085),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStep(int step, bool isActive) {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF1FBF9A) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildPatientOptionCard(PatientOption option) {
    final isSelected = _selectedPatientId == option.id;
    
    IconData icon;
    Color iconColor;
    
    switch (option.type) {
      case 'me':
        icon = Icons.person;
        iconColor = const Color(0xFF1FBF9A);
        break;
      case 'family':
        icon = Icons.people;
        iconColor = const Color(0xFF3B82F6);
        break;
      case 'other':
        icon = Icons.person_add;
        iconColor = const Color(0xFF9CA3AF);
        break;
      default:
        icon = Icons.person;
        iconColor = const Color(0xFF667085);
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPatientId = option.id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1FBF9A).withOpacity(0.05) : Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFF1FBF9A) : const Color(0xFFE2E8F0),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1FBF9A).withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isSelected ? iconColor : iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : iconColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.name,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A202C),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.relationship ?? _getDescription(option.type),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: const Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ),
            if (option.age != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F5F7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${option.age} ans',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF667085),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getDescription(String type) {
    switch (type) {
      case 'me':
        return 'Demande pour moi-même';
      case 'family':
        return 'Membre de la famille';
      case 'other':
        return 'Pour quelqu\'un d\'autre';
      default:
        return '';
    }
  }

  Widget _buildOtherPersonForm() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1FBF9A).withOpacity(0.05),
        border: Border.all(
          color: const Color(0xFF1FBF9A).withOpacity(0.2),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informations de la Personne',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A202C),
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _otherNameController,
            label: 'Nom Complet',
            hint: 'Ex: Mohamed Ali',
            required: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _otherAgeController,
            label: 'Âge',
            hint: 'Ex: 35',
            required: true,
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool required,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A202C),
              ),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(color: Color(0xFFEF4444), fontSize: 14),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF9CA3AF),
            ),
            filled: true,
            fillColor: Colors.white,
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            color: const Color(0xFF1A202C),
          ),
        ),
      ],
    );
  }
}
