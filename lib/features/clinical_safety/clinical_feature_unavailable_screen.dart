import 'package:flutter/material.dart';

import '../../core/theme/omni_theme.dart';

/// Fail-closed destination for clinical workflows that do not yet have an
/// approved production backend contract.
///
/// This screen deliberately does not accept or render route arguments. That
/// keeps clinical intake data out of an unsupported destination and prevents
/// stale deep links from manufacturing a successful outcome.
class ClinicalFeatureUnavailableScreen extends StatelessWidget {
  const ClinicalFeatureUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const ValueKey('clinical-feature-unavailable-screen'),
    backgroundColor: OmniColors.pageBackground,
    appBar: AppBar(
      backgroundColor: OmniColors.surfacePrimary,
      surfaceTintColor: OmniColors.surfacePrimary,
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back_rounded),
        tooltip: 'Retour',
      ),
      title: const Text('Service indisponible'),
    ),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.health_and_safety_outlined,
                      size: 52,
                      color: OmniColors.deepTealActive,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Cette demande n’est pas encore disponible dans cette version.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: OmniColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Aucune demande, réservation ou consultation n’a été créée. '
                      'Revenez à l’écran précédent pour choisir un service disponible.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: OmniColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('Revenir'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
