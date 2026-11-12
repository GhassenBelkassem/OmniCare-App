import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/omni_theme.dart';
import '../application/patient_scheduled_care_controller.dart';
import '../domain/patient_scheduled_care_models.dart';
import '../domain/scheduled_care_models.dart';
import '../realtime/scheduled_care_route_visibility.dart';
import '../../pending_answers/application/pending_answers_controller.dart';
import '../../pending_answers/presentation/pending_answers_section.dart';
import 'booking_review_screen.dart';
import 'scheduled_care_resource_resolver.dart';

class PatientScheduledCareScreen extends StatefulWidget {
  const PatientScheduledCareScreen({super.key});

  @override
  State<PatientScheduledCareScreen> createState() =>
      _PatientScheduledCareScreenState();
}

class _PatientScheduledCareScreenState extends State<PatientScheduledCareScreen>
    with ScheduledCareRouteVisibility<PatientScheduledCareScreen> {
  late final TextEditingController _searchController;
  late final PatientScheduledCareController _realtimeController;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    final controller = _realtimeController = context
        .read<PatientScheduledCareController>();
    _searchController = TextEditingController(text: controller.query);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !controller.hasLoaded) controller.load();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    onScheduledCareRouteVisibilityChanged(false);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void onScheduledCareRouteVisibilityChanged(bool visible) {
    _realtimeController.setRealtimeActive(visible);
  }

  void _search(PatientScheduledCareController controller, String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => controller.setQuery(value),
    );
  }

  Future<void> _openFilters(PatientScheduledCareController controller) async {
    final filters = await showModalBottomSheet<PatientScheduledCareFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _ScheduledCareFilterSheet(
        initial: controller.filters,
        knownCities:
            controller.items
                .map((item) => item.cabinet.city)
                .where((city) => city.trim().isNotEmpty)
                .toSet()
                .toList()
              ..sort(),
      ),
    );
    if (filters != null && mounted) await controller.setFilters(filters);
  }

  Future<void> _open(
    PatientScheduledCareController controller,
    PatientScheduledCareItem item,
  ) async {
    await ScheduledCareResourceResolver.openItem(context, item);
    if (mounted) await controller.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PatientScheduledCareController>();
    return Scaffold(
      backgroundColor: OmniColors.pageBackground,
      appBar: AppBar(
        title: const Text('Mes rendez-vous'),
        actions: [
          IconButton(
            key: const ValueKey('scheduled-care-list-refresh'),
            tooltip: 'Actualiser',
            onPressed: controller.isLoading ? null : controller.refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
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
          // G-1 D2 / D4: « En attente de votre réponse » (hidden when empty).
          PendingAnswersSection(onProposalConfirmed: controller.refresh),
          _BucketTabs(controller: controller),
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
                    onChanged: (value) => _search(controller, value),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (value) {
                      _searchDebounce?.cancel();
                      controller.setQuery(value);
                    },
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
          Expanded(child: _body(controller)),
        ],
      ),
    );
  }

  Widget _body(PatientScheduledCareController controller) {
    if (controller.isLoading && controller.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.state == PatientScheduledCareLoadState.failed &&
        controller.items.isEmpty) {
      return _LoadFailure(
        message:
            controller.failure?.message ??
            'Les rendez-vous sont indisponibles.',
        onRetry: controller.load,
      );
    }
    if (controller.items.isEmpty) {
      final filtersActive =
          controller.filters.isActive || controller.query.isNotEmpty;
      return _EmptyState(
        bucket: controller.bucket,
        filtersActive: filtersActive,
        onReset: () {
          _searchController.clear();
          controller.resetSearchAndFilters();
        },
      );
    }
    return RefreshIndicator(
      onRefresh: () => Future.wait([
        controller.refresh(),
        context.read<PendingAnswersController?>()?.refresh(
              keepAnswered: false,
            ) ??
            Future<void>.value(),
      ]),
      child: ListView.separated(
        key: PageStorageKey<String>('scheduled-care-${controller.bucket.name}'),
        padding: const EdgeInsets.fromLTRB(
          OmniSpacing.pageHorizontal,
          0,
          OmniSpacing.pageHorizontal,
          OmniSpacing.xxl,
        ),
        itemCount:
            controller.items.length + (controller.nextCursor != null ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: OmniSpacing.sm),
        itemBuilder: (context, index) {
          if (index == controller.items.length) {
            return Center(
              child: TextButton.icon(
                key: const ValueKey('scheduled-care-load-more'),
                onPressed: controller.canLoadMore ? controller.loadMore : null,
                icon: controller.isLoadingMore
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_rounded),
                label: const Text('Charger la suite'),
              ),
            );
          }
          final item = controller.items[index];
          return _ScheduledCareCard(
            item: item,
            emphasized:
                controller.bucket == PatientScheduledCareBucket.upcoming &&
                index == 0,
            onTap: () => _open(controller, item),
          );
        },
      ),
    );
  }
}

