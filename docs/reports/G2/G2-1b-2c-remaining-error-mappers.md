# G-2 · 1b-2c — the remaining patient error mappers on `ApiFailure`, in French

_Date: 2026-11-11 · Repo: **OmniCare-App** (uncommitted, on top of 1a, 1b-1 and 1b-2) · Backend contract used: 1b-2b `fieldErrorCodes` (additive; works with or without it)_
_Testing rule (CTO): automated tests cover logic only; the CTO tests by hand (§9)._

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

| Deliverable | Status after this step |
|---|---|
| 2. App connected | Requests, booking, both directories, urgent CABINET, documents and auth now read backend errors through the one parser, `ApiFailure`. Requests, both directories, documents and auth now show French from `app_fr.arb`. Booking and urgent CABINET keep their existing correct French. |
| 3. Report per step | This file. |

## 2. Plan findings (step 1)

### Where each feature parsed errors, which codes it relied on, what screens showed

| Feature | Parsed errors at (before) | Codes relied on | Screens showed | Server text reaching a screen? |
|---|---|---|---|---|
| Requests (M05) | `request_failure.dart:232-291`: own `_problemErrorCode` read `errorCode` only, uppercased. | `REQUEST_SUBJECT_FORBIDDEN`, `_TARGET_UNAVAILABLE`, `_INVALID`, `_VERSION_CONFLICT`, `_TRANSITION_INVALID`, `_IDEMPOTENCY_CONFLICT`, `_NOT_FOUND`; then status 400/403/404/409/422/5xx; 401 first. | **English** constants (« Connection unavailable… », « Something went wrong… ») on `my_requests_screen.dart:72` and `review_screen.dart:160`. | No (own constants). |
| Booking (scheduled care) | `scheduled_care_failure.dart:188-192` `_errorCode` read `errorCode ?? code`. | `VALIDATION_FAILED`, `SUBJECT_NOT_AVAILABLE`, `BOOKING_CONTEXT_NOT_AVAILABLE`, `SLOT_NO_LONGER_AVAILABLE`, `VERSION_CONFLICT`, `REQUEST_STATE_CONFLICT`, `ACTION_NOT_ALLOWED`, `REQUEST_EXPIRED`, `IDEMPOTENCY_CONFLICT`; then 401/403/404/5xx. | **French** constants, correct, on 6 patient screens **and** read by doctor code (`doctor_proposal_controller`, `doctor_appointment_controller`, which build `const ScheduledCareFailure(...)` and read `.message`). | No. |
| Clinic directory | `patient_clinic_failure.dart:72-92`, by Dio type and status only. | none (401 / 5xx / other). | **English** on `clinic_directory_screen.dart:319` (fallback « Unable to load clinics. ») and `clinic_detail_screen.dart:61`. | No. |
| Doctor directory | `doctor_directory_failure.dart:80-101`, by type and status. | none (401 / 404 / 5xx). | **English** except 404, on `doctor_directory_screen.dart:295` and `doctor_detail_screen.dart:61,903`. `.message` is also shown by the **doctor** proposal screen (`doctor_proposal_screen.dart:118`). | No. |
| Urgent CABINET | `urgent_cabinet_targeted_request_repository.dart:558` `_problemCode` read `code` only. `urgent_cabinet_discovery_repository.dart:105` read `code ?? errorCode`. | 21 `URGENT_CABINET_*` codes plus `VALIDATION_FAILED`; discovery uses `_REQUEST_UNAVAILABLE` / `_NOT_AUTHORIZED`. `isAuthoritativeRequestAbsence` needs 404 **and** `URGENT_CABINET_REQUEST_NOT_FOUND`. | **French** constants, which travel as `String`s into state objects built by controllers (`urgent_cabinet_request_state.dart:47,114`, lifecycle and submission controllers). | No. |
| Documents | `documents_api.dart:680-776` `_safeApiException` read `code ?? errorCode` itself and wrote an **English** message into `ApiException.message`. `TransportFailure` read the code again. | About 20 codes: local (`UPLOAD_CANCELLED_LOCAL`, `AUTH_REPLAY_REQUIRED`…), backend (`MRS_UNAVAILABLE`, `UNSUPPORTED_FILE_TYPE`, `DOCUMENT_UPLOAD_*`…), then status 401/403. | `medical_documents_screen.dart:1049` showed `ApiException.message`: **English**, including 4 local throws with no code (`:267,336,343,363`). | No, but every text was English. |
| Auth | `auth_api.dart:211-232` parsed `ApiErrorResponse.fromJson` (`auth_dtos.dart:49-73`) and kept the **server `message`** in `ApiException.message`. Transport cases got made-up codes (`NETWORK_UNAVAILABLE`…). `auth_interceptor.dart:145` and `auth_refresh_coordinator.dart:207` read `code ?? errorCode`. | 26 codes in `auth_error_messages.dart`, of which `NETWORK_CONNECTION_TIMEOUT` / `NETWORK_RECEIVE_TIMEOUT` were **never produced**, so timeouts showed the generic message. | French by code, through `AuthController.errorMessage` (8 read sites in 6 auth screens). | **Kept but not shown:** the server `message` in `ApiException.message`, and the server's English field sentences in `AuthController.fieldErrors` (no screen reads them). |

