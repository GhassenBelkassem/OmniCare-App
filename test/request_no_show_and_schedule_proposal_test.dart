// G-2 1a-4: NO_SHOW request status (C10) and schedule-proposal parsing
// without UI (C11). Logic only (CTO testing rule).
//
// The JSON below follows the backend records field by field
// (`PatientRequestResponse`, `PatientScheduleReadPort.Summary`,
// `ConfirmedSchedule`, `ActiveDelay`, `PatientRequestListItem`) with Spring
// Boot's default Jackson settings (ISO-8601 instants, nulls written). It was
// not captured from a running server.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

import 'package:omnicare_mobile/l10n/omni_localizations.dart';
import 'package:omnicare_mobile/features/request_core/data/request_models.dart';
import 'package:omnicare_mobile/features/request_core/domain/request_vocabulary.dart';
import 'package:omnicare_mobile/features/request_history/presentation/patient_request_journey.dart';
import 'package:omnicare_mobile/features/request_history/presentation/request_status_copy.dart';

const _requestId = '33333333-3333-4333-8333-333333333333';
const _clinicId = '44444444-4444-4444-8444-444444444444';
const _proposalId = '55555555-5555-4555-8555-555555555555';
const _confirmedRevisionId = '66666666-6666-4666-8666-666666666666';
const _delayId = '77777777-7777-4777-8777-777777777777';

Map<String, dynamic> _detailJson({
  required String status,
  List<String> actions = const [],
  Object? scheduleProposal,
}) => {
  'requestId': _requestId,
  'kind': 'CLINIC',
  'targetType': 'CLINIC',
  'targetId': _clinicId,
  'subjectType': 'SELF',
  'situation': 'APPOINTMENT',
  'patientStatus': status,
  'submittedAt': '2026-11-02T08:30:00Z',
  'cancelledAt': null,
  'version': 6,
  'availableActions': actions,
  'informationRequest': null,
  'scheduleProposal': scheduleProposal,
};

/// A clinic reschedule waiting for the patient, with the schedule it would
/// replace and a reported delay on that schedule.
const Map<String, dynamic> _rescheduleProposal = {
  'proposalId': _proposalId,
  'changeType': 'RESCHEDULE',
  'status': 'PROPOSED',
  'revisionNumber': 2,
  'proposedStartAt': '2026-11-20T09:00:00Z',
  'confirmedStartAt': null,
  'expectedDurationMinutes': 45,
  'proposalExpiresAt': '2026-11-18T09:00:00Z',
  'scheduleVersion': 3,
  'actionable': true,
  'currentConfirmedSchedule': {
    'scheduleRevisionId': _confirmedRevisionId,
    'revisionNumber': 1,
    'confirmedStartAt': '2026-11-19T08:00:00Z',
    'expectedDurationMinutes': 45,
    'scheduleVersion': 1,
  },
  'activeDelay': {
    'delayEventId': _delayId,
    'reportedAt': '2026-11-19T07:30:00Z',
    'estimatedStartAt': '2026-11-19T09:30:00Z',
  },
};

/// The generated French messages, without a widget tree.
final _fr = lookupOmniLocalizations(const Locale('fr'));

