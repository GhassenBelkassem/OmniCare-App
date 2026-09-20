import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/network/sse_decoder.dart';

void main() {
  test('decodes chunked SSE and preserves a retry-only hint', () async {
    const wire =
        'retry: 5000\r\n'
        '\r\n'
        ': keep-alive\r\n'
        '\r\n'
        'id: 83c593a2-e136-43b4-9e5f-a32ece6eb73e\r\n'
        'event: document-status\r\n'
        'data: {"document_id":"05c255eb-7c9f-4873-abd7-49b9b3a31b63",\r\n'
        'data: "status":"SCAN_PENDING"}\r\n'
        '\r\n';

    final bytes = utf8.encode(wire);

    final chunks = <List<int>>[
      bytes.sublist(0, 7),
      bytes.sublist(7, 31),
      bytes.sublist(31, 83),
      bytes.sublist(83),
    ];

    final messages = await Stream<List<int>>.fromIterable(
      chunks,
    ).transform(const SseDecoder()).toList();

    expect(messages, hasLength(1));
    expect(messages.single.event, 'document-status');
    expect(messages.single.id, '83c593a2-e136-43b4-9e5f-a32ece6eb73e');
    expect(messages.single.retry, const Duration(seconds: 5));
    expect(
      messages.single.data,
      '{"document_id":"05c255eb-7c9f-4873-abd7-49b9b3a31b63",\n'
      '"status":"SCAN_PENDING"}',
    );
  });

  test('rejects an event exceeding the size limit', () async {
    final stream = Stream<List<int>>.value(utf8.encode('data: 12345\n\n'));

    expect(
      stream.transform(const SseDecoder(maximumEventCharacters: 4)).toList(),
      throwsA(isA<FormatException>()),
    );
  });
}
