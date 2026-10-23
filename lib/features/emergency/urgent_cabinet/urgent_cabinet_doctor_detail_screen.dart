import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';

import '../../../core/network/app_http_client.dart';
import '../../../core/theme/omni_theme.dart';
import '../../patient_clinic/data/patient_clinic_models.dart';
import '../../patient_clinic/presentation/clinic_presentation_metadata.dart'
    as clinic;
import '../../patient_clinic/presentation/widgets/clinic_full_screen_gallery.dart';
import '../../patient_clinic/presentation/widgets/clinic_image_renderer.dart';
import 'urgent_cabinet_doctor_detail.dart';
import 'urgent_cabinet_discovery_mapper.dart';
import 'urgent_cabinet_discovery_repository.dart';
import 'urgent_cabinet_doctor_fixture.dart';
import 'urgent_cabinet_doctor_list_item.dart';
import 'urgent_cabinet_flow_controller.dart';
import 'urgent_cabinet_flow_routes.dart';

enum _DetailLoadState {
  loading,
  loaded,
  error,
  unavailable,
  missingSelection,
  missingDoctor,
  unknownCabinet,
}

/// P4 doctor profile. It intentionally owns no P3 directory or booking state.
class UrgentCabinetDoctorDetailScreen extends StatefulWidget {
  const UrgentCabinetDoctorDetailScreen({super.key, this.source});

  final UrgentCabinetDoctorSource? source;

  @override
  State<UrgentCabinetDoctorDetailScreen> createState() =>
      _UrgentCabinetDoctorDetailScreenState();
}

