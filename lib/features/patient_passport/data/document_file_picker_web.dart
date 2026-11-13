import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import 'medical_document_models.dart';

/// The types the server accepts (SB3 §4).
const _accept = '.pdf,.jpg,.jpeg,.png,application/pdf,image/jpeg,image/png';

/// One slice read at a time (the upload stream).
const _sliceBytes = 256 * 1024;

Future<DocumentFileSource?> pickDocumentFile() {
  final completer = Completer<DocumentFileSource?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = _accept;
  input.addEventListener(
    'change',
    ((web.Event _) {
      final file = input.files?.item(0);
      if (completer.isCompleted) return;
      completer.complete(
        file == null
            ? null
            : StreamDocumentSource(
                filename: file.name,
                sizeBytes: file.size,
                open: () => _slices(file),
              ),
      );
    }).toJS,
  );
  input.addEventListener(
    'cancel',
    ((web.Event _) {
      if (!completer.isCompleted) completer.complete(null);
    }).toJS,
  );
  input.click();
  return completer.future;
}

/// A fresh stream of the file on each call, one slice in memory at a time.
Stream<List<int>> _slices(web.File file) async* {
  for (var start = 0; start < file.size; start += _sliceBytes) {
    final end = math.min(start + _sliceBytes, file.size);
    final buffer = await file.slice(start, end).arrayBuffer().toDart;
    yield buffer.toDart.asUint8List();
  }
}
