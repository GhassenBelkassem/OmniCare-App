import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/omni_theme.dart';
import '../application/patient_appointments_controller.dart';
import '../data/patient_appointment_models.dart';
import 'patient_appointment_detail_screen.dart';
import 'patient_appointment_filter_sheet.dart';
import '../../scheduled_care/presentation/patient_scheduled_care_screen.dart';
import 'widgets/appointment_formatters.dart';
import 'widgets/patient_appointment_card.dart';

class PatientAppointmentsScreen extends StatefulWidget {
  const PatientAppointmentsScreen({super.key, this.controller});

  final PatientAppointmentsController? controller;

  @override
  State<PatientAppointmentsScreen> createState() =>
      _PatientAppointmentsScreenState();
}

class _PatientAppointmentsScreenState extends State<PatientAppointmentsScreen> {
  PatientAppointmentsController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return const PatientScheduledCareScreen();
    return ChangeNotifierProvider<PatientAppointmentsController>.value(
      value: controller,
      child: const _PatientAppointmentsContent(),
    );
  }
}

class _PatientAppointmentsContent extends StatefulWidget {
  const _PatientAppointmentsContent();

  @override
  State<_PatientAppointmentsContent> createState() =>
      _PatientAppointmentsContentState();
}

class _PatientAppointmentsContentState
    extends State<_PatientAppointmentsContent> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: context.read<PatientAppointmentsController>().query,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openFilters(PatientAppointmentsController controller) async {
    final filters = await showPatientAppointmentFilterSheet(
      context: context,
      appointments: controller.appointments,
      initial: controller.filters,
    );
    if (filters != null && mounted) controller.setFilters(filters);
  }

  void _openDetail(
    PatientAppointment appointment,
    PatientAppointmentsController controller,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PatientAppointmentDetailScreen(
          appointmentId: appointment.appointmentId,
          controller: controller,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PatientAppointmentsController>();
    final appointments = controller.visibleAppointments();
    return Scaffold(
      backgroundColor: OmniColors.pageBackground,
      appBar: AppBar(title: const Text('Mes rendez-vous')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              OmniSpacing.pageHorizontal,
              OmniSpacing.md,
              OmniSpacing.pageHorizontal,
              OmniSpacing.sm,
            ),
            child: Text(
              'Retrouvez et gérez vos rendez-vous.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: OmniColors.textSecondary),
            ),
          ),
          _buildTabs(controller),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              OmniSpacing.pageHorizontal,
              OmniSpacing.sm,
              OmniSpacing.pageHorizontal,
              OmniSpacing.base,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('appointment-search'),
                    controller: _searchController,
                    onChanged: controller.setQuery,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Rechercher un rendez-vous',
                      prefixIcon: Icon(Icons.search_rounded),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: OmniSpacing.sm),
                _FilterButton(
                  count: controller.filters.activeCount,
                  onPressed: () => _openFilters(controller),
                ),
              ],
            ),
          ),
          Expanded(
            child: appointments.isEmpty
                ? _EmptyAppointments(
                    tab: controller.tab,
                    filtersActive:
                        controller.filters.isActive ||
                        controller.query.trim().isNotEmpty,
                    onReset: controller.resetFilters,
                  )
                : _AppointmentsList(
                    appointments: appointments,
                    tab: controller.tab,
                    onTap: (appointment) =>
                        _openDetail(appointment, controller),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(PatientAppointmentsController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: OmniSpacing.pageHorizontal,
      ),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: OmniColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(OmniRadii.field),
        ),
        child: Row(
          children: [
            for (final tab in PatientAppointmentTab.values)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: controller.tab == tab,
                  label: tab.label,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => controller.setTab(tab),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: controller.tab == tab
                            ? OmniColors.surfacePrimary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: controller.tab == tab
                            ? const [OmniColors.shadowSm]
                            : null,
                      ),
                      child: Text(
                        tab.label,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: controller.tab == tab
                                  ? OmniColors.deepTealActive
                                  : OmniColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

extension on PatientAppointmentTab {
  String get label => switch (this) {
    PatientAppointmentTab.upcoming => 'À venir',
    PatientAppointmentTab.past => 'Passés',
    PatientAppointmentTab.cancelled => 'Annulés',
  };
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      width: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          OutlinedButton(
            key: const ValueKey('appointment-filter-button'),
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              side: const BorderSide(color: OmniColors.borderLight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(OmniRadii.field),
              ),
            ),
            child: const Icon(Icons.tune_rounded, size: 20),
          ),
          if (count > 0)
            Positioned(
              right: -3,
              top: -5,
              child: Container(
                width: 19,
                height: 19,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: OmniColors.deepTeal,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AppointmentsList extends StatelessWidget {
  const _AppointmentsList({
    required this.appointments,
    required this.tab,
    required this.onTap,
  });

  final List<PatientAppointment> appointments;
  final PatientAppointmentTab tab;
  final ValueChanged<PatientAppointment> onTap;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    if (tab == PatientAppointmentTab.upcoming) {
      for (var index = 0; index < appointments.length; index++) {
        children.add(
          PatientAppointmentCard(
            appointment: appointments[index],
            emphasized: index == 0,
            onTap: () => onTap(appointments[index]),
          ),
        );
      }
    } else {
      final grouped = <int, Map<int, List<PatientAppointment>>>{};
      for (final appointment in appointments) {
        grouped
            .putIfAbsent(appointment.startAt.year, () => {})
            .putIfAbsent(appointment.startAt.month, () => [])
            .add(appointment);
      }
      final years = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
      for (final year in years) {
        children.add(_HistoryYearHeader(year: year));
        final months = grouped[year]!.keys.toList()
          ..sort((a, b) => b.compareTo(a));
        for (final month in months) {
          children.add(
            _HistoryMonthHeader(
              label: formatAppointmentMonth(DateTime(year, month)),
            ),
          );
          for (final appointment in grouped[year]![month]!) {
            children.add(
              PatientAppointmentCard(
                appointment: appointment,
                onTap: () => onTap(appointment),
              ),
            );
          }
        }
      }
    }
    return ListView.separated(
      key: PageStorageKey<String>('appointments-${tab.name}'),
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal,
        0,
        OmniSpacing.pageHorizontal,
        OmniSpacing.xxl,
      ),
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(height: OmniSpacing.sm),
      itemBuilder: (_, index) => children[index],
    );
  }
}

class _HistoryYearHeader extends StatelessWidget {
  const _HistoryYearHeader({required this.year});

  final int year;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: OmniSpacing.sm),
      child: Text(
        '$year',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: OmniColors.deepTealActive,
        ),
      ),
    );
  }
}