class _UrgentCabinetDoctorDetailScreenState
    extends State<UrgentCabinetDoctorDetailScreen> {
  UrgentCabinetDoctorSource? _source;
  UrgentCabinetDiscoveryRepository? _repository;
  CancelToken? _requestToken;
  _DetailLoadState _loadState = _DetailLoadState.loading;
  UrgentCabinetDoctorDetail? _detail;
  UrgentCabinetLocationDetail? _cabinet;
  bool _requested = false;
  bool _revalidating = false;

  @override
  void initState() {
    super.initState();
    _source = widget.source;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    if (_source == null) {
      _repository = AppUrgentCabinetDiscoveryRepository(
        context.read<AppHttpClient>(),
      );
    }
    _loadDetail();
  }

  @override
  void dispose() {
    _requestToken?.cancel('urgent-cabinet-detail-disposed');
    super.dispose();
  }

  Future<void> _loadDetail() async {
    final flow = context.read<UrgentCabinetFlowController>();
    final doctorId = flow.selectedDoctorId;
    final cabinetId = flow.selectedCabinetId;
    if (doctorId == null || cabinetId == null) {
      setState(() => _loadState = _DetailLoadState.missingSelection);
      return;
    }

    setState(() => _loadState = _DetailLoadState.loading);
    try {
      final UrgentCabinetDoctorDetail? detail;
      if (_source != null) {
        detail = await _source!.loadDoctorDetail(doctorId);
      } else {
        _requestToken?.cancel('urgent-cabinet-detail-replaced');
        final token = CancelToken();
        _requestToken = token;
        final response = await _repository!.detail(
          doctorId: doctorId,
          practiceLocationId: cabinetId,
          cancelToken: token,
        );
        detail = response.toDetail();
      }
      if (!mounted) return;
      if (detail == null || detail.doctorId != doctorId) {
        setState(() => _loadState = _DetailLoadState.missingDoctor);
        return;
      }
      if (detail.isDevelopmentFixture &&
          _source?.isDevelopmentFixture != true) {
        setState(() => _loadState = _DetailLoadState.unavailable);
        return;
      }
      final cabinet = detail.cabinetById(cabinetId);
      if (cabinet == null) {
        setState(() {
          _detail = detail;
          _loadState = _DetailLoadState.unknownCabinet;
        });
        return;
      }
      setState(() {
        _detail = detail;
        _cabinet = cabinet;
        _loadState = _DetailLoadState.loaded;
      });
    } on UrgentCabinetDoctorSourceUnavailable {
      if (!mounted) return;
      setState(() => _loadState = _DetailLoadState.unavailable);
    } on UrgentCabinetDiscoveryFailure catch (failure) {
      if (!mounted || failure.isCancelled) return;
      setState(() {
        _loadState = failure.isNotFound
            ? _DetailLoadState.missingDoctor
            : failure.kind ==
                  UrgentCabinetDiscoveryFailureKind.developmentGateUnavailable
            ? _DetailLoadState.unavailable
            : _DetailLoadState.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadState = _DetailLoadState.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OmniColors.pageBackground,
      body: SafeArea(bottom: false, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loadState == _DetailLoadState.loaded) {
      return _UrgentDoctorDetailBody(
        detail: _detail!,
        cabinet: _cabinet!,
        canContinue:
            !_revalidating &&
            _detail!.eligibility == UrgentCabinetEligibility.eligible &&
            _detail!.availability == UrgentCabinetAvailability.availableNow,
        onContinue: _continue,
      );
    }

    final state = switch (_loadState) {
      _DetailLoadState.loading => const Center(
        key: ValueKey('urgent-cabinet-detail-loading'),
        child: CircularProgressIndicator(),
      ),
      _DetailLoadState.error => _DetailMessageState(
        key: const ValueKey('urgent-cabinet-detail-error'),
        icon: Icons.cloud_off_outlined,
        title: 'Impossible de charger ce médecin.',
        message: 'Veuillez réessayer dans un instant.',
        actionLabel: 'Réessayer',
        onAction: _loadDetail,
      ),
      _DetailLoadState.unavailable => const _DetailMessageState(
        key: ValueKey('urgent-cabinet-detail-unavailable'),
        icon: Icons.info_outline_rounded,
        title: 'Service bientôt disponible',
        message:
            'Les détails de ce médecin ne sont pas disponibles dans cet environnement.',
      ),
      _DetailLoadState.missingSelection => const _DetailMessageState(
        key: ValueKey('urgent-cabinet-detail-missing-selection'),
        icon: Icons.person_search_outlined,
        title: 'Aucun médecin sélectionné',
        message: 'Revenez à la liste et sélectionnez un médecin.',
      ),
      _DetailLoadState.missingDoctor => const _DetailMessageState(
        key: ValueKey('urgent-cabinet-detail-missing-doctor'),
        icon: Icons.person_off_outlined,
        title: 'Médecin introuvable',
        message: 'Ce médecin n’est plus disponible dans cette liste.',
      ),
      _DetailLoadState.unknownCabinet => const _DetailMessageState(
        key: ValueKey('urgent-cabinet-detail-unknown-cabinet'),
        icon: Icons.location_off_outlined,
        title: 'Cabinet introuvable',
        message:
            'Le cabinet sélectionné n’est plus associé à ce médecin pour ce parcours.',
      ),
      _DetailLoadState.loaded => const SizedBox.shrink(),
    };

    return Stack(
      children: [
        Positioned.fill(child: state),
        const Positioned(
          top: OmniSpacing.sm,
          left: OmniSpacing.base,
          child: _DetailBackButton(),
        ),
      ],
    );
  }

  Future<void> _continue() async {
    if (_source?.isDevelopmentFixture == true &&
        _detail?.isDevelopmentFixture == true) {
      final flow = context.read<UrgentCabinetFlowController>();
      final captured = flow.captureQuoteSnapshot(_detail!);
      if (!captured) {
        _showQuoteUnavailable();
        return;
      }
      Navigator.of(context).pushNamed<void>(
        flow.canReviewCurrentDraft
            ? UrgentCabinetFlowRoutes.requestConfirmation
            : UrgentCabinetFlowRoutes.symptomIntake,
      );
      return;
    }

    final flow = context.read<UrgentCabinetFlowController>();
    final doctorId = flow.selectedDoctorId;
    final locationId = flow.selectedCabinetId;
    if (doctorId == null || locationId == null || _repository == null) return;
    setState(() => _revalidating = true);
    try {
      _requestToken?.cancel('urgent-cabinet-continue-revalidation');
      final token = CancelToken();
      _requestToken = token;
      final response = await _repository!.detail(
        doctorId: doctorId,
        practiceLocationId: locationId,
        cancelToken: token,
      );
      if (!mounted || token.isCancelled) return;
      final detail = response.toDetail();
      final cabinet = detail.cabinetById(locationId);
      if (cabinet == null) {
        setState(() => _loadState = _DetailLoadState.unknownCabinet);
        return;
      }
      setState(() {
        _detail = detail;
        _cabinet = cabinet;
      });
      if (!flow.captureQuoteSnapshot(detail)) {
        _showQuoteUnavailable();
        return;
      }
      if (flow.bindSymptomIntakeToSelectedTarget() !=
          UrgentCabinetIntakeTransition.saved) {
        return;
      }
      await Navigator.of(
        context,
      ).pushNamed<void>(UrgentCabinetFlowRoutes.requestConfirmation);
    } on UrgentCabinetDiscoveryFailure catch (failure) {
      if (!mounted || failure.isCancelled) return;
      if (failure.isNotFound) {
        setState(() => _loadState = _DetailLoadState.missingDoctor);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Impossible de vérifier ce médecin. Veuillez réessayer.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _revalidating = false);
    }
  }

  void _showQuoteUnavailable() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Impossible de vérifier le tarif urgent. Veuillez réessayer.',
        ),
      ),
    );
  }
}

