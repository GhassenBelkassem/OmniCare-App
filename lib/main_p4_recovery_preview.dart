import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/omni_theme.dart';
import 'features/emergency/urgent_cabinet/urgent_cabinet_care_subject.dart';
import 'features/emergency/urgent_cabinet/urgent_cabinet_doctor_fixture.dart';
import 'features/emergency/urgent_cabinet/urgent_cabinet_flow_controller.dart';
import 'features/emergency/urgent_cabinet/urgent_cabinet_request_decision_source.dart';
import 'features/emergency/urgent_cabinet/urgent_cabinet_request_accepted_screen.dart';
import 'features/emergency/urgent_cabinet/urgent_cabinet_request_recovery_screen.dart';
import 'features/emergency/urgent_cabinet/urgent_cabinet_request_review.dart';
import 'features/emergency/urgent_cabinet/urgent_cabinet_request_source.dart';
import 'features/emergency/urgent_cabinet/urgent_cabinet_request_state.dart';

const _scenario = String.fromEnvironment(
  'P4_RECOVERY_SCENARIO',
  defaultValue: 'declined',
);

void main() {
  runApp(const _P4RecoveryPreviewApp());
}

class _P4RecoveryPreviewApp extends StatefulWidget {
  const _P4RecoveryPreviewApp();

  @override
  State<_P4RecoveryPreviewApp> createState() => _P4RecoveryPreviewAppState();
}

class _P4RecoveryPreviewAppState extends State<_P4RecoveryPreviewApp> {
  UrgentCabinetFlowController? _controller;
  Object? _failure;

  @override
  void initState() {
    super.initState();
    _prepareExplicitPreview();
  }

  Future<void> _prepareExplicitPreview() async {
    if (!kDebugMode) {
      setState(() {
        _failure = StateError('The P4 recovery preview is debug-only.');
      });
      return;
    }

    try {
      final doctor =
          UrgentCabinetDoctorFixtureSource.developmentDoctorDetails.first;
      final cabinet = doctor.cabinetById('p4-demo-cabinet-lac-1')!;
      final review = validateUrgentCabinetRequestReview(
        careSubject: const UrgentCabinetCareSubject.self(),
        patientDisplayName: 'Sarah Martin',
        selectedDoctorId: doctor.doctorId,
        selectedCabinetId: cabinet.cabinetId,
        doctor: doctor,
        cabinet: cabinet,
        feeQuote: UrgentCabinetDoctorFixtureSource.developmentFeeQuotes.first,
        developmentFixturesEnabled: true,
      ).review!;
      final controller =
          UrgentCabinetFlowController(accountId: 'p4-recovery-preview-account')
            ..selectSelf()
            ..selectDoctor(
              doctorId: doctor.doctorId,
              cabinetId: cabinet.cabinetId,
            );
      await controller.submitReview(
        review: review,
        source: const UrgentCabinetDevelopmentRequestSource(),
      );

      final pending =
          controller.requestState as UrgentCabinetRequestAttemptState;
      final decisions = UrgentCabinetDevelopmentDecisionSource();
      final subscription = decisions.decisions.listen(
        controller.applyDoctorDecision,
      );
      switch (_scenario) {
        case 'accepted':
          decisions.emitAccepted(
            accountId: 'p4-recovery-preview-account',
            localAttemptGeneration: pending.localAttemptGeneration,
            doctorId: pending.review.doctorId,
            cabinetId: pending.review.cabinetId,
          );
        case 'declined':
          decisions.emitDeclined(
            accountId: 'p4-recovery-preview-account',
            localAttemptGeneration: pending.localAttemptGeneration,
            doctorId: pending.review.doctorId,
            cabinetId: pending.review.cabinetId,
          );
        case 'unavailable':
          decisions.emitUnavailable(
            accountId: 'p4-recovery-preview-account',
            localAttemptGeneration: pending.localAttemptGeneration,
            doctorId: pending.review.doctorId,
            cabinetId: pending.review.cabinetId,
          );
        default:
          throw ArgumentError.value(
            _scenario,
            'P4_RECOVERY_SCENARIO',
            'Use accepted, declined or unavailable.',
          );
      }
      await subscription.cancel();
      decisions.dispose();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (error) {
      if (mounted) setState(() => _failure = error);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildOmniTheme(),
      home: _failure != null
          ? Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Preview unavailable: $_failure'),
                ),
              ),
            )
          : _controller == null
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : ChangeNotifierProvider<UrgentCabinetFlowController>.value(
              value: _controller!,
              child: _scenario == 'accepted'
                  ? const UrgentCabinetRequestAcceptedScreen(
                      onExitJourney: _previewActionUnavailable,
                    )
                  : const UrgentCabinetRequestRecoveryScreen(
                      onChooseAnotherDoctor: _previewActionUnavailable,
                      onExitJourney: _previewActionUnavailable,
                    ),
            ),
    );
  }
}

void _previewActionUnavailable() {}
