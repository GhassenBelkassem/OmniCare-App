# G-2 · 1b-2 — One error parser, French messages, server text removed from patient screens
_Date: 2026-11-11 · Repo: OmniCare-App (backend read only) · Roadmap: Phase 1b items 2–3 · Appendix: [G2-1b-2-backend-error-codes.md](G2-1b-2-backend-error-codes.md)_
_Testing rule (CTO): automated tests cover logic only; screens are tested by hand (§9)._
_Note: 1a-5 (push type) was moved to Phase 6 and is not planned here._

## 1. Goal card and deliverable status

```
GOAL G-2: Connect the patient Flutter app to the real backend without changing the current UI, with a report at every step.
Deliverables:
  1. A full, detailed roadmap for the patient app, consultation excluded
  2. The patient Flutter app connected to the backend (no UI redesign)
  3. A report for every step (saved in the repo)
  4. Claude Code prompts that enforce design patterns, clean code, bounded complexity/memory, and official docs
Done when: every patient screen reachable from production main.dart shows real data or an honest
"indisponible" state (no fixture, no mock), the release build passes the G-2 gate (§8), and every
step has a report in OmniCare-App/docs/reports/G2/.
```

| # | Deliverable | Status after 1b-2 |
|---|---|---|
| 1 | Roadmap | Done (v1.2). 1a-5 has moved to Phase 6. |
| 2 | App connected | Phase 1a done. Phase 1b: item 6 (French, ARB) and **items 2–3 (error parser, `Result`) are done for the error paths touched here**. |
| 3 | Reports | This file and its appendix |
| 4 | Prompts | Unchanged |

**Result:**
- **One parser:** `ApiFailure.from(error)` reads all five backend error shapes and never throws.
- **French text:** `apiFailureMessage(failure, l10n)` turns a failure into French from `app_fr.arb`.
- **Sinks:** **8 of the 9 places** where server text reached a patient screen now show French. Sink 8 had already been closed by 1a-6.
- **Sink 4 is not done.** Its code is in `lib/features/patient_passport/sharing/**`, which G-1 owns (roadmap §1.2), so I stopped there (R1).
- **`Result<T>`** is introduced and used in `FamilyRepository`.
- **Checks:**
  - `flutter analyze` shows 388 issues, the same lines as the baseline.
  - `flutter test`: **1891 passed, 7 skipped** (+33 new tests).
  - The drift test is green.

## 2. Plan findings (step 1)

### a) Backend error codes a patient screen can receive
The full table (about 150 rows, with HTTP status, shape, backend meaning and file:line) is in the **appendix**. It was built read-only from the backend, and I re-checked two facts by hand. Below is the part this step uses: the shared `ErrorCode` codes in shape 1, and what the app now shows for each.

