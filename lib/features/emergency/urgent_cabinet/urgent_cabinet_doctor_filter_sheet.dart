import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';
import 'urgent_cabinet_doctor_filter.dart';
import 'urgent_cabinet_doctor_list_item.dart';

class _FilterAccent {
  const _FilterAccent({required this.active, required this.soft});

  final Color active;
  final Color soft;
}

abstract final class _FilterAccents {
  static const specialty = _FilterAccent(
    active: OmniColors.violet,
    soft: OmniColors.violetSoft,
  );
  static const distance = _FilterAccent(
    active: OmniColors.infoBlue,
    soft: OmniColors.infoBlueSoft,
  );
  static const governorate = _FilterAccent(
    active: OmniColors.clinicalCyan,
    soft: OmniColors.clinicalCyanSoft,
  );
  static const city = _FilterAccent(
    active: OmniColors.deepTeal,
    soft: OmniColors.mintSoft,
  );
  static const sort = _FilterAccent(
    active: OmniColors.slateBlue,
    soft: OmniColors.slateSoft,
  );
}

Future<UrgentCabinetDoctorFilterSnapshot?> showUrgentCabinetDoctorFilterSheet({
  required BuildContext context,
  required List<UrgentCabinetDoctorListItem> doctors,
  required String query,
  required UrgentCabinetDoctorFilterSnapshot initial,
  UrgentCabinetDoctorFilterOptions? options,
  bool distanceAvailable = true,
  Future<bool> Function()? onDistanceAuthorizationRequested,
  bool showLocalResultCount = true,
}) {
  return showModalBottomSheet<UrgentCabinetDoctorFilterSnapshot>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 380),
      reverseDuration: Duration(milliseconds: 220),
    ),
    builder: (context) => UrgentCabinetDoctorFilterSheet(
      doctors: doctors,
      query: query,
      initial: initial,
      options: options,
      distanceAvailable: distanceAvailable,
      onDistanceAuthorizationRequested: onDistanceAuthorizationRequested,
      showLocalResultCount: showLocalResultCount,
    ),
  );
}

class UrgentCabinetDoctorFilterSheet extends StatefulWidget {
  const UrgentCabinetDoctorFilterSheet({
    super.key,
    required this.doctors,
    required this.query,
    required this.initial,
    this.options,
    this.distanceAvailable = true,
    this.onDistanceAuthorizationRequested,
    this.showLocalResultCount = true,
  });

  final List<UrgentCabinetDoctorListItem> doctors;
  final String query;
  final UrgentCabinetDoctorFilterSnapshot initial;
  final UrgentCabinetDoctorFilterOptions? options;
  final bool distanceAvailable;
  final Future<bool> Function()? onDistanceAuthorizationRequested;
  final bool showLocalResultCount;

  @override
  State<UrgentCabinetDoctorFilterSheet> createState() =>
      _UrgentCabinetDoctorFilterSheetState();
}

