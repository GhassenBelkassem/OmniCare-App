import 'package:flutter/material.dart';

import '../../../../core/theme/omni_theme.dart';
import '../../data/patient_clinic_models.dart';
import '../clinic_filter_model.dart';
import '../clinic_presentation_metadata.dart';

/// Semantic accent for one filter category.
///
/// Each category owns its color family so the sheet stays meaningful without
/// showing five saturated colors: mostly soft backgrounds, then a colored
/// border/icon/text only on the selected chip.
class _FilterAccent {
  const _FilterAccent({
    required this.active,
    required this.soft,
  });

  final Color active;
  final Color soft;
}

abstract final class _FilterAccents {
  /// Care need → clinical cyan.
  static const careNeed = _FilterAccent(
    active: OmniColors.clinicalCyan,
    soft: OmniColors.clinicalCyanSoft,
  );

  /// Specialty → identity/clinical-profile treatment.
  static const specialty = _FilterAccent(
    active: OmniColors.violet,
    soft: OmniColors.violetSoft,
  );

  /// Location / city → information blue.
  static const location = _FilterAccent(
    active: OmniColors.infoBlue,
    soft: OmniColors.infoBlueSoft,
  );

  /// Distance → information blue (shared with location).
  static const distance = _FilterAccent(
    active: OmniColors.infoBlue,
    soft: OmniColors.infoBlueSoft,
  );

  /// Accepting requests → brand availability mint.
  static const accepting = _FilterAccent(
    active: OmniColors.freshMint,
    soft: OmniColors.mintSoft,
  );

  /// Clinic type → structural slate.
  static const clinicType = _FilterAccent(
    active: OmniColors.slateBlue,
    soft: OmniColors.slateSoft,
  );

  /// Services → clinical cyan.
  static const services = _FilterAccent(
    active: OmniColors.clinicalCyan,
    soft: OmniColors.clinicalCyanSoft,
  );
}

/// Opens the clinic filter bottom sheet.
///
/// Returns the committed [ClinicFilterSnapshot], or `null` when the patient
/// dismisses without applying. The sheet edits a local draft; the directory
/// only updates after Apply.
Future<ClinicFilterSnapshot?> showClinicFilterSheet({
  required BuildContext context,
  required ClinicFilterOptions options,
  required List<PatientClinicListItem> items,
  ClinicFilterSnapshot initial = ClinicFilterSnapshot.none,
}) {
  return showModalBottomSheet<ClinicFilterSnapshot>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 380),
      reverseDuration: Duration(milliseconds: 220),
    ),
    builder: (context) => ClinicFilterSheet(
      options: options,
      items: items,
      initial: initial,
    ),
  );
}

/// Modal bottom sheet for the directory's presentation filters.
///
/// White surface, rounded top, drag handle, tap-outside and swipe-down dismiss,
/// internal scrolling, and a pinned Reset / Apply footer. No change is applied
/// to the directory until Apply is pressed.
class ClinicFilterSheet extends StatefulWidget {
  const ClinicFilterSheet({
    super.key,
    required this.options,
    required this.items,
    this.initial = ClinicFilterSnapshot.none,
  });

  final ClinicFilterOptions options;
  final List<PatientClinicListItem> items;
  final ClinicFilterSnapshot initial;

  @override
  State<ClinicFilterSheet> createState() => _ClinicFilterSheetState();
}

class _ClinicFilterSheetState extends State<ClinicFilterSheet> {
  late ClinicFilterSnapshot _draft = widget.initial;
  bool _showMoreFilters = false;

  void _reset() {
    setState(() {
      _draft = ClinicFilterSnapshot.none;
      _showMoreFilters = false;
    });
  }