class _UrgentDoctorDetailBody extends StatefulWidget {
  const _UrgentDoctorDetailBody({
    required this.detail,
    required this.cabinet,
    required this.canContinue,
    required this.onContinue,
  });

  final UrgentCabinetDoctorDetail detail;
  final UrgentCabinetLocationDetail cabinet;
  final bool canContinue;
  final VoidCallback onContinue;

  @override
  State<_UrgentDoctorDetailBody> createState() =>
      _UrgentDoctorDetailBodyState();
}

class _UrgentDoctorDetailBodyState extends State<_UrgentDoctorDetailBody> {
  static const _tabLabels = ['À propos', 'Cabinet'];
  int _selectedTab = 0;

  void _continue() {
    if (!widget.canContinue) return;
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final mediaQuery = MediaQuery.of(context);
    final usesCompactScrollableHeader =
        mediaQuery.size.height < 650 && mediaQuery.textScaler.scale(1) > 1.3;
    final identityHeader = _DoctorIdentityHeader(
      detail: widget.detail,
      cabinet: widget.cabinet,
    );
    return Scaffold(
      backgroundColor: OmniColors.pageBackground,
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                SizedBox(height: topInset),
                if (usesCompactScrollableHeader)
                  Flexible(
                    flex: 3,
                    child: SingleChildScrollView(child: identityHeader),
                  )
                else
                  identityHeader,
                _SegmentedTabBar(
                  labels: _tabLabels,
                  selectedIndex: _selectedTab,
                  onTabSelected: (index) =>
                      setState(() => _selectedTab = index),
                ),
                Expanded(
                  flex: usesCompactScrollableHeader ? 2 : 1,
                  child: _selectedTab == 0
                      ? _AboutTab(detail: widget.detail)
                      : _CabinetTab(
                          cabinet: widget.cabinet,
                          isDevelopmentFixture:
                              widget.detail.isDevelopmentFixture,
                        ),
                ),
                _ContinueBar(enabled: widget.canContinue, onPressed: _continue),
              ],
            ),
          ),
          Positioned(
            top: topInset + OmniSpacing.sm,
            left: OmniSpacing.base,
            child: const _DetailBackButton(),
          ),
        ],
      ),
    );
  }
}

class _DoctorIdentityHeader extends StatelessWidget {
  const _DoctorIdentityHeader({required this.detail, required this.cabinet});

