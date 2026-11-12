import '../../l10n/omni_localizations.dart';
import 'api_failure.dart';

/// Maps a failed medical-data save to one of four French messages (G2-1a-2),
/// from the single parser. Never the server's `message`/`detail` text.
String saveErrorMessage(Object error, OmniLocalizations l10n) {
  final failure = ApiFailure.from(error);
  if (_invalidInputCodes.contains(failure.code)) return l10n.saveInvalidInput;
  if (_unavailableCodes.contains(failure.code)) {
    return l10n.saveServiceUnavailable;
  }
  return switch (failure.kind) {
    ApiFailureKind.server => l10n.saveServiceUnavailable,
    ApiFailureKind.network || ApiFailureKind.timeout => l10n.saveNetwork,
    _ => l10n.saveGeneric,
  };
}

const _invalidInputCodes = {'INVALID_INPUT', 'VALIDATION_ERROR'};
const _unavailableCodes = {'MRS_UNAVAILABLE', 'SERVICE_UNAVAILABLE'};
