import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/models/family_models.dart';
import '../../../core/theme/omni_theme.dart';
import '../../../features/home/add_family_member_screen.dart';
import '../../../features/patient_clinic/presentation/clinic_directory_screen.dart';
import '../../../features/patient_doctor/presentation/doctor_directory_screen.dart';
import '../../../providers/family_provider.dart';
import '../../request_core/application/request_submission_controller.dart';
import '../../request_core/domain/request_vocabulary.dart';
import '../widgets/care_subject_card.dart';

/// Step 1 — Who needs care?
///
/// Profile-grid interaction adapted to healthcare:
/// - SELF is always the first profile
/// - Family members follow
/// - "Add family member" tile completes the grid
/// - Selection is local; Continue commits the choice
class WhoNeedsCareScreen extends StatefulWidget {
  const WhoNeedsCareScreen({super.key, this.requestKind = RequestKind.clinic});

  final RequestKind requestKind;

  @override
  State<WhoNeedsCareScreen> createState() => _WhoNeedsCareScreenState();
}

class _WhoNeedsCareScreenState extends State<WhoNeedsCareScreen> {
  FamilyMember? _selectedMember;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final family = context.read<FamilyProvider>();
      if (!family.hasMembers) {
        family.loadFamilyMembers();
      }
    });
  }

  void _continue() {
    final request = context.read<RequestSubmissionController>();

    if (_selectedMember == null) {
      request.selectSelfSubject();
    } else {
      request.selectFamilyMemberSubject(_selectedMember!);
    }

    if (widget.requestKind == RequestKind.doctor) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const DoctorDirectoryScreen()));
    } else {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ClinicDirectoryScreen()));
    }
  }

  Future<void> _openAddFamilyMember() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddFamilyMemberScreen()),
    );
    if (result == true && mounted) {
      context.read<FamilyProvider>().loadFamilyMembers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final family = context.watch<FamilyProvider>();
    final textTheme = Theme.of(context).textTheme;

    final tiles = <_GridItem>[
      _GridItem.self(),
      ...family.members.map(_GridItem.member),
      _GridItem.addFamily(),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  size: 24,
                  color: OmniColors.textPrimary,
                ),
              ),
              Expanded(
                child: Text(
                  'Who needs care?',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleLarge?.copyWith(
                    fontSize: 26,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: OmniColors.textPrimary,
                    letterSpacing: -0.45,
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
              OmniSpacing.sm,
              OmniSpacing.pageHorizontal,
              OmniSpacing.xxl,
            ),
            children: [
              Text(
                'Choose who this request is for.',
                style: textTheme.bodyMedium?.copyWith(
                  fontSize: 15,
                  height: 1.5,
                  color: OmniColors.textSecondary,
                ),
              ),
              const SizedBox(height: OmniSpacing.xl),
              _ProfileGrid(
                items: tiles,
                selectedId: _selectedMember?.id,
                onSelfTap: () {
                  setState(() {
                    _selectedMember = null;
                  });
                },
                onMemberTap: (member) {
                  setState(() {
                    _selectedMember = member;
                  });
                },
                onAddTap: _openAddFamilyMember,
              ),
            ],
          ),
        ),
        _ContinueFooter(onPressed: _continue),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Grid item model
// ---------------------------------------------------------------------------

enum _GridItemKind { self_, member, addFamily }

class _GridItem {
  const _GridItem._({required this.kind, this.member});

  const _GridItem.self() : this._(kind: _GridItemKind.self_);

  const _GridItem.member(FamilyMember m)
    : this._(kind: _GridItemKind.member, member: m);

  const _GridItem.addFamily() : this._(kind: _GridItemKind.addFamily);

  final _GridItemKind kind;
  final FamilyMember? member;

  bool get isSelf => kind == _GridItemKind.self_;
  bool get isAdd => kind == _GridItemKind.addFamily;
}

// ---------------------------------------------------------------------------
// Profile grid
// ---------------------------------------------------------------------------

class _ProfileGrid extends StatelessWidget {
  const _ProfileGrid({
    required this.items,
    required this.selectedId,
    required this.onSelfTap,
    required this.onMemberTap,
    required this.onAddTap,
  });

  final List<_GridItem> items;
  final String? selectedId;
  final VoidCallback onSelfTap;
  final ValueChanged<FamilyMember> onMemberTap;
  final VoidCallback onAddTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = OmniSpacing.lg;
        final tileWidth = (constraints.maxWidth - gap) / 2;

        return Wrap(
          spacing: gap,
          runSpacing: OmniSpacing.xl,
          children: items.map((item) {
            return SizedBox(
              width: tileWidth,
              child: item.isAdd
                  ? _AddFamilyTile(onTap: onAddTap)
                  : _ProfileTile(
                      item: item,
                      selected: item.isSelf
                          ? selectedId == null
                          : selectedId == item.member?.id,
                      onTap: () {
                        if (item.isSelf) {
                          onSelfTap();
                        } else if (item.member != null) {
                          onMemberTap(item.member!);
                        }
                      },
                    ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Profile tile
// ---------------------------------------------------------------------------

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _GridItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = item.isSelf ? 'Me' : item.member!.fullName;
    final subtitle = item.isSelf
        ? 'My care request'
        : _relationshipLabel(item.member!.relationship);

    return CareSubjectCard(
      title: name,
      subtitle: subtitle,
      selected: selected,
      onTap: onTap,
      avatarId: item.member?.id,
      photoUrl: item.member?.photoUrl,
      isSelf: item.isSelf,
    );
  }
}

const double _avatarSize = 120;
const double _avatarRadius = 24;

// ---------------------------------------------------------------------------
// Add family member tile
// ---------------------------------------------------------------------------

class _AddFamilyTile extends StatelessWidget {
  const _AddFamilyTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add family member',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _avatarSize,
              height: _avatarSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_avatarRadius),
                color: Colors.white,
                border: Border.all(color: OmniColors.borderStrong, width: 1.5),
              ),
              child: Icon(
                Icons.add_rounded,
                size: 32,
                color: OmniColors.slateBlue,
              ),
            ),
            const SizedBox(height: OmniSpacing.sm),
            Text(
              'Add family member',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 15,
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: OmniColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              ' ',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Continue footer
// ---------------------------------------------------------------------------

class _ContinueFooter extends StatelessWidget {
  const _ContinueFooter({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
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
              child: const Text('Continue'),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _relationshipLabel(String relationship) {
  return FamilyRelationships.frenchLabel(relationship);
}
