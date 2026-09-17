import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/features/request_core/domain/request_vocabulary.dart';
import 'package:omnicare_mobile/features/request_history/presentation/patient_request_journey.dart';

void main() {
  PatientRequestJourneyStageState stateFor(
    PatientRequestJourney journey,
    PatientRequestJourneyStage stage,
  ) => journey.stages.singleWhere((item) => item.stage == stage).state;

  group('PatientRequestJourneyMapper', () {
    test(
      'REQUEST_RECEIVED starts with request and leaves later product stages upcoming',
      () {
        final journey = PatientRequestJourneyMapper.fromStatus(
          PatientRequestStatus.requestReceived,
        );
        expect(
          stateFor(journey, PatientRequestJourneyStage.request),
          PatientRequestJourneyStageState.current,
        );
        expect(
          stateFor(journey, PatientRequestJourneyStage.review),
          PatientRequestJourneyStageState.upcoming,
        );
      },
    );

    test('UNDER_REVIEW completes request and makes review current', () {
      final journey = PatientRequestJourneyMapper.fromStatus(
        PatientRequestStatus.underReview,
      );
      expect(
        stateFor(journey, PatientRequestJourneyStage.request),
        PatientRequestJourneyStageState.completed,
      );
      expect(
        stateFor(journey, PatientRequestJourneyStage.review),
        PatientRequestJourneyStageState.current,
      );
    });

    test(
      'INFORMATION_REQUIRED remains in review and asks the patient to act',
      () {
        final journey = PatientRequestJourneyMapper.fromStatus(
          PatientRequestStatus.informationRequired,
        );
        expect(
          stateFor(journey, PatientRequestJourneyStage.review),
          PatientRequestJourneyStageState.current,
        );
        expect(journey.requiresPatientAction, isTrue);
        expect(
          stateFor(journey, PatientRequestJourneyStage.scheduling),
          PatientRequestJourneyStageState.upcoming,
        );
      },
    );

    test(
      'scheduling and confirmation statuses map to their own current stage',
      () {
        final scheduling = PatientRequestJourneyMapper.fromStatus(
          PatientRequestStatus.schedulingInProgress,
        );
        final confirmation = PatientRequestJourneyMapper.fromStatus(
          PatientRequestStatus.waitingForConfirmation,
        );
        expect(
          stateFor(scheduling, PatientRequestJourneyStage.scheduling),
          PatientRequestJourneyStageState.current,
        );
        expect(
          stateFor(confirmation, PatientRequestJourneyStage.confirmation),
          PatientRequestJourneyStageState.current,
        );
        expect(confirmation.requiresPatientAction, isTrue);
      },
    );

    test(
      'CONFIRMED keeps care upcoming and CARE_IN_PROGRESS makes care current',
      () {
        final confirmed = PatientRequestJourneyMapper.fromStatus(
          PatientRequestStatus.confirmed,
        );
        final inCare = PatientRequestJourneyMapper.fromStatus(
          PatientRequestStatus.careInProgress,
        );
        expect(
          stateFor(confirmed, PatientRequestJourneyStage.confirmation),
          PatientRequestJourneyStageState.completed,
        );
        expect(
          stateFor(confirmed, PatientRequestJourneyStage.care),
          PatientRequestJourneyStageState.upcoming,
        );
        expect(
          stateFor(inCare, PatientRequestJourneyStage.care),
          PatientRequestJourneyStageState.current,
        );
      },
    );

    test('COMPLETED is a successful terminal journey', () {
      final journey = PatientRequestJourneyMapper.fromStatus(
        PatientRequestStatus.completed,
      );
      expect(journey.terminal, PatientRequestJourneyTerminal.completed);
      expect(
        journey.stages.every(
          (item) => item.state == PatientRequestJourneyStageState.completed,
        ),
        isTrue,
      );
    });

    test('DECLINED and CANCELLED stop without fabricated future stages', () {
      for (final status in [
        PatientRequestStatus.declined,
        PatientRequestStatus.cancelled,
      ]) {
        final journey = PatientRequestJourneyMapper.fromStatus(status);
        expect(journey.stages, hasLength(1));
        expect(journey.stages.single.stage, PatientRequestJourneyStage.request);
        expect(journey.terminal, isNotNull);
      }
    });

    test('unknown future status produces a safe non-guessing presentation', () {
      final journey = PatientRequestJourneyMapper.fromStatus(
        PatientRequestStatus.unknown,
      );
      expect(journey.isUnknown, isTrue);
      expect(journey.stages, isEmpty);
      expect(journey.terminal, isNull);
    });

    testWidgets(
      'journey renders an accessible action signal and terminal branch',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: PatientRequestJourneyWidget(
              journey: PatientRequestJourneyMapper.fromStatus(
                PatientRequestStatus.informationRequired,
              ),
              submittedAt: DateTime.utc(2026, 8, 9, 14, 27),
            ),
          ),
        );
        expect(find.text('Clinic review'), findsOneWidget);
        expect(find.text('The clinic team reviews your request.'), findsOneWidget);

        await tester.pumpWidget(
          MaterialApp(
            home: PatientRequestJourneyWidget(
              journey: PatientRequestJourneyMapper.fromStatus(
                PatientRequestStatus.cancelled,
              ),
              submittedAt: DateTime.utc(2026, 8, 9, 14, 27),
            ),
          ),
        );
        expect(find.text('Request cancelled'), findsOneWidget);
        expect(find.text('Scheduling'), findsNothing);
        expect(find.text('Confirmation'), findsNothing);
      },
    );
  });
}