| Code | HTTP | Shape | Backend meaning | App message |
|---|---|---|---|---|
| `VALIDATION_ERROR` | 400 | 1 | `@Valid` failure; a missing header, type mismatch or malformed body | kind *validation*. Fields: « Vérifiez ce champ. » (no field code is sent, R2) |
| `INVALID_INPUT` | 400 | 1 | Business input check. **The meaning depends on the endpoint** (phone, name, age, blood type, upload…) | kind *validation* (generic) |
| `INVALID_STATE` | 400 | 1 | **Depends on the endpoint** (onboarding step, phone-change step, graduated member…) | kind *validation* (generic). On the security screens: « Cette étape a expiré. Recommencez la vérification. » (existing wording) |
| `CONFLICT` | 409 | 1 | On phone change: a change is already in progress. On documents: an MRS 409/410 (UNCLEAR) | kind *conflict*. On the security screens: « Un changement de numéro est déjà en cours. » |
| `FORBIDDEN` | 403 | 1 / 5 | Role or policy refusal; download not available | kind *forbidden* (generic) |
| `RESOURCE_NOT_FOUND` | 404 | 1 | Profile, family member, device, session or document not found or not owned | kind *notFound* (generic, or the screen's fallback) |
| `UNAUTHORIZED`, `AUTH_SESSION_INVALID`, `AUTH_REFRESH_TOKEN_INVALID` | 401 | 1 / 5 | No token, an invalid or expired session, or a revoked refresh token | kind *unauthorized*: « Votre session a expiré. Reconnectez-vous. » |
| `AUTH_INVALID_CREDENTIALS` | 401 | 1 | Wrong password: at login, or the current password on change/set | **« Les identifiants sont incorrects. »** |
| `AUTH_INVALID_OTP` | 401 | 1 | OTP invalid or expired | Security screens: « Le code est incorrect ou a expiré. » (existing). Elsewhere it goes through the auth mapper. |
| `AUTH_INVALID_TOKEN` | 401 | 1 | Invalid Google token, or an invalid or expired phone-change reversal link | Security screens: « Ce lien est invalide, expiré ou a déjà été utilisé. » (existing) |
| `AUTH_PHONE_ALREADY_USED` | 409 | 1 | Phone already linked to another account | Security screens: existing wording |
| `AUTH_PROVIDER_UNAVAILABLE` | 503 | 1 | SMS provider, Google OAuth or the password breach check is down | Security screens: « Le service SMS est temporairement indisponible. » (existing wording; it is narrower than the meaning, R4) |
| `AUTH_PASSWORD_COMPROMISED` | 400 | 1 | Password found in a breach list | **« Ce mot de passe est compromis. Choisissez-en un autre. »** (the auth screens' wording) |
| `TOO_MANY_REQUESTS` | 429 | 1 / 3 | Feature rate limit (OTP, avatar, SSE, QR). There is no global limiter. | kind *rateLimited*: « Trop de tentatives. Patientez avant de réessayer. » |
| `MRS_UNAVAILABLE` | 503 | 1 **or** 3 | Medical record service down | **« Le dossier médical est temporairement indisponible. Réessayez plus tard. »** |
| `OBJECT_STORAGE_UNAVAILABLE` | 503 | 1 | File storage down (avatar) | **« Le stockage des fichiers est temporairement indisponible… »** |
| `FILE_TOO_LARGE` | 413 | 1 | File over the size limit | **« Ce fichier est trop volumineux. »** |
| `UNSUPPORTED_FILE_TYPE` | 415 | 1 | File type not allowed | **« Ce type de fichier n’est pas accepté. »** |
| `PROFESSIONAL_ACCESS_REQUEST_ALREADY_PENDING` | 409 | 1 | An active request already exists for this e-mail or identifier | **« Une demande est déjà en cours pour cette adresse e-mail ou cet identifiant professionnel. »** |
| `AUTH_MAX_SESSIONS_REACHED` | 409 | **2** | Session limit reached. Unreachable for patients by default: `patient-max-sessions: 0`, which means unlimited (`application.yaml:370`). | kind *conflict* (generic) |
| `INTERNAL_SERVER_ERROR` | 500 | 1 (+`requestId`) | Catch-all | kind *server* |
| `METHOD_NOT_ALLOWED` | 405 | 1 | Wrong method | kind *unknown* (generic) |
| `RESOURCE_ALREADY_EXISTS` | 409 | 1 | Profile already exists | kind *conflict* (generic) |

- **Codes with their own feature enum stay with their feature mapper for now:** M05 `RequestErrorCode` (shape 3), booking `BookingRequestErrorCode` (shape 3), urgent cabinet `CareCapabilityErrorCode` (shape 4), documents `DOCUMENT_UPLOAD_*`, and medical sharing (G-1). They are listed in the appendix. Moving those mappers onto `ApiFailure` is the next step (§8).
- **UNCLEAR, so they get the generic message for their kind:**
  - `AUDIT_CIRCUIT_BROKEN` (503): which patient endpoints can raise it is unknown.
  - `MRS_SINGLETON_SERIES_AMBIGUOUS` (409): whether a patient write can reach it is unknown.
  - `CONFLICT` on `/documents/**`: an MRS 409 **or 410**.
  - `PRESCRIPTION_*` and `CONSULTATION_FINALIZED` on patient reads.
  - `URGENT_CABINET_COMMITMENT_READ_UNAVAILABLE`.
- **Defined but never thrown** (grep finds no use): `AUTH_SESSION_EXPIRED`, `BAD_REQUEST`, `AUTH_ACCOUNT_LOCKED`, `AUTH_ACCOUNT_DISABLED` and 5 others. No message was added for them.

### b) Field validation: what the backend actually sends
- **Shape 1 `fieldErrors`** is an object `{fieldPath: "English sentence"}` (`GlobalExceptionHandler.java:90-104`).
  - The constraint name (`NotBlank`, `Size`…) is **only logged** (`:95-97`).
  - `ErrorResponse.fieldErrorCodes` exists (`ErrorResponse.java:20`), but **no patient path fills it**. Only the doctor-side `ClinicalValidationAdvice` does.
- **The ProblemDetail shapes (3, 4) have no field list:**
  - M05 → `REQUEST_INVALID`;
  - booking and availability → `VALIDATION_FAILED` 422;
  - urgent cabinet → `VALIDATION_FAILED` 400.
- **Consequence:**
  - The app reads `fieldErrorCodes` when present and maps it to required / too long / too short / wrong length / format / out of range / invalid.
  - **With today's backend every flagged field shows « Vérifiez ce champ. »**, which is French and correct, but not specific (R2).

### c) The 9 sinks (P0 §f.3) and where the server text came from
| # | Sink | Source of the text | Done? |
|---|---|---|---|
| 1 | `professional_access_request_screen` | API copied `json['message']` into `ApiException` | ✅ |
| 2 | `account_security_provider` → `device_management_screen` | `_message` fell back to `error.message` | ✅ |
| 3 | `account_security_screen` (2 places) | `error.toString()` = server message | ✅ |
| 4 | `medical_sharing_controller` → `medical_sharing_settings_sheet` | `_ => error.message` (`medical_sharing_controller.dart:184`) | ❌ G-1 path (R1) |
| 5 | `user_provider` → `new_home_screen`, `patient_profile_screen` | `_safeMessage` = `error.message` | ✅ |
| 6 | `family_provider` → `new_home_screen`, `add_family_member_screen` (+ field errors) | `_message` and the `fieldErrors` sentences | ✅ |
| 7 | `patient_profile_screen` form (+ field errors) | `_profileFormFailure` used `error.message` and the `fieldErrors` sentences | ✅ |
| 8 | onboarding `'Failed to save: ${apiErrorMessage(e)}'` | already replaced by `onboardingSaveErrorMessage` in 1a-6 | ✅ (1a-6); now routed through the parser |
| 9 | `new_home_screen` logout `Text(e.toString())` | any exception's text | ✅ |

## 3. Design (as built)
- **`lib/core/network/api_failure.dart`**
  - `ApiFailure {kind, code, statusCode, fieldErrors: Map<path, ApiFieldErrorKind>, requestId, retryAfter}`.
  - `kind` is one of: network, timeout, unauthorized, forbidden, notFound, conflict, validation, rateLimited, server, unknown.
  - **No text field.** `message`, `detail` and `title` are never read.
  - `ApiFailure.from(Object?)` handles a DioException, a legacy `ApiException`, a `TransportFailure`, another `ApiFailure`, or anything else (→ unknown). `fromDio` and `fromResponse` do the rest.
  - The code is read as `errorCode ?? code`.
  - An HTML, text, empty or broken body gives the status's kind with no code.
  - **The status decides the kind** (400/422 → validation, 401, 403, 404/410, 408, 409/412, 429, 5xx); the code only refines the message.
  - `logSummary` returns `kind, status, code, requestId` only.
- **`lib/core/network/api_failure_message.dart`**: `apiFailureMessage(failure, l10n, {fallback})`.
  - **Order:** a code with a clear meaning (§2a) → the always-more-useful kinds (network, timeout, session, rate limit, server) → the screen's own fallback (« Impossible de charger le profil. »…) → the generic message for the kind.
  - Also provides `apiFieldErrorMessage` / `apiFieldErrorMessages` (per field) and `apiFailureMessageOr` (when the failure may be null).
- **`lib/core/result/result.dart`**: `sealed Result<T>` = `Ok(value)` / `Err(ApiFailure)`, plus `guardApiCall`. This follows the Flutter architecture guide's "Result" design pattern (docs.flutter.dev/app-architecture/design-patterns/result), with `Err` instead of `Error` so it cannot shadow `dart:core`.
- **`ApiException` (legacy) stays the type thrown** by `AccountApi`, `FamilyApi`, `FilesApi` and `AccountSecurityApi`, because many callers check `is ApiException` (documents, avatar retry, G-1 sharing).
  - These APIs now build it with `ApiException.fromFailure(ApiFailure.fromDio(e))`.
  - So it carries the parsed `failure`, its `message` is the safe `logSummary`, and its field values are kind names. **No server text is stored in it any more.**
- **How feature mappers reuse it:** a feature mapper calls `ApiFailure.from(error)` and switches on `kind` and `code`, instead of reading the JSON itself.
  - `saveErrorMessage` (1a-2), `onboardingSaveErrorMessage` (1a-6), `securityErrorMessage`, the user and family providers, and the profile form now do this.
  - Not yet migrated (§8): `request_failure`, `scheduled_care_failure`, `patient_clinic_failure`, `doctor_directory_failure`, `urgent_cabinet_*` (`_problemCode`), `documents_api`, `auth_api` / `auth_error_messages`, `TransportFailure`, `auth_interceptor.dart:145` (it reads `code ?? errorCode` only to decide on a session refresh), and G-1's sharing APIs.

## 4. What changed
| File | Change |
|---|---|
| `lib/core/network/api_failure.dart` (new) | Parser and types (§3) |
| `lib/core/network/api_failure_message.dart` (new) | French mapping (§3) |
| `lib/core/result/result.dart` (new) | `Result<T>`, `Ok`, `Err`, `guardApiCall` |
| `lib/core/network/api_exception.dart` | `failure` field and `ApiException.fromFailure` |
| `lib/core/network/save_error_message.dart` | Rebuilt on `ApiFailure` (same 4 outcomes) |
| `lib/core/api/account_api.dart`, `family_api.dart`, `files_api.dart` | `_mapDioException` now calls the parser. The `ApiErrorResponse` parsing is gone from these files. |
| `lib/features/security/account_security_api.dart` | Same |
| `lib/features/auth/data/professional_access_request_api.dart` | Throws `ApiFailure` |
| `lib/repositories/family_repository.dart` | Every method returns `Result<T>` |
| `lib/providers/family_provider.dart` | Unwraps `Result`. Exposes `loadFailure`, `mutationFailure` and `fieldErrors` (kinds); throws the `ApiFailure` to callers as before. |
| `lib/providers/user_provider.dart` | Exposes `loadFailure`, `saveFailure`, `saveFieldErrors` (kinds), `avatarFailure` and `avatarSelectionFailed`. Logs use `logSummary` only. |
| `lib/features/security/account_security_provider.dart` | Stores a parsed failure or a `SecurityLocalException` (Google re-auth, "already in progress"). Exposes `errorMessage`, `phoneErrorMessage` and `historyErrorMessage(l10n)` plus `has…Error`, and `securityErrorMessage(error, l10n)`. |
| Screens | `professional_access_request_screen`; `account_security_screen` (2), `device_management_screen`, `phone_change_screen`, `phone_change_reversal_screen`, `login_history_screen`; `new_home_screen` (profile load, profile and avatar errors, family list, member removal, logout); `add_family_member_screen` (banner and fields); `patient_profile_screen` (form failure and fields); `urgent_cabinet_flow_shell` (`family.loadFailure`); onboarding log uses `logSummary`. |
| `lib/l10n/app_fr.arb` | +42 keys, each with a description: 10 per kind, 7 per field kind, 7 per code, 10 security (moved out of the provider), 8 screen fallbacks (moved out of providers and screens, same text) |
| Tests | New `api_failure_parser_test`, `error_sinks_french_test`. 13 fake `FamilyRepository`s now return `Result`. 2 more widget-test harnesses got the French delegates. The drift test accepts a line-wrapped `OmniLocalizations.of(context)`. |

No layout, style or navigation change. `lib/features/doctor/**`, `lib/features/patient_passport/sharing/**` and the backend are untouched.

## 5. Evidence
- **`test/api_failure_parser_test.dart` (20 tests)**, with recorded bodies that follow the backend records (the English texts are the backend's own):
  - **The five shapes:** shape 1 with and without `fieldErrorCodes`; shape 2; shape 3, with `errorCode` winning over `code`; shape 4; shape 5.
  - **No server text** survives in `toString`, `logSummary`, the legacy message, the field values or the French output.
  - **Garbage never throws:** HTML, text, empty, null, list, number and broken JSON give the status's kind; an unknown status gives unknown with that status; a JSON string body is still read; an empty 404 body; non-string codes; `Retry-After`.
  - **Transport and other inputs:** every Dio type; `from()` on failures, legacy exceptions, transport failures, `StateError` and null.
  - **Messages:** the exact French per kind (all 10), per code (7), per field kind (all 7); endpoint-dependent codes get the generic message; the order of the screen fallback.
  - **`Result`:** `guardApiCall`.
- **`test/error_sinks_french_test.dart` (13 tests)**, with real view models and APIs against a fake server answering with English text:
  - sink 1: the professional API (conflict and validation);
  - sinks 2–3: the security provider (device list 500, wrong current password, phone-change conflict, local reasons);
  - sink 5: the user provider (load 404 uses the profile fallback; a save with field errors gives French field texts; `MRS_UNAVAILABLE`);
  - sink 6: the family provider (list 500; save with field errors; removal refused);
  - sink 8: onboarding and 1a-2 saves;
  - sink 9: logout.
  - Each checks the exact French text and that no server text is present.
- **Drift test** (`l10n_arb_contract_test`): green; every new ARB key is used.
- `flutter analyze`: 388 issues, identical to the baseline.
- `flutter test`: **1891 passed, 7 skipped**. The new tests also pass under `TZ=UTC`.

## 6. Complexity and memory
- Parsing is O(size of the error body), once per failed call.
- `ApiFailure` keeps no body, no headers and no `DioException`; `ApiException.fromFailure` still keeps `cause` for older callers.
- The providers now keep the parsed failure instead of the raw exception, so less memory is held.

## 7. Risks, open questions, things not done
- **R1. Sink 4 (medical sharing) not fixed: I stopped there.**
  - The server text comes from `lib/features/patient_passport/sharing/medical_sharing_controller.dart:184` (`_ => error.message`), and the same pattern is at `direct_patient_authorization_controller.dart:124`. Roadmap §1.2 makes `sharing/**` read-only for us.
  - A sheet-level workaround would mean guessing which of the controller's strings are safe.
  - **Hand to G-1**, or allow me: replace `_ => error.message` with `_ => <generic French>` (or `apiFailureMessage(ApiFailure.from(error), l10n)` once the controller gets `l10n`).
- **R2. Per-field French is generic today.**
  - Patients' validation errors carry no field code (§2b), so every flagged field reads « Vérifiez ce champ. ».
  - **Backend follow-up:** `GlobalExceptionHandler.handleValidationException` already computes `FieldError::getCode()` for the log (`:95-97`). Putting the same map into `ErrorResponse.fieldErrorCodes` (the record already has it) would let the app show « Ce champ est obligatoire. » or « Ce texte est trop long. ».
  - The app side is ready and tested.
- **R3. More server-text sinks found outside the 9** (reported, not changed):
  - `lib/features/home/consultation_detail_screen.dart:217,255` (`Text(e.toString())`, reached from `history_tab.dart:545`; consultation area);
  - `lib/features/emergency/review_confirm_screen.dart:121`, `doctor_arriving_screen.dart:138`, `consultation_qr_screen.dart:87` (`apiErrorMessage`; urgent HOME, out of G-2 per Q4).
  - `api_error_utils.dart` is still used by those screens and by `doctor/**`, so it stays.
- **R4. A few existing wordings are narrower than the backend meaning:**
  - `AUTH_PROVIDER_UNAVAILABLE` on the security screens says "SMS", but it can also mean the Google or password-check service.
  - The global 401 message (« session expirée ») would be wrong for 401 codes that aren't session-related. The security screens override the OTP and link codes, and I added `AUTH_INVALID_CREDENTIALS`.
  - **Copy review welcome.**
- **R5. Visible changes:**
  - Unexpected errors on these screens now show French (generic, or the screen's fallback) instead of English server sentences.
  - The professional form's network message changes from « …Vérifiez votre connexion. » to the shared « Connexion impossible. Vérifiez votre connexion et réessayez. ».
  - The non-API fallback of the profile form loses its trailing « Réessayez. ».
- **R6. Behaviour kept on purpose:** providers still rethrow (the screens catch as before); `FamilyProvider` throws the `ApiFailure`.
- **Not done:** the feature mappers listed in §3, the auth mapper, documents, and adopting `Result` in other repositories (as instructed, untouched ones are not refactored).

## 8. Path to deliver G-2
1. **CTO:**
   - Run §9.
   - Decide R1 (G-1 or me), R2 (the backend `fieldErrorCodes` one-liner, a backend task) and the R4 copy.
   - Commit Phase 1a, 1b-1 and 1b-2.
2. **Phase 1b, rest of item 2:**
   - Move the remaining feature mappers onto `ApiFailure` with their French wording in ARB: M05 `request_failure` (today in English), `scheduled_care_failure`, `patient_clinic_failure` / `doctor_directory_failure` (English), urgent cabinet, documents and auth.
   - Then timeouts and retry, and the Idempotency-Key helper.
   - Adopt `Result` in each repository as it is touched.
3. **Phase 1b, items 1, 4, 5, 7 and 8:** build config, logging, Clock and Tunis time, mock cut-off, guard test.
4. **Translation pass** (1b-1 R3), then Phase 1c and onwards. Phase 6 includes push (ex-1a-5).
5. **Release:** the §8 gate, then the final G-2 report.

## 9. Manual test steps for the CTO
Use staging and a test patient. Change the backend or network state only as described; do not use real patient data.

1. **Family member, server rejection.**
   - Ma famille → add a member → fill the form → turn on **airplane mode** → save.
   - Expected: a French message (« Connexion impossible. Vérifiez votre connexion et réessayez. »), with no English.
   - Send back: one screenshot.
2. **Family member, field rejected by the server.**
   - If you can, send a value the app accepts but the backend refuses (for example a very long first name, more than the backend limit).
   - Expected: under the field, **« Vérifiez ce champ. »**, never an English sentence such as "size must be between…".
   - Send back: a screenshot, or tell me no such value exists.
3. **Profile edit, no network.**
   - Profil → edit personal information → airplane mode → save.
   - Expected: the French banner « Connexion impossible… », with no English.
   - Send back: one screenshot.
4. **Change password, wrong current password.**
   - Sécurité → change the password, enter a **wrong current password**.
   - Expected: **« Les identifiants sont incorrects. »** (before, an English server sentence).
   - Send back: one screenshot.
5. **Devices list, service down (optional).**
   - Stop the backend, or make it return 500, then open Sécurité → Appareils.
   - Expected: « Service momentanément indisponible. Réessayez plus tard. » or « Connexion impossible… ».
   - Send back: one screenshot.
6. **Phone change already in progress.**
   - Start a phone change, then start another from a second device.
   - Expected: « Un changement de numéro est déjà en cours. ».
   - Send back: OK or not OK.
7. **Professional access form, duplicate.** (This screen is in the app, reached from the login screen; it is not a patient screen.)
   - Submit the form twice with the same e-mail.
   - Expected, the second time: « Une demande est déjà en cours pour cette adresse e-mail ou cet identifiant professionnel. ».
   - Send back: one screenshot.
8. **Logout without network.**
   - Turn on airplane mode → profile menu → Se déconnecter.
   - Expected: either a normal logout, or a French snackbar (never an English or technical text).
   - Send back: what you saw.
9. **Medical sharing (not fixed, R1).**
   - Ma Santé → sharing settings with the backend's MRS stopped.
   - Expected **today**: the controller's French message for `MRS_UNAVAILABLE`. **Other** server errors may still show English. That is the known G-1 gap.
   - Send back: what you saw, to pass to G-1.
