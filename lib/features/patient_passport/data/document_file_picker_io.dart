import 'package:file_picker/file_picker.dart';

import 'medical_document_models.dart';

/// The extensions the server accepts (SB3 §4).
const _extensions = ['pdf', 'jpg', 'jpeg', 'png'];

Future<DocumentFileSource?> pickDocumentFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: _extensions,
  );
  final file = result?.files.single;
  final path = file?.path;
  if (file == null || path == null) return null;
  return PathDocumentSource(
    path: path,
    filename: file.name,
    sizeBytes: file.size,
  );
}