**Backend check** (`code` vs `errorCode`): `RequestProblemDetailHandler.java:139` and `BookingRequestProblemDetailHandler.java:72` set only `errorCode`; `CareCapabilityProblemDetailHandler.java:109` (urgent CABINET) sets only `code`. The parser's `errorCode ?? code` therefore gives exactly the codes each mapper read before.

### Flags: behaviour that depends on the server's text

None left in the features above. Remaining elsewhere, unchanged:
- **G-1 sharing** (`medical_sharing_api.dart:156-157` reads `detail ?? message`; also `direct_patient_authorization_api.dart:157` and `medical_share_qr_api.dart:74` parse codes): read-only for G-2 (1b-2 R1, still open).
- **`features/clinic/data/clinic_failure.dart:283`** reads `errorCode`. That is the clinic **staff** workspace, not a patient feature.

### Decisions taken (no stop needed; each is within the rules)

1. **Shared types keep their public API.**
   - Doctor code builds `const ScheduledCareFailure(kind:, message:, diagnosticCode:)`, reads `.message`, and calls `ScheduledCareFailure.from` / `DoctorDirectoryFailure.from`. `lib/features/doctor/**` is off-limits.
   - So these two classes changed **inside** only: the code comes from `ApiFailure`, and the parsed failure is attached as `api`.
   - Booking keeps its French constants ("keep every correct French message"). The doctor directory adds `patientMessage(l10n)` for patient screens and keeps `.message` for the doctor screen.
2. **`Result<T>`: no repository class needed a change, so none was converted.**
   - All mapping lives in failure classes and APIs. The two urgent CABINET failure classes are defined in their repository files, but only the failure code changed there.
   - Converting the repositories would change the interfaces implemented by about 30 test fakes and their controllers.
   - For `ScheduledCareRepository` (7 doctor files) and `DoctorDirectoryRepository` (2), it is impossible without touching `doctor/**`. See R2.
3. **Urgent CABINET text stays as written.** It is correct French, and it is stored as `String`s in state objects that controllers build without `l10n`. Moving it to ARB is the translation pass. Only its parsing changed.
4. **Unknown cases get the generic text of their kind** (`apiFailureMessage`): for example a 429 shows « Trop de tentatives… ». Each feature keeps its own wording for the cases it knew.
5. **Field messages are shared.**
   - The 6 texts from the task live in the existing `fieldError*` keys.
   - Two were reworded to the task's text: « Format invalide. » and « Valeur hors limites. ».
   - « Vérifiez ce champ. » covers `INVALID` and an absent code.
   - Every feature failure now carries `api.fieldErrors`. Today only the profile and family forms show field errors (1b-2); there is no new UI.

