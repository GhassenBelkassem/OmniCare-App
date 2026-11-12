import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/api/account_api.dart';
import '../../core/api/documents_api.dart';
import '../../core/network/api_exception.dart';
import 'medical_document_upload_controller.dart';
import '../../l10n/omni_localizations.dart';
import 'medical_document_error_message.dart';

class MedicalDocumentsScreen extends StatefulWidget {
  const MedicalDocumentsScreen({
    super.key,
    this.documentsApi,
    this.uploadController,
    this.accountApi,
    this.initialAccountId,
    this.initialPatientId,
    this.pickDocumentFile,
    this.pollDelay = const Duration(seconds: 2),
    this.maximumPolls = 6,
    this.maximumPollDelay = const Duration(minutes: 1),
    this.maximumAutomaticWatchDuration = const Duration(minutes: 15),
    this.defaultSseReconnectDelay = const Duration(seconds: 5),
    this.maximumSseReconnectDelay = const Duration(seconds: 30),
    this.maximumSseReconnects = 2,
    this.retryJitterRatio = 0.20,
    this.randomDouble,
  }) : assert(maximumPolls >= 0),
       assert(maximumSseReconnects >= 0),
       assert(retryJitterRatio >= 0 && retryJitterRatio <= 0.50);

  final DocumentsApi? documentsApi;
  final MedicalDocumentUploadController? uploadController;
  final AccountApi? accountApi;
  final String? initialAccountId;
  final String? initialPatientId;
  final Future<PlatformFile?> Function()? pickDocumentFile;

  final Duration pollDelay;
  final int maximumPolls;
  final Duration maximumPollDelay;
  final Duration maximumAutomaticWatchDuration;

  final Duration defaultSseReconnectDelay;
  final Duration maximumSseReconnectDelay;
  final int maximumSseReconnects;

  final double retryJitterRatio;
  final double Function()? randomDouble;

  @override
  State<MedicalDocumentsScreen> createState() {
    return _MedicalDocumentsScreenState();
  }
}

