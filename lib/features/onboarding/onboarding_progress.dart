import 'dart:convert';

import '../../core/api/account_api.dart';
import '../../core/network/save_error_message.dart';
import '../../l10n/omni_localizations.dart';
import '../../core/models/blood_type.dart';
import '../../core/models/patient_profile.dart';
import '../../providers/user_onboarding_provider.dart';
import 'onboarding_basics_payload.dart';

/// Onboarding UI pages (the 5 dots) and the request each one saves.
abstract final class OnboardingPage {
  /// Identity → `POST /profile/onboarding/step/1`.
  static const int identity = 0;

  /// Blood type, height, weight → `PATCH /profile/passport` (MRS).
  static const int body = 1;

  /// → `POST /profile/onboarding/step/2`.
  static const int allergies = 2;

  /// → `POST /profile/onboarding/step/3`.
  static const int conditions = 3;

  /// → `POST /profile/onboarding/step/4` (completes onboarding).
  static const int medications = 4;
}

/// Server progress: `GET /profile` `onboardingStep` (1–4, the next step the
/// server expects), or [completed].
const int _completedServerStep = 0;

int _serverStepOf({required bool completed, required int step}) =>
    completed ? _completedServerStep : step;

/// Whether server step [step] (1–4) still has to be sent. Same rule as the
/// former single final save: a step is sent while the server has not passed
/// it. Re-sending a passed step is a silent no-op or a 400 on the server.
bool shouldSendOnboardingStep({required int serverStep, required int step}) =>
    serverStep != _completedServerStep && serverStep <= step;

/// The page to open on resume: the first one whose data is not saved yet.
///
/// Server step 2 covers two pages: identity is saved, and the body page is
/// saved once height and weight are stored (they are required on that page).
int onboardingResumePage({
  required bool completed,
  required int serverStep,
  required bool bodyMeasurementsStored,
}) {
  if (completed || serverStep <= 1) return OnboardingPage.identity;
  if (serverStep == 2) {
    return bodyMeasurementsStored
        ? OnboardingPage.allergies
        : OnboardingPage.body;
  }
  if (serverStep == 3) return OnboardingPage.conditions;
  return OnboardingPage.medications;
}

/// Everything the patient entered, as read from the screen.
class OnboardingDraft {
  const OnboardingDraft({
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.gender,
    required this.chosenBloodType,
    required this.heightCm,
    required this.weightKg,
    required this.allergies,
    required this.conditions,
    required this.medications,
    required this.today,
  });

  final String firstName;
  final String lastName;

  /// `yyyy-MM-dd`.
  final String dateOfBirth;
  final String gender;
  final BloodType? chosenBloodType;
  final int? heightCm;
  final double? weightKg;
  final List<AllergyEntry> allergies;
  final List<String> conditions;
  final List<MedicationEntry> medications;

  /// `yyyy-MM-dd`, the medications' start date (as before).
  final String today;
}

/// What the onboarding screen needs on open.
class OnboardingResume {
  const OnboardingResume({
    required this.page,
    required this.profile,
    required this.storedBasics,
  });

  final int page;

  /// Null when `GET /profile` failed.
  final PatientProfile? profile;

  /// Null when `GET /profile/medical-data` failed.
  final StoredMedicalBasics? storedBasics;
}

sealed class OnboardingSaveOutcome {
  const OnboardingSaveOutcome();
}

/// Everything up to the page is saved; move on.
final class OnboardingSaved extends OnboardingSaveOutcome {
  const OnboardingSaved({
    required this.completed,
    this.alreadySavedPageEdited = false,
  });

  /// True once step 4 is saved (or the server says onboarding is complete).
  final bool completed;

  /// The page was already saved and the patient changed it: the change was
  /// not sent (the backend cannot update a passed step). The screen says so.
  final bool alreadySavedPageEdited;
}

/// A save is already running; this tap is ignored.
final class OnboardingSaveIgnored extends OnboardingSaveOutcome {
  const OnboardingSaveIgnored();
}

/// The save failed; stay on the page, keep the typed values.
final class OnboardingSaveFailed extends OnboardingSaveOutcome {
  const OnboardingSaveFailed(this.error);

