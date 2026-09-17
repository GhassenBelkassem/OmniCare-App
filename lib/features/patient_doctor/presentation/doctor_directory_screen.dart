import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/omni_theme.dart';
import '../application/doctor_directory_controller.dart';
import 'doctor_detail_screen.dart';
import 'doctor_filter_model.dart';
import 'widgets/doctor_card.dart';
import 'widgets/doctor_filter_sheet.dart';
import 'widgets/doctor_search_field.dart';

/// Patient doctor directory: static mock doctors, search, and local presentation
/// filters.
///
/// Tapping a doctor card navigates to the Doctor Detail screen. Search, filter,
/// and scroll state are preserved when returning from detail.
class DoctorDirectoryScreen extends StatefulWidget {
  const DoctorDirectoryScreen({super.key});

  @override
  State<DoctorDirectoryScreen> createState() => _DoctorDirectoryScreenState();
}

class _DoctorDirectoryScreenState extends State<DoctorDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  DoctorFilterSnapshot _filters = DoctorFilterSnapshot.none;

  @override
  void initState() {
    super.initState();
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
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openFilters() async {
    final directory = context.read<DoctorDirectoryController>();
    final result = await showDoctorFilterSheet(
      context: context,
      options: buildDoctorFilterOptions(directory.items),
      items: directory.items,
      initial: _filters,
    );
    if (result != null && result != _filters) {
      setState(() {
        _filters = result;
      });
    }
  }

  void _resetFilters() {
    setState(() {
      _filters = DoctorFilterSnapshot.none;
    });
  }

  void _openDoctorDetail(String doctorId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DoctorDetailScreen(doctorId: doctorId),
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
                        activeCount: _filters.activeGroupCount,
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
                filters: _filters,
                scrollController: _scrollController,
                onResetFilters: _resetFilters,
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
    required this.filters,
    required this.scrollController,
    required this.onResetFilters,
    required this.onSelectDoctor,
  });

  final DoctorDirectoryController directory;
  final DoctorFilterSnapshot filters;
  final ScrollController scrollController;
  final VoidCallback onResetFilters;
  final ValueChanged<String> onSelectDoctor;

  @override
  Widget build(BuildContext context) {
    final status = directory.status;
    final rawItems = directory.items;

    if (status == DoctorDirectoryStatus.idle) {
      return const Center(child: CircularProgressIndicator());
    }

    if (status == DoctorDirectoryStatus.empty) {
      if (filters.isActive) {
        return _FilteredEmptyState(onReset: onResetFilters);
      }
      return _EmptyState(hasQuery: directory.query.trim().isNotEmpty);
    }

    final visible = applyDoctorFilters(items: rawItems, filters: filters);

    if (visible.isEmpty) {
      return _FilteredEmptyState(onReset: onResetFilters);
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
                ? '1 médecin trouvé'
                : '${visible.length} médecins trouvés',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: OmniColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(
              OmniSpacing.pageHorizontal,
              0,
              OmniSpacing.pageHorizontal,
              OmniSpacing.pageVertical,
            ),
            itemCount: visible.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doctor = visible[index];
              return DoctorListCard(
                doctor: doctor,
                onTap: () => onSelectDoctor(doctor.id),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasQuery});

  final bool hasQuery;

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
              hasQuery ? 'Aucun médecin trouvé' : 'Aucun médecin disponible',
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: OmniColors.textPrimary,
              ),
            ),
            const SizedBox(height: OmniSpacing.sm),
            Text(
              hasQuery
                  ? 'Essayez une autre recherche.'
                  : 'Revenez plus tard pour trouver un médecin.',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                height: 1.4,
                color: OmniColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilteredEmptyState extends StatelessWidget {
  const _FilteredEmptyState({required this.onReset});

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
                Icons.filter_alt_outlined,
                size: 26,
                color: OmniColors.slateBlue,
              ),
            ),
            const SizedBox(height: OmniSpacing.base),
            Text(
              'Aucun médecin ne correspond à ces filtres.',
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
                onPressed: onReset,
                child: const Text('Réinitialiser'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
