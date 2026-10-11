import 'package:flutter/material.dart';

import '../../../../core/theme/omni_theme.dart';
import '../../../patient_clinic/presentation/clinic_presentation_metadata.dart';
import '../../application/doctor_directory_filters.dart';
import '../../data/doctor_directory_models.dart';

Future<DoctorFilterSnapshot?> showDoctorFilterSheet({
  required BuildContext context,
  DoctorFilterSnapshot initial = DoctorFilterSnapshot.none,
}) {
  return showModalBottomSheet<DoctorFilterSnapshot>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => DoctorFilterSheet(initial: initial),
  );
}

class DoctorFilterSheet extends StatefulWidget {
  const DoctorFilterSheet({
    super.key,
    this.initial = DoctorFilterSnapshot.none,
  });

  final DoctorFilterSnapshot initial;

  @override
  State<DoctorFilterSheet> createState() => _DoctorFilterSheetState();
}

class _DoctorFilterSheetState extends State<DoctorFilterSheet> {
  late DoctorFilterSnapshot _draft = widget.initial;
  late final TextEditingController _specialtyController = TextEditingController(
    text: widget.initial.specialty,
  );

  @override
  void dispose() {
    _specialtyController.dispose();
    super.dispose();
  }

  void _reset() {
    _specialtyController.clear();
    setState(() => _draft = DoctorFilterSnapshot.none);
  }

  DoctorFilterSnapshot _withSpecialty() {
    final specialty = _specialtyController.text.trim();
    return specialty.isEmpty
        ? _draft.copyWith(clearSpecialty: true)
        : _draft.copyWith(specialty: specialty);
  }

  @override
  Widget build(BuildContext context) {
    final cities = _draft.governorate == null
        ? const <String>[]
        : GovernorateCatalog.citiesFor(_draft.governorate!);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              OmniSpacing.pageHorizontal,
              0,
              OmniSpacing.sm,
              OmniSpacing.sm,
            ),
            child: Row(
              children: [
                Text(
                  'Filtres',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _reset,
                  child: const Text('Tout effacer'),
                ),
                IconButton(
                  tooltip: 'Fermer',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(OmniSpacing.pageHorizontal),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle(
                    icon: Icons.local_hospital_outlined,
                    label: 'Spécialité',
                  ),
                  const SizedBox(height: OmniSpacing.sm),
                  TextField(
                    key: const ValueKey('doctor-filter-specialty'),
                    controller: _specialtyController,
                    maxLength: 100,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      hintText: 'Ex. Cardiologie',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: OmniSpacing.xl),
                  const _SectionTitle(
                    icon: Icons.location_on_outlined,
                    label: 'Localisation du cabinet',
                  ),
                  const SizedBox(height: OmniSpacing.sm),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('doctor-filter-governorate'),
                    initialValue: _draft.governorate,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Gouvernorat'),
                    items: [
                      for (final governorate
                          in GovernorateCatalog.governorates.keys)
                        DropdownMenuItem(
                          value: governorate,
                          child: Text(governorate),
                        ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _draft = value == null
                            ? _draft.copyWith(
                                clearGovernorate: true,
                                clearCity: true,
                              )
                            : _draft.copyWith(
                                governorate: value,
                                clearCity: true,
                              );
                      });
                    },
                  ),
                  const SizedBox(height: OmniSpacing.md),
                  DropdownButtonFormField<String>(
                    key: ValueKey('doctor-filter-city-${_draft.governorate}'),
                    initialValue: cities.contains(_draft.city)
                        ? _draft.city
                        : null,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Ville'),
                    items: [
                      for (final city in cities)
                        DropdownMenuItem(value: city, child: Text(city)),
                    ],
                    onChanged: cities.isEmpty
                        ? null
                        : (value) {
                            setState(() {
                              _draft = value == null
                                  ? _draft.copyWith(clearCity: true)
                                  : _draft.copyWith(city: value);
                            });
                          },
                  ),
                  const SizedBox(height: OmniSpacing.xl),
                  const _SectionTitle(
                    icon: Icons.near_me_outlined,
                    label: 'Distance autour de moi',
                  ),
                  const SizedBox(height: OmniSpacing.xs),
                  Text(
                    'Votre position sera demandée uniquement après avoir appliqué un rayon.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: OmniColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: OmniSpacing.sm),
                  _ChoiceWrap<double>(
                    values: const [2, 5, 10, 25],
                    selected: _draft.maxDistanceKm,
                    label: doctorDistanceLabel,
                    onSelected: (value) => setState(() {
                      _draft = value == null
                          ? _draft.copyWith(clearMaxDistanceKm: true)
                          : _draft.copyWith(maxDistanceKm: value);
                    }),
                  ),
                  const SizedBox(height: OmniSpacing.xl),
                  const _SectionTitle(
                    icon: Icons.medical_services_outlined,
                    label: 'Type de prise en charge',
                  ),
                  const SizedBox(height: OmniSpacing.sm),
                  _ChoiceWrap<DoctorCareCapability>(
                    values: DoctorCareCapability.values,
                    selected: _draft.careCapability,
                    label: doctorCapabilityLabel,
                    onSelected: (value) => setState(() {
                      _draft = value == null
                          ? _draft.copyWith(clearCareCapability: true)
                          : _draft.copyWith(careCapability: value);
                    }),
                  ),
                  const SizedBox(height: OmniSpacing.xl),
                  const _SectionTitle(
                    icon: Icons.shield_outlined,
                    label: 'Couverture déclarée',
                  ),
                  const SizedBox(height: OmniSpacing.xs),
                  Text(
                    'Ces choix reflètent les déclarations du cabinet, sans garantie de remboursement.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: OmniColors.textSecondary,
                    ),
                  ),
                  _FilterSwitch(
                    label: 'CNAM accepté',
                    value: _draft.cnamAccepted,
                    onChanged: (value) => setState(
                      () => _draft = _draft.copyWith(cnamAccepted: value),
                    ),
                  ),
                  _FilterSwitch(
                    label: 'Assurance privée acceptée',
                    value: _draft.privateInsuranceAccepted,
                    onChanged: (value) => setState(
                      () => _draft = _draft.copyWith(
                        privateInsuranceAccepted: value,
                      ),
                    ),
                  ),
                  _FilterSwitch(
                    label: 'Accepte de nouveaux patients',
                    value: _draft.acceptingNewPatients,
                    onChanged: (value) => setState(
                      () =>
                          _draft = _draft.copyWith(acceptingNewPatients: value),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(OmniSpacing.pageHorizontal),
              child: ElevatedButton(
                key: const ValueKey('doctor-filter-apply'),
                onPressed: () => Navigator.of(context).pop(_withSpecialty()),
                child: Text(
                  _withSpecialty().activeGroupCount == 0
                      ? 'Afficher les médecins'
                      : 'Appliquer (${_withSpecialty().activeGroupCount})',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: OmniColors.violet),
        const SizedBox(width: OmniSpacing.sm),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _ChoiceWrap<T> extends StatelessWidget {
  const _ChoiceWrap({
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  final List<T> values;
  final T? selected;
  final String Function(T) label;
  final ValueChanged<T?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: OmniSpacing.sm,
      runSpacing: OmniSpacing.sm,
      children: [
        for (final value in values)
          FilterChip(
            label: Text(label(value)),
            selected: selected == value,
            onSelected: (isSelected) => onSelected(isSelected ? value : null),
          ),
      ],
    );
  }
}

class _FilterSwitch extends StatelessWidget {
  const _FilterSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: value,
      onChanged: onChanged,
    );
  }
}
