import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../providers/user_onboarding_provider.dart';

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

  final List<String> bloodTypes = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
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
  }

  void _removeMedicationFields(int index) {
    if (_medicationNameControllers.length > 1) {
      _medicationNameControllers[index].dispose();
      _medicationDosageControllers[index].dispose();
      setState(() {
        _medicationNameControllers.removeAt(index);
        _medicationDosageControllers.removeAt(index);
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

  void _completeOnboarding() {
    final provider = Provider.of<UserOnboardingProvider>(context, listen: false);

    for (int i = 0; i < _medicationNameControllers.length; i++) {
      if (_medicationNameControllers[i].text.isNotEmpty &&
          _medicationDosageControllers[i].text.isNotEmpty) {
        provider.addMedication(
          MedicationEntry(
            name: _medicationNameControllers[i].text,
            dosage: _medicationDosageControllers[i].text,
            frequency: '1x daily',
          ),
        );
      }
    }

    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<UserOnboardingProvider>(context);

    return Scaffold(
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
                    onPressed: _nextPage,
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
    );
  }

  Widget _buildBloodTypePage(UserOnboardingProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          const SizedBox(height: 48),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
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
          const SizedBox(height: 32),
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
            'Knowing your current meds prevents dangerous drug-to-drug interactions.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 32),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _medicationNameControllers.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Medication ${index + 1}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F6F73),
                          ),
                        ),
                        if (_medicationNameControllers.length > 1)
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Color(0xFFDC2626),
                            ),
                            onPressed: () => _removeMedicationFields(index),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _medicationNameControllers[index],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        color: const Color(0xFF1D2939),
                      ),
                      decoration: InputDecoration(
                        labelText: 'Medicine Name',
                        labelStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: const Color(0xFF667085),
                        ),
                        hintText: 'e.g., Aspirin',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          color: const Color(0xFF9CA3AF),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF4F5F7),
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
                    const SizedBox(height: 12),
                    TextField(
                      controller: _medicationDosageControllers[index],
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        color: const Color(0xFF1D2939),
                      ),
                      decoration: InputDecoration(
                        labelText: 'Dosage',
                        labelStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: const Color(0xFF667085),
                        ),
                        hintText: 'e.g., 100mg',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          color: const Color(0xFF9CA3AF),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF4F5F7),
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
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _addMedicationFields();
              });
            },
            icon: const Icon(Icons.add, color: Color(0xFF1FBF9A)),
            label: Text(
              'Add Another Medication',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1FBF9A),
              ),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              side: const BorderSide(color: Color(0xFF1FBF9A)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