## 3. What changed

**Core (`lib/core/network/`)**
- `api_failure.dart`: public `apiErrorCodeOf(body)`, the parser's code reader, for decisions that only need the code.
- `api_failure_message.dart`: `AUTH_PROVIDER_UNAVAILABLE` → « Service de connexion momentanément indisponible. Réessayez plus tard. » (**the one wording fix**). It is now the same on auth and security screens.
- `auth_interceptor.dart`, `auth_refresh_coordinator.dart`: the session-invalid check reads the code through `apiErrorCodeOf`.
- `transport_failure.dart`: same; its own JSON reader was deleted.

**Requests:** `request_failure.dart`
- Built from `ApiFailure.fromDio`, with the same kinds, diagnostic codes, retry rules and status fallbacks as before.
- The `message` field became `message(l10n)`, with 14 new French keys and the shared network, timeout and session texts. Unknown → `apiFailureMessage`.
- Screens: `my_requests_screen.dart`, `review_screen.dart`.

**Clinic directory:** `patient_clinic_failure.dart` → `message(l10n)`.
- Screens: `clinic_directory_screen.dart`, `clinic_detail_screen.dart`. Their English fallbacks became `clinicListLoadFailed` and `clinicDetailLoadFailed`.

**Doctor directory:** `doctor_directory_failure.dart` adds `api` and `patientMessage(l10n)`; `.message` is kept.
- Screens: `doctor_directory_screen.dart`, `doctor_detail_screen.dart` (2 sites).

**Booking:** `scheduled_care_failure.dart` reads the code through `ApiFailure.fromDio` and attaches `api`; the constructor and messages are unchanged.

**Urgent CABINET:** both failure mappers read the code through the parser (`ApiFailure.fromDio`, `apiErrorCodeOf`). Their `_problemCode` helpers were deleted.

**Documents**
- `documents_api.dart` `_safeApiException`:
  - builds from `ApiFailure.fromDio`;
  - local codes win;
  - `message` is now the safe `logSummary`;
  - the English switch was deleted.
- New `features/profile/medical_document_error_message.dart`: `documentErrorMessage(error, l10n)` covers 33 local and backend codes, then the shared kind text with a documents fallback.
- `medical_documents_screen.dart`:
  - the snackbar uses it;
  - the 4 code-less local throws got codes (`PROFILE_NOT_READY` ×2, `OPERATION_IN_PROGRESS`, `FILE_READ_FAILED`).

**Auth**
- `auth_api.dart`: HTTP and transport errors → `ApiException.fromFailure(ApiFailure.fromDio(error))`. The server `message` is no longer kept. The local replay and refresh codes are unchanged.
- `auth_dtos.dart`: `ApiErrorResponse` and its two helpers were deleted.
- `auth_error_messages.dart`:
  - `fromCode(code, l10n)` covers 22 auth codes with the **same French text**, now in ARB. One accent was fixed: « différent ».
  - Of the 26 old codes, `AUTH_PROVIDER_UNAVAILABLE` moved to the shared code messages, and the three dead `NETWORK_*` codes are replaced by the parser's network and timeout kinds.
  - `message(error, l10n)` = local text, else the auth code, else `apiFailureMessage`.
  - `AuthErrorPresentation` keeps the error, the code and the field **kinds**.
- `auth_controller.dart`:
  - `errorMessage` → `errorMessage(l10n)`;
  - `fieldErrors` became `Map<String, ApiFieldErrorKind>` (no server sentences).
- Six auth screens pass `OmniLocalizations.of(context)`: login, signup, OTP, phone input, Google link sheet, reset password. There is no layout change.

**Security:** `account_security_provider.dart`: the « SMS » override for `AUTH_PROVIDER_UNAVAILABLE` was removed (key `securitySmsUnavailable` deleted).

**ARB:** 68 new keys, 2 reworded, 1 removed, giving 162 keys. Regenerated with `flutter gen-l10n`.

