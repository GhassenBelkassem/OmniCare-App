import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/family_models.dart';
import '../../../core/theme/omni_theme.dart';
import '../../../providers/family_provider.dart';
import '../../../providers/user_provider.dart';
import '../../home/add_family_member_screen.dart';
import '../../request_flow/widgets/care_subject_card.dart';
import 'urgent_cabinet_care_subject.dart';
import 'urgent_cabinet_flow_controller.dart';
import 'urgent_cabinet_flow_routes.dart';
import 'urgent_cabinet_patient_lifecycle_controller.dart';

class UrgentCabinetCareSubjectScreen extends StatefulWidget {
  const UrgentCabinetCareSubjectScreen({
    super.key,
    this.onClose,
    this.nextRoute = UrgentCabinetFlowRoutes.doctorDirectory,
  });

  final VoidCallback? onClose;
  final String nextRoute;

  @override
  State<UrgentCabinetCareSubjectScreen> createState() =>
      _UrgentCabinetCareSubjectScreenState();
}

class _UrgentCabinetCareSubjectScreenState
    extends State<UrgentCabinetCareSubjectScreen> {
  bool _recovering = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final family = context.read<FamilyProvider>();
      if (!family.hasMembers) family.loadFamilyMembers();
    });
  }

  List<_CareSubjectOption> _subjectOptions() {
    final user = context.read<UserProvider>().user;
    final family = context.read<FamilyProvider>();

    return [
      _CareSubjectOption(
        id: 'me',
        name: user?.displayName.trim().isNotEmpty == true
            ? user!.displayName
            : user?.derivedFirstName ?? 'Moi',
        kind: _CareSubjectOptionKind.self,
        avatar: user?.avatar,
      ),
      ...family.members.map(
        (member) => _CareSubjectOption(
          id: member.id,
          name: member.fullName,
          kind: _CareSubjectOptionKind.familyMember,
          age: member.ageYears,
          relationship: member.relationship,
          avatar: member.photoUrl,
        ),
      ),
      const _CareSubjectOption(
        id: 'other',
        name: 'Autre personne',
        kind: _CareSubjectOptionKind.other,
      ),
    ];
  }

  bool _canProceed(
    UrgentCabinetCareSubject? subject,
    List<FamilyMember> members,
  ) {
    if (subject == null) return false;
    if (subject.isSelf) return true;
    return members.any((member) => member.id == subject.familyMemberId);
  }

  Future<void> _handleNext() async {
    final controller = context.read<UrgentCabinetFlowController>();
    final family = context.read<FamilyProvider>();
    final subject = controller.selectedSubject;
    if (_recovering || !_canProceed(subject, family.members)) return;

    final accountId = context.read<UserProvider>().profile?.userId.trim();
    final lifecycle = context.read<UrgentCabinetPatientLifecycleController?>();
    if (lifecycle != null &&
        accountId != null &&
        accountId.isNotEmpty &&
        subject != null) {
      setState(() => _recovering = true);
      final restored = await lifecycle.recover(
        accountId: accountId,
        subject: subject,
      );
      if (!mounted) return;
      setState(() => _recovering = false);
      if (restored ||
          lifecycle.phase != UrgentCabinetPatientLifecyclePhase.idle) {
        return;
      }
    }

    await Navigator.of(context).pushNamed<void>(widget.nextRoute);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FamilyProvider>();
    final userProvider = context.watch<UserProvider>();
    final controller = context.watch<UrgentCabinetFlowController>();
    final options = _subjectOptions();
    final canProceed = _canProceed(
      controller.selectedSubject,
      context.read<FamilyProvider>().members,
    );
    final textTheme = Theme.of(context).textTheme;
    final currentAccountId = userProvider.profile?.userId;

    if (controller.accountId != currentAccountId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<UrgentCabinetFlowController>().ensureAccount(
          context.read<UserProvider>().profile?.userId,
        );
      });
    }

    return GestureDetector(
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
                  onPressed:
                      widget.onClose ?? () => Navigator.maybePop(context),
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
                    child: _buildSubjectCard(
                      option,
                      controller.selectedSubject,
                    ),
                  ),
                ),
                const SizedBox(height: OmniSpacing.md),
              ],
            ),
          ),
          _ContinueFooter(
            onPressed: canProceed && !_recovering ? _handleNext : null,
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(
    _CareSubjectOption option,
    UrgentCabinetCareSubject? selectedSubject,
  ) {
    final selected = switch (option.kind) {
      _CareSubjectOptionKind.self => selectedSubject?.isSelf == true,
      _CareSubjectOptionKind.familyMember =>
        selectedSubject?.type == UrgentCabinetCareSubjectType.familyMember &&
            selectedSubject?.familyMemberId == option.id,
      _CareSubjectOptionKind.other => false,
    };
    final subtitle = switch (option.kind) {
      _CareSubjectOptionKind.self => 'Demande pour moi',
      _CareSubjectOptionKind.familyMember => _familySubtitle(option),
      _CareSubjectOptionKind.other =>
        "Pour quelqu'un qui n'est pas dans votre famille",
    };

    return CareSubjectCard(
      compact: true,
      title: option.name,
      subtitle: subtitle,
      selected: selected,
      onTap: switch (option.kind) {
        _CareSubjectOptionKind.self =>
          context.read<UrgentCabinetFlowController>().selectSelf,
        _CareSubjectOptionKind.familyMember =>
          () => context.read<UrgentCabinetFlowController>().selectFamilyMember(
            option.id,
          ),
        _CareSubjectOptionKind.other => _openFamilyMemberCreation,
      },
      avatarId: option.id,
      photoUrl: option.avatar,
      isSelf: option.kind == _CareSubjectOptionKind.self,
      fallbackIcon: option.kind == _CareSubjectOptionKind.other
          ? Icons.person_add_outlined
          : null,
    );
  }

  String _familySubtitle(_CareSubjectOption option) {
    final relationship = option.relationship == null
        ? 'Membre de la famille'
        : FamilyRelationships.frenchLabel(option.relationship!);
    return option.age == null
        ? relationship
        : '$relationship · ${option.age} ans';
  }

  Future<void> _openFamilyMemberCreation() async {
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
    if (newMember != null) {
      context.read<UrgentCabinetFlowController>().selectFamilyMember(
        newMember.id,
      );
    }
  }
}

enum _CareSubjectOptionKind { self, familyMember, other }

class _CareSubjectOption {
  const _CareSubjectOption({
    required this.id,
    required this.name,
    required this.kind,
    this.age,
    this.relationship,
    this.avatar,
  });

  final String id;
  final String name;
  final _CareSubjectOptionKind kind;
  final int? age;
  final String? relationship;
  final String? avatar;
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
              onPressed: onPressed,
              child: const Text('Continuer'),
            ),
          ),
        ),
      ),
    );
  }
}
