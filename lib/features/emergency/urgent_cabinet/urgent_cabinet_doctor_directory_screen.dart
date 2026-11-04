import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/app_http_client.dart';
import '../../../core/theme/omni_theme.dart';
import '../../../providers/user_provider.dart';
import '../../patient_doctor/presentation/widgets/doctor_result_card.dart';
import '../../patient_doctor/presentation/widgets/doctor_search_field.dart';
import 'urgent_cabinet_discovery_controller.dart';
import 'urgent_cabinet_discovery_mapper.dart';
import 'urgent_cabinet_discovery_models.dart';
import 'urgent_cabinet_discovery_repository.dart';
import 'urgent_cabinet_doctor_filter.dart';
import 'urgent_cabinet_doctor_filter_sheet.dart';
import 'urgent_cabinet_doctor_fixture.dart';
import 'urgent_cabinet_doctor_list_item.dart';
import 'urgent_cabinet_flow_controller.dart';
import 'urgent_cabinet_flow_routes.dart';
import 'urgent_cabinet_search_location_provider.dart';

class UrgentCabinetDoctorDirectoryScreen extends StatefulWidget {
  const UrgentCabinetDoctorDirectoryScreen({
    super.key,
    this.source,
    this.searchLocationProvider,
    this.onExitJourney,
  });

  final UrgentCabinetDoctorSource? source;
  final UrgentCabinetSearchLocationProvider? searchLocationProvider;
  final VoidCallback? onExitJourney;

  @override
  State<UrgentCabinetDoctorDirectoryScreen> createState() =>
      _UrgentCabinetDoctorDirectoryScreenState();
}

enum _UrgentDirectoryLoadState { loading, loaded, error, unavailable }

