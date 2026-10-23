import 'package:image_picker/image_picker.dart';

import '../core/api/files_api.dart';
import '../core/api/documents_api.dart';

class FileRepository {
  FilesApi? _filesApi;
  DocumentsApi? _docsApi;

  FileRepository({FilesApi? filesApi, DocumentsApi? docsApi})
    : _filesApi = filesApi,
      _docsApi = docsApi;

  void useMock() {
    _filesApi = null;
    _docsApi = null;
  }

  void useApi({FilesApi? filesApi, DocumentsApi? docsApi}) {
    if (filesApi != null) _filesApi = filesApi;
    if (docsApi != null) _docsApi = docsApi;
  }

  bool get isMock => _filesApi == null;

  Future<FileUploadResponse?> uploadFile({
    required XFile file,
    required String folder,
  }) async {
    if (_filesApi == null) {
      return FileUploadResponse(
        url: 'https://mock-storage.example.com/${file.name}',
        publicId: 'mock-public-id',
        provider: 'mock',
      );
    }
    return _filesApi!.uploadFile(file: file, folder: folder);
  }

  Future<Map<String, dynamic>> createDocument({
    required String title,
    required String type,
    String? issueDate,
    required String fileUrl,
    String? filePublicId,
    String? fileProvider,
  }) async {
    if (_docsApi == null) {
      return {
        'id': 'doc-${DateTime.now().millisecondsSinceEpoch}',
        'title': title,
        'type': type,
        'fileUrl': fileUrl,
        'status': 'created',
      };
    }
    return _docsApi!.createDocument(
      title: title,
      type: type,
      issueDate: issueDate,
      fileUrl: fileUrl,
      filePublicId: filePublicId,
      fileProvider: fileProvider,
    );
  }
}
