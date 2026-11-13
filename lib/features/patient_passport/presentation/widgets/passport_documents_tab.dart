import 'package:flutter/material.dart';

import '../../../../core/theme/omni_theme.dart';
import 'passport_card.dart';
import 'passport_card_status.dart';

/// The « Documents » tab (G2.1-A4). [countText] is true or empty: the server
/// gives no total (see `documentsCountText`).
class PassportDocumentsTab extends StatelessWidget {
  /// « + »; hidden when null (a family member without an id: an upload must
  /// never land on the holder's record).
  final VoidCallback? onAddDocument;
  final String countText;

  /// Loading or failure (with « Réessayer ») in place of the list.
  final PassportCardStatus? status;

  /// No document: the existing « Aucun document médical disponible » card.
  final bool isEmpty;

  const PassportDocumentsTab({
    super.key,
    required this.onAddDocument,
    required this.countText,
    this.status,
    this.isEmpty = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Documents médicaux',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    countText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: OmniColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (onAddDocument case final onAddDocument?)
              Semantics(
                button: true,
                label: 'Ajouter un document médical',
                child: IconButton(
                  onPressed: onAddDocument,
                  icon: const Icon(Icons.add_rounded, size: 27),
                  color: Colors.white,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(56, 56),
                    backgroundColor: OmniColors.primaryAction,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        if (status case final status?)
          PassportCard(child: PassportCardStatusBody(status: status))
        else if (isEmpty)
          PassportCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 46),
            border: Border.all(color: OmniColors.borderStrong),
            child: Column(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: OmniColors.violetSoft,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: OmniColors.violet,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Aucun document médical disponible',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 92),
              ],
            ),
          ),
      ],
    );
  }
}