class _UrgentCabinetDoctorDirectoryScreenState
    extends State<UrgentCabinetDoctorDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  UrgentCabinetDoctorSource? _source;
  UrgentCabinetDiscoveryController? _controller;
  String? _sessionOwnerId;
  bool _initialized = false;
  int _sessionStartGeneration = 0;
  late final UrgentCabinetSearchLocationProvider _searchLocationProvider;
  _UrgentDirectoryLoadState _loadState = _UrgentDirectoryLoadState.loading;
  List<UrgentCabinetDoctorListItem> _doctors = const [];
  String _query = '';
  UrgentCabinetDoctorFilterSnapshot _filters =
      UrgentCabinetDoctorFilterSnapshot.none;

  @override
  void initState() {
    super.initState();
    _source = widget.source;
    _searchLocationProvider =
        widget.searchLocationProvider ??
        const GeolocatorUrgentCabinetSearchLocationProvider();
    _scrollController.addListener(_loadMoreWhenNeeded);
    if (_source != null) _loadDoctors();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_source != null) return;
    final ownerId = context.watch<UserProvider>().profile?.userId;
    if (!_initialized) {
      _initialized = true;
      _controller = UrgentCabinetDiscoveryController(
        repository: AppUrgentCabinetDiscoveryRepository(
          context.read<AppHttpClient>(),
        ),
      )..addListener(_handleAuthoritativeState);
      _sessionOwnerId = ownerId;
      unawaited(_startAuthoritativeSession(ownerId));
      return;
    }
    if (_sessionOwnerId != ownerId) {
      _sessionOwnerId = ownerId;
      _searchController.clear();
      _query = '';
      _filters = UrgentCabinetDoctorFilterSnapshot.none;
      _controller!.clearForSession();
      unawaited(_startAuthoritativeSession(ownerId));
    }
  }

  Future<void> _startAuthoritativeSession(String? ownerId) async {
    final generation = ++_sessionStartGeneration;
    final positionFuture = ownerId == null
        ? Future<UrgentCabinetSearchPosition?>.value()
        : _searchLocationProvider.currentPositionIfAuthorized();
    if (!mounted || generation != _sessionStartGeneration) return;
    await _controller!.startSession(ownerId);
    final position = await positionFuture;
    if (!mounted || generation != _sessionStartGeneration || position == null) {
      return;
    }
    await _controller!.setSearchPosition(position);
  }

  @override
  void dispose() {
    _sessionStartGeneration++;
    _scrollController.removeListener(_loadMoreWhenNeeded);
    _scrollController.dispose();
    _controller?.removeListener(_handleAuthoritativeState);
    _controller?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleAuthoritativeState() {
    if (!mounted) return;
    final controller = _controller!;
    setState(() {
      _doctors = List.unmodifiable(
        controller.items.map((pair) => pair.toListItem()),
      );
      _filters = controller.filters;
      _loadState = switch (controller.state) {
        UrgentCabinetDiscoveryLoadState.idle ||
        UrgentCabinetDiscoveryLoadState.loading =>
          _UrgentDirectoryLoadState.loading,
        UrgentCabinetDiscoveryLoadState.loaded ||
        UrgentCabinetDiscoveryLoadState.loadingMore =>
          _UrgentDirectoryLoadState.loaded,
        UrgentCabinetDiscoveryLoadState.error =>
          _UrgentDirectoryLoadState.error,
      };
    });
  }

  void _loadMoreWhenNeeded() {
    if (_source != null || !_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 320) {
      _controller?.loadMore();
    }
  }

  Future<void> _loadDoctors() async {
    setState(() {
      _loadState = _UrgentDirectoryLoadState.loading;
    });
    try {
      final doctors = await _source!.loadDoctors();
      if (!mounted) return;
      setState(() {
        _doctors = List.unmodifiable(doctors);
        _loadState = _UrgentDirectoryLoadState.loaded;
      });
    } on UrgentCabinetDoctorSourceUnavailable {
      if (!mounted) return;
      setState(() {
        _doctors = const [];
        _loadState = _UrgentDirectoryLoadState.unavailable;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _doctors = const [];
        _loadState = _UrgentDirectoryLoadState.error;
      });
    }
  }

  void _search(String value) {
    setState(() {
      _query = value.trim();
    });
    _controller?.updateQuery(value);
  }

  Future<void> _openFilters() async {
    final authoritativeOptions = _controller?.facets?.toFilterOptions();
    final result = await showUrgentCabinetDoctorFilterSheet(
      context: context,
      doctors: _doctors,
      query: _query,
      initial: _filters,
      options: authoritativeOptions,
      distanceAvailable: _controller?.canUseDistance ?? true,
      onDistanceAuthorizationRequested: _controller == null
          ? null
          : _authorizeDistanceSearch,
      showLocalResultCount: _controller == null,
    );
    if (!mounted || result == null || result == _filters) return;
    setState(() {
      _filters = result;
    });
    await _controller?.applyFilters(result);
  }

  Future<bool> _authorizeDistanceSearch() async {
    final ownerId = _sessionOwnerId;
    if (ownerId == null) return false;
    final position = await _searchLocationProvider.requestCurrentPosition();
    if (!mounted || _sessionOwnerId != ownerId || position == null) {
      return false;
    }
    await _controller!.setSearchPosition(position);
    return mounted && _sessionOwnerId == ownerId && _controller!.canUseDistance;
  }

  void _resetFilters() {
    if (!_filters.isActive) return;
    setState(() {
      _filters = UrgentCabinetDoctorFilterSnapshot.none;
    });
    _controller?.applyFilters(UrgentCabinetDoctorFilterSnapshot.none);
  }

  List<UrgentCabinetDoctorListItem> _eligibleDoctors(
    Set<String> excludedDoctorIds,
  ) => _doctors
      .where(
        (doctor) =>
            doctor.canReceiveUrgentRequest &&
            !excludedDoctorIds.contains(doctor.doctorId),
      )
      .toList(growable: false);

  List<UrgentCabinetDoctorListItem> _visibleDoctors(
    Set<String> excludedDoctorIds,
  ) {
    if (_controller != null) {
      return _doctors
          .where((doctor) => !excludedDoctorIds.contains(doctor.doctorId))
          .toList(growable: false);
    }
    return filterAndSortUrgentCabinetDoctors(
      doctors: _doctors.where(
        (doctor) => !excludedDoctorIds.contains(doctor.doctorId),
      ),
      query: _query,
      filters: _filters,
    );
  }

  void _selectDoctor(UrgentCabinetDoctorListItem doctor) {
    context.read<UrgentCabinetFlowController>().selectDoctor(
      doctorId: doctor.doctorId,
      cabinetId: doctor.activeCabinetId,
    );
    Navigator.of(context).pushNamed(UrgentCabinetFlowRoutes.doctorDetail);
  }

  void _retry() {
    if (_controller != null) {
      _controller!.refresh();
    } else {
      _loadDoctors();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final excludedDoctorIds = context
        .watch<UrgentCabinetFlowController>()
        .excludedDoctorIds;

    return Material(
      color: OmniColors.pageBackground,
      child: SafeArea(
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
                  _DirectoryBackButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(height: OmniSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _controller?.canUseDistance == true
                                  ? 'Médecins disponibles à proximité'
                                  : 'Médecins disponibles au cabinet',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.headlineMedium?.copyWith(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                height: 1.15,
                                color: OmniColors.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: OmniSpacing.sm),
                            Text(
                              'Choisissez un médecin pour votre demande urgente au cabinet.',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodyMedium?.copyWith(
                                fontSize: 14,
                                height: 1.5,
                                color: OmniColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: OmniSpacing.sm),
                      _FilterAction(
                        activeCount: _filters.activeGroupCount,
                        onTap: _openFilters,
                      ),
                    ],
                  ),
                  if (_source?.isDevelopmentFixture == true &&
                      _loadState == _UrgentDirectoryLoadState.loaded) ...[
                    const SizedBox(height: OmniSpacing.sm),
                    const _DemoDataIndicator(),
                  ],
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
                onChanged: _search,
              ),
            ),
            Expanded(child: _buildBody(excludedDoctorIds)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(Set<String> excludedDoctorIds) {
    return switch (_loadState) {
      _UrgentDirectoryLoadState.loading => const Center(
        key: ValueKey('urgent-cabinet-directory-loading'),
        child: CircularProgressIndicator(),
      ),
      _UrgentDirectoryLoadState.error => _DirectoryMessageState(
        key: const ValueKey('urgent-cabinet-directory-error'),
        icon: Icons.cloud_off_outlined,
        title: _directoryErrorTitle(),
        message: _directoryErrorMessage(),
        actionLabel: 'Réessayer',
        onAction: _retry,
      ),
      _UrgentDirectoryLoadState.unavailable => const _DirectoryMessageState(
        key: ValueKey('urgent-cabinet-directory-unavailable'),
        icon: Icons.info_outline_rounded,
        title: 'Service bientôt disponible',
        message:
            'La recherche de médecins urgents au cabinet n’est pas '
            'disponible pour cette session.',
      ),
      _UrgentDirectoryLoadState.loaded => _buildLoadedBody(excludedDoctorIds),
    };
  }

  Widget _buildLoadedBody(Set<String> excludedDoctorIds) {
    final eligible = _eligibleDoctors(excludedDoctorIds);
    if (eligible.isEmpty) {
      if (excludedDoctorIds.isNotEmpty) {
        return _DirectoryMessageState(
          key: const ValueKey('urgent-cabinet-directory-no-alternatives'),
          icon: Icons.person_search_outlined,
          title: 'Aucun autre médecin disponible',
          message:
              'Aucun autre médecin éligible à l’urgence au cabinet n’est disponible.',
          actionLabel: widget.onExitJourney == null
              ? null
              : 'Quitter la demande urgente',
          onAction: widget.onExitJourney,
        );
      }
      return const _DirectoryMessageState(
        key: ValueKey('urgent-cabinet-directory-no-eligible'),
        icon: Icons.person_search_outlined,
        title: 'Aucun médecin disponible',
        message:
            'Aucun médecin éligible à l’urgence au cabinet n’est disponible '
            'pour le moment.',
      );
    }

    final visible = _visibleDoctors(excludedDoctorIds);
    if (visible.isEmpty) {
      if (_filters.isActive) {
        return _DirectoryMessageState(
          key: const ValueKey('urgent-cabinet-directory-empty-filters'),
          icon: Icons.filter_alt_outlined,
          title: 'Aucun médecin ne correspond à ces filtres.',
          message: _query.isEmpty
              ? 'Modifiez vos critères ou réinitialisez les filtres.'
              : 'La recherche est conservée. Essayez de réinitialiser les filtres.',
          actionLabel: 'Réinitialiser',
          onAction: _resetFilters,
        );
      }
      return const _DirectoryMessageState(
        key: ValueKey('urgent-cabinet-directory-empty-search'),
        icon: Icons.search_off_rounded,
        title: 'Aucun résultat',
        message: 'Essayez un autre nom, une spécialité ou un quartier.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            OmniSpacing.pageHorizontal,
            0,
            OmniSpacing.pageHorizontal,
            OmniSpacing.sm,
          ),
          child: Text(
            visible.length == 1
                ? '1 médecin affiché'
                : '${visible.length} médecins affichés',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: OmniColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            key: const ValueKey('urgent-cabinet-doctor-list'),
            controller: _scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              OmniSpacing.pageHorizontal,
              0,
              OmniSpacing.pageHorizontal,
              OmniSpacing.pageVertical,
            ),
            itemCount:
                visible.length +
                (_controller?.state ==
                        UrgentCabinetDiscoveryLoadState.loadingMore
                    ? 1
                    : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == visible.length) {
                return const Padding(
                  padding: EdgeInsets.all(OmniSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final doctor = visible[index];
              return DoctorResultCard(
                key: ValueKey(
                  'urgent-cabinet-doctor-${doctor.doctorId}-${doctor.activeCabinetId}',
                ),
                data: DoctorResultCardData(
                  name: doctor.displayName,
                  specialty: doctor.specialty,
                  address:
                      doctor.distanceIsStraightLine && doctor.distanceKm != null
                      ? '${doctor.locationLabel} · ${doctor.distanceKm!.toStringAsFixed(1)} km à vol d’oiseau'
                      : doctor.locationLabel,
                  distanceKm: doctor.distanceIsStraightLine
                      ? null
                      : doctor.distanceKm,
                  imageAssetPath: doctor.imageAssetPath,
                  status: DoctorResultCardStatus(
                    label: _source?.isDevelopmentFixture == true
                        ? 'Disponible · démo'
                        : 'Éligible à cet instant',
                  ),
                ),
                onTap: () => _selectDoctor(doctor),
              );
            },
          ),
        ),
      ],
    );
  }

  String _directoryErrorTitle() {
    final kind = _controller?.failure?.kind;
    return switch (kind) {
      UrgentCabinetDiscoveryFailureKind.sessionRejected =>
        'Votre session a expiré.',
      UrgentCabinetDiscoveryFailureKind.forbidden => 'Accès patient requis',
      UrgentCabinetDiscoveryFailureKind.developmentGateUnavailable =>
        'Service de développement indisponible',
      _ => 'Impossible de charger les médecins.',
    };
  }

  String _directoryErrorMessage() {
    final kind = _controller?.failure?.kind;
    return switch (kind) {
      UrgentCabinetDiscoveryFailureKind.sessionRejected =>
        'Reconnectez-vous pour consulter les médecins.',
      UrgentCabinetDiscoveryFailureKind.forbidden =>
        'Cette recherche est réservée à une session Patient autorisée.',
      UrgentCabinetDiscoveryFailureKind.developmentGateUnavailable =>
        'La découverte urgente au cabinet n’est pas activée dans cet environnement.',
      UrgentCabinetDiscoveryFailureKind.invalidResponse =>
        'La réponse du service n’a pas pu être vérifiée.',
      _ => 'Vérifiez votre connexion puis réessayez.',
    };
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
          key: const ValueKey('urgent-cabinet-filter-action'),
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
                      key: const ValueKey('urgent-cabinet-filter-count'),
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

class _DirectoryBackButton extends StatelessWidget {
  const _DirectoryBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Retour',
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: OmniColors.surfacePrimary,
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

class _DemoDataIndicator extends StatelessWidget {
  const _DemoDataIndicator();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Données de démonstration, pas une disponibilité en temps réel',
      child: Container(
        key: const ValueKey('urgent-cabinet-demo-indicator'),
        padding: const EdgeInsets.symmetric(
          horizontal: OmniSpacing.sm,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: OmniColors.amberSoft,
          borderRadius: BorderRadius.circular(OmniRadii.pill),
        ),
        child: Text(
          'Données de démonstration',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: OmniColors.amber,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DirectoryMessageState extends StatelessWidget {
  const _DirectoryMessageState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
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
              child: Icon(icon, size: 26, color: OmniColors.slateBlue),
            ),
            const SizedBox(height: OmniSpacing.base),
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: OmniColors.textPrimary,
              ),
            ),
            const SizedBox(height: OmniSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                height: 1.45,
                color: OmniColors.textSecondary,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: OmniSpacing.base),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
