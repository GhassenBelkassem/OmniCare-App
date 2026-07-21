class FileUploadResponse {
  final String url;
  final String publicId;
  final String provider;

  FileUploadResponse({
    required this.url,
    required this.publicId,
    required this.provider,
  });
}

class FilesApi {
  FilesApi({Object? dio});

  Future<FileUploadResponse> uploadFile({
    required Object file,
    required String folder,
  }) async {
    return FileUploadResponse(
      url: 'https://mock.cloudinary.com/uploads/file.jpg',
      publicId: 'uploads/file',
      provider: 'mock',
    );
  }
}
