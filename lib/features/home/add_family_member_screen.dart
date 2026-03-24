import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/family_provider.dart';
import '../../providers/user_provider.dart';

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

class _GenderChoiceChip extends StatelessWidget {
  const _GenderChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xFF1FBF9A)
                  : const Color(0xFFE2E8F0),
              width: selected ? 2 : 1,
            ),
            color: selected
                ? const Color(0xFF1FBF9A).withOpacity(0.06)
                : Colors.white,
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A202C),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AddFamilyMemberScreen extends StatefulWidget {
  final void Function(FamilyMemberData)? onSave;

  const AddFamilyMemberScreen({super.key, this.onSave});

  @override
  State<AddFamilyMemberScreen> createState() => _AddFamilyMemberScreenState();
}

class _AddFamilyMemberScreenState extends State<AddFamilyMemberScreen> {
  int _currentStep = 0;
  String? _photoPath;
  bool _isSaving = false;

  // Step 1: Identity
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _birthDateController = TextEditingController();
  String? _selectedGender;

  // Step 2: Relationship
  String _selectedRelationship = '';
  final _relationshipDescriptionController = TextEditingController();
  bool _otherExpanded = false;
  String? _otherKind;
  String? _otherCousinGender;

  // Step 3: Medical Info
  String _selectedBloodType = '';
  final List<String> _selectedConditions = [];
  final _criticalAlertController = TextEditingController();

  final List<String> _bloodTypes = [
    '-',
    'A+',
    'A-',
    'B+',
    'B-',
    'O+',
    'O-',
    'AB+',
    'AB-',
  ];

  final List<Map<String, String>> _relationships = [
    {'value': 'Baba', 'label': 'Baba (Père)', 'icon': '👨'},
    {'value': 'Maman', 'label': 'Maman (Mère)', 'icon': '👩'},
    {'value': 'Fils', 'label': 'Fils', 'icon': '👦'},
    {'value': 'Fille', 'label': 'Fille', 'icon': '👧'},
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

  bool get _canProceedStep1 =>
      _firstNameController.text.trim().isNotEmpty &&
      _lastNameController.text.trim().isNotEmpty &&
      _birthDateController.text.isNotEmpty;
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

  String? _toIsoBirthDate(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return null;
    final parts = raw.split('/');
    if (parts.length != 3) return null;
    final dd = parts[0].padLeft(2, '0');
    final mm = parts[1].padLeft(2, '0');
    final yyyy = parts[2].padLeft(4, '0');
    if (dd.length != 2 || mm.length != 2 || yyyy.length != 4) return null;
    return '$yyyy-$mm-$dd';
  }

  Future<void> _handleSubmit() async {
    if (_isSaving) return;

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final fullName = '$firstName $lastName'.trim();
    final rawPhone = _phoneNumberController.text.trim();
    final birthDateUi = _birthDateController.text.trim();
    final relationship = _selectedRelationship.trim();
    final relationshipDescription = _relationshipDescriptionController.text
        .trim();
    final birthDateIso = _toIsoBirthDate(birthDateUi);

    if (firstName.isEmpty ||
        lastName.isEmpty ||
        relationship.isEmpty ||
        birthDateIso == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Veuillez remplir le prénom, le nom, la relation et la date de naissance.',
            style: GoogleFonts.plusJakartaSans(fontSize: 13),
          ),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final medicalInfo = <String, dynamic>{
        if (_selectedConditions.isNotEmpty)
          'chronicConditions': List<String>.from(_selectedConditions),
        if (_criticalAlertController.text.trim().isNotEmpty)
          'criticalAlert': _criticalAlertController.text.trim(),
      };

      final bloodGroup =
          (_selectedBloodType.trim().isEmpty ||
              _selectedBloodType.trim() == '-')
          ? null
          : _selectedBloodType.trim();

      final fallbackPhone = context.read<UserProvider>().user?.phoneNumber;
      final resolvedPhone = rawPhone.isNotEmpty ? rawPhone : fallbackPhone;

      final resolvedRelationshipDescription = relationship == 'Autre'
          ? (relationshipDescription.isEmpty ? null : relationshipDescription)
          : null;

      await context.read<FamilyProvider>().addFamilyMember(
        fullName: fullName,
        firstName: firstName,
        lastName: lastName,
        relationship: relationship,
        relationshipDescription: resolvedRelationshipDescription,
        phoneNumber: resolvedPhone,
        birthDate: birthDateIso,
        gender: _selectedGender,
        bloodGroup: bloodGroup,
        medicalInfo: medicalInfo.isEmpty ? null : medicalInfo,
      );

      final data = FamilyMemberData(
        photo: _photoPath,
        name: fullName,
        birthDate: birthDateUi,
        relationship: relationship,
        bloodType: _selectedBloodType,
        chronicConditions: _selectedConditions,
        criticalAlert: _criticalAlertController.text,
      );

      widget.onSave?.call(data);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Membre de la famille ajouté avec succès.',
            style: GoogleFonts.plusJakartaSans(fontSize: 13),
          ),
          backgroundColor: const Color(0xFF1FBF9A),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Échec de création: ${e.toString()}',
            style: GoogleFonts.plusJakartaSans(fontSize: 13),
          ),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneNumberController.dispose();
    _birthDateController.dispose();
    _criticalAlertController.dispose();
    _relationshipDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _showCustomRelationshipDialog() async {
    final controller = TextEditingController(
      text: _relationshipDescriptionController.text,
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Autre relation',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Ex: Voisin, Ami, Beau-frère...',
              hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: const Color(0xFF667085),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
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
                borderSide: const BorderSide(
                  color: Color(0xFF1FBF9A),
                  width: 2,
                ),
              ),
            ),
            style: GoogleFonts.plusJakartaSans(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(
                'Annuler',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1FBF9A),
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Valider',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();
    if (!mounted) return;

    final v = (result ?? '').trim();
    if (v.isEmpty) return;

    setState(() {
      _selectedRelationship = 'Autre';
      _relationshipDescriptionController.text = v;
      _otherExpanded = true;
      _otherKind = null;
      _otherCousinGender = null;
    });
  }