  final UrgentCabinetDoctorDetail detail;
  final UrgentCabinetLocationDetail cabinet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: OmniColors.surfacePrimary,
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal,
        56,
        OmniSpacing.pageHorizontal,
        OmniSpacing.md,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final portraitSize = constraints.maxWidth < 360 ? 84.0 : 104.0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DoctorPortrait(
                    name: detail.displayName,
                    image: detail.portrait,
                    size: portraitSize,
                  ),
                  const SizedBox(width: OmniSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detail.displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontSize: 22,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            color: OmniColors.textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          detail.specialty,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: OmniColors.violet,
                          ),
                        ),
                        if (detail.subSpecialties.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            detail.subSpecialties.join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                              height: 1.35,
                              color: OmniColors.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: OmniSpacing.sm),
                        if (detail.experienceYears case final years?
                            when years > 0)
                          _HeaderMetaLine(
                            icon: Icons.work_outline_rounded,
                            label: '$years ans d’expérience',
                          ),
                        _HeaderMetaLine(
                          icon: Icons.location_on_outlined,
                          label: _locationLabel(cabinet),
                        ),
                        if (detail.languages.isNotEmpty)
                          _HeaderMetaLine(
                            icon: Icons.language_outlined,
                            label: detail.languages.join(' · '),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (detail.isDevelopmentFixture) ...[
                const SizedBox(height: OmniSpacing.md),
                const _DemoIndicator(),
              ],
            ],
          );
        },
      ),
    );
  }

  String _locationLabel(UrgentCabinetLocationDetail location) {
    final distance = location.distanceKm;
    if (distance == null) return location.locality;
    return '${location.locality} · ${distance.toStringAsFixed(1)} km à vol d’oiseau';
  }
}

class _DoctorPortrait extends StatelessWidget {
  const _DoctorPortrait({
    required this.name,
    required this.image,
    required this.size,
  });

  final String name;
  final UrgentCabinetDoctorImage? image;
  final double size;

