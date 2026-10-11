import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/family_models.dart';
import '../../core/theme/omni_theme.dart';
import '../../features/home/add_family_member_screen.dart';
import '../../providers/family_provider.dart';
import '../../providers/user_provider.dart';
import '../request_flow/widgets/care_subject_card.dart';
import 'urgent_flow_mode.dart';

class PatientOption {
  const PatientOption({
    required this.id,
    required this.name,
    required this.type,
    this.age,
    this.relationship,
    this.avatar,
  });

  final String id;
  final String name;
  final String type; // 'me', 'family', 'other'
  final int? age;
  final String? relationship;
  final String? avatar;
}

class EmergencyRequestStep1 extends StatefulWidget {
  const EmergencyRequestStep1({
    super.key,
    this.flowMode = UrgentFlowMode.create,
    this.initialData,
    this.patientOptions,
    this.initialSelectedPatientId,
    this.onClose,
    this.onContinue,
    this.onSelectionChanged,
    this.onAddPerson,
    this.errorText,
  });

  final UrgentFlowMode flowMode;
  final Map<String, dynamic>? initialData;

  /// Optional presentation-only subject choices.
  ///
  /// When provided, this screen never reads [UserProvider] or
  /// [FamilyProvider] and never treats an application Patient identifier as
  /// journey authority. The P4 coordinator uses this seam with opaque,
  /// synthetic subject references while preserving the approved screen.
  final List<PatientOption>? patientOptions;
  final String? initialSelectedPatientId;
  final VoidCallback? onClose;
  final ValueChanged<PatientOption>? onContinue;
  final ValueChanged<PatientOption?>? onSelectionChanged;
  final VoidCallback? onAddPerson;
  final String? errorText;

  @override
  State<EmergencyRequestStep1> createState() => _EmergencyRequestStep1State();
}

class _EmergencyRequestStep1State extends State<EmergencyRequestStep1> {
  String? _selectedPatientId;