  Future<void> _openSpecialtySelector() async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 380),
        reverseDuration: Duration(milliseconds: 220),
      ),
      builder: (_) => _SpecialtySelectorSheet(
        selected: _draft.specialties,
      ),
    );
    if (result != null) {
      setState(() {
        _draft = _draft.copyWith(specialties: result);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final modalHeight = MediaQuery.sizeOf(context).height;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: modalHeight * 0.62,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetHeader(onClose: () => Navigator.of(context).pop()),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  OmniSpacing.pageHorizontal,
                  OmniSpacing.base,
                  OmniSpacing.pageHorizontal,
                  OmniSpacing.base,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 1. What do you need? ──────────────────────────
                    _FilterSection(
                      title: 'What do you need?',
                      icon: Icons.medical_services_outlined,
                      accent: _FilterAccents.careNeed,
                      child: _ChoiceWrap(
                        accent: _FilterAccents.careNeed,
                        options: CareNeedOptions.values,
                        selected: _draft.careNeeds,
                        onChanged: (next) {
                          setState(() {
                            _draft = _draft.copyWith(careNeeds: next);
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: OmniSpacing.xl),

                    // ── 2. Medical specialty ──────────────────────────
                    _FilterSection(
                      title: 'Medical specialty',
                      icon: Icons.local_hospital_outlined,
                      accent: _FilterAccents.specialty,
                      child: _SpecialtySelectorTrigger(
                        selected: _draft.specialties,
                        onTap: _openSpecialtySelector,
                        onRemove: (specialty) {
                          setState(() {
                            final next = Set<String>.of(_draft.specialties)
                              ..remove(specialty);
                            _draft = _draft.copyWith(
                              specialties: Set.unmodifiable(next),
                            );
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: OmniSpacing.xl),

                    // ── 3. Location ──────────────────────────────────
                    _FilterSection(
                      title: 'Location',
                      icon: Icons.location_on_outlined,
                      accent: _FilterAccents.location,
                      child: _LocationSelector(
                        cities: widget.options.cities,
                        selected: _draft.cities,
                        onChanged: (next) {
                          setState(() {
                            _draft = _draft.copyWith(cities: next);
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: OmniSpacing.xl),

                    // ── 4. Distance ──────────────────────────────────
                    _FilterSection(
                      title: 'Distance',
                      icon: Icons.near_me_outlined,
                      accent: _FilterAccents.distance,
                      child: _DistanceChips(
                        selected: _draft.distance,
                        onChanged: (value) {
                          setState(() {
                            if (value == null) {
                              _draft = _draft.copyWith(clearDistance: true);
                            } else {
                              _draft = _draft.copyWith(distance: value);
                            }
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: OmniSpacing.xl),

                    // ── 5. Accepting requests ────────────────────────
                    _FilterSection(
                      title: 'Accepting requests',
                      icon: Icons.check_circle_outline,
                      accent: _FilterAccents.accepting,
                      child: _AcceptingToggle(
                        acceptingOnly: _draft.acceptingOnly,
                        onChanged: (value) {
                          setState(() {
                            _draft = _draft.copyWith(acceptingOnly: value);
                          });
                        },
                      ),
                    ),

                    // ── More filters ──────────────────────────────────
                    const SizedBox(height: OmniSpacing.xl),
                    _MoreFiltersSection(
                      expanded: _showMoreFilters,
                      onToggle: () {
                        setState(() {
                          _showMoreFilters = !_showMoreFilters;
                        });
                      },
                      options: widget.options,
                      draft: _draft,
                      onChanged: (next) {
                        setState(() {
                          _draft = next;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            _SheetFooter(
              onReset: _reset,
              onApply: () {
                Navigator.of(context).pop(_draft);
              },
              filteredCount: applyClinicFilters(
                items: widget.items,
                filters: _draft,
              ).length,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Sheet Header
// ═══════════════════════════════════════════════════════════════════════════

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal,
        OmniSpacing.xs,
        OmniSpacing.sm,
        OmniSpacing.sm,
      ),
      child: Row(
        children: [
          Text(
            'Filters',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: OmniColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Close',
            onPressed: onClose,
            icon: const Icon(
              Icons.close_rounded,
              size: 22,
              color: OmniColors.textSecondary,
            ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Filter Section with icon
// ═══════════════════════════════════════════════════════════════════════════

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.title,
    required this.icon,
    required this.accent,
    required this.child,
  });

  final String title;
  final IconData icon;
  final _FilterAccent accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: accent.active,
            ),
            const SizedBox(width: OmniSpacing.sm),
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: OmniColors.textSecondary,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: OmniSpacing.sm),
        child,
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Multi-select chips
// ═══════════════════════════════════════════════════════════════════════════

class _ChoiceWrap extends StatelessWidget {
  const _ChoiceWrap({
    required this.accent,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final _FilterAccent accent;
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: OmniSpacing.sm,
      runSpacing: OmniSpacing.sm,
      children: [
        for (final option in options)
          _OptionChip(
            label: option,
            accent: accent,
            selected: selected.contains(option),
            onSelected: (isSelected) {
              final next = Set<String>.of(selected);
              if (isSelected) {
                next.add(option);
              } else {
                next.remove(option);
              }
              onChanged(Set.unmodifiable(next));
            },
          ),
      ],
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.accent,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final _FilterAccent accent;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: selected ? accent.active : OmniColors.textPrimary,
        ),
      ),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: true,
      checkmarkColor: accent.active,
      selectedColor: accent.soft,
      side: BorderSide(
        color: selected ? accent.active : OmniColors.borderLight,
        width: 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OmniRadii.pill),
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Specialty selector trigger (in main sheet)
// ═══════════════════════════════════════════════════════════════════════════

class _SpecialtySelectorTrigger extends StatelessWidget {
  const _SpecialtySelectorTrigger({
    required this.selected,
    required this.onTap,
    required this.onRemove,
  });

  final Set<String> selected;
  final VoidCallback onTap;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selected tokens
        if (selected.isNotEmpty) ...[
          Wrap(
            spacing: OmniSpacing.sm,
            runSpacing: OmniSpacing.sm,
            children: [
              for (final specialty in selected.take(3))
                _SelectedToken(
                  label: specialty,
                  accent: _FilterAccents.specialty,
                  onRemove: () => onRemove(specialty),
                ),
              if (selected.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '+${selected.length - 3} more',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _FilterAccents.specialty.active,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: OmniSpacing.sm),
        ],
        // Selector row
        _SelectorRow(
          label: selected.isEmpty
              ? 'Search specialties'
              : '${selected.length} selected',
          accent: _FilterAccents.specialty,
          onTap: onTap,
        ),
      ],
    );
  }
}

class _SelectedToken extends StatelessWidget {
  const _SelectedToken({
    required this.label,
    required this.accent,
    required this.onRemove,
  });

  final String label;
  final _FilterAccent accent;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: OmniSpacing.sm,
        vertical: OmniSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: accent.soft,
        borderRadius: BorderRadius.circular(OmniRadii.pill),
        border: Border.all(color: accent.active.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: accent.active,
            ),
          ),
          const SizedBox(width: OmniSpacing.xs),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close_rounded,
              size: 14,
              color: accent.active,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectorRow extends StatelessWidget {
  const _SelectorRow({
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final _FilterAccent accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: OmniSpacing.base,
          vertical: OmniSpacing.md,
        ),
        decoration: BoxDecoration(
          color: accent.soft,
          borderRadius: BorderRadius.circular(OmniRadii.field),
          border: Border.all(color: accent.active.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              size: 18,
              color: accent.active,
            ),
            const SizedBox(width: OmniSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: accent.active,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: accent.active,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Specialty selector full-screen sheet
// ═══════════════════════════════════════════════════════════════════════════

class _SpecialtySelectorSheet extends StatefulWidget {
  const _SpecialtySelectorSheet({required this.selected});

  final Set<String> selected;

  @override
  State<_SpecialtySelectorSheet> createState() =>
      _SpecialtySelectorSheetState();
}

class _SpecialtySelectorSheetState extends State<_SpecialtySelectorSheet> {
  late final Set<String> _selected = Set.of(widget.selected);
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _filteredSpecialties {
    if (_query.isEmpty) return SpecialtyCatalog.all;
    final needle = _query.toLowerCase();
    return SpecialtyCatalog.all
        .where((s) => s.toLowerCase().contains(needle))
        .toList();
  }

  /// Group specialties by first letter.
  Map<String, List<String>> get _grouped {
    final groups = <String, List<String>>{};
    for (final specialty in _filteredSpecialties) {
      final letter = specialty[0].toUpperCase();
      groups.putIfAbsent(letter, () => []).add(specialty);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                OmniSpacing.pageHorizontal,
                OmniSpacing.xs,
                OmniSpacing.sm,
                OmniSpacing.sm,
              ),
              child: Row(
                children: [
                  Text(
                    'Medical specialty',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: OmniColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 22,
                      color: OmniColors.textSecondary,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(
                OmniSpacing.pageHorizontal,
                OmniSpacing.md,
                OmniSpacing.pageHorizontal,
                OmniSpacing.md,
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Search specialties',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: OmniColors.textTertiary,
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 0,
                  ),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: OmniColors.textTertiary,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                ),
              ),
            ),
            // Selected at top
            if (_selected.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  OmniSpacing.pageHorizontal,
                  0,
                  OmniSpacing.pageHorizontal,
                  OmniSpacing.md,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: OmniSpacing.sm,
                    runSpacing: OmniSpacing.sm,
                    children: [
                      for (final specialty in _selected)
                        _SelectedToken(
                          label: specialty,
                          accent: _FilterAccents.specialty,
                          onRemove: () {
                            setState(() {
                              _selected.remove(specialty);
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
            ],
            // Alphabetized list
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(
                  vertical: OmniSpacing.sm,
                ),
                itemCount: _grouped.length,
                itemBuilder: (context, index) {
                  final letter = _grouped.keys.elementAt(index);
                  final specialties = _grouped[letter]!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          OmniSpacing.pageHorizontal,
                          OmniSpacing.md,
                          OmniSpacing.pageHorizontal,
                          OmniSpacing.xs,
                        ),
                        child: Text(
                          letter,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: OmniColors.textTertiary,
                          ),
                        ),
                      ),
                      for (final specialty in specialties)
                        _SpecialtyTile(
                          label: specialty,
                          selected: _selected.contains(specialty),
                          onToggle: () {
                            setState(() {
                              if (_selected.contains(specialty)) {
                                _selected.remove(specialty);
                              } else {
                                _selected.add(specialty);
                              }
                            });
                          },
                        ),
                    ],
                  );
                },
              ),
            ),
            // Confirm button
            const Divider(height: 1),
            SafeArea(
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
                    onPressed: () {
                      Navigator.of(context).pop(
                        Set.unmodifiable(_selected),
                      );
                    },
                    child: Text(
                      _selected.isEmpty
                          ? 'Done'
                          : 'Confirm ${_selected.length} specialties',
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SpecialtyTile extends StatelessWidget {
  const _SpecialtyTile({
    required this.label,
    required this.selected,
    required this.onToggle,
  });

  final String label;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: OmniSpacing.pageHorizontal,
          vertical: OmniSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: selected
                      ? _FilterAccents.specialty.active
                      : OmniColors.textPrimary,
                ),
              ),
            ),
            if (selected)
              Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: _FilterAccents.specialty.active,
              )
            else
              Icon(
                Icons.circle_outlined,
                size: 20,
                color: OmniColors.borderStrong,
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Location selector
// ═══════════════════════════════════════════════════════════════════════════

class _LocationSelector extends StatelessWidget {
  const _LocationSelector({
    required this.cities,
    required this.selected,
    required this.onChanged,
  });

  final List<String> cities;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ChoiceWrap(
      accent: _FilterAccents.location,
      options: cities,
      selected: selected,
      onChanged: onChanged,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Distance chips (single-select)
// ═══════════════════════════════════════════════════════════════════════════

class _DistanceChips extends StatelessWidget {
  const _DistanceChips({
    required this.selected,
    required this.onChanged,
  });

  final String? selected;
  final ValueChanged<String?> onChanged;

  static const _options = ['< 2 km', '< 5 km', '< 10 km', '< 25 km'];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: OmniSpacing.sm,
      runSpacing: OmniSpacing.sm,
      children: [
        for (final option in _options)
          _OptionChip(
            label: option,
            accent: _FilterAccents.distance,
            selected: selected == option,
            onSelected: (isSelected) {
              onChanged(isSelected ? option : null);
            },
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Accepting requests toggle
// ═══════════════════════════════════════════════════════════════════════════

class _AcceptingToggle extends StatelessWidget {
  const _AcceptingToggle({
    required this.acceptingOnly,
    required this.onChanged,
  });

  final bool acceptingOnly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: acceptingOnly,
      label:
          'Accepting requests only, ${acceptingOnly ? 'enabled' : 'disabled'}',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: OmniSpacing.md,
          vertical: OmniSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: _FilterAccents.accepting.soft,
          borderRadius: BorderRadius.circular(OmniRadii.field),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 20,
              color: OmniColors.freshMint,
            ),
            const SizedBox(width: OmniSpacing.md),
            Expanded(
              child: Text(
                'Accepting requests only',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: OmniColors.textPrimary,
                ),
              ),
            ),
            Switch(
              value: acceptingOnly,
              onChanged: onChanged,
              activeTrackColor: OmniColors.freshMint,
              activeThumbColor: OmniColors.deepTealActive,
              inactiveThumbColor: Color.alphaBlend(
                OmniColors.textTertiary.withValues(alpha: 0.35),
                Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// More filters section (collapsible)
// ═══════════════════════════════════════════════════════════════════════════

class _MoreFiltersSection extends StatelessWidget {
  const _MoreFiltersSection({
    required this.expanded,
    required this.onToggle,
    required this.options,
    required this.draft,
    required this.onChanged,
  });

  final bool expanded;
  final VoidCallback onToggle;
  final ClinicFilterOptions options;
  final ClinicFilterSnapshot draft;
  final ValueChanged<ClinicFilterSnapshot> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onToggle,
          child: Row(
            children: [
              Icon(
                Icons.tune_rounded,
                size: 16,
                color: OmniColors.slateBlue,
              ),
              const SizedBox(width: OmniSpacing.sm),
              Text(
                'More filters',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: OmniColors.textSecondary,
                  letterSpacing: 0.1,
                ),
              ),
              const Spacer(),
              Icon(
                expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: OmniColors.textSecondary,
              ),
            ],
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: OmniSpacing.md),
          // Clinic type
          if (options.clinicTypes.isNotEmpty) ...[
            _FilterSection(
              title: 'Clinic type',
              icon: Icons.domain_outlined,
              accent: _FilterAccents.clinicType,
              child: _ChoiceWrap(
                accent: _FilterAccents.clinicType,
                options: options.clinicTypes,
                selected: draft.clinicTypes,
                onChanged: (next) {
                  onChanged(draft.copyWith(clinicTypes: next));
                },
              ),
            ),
            const SizedBox(height: OmniSpacing.xl),
          ],
          // Services
          if (options.services.isNotEmpty)
            _FilterSection(
              title: 'Services',
              icon: Icons.medical_services_outlined,
              accent: _FilterAccents.services,
              child: _ChoiceWrap(
                accent: _FilterAccents.services,
                options: options.services,
                selected: draft.services,
                onChanged: (next) {
                  onChanged(draft.copyWith(services: next));
                },
              ),
            ),
          // Sort
          const SizedBox(height: OmniSpacing.xl),
          _FilterSection(
            title: 'Sort',
            icon: Icons.sort_rounded,
            accent: _FilterAccents.clinicType,
            child: _SortOptions(
              value: draft.sortOrder,
              onChanged: (order) {
                onChanged(draft.copyWith(sortOrder: order));
              },
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Sort options
// ═══════════════════════════════════════════════════════════════════════════

class _SortOptions extends StatelessWidget {
  const _SortOptions({required this.value, required this.onChanged});

  final ClinicSortOrder value;
  final ValueChanged<ClinicSortOrder> onChanged;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        radioTheme: RadioThemeData(
          fillColor: WidgetStateProperty.resolveWith(
            (states) {
              if (states.contains(WidgetState.selected)) {
                return OmniColors.slateBlue;
              }
              return OmniColors.textTertiary;
            },
          ),
        ),
      ),
      child: RadioGroup<ClinicSortOrder>(
        groupValue: value,
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
        child: Column(
          children: [
            for (final order in ClinicSortOrder.values)
              RadioListTile<ClinicSortOrder>(
                value: order,
                title: Text(
                  order.label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    color: OmniColors.textPrimary,
                  ),
                ),
                dense: true,
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Sheet Footer
// ═══════════════════════════════════════════════════════════════════════════

class _SheetFooter extends StatelessWidget {
  const _SheetFooter({
    required this.onReset,
    required this.onApply,
    required this.filteredCount,
  });

  final VoidCallback onReset;
  final VoidCallback onApply;
  final int filteredCount;

  @override
  Widget build(BuildContext context) {
    final showCount = filteredCount > 0;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          OmniSpacing.pageHorizontal,
          OmniSpacing.md,
          OmniSpacing.pageHorizontal,
          OmniSpacing.md,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 108,
              child: OutlinedButton(
                onPressed: onReset,
                child: const Text('Reset'),
              ),
            ),
            const SizedBox(width: OmniSpacing.md),
            Expanded(
              child: ElevatedButton(
                onPressed: onApply,
                child: Text(
                  showCount
                      ? 'Show $filteredCount ${filteredCount == 1 ? 'clinic' : 'clinics'}'
                      : 'Apply filters',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Future filter roadmap
// ═══════════════════════════════════════════════════════════════════════════
//
// The following filters require backend API support and are NOT implemented
// in this phase:
//
// - availability/date (next available appointment slot)
// - insurance / CNAM acceptance
// - specific insurance plans
// - price range / consultation fees
// - doctor availability (named doctor)
// - gender preference (doctor gender)
// - facilities (parking, wheelchair, elevator, etc.)
// - accessibility features
// - languages spoken
// - 24/7 availability
// - home services
// - online payment
// - online booking
//
// These should only be added when the backend exposes authoritative data
// for each field.
