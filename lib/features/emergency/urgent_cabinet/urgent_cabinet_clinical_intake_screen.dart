import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../emergency_request_step2.dart';
import '../emergency_symptom_intake_value.dart';
import 'urgent_cabinet_clinical_intake_draft.dart';
import 'urgent_cabinet_flow_controller.dart';
import 'urgent_cabinet_flow_routes.dart';

/// Reuses the frozen symptom presentation without inheriting its HOME route.
class UrgentCabinetClinicalIntakeScreen extends StatelessWidget {
  const UrgentCabinetClinicalIntakeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final flow = context.read<UrgentCabinetFlowController>();
    final subject = flow.selectedSubject;
    if (subject == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
      return const SizedBox.shrink();
    }

    final existing = flow.symptomIntakeValue;
    final initialData = <String, dynamic>{
      if (existing != null) ...{
        'bodyParts': existing.rawAnatomicalRegionIds,
        'painLevel': existing.painScore,
        'description': existing.shortDescription,
        'symptoms': existing.shortDescription,
      },
    };

    return EmergencyRequestStep2(
      step1Data: initialData,
      maxDescriptionCharacters:
          UrgentCabinetClinicalIntakeDraft.maxDescriptionCharacters,
      requireExplicitPainSelection: true,
      onCompleted: (value) => _complete(context, flow: flow, value: value),
    );
  }

  void _complete(
    BuildContext context, {
    required UrgentCabinetFlowController flow,
    required EmergencySymptomIntakeValue value,
  }) {
    final hasTarget =
        flow.selectedDoctorId != null && flow.selectedCabinetId != null;
    final transition = hasTarget
        ? flow.saveClinicalIntake(
            UrgentCabinetClinicalIntakeDraft.fromPresentation(
              careSubject: flow.selectedSubject!,
              doctorId: flow.selectedDoctorId!,
              cabinetId: flow.selectedCabinetId!,
              value: value,
            ),
          )
        : flow.saveSymptomIntake(value);
    if (!context.mounted) {
      return;
    }
    if (transition != UrgentCabinetIntakeTransition.saved) {
      return;
    }
    if (hasTarget) {
      Navigator.of(context).pushReplacementNamed<void, void>(
        UrgentCabinetFlowRoutes.requestConfirmation,
      );
    } else {
      Navigator.of(
        context,
      ).pushNamed<void>(UrgentCabinetFlowRoutes.doctorDirectory);
    }
  }
}
