import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/user_onboarding_provider.dart';

class VitalInfoScreen extends StatefulWidget {
  const VitalInfoScreen({super.key});

  @override
  State<VitalInfoScreen> createState() => _VitalInfoScreenState();
}

class _VitalInfoScreenState extends State<VitalInfoScreen> {
  final List<String> bloodGroups = [
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

  final TextEditingController _searchController = TextEditingController();
  List<String> _filteredConditions = [];

  @override
  void initState() {
    super.initState();
    _filteredConditions = availableConditions;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<UserOnboardingProvider>(context);

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
          'Medical Profile',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1D2939),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/home');
            },
            child: Text(
              'Skip for now',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1FBF9A),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1FBF9A),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '1',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Vital Information',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F6F73),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Step 1 of 3',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: const Color(0xFF667085),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Blood Group',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1D2939),
                ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                ),
                itemCount: bloodGroups.length,
                itemBuilder: (context, index) {
                  final bloodGroup = bloodGroups[index];
                  final isSelected = provider.bloodGroup == bloodGroup;

                  return GestureDetector(
                    onTap: () {
                      provider.setBloodGroup(bloodGroup);
                    },
                    child: Container(
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
                      ),
                      child: Center(
                        child: Text(
                          bloodGroup,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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
              const SizedBox(height: 32),
              Text(
                'Chronic Conditions',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1D2939),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select all that apply',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: const Color(0xFF667085),
                ),
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
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
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
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
                          color: const Color(0xFF1D2939),
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_circle,
                              color: Color(0xFF1FBF9A),
                            )
                          : const Icon(
                              Icons.circle_outlined,
                              color: Color(0xFFE5E7EB),
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
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/medications');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1FBF9A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Continue',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
