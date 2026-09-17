import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/omni_theme.dart';
import '../../../features/request_core/application/request_submission_controller.dart';
import '../application/patient_clinic_directory_controller.dart';
import 'clinic_detail_screen.dart';
import 'clinic_filter_model.dart';
import 'widgets/clinic_card.dart';
import 'widgets/clinic_filter_sheet.dart';
import 'widgets/clinic_search_field.dart';

/// Patient clinic directory: real backend Clinics, search, local presentation
/// filters and bounded pagination.
///
/// Selects nothing on its own — it records the chosen clinic on
/// [RequestSubmissionController] only via the detail screen's CTA, and shows
/// the current selection so the patient can continue to the next step. The
/// directory controller handles debounced, cancel-safe search and `Slice`
/// pagination, so this screen never loads every clinic.
///
/// Presentation filters (specialty, city, clinic type, services, accepting,
/// sort) are local and applied only to the currently loaded clinics. They
/// never become backend query parameters.
class ClinicDirectoryScreen extends StatefulWidget {
  const ClinicDirectoryScreen({super.key});

  @override
  State<ClinicDirectoryScreen> createState() => _ClinicDirectoryScreenState();
}

class _ClinicDirectoryScreenState extends State<ClinicDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  ClinicFilterSnapshot _filters = ClinicFilterSnapshot.none;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = context.read<PatientClinicDirectoryController>();
      if (controller.items.isEmpty &&
          controller.status == PatientClinicDirectoryStatus.idle) {
        controller.loadFirst();
      }
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final controller = context.read<PatientClinicDirectoryController>();
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      controller.loadMore();
    }
  }

  Future<void> _openFilters() async {
    final directory = context.read<PatientClinicDirectoryController>();
    final result = await showClinicFilterSheet(
      context: context,
      options: buildClinicFilterOptions(directory.items),
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
      _filters = ClinicFilterSnapshot.none;
    });
  }

  @override
  Widget build(BuildContext context) {
    final directory = context.watch<PatientClinicDirectoryController>();
    final request = context.watch<RequestSubmissionController>();

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
                              'Choose a clinic',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
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
                              'Find a clinic that\'s right for you.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
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
              child: ClinicSearchField(
                controller: _searchController,
                onChanged: directory.search,
              ),
            ),
            Expanded(
              child: _DirectoryBody(
                directory: directory,
                selectedClinicId: request.selectedClinicId,
                scrollController: _scrollController,
                filters: _filters,
                onResetFilters: _resetFilters,
              ),
            ),
            if (request.selectedClinicId != null)
              _ContinueBar(
                onContinue: () {
                  Navigator.of(context).pushNamed('/m05/situation');
                },
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
      label: 'Back',
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
  const _FilterAction({
    required this.activeCount,
    required this.onTap,
  });

  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasActive = activeCount > 0;

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Semantics(
        button: true,
        label: hasActive ? 'Filters, $activeCount active' : 'Filters',
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
    this.selectedClinicId,
    this.scrollController,
    required this.filters,
    required this.onResetFilters,
  });

  final PatientClinicDirectoryController directory;
  final String? selectedClinicId;
  final ScrollController? scrollController;
  final ClinicFilterSnapshot filters;
  final VoidCallback onResetFilters;

  @override
  Widget build(BuildContext context) {
    final status = directory.status;
    final rawItems = directory.items;

    if (status == PatientClinicDirectoryStatus.loadingFirst &&
        rawItems.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (status == PatientClinicDirectoryStatus.error && rawItems.isEmpty) {
      return _ErrorState(
        message: directory.error?.message ?? 'Unable to load clinics.',
        onRetry: directory.loadFirst,
      );
    }

    if (rawItems.isEmpty) {
      if (filters.isActive) {
        return _FilteredEmptyState(onReset: onResetFilters);
      }
      return _EmptyState(
        hasQuery: directory.query.trim().isNotEmpty,
      );
    }

    final visible = applyClinicFilters(
      items: rawItems,
      filters: filters,
    );

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
                ? '1 clinic found'
                : '${visible.length} clinics found',
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
            itemCount: visible.length + (directory.isLoadingMore ? 1 : 0),
            separatorBuilder: (context, index) =>
                const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index >= visible.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: OmniSpacing.md),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    ),
                  ),
                );
              }
              final item = visible[index];
              return ClinicListCard(
                clinic: item.clinic,
                selected: item.clinicId == selectedClinicId,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ClinicDetailScreen(clinicId: item.clinicId),
                    ),
                  );
                },
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
                Icons.local_hospital_outlined,
                size: 26,
                color: OmniColors.slateBlue,
              ),
            ),
            const SizedBox(height: OmniSpacing.base),
            Text(
              hasQuery ? 'No clinics found' : 'No clinics available',
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: OmniColors.textPrimary,
              ),
            ),
            const SizedBox(height: OmniSpacing.sm),
            Text(
              hasQuery
                  ? 'Try another search.'
                  : 'Check back later for open clinics.',
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
              'No clinics match these filters.',
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
                child: const Text('Reset filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

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
                color: OmniColors.errorSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 26,
                color: OmniColors.error,
              ),
            ),
            const SizedBox(height: OmniSpacing.base),
            Text(
              message,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 15,
                height: 1.4,
                color: OmniColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: OmniSpacing.base + 4),
            SizedBox(
              width: 160,
              height: 44,
              child: ElevatedButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueBar extends StatelessWidget {
  const _ContinueBar({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: OmniColors.borderLight),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            OmniSpacing.pageHorizontal,
            OmniSpacing.md,
            OmniSpacing.pageHorizontal,
            OmniSpacing.md,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onContinue,
              child: const Text('Continue'),
            ),
          ),
        ),
      ),
    );
  }
}
