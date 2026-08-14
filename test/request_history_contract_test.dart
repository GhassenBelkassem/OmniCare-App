import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/features/request_core/data/request_models.dart';
import 'package:omnicare_mobile/features/request_core/domain/request_vocabulary.dart';

const _id = '33333333-3333-4333-8333-333333333333';
const _target = '44444444-4444-4444-8444-444444444444';

Map<String, dynamic> _request({
  String situation = 'APPOINTMENT',
  String status = 'REQUEST_RECEIVED',
  List<String> actions = const ['CANCEL'],
  String? cancelledAt,
  int version = 3,
}) => {
  'requestId': _id,
  'kind': 'CLINIC',
  'targetType': 'CLINIC',
  'targetId': _target,
  'clinicDisplayName': 'Clinique Centre',
  'subjectType': 'SELF',
  'subjectDisplayName': 'Sarah Martin',
  'relationship': null,
  'situation': situation,
  'patientStatus': status,
  'submittedAt': '2026-08-08T10:00:00Z',
  'cancelledAt': cancelledAt,
  'version': version,
  'availableActions': actions,
  'requiresPatientAction': false,
};

void main() {
  group('M05 F03 request contracts', () {
    test('preserves Slice ordering and metadata', () {
      final page = PatientRequestPage.fromJson({
        'contractVersion': '1.0',
        'items': [
          _request(situation: 'AMBULANCE', status: 'UNDER_REVIEW'),
          _request(situation: 'URGENT', status: 'CONFIRMED', version: 2),
        ],
        'page': 1,
        'pageSize': 20,
        'hasNext': true,
      });
      expect(page.page, 1);
      expect(page.pageSize, 20);
      expect(page.hasNext, isTrue);
      expect(page.items.map((item) => item.situation), [
        RequestSituation.ambulance,
        RequestSituation.urgent,
      ]);
    });

    test('parses detail version, actions and cancellation time', () {
      final request = PatientRequest.fromJson(
        _request(
          cancelledAt: '2026-08-08T11:00:00Z',
          status: 'CANCELLED',
          actions: const [],
          version: 4,
        ),
      );
      expect(request.requestId.value, _id);
      expect(request.targetId, _target);
      expect(request.patientStatus, PatientRequestStatus.cancelled);
      expect(request.cancelledAt, DateTime.utc(2026, 8, 8, 11));
      expect(request.version, 4);
      expect(request.availableActions, isEmpty);
    });

    test('cancel payload contains only the backend expectedVersion field', () {
      expect(const CancelRequestPayload(expectedVersion: 7).toJson(), {
        'expectedVersion': 7,
      });
    });
  });
}
