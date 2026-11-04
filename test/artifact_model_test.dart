import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/features/doctor/artifact/artifact.dart';
import 'package:omnicare_mobile/features/scheduled_care/realtime/scheduled_care_event.dart';

void main() {
  test('artifact model keeps definition and render versions distinct', () {
    final artifact = OfficialArtifact.fromJson({
      'artifactId': '11111111-1111-4111-8111-111111111111',
      'artifactType': 'SICK_LEAVE_CERTIFICATE',
      'artifactVersion': 3,
      'status': 'FINALIZED',
      'renderStatus': 'READY',
      'renderVersion': 1,
      'definition': {
        'certificate': {
          'statement': 'Attendance only',
          'startDate': '2026-10-26',
          'endDate': '2026-10-28',
          'durationDays': 3,
        },
      },
      'verificationReference': 'opaque-reference',
    });

    expect(artifact.version, 3);
    expect(artifact.renderVersion, 1);
    expect(artifact.finalized, isTrue);
    expect(artifact.ready, isTrue);
    expect(artifact.definition['certificate'], isA<Map>());
  });

  test(
    'ambiguous retry registry retains a key only for the same fingerprint',
    () {
      final keys = ArtifactMutationKeys();
      final first = keys.acquire('save:artifact-v1:statement-a');
      expect(keys.acquire('save:artifact-v1:statement-a'), first);
      expect(keys.acquire('save:artifact-v1:statement-b'), isNot(first));
      expect(first, startsWith('artifact-save:'));
      expect(first.length, greaterThan(40));
      keys.complete('save:artifact-v1:statement-a');
      expect(keys.acquire('save:artifact-v1:statement-a'), isNot(first));
    },
  );

  test('PHI-free artifact realtime event parses as an invalidation', () {
    final event = ScheduledCareInvalidationEvent.tryParse(
      '{"eventId":"22222222-2222-4222-8222-222222222222",'
      '"eventType":"DOCUMENT_READY","resourceType":"ARTIFACT",'
      '"resourceId":"11111111-1111-4111-8111-111111111111",'
      '"version":3,"occurredAt":"2026-10-26T10:00:00Z"}',
    );
    expect(event?.resourceType, ScheduledCareResourceType.artifact);
    expect(event?.rawEventType, 'DOCUMENT_READY');
  });
}
