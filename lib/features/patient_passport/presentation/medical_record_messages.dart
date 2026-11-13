import '../../../core/network/api_failure.dart';
import '../../../core/network/api_failure_message.dart';
import '../../../l10n/omni_localizations.dart';
import '../data/medical_record_write_models.dart';

/// French texts for the « Dossier médical » saves and documents (G2.1-A1),
/// from the error code and the field path only. The server's text is never
/// shown; anything not listed here falls back to the shared messages
/// ([apiFailureMessage], [apiFieldErrorMessage]).

/// The message of a failed save, upload, delete or page fetch.
String recordFailureMessage(
  ApiFailure failure,
  OmniLocalizations l10n, {
  String? fallback,
}) => switch (failure.code) {
  'ITEM_LOCKED' => l10n.recordCodeItemLocked,
  'BLOOD_TYPE_LOCKED' => l10n.recordCodeBloodTypeLocked,
  'RECORD_VERSION_CONFLICT' => l10n.recordCodeVersionConflict,
  'IDEMPOTENCY_IN_PROGRESS' => l10n.recordCodeSaveInProgress,
  'DOCUMENT_NOT_READY' => l10n.recordCodeDocumentNotReady,
  'TOO_MANY_REQUESTS' => l10n.recordCodeTooManyRequests,
  _ => apiFailureMessage(failure, l10n, fallback: fallback),
};

/// Text fields: limits are counted in characters; INVALID means a control or
/// direction character.
const _textFields = {'label', 'name', 'title', 'dosageText'};
const _dateFields = {'startedOn', 'documentDate'};

/// The message of one rejected field. [field] is the API path from
/// `fieldErrorCodes` (`items[2].label`, `items[0].duration.value`, `value`…).
String recordFieldMessage(
  String field,
  ApiFieldErrorKind kind,
  OmniLocalizations l10n,
) {
  final path = field.replaceAll(RegExp(r'\[\d+\]'), '');
  final leaf = path.substring(path.lastIndexOf('.') + 1);
  final specific = switch (kind) {
    ApiFieldErrorKind.required => l10n.fieldErrorRequired,
    ApiFieldErrorKind.duplicate => l10n.fieldErrorDuplicate,
    ApiFieldErrorKind.tooLong => switch (leaf) {
      'label' || 'name' || 'title' => l10n.recordFieldTooLong160,
      'dosageText' => l10n.recordFieldTooLong80,
      'items' => l10n.recordFieldTooManyItems,
      'file' => l10n.recordFieldFileTooLarge,
      _ => null,
    },
    ApiFieldErrorKind.invalid =>
      _textFields.contains(leaf) ? l10n.recordFieldForbiddenCharacters : null,
    ApiFieldErrorKind.invalidFormat => switch (path) {
      'value' => l10n.recordFieldBloodTypeInvalid,
      'file' => l10n.recordFieldFileFormat,
      _ when _dateFields.contains(leaf) => l10n.recordFieldDateInvalid,
      _ => null,
    },
    ApiFieldErrorKind.outOfRange => switch (path) {
      'heightCm' => l10n.recordFieldHeightRange,
      'weightKg' => l10n.recordFieldWeightRange,
      _ when leaf == 'timesPerDay' => l10n.recordFieldTimesPerDayRange,
      _ when path.endsWith('duration.value') => l10n.recordFieldDurationRange,
      _ when _dateFields.contains(leaf) => l10n.recordFieldDateInFuture,
      _ => null,
    },
    ApiFieldErrorKind.tooShort || ApiFieldErrorKind.invalidLength => null,
  };
  return specific ?? apiFieldErrorMessage(kind, l10n);
}

/// Field path → French text, for a form that marks each field.
Map<String, String> recordFieldMessages(
  Map<String, ApiFieldErrorKind> fieldErrors,
  OmniLocalizations l10n,
) => {
  for (final entry in fieldErrors.entries)
    entry.key: recordFieldMessage(entry.key, entry.value, l10n),
};

/// The text of a save warning (shown after the save; it never blocks it).
/// `null` for a warning the app does not know.
String? recordWarningMessage(RecordWarning warning, OmniLocalizations l10n) =>
    switch (warning) {
      RecordWarning.heightUnusual ||
      RecordWarning.weightUnusual => l10n.recordWarningUnusualValue,
      RecordWarning.unknown => null,
    };
