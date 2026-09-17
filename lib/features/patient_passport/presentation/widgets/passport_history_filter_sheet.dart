import 'package:flutter/material.dart';

import '../../../../core/theme/omni_theme.dart';
import '../../models/patient_passport_view_models.dart';

Future<PassportHistoryFilters?> showPassportHistoryFilterSheet(
  BuildContext context, {
  required PassportHistoryFilters initialFilters,
}) {
  return showModalBottomSheet<PassportHistoryFilters>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PassportHistoryFilterSheet(initialFilters: initialFilters),
  );
}

class PassportHistoryFilterSheet extends StatefulWidget {
  final PassportHistoryFilters initialFilters;

  const PassportHistoryFilterSheet({super.key, required this.initialFilters});

  @override
  State<PassportHistoryFilterSheet> createState() =>
      _PassportHistoryFilterSheetState();
}

class _PassportHistoryFilterSheetState
    extends State<PassportHistoryFilterSheet> {
  late PassportHistoryFilters _filters;

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters;
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.88,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: OmniColors.mintSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.filter_list_rounded,
                      color: OmniColors.primaryAction,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Filtrer l'historique",
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Affinez les résultats par période, médecin et confidentialité.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: OmniColors.textSecondary,
                                height: 1.35,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Fermer',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                children: [
                  const _SectionHeader(
                    icon: Icons.calendar_month_outlined,
                    label: 'Période',
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _DropdownField(
                          label: 'Année',
                          value: _filters.year,
                          items: const ['Toutes les années', '2026', '2025'],
                          onChanged: (value) => _update(year: value),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DropdownField(
                          label: 'Mois',
                          value: _filters.month,
                          items: const ['Tous les Mois', 'Janvier', 'Février'],
                          onChanged: (value) => _update(month: value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const _SectionHeader(
                    icon: Icons.medical_services_outlined,
                    label: 'Professionnel de santé',
                  ),
                  _DropdownField(
                    label: 'Spécialité',
                    value: _filters.specialty,
                    items: const [
                      'Toutes les spécialités',
                      'Médecin Généraliste',
                      'Gynécologue',
                    ],
                    onChanged: (value) => _update(specialty: value),
                  ),
                  const SizedBox(height: 12),
                  _DropdownField(
                    label: 'Médecin',
                    value: _filters.doctor,
                    items: const [
                      'Tous les médecins',
                      'Dr. Karim Mansour',
                      'Dr. Nadia Hamdi',
                    ],
                    onChanged: (value) => _update(doctor: value),
                  ),
                  const SizedBox(height: 20),
                  _FilterLabel('Statut'),
                  _ChoiceRow(
                    values: const ['Tous', 'Terminée', 'Annulée'],
                    selected: _filters.status,
                    onSelected: (value) => _update(status: value),
                  ),
                  const SizedBox(height: 20),
                  _FilterLabel('Partage'),
                  _ChoiceRow(
                    values: const ['Tous', 'Partageables', 'Privées'],
                    selected: _filters.sharing,
                    onSelected: (value) => _update(sharing: value),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: OutlinedButton.icon(
                        onPressed: () => setState(
                          () => _filters = const PassportHistoryFilters(),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text(
                          'Réinitialiser',
                          maxLines: 1,
                          softWrap: false,
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 6,
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(_filters),
                        style: FilledButton.styleFrom(
                          backgroundColor: OmniColors.primaryAction,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(50),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Appliquer les filtres',
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _update({
    String? year,
    String? month,
    String? specialty,
    String? doctor,
    String? status,
    String? sharing,
  }) {
    setState(() {
      _filters = _filters.copyWith(
        year: year,
        month: month,
        specialty: specialty,
        doctor: doctor,
        status: status,
        sharing: sharing,
      );
    });
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: OmniColors.primaryAction),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: OmniColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterLabel extends StatelessWidget {
  final String label;

  const _FilterLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: OmniColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: OmniColors.borderLight),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: OmniColors.textSecondary,
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: OmniColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              items: items
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item,
                      child: Text(item, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (next) {
                if (next != null) onChanged(next);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelected;

  const _ChoiceRow({
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final selectedIndex = values.indexOf(selected);
    final alignment = switch (selectedIndex) {
      1 => Alignment.center,
      2 => Alignment.centerRight,
      _ => Alignment.centerLeft,
    };

    return Container(
      height: 48,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: OmniColors.slateSoft,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedAlign(
            alignment: alignment,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: FractionallySizedBox(
              widthFactor: 1 / 3,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [OmniColors.shadowSm],
                ),
              ),
            ),
          ),
          Row(
            children: values
                .map(
                  (value) => Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onSelected(value),
                      child: Center(
                        child: Text(
                          value,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: value == selected
                                    ? OmniColors.primaryAction
                                    : OmniColors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}