class _HistoryMonthHeader extends StatelessWidget {
  const _HistoryMonthHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: OmniSpacing.xs),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: OmniColors.textSecondary,
        ),
      ),
    );
  }
}

class _EmptyAppointments extends StatelessWidget {
  const _EmptyAppointments({
    required this.tab,
    required this.filtersActive,
    required this.onReset,
  });

  final PatientAppointmentTab tab;
  final bool filtersActive;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final title = filtersActive
        ? 'Aucun rendez-vous ne correspond à vos filtres.'
        : switch (tab) {
            PatientAppointmentTab.upcoming => 'Aucun rendez-vous à venir',
            PatientAppointmentTab.past => 'Aucun rendez-vous passé',
            PatientAppointmentTab.cancelled => 'Aucun rendez-vous annulé',
          };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(OmniSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.event_available_outlined,
              size: 52,
              color: OmniColors.slateBlue,
            ),
            const SizedBox(height: OmniSpacing.base),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (!filtersActive && tab == PatientAppointmentTab.upcoming) ...[
              const SizedBox(height: OmniSpacing.xs),
              const Text(
                'Vos prochains rendez-vous apparaîtront ici.',
                textAlign: TextAlign.center,
              ),
            ],
            if (filtersActive) ...[
              const SizedBox(height: OmniSpacing.sm),
              TextButton(
                onPressed: onReset,
                child: const Text('Réinitialiser les filtres'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
