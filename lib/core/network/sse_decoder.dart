import 'dart:async';
import 'dart:convert';

class SseMessage {
  const SseMessage({
    this.id,
    required this.event,
    required this.data,
    this.retry,
  });

  final String? id;
  final String event;
  final String data;
  final Duration? retry;
}

/// Incrementally decodes Server-Sent Events without buffering
/// the complete HTTP response.
class SseDecoder extends StreamTransformerBase<List<int>, SseMessage> {
  const SseDecoder({
    this.maximumLineCharacters = 4096,
    this.maximumEventCharacters = 16 * 1024,
  }) : assert(maximumLineCharacters > 0),
       assert(maximumEventCharacters > 0);

  final int maximumLineCharacters;
  final int maximumEventCharacters;

  @override
  Stream<SseMessage> bind(Stream<List<int>> stream) async* {
    String? lastEventId;
    String eventType = 'message';
    Duration? reconnectDelay;

    final dataLines = <String>[];

    var dataCharacters = 0;
    var firstLine = true;

    SseMessage? dispatch() {
      if (dataLines.isEmpty) {
        // A retry-only block changes the reconnection delay
        // but does not represent an application event.
        eventType = 'message';
        return null;
      }

      final message = SseMessage(
        id: lastEventId,
        event: eventType.isEmpty ? 'message' : eventType,
        data: dataLines.join('\n'),
        retry: reconnectDelay,
      );

      dataLines.clear();
      dataCharacters = 0;
      eventType = 'message';

      return message;
    }

    await for (final decodedLine
        in stream.transform(utf8.decoder).transform(const LineSplitter())) {
      final line = firstLine && decodedLine.startsWith('\ufeff')
          ? decodedLine.substring(1)
          : decodedLine;

      firstLine = false;

      if (line.length > maximumLineCharacters) {
        throw const FormatException('SSE field is too large.');
      }

      if (line.isEmpty) {
        final message = dispatch();

        if (message != null) {
          yield message;
        }

        continue;
      }

      // SSE comments are heartbeat messages.
      if (line.startsWith(':')) {
        continue;
      }

      final separator = line.indexOf(':');

      final field = separator < 0 ? line : line.substring(0, separator);

      var value = separator < 0 ? '' : line.substring(separator + 1);

      if (value.startsWith(' ')) {
        value = value.substring(1);
      }

      switch (field) {
        case 'data':
          dataCharacters += value.length + (dataLines.isEmpty ? 0 : 1);

          if (dataCharacters > maximumEventCharacters) {
            throw const FormatException('SSE event is too large.');
          }

          dataLines.add(value);
          break;

        case 'event':
          eventType = value;
          break;

        case 'id':
          if (!value.contains('\u0000')) {
            lastEventId = value;
          }
          break;

        case 'retry':
          final milliseconds = int.tryParse(value);

          if (milliseconds != null && milliseconds >= 0) {
            reconnectDelay = Duration(milliseconds: milliseconds);
          }

          break;
      }
    }

    // An unterminated trailing block is discarded.
  }
}
