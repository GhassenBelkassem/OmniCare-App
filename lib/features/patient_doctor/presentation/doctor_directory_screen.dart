import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/omni_theme.dart';
import '../application/doctor_discovery_context.dart';
import '../application/doctor_directory_controller.dart';
import '../data/doctor_directory_models.dart';
import '../data/doctor_models.dart';
import '../../scheduled_care/application/scheduled_care_controller.dart';
import '../../scheduled_care_prototype/scheduled_care_controller.dart';
import 'doctor_detail_screen.dart';
import 'widgets/doctor_card.dart';
import 'widgets/doctor_filter_sheet.dart';
import 'widgets/doctor_search_field.dart';

/// Backend-authoritative, paginated Patient Doctor directory.
class DoctorDirectoryScreen extends StatelessWidget {
  const DoctorDirectoryScreen({
    super.key,
    this.discoveryContext = DoctorDiscoveryContext.generic,
    this.scheduledBookingWorkflow = false,
  });

  final DoctorDiscoveryContext discoveryContext;
  final bool scheduledBookingWorkflow;

  @override
  Widget build(BuildContext context) {
    final inherited = context.read<DoctorDirectoryController>();
    if (inherited.discoveryContext == discoveryContext) {
      return _DoctorDirectoryView(
        scheduledBookingWorkflow: scheduledBookingWorkflow,
      );
    }
    return ChangeNotifierProvider<DoctorDirectoryController>(
      create: (_) => inherited.forDiscoveryContext(discoveryContext),
      child: _DoctorDirectoryView(
        scheduledBookingWorkflow: scheduledBookingWorkflow,
      ),
    );
  }
}

class _DoctorDirectoryView extends StatefulWidget {
  const _DoctorDirectoryView({required this.scheduledBookingWorkflow});

  final bool scheduledBookingWorkflow;

  @override
  State<_DoctorDirectoryView> createState() => _DoctorDirectoryViewState();
}

