import 'package:flutter/material.dart';

import '../../../../core/theme/omni_theme.dart';
import '../../models/patient_passport_view_models.dart';
import 'passport_card.dart';

class PassportHistoryTab extends StatefulWidget {
  final List<PassportConsultation> consultations;
  final VoidCallback onOpenFilters;
  final Future<void> Function(PassportConsultation consultation)?
  onToggleSharing;

  const PassportHistoryTab({
    super.key,
    required this.consultations,
    required this.onOpenFilters,
    this.onToggleSharing,
  });

  @override
  State<PassportHistoryTab> createState() => _PassportHistoryTabState();
}

class _PassportHistoryTabState extends State<PassportHistoryTab> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final visibleConsultations = widget.consultations
        .where(
          (consultation) =>
              query.isEmpty ||
              '${consultation.doctor} ${consultation.reason} ${consultation.specialty}'
                  .toLowerCase()
                  .contains(query),
        )
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Historique des consultations',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        Text(
          'Retrouvez vos visites, diagnostics et ordonnances.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: OmniColors.textSecondary),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Rechercher une consultation...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 21),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Semantics(
              button: true,
              label: 'Filtrer l’historique',
              child: IconButton(
                onPressed: widget.onOpenFilters,
                icon: const Icon(Icons.tune_rounded),
                color: OmniColors.primaryAction,
                style: IconButton.styleFrom(
                  minimumSize: const Size(52, 52),
                  backgroundColor: OmniColors.mintSoft,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Icon(
              Icons.description_outlined,
              size: 18,
              color: OmniColors.primaryAction,
            ),
            const SizedBox(width: 8),
            Text(
              '${visibleConsultations.length} consultations',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (visibleConsultations.isEmpty)
          const PassportCard(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Aucune consultation trouvée.')),
            ),
          )
        else
          ...visibleConsultations.map(
            (consultation) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ConsultationCard(
                consultation: consultation,
                onToggleSharing:
                    consultation.status ==
                            PassportConsultationStatus.completed &&
                        consultation.consultationId != null &&
                        consultation.sharingVersion != null
                    ? () => widget.onToggleSharing?.call(consultation)
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

class _ConsultationCard extends StatelessWidget {
  final PassportConsultation consultation;
  final VoidCallback? onToggleSharing;

  const _ConsultationCard({
    required this.consultation,
    required this.onToggleSharing,
  });

  @override
  Widget build(BuildContext context) {
    final cancelled =
        consultation.status == PassportConsultationStatus.cancelled;
    final accent = cancelled ? OmniColors.error : OmniColors.primaryAction;
    final surface = cancelled ? OmniColors.errorSoft : Colors.white;
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cancelled
              ? OmniColors.error.withValues(alpha: 0.28)
              : OmniColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: cancelled
                          ? const Color(0xFFFFE4E2)
                          : OmniColors.mintSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.calendar_month_outlined,
                      color: accent,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              consultation.date,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: OmniColors.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          consultation.doctor,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${consultation.reason} · ${consultation.specialty}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: OmniColors.textSecondary,
                                height: 1.35,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: OmniColors.textTertiary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 52,
            height: 86,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: cancelled
                      ? const Color(0x33D92D20)
                      : OmniColors.borderLight,
                ),
              ),
            ),
            child: IconButton(
              tooltip: consultation.isShareable
                  ? 'Rendre privée pour le partage normal'
                  : 'Rendre éligible au partage autorisé',
              onPressed: onToggleSharing,
              icon: Icon(
                consultation.isShareable
                    ? Icons.lock_open_outlined
                    : Icons.lock_outline_rounded,
                color: cancelled ? OmniColors.error : OmniColors.textTertiary,
                size: 19,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