**Not touched:** `lib/features/doctor/**`, `patient_passport/sharing/**`, the urgent-home `emergency/*` screens, every repository class, layouts and styles, pubspec.

## 4. Evidence

- `flutter analyze`: **388 issues**, the same as the baseline, none new.
- `flutter test`: **1914 passed, 7 skipped** (1891 before, plus 23 new). The ARB drift test is green.
- New `test/error_mappers_french_test.dart`, 23 logic tests:

  | Area | Tests | What they check |
  |---|---|---|
  | Field contract | 2 | Each of the 6 codes gives its exact French text; no codes gives « Vérifiez ce champ. ». |
  | Requests | 6 | Recorded ProblemDetail codes give the same kinds with French text. 401 wins over the code. HTML bodies use the status fallback. 429 and non-Dio errors give generic text. Timeout, network and cancel are covered. All 18 constants are French. Field codes give precise text. |
  | Booking | 4 | Same French text as before; shapes 1 and 3 both work; unknown and 5xx stay generic; the doctor's `const` constructor still works; field codes. |
  | Clinic directory | 1 | All statuses and transport cases, in French. |
  | Doctor directory | 1 | `patientMessage` is French, while the doctor's `.message` is unchanged. |
  | Urgent CABINET | 2 | Same kinds and text. `isAuthoritativeRequestAbsence` still needs the code: a plain 404 is not an absence. Discovery reads the code from a map or from JSON text. |
  | Documents | 3 | Through `DocumentsApi.listDocuments` against a fake server: backend codes give French and the server text is absent; unknown cases give the kind text or the documents fallback; local codes give French. |
  | Auth | 4 | Through `AuthApi`: a known code keeps its French text and field codes give kinds; the provider outage reads the same on the auth and security screens; unknown and transport cases give generic text; `apiErrorCodeOf` handles all body shapes. |

- **Updated tests:**
  - `auth_phase1_test`: the `ApiErrorResponse` test became an `ApiFailure` test; `fromCode`, `errorMessage(l10n)` and the transport kind replace the old code `NETWORK_UNAVAILABLE`; the old provider wording became the new one.
  - `documents_api_test`: asserts the French text, not the English message.
  - `api_failure_parser_test`: the two reworded field texts.
  - **Existing** widget tests, updated only to stay green (no new widget tests):
    - `request_history_widget_test`, `clinic_detail_screen_test`, `clinic_directory_screen_test`, `doctor_detail_availability_test`: localization delegates and French expected text;
    - `auth_phase1_test`: localization delegates added to its 12 harnesses.

## 5. Visible changes for patients

- **Requests, clinic directory, doctor directory and documents:** English error texts are now French.
- **Auth:**
  - « Service de vérification temporairement indisponible… » became « Service de connexion momentanément indisponible. Réessayez plus tard. ».
  - No network now reads « Connexion impossible. Vérifiez votre connexion et réessayez. » (was « Connexion réseau indisponible. »).
  - Timeouts now show « Le serveur met trop de temps à répondre. Réessayez. ». Before, they showed the generic message, because of the dead codes.
  - Unknown codes give the text of their kind instead of one generic sentence.
- **Security screens:** the provider outage no longer says « SMS ».
- **Booking and urgent CABINET:** unchanged.

## 6. Complexity

- Every mapper is O(1) over one parsed body.
- One parse per error: `ApiFailure.fromDio`.
- No new dependencies, no new state.

## 7. Risks, open questions, things not done

