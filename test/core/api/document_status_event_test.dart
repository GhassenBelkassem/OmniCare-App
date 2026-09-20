import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/api/documents_api.dart';
import 'package:omnicare_mobile/core/network/sse_decoder.dart';

void main() {
  test('accepts a nonterminal SCAN_PENDING event', () {
    const eventId = '83c593a2-e136-43b4-9e5f-a32ece6eb73e';

    const documentId = '05c255eb-7c9f-4873-abd7-49b9b3a31b63';

    final event = DocumentStatusEvent.fromSse(
      SseMessage(
        id: eventId,
        event: 'document-status',
        retry: const Duration(seconds: 5),
        data:
            '{'
            '"event_id":"$eventId",'
            '"document_id":"$documentId",'
            '"status":"SCAN_PENDING",'
            '"occurred_at":"2026-09-02T05:11:29.209327+02:00"'
            '}',
      ),
    );

    expect(event.eventId, eventId);
    expect(event.documentId, documentId);
    expect(event.status, 'SCAN_PENDING');
    expect(event.isTerminal, isFalse);
    expect(event.reconnectDelay, const Duration(seconds: 5));
  });

  test('rejects disagreement between frame and payload IDs', () {
    expect(
      () => DocumentStatusEvent.fromSse(
        SseMessage(
          id: '83c593a2-e136-43b4-9e5f-a32ece6eb73e',
          event: 'document-status',
          data:
              '{'
              '"event_id":"96296041-a13d-4ea1-8ee2-80e60f030f44",'
              '"document_id":"05c255eb-7c9f-4873-abd7-49b9b3a31b63",'
              '"status":"AVAILABLE",'
              '"occurred_at":"2026-09-02T05:11:30+02:00"'
              '}',
        ),
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