class _MedicalDocumentsScreenState extends State<MedicalDocumentsScreen>
    with WidgetsBindingObserver {
  bool _isLoading = false;
  bool _pollInFlight = false;
  bool _appIsActive = true;
  bool _fallbackPollingActive = false;

  late final MedicalDocumentUploadController _uploadController;
  late final bool _ownsUploadController;
  late final DocumentsApi _documentsApi;

  late final AccountApi _accountApi = widget.accountApi ?? AccountApi();

  final math.Random _retryRandom = math.Random.secure();

  String? _patientId;

  List<MedicalDocumentRecord> _documents = const [];

  StreamSubscription<DocumentStatusEvent>? _eventSubscription;

  Timer? _transportTimer;
  Timer? _deadlineTimer;

  int _watchGeneration = 0;
  int _sseConnectionSerial = 0;
  int _sseReconnectCount = 0;
  int _pollCount = 0;

  String? _watchedDocumentId;
  String? _lastEventId;
  DateTime? _watchDeadline;

  late Duration _nextPollDelay;
  late Duration _sseReconnectDelay;

  DocumentUploadOperation? _pendingUpload;
  CancelToken? _uploadCancelToken;
  String? _recoveryOwnerKey;

  final Map<String, DocumentDeleteOperation> _pendingDeletes = {};

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _ownsUploadController = widget.uploadController == null;
    _uploadController =
        widget.uploadController ??
        MedicalDocumentUploadController(
          api: widget.documentsApi ?? DocumentsApi(),
          receiptStore: SecureMedicalDocumentUploadReceiptStore(),
        );
    _documentsApi = _uploadController.api;
    _uploadController.addListener(_handleUploadControllerChanged);

    _nextPollDelay = widget.pollDelay;
    _sseReconnectDelay = widget.defaultSseReconnectDelay;

    final suppliedPatientId = widget.initialPatientId?.trim();

    if (suppliedPatientId != null && suppliedPatientId.isNotEmpty) {
      _patientId = suppliedPatientId;
    }

    unawaited(_loadDocuments());
  }

  @override
  void didUpdateWidget(covariant MedicalDocumentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousOwner = oldWidget.initialPatientId?.trim();
    final nextOwner = widget.initialPatientId?.trim();
    final previousAccount = oldWidget.initialAccountId?.trim();
    final nextAccount = widget.initialAccountId?.trim();
    if (previousOwner == nextOwner && previousAccount == nextAccount) return;

    _uploadCancelToken?.cancel('medical document owner changed');
    if (previousAccount != null && previousAccount.isNotEmpty) {
      unawaited(_uploadController.endAccount(previousAccount));
    }
    _pendingUpload = null;
    _recoveryOwnerKey = null;
    _pendingDeletes.clear();
    _isLoading = false;
    _cancelNetworkTransports(invalidateCallbacks: true);
    _patientId = nextOwner == null || nextOwner.isEmpty ? null : nextOwner;
    _documents = const [];
    unawaited(_loadDocuments());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_appIsActive) {
          _appIsActive = true;
          _resumeAutomaticWatch();
        }
        break;

      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (_appIsActive) {
          _appIsActive = false;
          _pauseAutomaticWatch();
        }
        break;

      case AppLifecycleState.inactive:
        // A file picker or temporary browser focus
        // change can trigger this state. Keep SSE alive.
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _cancelNetworkTransports(invalidateCallbacks: true);

    _deadlineTimer?.cancel();

    _uploadCancelToken?.cancel('medical documents screen disposed');

    _uploadController.removeListener(_handleUploadControllerChanged);
    if (_ownsUploadController) {
      _uploadController.dispose();
    }

    super.dispose();
  }

  String _toBackendDocumentType(String uiType) {
    final value = uiType.trim().toLowerCase();

    if (value == 'prescription') {
      return 'PRESCRIPTION_DOCUMENT';
    }

    if (value == 'lab results') {
      return 'LAB_RESULT';
    }

    if (value == 'scan') {
      return 'IMAGING';
    }

    return 'OTHER_MEDICAL_DOCUMENT';
  }

  String _mimeFor(String filename) {
    final lower = filename.toLowerCase();

    if (lower.endsWith('.pdf')) {
      return 'application/pdf';
    }

    if (lower.endsWith('.png')) {
      return 'image/png';
    }

    return 'image/jpeg';
  }

  Future<PlatformFile?> _pickDocumentFile() async {
    final injectedPicker = widget.pickDocumentFile;

    if (injectedPicker != null) {
      return injectedPicker();
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: kIsWeb,
    );

    return result?.files.single;
  }

  Future<void> _loadDocuments({bool showErrors = true}) async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      var patientId = _patientId;

      if (patientId == null || patientId.isEmpty) {
        final profile = await _accountApi.getPatientProfile();

        patientId = profile.patientId;
      }

      if (patientId == null || patientId.isEmpty) {
        throw const ApiException(
          'Your patient profile is not ready yet.',
          code: 'PROFILE_NOT_READY',
        );
      }

      if (!mounted) {
        return;
      }

      // Store it before listing documents. Listing
      // failure must not disable document upload.
      setState(() {
        _patientId = patientId;
      });

      final page = await _documentsApi.listDocuments(patientId);

      if (!mounted) {
        return;
      }

      setState(() {
        _documents = page.documents;
      });

      final accountId = widget.initialAccountId?.trim();
      final ownerKey = accountId == null || accountId.isEmpty
          ? null
          : '$accountId\u001f$patientId';
      if (ownerKey != null && ownerKey != _recoveryOwnerKey) {
        _recoveryOwnerKey = ownerKey;
        unawaited(
          _uploadController.recoverForOwner(
            accountId: accountId!,
            patientId: patientId,
          ),
        );
      }

      // Do not automatically monitor old pending
      // documents whenever the page opens.
      final watchedDocumentId = _watchedDocumentId;

      if (watchedDocumentId != null) {
        final watched = _findDocument(page.documents, watchedDocumentId);

        if (watched?.isTerminal ?? false) {
          _finishAutomaticWatch(_watchGeneration, watched!);
        }
      }
    } catch (error) {
      if (showErrors) {
        _showError(error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<MedicalDocumentRecord> _uploadDocument({
    required String documentName,
    required String documentType,
    required PlatformFile file,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    if (_isLoading) {
      throw const ApiException(
        'A document operation is already in progress.',
        code: 'OPERATION_IN_PROGRESS',
      );
    }

    final patientId = _patientId;
    final accountId = widget.initialAccountId?.trim();

    if (patientId == null || accountId == null || accountId.isEmpty) {
      throw const ApiException(
        'Your patient profile is not ready yet.',
        code: 'PROFILE_NOT_READY',
      );
    }

    if (file.size <= 0) {
      throw const ApiException(
        'The selected file is empty.',
        code: 'EMPTY_FILE',
      );
    }
    if (file.size > DocumentsApi.maximumUploadBytes) {
      throw const ApiException(
        'The file is larger than the 20 MB limit.',
        code: 'FILE_TOO_LARGE',
      );
    }

    final path = file.path?.trim();
    final filePath = path == null || path.isEmpty ? null : path;
    final bytes = file.bytes;
    if (filePath == null && bytes == null) {
      throw const ApiException(
        'The selected file could not be read.',
        code: 'FILE_READ_FAILED',
      );
    }

    final backendDocumentType = _toBackendDocumentType(documentType);
    final mimeType = _mimeFor(file.name);
    final existingOperation = _pendingUpload;
    if (existingOperation == null ||
        !existingOperation.matches(
          patientId: patientId,
          fileSizeBytes: file.size,
          filePath: filePath,
          bytes: bytes,
          filename: file.name,
          mimeType: mimeType,
          displayName: documentName,
          documentType: backendDocumentType,
        )) {
      _pendingUpload = _documentsApi.startUpload(
        patientId: patientId,
        fileSizeBytes: file.size,
        filePath: filePath,
        bytes: filePath == null ? bytes : null,
        filename: file.name,
        mimeType: mimeType,
        displayName: documentName,
        documentType: backendDocumentType,
        documentDate: DateTime.now(),
      );
    }

    final activeCancelToken = cancelToken ?? CancelToken();
    _uploadCancelToken = activeCancelToken;

    setState(() {
      _isLoading = true;
    });

    try {
      final uploaded = await _uploadController.upload(
        accountId: accountId,
        operation: _pendingUpload!,
        cancelToken: activeCancelToken,
        onSendProgress: onSendProgress,
      );

      if (_patientId != patientId) {
        throw const ApiException(
          'The account changed while the upload was running. Refresh the document list before retrying.',
          code: 'UPLOAD_OWNER_CHANGED',
        );
      }

      _pendingUpload = null;

      if (!mounted) {
        return uploaded;
      }

      setState(() {
        _documents = [
          uploaded,
          ..._documents.where((item) => item.id != uploaded.id),
        ];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Document status: ${uploaded.status}'),
          backgroundColor: const Color(0xFF1FBF9A),
        ),
      );

      if (!uploaded.isTerminal) {
        // SSE is the primary transport.
        // Do not start polling here.
        _startAutomaticWatch(uploaded);
      }

      return uploaded;
    } catch (error) {
      if (_uploadController.phase ==
          MedicalDocumentUploadPhase.terminalFailure) {
        _pendingUpload = null;
      }
      _showError(error);
      rethrow;
    } finally {
      if (identical(_uploadCancelToken, activeCancelToken)) {
        _uploadCancelToken = null;
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _startAutomaticWatch(MedicalDocumentRecord document) {
    _cancelNetworkTransports(invalidateCallbacks: true);

    _deadlineTimer?.cancel();

    _watchedDocumentId = document.id;
    _lastEventId = null;
    _sseReconnectCount = 0;
    _pollCount = 0;
    _pollInFlight = false;
    _fallbackPollingActive = false;

    _nextPollDelay = widget.pollDelay;

    _sseReconnectDelay = widget.defaultSseReconnectDelay;

    _watchDeadline = DateTime.now().add(widget.maximumAutomaticWatchDuration);

    final generation = _watchGeneration;

    _armWatchDeadline(generation);

    if (_appIsActive) {
      _openEventStream(generation);
    }
  }

  void _openEventStream(int generation) {
    final patientId = _patientId;
    final documentId = _watchedDocumentId;

    if (!_watchIsCurrent(generation) ||
        !_appIsActive ||
        patientId == null ||
        documentId == null) {
      return;
    }

    if (_deadlineHasExpired) {
      _expireAutomaticWatch(generation);
      return;
    }

    _transportTimer?.cancel();
    _fallbackPollingActive = false;

    final connectionSerial = ++_sseConnectionSerial;

    try {
      final stream = _documentsApi.watchDocumentStatus(
        patientId: patientId,
        documentId: documentId,
        lastEventId: _lastEventId,
      );

      _eventSubscription = stream.listen(
        (event) {
          _handleDocumentEvent(generation, connectionSerial, event);
        },
        onError: (Object error, StackTrace _) {
          _handleEventStreamEnd(generation, connectionSerial, error: error);
        },
        onDone: () {
          _handleEventStreamEnd(generation, connectionSerial);
        },
        cancelOnError: true,
      );
    } catch (error) {
      _handleEventStreamEnd(generation, connectionSerial, error: error);
    }
  }

  void _handleDocumentEvent(
    int generation,
    int connectionSerial,
    DocumentStatusEvent event,
  ) {
    if (!_watchIsCurrent(generation) ||
        connectionSerial != _sseConnectionSerial ||
        event.documentId != _watchedDocumentId) {
      return;
    }

    final serverDelay = event.reconnectDelay;

    if (serverDelay != null && serverDelay.inMicroseconds > 0) {
      _sseReconnectDelay = _capDuration(
        serverDelay,
        widget.maximumSseReconnectDelay,
      );
    }

    final eventId = event.eventId;

    if (eventId != null) {
      if (eventId == _lastEventId) {
        return;
      }

      _lastEventId = eventId;
    }

    final current = _findDocument(_documents, event.documentId);

    if (current == null) {
      return;
    }

    final currentUpdatedAt = current.updatedAt;

    if (currentUpdatedAt != null &&
        event.occurredAt.isBefore(currentUpdatedAt.toUtc()) &&
        current.status != event.status) {
      // Do not roll the UI backwards with an
      // older event replayed after reconnection.
      return;
    }

    final updated = current.withStatus(event.status, event.occurredAt);

    if (mounted) {
      setState(() {
        _documents = _documents
            .map((item) => item.id == updated.id ? updated : item)
            .toList(growable: false);
      });
    }

    if (event.isTerminal) {
      _finishAutomaticWatch(generation, updated);
    }
  }

  void _handleEventStreamEnd(
    int generation,
    int connectionSerial, {
    Object? error,
  }) {
    if (!_watchIsCurrent(generation) ||
        connectionSerial != _sseConnectionSerial) {
      return;
    }

    // Avoid processing onDone again after onError.
    _sseConnectionSerial++;
    _eventSubscription = null;

    if (!_appIsActive) {
      return;
    }

    if (_deadlineHasExpired) {
      _expireAutomaticWatch(generation);
      return;
    }

    if (_isNonRetryable(error)) {
      if (error != null) {
        _showError(error);
      }

      _stopAutomaticWatch(generation);
      return;
    }

    // Repeating a malformed stream will not help.
    if (_isMalformedStream(error)) {
      _startPollingFallback(generation);
      return;
    }

    if (_sseReconnectCount < widget.maximumSseReconnects) {
      _sseReconnectCount++;

      var delay = _sseReconnectDelay;

      if (error is ApiException && error.retryAfter != null) {
        delay = _longerDuration(delay, error.retryAfter!);
      }

      _transportTimer = Timer(_withJitter(delay), () {
        if (_watchIsCurrent(generation) && _appIsActive) {
          _openEventStream(generation);
        }
      });

      return;
    }

    _startPollingFallback(
      generation,
      retryAfter: error is ApiException ? error.retryAfter : null,
    );
  }

  void _startPollingFallback(int generation, {Duration? retryAfter}) {
    if (!_watchIsCurrent(generation) || !_appIsActive) {
      return;
    }

    final subscription = _eventSubscription;

    if (subscription != null) {
      unawaited(subscription.cancel());
    }

    _eventSubscription = null;
    _sseConnectionSerial++;
    _transportTimer?.cancel();

    if (widget.maximumPolls == 0) {
      _announceAutomaticWatchStopped();
      _stopAutomaticWatch(generation);
      return;
    }

    _fallbackPollingActive = true;
    _pollCount = 0;
    _nextPollDelay = widget.pollDelay;

    final delay = retryAfter == null
        ? _nextPollDelay
        : _longerDuration(_nextPollDelay, retryAfter);

    _scheduleFallbackPoll(generation, delay);
  }

  void _scheduleFallbackPoll(int generation, Duration delay) {
    if (!_watchIsCurrent(generation) ||
        !_appIsActive ||
        !_fallbackPollingActive) {
      return;
    }

    _transportTimer?.cancel();

    _transportTimer = Timer(_withJitter(delay), () {
      unawaited(_pollWatchedDocument(generation));
    });
  }

  Future<void> _pollWatchedDocument(int generation) async {
    if (!_watchIsCurrent(generation) ||
        !_appIsActive ||
        !_fallbackPollingActive ||
        _pollInFlight ||
        _pollCount >= widget.maximumPolls) {
      return;
    }

    final patientId = _patientId;
    final documentId = _watchedDocumentId;

    if (patientId == null || documentId == null) {
      return;
    }

    if (_deadlineHasExpired) {
      _expireAutomaticWatch(generation);
      return;
    }

    _pollInFlight = true;
    _pollCount++;

    try {
      final updated = await _documentsApi.getStatus(
        patientId: patientId,
        documentId: documentId,
      );

      if (!_watchIsCurrent(generation) || !mounted) {
        return;
      }

      setState(() {
        _documents = _documents
            .map((item) => item.id == updated.id ? updated : item)
            .toList(growable: false);
      });

      if (updated.isTerminal) {
        _finishAutomaticWatch(generation, updated);
        return;
      }

      if (_pollCount >= widget.maximumPolls) {
        _announceAutomaticWatchStopped();
        _stopAutomaticWatch(generation);
        return;
      }

      _nextPollDelay = _doubleAndCap(_nextPollDelay, widget.maximumPollDelay);

      _scheduleFallbackPoll(generation, _nextPollDelay);
    } catch (error) {
      if (!_watchIsCurrent(generation)) {
        return;
      }

      if (_isNonRetryable(error)) {
        _showError(error);
        _stopAutomaticWatch(generation);
        return;
      }

      if (_pollCount >= widget.maximumPolls) {
        _announceAutomaticWatchStopped();
        _stopAutomaticWatch(generation);
        return;
      }

      _nextPollDelay = _doubleAndCap(_nextPollDelay, widget.maximumPollDelay);

      var delay = _nextPollDelay;

      if (error is ApiException && error.retryAfter != null) {
        delay = _longerDuration(delay, error.retryAfter!);
      }

      _scheduleFallbackPoll(generation, delay);
    } finally {
      if (_watchIsCurrent(generation)) {
        _pollInFlight = false;
      }
    }
  }

  void _pauseAutomaticWatch() {
    if (_watchedDocumentId == null) {
      return;
    }

    _cancelNetworkTransports(invalidateCallbacks: true);

    _deadlineTimer?.cancel();
  }

  void _resumeAutomaticWatch() {
    if (_watchedDocumentId == null) {
      return;
    }

    final generation = _watchGeneration;

    if (_deadlineHasExpired) {
      _expireAutomaticWatch(generation);
      return;
    }

    _sseReconnectCount = 0;
    _fallbackPollingActive = false;

    _armWatchDeadline(generation);
    _openEventStream(generation);
  }

  void _armWatchDeadline(int generation) {
    _deadlineTimer?.cancel();

    final deadline = _watchDeadline;

    if (deadline == null) {
      return;
    }

    final remaining = deadline.difference(DateTime.now());

    if (remaining <= Duration.zero) {
      _expireAutomaticWatch(generation);
      return;
    }

    _deadlineTimer = Timer(remaining, () {
      _expireAutomaticWatch(generation);
    });
  }

  void _expireAutomaticWatch(int generation) {
    if (!_watchIsCurrent(generation)) {
      return;
    }

    _announceAutomaticWatchStopped();
    _stopAutomaticWatch(generation);
  }

  void _finishAutomaticWatch(int generation, MedicalDocumentRecord document) {
    if (!_watchIsCurrent(generation)) {
      return;
    }

    _stopAutomaticWatch(generation);
    unawaited(_uploadController.acceptAuthoritativeStatus(document));

    if (!mounted) {
      return;
    }

    final color = document.status == 'AVAILABLE'
        ? const Color(0xFF1FBF9A)
        : const Color(0xFFDC2626);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Document status: ${document.status}'),
        backgroundColor: color,
      ),
    );
  }

  void _stopAutomaticWatch(int generation) {
    if (!_watchIsCurrent(generation)) {
      return;
    }

    _cancelNetworkTransports(invalidateCallbacks: true);

    _deadlineTimer?.cancel();
    _deadlineTimer = null;

    _watchedDocumentId = null;
    _lastEventId = null;
    _watchDeadline = null;
    _fallbackPollingActive = false;
    _pollCount = 0;
    _pollInFlight = false;
  }

  void _cancelNetworkTransports({required bool invalidateCallbacks}) {
    if (invalidateCallbacks) {
      _watchGeneration++;
      _sseConnectionSerial++;
    }

    final subscription = _eventSubscription;

    _eventSubscription = null;

    if (subscription != null) {
      unawaited(subscription.cancel());
    }

    _transportTimer?.cancel();
    _transportTimer = null;
    _pollInFlight = false;
  }

  bool _watchIsCurrent(int generation) {
    return mounted &&
        generation == _watchGeneration &&
        _watchedDocumentId != null;
  }

  bool get _deadlineHasExpired {
    final deadline = _watchDeadline;

    return deadline != null && !DateTime.now().isBefore(deadline);
  }

  bool _isNonRetryable(Object? error) {
    if (error is! ApiException) {
      return false;
    }

    return error.statusCode == 401 ||
        error.statusCode == 403 ||
        error.statusCode == 404;
  }

  bool _isMalformedStream(Object? error) {
    return error is ApiException && error.code == 'MALFORMED_RESPONSE';
  }

  MedicalDocumentRecord? _findDocument(
    Iterable<MedicalDocumentRecord> documents,
    String documentId,
  ) {
    for (final document in documents) {
      if (document.id == documentId) {
        return document;
      }
    }

    return null;
  }

  Duration _withJitter(Duration delay) {
    if (widget.retryJitterRatio == 0) {
      return delay;
    }

    final randomValue =
        (widget.randomDouble?.call() ?? _retryRandom.nextDouble())
            .clamp(0.0, 1.0)
            .toDouble();

    final multiplier = 1 + (randomValue * widget.retryJitterRatio);

    return Duration(
      microseconds: math.max(1, (delay.inMicroseconds * multiplier).round()),
    );
  }

  Duration _doubleAndCap(Duration current, Duration maximum) {
    final doubled = current.inMicroseconds > maximum.inMicroseconds ~/ 2
        ? maximum
        : Duration(microseconds: current.inMicroseconds * 2);

    return _capDuration(doubled, maximum);
  }

  Duration _capDuration(Duration value, Duration maximum) {
    return value > maximum ? maximum : value;
  }

  Duration _longerDuration(Duration first, Duration second) {
    return first >= second ? first : second;
  }

  void _announceAutomaticWatchStopped() {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Document processing is taking longer '
          'than expected. Use Refresh to check again.',
        ),
        backgroundColor: Color(0xFF667085),
      ),
    );
  }

  Future<void> _deleteDocument(MedicalDocumentRecord document) async {
    final patientId = _patientId;

    if (patientId == null || _isLoading) {
      return;
    }

    if (_watchedDocumentId == document.id) {
      _stopAutomaticWatch(_watchGeneration);
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final operation = _pendingDeletes.putIfAbsent(
        document.id,
        () => _documentsApi.startDelete(
          patientId: patientId,
          documentId: document.id,
        ),
      );

      await _documentsApi.delete(operation);

      _pendingDeletes.remove(document.id);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      await _loadDocuments(showErrors: false);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }

    // French from the error code only (G2-1b-2c), never the error's text.
    final message = documentErrorMessage(error, OmniLocalizations.of(context));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFDC2626),
      ),
    );
  }

  void _handleUploadControllerChanged() {
    if (!mounted) return;
    final reconciled = _uploadController.reconciledDocuments;
    final document = _uploadController.lastDocument;
    final terminal =
        _uploadController.phase == MedicalDocumentUploadPhase.terminalFailure;
    setState(() {
      if (reconciled != null) {
        _documents = reconciled;
      }
      if (document != null) {
        _documents = [
          document,
          ..._documents.where((item) => item.id != document.id),
        ];
      }
      if (terminal) _pendingUpload = null;
    });
    if (document != null &&
        !document.isTerminal &&
        _uploadController.phase == MedicalDocumentUploadPhase.processing &&
        _watchedDocumentId != document.id) {
      _startAutomaticWatch(document);
    }
  }

  Future<void> _showAddDocumentDialog() async {
    _pendingUpload = null;

    final allowedTypes = [
      'Prescription',
      'Report',
      'Scan',
      'Lab Results',
      'Other',
    ];

    var documentName = '';
    var documentType = 'Prescription';
    PlatformFile? selectedFile;
    var submitting = false;
    double? uploadProgress;
    CancelToken? dialogCancelToken;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final documentTypeItems = allowedTypes
                .map(
                  (type) => DropdownMenuItem<String>(
                    value: type,
                    child: Text(
                      type,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        color: const Color(0xFF1D2939),
                      ),
                    ),
                  ),
                )
                .toList(growable: false);

            return PopScope(
              canPop: !submitting,
              child: AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text(
                  'Add Document',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F6F73),
                  ),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Document Name',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1D2939),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        enabled: !submitting,
                        onChanged: (value) {
                          documentName = value;
                          _pendingUpload = null;
                        },
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          color: const Color(0xFF1D2939),
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g., Blood Test Results',
                          hintStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            color: const Color(0xFF9CA3AF),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF4F5F7),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E7EB),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E7EB),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF1FBF9A),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Document Type',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1D2939),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: documentType,
                        onChanged: submitting
                            ? null
                            : (value) {
                                setDialogState(() {
                                  documentType = value ?? 'Other';
                                  _pendingUpload = null;
                                });
                              },
                        items: documentTypeItems,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF4F5F7),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E7EB),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE5E7EB),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF1FBF9A),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'File',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1D2939),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: submitting
                              ? null
                              : () async {
                                  final file = await _pickDocumentFile();

                                  if (!dialogContext.mounted || file == null) {
                                    return;
                                  }

                                  if (file.size >
                                      DocumentsApi.maximumUploadBytes) {
                                    ScaffoldMessenger.of(
                                      dialogContext,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'The file is larger '
                                          'than the 20 MB limit.',
                                        ),
                                        backgroundColor: Color(0xFFDC2626),
                                      ),
                                    );

                                    return;
                                  }

                                  setDialogState(() {
                                    selectedFile = file;
                                    _pendingUpload = null;
                                  });
                                },
                          icon: const Icon(
                            Icons.attach_file,
                            color: Color(0xFF1FBF9A),
                          ),
                          label: Text(
                            selectedFile?.name ?? 'Choose File',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1FBF9A),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            side: const BorderSide(color: Color(0xFF1FBF9A)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      if (submitting) ...[
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: uploadProgress,
                          color: const Color(0xFF1FBF9A),
                          backgroundColor: const Color(0xFFE5E7EB),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          uploadProgress == null
                              ? 'Preparing upload…'
                              : 'Uploading ${(uploadProgress! * 100).round()}%',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: const Color(0xFF667085),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: submitting
                        ? () => dialogCancelToken?.cancel('cancelled by user')
                        : () => Navigator.pop(dialogContext),
                    child: Text(
                      submitting ? 'Cancel upload' : 'Cancel',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF667085),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            if (documentName.trim().isEmpty) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please enter a '
                                    'document name',
                                  ),
                                  backgroundColor: Color(0xFFDC2626),
                                ),
                              );

                              return;
                            }

                            final file = selectedFile;

                            if (file == null) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text('Please select a file'),
                                  backgroundColor: Color(0xFFDC2626),
                                ),
                              );

                              return;
                            }

                            final cancelToken = CancelToken();
                            dialogCancelToken = cancelToken;
                            setDialogState(() {
                              submitting = true;
                              uploadProgress = null;
                            });

                            try {
                              await _uploadDocument(
                                documentName: documentName.trim(),
                                documentType: documentType,
                                file: file,
                                cancelToken: cancelToken,
                                onSendProgress: (sent, total) {
                                  if (!dialogContext.mounted || total <= 0) {
                                    return;
                                  }
                                  setDialogState(() {
                                    uploadProgress = (sent / total)
                                        .clamp(0, 1)
                                        .toDouble();
                                  });
                                },
                              );

                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext);
                              }
                            } catch (_) {
                              // A safe error has already
                              // been displayed.
                            } finally {
                              if (dialogContext.mounted) {
                                setDialogState(() {
                                  submitting = false;
                                  uploadProgress = null;
                                  dialogCancelToken = null;
                                });
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1FBF9A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Submit',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1D2939)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Medical Profile',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1D2939),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh documents',
            onPressed: _isLoading ? null : _loadDocuments,
            icon: const Icon(Icons.refresh, color: Color(0xFF0F6F73)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1FBF9A),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '3',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Medical Documents',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F6F73),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Step 3 of 3',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: const Color(0xFF667085),
                ),
              ),
              const SizedBox(height: 32),
              if (_documents.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 64,
                        color: const Color(0xFF667085).withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No documents uploaded yet',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF667085),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Upload your medical documents '
                        'for easy access',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _documents.length,
                  separatorBuilder: (context, index) {
                    return const SizedBox(height: 12);
                  },
                  itemBuilder: (context, index) {
                    final document = _documents[index];

                    final displayDate =
                        document.createdAt ??
                        document.updatedAt ??
                        DateTime.now();

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF1FBF9A,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.description,
                              color: Color(0xFF1FBF9A),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  document.documentType,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1D2939),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${document.status} • '
                                  '${DateFormat('MMM dd, yyyy').format(displayDate)}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    color: const Color(0xFF667085),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Delete document',
                            icon: const Icon(Icons.delete_outline, size: 20),
                            color: const Color(0xFFDC2626),
                            onPressed: _isLoading
                                ? null
                                : () => _deleteDocument(document),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _showAddDocumentDialog,
                icon: const Icon(Icons.add, color: Color(0xFF1FBF9A)),
                label: Text(
                  'Add Document',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1FBF9A),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  side: const BorderSide(color: Color(0xFF1FBF9A)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
