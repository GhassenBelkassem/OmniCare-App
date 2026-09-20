import 'package:flutter_test/flutter_test.dart';

import '../../../lib/core/api/documents_api.dart';
import '../../../lib/core/network/sse_decoder.dart';

void main() {
  test('parses a minimal terminal document event with an opaque UUID id', () {
    const message = SseMessage(
      id: '11111111-1111-4111-8111-111111111111',
      event: 'document-status',
      data: '{'
          '"document_id":"22222222-2222-4222-8222-222222222222",'
          '"status":"AVAILABLE",'
          '"occurred_at":"2026-08-29T12:00:00Z"'
          '}',
    );

    final event = DocumentStatusEvent.fromSse(message);
    expect(event.eventId, message.id);
    expect(event.documentId, '22222222-2222-4222-8222-222222222222');
    expect(event.status, 'AVAILABLE');
    expect(event.isTerminal, isTrue);
  });

  test('rejects a numeric database sequence as a public event id', () {
    const message = SseMessage(
      id: '42',
      event: 'document-status',
      data: '{'
          '"document_id":"22222222-2222-4222-8222-222222222222",'
          '"status":"AVAILABLE",'
          '"occurred_at":"2026-08-29T12:00:00Z"'
          '}',
    );

    expect(
      () => DocumentStatusEvent.fromSse(message),
      throwsFormatException,
    );
  });
}
