import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/family_models.dart';
import '../../../features/patient_clinic/presentation/clinic_directory_screen.dart';
import '../../../providers/family_provider.dart';
import '../../request_core/application/request_submission_controller.dart';

/// Step 1 — Who needs care?
///
/// Only SELF and owned FAMILY_MEMBER are offered. There is deliberately no
/// "Other Person" mode: a Module 05 request is for the account holder or one
/// of their own family members. Selection is explicit and drives a Continue
/// button — tapping "Me" never navigates on its own.
class WhoNeedsCareScreen extends StatefulWidget {
  const WhoNeedsCareScreen({super.key});

  @override
  State<WhoNeedsCareScreen> createState() => _WhoNeedsCareScreenState();
}

class _WhoNeedsCareScreenState extends State<WhoNeedsCareScreen> {
  FamilyMember? _selectedMember;

  @override
  void initState() {
    super.initState();
    final family = context.read<FamilyProvider>();
    if (!family.hasMembers) {
      family.loadFamilyMembers();
    }
  }

  void _continue(BuildContext context) {
    final request = context.read<RequestSubmissionController>();
    if (_selectedMember == null) {
      request.selectSelfSubject();
    } else {
      request.selectFamilyMemberSubject(_selectedMember!);
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ClinicDirectoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final family = context.watch<FamilyProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Who needs care?',
          style: TextStyle(
            color: Color(0xFF1D2939),
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: const BackButton(color: Color(0xFF1D2939)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SubjectTile(
                  icon: Icons.person_outline,
                  title: 'Me',
                  subtitle: 'Request care for myself.',
                  selected: _selectedMember == null,
                  onTap: () => setState(() => _selectedMember = null),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Family members',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 8),
                if (family.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (family.members.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No family members added yet.',
                      style: TextStyle(color: Color(0xFF667085)),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  for (final member in family.members)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SubjectTile(
                        icon: Icons.group_outlined,
                        title: member.fullName,
                        subtitle: _relationshipLabel(member.relationship),
                        selected: _selectedMember?.id == member.id,
                        onTap: () => setState(() => _selectedMember = member),
                      ),
                    ),
              ],
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x11000000),
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _continue(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1FBF9A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectTile extends StatelessWidget {
  const _SubjectTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? theme.colorScheme.primary : Colors.grey.withOpacity(0.18),
          width: selected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1FBF9A).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFF1FBF9A)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1D2939),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF667085),
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle, color: Color(0xFF1FBF9A)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _relationshipLabel(String relationship) {
  return FamilyRelationships.frenchLabel(relationship);
}