  @override
  Widget build(BuildContext context) {
    final source = image;
    return Container(
      key: const ValueKey('urgent-cabinet-doctor-portrait'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: OmniColors.slateSoft,
        border: Border.all(color: OmniColors.borderLight, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: source == null || source.value.trim().isEmpty
          ? _InitialsFallback(name: name)
          : source.isAsset
          ? Image.asset(
              source.value,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _InitialsFallback(name: name),
            )
          : Image.network(
              source.value,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _InitialsFallback(name: name),
            ),
    );
  }
}

class _HeaderMetaLine extends StatelessWidget {
  const _HeaderMetaLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: OmniColors.textTertiary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12,
                height: 1.3,
                color: OmniColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoIndicator extends StatelessWidget {
  const _DemoIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('urgent-cabinet-detail-demo-indicator'),
      padding: const EdgeInsets.symmetric(
        horizontal: OmniSpacing.sm,
        vertical: OmniSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: OmniColors.amberSoft,
        borderRadius: BorderRadius.circular(OmniRadii.field),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.science_outlined, size: 15, color: OmniColors.amber),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Profil de démonstration',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: OmniColors.amber,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedTabBar extends StatelessWidget {
  const _SegmentedTabBar({
    required this.labels,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('urgent-cabinet-detail-tabs'),
      color: OmniColors.surfacePrimary,
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal,
        0,
        OmniSpacing.pageHorizontal,
        OmniSpacing.sm,
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: OmniColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(OmniRadii.field),
        ),
        child: Row(
          children: [
            for (var index = 0; index < labels.length; index++)
              Expanded(
                child: GestureDetector(
                  key: ValueKey('urgent-cabinet-detail-tab-$index'),
                  onTap: () => onTabSelected(index),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    constraints: const BoxConstraints(minHeight: 38),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selectedIndex == index
                          ? OmniColors.surfacePrimary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      border: selectedIndex == index
                          ? Border.all(color: OmniColors.borderLight)
                          : null,
                    ),
                    child: Text(
                      labels[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        fontWeight: selectedIndex == index
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selectedIndex == index
                            ? OmniColors.textPrimary
                            : OmniColors.textSecondary,
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

class _AboutTab extends StatefulWidget {
  const _AboutTab({required this.detail});

  final UrgentCabinetDoctorDetail detail;

  @override
  State<_AboutTab> createState() => _AboutTabState();
}

class _AboutTabState extends State<_AboutTab> {
  bool _showFullBiography = false;

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final hasContent =
        detail.areasOfCare.isNotEmpty ||
        detail.expertise.isNotEmpty ||
        detail.visitReasons.isNotEmpty ||
        (detail.biography?.trim().isNotEmpty ?? false);
    return ListView(
      key: const PageStorageKey('urgent-cabinet-detail-about-scroll'),
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal,
        OmniSpacing.md,
        OmniSpacing.pageHorizontal,
        OmniSpacing.pageVertical,
      ),
      children: [
        if (!hasContent)
          const _SoftPanel(
            child: Text('Aucune information de profil supplémentaire.'),
          ),
        if (detail.areasOfCare.isNotEmpty) ...[
          const _SectionTitle(title: 'Domaines de prise en charge'),
          const SizedBox(height: OmniSpacing.sm),
          _TagWrap(
            labels: detail.areasOfCare,
            background: OmniColors.mintSoft,
            foreground: OmniColors.deepTeal,
            icon: Icons.check_circle_outline,
          ),
        ],
        if (detail.expertise.isNotEmpty) ...[
          const SizedBox(height: OmniSpacing.lg),
          const _SectionTitle(title: 'Expertises'),
          const SizedBox(height: OmniSpacing.sm),
          _TagWrap(
            labels: detail.expertise,
            background: OmniColors.violetSoft,
            foreground: OmniColors.violet,
            icon: Icons.auto_awesome_outlined,
          ),
        ],
        if (detail.visitReasons.isNotEmpty) ...[
          const SizedBox(height: OmniSpacing.lg),
          const _SectionTitle(title: 'Motifs de consultation'),
          const SizedBox(height: OmniSpacing.sm),
          _BulletList(labels: detail.visitReasons),
        ],
        if (detail.biography?.trim().isNotEmpty ?? false) ...[
          const SizedBox(height: OmniSpacing.lg),
          const _SectionTitle(title: 'À propos du médecin'),
          const SizedBox(height: OmniSpacing.sm),
          Text(
            detail.biography!,
            maxLines: _showFullBiography ? null : 4,
            overflow: _showFullBiography ? null : TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              height: 1.6,
              color: OmniColors.textSecondary,
            ),
          ),
          if (detail.biography!.length > 240)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () =>
                    setState(() => _showFullBiography = !_showFullBiography),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.only(top: OmniSpacing.xs),
                  minimumSize: const Size(44, 44),
                ),
                child: Text(_showFullBiography ? 'Voir moins' : 'Voir plus'),
              ),
            ),
        ],
      ],
    );
  }
}

class _CabinetTab extends StatelessWidget {
  const _CabinetTab({
    required this.cabinet,
    required this.isDevelopmentFixture,
  });

  final UrgentCabinetLocationDetail cabinet;
  final bool isDevelopmentFixture;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const PageStorageKey('urgent-cabinet-detail-cabinet-scroll'),
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal,
        OmniSpacing.md,
        OmniSpacing.pageHorizontal,
        OmniSpacing.pageVertical,
      ),
      children: [
        if (cabinet.gallery.isNotEmpty) ...[
          _CabinetGallery(images: cabinet.gallery),
          const SizedBox(height: OmniSpacing.sm),
          Text(
            isDevelopmentFixture
                ? 'Images de démonstration du cabinet'
                : 'Photos du cabinet',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 11,
              color: OmniColors.textTertiary,
            ),
          ),
          const SizedBox(height: OmniSpacing.lg),
        ] else ...[
          const _SoftPanel(
            child: Row(
              children: [
                Icon(Icons.photo_outlined, color: OmniColors.slateBlue),
                SizedBox(width: OmniSpacing.sm),
                Expanded(child: Text('Aucune photo du cabinet disponible.')),
              ],
            ),
          ),
          const SizedBox(height: OmniSpacing.lg),
        ],
        const _SectionTitle(title: 'Localisation'),
        const SizedBox(height: OmniSpacing.sm),
        _LocationCard(cabinet: cabinet),
        if (cabinet.equipment.isNotEmpty) ...[
          const SizedBox(height: OmniSpacing.lg),
          const _SectionTitle(title: 'Équipements et examens disponibles'),
          const SizedBox(height: OmniSpacing.sm),
          _TagWrap(
            labels: cabinet.equipment,
            background: OmniColors.clinicalCyanSoft,
            foreground: OmniColors.clinicalCyan,
            icon: Icons.medical_services_outlined,
          ),
        ],
        if (cabinet.openingHours.isNotEmpty) ...[
          const SizedBox(height: OmniSpacing.lg),
          const _SectionTitle(title: 'Horaires'),
          const SizedBox(height: OmniSpacing.sm),
          _HoursTable(hours: cabinet.openingHours),
        ],
        if (cabinet.accessibility.isNotEmpty) ...[
          const SizedBox(height: OmniSpacing.lg),
          const _SectionTitle(title: 'Informations pratiques'),
          const SizedBox(height: OmniSpacing.sm),
          _CompactRows(
            labels: cabinet.accessibility,
            icon: Icons.check_circle_outline,
          ),
        ],
      ],
    );
  }
}

