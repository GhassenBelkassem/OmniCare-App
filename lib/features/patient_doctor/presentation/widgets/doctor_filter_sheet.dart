import 'package:flutter/material.dart';

import '../../../../core/theme/omni_theme.dart';
import '../../data/doctor_models.dart';
import '../doctor_filter_model.dart';

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
  static const availability = _FilterAccent(
    active: OmniColors.freshMint,
    soft: OmniColors.mintSoft,
  );
  static const patient = _FilterAccent(
    active: OmniColors.clinicalCyan,
    soft: OmniColors.clinicalCyanSoft,
  );
  static const consultation = _FilterAccent(
    active: OmniColors.deepTeal,
    soft: OmniColors.mintSoft,
  );
  static const gender = _FilterAccent(
    active: OmniColors.violet,
    soft: OmniColors.violetSoft,
  );
  static const language = _FilterAccent(
    active: OmniColors.slateBlue,
    soft: OmniColors.slateSoft,
  );
  static const visit = _FilterAccent(
    active: OmniColors.infoBlue,
    soft: OmniColors.infoBlueSoft,
  );
  static const insurance = _FilterAccent(
    active: OmniColors.clinicalCyan,
    soft: OmniColors.clinicalCyanSoft,
  );
  static const experience = _FilterAccent(
    active: OmniColors.amber,
    soft: OmniColors.amberSoft,
  );
  static const location = _FilterAccent(
    active: OmniColors.infoBlue,
    soft: OmniColors.infoBlueSoft,
  );
  static const schedule = _FilterAccent(
    active: OmniColors.freshMint,
    soft: OmniColors.mintSoft,
  );
  static const service = _FilterAccent(
    active: OmniColors.clinicalCyan,
    soft: OmniColors.clinicalCyanSoft,
  );
}

Future<DoctorFilterSnapshot?> showDoctorFilterSheet({
  required BuildContext context,
  required DoctorFilterOptions options,
  required List<DoctorListItem> items,
  DoctorFilterSnapshot initial = DoctorFilterSnapshot.none,
}) {
  return showModalBottomSheet<DoctorFilterSnapshot>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 380),
      reverseDuration: Duration(milliseconds: 220),
    ),
    builder: (context) =>
        DoctorFilterSheet(options: options, items: items, initial: initial),
  );
}

class DoctorFilterSheet extends StatefulWidget {
  const DoctorFilterSheet({
    super.key,
    required this.options,
    required this.items,
    this.initial = DoctorFilterSnapshot.none,
  });

  final DoctorFilterOptions options;
  final List<DoctorListItem> items;
  final DoctorFilterSnapshot initial;

  @override
  State<DoctorFilterSheet> createState() => _DoctorFilterSheetState();
}

class _DoctorFilterSheetState extends State<DoctorFilterSheet> {
  late DoctorFilterSnapshot _draft = widget.initial;

  void _reset() {
    setState(() {
      _draft = DoctorFilterSnapshot.none;
    });
  }

