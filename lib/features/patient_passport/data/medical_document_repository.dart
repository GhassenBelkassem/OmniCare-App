import 'package:dio/dio.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/result/result.dart';
import 'medical_document_api.dart';
import 'medical_document_models.dart';
import 'medical_record_models.dart';
import 'medical_record_write_models.dart';

/// The patient's documents, for themself or a family member (G2-FT-2,
/// G2.1-SB3). Every call returns a [Result]; nothing is logged here.
///
/// - Lists are one page at a time ([pageSize], cursor from the previous page).
/// - An upload is refused **before any request** when the file is over
///   [maxFileBytes] or is not a PDF, JPG or PNG, with the same field code the
///   server would give (`file`: TOO_LONG / INVALID_FORMAT).
/// - Upload and delete take their Idempotency-Key from a [SaveAttempt].
/// - Pages are fetched one at a time, never the whole document. An expired
///   view session (410) is replaced once, silently.
class MedicalDocumentRepository {
  const MedicalDocumentRepository(this._api);

  static const pageSize = 20;

  /// The server and MRS limit: 15 MiB.
  static const maxFileBytes = 15 * 1024 * 1024;

  /// Extension → the content type sent for the file part.
  static const contentTypes = {
    'pdf': 'application/pdf',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
  };

  static const viewSessionExpiredCode = 'VIEW_SESSION_EXPIRED';

  final MedicalDocumentApiContract _api;

  Future<Result<MedicalDocumentPage>> documents(
    RecordSubject subject, {
    String? cursor,
    CancelToken? cancelToken,
  }) => guardApiCall(() async {
    final body = await _api.list(
      subject,
      size: pageSize,
      cursor: cursor,
      cancelToken: cancelToken,
    );
    return MedicalDocumentPage.fromJson(_object(body));
  });

  /// One document's status, for polling while it is processed.
  Future<Result<MedicalDocument>> status(
    RecordSubject subject,
    String documentId, {
    CancelToken? cancelToken,
  }) => guardApiCall(() async {
    final body = await _api.status(
      subject,
      documentId,
      cancelToken: cancelToken,
    );
    return MedicalDocument.fromJson(_object(body));
  });

  Future<Result<UploadedDocument>> upload({
    required RecordSubject subject,
    required DocumentFileSource source,
    required DocumentUploadForm form,
    required SaveAttempt attempt,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    final refused = fileRefusal(source);
    if (refused != null) return Err(refused);
    final key = attempt.keyFor(
      'upload|${subject.queryValue}|${source.filename}|${source.sizeBytes}|'
      '${form.title}|${form.type.serverValue}|${form.documentDate}',
    );
    final result = await guardApiCall(() async {
      final body = await _api.upload(
        subject,
        source: source,
        contentType: contentTypeOf(source.filename)!,
        form: form,
        idempotencyKey: key,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
      );
      final json = _object(body);
      final id = json['documentId'];
      if (id is! String || id.isEmpty) {
        throw const FormatException('documentId is missing');
      }
      return UploadedDocument(
        documentId: id,
        status: MedicalDocumentStatus.fromServer(json['status']),
      );
    });
    _settle(attempt, result);
    return result;
  }

  Future<Result<void>> delete({
    required RecordSubject subject,
    required String documentId,
    required SaveAttempt attempt,
    CancelToken? cancelToken,
  }) async {
    final key = attempt.keyFor('delete|${subject.queryValue}|$documentId');
    final result = await guardApiCall(
      () => _api.delete(
        subject,
        documentId,
        idempotencyKey: key,
        cancelToken: cancelToken,
      ),
    );
    _settle(attempt, result);
    return result;
  }

  Future<Result<DocumentViewSession>> openViewSession(
    RecordSubject subject,
    String documentId, {
    CancelToken? cancelToken,
  }) => guardApiCall(() async {
    final body = await _api.openViewSession(
      subject,
      documentId,
      cancelToken: cancelToken,
    );
    return DocumentViewSession.fromJson(_object(body));
  });

  /// Page [pageNumber] (1..`pageCount`) of [session]. When the session has
  /// expired, one new session is opened and the page asked again; a second
  /// expiry is returned as a failure (no loop).
  Future<Result<FetchedDocumentPage>> fetchPage({
    required RecordSubject subject,
    required String documentId,
    required DocumentViewSession session,
    required int pageNumber,
    CancelToken? cancelToken,
  }) async {
    final first = await _page(
      subject,
      documentId,
      session,
      pageNumber,
      cancelToken,
    );
    if (first is! Err<FetchedDocumentPage> || !_expired(first.failure)) {
      return first;
    }
    final reopened = await openViewSession(
      subject,
      documentId,
      cancelToken: cancelToken,
    );
    switch (reopened) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final renewed):
        if (pageNumber > renewed.pageCount) {
          return const Err(ApiFailure(kind: ApiFailureKind.notFound));
        }
        return _page(subject, documentId, renewed, pageNumber, cancelToken);
    }
  }

  Future<Result<FetchedDocumentPage>> _page(
    RecordSubject subject,
    String documentId,
    DocumentViewSession session,
    int pageNumber,
    CancelToken? cancelToken,
  ) => guardApiCall(() async {
    final png = await _api.page(
      subject,
      documentId,
      session.viewSessionId,
      pageNumber,
      cancelToken: cancelToken,
    );
    return FetchedDocumentPage(
      session: session,
      page: DocumentPageImage(pageNumber: pageNumber, png: png),
    );
  });

  /// The local refusal of a file, in the server's terms; `null` when the
  /// file may be sent.
  static ApiFailure? fileRefusal(DocumentFileSource source) {
    final ApiFieldErrorKind? kind;
    if (source.sizeBytes <= 0) {
      kind = ApiFieldErrorKind.required;
    } else if (source.sizeBytes > maxFileBytes) {
      kind = ApiFieldErrorKind.tooLong;
    } else if (contentTypeOf(source.filename) == null) {
      kind = ApiFieldErrorKind.invalidFormat;
    } else {
      kind = null;
    }
    return kind == null
        ? null
        : ApiFailure(
            kind: ApiFailureKind.validation,
            code: 'VALIDATION_ERROR',
            fieldErrors: {'file': kind},
          );
  }

  /// `application/pdf`, `image/jpeg` or `image/png` from the extension (any
  /// case); `null` for any other file.
  static String? contentTypeOf(String filename) {
    final dot = filename.lastIndexOf('.');
    if (dot < 0 || dot == filename.length - 1) return null;
    return contentTypes[filename.substring(dot + 1).toLowerCase()];
  }

  static bool _expired(ApiFailure failure) =>
      failure.code == viewSessionExpiredCode || failure.statusCode == 410;

  /// Success drops the key; a key used for other content is dropped too.
  static void _settle<T>(SaveAttempt attempt, Result<T> result) {
    switch (result) {
      case Ok():
        attempt.reset();
      case Err(:final failure):
        if (failure.code == 'IDEMPOTENCY_CONFLICT') attempt.reset();
    }
  }

  static Map<String, Object?> _object(Object? body) {
    if (body is Map<String, Object?>) return body;
    throw const FormatException('The response is not a JSON object');
  }
}
