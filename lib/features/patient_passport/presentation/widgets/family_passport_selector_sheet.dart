import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/omni_theme.dart';
import '../../models/patient_passport_view_models.dart';

const _selectionDuration = Duration(milliseconds: 200);

Future<PassportFamilyMember?> showFamilyPassportSelector(
  BuildContext context, {
  required List<PassportFamilyMember> familyMembers,
  required String selectedName,
}) {
  return showModalBottomSheet<PassportFamilyMember>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    barrierColor: Colors.black54,
    backgroundColor: Colors.transparent,
    builder: (_) => FamilyPassportSelectorSheet(
      familyMembers: familyMembers,
      selectedName: selectedName,
    ),
  );
}

class FamilyPassportSelectorSheet extends StatefulWidget {
  final List<PassportFamilyMember> familyMembers;
  final String selectedName;

  const FamilyPassportSelectorSheet({
    super.key,
    required this.familyMembers,
    required this.selectedName,
  });

  @override
  State<FamilyPassportSelectorSheet> createState() =>
      _FamilyPassportSelectorSheetState();
}

class _FamilyPassportSelectorSheetState
    extends State<FamilyPassportSelectorSheet> {
  late String _selectedName;
  bool _isCompletingSelection = false;

  @override
  void initState() {
    super.initState();
    _selectedName = widget.selectedName;
  }

  @override
  Widget build(BuildContext context) {
    final availableHeight = MediaQuery.sizeOf(context).height;
    final preferredHeight = (availableHeight * 0.58)
        .clamp(508.0, 540.0)
        .toDouble();
    final sheetHeight = math.min(availableHeight, preferredHeight);

    return SizedBox(
      height: sheetHeight,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: OmniColors.surfacePrimary,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(OmniRadii.sheet),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 56,
                height: 5,
                decoration: BoxDecoration(
                  color: OmniColors.borderStrong,
                  borderRadius: BorderRadius.circular(OmniRadii.pill),
                ),
              ),
              const SizedBox(height: 12),
              _SheetHeader(onClose: () => Navigator.of(context).pop()),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
                  child: _FamilyMemberGroup(
                    familyMembers: widget.familyMembers,
                    selectedName: _selectedName,
                    onSelected: _selectMember,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectMember(PassportFamilyMember member) async {
    if (_isCompletingSelection) return;

    if (member.name == _selectedName) {
      Navigator.of(context).pop(member);
      return;
    }

    _isCompletingSelection = true;
    setState(() => _selectedName = member.name);

    await Future<void>.delayed(_selectionDuration);
    if (mounted) Navigator.of(context).pop(member);
  }
}

class _SheetHeader extends StatelessWidget {
  final VoidCallback onClose;

  const _SheetHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 8, 0),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: OmniColors.mintSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Semantics(
              label: 'Passeport médical',
              child: SvgPicture.asset(
                'assets/svg/medical_pass_green.svg',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Passeports de la famille',
                    maxLines: 1,
                    softWrap: false,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: OmniColors.textPrimary,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Choisissez le passeport à consulter',
                    maxLines: 1,
                    softWrap: false,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: OmniColors.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Fermer',
            style: IconButton.styleFrom(
              minimumSize: const Size(44, 44),
              foregroundColor: OmniColors.textSecondary,
              iconSize: 24,
            ),
          ),
        ],
      ),
    );
  }
}

class _FamilyMemberGroup extends StatelessWidget {
  final List<PassportFamilyMember> familyMembers;
  final String selectedName;
  final ValueChanged<PassportFamilyMember> onSelected;

  const _FamilyMemberGroup({
    required this.familyMembers,
    required this.selectedName,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (familyMembers.isEmpty) {
      return const Center(child: Text('Aucun passeport disponible'));
    }

    final selectedIndex = familyMembers.indexWhere(
      (member) => member.name == selectedName,
    );
    final safeSelectedIndex = selectedIndex < 0 ? 0 : selectedIndex;

    return Container(
      decoration: BoxDecoration(
        color: OmniColors.surfacePrimary,
        border: Border.all(color: OmniColors.borderLight),
        borderRadius: BorderRadius.circular(OmniRadii.card),
      ),
      padding: const EdgeInsets.all(1),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(OmniRadii.card - 1),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const dividerHeight = 1.0;
            final dividerCount = familyMembers.length - 1;
            final rowHeight =
                (constraints.maxHeight - (dividerCount * dividerHeight)) /
                familyMembers.length;

            return Stack(
              children: [
                AnimatedPositioned(
                  duration: _selectionDuration,
                  curve: Curves.easeOutCubic,
                  left: 0,
                  right: 0,
                  top: safeSelectedIndex * (rowHeight + dividerHeight),
                  height: rowHeight,
                  child: const ColoredBox(color: OmniColors.mintSoft),
                ),
                Column(
                  children: [
                    for (
                      var index = 0;
                      index < familyMembers.length;
                      index++
                    ) ...[
                      Expanded(
                        child: _FamilyMemberRow(
                          member: familyMembers[index],
                          selected: index == safeSelectedIndex,
                          onTap: () => onSelected(familyMembers[index]),
                        ),
                      ),
                      if (index < familyMembers.length - 1)
                        const SizedBox(
                          height: dividerHeight,
                          child: ColoredBox(color: OmniColors.borderLight),
                        ),
                    ],
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FamilyMemberRow extends StatelessWidget {
  final PassportFamilyMember member;
  final bool selected;
  final VoidCallback onTap;

  const _FamilyMemberRow({
    required this.member,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              AnimatedContainer(
                duration: _selectionDuration,
                curve: Curves.easeOutCubic,
                width: 54,
                height: 54,
                padding: EdgeInsets.all(selected ? 3 : 0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? OmniColors.freshMint : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: Image.asset(
                    member.avatarAsset,
                    fit: BoxFit.cover,
                    cacheWidth: 160,
                    cacheHeight: 160,
                    errorBuilder: (_, _, _) => Container(
                      color: OmniColors.slateSoft,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.person_outline_rounded,
                        color: OmniColors.slateBlue,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: OmniColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      member.relationship,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: OmniColors.textSecondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: _selectionDuration,
                curve: Curves.easeOutCubic,
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected
                      ? OmniColors.primaryAction
                      : OmniColors.surfacePrimary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? OmniColors.primaryAction
                        : OmniColors.borderStrong,
                    width: selected ? 2 : 1.5,
                  ),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 140),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          key: ValueKey('selected'),
                          color: Colors.white,
                          size: 20,
                        )
                      : const SizedBox(key: ValueKey('unselected')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
