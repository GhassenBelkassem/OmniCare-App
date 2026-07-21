class DocumentsApi {
  DocumentsApi({Object? dio});

  Future<Map<String, dynamic>> createDocument({
    required String title,
    required String type,
    String? issueDate,
    required String fileUrl,
    String? filePublicId,
    String? fileProvider,
  }) async {
    return {
      'id': 'doc-${DateTime.now().millisecondsSinceEpoch}',
      'title': title,
      'type': type,
      'fileUrl': fileUrl,
    };
  }
}