void main() {
  group('NO_SHOW (C10)', () {
    test('parsed from the wire value, list and detail', () {
      expect(
        PatientRequestStatus.parse('NO_SHOW'),
        PatientRequestStatus.noShow,
      );
      expect(PatientRequestStatus.noShow.wireValue, 'NO_SHOW');

      final item = PatientRequestListItem.fromJson({
        'requestId': _requestId,
        'clinicDisplayName': 'Clinique',
        'subjectType': 'SELF',
        'subjectDisplayName': 'Moi',
        'relationship': null,
        'situation': 'APPOINTMENT',
        'patientStatus': 'NO_SHOW',
        'submittedAt': '2026-11-02T08:30:00Z',
        'requiresPatientAction': false,
      });
      expect(item.patientStatus, PatientRequestStatus.noShow);

      final detail = PatientRequest.fromJson(_detailJson(status: 'NO_SHOW'));
      expect(detail.patientStatus, PatientRequestStatus.noShow);
    });

    test('final: terminal like the server, journey ends, no actions', () {
      expect(PatientRequestStatus.noShow.isTerminal, isTrue);

      final journey = PatientRequestJourneyMapper.fromStatus(
        PatientRequestStatus.noShow,
      );
      expect(journey.terminal, PatientRequestJourneyTerminal.noShow);
      expect(journey.isUnknown, isFalse);
      expect(journey.requiresPatientAction, isFalse);
      expect(journey.stages.map((s) => s.stage), [
        PatientRequestJourneyStage.request,
      ]);

      // The server sends no action for a terminal status
      // (`PatientRequestAction.availableFor`): nothing to press.
      final detail = PatientRequest.fromJson(_detailJson(status: 'NO_SHOW'));
      expect(detail.availableActions, isEmpty);
      expect(detail.canCancel, isFalse);
      expect(detail.canProvideInformation, isFalse);
    });

    test('past list: the server filter that holds it is the one sent', () {
      // Backend `PatientRequestListFilter.CANCELLED_DECLINED` contains
      // NO_SHOW; ACTIVE does not. The app only sends the filter name.
      expect(
        PatientRequestListFilter.cancelledDeclined.wireValue,
        'CANCELLED_DECLINED',
      );
    });

    test('French label with the existing status style', () {
      final copy = RequestStatusCopy.of(PatientRequestStatus.noShow, _fr);
      expect(copy.label, 'Rendez-vous manqué');
      expect(copy.label, 'Rendez-vous manqué');
      expect(
        copy.description,
        'La clinique a indiqué que ce rendez-vous n’a pas eu lieu.',
      );
      expect(copy.actionMessage, 'Demande terminée');
      // Same palette as the other ended-by-the-clinic outcomes.
      final cancelled = RequestStatusCopy.of(
        PatientRequestStatus.cancelled,
        _fr,
      );
      expect(copy.accent, cancelled.accent);
      expect(copy.softBackground, cancelled.softBackground);
    });

    test('a status added later still falls back to unknown', () {
      final detail = PatientRequest.fromJson(
        _detailJson(status: 'RESCHEDULE_REQUESTED_V3'),
      );
      expect(detail.patientStatus, PatientRequestStatus.unknown);
      expect(PatientRequestStatus.unknown.isTerminal, isFalse);
      expect(
        PatientRequestJourneyMapper.fromStatus(detail.patientStatus).isUnknown,
        isTrue,
      );
    });
  });

  group('schedule proposal parsed, no UI (C11)', () {
    test('proposal, confirmed schedule, delay and both actions', () {
      final request = PatientRequest.fromJson(
        _detailJson(
          status: 'CONFIRMED',
          actions: const [
            'CANCEL',
            'ACCEPT_SCHEDULE_PROPOSAL',
            'REJECT_SCHEDULE_PROPOSAL',
          ],
          scheduleProposal: _rescheduleProposal,
        ),
      );

      expect(request.availableActions, {
        PatientRequestAction.cancel,
        PatientRequestAction.acceptScheduleProposal,
        PatientRequestAction.rejectScheduleProposal,
      });
      expect(request.canCancel, isTrue);

      final proposal = request.scheduleProposal!;
      expect(proposal.proposalId, _proposalId);
      expect(proposal.changeType, ScheduleProposalChangeType.reschedule);
      expect(proposal.status, ScheduleProposalStatus.proposed);
      expect(proposal.revisionNumber, 2);
      expect(proposal.proposedStartAt, DateTime.utc(2026, 11, 20, 9));
      expect(proposal.confirmedStartAt, isNull);
      expect(proposal.expectedDurationMinutes, 45);
      expect(proposal.proposalExpiresAt, DateTime.utc(2026, 11, 18, 9));
      expect(proposal.scheduleVersion, 3);
      expect(proposal.actionable, isTrue);

      final current = proposal.currentConfirmedSchedule!;
      expect(current.scheduleRevisionId, _confirmedRevisionId);
      expect(current.revisionNumber, 1);
      expect(current.confirmedStartAt, DateTime.utc(2026, 11, 19, 8));
      expect(current.expectedDurationMinutes, 45);
      expect(current.scheduleVersion, 1);

      final delay = proposal.activeDelay!;
      expect(delay.delayEventId, _delayId);
      expect(delay.reportedAt, DateTime.utc(2026, 11, 19, 7, 30));
      expect(delay.estimatedStartAt, DateTime.utc(2026, 11, 19, 9, 30));
    });

    test('initial proposal without the optional parts', () {
      final request = PatientRequest.fromJson(
        _detailJson(
          status: 'WAITING_FOR_CONFIRMATION',
          actions: const [
            'CANCEL',
            'ACCEPT_SCHEDULE_PROPOSAL',
            'REJECT_SCHEDULE_PROPOSAL',
          ],
          scheduleProposal: {
            ..._rescheduleProposal,
            'changeType': 'INITIAL_PROPOSAL',
            'revisionNumber': 1,
            'scheduleVersion': 0,
            'currentConfirmedSchedule': null,
            'activeDelay': null,
          },
        ),
      );
      final proposal = request.scheduleProposal!;
      expect(proposal.changeType, ScheduleProposalChangeType.initialProposal);
      expect(proposal.scheduleVersion, 0);
      expect(proposal.currentConfirmedSchedule, isNull);
      expect(proposal.activeDelay, isNull);
    });

    test('a confirmed schedule (nothing to answer)', () {
      final request = PatientRequest.fromJson(
        _detailJson(
          status: 'CONFIRMED',
          actions: const ['CANCEL'],
          scheduleProposal: {
            ..._rescheduleProposal,
            'status': 'CONFIRMED',
            'confirmedStartAt': '2026-11-20T09:00:00Z',
            'actionable': false,
          },
        ),
      );
      final proposal = request.scheduleProposal!;
      expect(proposal.status, ScheduleProposalStatus.confirmed);
      expect(proposal.confirmedStartAt, DateTime.utc(2026, 11, 20, 9));
      expect(proposal.actionable, isFalse);
      expect(request.availableActions, {PatientRequestAction.cancel});
    });

    test('absent or null proposal → null; unknown enums → unknown', () {
      final withoutKey = _detailJson(status: 'UNDER_REVIEW')
        ..remove('scheduleProposal');
      expect(PatientRequest.fromJson(withoutKey).scheduleProposal, isNull);
      expect(
        PatientRequest.fromJson(
          _detailJson(status: 'UNDER_REVIEW'),
        ).scheduleProposal,
        isNull,
      );

      final proposal = PatientRequest.fromJson(
        _detailJson(
          status: 'CONFIRMED',
          scheduleProposal: {
            ..._rescheduleProposal,
            'changeType': 'SPLIT_V2',
            'status': 'ON_HOLD_V2',
          },
        ),
      ).scheduleProposal!;
      expect(proposal.changeType, ScheduleProposalChangeType.unknown);
      expect(proposal.status, ScheduleProposalStatus.unknown);
    });

    test('malformed proposal is a contract error, like informationRequest', () {
      expect(
        () => PatientRequest.fromJson(
          _detailJson(status: 'CONFIRMED', scheduleProposal: 'PROPOSED'),
        ),
        throwsA(isA<RequestContractException>()),
      );
      expect(
        () => PatientRequest.fromJson(
          _detailJson(
            status: 'CONFIRMED',
            scheduleProposal: {..._rescheduleProposal}..remove('proposalId'),
          ),
        ),
        throwsA(isA<RequestContractException>()),
      );
    });

    test('action wire values match the backend enum', () {
      expect(
        PatientRequestAction.tryParse('ACCEPT_SCHEDULE_PROPOSAL'),
        PatientRequestAction.acceptScheduleProposal,
      );
      expect(
        PatientRequestAction.tryParse('REJECT_SCHEDULE_PROPOSAL'),
        PatientRequestAction.rejectScheduleProposal,
      );
      // Still dropped: an action this app does not know.
      expect(PatientRequestAction.tryParse('RESCHEDULE_V2'), isNull);
    });
  });
}