class _BucketTabs extends StatelessWidget {
  const _BucketTabs({required this.controller});
  final PatientScheduledCareController controller;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.pageHorizontal),
    child: Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: OmniColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(OmniRadii.field),
      ),
      child: Row(
        children: [
          for (final bucket in PatientScheduledCareBucket.values)
            Expanded(
              child: Semantics(
                button: true,
                selected: controller.bucket == bucket,
                label: _bucketLabel(bucket),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => controller.setBucket(bucket),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: controller.bucket == bucket
                          ? OmniColors.surfacePrimary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: controller.bucket == bucket
                          ? const [OmniColors.shadowSm]
                          : null,
                    ),
                    child: Text(
                      _bucketLabel(bucket),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: controller.bucket == bucket
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

class _ScheduledCareCard extends StatelessWidget {
  const _ScheduledCareCard({
    required this.item,
    required this.onTap,
    this.emphasized = false,
  });

  final PatientScheduledCareItem item;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${item.doctor.displayName}, ${item.subject.displayName}',
    child: Material(
      color: OmniColors.surfacePrimary,
      borderRadius: BorderRadius.circular(OmniRadii.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        child: Container(
          padding: const EdgeInsets.all(OmniSpacing.base),
          decoration: BoxDecoration(
            color: emphasized ? OmniColors.mintSoft : null,
            borderRadius: BorderRadius.circular(OmniRadii.card),
            border: Border.all(
              color: emphasized ? OmniColors.freshMint : OmniColors.borderLight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      formatSchedulingDateTime(
                        item.start,
                        timezone: item.timezone,
                      ),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: OmniSpacing.sm),
                  _StatusChip(item: item),
                ],
              ),
              const SizedBox(height: OmniSpacing.base),
              Row(
                children: [
                  _DoctorAvatar(name: item.doctor.displayName),
                  const SizedBox(width: OmniSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.doctor.displayName,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        if (item.doctor.specialty case final specialty?)
                          Text(
                            specialty,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: OmniColors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: OmniColors.textTertiary,
                  ),
                ],
              ),
              const SizedBox(height: OmniSpacing.base),
              _Meta(
                icon: Icons.location_on_outlined,
                value: '${item.cabinet.name} · ${item.cabinet.city}',
              ),
              const SizedBox(height: OmniSpacing.xs),
              _Meta(
                icon: Icons.person_outline_rounded,
                value: 'Pour : ${item.subject.displayName}',
              ),
              const SizedBox(height: OmniSpacing.xs),
              _Meta(icon: Icons.public_rounded, value: item.timezone),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DoctorAvatar extends StatelessWidget {
  const _DoctorAvatar({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .replaceFirst(RegExp(r'^Dr\.\s*'), '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: OmniColors.mintSoft,
        borderRadius: BorderRadius.circular(OmniRadii.field),
      ),
      child: Text(
        initials,
        style: const TextStyle(
          color: OmniColors.deepTealActive,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.item});
  final PatientScheduledCareItem item;

  @override
  Widget build(BuildContext context) {
    final label = switch (item.status) {
      'PENDING_DOCTOR' => 'En attente',
      'PENDING_PATIENT_TIME_CONFIRMATION' => 'À confirmer',
      'CONFIRMED' => 'Confirmé',
      'IN_PROGRESS' => 'En cours',
      'COMPLETED' => 'Terminé',
      'NO_SHOW' => 'Non présenté',
      'CANCELLED' ||
      'CANCELLED_BY_PATIENT' ||
      'CANCELLED_BY_DOCTOR' => 'Annulé',
      'EXPIRED' => 'Expiré',
      _ => 'À vérifier',
    };
    final cancelled =
        item.status.contains('CANCELLED') || item.status == 'EXPIRED';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: cancelled ? OmniColors.errorSoft : OmniColors.mintSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: cancelled ? OmniColors.error : OmniColors.deepTealActive,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.value});
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: OmniColors.slateBlue),
      const SizedBox(width: OmniSpacing.sm),
      Expanded(
        child: Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: OmniColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onPressed});
  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    width: 52,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        OutlinedButton(
          key: const ValueKey('appointment-filter-button'),
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
          child: const Icon(Icons.tune_rounded, size: 20),
        ),
        if (count > 0)
          Positioned(
            right: -3,
            top: -5,
            child: CircleAvatar(
              radius: 9.5,
              backgroundColor: OmniColors.deepTeal,
              child: Text(
                '$count',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.bucket,
    required this.filtersActive,
    required this.onReset,
  });
  final PatientScheduledCareBucket bucket;
  final bool filtersActive;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Center(
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
            filtersActive
                ? 'Aucun rendez-vous ne correspond à vos filtres.'
                : 'Aucun rendez-vous ${_emptySuffix(bucket)}',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
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

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(OmniSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 48),
          const SizedBox(height: OmniSpacing.md),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: OmniSpacing.sm),
          TextButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    ),
  );
}

class _ScheduledCareFilterSheet extends StatefulWidget {
  const _ScheduledCareFilterSheet({
    required this.initial,
    required this.knownCities,
  });
  final PatientScheduledCareFilters initial;
  final List<String> knownCities;

  @override
  State<_ScheduledCareFilterSheet> createState() =>
      _ScheduledCareFilterSheetState();
}

class _ScheduledCareFilterSheetState extends State<_ScheduledCareFilterSheet> {
  late PatientScheduledCareFilters _draft = widget.initial;

  Future<void> _choosePeriod() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5, 12, 31),
      initialDateRange: _draft.from != null && _draft.to != null
          ? DateTimeRange(start: _draft.from!, end: _draft.to!)
          : DateTimeRange(start: now, end: now.add(const Duration(days: 30))),
    );
    if (!mounted || range == null) return;
    setState(() {
      _draft = _draft.copyWith(
        from: DateTime.utc(
          range.start.year,
          range.start.month,
          range.start.day,
        ),
        to: DateTime.utc(range.end.year, range.end.month, range.end.day + 1),
      );
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal,
        OmniSpacing.xs,
        OmniSpacing.pageHorizontal,
        OmniSpacing.base,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Filtrer les rendez-vous',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: OmniSpacing.base),
          Text('Pour qui ?', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: OmniSpacing.xs),
          Wrap(
            spacing: OmniSpacing.xs,
            children: [
              ChoiceChip(
                label: const Text('Moi'),
                selected: _draft.subjectType == CareSubjectType.self,
                onSelected: (_) => setState(() {
                  _draft = _draft.copyWith(subjectType: CareSubjectType.self);
                }),
              ),
              ChoiceChip(
                label: const Text('Membre de la famille'),
                selected: _draft.subjectType == CareSubjectType.familyMember,
                onSelected: (_) => setState(() {
                  _draft = _draft.copyWith(
                    subjectType: CareSubjectType.familyMember,
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: OmniSpacing.lg),
          OutlinedButton.icon(
            onPressed: _choosePeriod,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(
              _draft.from == null
                  ? 'Choisir une période'
                  : 'Période sélectionnée',
            ),
          ),
          if (widget.knownCities.isNotEmpty) ...[
            const SizedBox(height: OmniSpacing.lg),
            Text('Ville', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: OmniSpacing.xs),
            Wrap(
              spacing: OmniSpacing.xs,
              children: [
                for (final city in widget.knownCities)
                  ChoiceChip(
                    label: Text(city),
                    selected: _draft.city == city,
                    onSelected: (_) => setState(() {
                      _draft = _draft.copyWith(city: city);
                    }),
                  ),
              ],
            ),
          ],
          const SizedBox(height: OmniSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _draft.isActive
                      ? () => setState(() {
                          _draft = PatientScheduledCareFilters.none;
                        })
                      : null,
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
        ],
      ),
    ),
  );
}

String _bucketLabel(PatientScheduledCareBucket bucket) => switch (bucket) {
  PatientScheduledCareBucket.upcoming => 'À venir',
  PatientScheduledCareBucket.past => 'Passés',
  PatientScheduledCareBucket.cancelled => 'Annulés',
};

String _emptySuffix(PatientScheduledCareBucket bucket) => switch (bucket) {
  PatientScheduledCareBucket.upcoming => 'à venir',
  PatientScheduledCareBucket.past => 'passé',
  PatientScheduledCareBucket.cancelled => 'annulé',
};