  Future<void> _showSidePickerSheet(String kind) async {
    final needsCousinGender =
        kind == 'COUSIN' &&
        (_selectedGender == null || _selectedGender!.trim().isEmpty);

    String? tempGender = _otherCousinGender;

    final side = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Choisir le côté',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1A202C),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (needsCousinGender) ...[
                      Text(
                        'Genre (pour Cousin(e))',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF667085),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: Text(
                                'Homme',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              selected: (tempGender ?? '') == 'M',
                              onSelected: (_) => setLocalState(() {
                                tempGender = 'M';
                              }),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ChoiceChip(
                              label: Text(
                                'Femme',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              selected: (tempGender ?? '') == 'F',
                              onSelected: (_) => setLocalState(() {
                                tempGender = 'F';
                              }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.account_tree_outlined),
                      title: Text(
                        'Paternel',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onTap: () => Navigator.of(context).pop('PATERNAL'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.account_tree_outlined),
                      title: Text(
                        'Maternel',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onTap: () => Navigator.of(context).pop('MATERNAL'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted) return;
    if (side == null) return;

    setState(() {
      _otherExpanded = true;
      _otherKind = kind;
      if (needsCousinGender &&
          tempGender != null &&
          tempGender!.trim().isNotEmpty) {
        _otherCousinGender = tempGender;
      }
      _relationshipDescriptionController.clear();
    });

    _commitOtherSide(side);
  }

  void _commitOtherSide(String side) {
    if (_otherKind == null) return;

    final kind = _otherKind;
    String uiRelationship = '';

    if (kind == 'UNCLE') {
      uiRelationship = side == 'PATERNAL'
          ? 'Oncle (Paternel)'
          : 'Oncle (Maternel)';
    } else if (kind == 'AUNT') {
      uiRelationship = side == 'PATERNAL'
          ? 'Tante (Paternelle)'
          : 'Tante (Maternelle)';
    } else if (kind == 'COUSIN') {
      final gender = (_otherCousinGender ?? _selectedGender) ?? 'M';
      final isFemale = gender == 'F';
      if (isFemale) {
        uiRelationship = side == 'PATERNAL'
            ? 'Cousine (Paternelle)'
            : 'Cousine (Maternelle)';
      } else {
        uiRelationship = side == 'PATERNAL'
            ? 'Cousin (Paternel)'
            : 'Cousin (Maternel)';
      }
    }

    if (uiRelationship.trim().isEmpty) return;

    setState(() {
      _selectedRelationship = uiRelationship;
      _otherExpanded = true;
      _relationshipDescriptionController.clear();
    });
  }

  Widget _buildRelationshipCard({
    required String label,
    required String icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF1FBF9A).withOpacity(0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF1FBF9A) : const Color(0xFFE2E8F0),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
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
            Text(icon, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(
              label,
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
                const Icon(
                  Icons.person_add,
                  color: Color(0xFF1FBF9A),
                  size: 20,
                ),
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
                      color: index <= _currentStep
                          ? const Color(0xFF1FBF9A)
                          : const Color(0xFFE2E8F0),
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
              Icon(Icons.person, size: 48, color: const Color(0xFF1FBF9A)),
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
                  'Nom *',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A202C),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _firstNameController,
                    decoration: InputDecoration(
                      hintText: 'Prénom',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: const Color(0xFF667085),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
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
                        borderSide: const BorderSide(
                          color: Color(0xFF1FBF9A),
                          width: 2,
                        ),
                      ),
                    ),
                    style: GoogleFonts.plusJakartaSans(fontSize: 14),
                    onChanged: (value) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _lastNameController,
                    decoration: InputDecoration(
                      hintText: 'Nom',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: const Color(0xFF667085),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
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
                        borderSide: const BorderSide(
                          color: Color(0xFF1FBF9A),
                          width: 2,
                        ),
                      ),
                    ),
                    style: GoogleFonts.plusJakartaSans(fontSize: 14),
                    onChanged: (value) => setState(() {}),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Gender
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.wc, color: Color(0xFF1FBF9A), size: 18),
                const SizedBox(width: 8),
                Text(
                  'Genre (optionnel)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A202C),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _GenderChoiceChip(
                    label: 'Homme',
                    selected: _selectedGender == 'M',
                    onTap: () => setState(() => _selectedGender = 'M'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GenderChoiceChip(
                    label: 'Femme',
                    selected: _selectedGender == 'F',
                    onTap: () => setState(() => _selectedGender = 'F'),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Phone Number
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.phone, color: Color(0xFF1FBF9A), size: 18),
                const SizedBox(width: 8),
                Text(
                  'Téléphone (optionnel)',
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
              controller: _phoneNumberController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'Ex: +216 12 345 678',
                hintStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: const Color(0xFF667085),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
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
                  borderSide: const BorderSide(
                    color: Color(0xFF1FBF9A),
                    width: 2,
                  ),
                ),
              ),
              style: GoogleFonts.plusJakartaSans(fontSize: 14),
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
                const Icon(
                  Icons.calendar_today,
                  color: Color(0xFF1FBF9A),
                  size: 18,
                ),
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
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
                  borderSide: const BorderSide(
                    color: Color(0xFF1FBF9A),
                    width: 2,
                  ),
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
                    _birthDateController.text =
                        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
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
    return Stack(
      children: [
        Column(
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
                final v = rel['value']!;
                final isSelected = _selectedRelationship == v;

                return _buildRelationshipCard(
                  label: rel['label']!,
                  icon: rel['icon']!,
                  selected: isSelected,
                  onTap: () {
                    if (v == 'Autre') {
                      setState(() {
                        _otherExpanded = !_otherExpanded;
                        if (!_otherExpanded) {
                          _otherKind = null;
                          _otherCousinGender = null;
                        }
                      });
                      return;
                    }

                    setState(() {
                      _selectedRelationship = v;
                      _relationshipDescriptionController.clear();
                      _otherExpanded = false;
                      _otherKind = null;
                      _otherCousinGender = null;
                    });
                  },
                );
              },
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              child: !_otherExpanded
                  ? const SizedBox.shrink()
                  : Column(
                      children: [
                        const SizedBox(height: 16),
                        GridView(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1.2,
                              ),
                          children: [
                            _buildRelationshipCard(
                              label: 'Oncle',
                              icon: '🧔',
                              selected: _otherKind == 'UNCLE',
                              onTap: () => _showSidePickerSheet('UNCLE'),
                            ),
                            _buildRelationshipCard(
                              label: 'Tante',
                              icon: '👩',
                              selected: _otherKind == 'AUNT',
                              onTap: () => _showSidePickerSheet('AUNT'),
                            ),
                            _buildRelationshipCard(
                              label: 'Cousin(e)',
                              icon: '👤',
                              selected: _otherKind == 'COUSIN',
                              onTap: () => _showSidePickerSheet('COUSIN'),
                            ),
                            _buildRelationshipCard(
                              label: 'Écrire…',
                              icon: '✍️',
                              selected:
                                  _selectedRelationship == 'Autre' &&
                                  _relationshipDescriptionController.text
                                      .trim()
                                      .isNotEmpty,
                              onTap: _showCustomRelationshipDialog,
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 40),
          ],
        ),
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
            initialValue: _bloodTypes.contains(_selectedBloodType)
                ? _selectedBloodType
                : '-',
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
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
                _selectedBloodType = (value == null || value.trim().isEmpty)
                    ? '-'
                    : value;
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF0F6F73)
                      : const Color(0xFFF4F5F7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF0F6F73)
                        : const Color(0xFFE2E8F0),
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
        border: Border(top: BorderSide(color: const Color(0xFFE2E8F0))),
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
                      side: const BorderSide(
                        color: Color(0xFFE2E8F0),
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.chevron_left,
                          color: Color(0xFF1A202C),
                        ),
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
                  onPressed: (_currentStep == 2 && _isSaving)
                      ? null
                      : (_currentStep < 2
                            ? ((_currentStep == 0 && _canProceedStep1) ||
                                      (_currentStep == 1 && _canProceedStep2)
                                  ? _handleNext
                                  : null)
                            : () => _handleSubmit()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1FBF9A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: (_currentStep == 2 && _isSaving)
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentStep < 2 ? 'Suivant' : 'Terminer',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (_currentStep < 2) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.chevron_right, size: 20),
                            ] else ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.person_add, size: 20),
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
