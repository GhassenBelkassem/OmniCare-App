import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';
import '../profile/doctor_display_profile.dart';
import '../workspace/doctor_workspace_config.dart';

/// Five-step, local-only setup for a Doctor's D1 workspace.
class DoctorOnboardingScreen extends StatefulWidget {
  const DoctorOnboardingScreen({
    super.key,
    required this.doctorId,
    required this.profile,
    required this.onCompleted,
  });

  final String doctorId;
  final DoctorDisplayProfile profile;
  final Future<void> Function(DoctorWorkspaceConfig config) onCompleted;

  @override
  State<DoctorOnboardingScreen> createState() => _DoctorOnboardingScreenState();
}

class _DoctorOnboardingScreenState extends State<DoctorOnboardingScreen> {
  static const _clinicFixtures = <DoctorClinicAffiliation>[
    DoctorClinicAffiliation(id: 'clinique-carthage', name: 'Clinique Carthage'),
    DoctorClinicAffiliation(
      id: 'clinique-les-jasmins',
      name: 'Clinique Les Jasmins',
    ),
  ];

  final _cabinetNameController = TextEditingController();
  final _cabinetGovernorateController = TextEditingController();
  final _cabinetCityController = TextEditingController();
  final _cabinetAddressController = TextEditingController();
  final _homeGovernorateController = TextEditingController();
  final _homeRadiusController = TextEditingController();

  int _step = 0;
  bool _isSaving = false;
  String? _validationMessage;
  final Set<DoctorPracticeMode> _practiceModes = <DoctorPracticeMode>{};
  final Set<DoctorWorkspaceService> _services = <DoctorWorkspaceService>{};
  final Set<String> _clinicIds = <String>{};
  final Set<DoctorWorkingDay> _workingDays = {
    DoctorWorkingDay.monday,
    DoctorWorkingDay.tuesday,
    DoctorWorkingDay.wednesday,
    DoctorWorkingDay.thursday,
    DoctorWorkingDay.friday,
  };
  String _startTime = '08:00';
  String _endTime = '17:00';
  bool _availableForHomeVisits = true;

  bool get _hasHomeActivity =>
      _practiceModes.contains(DoctorPracticeMode.homeVisit) ||
      _practiceModes.contains(DoctorPracticeMode.urgentHome);

