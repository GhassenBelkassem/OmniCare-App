import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';
import '../domain/urgent_journey_models.dart';
import '../domain/p4_urgent_feature_gate.dart';
import 'p4_urgent_journey_coordinator.dart';

abstract final class P4UrgentRoutes {
  static const entry = '/emergency-step0';
  static const subject = '/emergency-step1';
  static const cabinetEntry = '/doctor/cabinet/who-needs-care';

  static const prohibitedContinuations = <String>{
    '/emergency-step2',
    '/emergency-step3',
    '/emergency-review',
    '/doctor-selection',
    '/review-confirm',
    '/doctor-calling',
    '/doctor-arriving',
    '/consultation-qr',
    '/consultation-complete',
  };
}

/// The only route resolver for Patient P4 urgent entry and legacy containment.
abstract final class P4UrgentRouteOwner {
  static bool owns(String? routeName) =>
      routeName == P4UrgentRoutes.entry ||
      routeName == P4UrgentRoutes.subject ||
      routeName == P4UrgentRoutes.cabinetEntry ||
      P4UrgentRoutes.prohibitedContinuations.contains(routeName);

  static Widget? buildPage(
    RouteSettings settings, {
    P4UrgentFeatureGate featureGate = P4UrgentFeatureGate.runtime,
  }) {
    if (owns(settings.name) && !featureGate.isEnabled) {
      return const P4UrgentFeatureUnavailableScreen();
    }
    return switch (settings.name) {
      P4UrgentRoutes.entry => P4UrgentJourneyCoordinator(
        featureGate: featureGate,
      ),
      P4UrgentRoutes.subject => P4UrgentJourneyCoordinator(
        initialStage: P4UrgentCoordinatorStage.subject,
        initialMode: _modeFromArguments(settings.arguments),
        featureGate: featureGate,
      ),
      P4UrgentRoutes.cabinetEntry => P4UrgentJourneyCoordinator(
        initialStage: P4UrgentCoordinatorStage.subject,
        initialMode: UrgentAttemptMode.cabinet,
        featureGate: featureGate,
      ),
      final String routeName
          when P4UrgentRoutes.prohibitedContinuations.contains(routeName) =>
        const P4ProhibitedContinuationScreen(),
      _ => null,
    };
  }

  static UrgentAttemptMode _modeFromArguments(Object? arguments) {
    if (arguments is P4UrgentRouteArguments) return arguments.mode;
    if (arguments is Map && arguments['consultationType'] == 'cabinet') {
      return UrgentAttemptMode.cabinet;
    }
    return UrgentAttemptMode.home;
  }
}

final class P4UrgentRouteArguments {
  const P4UrgentRouteArguments({required this.mode});

  final UrgentAttemptMode mode;
}

class P4ProhibitedContinuationScreen extends StatelessWidget {
  const P4ProhibitedContinuationScreen({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: OmniColors.pageBackground,
    child: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(OmniSpacing.pageHorizontal),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              key: const ValueKey('p4-prohibited-continuation'),
              padding: const EdgeInsets.all(OmniSpacing.xl),
              decoration: BoxDecoration(
                color: OmniColors.surfacePrimary,
                borderRadius: BorderRadius.circular(OmniRadii.cardLarge),
                border: Border.all(color: OmniColors.borderLight),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    size: 44,
                    color: OmniColors.deepTeal,
                  ),
                  const SizedBox(height: OmniSpacing.md),
                  Text(
                    'Parcours urgent sécurisé',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: OmniSpacing.sm),
                  Text(
                    'Cette ancienne étape n’est plus accessible depuis P4. '
                    'Recommencez depuis l’entrée urgente sécurisée.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: OmniColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: OmniSpacing.lg),
                  FilledButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pushReplacementNamed(P4UrgentRoutes.entry),
                    child: const Text('Revenir au début'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