  final Object error;
}

/// Saves onboarding page by page and knows where the server stands.
///
/// One instance per onboarding screen. Not a ChangeNotifier: the screen owns
/// the UI state and only asks this object to load and to save.
class OnboardingProgressController {
  OnboardingProgressController(this._api);

  final AccountApi _api;

  /// Null until known (read on open, refreshed before a save if needed).
  int? _serverStep;
  StoredBloodType _storedBloodType = const StoredBloodTypeUnavailable();
  int? _savedHeightCm;
  double? _savedWeightKg;
  BloodType? _lastSentBloodType;
  bool _inFlight = false;

  /// Per already-saved page (identity, allergies, conditions): the request
  /// body the page held when it was saved, or when it was first shown as
  /// saved. Used only to tell the patient an edit was not sent.
  final Map<int, String> _savedPageBodies = {};

  bool get isSaving => _inFlight;
  StoredBloodType get storedBloodType => _storedBloodType;

  /// Reads server progress and stored values. Never throws: a failed read
  /// leaves the conservative defaults (identity page, guard unavailable).
  Future<OnboardingResume> load() async {
    PatientProfile? profile;
    StoredMedicalBasics? basics;
    try {
      profile = await _api.getPatientProfile();
      _serverStep = _serverStepOf(
        completed: profile.onboardingCompleted,
        step: profile.onboardingStep,
      );
    } catch (_) {
      profile = null;
    }
    try {
      basics = await _api.getStoredMedicalBasics();
      _storedBloodType = StoredBloodTypeKnown(basics.bloodType);
      _savedHeightCm = basics.heightCm;
      _savedWeightKg = basics.weightKg;
    } catch (_) {
      basics = null;
    }
    final page = profile == null
        ? OnboardingPage.identity
        : onboardingResumePage(
            completed: profile.onboardingCompleted,
            serverStep: profile.onboardingStep,
            bodyMeasurementsStored: basics?.hasBodyMeasurements ?? false,
          );
    return OnboardingResume(page: page, profile: profile, storedBasics: basics);
  }

  /// Records what the already-saved pages show right after resume, so a
  /// later change on one of them is detected. Pages with a recorded value
  /// keep it. Does nothing while the server progress is unknown.
  void rememberShownValues(OnboardingDraft draft) {
    for (final page in _stepPages.keys) {
      if (_isSavedStepPage(page)) {
        _savedPageBodies.putIfAbsent(page, () => _stepBodyKey(page, draft));
      }
    }
  }

  /// Saves every unsaved page from the first one up to [page], in order,
  /// each request at most once. A second call while one runs is ignored.
  Future<OnboardingSaveOutcome> saveThrough(
    int page,
    OnboardingDraft draft,
  ) async {
    if (_inFlight) return const OnboardingSaveIgnored();
    _inFlight = true;
    try {
      final known = _serverStep;
      final serverStep = known ?? await _readServerStep();
      _serverStep = serverStep;
      final edited = _isEditedSavedPage(page, draft);
      for (var current = 0; current <= page; current++) {
        await _savePage(current, draft);
      }
      return OnboardingSaved(
        completed: _serverStep == _completedServerStep,
        alreadySavedPageEdited: edited,
      );
    } catch (error) {
      return OnboardingSaveFailed(error);
    } finally {
      _inFlight = false;
    }
  }

  Future<int> _readServerStep() async {
    final profile = await _api.getPatientProfile();
    return _serverStepOf(
      completed: profile.onboardingCompleted,
      step: profile.onboardingStep,
    );
  }

  Future<void> _savePage(int page, OnboardingDraft draft) async {
    switch (page) {
      case OnboardingPage.identity:
        await _sendStep(1, _identityBody(draft), page: OnboardingPage.identity);
      case OnboardingPage.body:
        await _saveBody(draft);
      case OnboardingPage.allergies:
        await _sendStep(
          2,
          onboardingStep2Body(draft.allergies),
          page: OnboardingPage.allergies,
        );
      case OnboardingPage.conditions:
        await _sendStep(
          3,
          onboardingStep3Body(draft.conditions),
          page: OnboardingPage.conditions,
        );
      case OnboardingPage.medications:
        await _sendStep(
          4,
          onboardingStep4Body(draft.medications, startDate: draft.today),
        );
    }
  }

