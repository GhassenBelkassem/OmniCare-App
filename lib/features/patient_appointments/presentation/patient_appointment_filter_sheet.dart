import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';
import '../../../core/models/family_models.dart';
import '../data/patient_appointment_models.dart';

Future<PatientAppointmentFilters?> showPatientAppointmentFilterSheet({
  required BuildContext context,
  required List<PatientAppointment> appointments,
  List<FamilyMember> familyMembers = const [],
  required PatientAppointmentFilters initial,
}) {
  return showModalBottomSheet<PatientAppointmentFilters>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => PatientAppointmentFilterSheet(
      appointments: appointments,
      familyMembers: familyMembers,
      initial: initial,
    ),
  );
}

class PatientAppointmentFilterSheet extends StatefulWidget {
  const PatientAppointmentFilterSheet({
    super.key,
    required this.appointments,
    this.familyMembers = const [],
    required this.initial,
  });

  final List<PatientAppointment> appointments;
  final List<FamilyMember> familyMembers;
  final PatientAppointmentFilters initial;

  @override
  State<PatientAppointmentFilterSheet> createState() =>
      _PatientAppointmentFilterSheetState();
}

class _PatientAppointmentFilterSheetState
    extends State<PatientAppointmentFilterSheet> {
  late PatientAppointmentFilters _draft = widget.initial;

  List<({String? id, String label})> get _subjects {
    if (widget.familyMembers.isNotEmpty) {
      return widget.familyMembers
          .map((member) => (id: member.id, label: member.fullName))
          .toList()
        ..sort((left, right) => left.label.compareTo(right.label));
    }
    return widget.appointments
        .where(
          (appointment) =>
              appointment.subjectType ==
              PatientAppointmentSubjectType.familyMember,
        )
        .map(
          (appointment) =>
              (id: null as String?, label: appointment.subjectDisplayName),
        )
        .toSet()
        .toList()
      ..sort((left, right) => left.label.compareTo(right.label));
  }

  List<String> get _cities =>
      widget.appointments
          .map((appointment) => appointment.city)
          .where((city) => city.trim().isNotEmpty)
          .toSet()
          .toList()
        ..sort();

  void _reset() => setState(() => _draft = PatientAppointmentFilters.none);

  Future<void> _choosePeriod() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5, 12, 31),
      initialDateRange: _draft.customStart != null && _draft.customEnd != null
          ? DateTimeRange(start: _draft.customStart!, end: _draft.customEnd!)
          : DateTimeRange(start: now, end: now.add(const Duration(days: 30))),
    );
    if (!mounted || range == null) return;
    setState(() {
      _draft = _draft.copyWith(
        dateFilter: PatientAppointmentDateFilter.custom,
        customStart: range.start,
        customEnd: range.end,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: height * .62),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              OmniSpacing.pageHorizontal,
              OmniSpacing.sm,
              OmniSpacing.pageHorizontal,
              OmniSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Filtrer les rendez-vous',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
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
              padding: const EdgeInsets.fromLTRB(
                OmniSpacing.pageHorizontal,
                OmniSpacing.base,
                OmniSpacing.pageHorizontal,
                OmniSpacing.base,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FilterTitle(
                    icon: Icons.people_outline_rounded,
                    title: 'Pour qui ?',
                  ),
                  Wrap(
                    spacing: OmniSpacing.xs,
                    runSpacing: OmniSpacing.xs,
                    children: [
                      _choice(
                        label: 'Moi',
                        selected:
                            _draft.subjectType ==
                            PatientAppointmentSubjectType.self,
                        onSelected: () => setState(
                          () => _draft = _draft.copyWith(
                            subjectType: PatientAppointmentSubjectType.self,
                            clearSubjectDisplayName: true,
                            clearSubjectFamilyMemberId: true,
                          ),
                        ),
                      ),
                      for (final subject in _subjects)
                        _choice(
                          label: subject.label,
                          selected: subject.id != null
                              ? _draft.subjectFamilyMemberId == subject.id
                              : _draft.subjectDisplayName == subject.label,
                          onSelected: () => setState(
                            () => _draft = _draft.copyWith(
                              subjectType:
                                  PatientAppointmentSubjectType.familyMember,
                              subjectDisplayName: subject.label,
                              subjectFamilyMemberId: subject.id,
                              clearSubjectFamilyMemberId: subject.id == null,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: OmniSpacing.lg),
                  _FilterTitle(
                    icon: Icons.business_outlined,
                    title: 'Type de professionnel',
                  ),
                  Wrap(
                    spacing: OmniSpacing.xs,
                    children: [
                      _choice(
                        label: 'Médecin',
                        selected:
                            _draft.providerType ==
                            PatientAppointmentProviderType.doctor,
                        onSelected: () => setState(
                          () => _draft = _draft.copyWith(
                            providerType: PatientAppointmentProviderType.doctor,
                          ),
                        ),
                      ),
                      _choice(
                        label: 'Clinique',
                        selected:
                            _draft.providerType ==
                            PatientAppointmentProviderType.clinic,
                        onSelected: () => setState(
                          () => _draft = _draft.copyWith(
                            providerType: PatientAppointmentProviderType.clinic,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: OmniSpacing.lg),
                  _FilterTitle(
                    icon: Icons.calendar_today_outlined,
                    title: 'Période',
                  ),
                  Wrap(
                    spacing: OmniSpacing.xs,
                    runSpacing: OmniSpacing.xs,
                    children: [
                      for (final option in [
                        (
                          PatientAppointmentDateFilter.thisWeek,
                          'Cette semaine',
                        ),
                        (PatientAppointmentDateFilter.thisMonth, 'Ce mois'),
                        (PatientAppointmentDateFilter.thisYear, 'Cette année'),
                      ])
                        _choice(
                          label: option.$2,
                          selected: _draft.dateFilter == option.$1,
                          onSelected: () => setState(
                            () => _draft = _draft.copyWith(
                              dateFilter: option.$1,
                              clearCustomRange: true,
                            ),
                          ),
                        ),
                      _choice(
                        label: 'Choisir une période',
                        selected:
                            _draft.dateFilter ==
                            PatientAppointmentDateFilter.custom,
                        onSelected: _choosePeriod,
                      ),
                    ],
                  ),
                  if (_cities.length > 1) ...[
                    const SizedBox(height: OmniSpacing.lg),
                    _FilterTitle(
                      icon: Icons.location_on_outlined,
                      title: 'Ville',
                    ),
                    Wrap(
                      spacing: OmniSpacing.xs,
                      children: [
                        for (final city in _cities)
                          _choice(
                            label: city,
                            selected: _draft.city == city,
                            onSelected: () => setState(
                              () => _draft = _draft.copyWith(city: city),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                OmniSpacing.pageHorizontal,
                OmniSpacing.xs,
                OmniSpacing.pageHorizontal,
                OmniSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _draft.isActive ? _reset : null,
                      child: const Text('Réinitialiser'),
                    ),
                  ),
                  const SizedBox(width: OmniSpacing.sm),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(_draft),
                      child: const Text('Appliquer'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _choice({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: OmniColors.mintSoft,
      labelStyle: TextStyle(
        color: selected ? OmniColors.deepTeal : OmniColors.textSecondary,
        fontSize: 12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide(
        color: selected ? OmniColors.freshMint : OmniColors.borderLight,
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _FilterTitle extends StatelessWidget {
  const _FilterTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: OmniSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: OmniColors.slateBlue),
          const SizedBox(width: OmniSpacing.xs),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