  @override
  void dispose() {
    _cabinetNameController.dispose();
    _cabinetGovernorateController.dispose();
    _cabinetCityController.dispose();
    _cabinetAddressController.dispose();
    _homeGovernorateController.dispose();
    _homeRadiusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: OmniColors.pageBackground,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _OnboardingTopBar(
              step: _step,
              isSaving: _isSaving,
              onBack: _goBack,
              textTheme: textTheme,
            ),
            Expanded(
              child: SingleChildScrollView(
                key: ValueKey('doctor-onboarding-step-${_step + 1}'),
                padding: const EdgeInsets.fromLTRB(
                  OmniSpacing.pageHorizontal,
                  OmniSpacing.pageVertical,
                  OmniSpacing.pageHorizontal,
                  OmniSpacing.xxl,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStepHeader(textTheme),
                        if (_validationMessage != null) ...[
                          const SizedBox(height: OmniSpacing.md),
                          _ValidationMessage(message: _validationMessage!),
                        ],
                        const SizedBox(height: OmniSpacing.xl),
                        _buildStepContent(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _OnboardingFooter(
              step: _step,
              isSaving: _isSaving,
              onContinue: _continue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepHeader(TextTheme textTheme) {
    final title = switch (_step) {
      0 => 'Votre activité',
      1 => 'Vos lieux d’exercice',
      2 => 'Vos services',
      3 => 'Vos disponibilités',
      _ => 'Votre espace médecin',
    };
    final subtitle = switch (_step) {
      0 => "Comment exercez-vous aujourd'hui ?",
      1 => 'Ajoutez uniquement les informations utiles à votre pratique.',
      2 => 'Choisissez ce que votre espace préparera pour vous.',
      3 => 'Une base simple pour votre futur agenda.',
      _ => 'Vérifiez votre configuration avant de continuer.',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: OmniSpacing.sm),
        Text(
          subtitle,
          style: textTheme.bodyMedium?.copyWith(
            color: OmniColors.textSecondary,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildStepContent() {
    return switch (_step) {
      0 => _buildActivityStep(),
      1 => _buildLocationsStep(),
      2 => _buildServicesStep(),
      3 => _buildAvailabilityStep(),
      _ => _buildReviewStep(),
    };
  }

  Widget _buildActivityStep() {
    return Column(
      children: DoctorPracticeMode.values
          .map(
            (mode) => Padding(
              padding: const EdgeInsets.only(bottom: OmniSpacing.sm),
              child: _SelectionCard(
                key: ValueKey('doctor-onboarding-mode-${mode.name}'),
                label: mode.label,
                detail: _practiceModeDetail(mode),
                icon: _practiceModeIcon(mode),
                selected: _practiceModes.contains(mode),
                onTap: () => _togglePracticeMode(mode),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildLocationsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_practiceModes.contains(DoctorPracticeMode.cabinet)) ...[
          _SectionLabel(label: 'Cabinet'),
          const SizedBox(height: OmniSpacing.md),
          _textField(
            key: const ValueKey('doctor-cabinet-name'),
            controller: _cabinetNameController,
            label: 'Nom du cabinet',
          ),
          const SizedBox(height: OmniSpacing.md),
          _textField(
            key: const ValueKey('doctor-cabinet-governorate'),
            controller: _cabinetGovernorateController,
            label: 'Gouvernorat',
          ),
          const SizedBox(height: OmniSpacing.md),
          _textField(
            key: const ValueKey('doctor-cabinet-city'),
            controller: _cabinetCityController,
            label: 'Ville',
          ),
          const SizedBox(height: OmniSpacing.md),
          _textField(
            key: const ValueKey('doctor-cabinet-address'),
            controller: _cabinetAddressController,
            label: 'Adresse',
            maxLines: 2,
          ),
          const SizedBox(height: OmniSpacing.xl),
        ],
        if (_practiceModes.contains(DoctorPracticeMode.clinic)) ...[
          _SectionLabel(label: 'Affiliations cliniques'),
          const SizedBox(height: OmniSpacing.md),
          ..._clinicFixtures.map(
            (clinic) => Padding(
              padding: const EdgeInsets.only(bottom: OmniSpacing.sm),
              child: _SelectionCard(
                key: ValueKey('doctor-clinic-${clinic.id}'),
                label: clinic.name,
                detail: 'Affiliation de démonstration',
                icon: Icons.local_hospital_outlined,
                selected: _clinicIds.contains(clinic.id),
                onTap: () => setState(() {
                  _clinicIds.contains(clinic.id)
                      ? _clinicIds.remove(clinic.id)
                      : _clinicIds.add(clinic.id);
                  _validationMessage = null;
                }),
              ),
            ),
          ),
          const SizedBox(height: OmniSpacing.xl),
        ],
        if (_hasHomeActivity) ...[
          _SectionLabel(label: 'Zone de visites à domicile'),
          const SizedBox(height: OmniSpacing.md),
          _textField(
            key: const ValueKey('doctor-home-governorate'),
            controller: _homeGovernorateController,
            label: 'Gouvernorat ou zone de service',
          ),
          const SizedBox(height: OmniSpacing.md),
          _textField(
            key: const ValueKey('doctor-home-radius'),
            controller: _homeRadiusController,
            label: 'Distance maximale (km, optionnel)',
            keyboardType: TextInputType.number,
          ),
        ],
      ],
    );
  }

  Widget _buildServicesStep() {
    final services = _availableServices;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ces choix préparent votre espace. Ils pourront évoluer avec vos outils.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: OmniColors.textSecondary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: OmniSpacing.lg),
        Wrap(
          spacing: OmniSpacing.sm,
          runSpacing: OmniSpacing.sm,
          children: services
              .map(
                (service) => FilterChip(
                  key: ValueKey('doctor-service-${service.name}'),
                  label: Text(service.label),
                  selected: _services.contains(service),
                  onSelected: (_) => setState(() {
                    _services.contains(service)
                        ? _services.remove(service)
                        : _services.add(service);
                  }),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }

  Widget _buildAvailabilityStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: 'Jours travaillés'),
        const SizedBox(height: OmniSpacing.md),
        Wrap(
          spacing: OmniSpacing.sm,
          runSpacing: OmniSpacing.sm,
          children: DoctorWorkingDay.values
              .map(
                (day) => FilterChip(
                  key: ValueKey('doctor-day-${day.name}'),
                  label: Text(day.shortLabel),
                  selected: _workingDays.contains(day),
                  onSelected: (_) => setState(() {
                    _workingDays.contains(day)
                        ? _workingDays.remove(day)
                        : _workingDays.add(day);
                    _validationMessage = null;
                  }),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: OmniSpacing.xl),
        Row(
          children: [
            Expanded(
              child: _timePicker(
                label: 'Début',
                value: _startTime,
                onChanged: (value) => setState(() => _startTime = value),
              ),
            ),
            const SizedBox(width: OmniSpacing.md),
            Expanded(
              child: _timePicker(
                label: 'Fin',
                value: _endTime,
                onChanged: (value) => setState(() => _endTime = value),
              ),
            ),
          ],
        ),
        if (_hasHomeActivity) ...[
          const SizedBox(height: OmniSpacing.xl),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Disponible pour les visites à domicile'),
            subtitle: const Text('Cette disponibilité reste locale pour D1.'),
            value: _availableForHomeVisits,
            activeThumbColor: OmniColors.freshMint,
            onChanged: (value) =>
                setState(() => _availableForHomeVisits = value),
          ),
        ],
      ],
    );
  }

  Widget _buildReviewStep() {
    final clinics = _clinicFixtures
        .where((clinic) => _clinicIds.contains(clinic.id))
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ReviewCard(
          title: 'Votre activité',
          value: _practiceModes.map((mode) => mode.label).join(' · '),
        ),
        if (_practiceModes.contains(DoctorPracticeMode.cabinet)) ...[
          const SizedBox(height: OmniSpacing.md),
          _ReviewCard(
            title: 'Cabinet',
            value:
                '${_cabinetNameController.text.trim()} · ${_cabinetCityController.text.trim()}',
          ),
        ],
        if (clinics.isNotEmpty) ...[
          const SizedBox(height: OmniSpacing.md),
          _ReviewCard(
            title: 'Cliniques',
            value: clinics.map((clinic) => clinic.name).join(' · '),
          ),
        ],
        if (_hasHomeActivity) ...[
          const SizedBox(height: OmniSpacing.md),
          _ReviewCard(
            title: 'Visites à domicile',
            value: _homeGovernorateController.text.trim(),
          ),
        ],
        const SizedBox(height: OmniSpacing.md),
        _ReviewCard(
          title: 'Disponibilités',
          value:
              '${_workingDays.map((day) => day.shortLabel).join(', ')} · $_startTime → $_endTime',
        ),
        const SizedBox(height: OmniSpacing.lg),
        TextButton.icon(
          onPressed: () => setState(() => _step = 0),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Modifier'),
        ),
      ],
    );
  }

  Widget _textField({
    required Key key,
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      textInputAction: maxLines > 1
          ? TextInputAction.newline
          : TextInputAction.next,
      decoration: InputDecoration(labelText: label),
      onChanged: (_) {
        if (_validationMessage != null) {
          setState(() => _validationMessage = null);
        }
      },
    );
  }

  Widget _timePicker({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    const values = ['07:00', '08:00', '09:00', '12:00', '17:00', '18:00'];
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: values
          .map((time) => DropdownMenuItem(value: time, child: Text(time)))
          .toList(growable: false),
      onChanged: (selected) {
        if (selected != null) {
          onChanged(selected);
        }
      },
    );
  }

  void _togglePracticeMode(DoctorPracticeMode mode) {
    setState(() {
      _practiceModes.contains(mode)
          ? _practiceModes.remove(mode)
          : _practiceModes.add(mode);
      _services
        ..clear()
        ..addAll(_availableServices);
      _validationMessage = null;
    });
  }

  List<DoctorWorkspaceService> get _availableServices {
    final services = <DoctorWorkspaceService>[];
    if (_practiceModes.contains(DoctorPracticeMode.cabinet)) {
      services.addAll([
        DoctorWorkspaceService.cabinetConsultations,
        DoctorWorkspaceService.patientFollowUp,
        DoctorWorkspaceService.appointments,
      ]);
    }
    if (_practiceModes.contains(DoctorPracticeMode.homeVisit)) {
      services.add(DoctorWorkspaceService.homeVisits);
    }
    if (_practiceModes.contains(DoctorPracticeMode.urgentHome)) {
      services.add(DoctorWorkspaceService.urgentHomeVisits);
    }
    if (_practiceModes.contains(DoctorPracticeMode.clinic)) {
      services.add(DoctorWorkspaceService.clinicWorkspace);
    }
    if (_practiceModes.contains(DoctorPracticeMode.teleconsultation)) {
      services.add(DoctorWorkspaceService.teleconsultationPreparation);
    }
    return services;
  }

  Future<void> _continue() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_validateCurrentStep()) return;
    if (_step < 4) {
      setState(() {
        _step += 1;
        _validationMessage = null;
      });
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.onCompleted(_buildConfig());
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _validationMessage =
              'Impossible d’enregistrer cette configuration localement.';
        });
      }
    }
  }

  bool _validateCurrentStep() {
    String? message;
    if (_step == 0 && _practiceModes.isEmpty) {
      message = 'Sélectionnez au moins une façon d’exercer.';
    } else if (_step == 1) {
      if (_practiceModes.contains(DoctorPracticeMode.cabinet) &&
          [
            _cabinetNameController,
            _cabinetGovernorateController,
            _cabinetCityController,
            _cabinetAddressController,
          ].any((controller) => controller.text.trim().isEmpty)) {
        message = 'Complétez les informations principales de votre cabinet.';
      } else if (_practiceModes.contains(DoctorPracticeMode.clinic) &&
          _clinicIds.isEmpty) {
        message = 'Sélectionnez au moins une affiliation clinique.';
      } else if (_hasHomeActivity &&
          _homeGovernorateController.text.trim().isEmpty) {
        message = 'Indiquez votre zone de service à domicile.';
      }
    } else if (_step == 3 && _workingDays.isEmpty) {
      message = 'Sélectionnez au moins un jour travaillé.';
    }
    if (message == null) return true;
    setState(() => _validationMessage = message);
    return false;
  }

  DoctorWorkspaceConfig _buildConfig() {
    final clinics = _clinicFixtures
        .where((clinic) => _clinicIds.contains(clinic.id))
        .toList(growable: false);
    return DoctorWorkspaceConfig(
      doctorId: widget.doctorId,
      onboardingCompleted: true,
      practiceModes: Set<DoctorPracticeMode>.from(_practiceModes),
      services: Set<DoctorWorkspaceService>.from(_services),
      cabinet: _practiceModes.contains(DoctorPracticeMode.cabinet)
          ? DoctorCabinetConfig(
              name: _cabinetNameController.text.trim(),
              governorate: _cabinetGovernorateController.text.trim(),
              city: _cabinetCityController.text.trim(),
              address: _cabinetAddressController.text.trim(),
            )
          : null,
      clinics: clinics,
      homeVisit: _hasHomeActivity
          ? DoctorHomeVisitConfig(
              governorate: _homeGovernorateController.text.trim(),
              maxDistanceKm: int.tryParse(_homeRadiusController.text.trim()),
              availableForHomeVisits: _availableForHomeVisits,
            )
          : null,
      availability: DoctorAvailability(
        workingDays: Set<DoctorWorkingDay>.from(_workingDays),
        startTime: _startTime,
        endTime: _endTime,
      ),
    );
  }

  void _goBack() => setState(() {
    _step -= 1;
    _validationMessage = null;
  });

  String _practiceModeDetail(DoctorPracticeMode mode) => switch (mode) {
    DoctorPracticeMode.cabinet => 'Recevez vos patients dans votre cabinet.',
    DoctorPracticeMode.clinic => 'Ajoutez une affiliation clinique locale.',
    DoctorPracticeMode.homeVisit => 'Planifiez vos visites à domicile.',
    DoctorPracticeMode.urgentHome => 'Préparez les urgences à domicile.',
    DoctorPracticeMode.teleconsultation => 'Préparez une option future.',
  };

  IconData _practiceModeIcon(DoctorPracticeMode mode) => switch (mode) {
    DoctorPracticeMode.cabinet => Icons.medical_services_outlined,
    DoctorPracticeMode.clinic => Icons.local_hospital_outlined,
    DoctorPracticeMode.homeVisit => Icons.home_work_outlined,
    DoctorPracticeMode.urgentHome => Icons.emergency_outlined,
    DoctorPracticeMode.teleconsultation => Icons.videocam_outlined,
  };
}

class _OnboardingTopBar extends StatelessWidget {
  const _OnboardingTopBar({
    required this.step,
    required this.isSaving,
    required this.onBack,
    required this.textTheme,
  });

  final int step;
  final bool isSaving;
  final VoidCallback onBack;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: OmniColors.surfacePrimary,
        border: Border(bottom: BorderSide(color: OmniColors.borderLight)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 68,
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  child: step == 0
                      ? null
                      : IconButton(
                          tooltip: 'Retour',
                          onPressed: isSaving ? null : onBack,
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                ),
                Expanded(
                  child: Text(
                    'OmniCare',
                    style: textTheme.titleMedium?.copyWith(
                      color: OmniColors.deepTeal,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: OmniSpacing.base),
                  child: Text(
                    'Étape ${step + 1} sur 5',
                    style: textTheme.labelMedium?.copyWith(
                      color: OmniColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          LinearProgressIndicator(
            value: (step + 1) / 5,
            minHeight: 4,
            backgroundColor: OmniColors.slateSoft,
            color: OmniColors.freshMint,
          ),
        ],
      ),
    );
  }
}

class _OnboardingFooter extends StatelessWidget {
  const _OnboardingFooter({
    required this.step,
    required this.isSaving,
    required this.onContinue,
  });

  final int step;
  final bool isSaving;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: OmniColors.surfacePrimary,
        border: Border(top: BorderSide(color: OmniColors.borderLight)),
      ),
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal,
        OmniSpacing.md,
        OmniSpacing.pageHorizontal,
        OmniSpacing.md,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('doctor-onboarding-continue'),
              onPressed: isSaving ? null : onContinue,
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(step == 4 ? 'Terminer la configuration' : 'Continuer'),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  const _SelectionCard({
    super.key,
    required this.label,
    required this.detail,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String detail;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(OmniRadii.card),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(OmniSpacing.base),
            decoration: BoxDecoration(
              color: selected ? OmniColors.mintSoft : OmniColors.surfacePrimary,
              borderRadius: BorderRadius.circular(OmniRadii.card),
              border: Border.all(
                color: selected ? OmniColors.freshMint : OmniColors.borderLight,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: selected
                        ? OmniColors.surfacePrimary
                        : OmniColors.slateSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: selected
                        ? OmniColors.deepTeal
                        : OmniColors.slateBlue,
                    size: 21,
                  ),
                ),
                const SizedBox(width: OmniSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: textTheme.bodySmall?.copyWith(
                          color: OmniColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.add_circle_outline_rounded,
                  color: selected
                      ? OmniColors.primaryAction
                      : OmniColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
  );
}

class _ValidationMessage extends StatelessWidget {
  const _ValidationMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(OmniSpacing.md),
    decoration: BoxDecoration(
      color: OmniColors.errorSoft,
      borderRadius: BorderRadius.circular(OmniRadii.field),
      border: Border.all(color: OmniColors.error.withValues(alpha: 0.25)),
    ),
    child: Text(
      message,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: OmniColors.error,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(OmniSpacing.base),
    decoration: BoxDecoration(
      color: OmniColors.slateSoft,
      borderRadius: BorderRadius.circular(OmniRadii.card),
      border: Border.all(color: OmniColors.borderLight),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: OmniColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: OmniSpacing.xs),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}