class _UrgentCabinetDoctorFilterSheetState
    extends State<UrgentCabinetDoctorFilterSheet> {
  late UrgentCabinetDoctorFilterSnapshot _draft = widget.initial;
  late bool _distanceAvailable = widget.distanceAvailable;

  UrgentCabinetDoctorFilterOptions get _options =>
      widget.options ?? buildUrgentCabinetDoctorFilterOptions(widget.doctors);

  void _reset() {
    setState(() {
      _draft = UrgentCabinetDoctorFilterSnapshot.none;
    });
  }

  void _selectGovernorate(String? governorate) {
    final availableCities = _options.citiesFor(governorate);
    final currentCity = _draft.city;
    setState(() {
      _draft = _draft.copyWith(
        governorate: governorate,
        clearGovernorate: governorate == null,
        clearCity:
            currentCity != null && !availableCities.contains(currentCity),
      );
    });
  }

  Future<bool> _ensureDistanceAuthorization() async {
    if (_distanceAvailable) return true;
    final authorize = widget.onDistanceAuthorizationRequested;
    if (authorize == null || !await authorize()) return false;
    if (!mounted) return false;
    setState(() => _distanceAvailable = true);
    return true;
  }

  Future<void> _selectDistance(double? distance) async {
    if (distance != null && !await _ensureDistanceAuthorization()) return;
    if (!mounted) return;
    setState(() {
      _draft = _draft.copyWith(
        maximumDistanceKm: distance,
        clearMaximumDistance: distance == null,
      );
    });
  }

  Future<void> _selectSort(UrgentCabinetSortOrder order) async {
    if (order == UrgentCabinetSortOrder.nearest &&
        !await _ensureDistanceAuthorization()) {
      return;
    }
    if (!mounted) return;
    setState(() => _draft = _draft.copyWith(sortOrder: order));
  }

  @override
  Widget build(BuildContext context) {
    final modalHeight = MediaQuery.sizeOf(context).height;
    final options = _options;
    final cities = options.citiesFor(_draft.governorate);
    final filteredCount = filterAndSortUrgentCabinetDoctors(
      doctors: widget.doctors,
      query: widget.query,
      filters: _draft,
    ).length;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: modalHeight * 0.60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SheetHeader(onClose: () => Navigator.of(context).pop()),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  OmniSpacing.pageHorizontal,
                  OmniSpacing.base,
                  OmniSpacing.pageHorizontal,
                  OmniSpacing.base,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FilterSection(
                      title: 'Spécialité',
                      icon: Icons.local_hospital_outlined,
                      accent: _FilterAccents.specialty,
                      child: _MultiChoiceWrap(
                        allLabel: 'Toutes',
                        accent: _FilterAccents.specialty,
                        options: options.specialties,
                        selected: _draft.specialties,
                        onChanged: (selected) {
                          setState(() {
                            _draft = _draft.copyWith(specialties: selected);
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: OmniSpacing.xl),
                    _FilterSection(
                      title: 'Distance maximale',
                      icon: Icons.location_on_outlined,
                      accent: _FilterAccents.distance,
                      child: _DistanceChoices(
                        selected: _draft.maximumDistanceKm,
                        enabled:
                            _distanceAvailable ||
                            widget.onDistanceAuthorizationRequested != null,
                        onChanged: (distance) => _selectDistance(distance),
                      ),
                    ),
                    const SizedBox(height: OmniSpacing.xl),
                    _FilterSection(
                      title: 'Gouvernorat',
                      icon: Icons.map_outlined,
                      accent: _FilterAccents.governorate,
                      child: _SingleChoiceWrap(
                        allLabel: 'Tous',
                        accent: _FilterAccents.governorate,
                        options: options.governorates,
                        selected: _draft.governorate,
                        onChanged: _selectGovernorate,
                      ),
                    ),
                    const SizedBox(height: OmniSpacing.xl),
                    _FilterSection(
                      title: 'Ville',
                      icon: Icons.location_city_outlined,
                      accent: _FilterAccents.city,
                      child: _SingleChoiceWrap(
                        allLabel: 'Toutes',
                        accent: _FilterAccents.city,
                        options: cities,
                        selected: _draft.city,
                        onChanged: (city) {
                          setState(() {
                            _draft = _draft.copyWith(
                              city: city,
                              clearCity: city == null,
                            );
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: OmniSpacing.xl),
                    _FilterSection(
                      title: 'Trier par',
                      icon: Icons.sort_rounded,
                      accent: _FilterAccents.sort,
                      child: Wrap(
                        spacing: OmniSpacing.sm,
                        runSpacing: OmniSpacing.sm,
                        children: [
                          for (final order in UrgentCabinetSortOrder.values)
                            _OptionChip(
                              key: ValueKey('urgent-filter-sort-${order.name}'),
                              label: order.label,
                              accent: _FilterAccents.sort,
                              selected: _draft.sortOrder == order,
                              enabled:
                                  order != UrgentCabinetSortOrder.nearest ||
                                  _distanceAvailable ||
                                  widget.onDistanceAuthorizationRequested !=
                                      null,
                              onSelected: (_) => _selectSort(order),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            _SheetFooter(
              onReset: _reset,
              onApply: () => Navigator.of(context).pop(_draft),
              filteredCount: widget.showLocalResultCount ? filteredCount : null,
            ),
          ],
        ),
      ),
    );
  }
}

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
            'Filtres',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: OmniColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Fermer',
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
            Icon(icon, size: 16, color: accent.active),
            const SizedBox(width: OmniSpacing.sm),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: OmniColors.textSecondary,
                  letterSpacing: 0.1,
                ),
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

class _MultiChoiceWrap extends StatelessWidget {
  const _MultiChoiceWrap({
    required this.allLabel,
    required this.accent,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String allLabel;
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
        _OptionChip(
          key: const ValueKey('urgent-filter-specialty-all'),
          label: allLabel,
          accent: accent,
          selected: selected.isEmpty,
          onSelected: (_) => onChanged(const {}),
        ),
        for (final option in options)
          _OptionChip(
            key: ValueKey('urgent-filter-specialty-$option'),
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
              onChanged(next);
            },
          ),
      ],
    );
  }
}

class _SingleChoiceWrap extends StatelessWidget {
  const _SingleChoiceWrap({
    required this.allLabel,
    required this.accent,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final String allLabel;
  final _FilterAccent accent;
  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: OmniSpacing.sm,
      runSpacing: OmniSpacing.sm,
      children: [
        _OptionChip(
          key: ValueKey('urgent-filter-$allLabel-all'),
          label: allLabel,
          accent: accent,
          selected: selected == null,
          onSelected: (_) => onChanged(null),
        ),
        for (final option in options)
          _OptionChip(
            key: ValueKey('urgent-filter-$allLabel-$option'),
            label: option,
            accent: accent,
            selected: selected == option,
            onSelected: (isSelected) => onChanged(isSelected ? option : null),
          ),
      ],
    );
  }
}

class _DistanceChoices extends StatelessWidget {
  const _DistanceChoices({
    required this.selected,
    required this.onChanged,
    required this.enabled,
  });

  static const _distances = <double>[5, 10, 20, 30];

  final double? selected;
  final ValueChanged<double?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: OmniSpacing.sm,
      runSpacing: OmniSpacing.sm,
      children: [
        _OptionChip(
          key: const ValueKey('urgent-filter-distance-all'),
          label: 'Toutes',
          accent: _FilterAccents.distance,
          selected: selected == null,
          enabled: enabled,
          onSelected: (_) => onChanged(null),
        ),
        for (final distance in _distances)
          _OptionChip(
            key: ValueKey('urgent-filter-distance-${distance.toInt()}'),
            label: '${distance.toInt()} km',
            accent: _FilterAccents.distance,
            selected: selected == distance,
            enabled: enabled,
            onSelected: (isSelected) => onChanged(isSelected ? distance : null),
          ),
      ],
    );
  }
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    super.key,
    required this.label,
    required this.accent,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
  });

  final String label;
  final _FilterAccent accent;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final bool enabled;

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
      onSelected: enabled ? onSelected : null,
      showCheckmark: true,
      checkmarkColor: accent.active,
      selectedColor: accent.soft,
      side: BorderSide(
        color: selected ? accent.active : OmniColors.borderLight,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OmniRadii.pill),
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _SheetFooter extends StatelessWidget {
  const _SheetFooter({
    required this.onReset,
    required this.onApply,
    required this.filteredCount,
  });

  final VoidCallback onReset;
  final VoidCallback onApply;
  final int? filteredCount;

  @override
  Widget build(BuildContext context) {
    final count = filteredCount;
    final applyLabel = count != null && count > 0
        ? 'Afficher $count ${count == 1 ? 'médecin' : 'médecins'}'
        : 'Appliquer';
    final useVerticalLayout =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.3;

    final resetButton = OutlinedButton(
      onPressed: onReset,
      child: const Text('Réinitialiser'),
    );
    final applyButton = ElevatedButton(
      onPressed: onApply,
      child: Text(applyLabel, textAlign: TextAlign.center),
    );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          OmniSpacing.pageHorizontal,
          OmniSpacing.md,
          OmniSpacing.pageHorizontal,
          OmniSpacing.md,
        ),
        child: useVerticalLayout
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: double.infinity, child: applyButton),
                  const SizedBox(height: OmniSpacing.sm),
                  SizedBox(width: double.infinity, child: resetButton),
                ],
              )
            : Row(
                children: [
                  SizedBox(width: 108, child: resetButton),
                  const SizedBox(width: OmniSpacing.md),
                  Expanded(child: applyButton),
                ],
              ),
      ),
    );
  }
}