| # | Item | Proposal |
|---|---|---|
| R1 | Booking and urgent CABINET French text is still constants in Dart, not ARB. | The translation pass. Booking needs the doctor side too, since the doctor app builds and reads the same type. |
| R2 | `Result<T>` was not adopted: no repository class changed. | A dedicated step per patient-only repository (requests, clinic directory, urgent CABINET, auth, files), each with its fakes. Booking and doctor directory wait for a doctor-side decision. |
| R3 | `AuthFlowException` carries **English** developer text that reaches auth snackbars in contract-violation paths (« Login session was not returned. »…). This is local text, not server text. A few English screen fallbacks also remain on lines I did not change (« Unable to verify code. », « Unable to continue. », « Please enter all 6 digits »). | The translation pass (1b-1 R3). |
| R4 | Some urgent CABINET copy is developer wording: « Les demandes CABINET synthétiques ne sont pas activées. », and « CABINET » in capitals. | Copy review with the urgent-flow owner. |
| R5 | `TransportFailure` is now used only by `ApiFailure` and its own test, since documents and auth moved off it. | Delete it in the next cleanup if nothing needs the DNS/TLS distinction. |
| R6 | Sharing (G-1) still parses errors itself and can show server `detail` (1b-2 R1). | Unchanged; G-1 decision. |
| R7 | The local developer `ApiException` texts in the documents API and controller are still English, but are no longer shown. | Cleanup when those classes are next touched. |

## 8. Path to deliver G-2

1. **CTO:**
   - Run §9.
   - Commit the app work: 1a, 1b-1, 1b-2 and this step.
   - Commit the backend 1b-2b paths.
2. **Rest of Phase 1b, item 2:** timeouts, retry, one Idempotency-Key helper. Adopt `Result` per patient-only repository (R2).
3. **Rest of Phase 1b:** build config, logging, clock and Tunis time, cutting off the mocks, guard test.
4. **Translation pass:** R1, R3 and the 1b-1 list. Then Phase 1c onwards; push notifications are in Phase 6.
5. **Release gate (§8)**, then the final G-2 report.

## 9. Manual test steps for the CTO

Run a debug build against the local backend. "Offline" means airplane mode with the app open.

1. **Requests, offline.** Open « Mes demandes » offline. Expect « Connexion impossible. Vérifiez votre connexion et réessayez. », with no English.
2. **Request send failure.** Prepare a care request, go offline at the review screen and press send. Expect a French banner, retry still offered, and the same operation retried when back online.
3. **Clinic directory.** Offline, open the clinic list, then a clinic detail. Expect French messages. Online, « Réessayer » restores them.
4. **Doctor directory.** Offline, open the doctor list. Expect French. Online, open a doctor, then stop the backend and retry availability. Expect « Le répertoire des médecins est momentanément indisponible. Réessayez. ».
5. **Booking (unchanged).** Book a slot that another account just took. Expect the same « Ce créneau n’est plus disponible. Choisissez-en un autre. ».
6. **Documents.**
   - Try to upload a file over 20 Mo. Expect « Ce fichier dépasse la limite de 20 Mo. ».
   - Open the documents list offline. Expect a French message.
   - Start an upload and cancel it. Expect the French "transfer stopped" text.
7. **Auth.**
   - Wrong OTP: « Code invalide ou expiré. ».
   - Sign up with an already-used phone: « Ce numéro est déjà utilisé. ».
   - Log in offline: « Connexion impossible… ».
8. **Provider outage.** Start the backend with the SMS or Google provider disabled, if your dev config allows it. Request an OTP on login, then a phone change in « Sécurité ». Both show « Service de connexion momentanément indisponible. Réessayez plus tard. ».
9. **Field messages (optional).** Needs a backend with 1b-2b. With a tool like Proxyman, make `PUT /api/v1/profile` return `400 {"code":"VALIDATION_ERROR","fieldErrors":{"firstName":"x"},"fieldErrorCodes":{"firstName":"REQUIRED"}}`. The profile form shows « Ce champ est obligatoire. » under the first name. Without `fieldErrorCodes` it shows « Vérifiez ce champ. ».
10. **Urgent CABINET (regression).** Go through the urgent CABINET flow once (discover, request, cancel). The behaviour and texts are the same as before.
11. **Doctor app (regression).** In the doctor proposal screen, cut the network while availability loads. The message is the same as before (unchanged English).
