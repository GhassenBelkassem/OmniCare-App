import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../core/api/account_api.dart';
import '../../core/api/api_error_utils.dart';
import '../../core/api/medications_api.dart' as med_api;
import '../../core/utils/logger.dart';
import '../../providers/user_onboarding_provider.dart';
import '../../providers/user_provider.dart';
import '../../core/widgets/medication_search_field.dart';
import 'onboarding_complete_screen.dart';

class ConversationalOnboardingScreen extends StatefulWidget {
  const ConversationalOnboardingScreen({super.key, required this.accountApi});

  final AccountApi accountApi;

  @override
  State<ConversationalOnboardingScreen> createState() =>
      _ConversationalOnboardingScreenState();
}

class _ConversationalOnboardingScreenState
    extends State<ConversationalOnboardingScreen> {
  final PageController _pageController = PageController();
  AccountApi get _accountApi => widget.accountApi;
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _dateOfBirthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  int _currentPage = 0;
  bool _saving = false;
  bool _profilePrefillStarted = false;
  DateTime? _selectedDateOfBirth;
  String? _selectedGender;

  final List<String> bloodTypes = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
    'IDK',
  ];

  final List<String> availableConditions = [
    'Diabetes',
    'Hypertension',
    'Asthma',
    'Heart Disease',
    'Arthritis',
    'Thyroid Disorder',
    'Kidney Disease',
    'Liver Disease',
    'Cancer',
    'Epilepsy',
    'COPD',
    'Depression',
    'Anxiety',
    'Migraine',
  ];

  List<String> _filteredConditions = [];
  final TextEditingController _searchController = TextEditingController();
  final List<TextEditingController> _allergyNameControllers = [];
  final List<String> _allergySeverities = [];
  final List<bool> _allergyLifeSafety = [];
  final List<TextEditingController> _medicationNameControllers = [];
  final List<TextEditingController> _medicationDosageControllers = [];
  final List<String?> _medicationIds = [];
  final List<med_api.MedicationSearchResult?> _medicationDetails = [];

  @override
  void initState() {
    super.initState();
    _filteredConditions = availableConditions;
    _addAllergyFields();
    _addMedicationFields();
    _heightController.addListener(_refreshBodyMeasurementPreview);
    _weightController.addListener(_refreshBodyMeasurementPreview);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_profilePrefillStarted) return;
    _profilePrefillStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefillBasicProfile();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dateOfBirthController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _searchController.dispose();
    for (var controller in _allergyNameControllers) {
      controller.dispose();
    }
    for (var controller in _medicationNameControllers) {
      controller.dispose();
    }
    for (var controller in _medicationDosageControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addMedicationFields() {
    _medicationNameControllers.add(TextEditingController());
    _medicationDosageControllers.add(TextEditingController());
    _medicationIds.add(null);
    _medicationDetails.add(null);
  }

  void _addAllergyFields() {
    _allergyNameControllers.add(TextEditingController());
    _allergySeverities.add('modérée');
    _allergyLifeSafety.add(false);
  }

  void _removeAllergyFields(int index) {
    if (_allergyNameControllers.length > 1) {
      _allergyNameControllers[index].dispose();
      setState(() {
        _allergyNameControllers.removeAt(index);
        _allergySeverities.removeAt(index);
        _allergyLifeSafety.removeAt(index);
      });
    }
  }

  void _removeMedicationFields(int index) {
    if (_medicationNameControllers.length > 1) {
      _medicationNameControllers[index].dispose();
      _medicationDosageControllers[index].dispose();
      setState(() {
        _medicationNameControllers.removeAt(index);
        _medicationDosageControllers.removeAt(index);
        _medicationIds.removeAt(index);
        _medicationDetails.removeAt(index);
      });
    }
  }

  void _filterConditions(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredConditions = availableConditions;
      } else {
        _filteredConditions = availableConditions
            .where(
              (condition) =>
                  condition.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      }
    });
  }

  int get _pageCount => 5;
  int get _lastPageIndex => _pageCount - 1;

  int? get _heightCm => int.tryParse(_heightController.text.trim());
  double? get _weightKg =>
      double.tryParse(_weightController.text.trim().replaceAll(',', '.'));

  double? get _bmiPreview {
    final height = _heightCm;
    final weight = _weightKg;
    if (height == null || height <= 0 || weight == null || weight <= 0) {
      return null;
    }
    final meters = height / 100;
    return weight / (meters * meters);
  }

  void _refreshBodyMeasurementPreview() {
    if (mounted) setState(() {});
  }

  Future<void> _prefillBasicProfile() async {
    try {
      final profile = await _accountApi.getPatientProfile();
      if (!mounted) return;
      setState(() {
        if (_firstNameController.text.trim().isEmpty) {
          _firstNameController.text = profile.firstName;
        }
        if (_lastNameController.text.trim().isEmpty) {
          _lastNameController.text = profile.lastName;
        }
        if (_selectedDateOfBirth == null && profile.dateOfBirth != null) {
          _selectedDateOfBirth = profile.dateOfBirth;
          _dateOfBirthController.text = _formatDobDisplay(profile.dateOfBirth!);
        }
        if ((_selectedGender ?? '').trim().isEmpty &&
            (profile.gender ?? '').trim().isNotEmpty) {
          _selectedGender = profile.gender;
        }
      });
    } catch (e, st) {
      AppLogger.error('Failed to prefill onboarding profile', e, st);
    }
  }

  void _nextPage() {
    if (_currentPage == 0 && !_validateBasicProfile(showError: true)) {
      return;
    }
    if (_currentPage == 1 && !_validateBodyMeasurements(showError: true)) {
      return;
    }
    if (_currentPage == 2 && !_validateAllergies(showError: true)) {
      return;
    }
    if (_currentPage < _lastPageIndex) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    final provider = Provider.of<UserOnboardingProvider>(
      context,
      listen: false,
    );
    final userProvider = context.read<UserProvider>();

    if (!_validateBasicProfile(showError: true)) return;
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final dateOfBirth = _selectedDateOfBirth!;
    final gender = _selectedGender!;
    provider.setBasicProfile(
      firstName: firstName,
      lastName: lastName,
      dateOfBirth: dateOfBirth,
      gender: gender,
    );
    if (!_validateBodyMeasurements(showError: true)) return;
    final heightCm = _heightCm;
    final weightKg = _weightKg;
    provider.setBodyMeasurements(heightCm: heightCm, weightKg: weightKg);

    if (!_validateAllergies(showError: true)) return;
    final allergies = _collectAllergies();
    provider.setAllergies(allergies);

    provider.medications.clear();

    for (int i = 0; i < _medicationNameControllers.length; i++) {
      final name = _medicationNameControllers[i].text.trim();
      final dosage = _medicationDosageControllers[i].text.trim();
      final medId = _medicationIds[i];
      final hasAnyInput = name.isNotEmpty || dosage.isNotEmpty;
      if (!hasAnyInput) continue;

      if (medId == null || medId.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a medication from the list.'),
          ),
        );
        return;
      }

      if (dosage.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a dosage for the selected medication.'),
          ),
        );
        return;
      }

      provider.addMedication(
        MedicationEntry(
          medicationId: medId,
          name: name,
          dosage: dosage,
          frequency: '1x daily',
        ),
      );
    }

    setState(() => _saving = true);
    try {
      final profile = await _accountApi.getPatientProfile();
      final currentStep = profile.onboardingCompleted
          ? 0
          : profile.onboardingStep;

      if (currentStep != 0 && currentStep <= 1) {
        await _accountApi.saveOnboardingStep(1, {
          'firstName': firstName,
          'lastName': lastName,
          'dateOfBirth': _formatDateOnly(dateOfBirth),
          'gender': gender,
          'bloodType': provider.bloodGroup,
          'heightCm': heightCm,
          'weightKg': weightKg,
        });
      }

      if (currentStep != 0) {
        await _accountApi.patchMedicalPassport(
          bloodGroup: provider.bloodGroup,
          heightCm: heightCm,
          weightKg: weightKg,
        );
      }

      if (currentStep != 0 && currentStep <= 2) {
        await _accountApi.saveOnboardingStep(2, {
          if (allergies.isEmpty) 'noKnownAllergies': true,
          if (allergies.isNotEmpty)
            'allergies': allergies.map((a) => a.toJson()).toList(),
        });
      }

      if (currentStep != 0 && currentStep <= 3) {
        final conditions = provider.chronicConditions
            .where((condition) => condition.trim().isNotEmpty)
            .map(
              (condition) => {'name': condition.trim(), 'criticalOptIn': false},
            )
            .toList();
        await _accountApi.saveOnboardingStep(3, {
          if (conditions.isEmpty) 'noKnownConditions': true,
          if (conditions.isNotEmpty) 'conditions': conditions,
        });
      }

      if (currentStep != 0 && currentStep <= 4) {
        final medications = provider.medications
            .where((m) => m.name.trim().isNotEmpty)
            .map(
              (m) => {
                'drugName': m.name.trim(),
                'dosage': m.dosage.trim().isEmpty ? null : m.dosage.trim(),
                'frequency': m.frequency.trim().isEmpty
                    ? null
                    : m.frequency.trim(),
                'startDate': _formatDateOnly(DateTime.now()),
              },
            )
            .toList();
        await _accountApi.saveOnboardingStep(4, {
          if (medications.isEmpty) 'noKnownMedications': true,
          if (medications.isNotEmpty) 'medications': medications,
        });
      }

      if (!mounted) return;
      await userProvider.refresh();
    } catch (e, st) {
      AppLogger.error('Failed to save medical passport', e, st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: ${apiErrorMessage(e)}')),
      );
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const OnboardingCompleteScreen()),
    );
  }

  bool _validateBasicProfile({required bool showError}) {
    String? message;
    if (_firstNameController.text.trim().isEmpty) {
      message = 'Please enter your first name.';
    } else if (_lastNameController.text.trim().isEmpty) {
      message = 'Please enter your last name.';
    } else if (_selectedDateOfBirth == null) {
      message = 'Please select your birth date.';
    } else if (!_selectedDateOfBirth!.isBefore(DateTime.now())) {
      message = 'Please select a birth date in the past.';
    } else if ((_selectedGender ?? '').trim().isEmpty) {
      message = 'Please select your gender.';
    }

    if (message == null) return true;
    if (showError) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
    return false;
  }

  bool _validateBodyMeasurements({required bool showError}) {
    String? message;
    final rawHeight = _heightController.text.trim();
    final rawWeight = _weightController.text.trim();
    final height = _heightCm;
    final weight = _weightKg;

    if (rawHeight.isEmpty) {
      message = 'Please enter your height.';
    } else if (rawWeight.isEmpty) {
      message = 'Please enter your weight.';
    } else if (height == null || height <= 0 || height >= 300) {
      message = 'Please enter a valid height.';
    } else if (weight == null || weight <= 0 || weight >= 500) {
      message = 'Please enter a valid weight.';
    }

    if (message == null) return true;
    if (showError) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
    return false;
  }

  bool _validateAllergies({required bool showError}) {
    String? message;
    for (var i = 0; i < _allergyNameControllers.length; i++) {
      final name = _allergyNameControllers[i].text.trim();
      final severity = _allergySeverities[i].trim();
      if (name.isEmpty && _allergyLifeSafety[i]) {
        message = 'Please enter the allergy name.';
        break;
      }
      if (name.isNotEmpty && severity.isEmpty) {
        message = 'Please select allergy severity.';
        break;
      }
    }

    if (message == null) return true;
    if (showError) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
    return false;
  }

  List<AllergyEntry> _collectAllergies() {
    final entries = <AllergyEntry>[];
    for (var i = 0; i < _allergyNameControllers.length; i++) {
      final name = _allergyNameControllers[i].text.trim();
      if (name.isEmpty) continue;
      entries.add(
        AllergyEntry(
          name: name,
          severity: _allergySeverities[i],
          lifeSafety: _allergyLifeSafety[i],
        ),
      );
    }
    return entries;
  }

  void _clearAllergies() {
    setState(() {
      for (var i = _allergyNameControllers.length - 1; i > 0; i--) {
        _allergyNameControllers[i].dispose();
        _allergyNameControllers.removeAt(i);
        _allergySeverities.removeAt(i);
        _allergyLifeSafety.removeAt(i);
      }
      if (_allergyNameControllers.isEmpty) {
        _allergyNameControllers.add(TextEditingController());
        _allergySeverities.add('modérée');
        _allergyLifeSafety.add(false);
      }
      _allergyNameControllers.first.clear();
      _allergySeverities.first = 'modérée';
      _allergyLifeSafety.first = false;
    });
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateOfBirth ?? DateTime(now.year - 25, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked == null) return;
    setState(() {
      _selectedDateOfBirth = picked;
      _dateOfBirthController.text = _formatDobDisplay(picked);
    });
  }

  static String _formatDateOnly(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static String _formatDobDisplay(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year.toString().padLeft(4, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<UserOnboardingProvider>(context);

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: const Color(0xFFF4F5F7),
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: _currentPage > 0
                  ? IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Color(0xFF1D2939),
                      ),
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeInOut,
                        );
                      },
                    )
                  : null,
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacementNamed(context, '/home');
                  },
                  child: Text(
                    'Skip',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF667085),
                    ),
                  ),
                ),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    children: [
                      _buildBasicProfilePage(),
                      _buildBloodTypePage(provider),
                      _buildAllergiesPage(),
                      _buildConditionsPage(provider),
                      _buildMedicationsPage(),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 8,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SmoothPageIndicator(
                        controller: _pageController,
                        count: _pageCount,
                        effect: ExpandingDotsEffect(
                          activeDotColor: const Color(0xFF1FBF9A),
                          dotColor: const Color(0xFFE5E7EB),
                          dotHeight: 8,
                          dotWidth: 8,
                          expansionFactor: 4,
                          spacing: 8,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1FBF9A),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _currentPage == _lastPageIndex
                                ? 'Complete'
                                : 'Continue',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_saving)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.2),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBasicProfilePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 140,
              height: 140,
              decoration: const BoxDecoration(
                color: Color(0xFFF0FDF9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.badge_rounded,
                size: 64,
                color: Color(0xFF1FBF9A),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Confirm your profile',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F6F73),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'These details help us keep your medical passport accurate.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 28),
          _buildProfileTextField(
            controller: _firstNameController,
            label: 'First name',
            icon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          _buildProfileTextField(
            controller: _lastNameController,
            label: 'Last name',
            icon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _dateOfBirthController,
            readOnly: true,
            onTap: _pickDateOfBirth,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              color: const Color(0xFF1D2939),
            ),
            decoration: InputDecoration(
              labelText: 'Birth date',
              labelStyle: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF667085),
              ),
              prefixIcon: const Icon(
                Icons.calendar_today_rounded,
                color: Color(0xFF667085),
              ),
              suffixIcon: const Icon(
                Icons.expand_more_rounded,
                color: Color(0xFF667085),
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF1FBF9A),
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Gender',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1D2939),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildGenderOption(
                  value: 'M',
                  label: 'Male',
                  icon: Icons.male_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGenderOption(
                  value: 'F',
                  label: 'Female',
                  icon: Icons.female_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildGenderOption(
            value: 'autre',
            label: 'Other',
            icon: Icons.transgender_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputAction? textInputAction,
  }) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.words,
      textInputAction: textInputAction,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        color: const Color(0xFF1D2939),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF667085)),
        prefixIcon: Icon(icon, color: const Color(0xFF667085)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1FBF9A), width: 2),
        ),
      ),
    );
  }

  Widget _buildGenderOption({
    required String value,
    required String label,
    required IconData icon,
  }) {
    final selected = _selectedGender == value;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _selectedGender = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1FBF9A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF1FBF9A) : const Color(0xFFE5E7EB),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? Colors.white : const Color(0xFF667085),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : const Color(0xFF1D2939),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBloodTypePage(UserOnboardingProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Illustration
          Center(
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF9),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Image.asset(
                  'assets/images/blood_type.png',
                  width: 100,
                  height: 100,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.bloodtype_rounded,
                      size: 60,
                      color: const Color(0xFF1FBF9A),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'What is your blood type?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F6F73),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'This helps our emergency team prepare the right blood supply for you.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 32),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
            ),
            itemCount: bloodTypes.length,
            itemBuilder: (context, index) {
              final bloodType = bloodTypes[index];
              final isSelected = provider.bloodGroup == bloodType;

              return GestureDetector(
                onTap: () {
                  provider.setBloodGroup(bloodType);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF1FBF9A) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF1FBF9A)
                          : const Color(0xFFE5E7EB),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(
                                0xFF1FBF9A,
                              ).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: Text(
                      bloodType,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF1D2939),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 28),
          Text(
            'Height and weight',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F6F73),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMeasurementField(
                  controller: _heightController,
                  label: 'Height',
                  suffix: 'cm',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMeasurementField(
                  controller: _weightController,
                  label: 'Weight',
                  suffix: 'kg',
                  decimal: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Builder(
            builder: (context) {
              final bmi = _bmiPreview;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD7F3EA)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.monitor_heart_rounded,
                      color: Color(0xFF1FBF9A),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        bmi == null
                            ? 'BMI will be calculated after height and weight.'
                            : 'BMI ${bmi.toStringAsFixed(1)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F6F73),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementField({
    required TextEditingController controller,
    required String label,
    required String suffix,
    bool decimal = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      style: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        color: const Color(0xFF1D2939),
      ),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        labelStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF667085)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1FBF9A), width: 2),
        ),
      ),
    );
  }

  Widget _buildAllergiesPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 140,
              height: 140,
              decoration: const BoxDecoration(
                color: Color(0xFFF0FDF9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.health_and_safety_rounded,
                size: 64,
                color: Color(0xFF1FBF9A),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Any allergies?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F6F73),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Add medication, food, or material allergies doctors should know about.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 24),
          ...List.generate(_allergyNameControllers.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            size: 20,
                            color: Color(0xFF1FBF9A),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Allergy ${index + 1}',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F6F73),
                            ),
                          ),
                        ),
                        if (_allergyNameControllers.length > 1)
                          IconButton(
                            tooltip: 'Remove allergy',
                            onPressed: () => _removeAllergyFields(index),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF667085),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _allergyNameControllers[index],
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        color: const Color(0xFF1D2939),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Allergy name',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: const Color(0xFF9CA3AF),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF1FBF9A),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Severity',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1D2939),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildSeverityOption(
                          index: index,
                          value: 'légère',
                          label: 'Mild',
                        ),
                        _buildSeverityOption(
                          index: index,
                          value: 'modérée',
                          label: 'Moderate',
                        ),
                        _buildSeverityOption(
                          index: index,
                          value: 'sévère',
                          label: 'Severe',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        'Life-threatening',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1D2939),
                        ),
                      ),
                      subtitle: Text(
                        'Highlight this allergy for emergency care.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: const Color(0xFF667085),
                        ),
                      ),
                      activeThumbColor: const Color(0xFF1FBF9A),
                      activeTrackColor: const Color(0xFFD7F3EA),
                      value: _allergyLifeSafety[index],
                      onChanged: (value) {
                        setState(() => _allergyLifeSafety[index] = value);
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
          GestureDetector(
            onTap: () {
              setState(() {
                _addAllergyFields();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF1FBF9A).withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1FBF9A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.add, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Add Another Allergy',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1FBF9A),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: _clearAllergies,
              child: Text(
                'I don\'t have known allergies',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF667085),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSeverityOption({
    required int index,
    required String value,
    required String label,
  }) {
    final selected = _allergySeverities[index] == value;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _allergySeverities[index] = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1FBF9A) : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF1FBF9A) : const Color(0xFFE5E7EB),
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF1D2939),
          ),
        ),
      ),
    );
  }

  Widget _buildConditionsPage(UserOnboardingProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Illustration
          Center(
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF9),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Image.asset(
                  'assets/images/chronic_conditions.png',
                  width: 100,
                  height: 100,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.health_and_safety_rounded,
                      size: 60,
                      color: const Color(0xFF1FBF9A),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Any chronic conditions?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F6F73),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Doctors use this to ensure your treatment plan is 100% safe.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _searchController,
            onChanged: _filterConditions,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              color: const Color(0xFF1D2939),
            ),
            decoration: InputDecoration(
              hintText: 'Search conditions...',
              hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                color: const Color(0xFF9CA3AF),
              ),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF667085)),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF1FBF9A),
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (provider.chronicConditions.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: provider.chronicConditions.map((condition) {
                return Chip(
                  label: Text(
                    condition,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1FBF9A),
                    ),
                  ),
                  backgroundColor: const Color(
                    0xFF1FBF9A,
                  ).withValues(alpha: 0.1),
                  deleteIcon: const Icon(
                    Icons.close,
                    size: 18,
                    color: Color(0xFF1FBF9A),
                  ),
                  onDeleted: () {
                    provider.removeChronicCondition(condition);
                  },
                  side: const BorderSide(color: Color(0xFF1FBF9A)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _filteredConditions.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final condition = _filteredConditions[index];
                final isSelected = provider.chronicConditions.contains(
                  condition,
                );

                return ListTile(
                  title: Text(
                    condition,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1D2939),
                    ),
                  ),
                  trailing: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: isSelected
                        ? const Icon(
                            Icons.check_circle,
                            color: Color(0xFF1FBF9A),
                            key: ValueKey('selected'),
                          )
                        : const Icon(
                            Icons.circle_outlined,
                            color: Color(0xFFE5E7EB),
                            key: ValueKey('unselected'),
                          ),
                  ),
                  onTap: () {
                    if (isSelected) {
                      provider.removeChronicCondition(condition);
                    } else {
                      provider.addChronicCondition(condition);
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Illustration
          Center(
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF9),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Image.asset(
                  'assets/images/medications.png',
                  width: 100,
                  height: 100,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.medication_rounded,
                      size: 60,
                      color: const Color(0xFF1FBF9A),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Current Medications',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F6F73),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Add any medications you\'re currently taking 💊',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 24),
          // Medication chips/pills
          if (_medicationNameControllers.any(
            (controller) => controller.text.isNotEmpty,
          ))
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_medicationNameControllers.length, (i) {
                if (_medicationNameControllers[i].text.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('💊', style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _medicationNameControllers[i].text,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1FBF9A),
                          ),
                        ),
                      ),
                      if (_medicationDosageControllers[i].text.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '• ${_medicationDosageControllers[i].text}',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF667085),
                            ),
                          ),
                        ),
                      ],
                      if (_medicationDetails.length > i &&
                          _medicationDetails[i] != null) ...[
                        const SizedBox(width: 4),
                        Builder(
                          builder: (context) {
                            final d = _medicationDetails[i]!;
                            final parts = <String>[];
                            final form = (d.form ?? '').trim();
                            final dci = (d.dci ?? '').trim();
                            final type = (d.type ?? '').trim();
                            if (form.isNotEmpty) parts.add(form);
                            if (dci.isNotEmpty) parts.add(dci);
                            if (type.isNotEmpty) parts.add(type);
                            if (d.isSoluble) parts.add('Soluble');
                            if (parts.isEmpty) return const SizedBox.shrink();
                            return Flexible(
                              child: Text(
                                parts.join(' • '),
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: const Color(0xFF667085),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _removeMedicationFields(i),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Color(0xFF1FBF9A),
                        ),
                      ),
                    ],
                  ),
                );
              }).where((widget) => widget is! SizedBox).toList(),
            ),
          if (_medicationNameControllers.any(
            (controller) => controller.text.isNotEmpty,
          ))
            const SizedBox(height: 20),
          ...List.generate(_medicationNameControllers.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF1FBF9A).withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1FBF9A).withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '💊',
                            style: TextStyle(fontSize: 20),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Medication ${index + 1}',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0F6F73),
                            ),
                          ),
                        ),
                        if (_medicationNameControllers.length > 1)
                          IconButton(
                            tooltip: 'Remove medication',
                            onPressed: () => _removeMedicationFields(index),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Color(0xFF667085),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    MedicationSearchField(
                      controller: _medicationNameControllers[index],
                      dosageController: _medicationDosageControllers[index],
                      hintText: 'Medicine name (e.g., Aspirin)',
                      onSelected: (r) {
                        if (index >= 0 && index < _medicationIds.length) {
                          _medicationIds[index] = r.id;
                        }
                        if (index >= 0 && index < _medicationDetails.length) {
                          _medicationDetails[index] = r;
                        }
                        setState(() {});
                      },
                      onChanged: (_) {
                        if (index >= 0 && index < _medicationIds.length) {
                          _medicationIds[index] = null;
                        }
                        if (index >= 0 && index < _medicationDetails.length) {
                          _medicationDetails[index] = null;
                        }
                        setState(() {});
                      },
                    ),
                    if (_medicationDetails.length > index &&
                        _medicationDetails[index] != null) ...[
                      const SizedBox(height: 10),
                      Builder(
                        builder: (context) {
                          final d = _medicationDetails[index]!;
                          final parts = <String>[];
                          final form = (d.form ?? '').trim();
                          final dci = (d.dci ?? '').trim();
                          final type = (d.type ?? '').trim();
                          if (form.isNotEmpty) parts.add(form);
                          if (dci.isNotEmpty) parts.add(dci);
                          if (type.isNotEmpty) parts.add(type);
                          if (d.isSoluble) parts.add('Soluble');
                          if (parts.isEmpty) return const SizedBox.shrink();
                          return Text(
                            parts.join(' • '),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: const Color(0xFF667085),
                            ),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: _medicationDosageControllers[index],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: const Color(0xFF1D2939),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Dosage (e.g., 100mg, 2x daily)',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: const Color(0xFF9CA3AF),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF1FBF9A),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          // Add another button
          GestureDetector(
            onTap: () {
              setState(() {
                _addMedicationFields();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF1FBF9A).withValues(alpha: 0.3),
                  width: 1.5,
                  style: BorderStyle.solid,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1FBF9A),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.add, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Add Another Medication',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1FBF9A),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Skip option
          Center(
            child: TextButton(
              onPressed: () {
                setState(() {
                  for (var controller in _medicationNameControllers) {
                    controller.clear();
                  }
                  for (var controller in _medicationDosageControllers) {
                    controller.clear();
                  }
                });
              },
              child: Text(
                'I\'m not taking any medications',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF667085),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