class _DoctorDirectoryViewState extends State<_DoctorDirectoryView> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  DoctorSearchLocation? _searchLocation;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = context.read<DoctorDirectoryController>();
      if (controller.status == DoctorDirectoryStatus.idle) {
        controller.loadFirst();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openFilters() async {
    final directory = context.read<DoctorDirectoryController>();
    final result = await showDoctorFilterSheet(
      context: context,
      initial: directory.filters,
    );
    if (!mounted || result == null || result == directory.filters) return;

    var location = _searchLocation;
    if (result.maxDistanceKm != null && location == null) {
      location = await _requestSearchLocation();
      if (!mounted || location == null) return;
    }
    if (result.maxDistanceKm == null) location = null;
    _searchLocation = location;
    await directory.applyFilters(result, location: location);
  }

  Future<void> _resetFilters() async {
    _searchLocation = null;
    _searchController.clear();
    await context.read<DoctorDirectoryController>().clearSearchAndFilters();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 320) {
      context.read<DoctorDirectoryController>().loadNext();
    }
  }

  Future<DoctorSearchLocation?> _requestSearchLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showLocationMessage(
          'Activez la localisation pour filtrer les médecins par distance.',
        );
        return null;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showLocationMessage(
          'Autorisez la localisation pour appliquer ce rayon.',
        );
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      return DoctorSearchLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      _showLocationMessage(
        'Votre position est indisponible. Réessayez ou retirez le rayon.',
      );
      return null;
    }
  }

  void _showLocationMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openDoctorDetail(DoctorListItem doctor) {
    final directory = context.read<DoctorDirectoryController>();
    final scheduledCare = widget.scheduledBookingWorkflow
        ? context.read<ScheduledCareController?>()
        : null;
    final prototypeCare =
        widget.scheduledBookingWorkflow && scheduledCare == null
        ? context.read<ScheduledCarePrototypeController?>()
        : null;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) {
          Widget detail =
              ChangeNotifierProvider<DoctorDirectoryController>.value(
                value: directory,
                child: DoctorDetailScreen(
                  doctorId: doctor.id,
                  preferredPracticeLocationId:
                      doctor.matchingPracticeLocation?.practiceLocationId,
                  scheduledBookingWorkflow: widget.scheduledBookingWorkflow,
                ),
              );
          if (scheduledCare != null) {
            detail = ChangeNotifierProvider<ScheduledCareController>.value(
              value: scheduledCare,
              child: detail,
            );
          }
          if (prototypeCare != null) {
            detail =
                ChangeNotifierProvider<ScheduledCarePrototypeController>.value(
                  value: prototypeCare,
                  child: detail,
                );
          }
          return detail;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final directory = context.watch<DoctorDirectoryController>();

    return Scaffold(
      backgroundColor: OmniColors.pageBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                OmniSpacing.pageHorizontal,
                OmniSpacing.md,
                OmniSpacing.pageHorizontal,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BackButton(),
                  const SizedBox(height: OmniSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Choisissez votre médecin',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    height: 1.15,
                                    color: OmniColors.textPrimary,
                                    letterSpacing: -0.5,
                                  ),
                            ),
                            const SizedBox(height: OmniSpacing.sm),
                            Text(
                              'Trouvez le médecin qui correspond à vos besoins.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: OmniColors.textSecondary,
                                  ),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                      _FilterAction(
                        activeCount: directory.filters.activeGroupCount,
                        onTap: _openFilters,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                OmniSpacing.pageHorizontal,
                OmniSpacing.md,
                OmniSpacing.pageHorizontal,
                OmniSpacing.sm,
              ),
              child: DoctorSearchField(
                controller: _searchController,
                onChanged: directory.search,
              ),
            ),
            Expanded(
              child: _DirectoryBody(
                directory: directory,
                scrollController: _scrollController,
                onResetFilters: _resetFilters,
                onModifyFilters: _openFilters,
                onSelectDoctor: _openDoctorDetail,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Retour',
      child: GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: OmniColors.borderLight),
            boxShadow: const [OmniColors.shadowSm],
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            size: 22,
            color: OmniColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _FilterAction extends StatelessWidget {
  const _FilterAction({required this.activeCount, required this.onTap});

  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasActive = activeCount > 0;

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Semantics(
        button: true,
        label: hasActive ? 'Filtres, $activeCount actifs' : 'Filtres',
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: hasActive ? OmniColors.mintSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Icon(
                    Icons.tune_rounded,
                    size: 22,
                    color: hasActive
                        ? OmniColors.deepTeal
                        : OmniColors.textPrimary,
                  ),
                ),
                if (hasActive)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: OmniColors.freshMint,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$activeCount',
                        style: const TextStyle(
                          fontSize: 10,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          color: OmniColors.deepTealActive,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DirectoryBody extends StatelessWidget {
  const _DirectoryBody({
    required this.directory,
    required this.scrollController,
    required this.onResetFilters,
    required this.onModifyFilters,
    required this.onSelectDoctor,
  });

  final DoctorDirectoryController directory;
  final ScrollController scrollController;
  final VoidCallback onResetFilters;
  final VoidCallback onModifyFilters;
  final ValueChanged<DoctorListItem> onSelectDoctor;

  @override
  Widget build(BuildContext context) {
    final status = directory.status;
    final items = directory.items;

    if (status == DoctorDirectoryStatus.idle) {
      return const Center(child: CircularProgressIndicator());
    }

    if (status == DoctorDirectoryStatus.error) {
      return _DirectoryErrorState(
        message:
            directory.error?.message ??
            'Le répertoire des médecins est momentanément indisponible.',
        onRetry: () => directory.loadFirst(),
      );
    }

    if (status == DoctorDirectoryStatus.empty) {
      return _EmptyState(
        hasCriteria:
            directory.query.trim().isNotEmpty || directory.filters.isActive,
        onModifyFilters: onModifyFilters,
        onReset: onResetFilters,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (directory.isReloading) const LinearProgressIndicator(minHeight: 2),
        if (directory.error != null)
          _ReloadErrorBanner(
            message: directory.error!.message,
            onRetry: directory.refresh,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            OmniSpacing.pageHorizontal,
            0,
            OmniSpacing.pageHorizontal,
            OmniSpacing.sm,
          ),
          child: Text(
            items.length == 1
                ? '1 médecin trouvé'
                : directory.hasNext
                ? '${items.length} médecins chargés'
                : '${items.length} médecins trouvés',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: OmniColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: directory.refresh,
            child: ListView.separated(
              controller: scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                OmniSpacing.pageHorizontal,
                0,
                OmniSpacing.pageHorizontal,
                OmniSpacing.pageVertical,
              ),
              itemCount:
                  items.length +
                  ((directory.isLoadingNext || directory.nextPageError != null)
                      ? 1
                      : 0),
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == items.length) {
                  if (directory.isLoadingNext) {
                    return const Padding(
                      padding: EdgeInsets.all(OmniSpacing.base),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  return _NextPageError(
                    message: directory.nextPageError!.message,
                    onRetry: directory.retryNextPage,
                  );
                }
                final doctor = items[index];
                return DoctorListCard(
                  key: ValueKey('doctor-card-${doctor.id}'),
                  doctor: doctor,
                  onTap: () => onSelectDoctor(doctor),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _DirectoryErrorState extends StatelessWidget {
  const _DirectoryErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(OmniSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: OmniColors.surfaceSecondary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_outlined,
                size: 26,
                color: OmniColors.slateBlue,
              ),
            ),
            const SizedBox(height: OmniSpacing.base),
            Text(
              message,
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: OmniColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: OmniSpacing.base),
            SizedBox(
              width: 150,
              height: 44,
              child: OutlinedButton(
                onPressed: onRetry,
                child: const Text('Réessayer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasCriteria,
    required this.onModifyFilters,
    required this.onReset,
  });

  final bool hasCriteria;
  final VoidCallback onModifyFilters;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(OmniSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: OmniColors.surfaceSecondary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                size: 26,
                color: OmniColors.slateBlue,
              ),
            ),
            const SizedBox(height: OmniSpacing.base),
            Text(
              hasCriteria
                  ? 'Aucun médecin ne correspond à vos critères.'
                  : 'Aucun médecin disponible',
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: OmniColors.textPrimary,
              ),
            ),
            const SizedBox(height: OmniSpacing.sm),
            Text(
              hasCriteria
                  ? 'Modifiez votre recherche ou effacez les filtres.'
                  : 'Revenez plus tard pour trouver un médecin.',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                height: 1.4,
                color: OmniColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (hasCriteria) ...[
              const SizedBox(height: OmniSpacing.base),
              Wrap(
                spacing: OmniSpacing.sm,
                runSpacing: OmniSpacing.sm,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: onModifyFilters,
                    child: const Text('Modifier les filtres'),
                  ),
                  TextButton(
                    onPressed: onReset,
                    child: const Text('Effacer les filtres'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReloadErrorBanner extends StatelessWidget {
  const _ReloadErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: OmniColors.amberSoft,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: OmniSpacing.pageHorizontal,
          vertical: OmniSpacing.sm,
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 18, color: OmniColors.amber),
            const SizedBox(width: OmniSpacing.sm),
            Expanded(child: Text(message, maxLines: 2)),
            TextButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}

class _NextPageError extends StatelessWidget {
  const _NextPageError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: OmniSpacing.sm),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: OmniColors.textSecondary),
          ),
          TextButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}