  /// Pages saved by `POST /profile/onboarding/step/{n}` that the patient can
  /// go back to (medications completes onboarding and closes the screen).
  static const Map<int, int> _stepPages = {
    OnboardingPage.identity: 1,
    OnboardingPage.allergies: 2,
    OnboardingPage.conditions: 3,
  };

  bool _isSavedStepPage(int page) {
    final step = _stepPages[page];
    final serverStep = _serverStep;
    return step != null &&
        serverStep != null &&
        !shouldSendOnboardingStep(serverStep: serverStep, step: step);
  }

  bool _isEditedSavedPage(int page, OnboardingDraft draft) {
    if (!_isSavedStepPage(page)) return false;
    final saved = _savedPageBodies[page];
    return saved != null && saved != _stepBodyKey(page, draft);
  }

  /// The page's request body as a comparable string (same builder, so the
  /// same key order). Unknown pages give an empty key.
  static String _stepBodyKey(int page, OnboardingDraft draft) =>
      jsonEncode(switch (page) {
        OnboardingPage.identity => _identityBody(draft),
        OnboardingPage.allergies => onboardingStep2Body(draft.allergies),
        OnboardingPage.conditions => onboardingStep3Body(draft.conditions),
        _ => const <String, dynamic>{},
      });

  static Map<String, dynamic> _identityBody(OnboardingDraft draft) =>
      onboardingStep1Body(
        firstName: draft.firstName,
        lastName: draft.lastName,
        dateOfBirth: draft.dateOfBirth,
        gender: draft.gender,
      );

  /// Sends step [step] if the server has not passed it. For a page the
  /// patient can go back to ([page]), records the body as the saved value:
  /// the sent body, or the first one seen when the step was already passed.
  Future<void> _sendStep(
    int step,
    Map<String, dynamic> body, {
    int? page,
  }) async {
    final serverStep = _serverStep;
    if (serverStep == null) return;
    if (!shouldSendOnboardingStep(serverStep: serverStep, step: step)) {
      if (page != null) {
        _savedPageBodies.putIfAbsent(page, () => jsonEncode(body));
      }
      return;
    }
    final response = await _api.saveOnboardingStep(step, body);
    if (page != null) _savedPageBodies[page] = jsonEncode(body);
    _serverStep = _serverStepOf(
      completed: response.onboardingCompleted,
      step: response.nextStep,
    );
  }

  /// `PATCH /profile/passport`, only for what differs from the server, with
  /// the 1a-2b guard (« Je ne sais pas » never erases a stored blood type).
  Future<void> _saveBody(OnboardingDraft draft) async {
    if (_serverStep == _completedServerStep) return;
    final candidate = bloodTypeToSend(
      chosen: draft.chosenBloodType,
      stored: _storedBloodType,
    );
    final bloodType = candidate == _lastSentBloodType ? null : candidate;
    final measurementsChanged =
        draft.heightCm != _savedHeightCm || draft.weightKg != _savedWeightKg;
    if (bloodType == null && !measurementsChanged) return;
    await _api.patchMedicalPassport(
      bloodType: bloodType,
      heightCm: measurementsChanged ? draft.heightCm : null,
      weightKg: measurementsChanged ? draft.weightKg : null,
    );
    if (bloodType != null) {
      _lastSentBloodType = bloodType;
      _storedBloodType = StoredBloodTypeKnown(
        bloodType == BloodType.unknown ? null : bloodType,
      );
    }
    if (measurementsChanged) {
      _savedHeightCm = draft.heightCm;
      _savedWeightKg = draft.weightKg;
    }
  }
}

/// French message for a failed onboarding save. Invalid input keeps its own
/// message; every other failure asks to check the connection and retry.
/// Never server text.
String onboardingSaveErrorMessage(Object error, OmniLocalizations l10n) {
  final message = saveErrorMessage(error, l10n);
  return message == l10n.saveInvalidInput ? message : l10n.onboardingSaveFailed;
}