  @override
  Widget build(BuildContext context) {
    final modalHeight = MediaQuery.sizeOf(context).height;

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
                      child: _ChoiceWrap(
                        accent: _FilterAccents.specialty,
                        options: widget.options.specialties,
                        selected: _draft.specialties,
                        onChanged: (next) {
                          setState(() {
                            _draft = _draft.copyWith(specialties: next);
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: OmniSpacing.xl),
                    _FilterSection(
                      title: 'Distance',
                      icon: Icons.location_on_outlined,
                      accent: _FilterAccents.distance,
                      child: _SingleChoiceWrap(
                        accent: _FilterAccents.distance,
                        options: widget.options.distanceOptions,
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
                    _FilterSection(
                      title: 'Disponibilité',
                      icon: Icons.calendar_today_outlined,
                      accent: _FilterAccents.availability,
                      child: _SingleChoiceWrap(
                        accent: _FilterAccents.availability,
                        options: widget.options.availabilityOptions,
                        selected: _draft.availability,
                        onChanged: (value) {
                          setState(() {
                            if (value == null) {
                              _draft = _draft.copyWith(clearAvailability: true);
                            } else {
                              _draft = _draft.copyWith(availability: value);
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: OmniSpacing.xl),
                    _FilterSection(
                      title: 'Nouveau patient',
                      icon: Icons.person_add_outlined,
                      accent: _FilterAccents.patient,
                      child: _SingleChoiceWrap(
                        accent: _FilterAccents.patient,
                        options: const ['Oui'],
                        selected: _draft.acceptingNewPatients == true
                            ? 'Oui'
                            : null,
                        onChanged: (value) {
                          setState(() {
                            if (value == null) {
                              _draft = _draft.copyWith(
                                clearAcceptingNewPatients: true,
                              );
                            } else {
                              _draft = _draft.copyWith(
                                acceptingNewPatients: true,
                              );
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: OmniSpacing.xl),
                    _FilterSection(
                      title: 'Tranche d\'âge',
                      icon: Icons.cake_outlined,
                      accent: _FilterAccents.patient,
                      child: _SingleChoiceWrap(
                        accent: _FilterAccents.patient,
                        options: widget.options.patientAgeGroupOptions,
                        selected: _draft.patientAgeGroup,
                        onChanged: (value) {
                          setState(() {
                            if (value == null) {
                              _draft = _draft.copyWith(
                                clearPatientAgeGroup: true,
                              );
                            } else {
                              _draft = _draft.copyWith(patientAgeGroup: value);
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: OmniSpacing.xl),
                    _FilterSection(
                      title: 'Type de consultation',
                      icon: Icons.video_call_outlined,
                      accent: _FilterAccents.consultation,
                      child: _ChoiceWrap(
                        accent: _FilterAccents.consultation,
                        options: widget.options.consultationTypeOptions,
                        selected: _draft.consultationTypes,
                        onChanged: (next) {
                          setState(() {
                            _draft = _draft.copyWith(consultationTypes: next);
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: OmniSpacing.xl),
                    _FilterSection(
                      title: 'Genre du médecin',
                      icon: Icons.person_outline,
                      accent: _FilterAccents.gender,
                      child: _SingleChoiceWrap(
                        accent: _FilterAccents.gender,
                        options: widget.options.genderOptions,
                        selected: _draft.gender,
                        onChanged: (value) {
                          setState(() {
                            if (value == null) {
                              _draft = _draft.copyWith(clearGender: true);
                            } else {
                              _draft = _draft.copyWith(gender: value);
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: OmniSpacing.xl),
                    _FilterSection(
                      title: 'Langue',
                      icon: Icons.language_rounded,
                      accent: _FilterAccents.language,
                      child: _ChoiceWrap(
                        accent: _FilterAccents.language,
                        options: widget.options.languages,
                        selected: _draft.languages,
                        onChanged: (next) {
                          setState(() {
                            _draft = _draft.copyWith(languages: next);
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: OmniSpacing.xl),
                    _FilterSection(
                      title: 'Motif de visite',
                      icon: Icons.healing_outlined,
                      accent: _FilterAccents.visit,
                      child: _ChoiceWrap(
                        accent: _FilterAccents.visit,
                        options: widget.options.visitReasons,
                        selected: _draft.visitReasons,
                        onChanged: (next) {
                          setState(() {
                            _draft = _draft.copyWith(visitReasons: next);
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: OmniSpacing.xl),
                    _FilterSection(
                      title: 'Assurance',
                      icon: Icons.shield_outlined,
                      accent: _FilterAccents.insurance,
                      child: _ChoiceWrap(
                        accent: _FilterAccents.insurance,
                        options: widget.options.insuranceOptions,
                        selected: _draft.insuranceAccepted,
                        onChanged: (next) {
                          setState(() {
                            _draft = _draft.copyWith(insuranceAccepted: next);
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: OmniSpacing.xl),
                    _FilterSection(
                      title: 'Expérience',
                      icon: Icons.workspace_premium_outlined,
                      accent: _FilterAccents.experience,
                      child: _SingleChoiceWrap(
                        accent: _FilterAccents.experience,
                        options: widget.options.experienceOptions,
                        selected: _draft.experience,
                        onChanged: (value) {
                          setState(() {
                            if (value == null) {
                              _draft = _draft.copyWith(clearExperience: true);
                            } else {
                              _draft = _draft.copyWith(experience: value);
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: OmniSpacing.xl),
                    _FilterSection(
                      title: 'Lieu de pratique',
                      icon: Icons.apartment_outlined,
                      accent: _FilterAccents.location,
                      child: _SingleChoiceWrap(
                        accent: _FilterAccents.location,
                        options: widget.options.practiceLocationOptions,
                        selected: _draft.practiceLocationType,
                        onChanged: (value) {
                          setState(() {
                            if (value == null) {
                              _draft = _draft.copyWith(
                                clearPracticeLocationType: true,
                              );
                            } else {
                              _draft = _draft.copyWith(
                                practiceLocationType: value,
                              );
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: OmniSpacing.xl),
                    _FilterSection(
                      title: 'Moment de la journée',
                      icon: Icons.wb_sunny_outlined,
                      accent: _FilterAccents.schedule,
                      child: _SingleChoiceWrap(
                        accent: _FilterAccents.schedule,
                        options: widget.options.timeOfDayOptions,
                        selected: _draft.timeOfDay,
                        onChanged: (value) {
                          setState(() {
                            if (value == null) {
                              _draft = _draft.copyWith(clearTimeOfDay: true);
                            } else {
                              _draft = _draft.copyWith(timeOfDay: value);
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: OmniSpacing.xl),
                    _FilterSection(
                      title: 'Services',
                      icon: Icons.miscellaneous_services_outlined,
                      accent: _FilterAccents.service,
                      child: _ToggleFilters(
                        draft: _draft,
                        onChanged: (next) {
                          setState(() {
                            _draft = next;
                          });
                        },
                      ),
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
              filteredCount: applyDoctorFilters(
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

class _SingleChoiceWrap extends StatelessWidget {
  const _SingleChoiceWrap({
    required this.accent,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

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
        for (final option in options)
          _OptionChip(
            label: option,
            accent: accent,
            selected: selected == option,
            onSelected: (isSelected) {
              onChanged(isSelected ? option : null);
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
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OmniRadii.pill),
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _ToggleFilters extends StatelessWidget {
  const _ToggleFilters({required this.draft, required this.onChanged});

  final DoctorFilterSnapshot draft;
  final ValueChanged<DoctorFilterSnapshot> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ToggleRow(
          label: 'Disponible le samedi',
          value: draft.availableSaturday ?? false,
          accent: _FilterAccents.schedule,
          onChanged: (v) {
            onChanged(
              v
                  ? draft.copyWith(availableSaturday: true)
                  : draft.copyWith(clearAvailableSaturday: true),
            );
          },
        ),
        const SizedBox(height: OmniSpacing.sm),
        _ToggleRow(
          label: 'Visite à domicile',
          value: draft.homeVisitAvailable ?? false,
          accent: _FilterAccents.service,
          onChanged: (v) {
            onChanged(
              v
                  ? draft.copyWith(homeVisitAvailable: true)
                  : draft.copyWith(clearHomeVisitAvailable: true),
            );
          },
        ),
        const SizedBox(height: OmniSpacing.sm),
        _ToggleRow(
          label: 'Garde / astreinte',
          value: draft.dutyService ?? false,
          accent: _FilterAccents.service,
          onChanged: (v) {
            onChanged(
              v
                  ? draft.copyWith(dutyService: true)
                  : draft.copyWith(clearDutyService: true),
            );
          },
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final _FilterAccent accent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: OmniSpacing.base,
          vertical: OmniSpacing.md,
        ),
        decoration: BoxDecoration(
          color: value ? accent.soft : Colors.transparent,
          borderRadius: BorderRadius.circular(OmniRadii.field),
          border: Border.all(
            color: value ? accent.active : OmniColors.borderLight,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: value ? accent.active : OmniColors.textPrimary,
                ),
              ),
            ),
            SizedBox(
              width: 44,
              height: 24,
              child: Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeTrackColor: accent.active,
              ),
            ),
          ],
        ),
      ),
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
                child: const Text('Réinitialiser'),
              ),
            ),
            const SizedBox(width: OmniSpacing.md),
            Expanded(
              child: ElevatedButton(
                onPressed: onApply,
                child: Text(
                  showCount
                      ? 'Afficher $filteredCount ${filteredCount == 1 ? 'médecin' : 'médecins'}'
                      : 'Appliquer',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