class _CabinetGallery extends StatefulWidget {
  const _CabinetGallery({required this.images});

  final List<UrgentCabinetDoctorImage> images;

  @override
  State<_CabinetGallery> createState() => _CabinetGalleryState();
}

class _CabinetGalleryState extends State<_CabinetGallery> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('urgent-cabinet-detail-gallery'),
      children: [
        SizedBox(
          height: 220,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(OmniRadii.cardLarge),
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.images.length,
                  onPageChanged: (index) =>
                      setState(() => _currentIndex = index),
                  itemBuilder: (context, index) => GestureDetector(
                    key: ValueKey('urgent-cabinet-gallery-image-$index'),
                    onTap: () => _openFullScreen(context, index),
                    child: _CabinetImage(
                      image: widget.images[index],
                      width: double.infinity,
                      height: 220,
                      borderRadius: BorderRadius.circular(OmniRadii.cardLarge),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: OmniSpacing.sm,
                top: OmniSpacing.sm,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: OmniSpacing.sm,
                    vertical: OmniSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(OmniRadii.pill),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.images.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: OmniSpacing.sm),
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: widget.images.length,
            separatorBuilder: (_, _) => const SizedBox(width: OmniSpacing.sm),
            itemBuilder: (context, index) {
              final isSelected = index == _currentIndex;
              return GestureDetector(
                onTap: () => _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                ),
                child: Container(
                  width: 78,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(OmniRadii.field),
                    border: Border.all(
                      color: isSelected
                          ? OmniColors.freshMint
                          : OmniColors.borderLight,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _CabinetImage(
                    image: widget.images[index],
                    width: 78,
                    height: 64,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openFullScreen(BuildContext context, int initialIndex) {
    final networkImages = widget.images
        .where((image) => image.isNetwork && image.value.trim().isNotEmpty)
        .map((image) => PatientClinicImage(imageUrl: image.value))
        .toList(growable: false);
    final localAssets = widget.images
        .where((image) => image.isAsset && image.value.trim().isNotEmpty)
        .map((image) => clinic.ClinicPresentationImage.asset(image.value))
        .toList(growable: false);
    if (networkImages.isEmpty && localAssets.isEmpty) return;

    final tapped = widget.images[initialIndex];
    final precedingSameSource = widget.images
        .take(initialIndex)
        .where(
          (image) =>
              image.source == tapped.source && image.value.trim().isNotEmpty,
        )
        .length;
    final fullScreenIndex = tapped.isNetwork
        ? precedingSameSource
        : networkImages.length + precedingSameSource;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ClinicFullScreenGallery(
          images: networkImages,
          localAssets: localAssets,
          initialIndex: fullScreenIndex,
        ),
      ),
    );
  }
}

class _CabinetImage extends StatelessWidget {
  const _CabinetImage({
    required this.image,
    this.width,
    this.height,
    this.borderRadius,
  });

  final UrgentCabinetDoctorImage image;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final presentationImage = image.isAsset
        ? clinic.ClinicPresentationImage.asset(image.value)
        : clinic.ClinicPresentationImage.network(image.value);
    return ClinicImageRenderer(
      image: presentationImage,
      width: width,
      height: height,
      fit: BoxFit.cover,
      borderRadius: borderRadius,
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.cabinet});

  final UrgentCabinetLocationDetail cabinet;

  @override
  Widget build(BuildContext context) {
    final address = cabinet.address?.trim();
    return Container(
      key: const ValueKey('urgent-cabinet-detail-location'),
      width: double.infinity,
      padding: const EdgeInsets.all(OmniSpacing.base),
      decoration: BoxDecoration(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(color: OmniColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: OmniColors.infoBlueSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on_outlined,
              size: 19,
              color: OmniColors.infoBlue,
            ),
          ),
          const SizedBox(width: OmniSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cabinet.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: OmniColors.textPrimary,
                  ),
                ),
                if (address != null && address.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    address,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 13,
                      height: 1.4,
                      color: OmniColors.textPrimary,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  cabinet.distanceKm == null
                      ? cabinet.locality
                      : '${cabinet.locality} · ${cabinet.distanceKm!.toStringAsFixed(1)} km à vol d’oiseau',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    color: OmniColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HoursTable extends StatelessWidget {
  const _HoursTable({required this.hours});

  final List<UrgentCabinetOpeningHours> hours;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: OmniSpacing.xs),
      decoration: BoxDecoration(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(color: OmniColors.borderLight),
      ),
      child: Column(
        children: [
          for (final entry in hours)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: OmniSpacing.base,
                vertical: OmniSpacing.sm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      entry.day,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 13,
                        color: OmniColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: OmniSpacing.sm),
                  Flexible(
                    child: Text(
                      entry.hours,
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: OmniColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: OmniColors.textPrimary,
      ),
    );
  }
}

class _TagWrap extends StatelessWidget {
  const _TagWrap({
    required this.labels,
    required this.background,
    required this.foreground,
    required this.icon,
  });

  final List<String> labels;
  final Color background;
  final Color foreground;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: OmniSpacing.sm,
      runSpacing: OmniSpacing.sm,
      children: [
        for (final label in labels)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: OmniSpacing.sm,
              vertical: OmniSpacing.xs + 2,
            ),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(OmniRadii.field),
              border: Border.all(color: foreground.withValues(alpha: 0.12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: foreground),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final label in labels)
          Padding(
            padding: const EdgeInsets.only(bottom: OmniSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 7),
                  child: Icon(
                    Icons.circle,
                    size: 6,
                    color: OmniColors.textTertiary,
                  ),
                ),
                const SizedBox(width: OmniSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      height: 1.35,
                      color: OmniColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CompactRows extends StatelessWidget {
  const _CompactRows({required this.labels, required this.icon});

  final List<String> labels;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final label in labels)
          Padding(
            padding: const EdgeInsets.only(bottom: OmniSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 17, color: OmniColors.textTertiary),
                const SizedBox(width: OmniSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      height: 1.35,
                      color: OmniColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SoftPanel extends StatelessWidget {
  const _SoftPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(OmniSpacing.base),
      decoration: BoxDecoration(
        color: OmniColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(OmniRadii.card),
      ),
      child: child,
    );
  }
}

class _ContinueBar extends StatelessWidget {
  const _ContinueBar({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          OmniSpacing.pageHorizontal,
          OmniSpacing.sm,
          OmniSpacing.pageHorizontal,
          OmniSpacing.md,
        ),
        decoration: const BoxDecoration(
          color: OmniColors.surfacePrimary,
          border: Border(top: BorderSide(color: OmniColors.borderLight)),
        ),
        child: ElevatedButton(
          key: const ValueKey('urgent-cabinet-detail-continue'),
          style: buildOmniPrimaryButtonStyle(),
          onPressed: enabled ? onPressed : null,
          child: const Text('Continuer avec ce médecin'),
        ),
      ),
    );
  }
}

class _DetailMessageState extends StatelessWidget {
  const _DetailMessageState({
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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: OmniColors.textPrimary,
              ),
            ),
            const SizedBox(height: OmniSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: OmniColors.textSecondary),
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

class _DetailBackButton extends StatelessWidget {
  const _DetailBackButton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Retour',
      button: true,
      child: GestureDetector(
        key: const ValueKey('urgent-cabinet-detail-back'),
        onTap: () => Navigator.of(context).maybePop(),
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

class _InitialsFallback extends StatelessWidget {
  const _InitialsFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final parts = name
        .replaceFirst(RegExp(r'^Dr\.?\s+', caseSensitive: false), '')
        .trim()
        .split(RegExp(r'\s+'));
    final initials = parts
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return Container(
      key: const ValueKey('urgent-cabinet-doctor-initials'),
      alignment: Alignment.center,
      color: OmniColors.slateSoft,
      child: Text(
        initials.isEmpty ? 'DR' : initials,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: OmniColors.slateBlue,
        ),
      ),
    );
  }
}
