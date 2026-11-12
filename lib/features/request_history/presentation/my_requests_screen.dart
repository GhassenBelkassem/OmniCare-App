import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/omni_theme.dart';
import '../../request_core/data/request_models.dart';
import '../../request_core/domain/request_vocabulary.dart';
import '../application/patient_requests_controller.dart';
import 'patient_request_detail_screen.dart';
import 'request_status_copy.dart';
import '../../../l10n/omni_localizations.dart';

class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});
  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  final scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    final c = context.read<PatientRequestsController>();
    if (c.status == PatientRequestsStatus.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) c.loadFirst();
      });
    }
    scroll.addListener(() {
      if (scroll.position.pixels >= scroll.position.maxScrollExtent - 180) {
        context.read<PatientRequestsController>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PatientRequestsController>();
    return Scaffold(
      backgroundColor: OmniColors.pageBackground,
      appBar: AppBar(title: const Text('My requests')),
      body: RefreshIndicator(
        onRefresh: () => c.loadFirst(preserveItems: true),
        child: Column(
          children: [
            _FilterBar(controller: c),
            Expanded(child: _content(c)),
          ],
        ),
      ),
    );
  }

  Widget _content(PatientRequestsController c) {
    if (c.status == PatientRequestsStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (c.status == PatientRequestsStatus.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(OmniSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40, color: OmniColors.textTertiary),
              const SizedBox(height: 12),
              Text(c.listFailure!.message(OmniLocalizations.of(context)), textAlign: TextAlign.center, style: const TextStyle(color: OmniColors.textSecondary)),
            ],
          ),
        ),
      );
    }
    if (c.status == PatientRequestsStatus.empty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(OmniSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inbox_outlined, size: 48, color: OmniColors.textTertiary),
              const SizedBox(height: 12),
              Text(
                c.filter == PatientRequestListFilter.all
                    ? 'You have no requests yet.'
                    : 'No ${c.filter.label.toLowerCase()} requests yet.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: OmniColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      controller: scroll,
      padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.pageHorizontal, vertical: OmniSpacing.sm),
      itemCount: c.items.length + (c.isLoadingMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: OmniSpacing.sm),
      itemBuilder: (context, index) {
        if (index >= c.items.length) {
          return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
        }
        return RequestCard(request: c.items[index]);
      },
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.controller});
  final PatientRequestsController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.pageHorizontal, vertical: OmniSpacing.sm),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: PatientRequestListFilter.values.length,
          separatorBuilder: (_, _) => const SizedBox(width: OmniSpacing.sm),
          itemBuilder: (context, index) {
            final filter = PatientRequestListFilter.values[index];
            final selected = controller.filter == filter;
            return ChoiceChip(
              label: Text(filter.label),
              selected: selected,
              onSelected: (_) => controller.selectFilter(filter),
              selectedColor: OmniColors.mintSoft,
              labelStyle: TextStyle(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? OmniColors.deepTeal : OmniColors.textSecondary,
                fontSize: 13,
              ),
              side: BorderSide(color: selected ? OmniColors.freshMint : OmniColors.borderLight),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            );
          },
        ),
      ),
    );
  }
}

class RequestCard extends StatelessWidget {
  const RequestCard({super.key, required this.request});
  final PatientRequestListItem request;

  @override
  Widget build(BuildContext context) {
    final status = RequestStatusCopy.of(
      request.patientStatus,
      OmniLocalizations.of(context),
    );
    final localizations = MaterialLocalizations.of(context);
    final submittedAt = request.submittedAt.toLocal();
    final submittedLabel =
        '${localizations.formatMediumDate(submittedAt)} \u00b7 '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(submittedAt))}';
    final subjectLabel = request.subjectType == RequestSubjectType.self
        ? 'Me'
        : request.subjectDisplayName;

    return Material(
      key: ValueKey(request.requestId.value),
      color: OmniColors.surfacePrimary,
      borderRadius: BorderRadius.circular(OmniRadii.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(OmniRadii.card),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PatientRequestDetailScreen(requestId: request.requestId),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(OmniSpacing.base),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(OmniRadii.card),
            border: Border.all(color: OmniColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      request.clinicDisplayName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: OmniColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, size: 20, color: OmniColors.textTertiary),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '$subjectLabel \u00b7 ${situationLabel(request.situation)}',
                style: const TextStyle(fontSize: 13, color: OmniColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(status.icon, size: 16, color: status.accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      status.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: status.accent,
                      ),
                    ),
                  ),
                ],
              ),
              if (request.requiresPatientAction) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 14, color: OmniColors.amber),
                    const SizedBox(width: 4),
                    const Text(
                      'Action required',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: OmniColors.amber,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              Text(
                'Submitted $submittedLabel',
                style: const TextStyle(fontSize: 12, color: OmniColors.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