  @override
  void initState() {
    super.initState();
    _selectedPatientId =
        widget.initialSelectedPatientId ??
        widget.initialData?['patientId'] as String?;
    if (widget.patientOptions != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final family = context.read<FamilyProvider>();
      if (!family.hasMembers) family.loadFamilyMembers();
    });
  }

  List<PatientOption> _patientOptions() {
    final injected = widget.patientOptions;
    if (injected != null) return List<PatientOption>.unmodifiable(injected);

    final user = context.read<UserProvider>().user;
    final family = context.read<FamilyProvider>();

    return [
      PatientOption(
        id: 'me',
        name: user?.displayName.trim().isNotEmpty == true
            ? user!.displayName
            : user?.derivedFirstName ?? 'Moi',
        type: 'me',
        avatar: user?.avatar,
      ),
      ...family.members.map(
        (member) => PatientOption(
          id: member.id,
          name: member.fullName,
          type: 'family',
          age: member.ageYears,
          relationship: member.relationship,
          avatar: member.photoUrl,
        ),
      ),
      PatientOption(id: 'other', name: 'Autre personne', type: 'other'),
    ];
  }

  bool _canProceed() {
    return _selectedPatientId != null &&
        _patientOptions().any((option) => option.id == _selectedPatientId);
  }

  void _handleNext() {
    if (!_canProceed()) return;

    final selectedOption = _patientOptions().firstWhere(
      (option) => option.id == _selectedPatientId,
    );
    final onContinue = widget.onContinue;
    if (onContinue != null) {
      onContinue(selectedOption);
      return;
    }

    final routeArgs =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final providerType =
        routeArgs?['providerType'] as String? ??
        widget.initialData?['providerType'] as String? ??
        'doctor';
    final consultationType =
        routeArgs?['consultationType'] as String? ??
        widget.initialData?['consultationType'] as String? ??
        'home';

    String? backendPatientId;
    if (selectedOption.type == 'family') {
      final family = context.read<FamilyProvider>();
      final familyMember = family.members.firstWhere(
        (member) => member.id == _selectedPatientId,
        orElse: () => family.members.first,
      );
      backendPatientId = familyMember.patientId;
    }

    final data = {
      if (widget.initialData != null) ...widget.initialData!,
      'patientId': _selectedPatientId,
      'backendPatientId': backendPatientId,
      'patientName': selectedOption.name,
      'patientType': selectedOption.type,
      'age': selectedOption.age,
      if (selectedOption.relationship != null)
        'relationship': selectedOption.relationship,
      'providerType': providerType,
      'consultationType': consultationType,
    };

    if (widget.flowMode == UrgentFlowMode.editFromReview) {
      Navigator.pop(context, data);
      return;
    }
    Navigator.pushNamed(context, '/emergency-step2', arguments: data);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.patientOptions == null) context.watch<FamilyProvider>();
    final options = _patientOptions();
    final canProceed = _canProceed();
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      key: const ValueKey('emergency-step1-page-surface'),
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Fermer',
                  icon: const Icon(Icons.close, color: OmniColors.textPrimary),
                  onPressed: widget.onClose ?? () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    'Demande urgente',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleLarge?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: OmniColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                OmniSpacing.pageHorizontal,
                OmniSpacing.lg,
                OmniSpacing.pageHorizontal,
                OmniSpacing.xxl,
              ),
              children: [
                Text(
                  'Qui a besoin de soins ?',
                  style: textTheme.headlineSmall?.copyWith(
                    fontSize: 26,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: OmniColors.textPrimary,
                    letterSpacing: -0.45,
                  ),
                ),
                const SizedBox(height: OmniSpacing.sm),
                Text(
                  'Choisissez la personne concernée par cette demande.',
                  style: textTheme.bodyLarge?.copyWith(
                    fontSize: 15,
                    height: 1.45,
                    color: OmniColors.textSecondary,
                  ),
                ),
                const SizedBox(height: OmniSpacing.xl),
                ...options.map(
                  (option) => Padding(
                    padding: const EdgeInsets.only(bottom: OmniSpacing.sm),
                    child: _buildPatientOptionCard(option),
                  ),
                ),
                if (widget.errorText?.isNotEmpty == true) ...[
                  const SizedBox(height: OmniSpacing.sm),
                  Text(
                    widget.errorText!,
                    key: const ValueKey('emergency-subject-safe-error'),
                    style: textTheme.bodySmall?.copyWith(
                      color: OmniColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: OmniSpacing.md),
              ],
            ),
          ),
          _ContinueFooter(onPressed: canProceed ? _handleNext : null),
        ],
      ),
    );
  }

  Widget _buildPatientOptionCard(PatientOption option) {
    final subtitle = switch (option.type) {
      'me' => 'Demande pour moi',
      'family' => _familySubtitle(option),
      _ => "Pour quelqu'un qui n'est pas dans votre famille",
    };

    return CareSubjectCard(
      key: ValueKey('emergency-subject-${option.id}'),
      compact: true,
      title: option.name,
      subtitle: subtitle,
      selected: _selectedPatientId == option.id,
      onTap: option.type == 'other'
          ? _openFamilyMemberCreation
          : () => setState(() {
              _selectedPatientId = option.id;
              widget.onSelectionChanged?.call(option);
            }),
      avatarId: option.id,
      photoUrl: option.avatar,
      isSelf: option.type == 'me',
      fallbackIcon: option.type == 'other' ? Icons.person_add_outlined : null,
    );
  }

  String _familySubtitle(PatientOption option) {
    final relationship = option.relationship == null
        ? 'Membre de la famille'
        : FamilyRelationships.frenchLabel(option.relationship!);
    return option.age == null
        ? relationship
        : '$relationship · ${option.age} ans';
  }

  Future<void> _openFamilyMemberCreation() async {
    final onAddPerson = widget.onAddPerson;
    if (onAddPerson != null) {
      onAddPerson();
      return;
    }
    if (widget.patientOptions != null) return;

    final family = context.read<FamilyProvider>();
    final existingIds = family.members.map((member) => member.id).toSet();
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.94,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(OmniRadii.cardLarge),
          ),
          child: const AddFamilyMemberScreen(
            title: 'Ajouter un proche',
            submitLabel: 'Ajouter',
            modal: true,
          ),
        ),
      ),
    );
    if (!mounted || created != true) return;

    FamilyMember? newMember;
    for (final member in family.members.reversed) {
      if (!existingIds.contains(member.id)) {
        newMember = member;
        break;
      }
    }
    final createdMember = newMember;
    if (createdMember == null) return;

    setState(() => _selectedPatientId = createdMember.id);
  }
}

class _ContinueFooter extends StatelessWidget {
  const _ContinueFooter({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: OmniColors.surfacePrimary,
        border: Border(top: BorderSide(color: OmniColors.borderLight)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            OmniSpacing.pageHorizontal,
            OmniSpacing.md,
            OmniSpacing.pageHorizontal,
            OmniSpacing.md,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              key: const ValueKey('emergency-subject-continue'),
              onPressed: onPressed,
              child: const Text('Continuer'),
            ),
          ),
        ),
      ),
    );
  }
}
