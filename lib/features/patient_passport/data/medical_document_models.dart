import 'package:flutter/foundation.dart';

/// The patient's documents in the « Dossier médical » (G2-FT-2 list/status,
/// G2.1-SB3 upload, delete and view). Immutable; no `dynamic`; unknown server
/// values read as `unknown`. A missing id or date throws a [FormatException]
/// (nothing partial is shown). No title or file name ever reaches `toString`.

/// The document kinds the server accepts (SB3 §3c).
enum MedicalDocumentType {
  labResult('LAB_RESULT'),
  imaging('IMAGING'),
  prescription('PRESCRIPTION_DOCUMENT'),
  referral('REFERRAL'),
  dischargeSummary('DISCHARGE_SUMMARY'),
  vaccination('VACCINATION'),
  other('OTHER_MEDICAL_DOCUMENT'),

  /// Read only: a value the app does not know. Never sent.
  unknown('');

  const MedicalDocumentType(this.serverValue);

  final String serverValue;

  static MedicalDocumentType fromServer(Object? value) => values.firstWhere(
    (type) => type != unknown && type.serverValue == value,
    orElse: () => unknown,
  );
}

/// Processing status. Poll the status route while [isProcessing].
enum MedicalDocumentStatus {
  uploadInitiated,
  scanPending,
  available,
  scanFailed,
  unknown;

  static MedicalDocumentStatus fromServer(Object? value) => switch (value) {
    'UPLOAD_INITIATED' => uploadInitiated,
    'SCAN_PENDING' => scanPending,
    'AVAILABLE' => available,
    'SCAN_FAILED' => scanFailed,
    _ => unknown,
  };

  bool get isProcessing => this == uploadInitiated || this == scanPending;
}

/// One document of the list, or the answer of the status route.
@immutable
class MedicalDocument {
  const MedicalDocument({
    required this.documentId,
    required this.type,
    required this.status,
    required this.createdAt,
    this.title,
    this.contentType,
    this.sizeBytes,
    this.pageCount,
  });

  final String documentId;
  final MedicalDocumentType type;
  final MedicalDocumentStatus status;

  /// UTC instant; displayed in Africa/Tunis.
  final DateTime createdAt;

  /// The title the patient typed (else the file name), as the server holds it.
  final String? title;
  final String? contentType;
  final int? sizeBytes;
  final int? pageCount;

  factory MedicalDocument.fromJson(Map<String, Object?> json) {
    final id = json['documentId'];
    if (id is! String || id.isEmpty) {
      throw const FormatException('documentId is missing');
    }
    final created = json['createdAt'];
    final createdAt = created is String ? DateTime.tryParse(created) : null;
    if (createdAt == null) throw const FormatException('createdAt is missing');
    return MedicalDocument(
      documentId: id,
      type: MedicalDocumentType.fromServer(json['documentType']),
      status: MedicalDocumentStatus.fromServer(json['status']),
      createdAt: createdAt.toUtc(),
      title: _text(json['title']),
      contentType: _text(json['contentType']),
      sizeBytes: _int(json['sizeBytes']),
      pageCount: _int(json['pageCount']),
    );
  }

  @override
  String toString() =>
      'MedicalDocument(type: ${type.name}, status: ${status.name})';
}

/// One page of the documents list (newest first, at most 50).
@immutable
class MedicalDocumentPage {
  const MedicalDocumentPage({required this.items, this.nextCursor});

  final List<MedicalDocument> items;

  /// Pass back to get the next page; `null` on the last page.
  final String? nextCursor;

  factory MedicalDocumentPage.fromJson(Map<String, Object?> json) {
    final items = json['items'];
    if (items is! List) throw const FormatException('items is not a list');
    return MedicalDocumentPage(
      items: List.unmodifiable(
        items.map((item) {
          if (item is! Map<String, Object?>) {
            throw const FormatException('item is not an object');
          }
          return MedicalDocument.fromJson(item);
        }),
      ),
      nextCursor: _text(json['nextCursor']),
    );
  }
}

/// Where the file to upload is read from. Both are streamed in chunks; the
/// file is never loaded whole into app state.
@immutable
sealed class DocumentFileSource {
  const DocumentFileSource({required this.filename, required this.sizeBytes});

  /// The picked file's name; its extension decides the content type sent.
  final String filename;

  /// The size the picker reported; checked before anything is sent.
  final int sizeBytes;

  @override
  String toString() => 'DocumentFileSource(sizeBytes: $sizeBytes)';
}

/// A file on disk (Android, iOS, desktop): Dio reads it in chunks.
final class PathDocumentSource extends DocumentFileSource {
  const PathDocumentSource({
    required this.path,
    required super.filename,
    required super.sizeBytes,
  });

  final String path;
}

/// A file read through a stream (web: `XFile.openRead`). [open] must give a
/// fresh stream on each call: the upload may be sent again after a session
/// refresh.
final class StreamDocumentSource extends DocumentFileSource {
  const StreamDocumentSource({
    required this.open,
    required super.filename,
    required super.sizeBytes,
  });

  final Stream<List<int>> Function() open;
}

/// The form fields of an upload (SB3 §4). The server checks them (title 1–160
/// characters, date not in the future in Africa/Tunis).
@immutable
class DocumentUploadForm {
  const DocumentUploadForm({
    required this.title,
    required this.type,
    this.documentDate,
  });

  final String title;
  final MedicalDocumentType type;

  /// A calendar date; only year, month and day are sent.
  final DateTime? documentDate;

  @override
  String toString() => 'DocumentUploadForm(type: ${type.name})';
}

/// The answer to an upload: poll the status route with [documentId].
@immutable
class UploadedDocument {
  const UploadedDocument({required this.documentId, required this.status});

  final String documentId;
  final MedicalDocumentStatus status;
}

/// An open view session. The server keeps the access token; the app holds
/// only the id. Pages 1..[pageCount] can be fetched until [expiresAt].
@immutable
class DocumentViewSession {
  const DocumentViewSession({
    required this.viewSessionId,
    required this.pageCount,
    required this.expiresAt,
  });

  final String viewSessionId;
  final int pageCount;
  final DateTime expiresAt;

  factory DocumentViewSession.fromJson(Map<String, Object?> json) {
    final id = json['viewSessionId'];
    final pages = json['pageCount'];
    final expires = json['expiresAt'];
    final expiresAt = expires is String ? DateTime.tryParse(expires) : null;
    if (id is! String || id.isEmpty || pages is! int || pages < 1) {
      throw const FormatException('view session is incomplete');
    }
    if (expiresAt == null) throw const FormatException('expiresAt is missing');
    return DocumentViewSession(
      viewSessionId: id,
      pageCount: pages,
      expiresAt: expiresAt.toUtc(),
    );
  }
}

/// One watermarked page as PNG bytes. Keep only the pages on screen.
@immutable
class DocumentPageImage {
  const DocumentPageImage({required this.pageNumber, required this.png});

  final int pageNumber;
  final Uint8List png;

  @override
  String toString() =>
      'DocumentPageImage(page: $pageNumber, bytes: ${png.length})';
}

/// A fetched page and the session it came from: a new session when the
/// previous one had expired (the caller keeps using this one).
@immutable
class FetchedDocumentPage {
  const FetchedDocumentPage({required this.session, required this.page});

  final DocumentViewSession session;
  final DocumentPageImage page;
}

String? _text(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

int? _int(Object? value) => value is int && value >= 0 ? value : null;
