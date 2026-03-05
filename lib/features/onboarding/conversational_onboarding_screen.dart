import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../providers/user_onboarding_provider.dart';
import '../../providers/user_provider.dart';
import '../../core/api/account_api.dart';
import '../../core/api/api_error_utils.dart';
import '../../core/utils/logger.dart';
import '../../core/widgets/medication_search_field.dart';
import 'onboarding_complete_screen.dart';

class ConversationalOnboardingScreen extends StatefulWidget {
  const ConversationalOnboardingScreen({super.key});

  @override
  State<ConversationalOnboardingScreen> createState() =>
      _ConversationalOnboardingScreenState();
}

class _ConversationalOnboardingScreenState
    extends State<ConversationalOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _saving = false;

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
  final List<TextEditingController> _medicationNameControllers = [];
  final List<TextEditingController> _medicationDosageControllers = [];
  final List<String?> _medicationIds = [];

  @override
  void initState() {
    super.initState();
    _filteredConditions = availableConditions;
    _addMedicationFields();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
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
  }

  void _removeMedicationFields(int index) {
    if (_medicationNameControllers.length > 1) {
      _medicationNameControllers[index].dispose();
      _medicationDosageControllers[index].dispose();
      setState(() {
        _medicationNameControllers.removeAt(index);
        _medicationDosageControllers.removeAt(index);
        _medicationIds.removeAt(index);
      });
    }
  }

  void _filterConditions(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredConditions = availableConditions;
      } else {
        _filteredConditions = availableConditions
            .where((condition) =>
                condition.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    final provider = Provider.of<UserOnboardingProvider>(context, listen: false);

    provider.medications.clear();

    for (int i = 0; i < _medicationNameControllers.length; i++) {
      final name = _medicationNameControllers[i].text.trim();
      final dosage = _medicationDosageControllers[i].text.trim();
      final medId = _medicationIds[i];
      final hasAnyInput = name.isNotEmpty || dosage.isNotEmpty;
      if (!hasAnyInput) continue;

      if (medId == null || medId.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a medication from the list.')),
        );
        return;
      }

      if (dosage.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a dosage for the selected medication.')),
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
      final medicalInfo = <String, dynamic>{
        'chronicConditions': provider.chronicConditions,
        'currentMedications': provider.medications
            .where((m) => (m.medicationId ?? '').trim().isNotEmpty)
            .map((m) => {
                  'medicationId': m.medicationId,
                  'dosage': m.dosage,
                  'frequency': m.frequency,
                })
            .toList(),
      };

      await AccountApi().patchMedicalPassport(
        bloodGroup: provider.bloodGroup,
        medicalInfo: medicalInfo,
      );

      if (!mounted) return;
      await context.read<UserProvider>().refresh();
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

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const OnboardingCompleteScreen(),
      ),
    );
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
                      icon: const Icon(Icons.arrow_back, color: Color(0xFF1D2939)),
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
                      _buildBloodTypePage(provider),
                      _buildConditionsPage(provider),
                      _buildMedicationsPage(provider),
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
                        count: 3,
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
                            _currentPage == 2 ? 'Complete' : 'Continue',
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
                color: Colors.black.withOpacity(0.2),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
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
                    color: isSelected
                        ? const Color(0xFF1FBF9A)
                        : Colors.white,
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
                              color: const Color(0xFF1FBF9A).withOpacity(0.3),
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
        ],
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
                  backgroundColor: const Color(0xFF1FBF9A).withOpacity(0.1),
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
                final isSelected =
                    provider.chronicConditions.contains(condition);

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

  Widget _buildMedicationsPage(UserOnboardingProvider provider) {
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
          if (_medicationNameControllers.any((controller) => controller.text.isNotEmpty))
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_medicationNameControllers.length, (index) {
                if (_medicationNameControllers[index].text.isEmpty) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1FBF9A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF1FBF9A)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '💊',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _medicationNameControllers[index].text,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1FBF9A),
                        ),
                      ),
                      if (_medicationDosageControllers[index].text.isNotEmpty) ...[
                        const SizedBox(width: 4),
                        Text(
                          '• ${_medicationDosageControllers[index].text}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF667085),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _removeMedicationFields(index),
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
          if (_medicationNameControllers.any((controller) => controller.text.isNotEmpty))
            const SizedBox(height: 20),
          // Simple input card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1FBF9A).withOpacity(0.3), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1FBF9A).withOpacity(0.08),
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
                      child: const Text('💊', style: TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Add a medication',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F6F73),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                MedicationSearchField(
                  controller: _medicationNameControllers.last,
                  dosageController: _medicationDosageControllers.last,
                  hintText: 'Medicine name (e.g., Aspirin)',
                  onSelected: (r) {
                    final idx = _medicationNameControllers.length - 1;
                    if (idx >= 0 && idx < _medicationIds.length) {
                      _medicationIds[idx] = r.id;
                    }
                    setState(() {});
                  },
                  onChanged: (_) {
                    final idx = _medicationNameControllers.length - 1;
                    if (idx >= 0 && idx < _medicationIds.length) {
                      _medicationIds[idx] = null;
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _medicationDosageControllers.last,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    color: const Color(0xFF1D2939),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Dosage (e.g., 100mg, 2x daily)',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      color: const Color(0xFF9CA3AF),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  color: const Color(0xFF1FBF9A).withOpacity(0.3),
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
                    child: const Icon(
                      Icons.add,
                      size: 16,
                      color: Colors.white,
                    ),
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
