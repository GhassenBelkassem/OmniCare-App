# G-2 · 1b-2b — a stable code per rejected field in validation errors

_Date: 2026-11-11 · Repo: **OmniCare-BackEnd** (working tree on `feature/g1-p2b-single-page`, which also holds uncommitted G-1 work; see §7) · Additive only: status, `code`, `message` and the English `fieldErrors` are unchanged._
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
| 2. App connected | Backend side of 1b-2 decision R2 is done: Bean Validation errors now carry `fieldErrorCodes`. The app already reads them (1b-2), so patients get « Ce champ est obligatoire. » etc. instead of « Vérifiez ce champ. » with no app change. |
| 3. Report per step | This file. |

## 2. Plan findings (step 1)

### Where the codes come from today

- `ErrorResponse` already has `fieldErrorCodes` (`shared/error/ErrorResponse.java:20`), `@JsonInclude(NON_NULL)`, so it is omitted when null.
- `GlobalExceptionHandler.handleValidationException` (`GlobalExceptionHandler.java:85-109` before this change) put `error.getField() → getDefaultMessage()` into `fieldErrors` and only **logged** `FieldError::getCode()` (lines 95-97). The response used the 4-argument constructor, so `fieldErrorCodes` was always absent.
- `FieldError.getCode()` is the constraint annotation's simple name (`NotBlank`, `Size`…), the last of the codes that Spring's `SpringValidatorAdapter` builds for a violation. The underlying `ConstraintViolation` is reachable through `ObjectError.unwrap(ConstraintViolation.class)` (the same approach `ClinicalValidationAdvice.violation` already uses, `shared/validation/ClinicalValidationAdvice.java:182-197`).

### Which patient endpoints reach this handler

Package-scoped advices with `@Order(HIGHEST_PRECEDENCE)` catch `MethodArgumentNotValidException` first for `request.api`, `scheduledcare.api`, `professionalcare.api`, `clinic.api`/`access`/`professional.api`, `appointment` availability, and the professional profile/practice/equipment/coverage packages. They render ProblemDetail and are **not changed**.

The patient controllers with `@Valid @RequestBody` whose errors reach `GlobalExceptionHandler`:

| Controller | Request DTOs |
|---|---|
| `auth/api/AuthController` | `ChangePasswordRequest`, `Google*Request` (5), `LoginRequest`, `OtpRequest`, `PhoneRequest`, `RefreshTokenRequest`, `SignupCompleteRequest` |
| `auth/api/AccountSecurityController` | `SetPasswordRequest` |
| `auth/api/PhoneChangeController` | `PhoneChangeNewPhoneRequest`, `PhoneChangeOtpRequest`, `PhoneChangeReversalRequest` |
| `profile/controller/FamilyMemberController` | `FamilyMemberRequest`, `UpdatePassportRequest` |
| `profile/controller/OnboardingController`, `PassportController` | `OnboardingStepRequest` |
| `profile/controller/ProfileController` | `UpdateMedicalDataRequest`, `UpdatePassportRequest`, `UpdateProfileRequest` |
| `professionalaccess/api/ProfessionalAccessRequestController` | `CreateProfessionalAccessRequest` |
| `urgentrequest/controller/UrgentRequestController` | `LocationUpdateRequest`, `SelectDoctorRequest`, `UrgentRequestCreateRequest` |

`medicalsharing` patient controllers also reach it, because `MedicalSharingProblemDetailHandler` has no validation handler. Their bodies gain the same additive field; the package itself is untouched.

### Constraint annotations in those 24 DTOs, and the code for each

| Annotation (count in the 24 DTOs) | Stable code | Example field |
|---|---|---|
| `@NotBlank` (44), `@NotNull` (13), `@NotEmpty` (0) | `REQUIRED` | `FamilyMemberRequest.firstName` |
| `@Size` (43), Hibernate `@Length` (0) | `TOO_LONG` if the value's length/size is above `max`, else `TOO_SHORT` | `SetPasswordRequest.newPassword` (`min = 12`) |
| `@Pattern` (13), `@Email` (2) | `INVALID_FORMAT` | `CreateProfessionalAccessRequest.phone` |
| `@Positive` (6), `@DecimalMin` (5), `@DecimalMax` (4), `@Past` (3); also `@Min`, `@Max`, `@Digits`, `@PositiveOrZero`, `@Negative*`, `@PastOrPresent`, `@Future*`, `@Range` (0 today) | `OUT_OF_RANGE` | `UrgentRequestCreateRequest.patientLatitude` |
| anything else (`@AssertTrue`, `@Null`, custom constraints, `typeMismatch`) | `INVALID` | none in these DTOs today |

`@Valid` (3) only cascades into nested objects and list elements. Their keys are the same as in `fieldErrors`, for example `lifeSafety.allergies[3]`. No custom constraints and no class-level constraints are used.

### Decisions taken (no stop needed)

1. **`INVALID`, as the task says, not G-1's `INVALID_VALUE`.** The consultation catalog (`ClinicalValidationCatalog.INVALID_VALUE`) is a separate envelope and is unchanged. The app treats both the same (any unknown code → « Vérifiez ce champ. », `api_failure.dart:231`).
2. **One code per field, by fixed precedence: `REQUIRED` > `TOO_SHORT` > `TOO_LONG` > `INVALID_FORMAT` > `OUT_OF_RANGE` > `INVALID`.** One field can break two constraints. For example `""` on `@NotBlank @Size(min = 12)` breaks both, and Hibernate Validator returns its violations as a `Set`, so in no fixed order. The precedence makes the code deterministic. The English `fieldErrors` keeps its old last-wins behaviour, unchanged.
3. **A `@Size` failure without its `ConstraintViolation` gives `INVALID`, not a guess.** This cannot happen for real `@Valid` bodies; it guards hand-built `FieldError`s.
4. **List sizes use `TOO_LONG`/`TOO_SHORT` too**, as the task maps `Size` → those codes. The only list fields are `allergies`/`criticalConditions` (`@Size(max = 50)`); see R2.

### Constraint-violation path

`GlobalExceptionHandler` has **no** handler for `ConstraintViolationException` or `HandlerMethodValidationException`. A method-parameter constraint failure there falls to the catch-all as 500 `INTERNAL_SERVER_ERROR` with empty `fieldErrors`, so it does not use the same envelope. It is left unchanged, since a new handler would change a status code. No patient controller reaching this handler declares parameter constraints. The only one found is the doctor-side `PracticePatientReconciliationController.java:40` (`Idempotency-Key` header). See R3.

### Angular dashboard tolerance

- `OmniCare-FrontEnd/src/app/core/http/app-http-error.ts:56-66`: `normalizeHttpError` already reads `fieldErrorCodes` from **every** error body into `AppHttpError.fieldErrorCodes`. It bounds the entries (`safeFieldErrorCodes`, lines 97-103, requires `^[A-Z_]{1,40}$` and keeps at most 50) and ignores every other unknown key.
- The only reader of `fieldErrorCodes` is `features/doctor/consultation/model/consultation-errors.ts:28-34` (`mapServerFieldErrors`). It is used only for note and prescription autosave calls, whose validation is rendered by `ClinicalValidationAdvice`, never by `GlobalExceptionHandler`.
- The other `fieldErrors` readers (`admin-page-utils.ts:77`, `secretary-page-utils.ts:79`, `professional-profile-section.ts:263`, `auth.models.ts:99`) read `fieldErrors` only, with no strict key checks.
- **Result:** the dashboard ignores the new field everywhere it can appear. No Angular change.

### App tolerance (already done in 1b-2)

`OmniCare-App/lib/core/network/api_failure.dart:203-232` (`fieldErrorKindOf`) maps `REQUIRED`, `TOO_LONG`, `TOO_SHORT`, `INVALID_FORMAT`, `OUT_OF_RANGE` and any other code (→ `invalid`) to the French field texts in `app_fr.arb:255-279`. No app change.

## 3. What changed (backend)

| File | Change |
|---|---|
| `src/main/java/com/omnicare/app/shared/error/FieldErrorCode.java` (new, 70 lines) | Enum of the 6 codes, in precedence order. `byField(List<FieldError>)` builds the field → code map with the same keys as `fieldErrors`; `of(FieldError)` maps an annotation name to its code; `length(...)` compares the rejected value's length or size with the constraint's `max`. |
| `.../shared/error/GlobalExceptionHandler.java` (+6 −1) | `handleValidationException` passes `FieldErrorCode.byField(...)` as `fieldErrorCodes` (null when empty, so omitted). `fieldErrors`, `code`, `message`, status 400, `requestId` (still absent here) and the log line are unchanged. |
| `.../shared/error/ErrorResponse.java` (comment only) | The javadoc of `fieldErrorCodes` mentions Bean Validation. |
| `src/test/java/com/omnicare/app/shared/error/FieldErrorCodesWebMvcTest.java` (new) | `@WebMvcTest`, 5 tests (§4). |
| `src/test/java/com/omnicare/app/shared/error/FieldErrorCodeTest.java` (new) | Pure logic, 4 tests (§4). |

Not touched: the consultation, clinicalrecord, medicalsharing and mrs packages, every ProblemDetail handler, `ClinicalValidationAdvice`, the other `GlobalExceptionHandler` handlers, and the Angular and Flutter repos.

## 4. Evidence

`./mvnw -Dtest='FieldErrorCodesWebMvcTest,FieldErrorCodeTest,GlobalExceptionHandler*Test' test` passed **16 of 16** (9 new and 7 existing handler tests).

- `FieldErrorCodesWebMvcTest` (real Spring MVC slice; `GlobalExceptionHandler` and the app's other advices are loaded):
  1. `eachViolationTypeGetsItsStableCode`: one sample patient DTO with 17 fields. Each of `@NotBlank`, `@NotNull`, `@NotEmpty`, `@Size` (too long and too short, string and list), Hibernate `@Length`, a list-element `@NotBlank` (`tags[1]`), `@Pattern`, `@Email`, `@Positive`, `@Min`, `@DecimalMax`, `@Digits`, `@Past`, `@Future` and `@AssertTrue` gets its expected code, and there are exactly 17 entries.
  2. `existingEnvelopeAndEnglishFieldErrorsAreUnchanged`: `code` = `VALIDATION_ERROR`, `message` unchanged, `timestamp` present, `requestId` absent. `fieldErrors` keeps the Bean Validation English texts (`must not be blank`, `size must be between 0 and 5`, `must be a well-formed email address`), with the same 3 keys as `fieldErrorCodes`.
  3. `anEmptyFieldWithTwoViolationsReportsRequired`: `""` on `@NotBlank @Size(min = 12)` gives `REQUIRED`. In this run the existing log line showed `newPassword:Size`, so the precedence did the work.
  4. `realPatientDtoProfessionalAccessRequest`: the real `CreateProfessionalAccessRequest` gives `profession` `REQUIRED`, `email` and `phone` `INVALID_FORMAT`, `organization` `TOO_LONG`, and keeps its custom English text `Must be +216 followed by 8 digits`.
  5. `aValidBodyStillSucceeds`: a valid body gives 200.
- `FieldErrorCodeTest`: the precedence does not depend on violation order; container keys (`allergies[2]`) are kept; `typeMismatch`, `@AssertTrue`, a null code and a `Size` failure without its constraint give `INVALID`; no errors give an empty map.

**Affected packages:** shared, auth, profile, professionalaccess, urgentrequest, appointment, secretary, admin and medicalsharing.
- Result: **958 tests, 0 failures, 3 skipped, 9 errors**.
- Every error is a context-load failure in two full-application tests, `auth/session/DeviceAwareSessionLifecycleIntegrationTest` (8) and `shared/audit/loadtest/AuditPipelineLoadTest` (1).
- Cause: the committed `urgentcabinetrequest/UrgentCabinetAccessStartupValidator.java:63` refuses to start: « Urgent CABINET local development requires the exact authorized PostgreSQL omnicare database ».
- That is a local-environment check, unrelated to this change, which touches no bean or configuration.

## 5. Contract (before → after)

```http
POST /api/v1/professional-access-requests   {"profession":"", "email":"lina@", "phone":"123", ...}
400
```
```jsonc
{
  "code": "VALIDATION_ERROR",
  "message": "<unchanged>",
  "timestamp": "…",
  "fieldErrors":     { "profession": "must not be blank", "email": "must be a well-formed email address",
                       "phone": "Must be +216 followed by 8 digits" },          // unchanged
  "fieldErrorCodes": { "profession": "REQUIRED", "email": "INVALID_FORMAT", "phone": "INVALID_FORMAT" }  // new
}
```

- `fieldErrorCodes` has exactly the keys of `fieldErrors`, and each value is one of `REQUIRED`, `TOO_SHORT`, `TOO_LONG`, `INVALID_FORMAT`, `OUT_OF_RANGE`, `INVALID`.
- It is omitted when there are no field errors.
- The `ApiException` path (`handleApiException`) already emitted `fieldErrorCodes` when the exception carried some; that is unchanged.

## 6. Complexity

- One pass over the field errors: O(n), with n bounded by the DTO's field count (≤ 17 in patient DTOs) plus list elements (≤ 50 per list).
- No reflection beyond `Array.getLength` for array values, no new beans, no new configuration.

## 7. Risks, open questions, things not done

| # | Item | Proposal |
|---|---|---|
| R1 | The working tree also holds uncommitted G-1 work, including `shared/error/ErrorCode.java` (`ARTIFACT_NOT_DISCARDABLE`, **not** this step). | Commit only the 5 paths in §3 (commands in the chat summary). |
| R2 | List sizes (`allergies`, `criticalConditions` > 50) give `TOO_LONG`, which the app shows as « Ce texte est trop long. ». The app's lists cannot reach 50 in normal use. | Accept. If wanted later: an app-side override per field, or a `TOO_MANY_ITEMS` code (it exists in G-1's clinical catalog) as a separate decision. |
| R3 | `ConstraintViolationException` / `HandlerMethodValidationException` still become a 500 in `GlobalExceptionHandler`. No patient endpoint is affected today. | Separate backend task if a patient endpoint ever adds parameter constraints: map them to the same 400 envelope with codes. |
| R4 | The other global 400s still send no codes: missing header, type mismatch, unreadable body. Their `fieldErrors` keys are `<header name>`, `<param name>` and `body`. | Out of scope (the task named `MethodArgumentNotValidException` only). The app already shows the generic per-kind message for them. |
| R5 | The handled-4xx log line still logs annotation names (`newPassword:Size`) and keeps the first one, not the precedence code. | Left unchanged ("no other behaviour change"). It could log the stable code later. |
| R6 | Two integration tests cannot start locally (§4). | Not related to G-2; to be looked at by whoever owns the urgent-cabinet startup check. |

## 8. Path to deliver G-2

1. **CTO:** run §9 and commit the 5 backend paths. The app needs no change: 1b-2 already maps these codes to French. Also commit the still-uncommitted app work of 1a, 1b-1 and 1b-2.
2. **Phase 1b, rest of item 2:** move the remaining feature error mappers to `ApiFailure` (requests, booking, directories, urgent cabinet, documents, auth), then timeouts and retry and one Idempotency-Key helper, with `Result` in each repository as it is touched.
3. **Rest of Phase 1b:** build config, logging, clock and Tunis time, cutting off the mocks, and the guard test.
4. **Translation pass, then Phase 1c onwards.** Push notifications (ex-1a-5) are in Phase 6.
5. **Release gate (§8)**, then the final G-2 report.

## 9. Manual test steps for the CTO

Backend running locally from this working tree, dev profile, on the port you normally use (8080 below).

1. **Codes appear.** Send an invalid public request:
   ```bash
   curl -s -X POST http://localhost:8080/api/v1/professional-access-requests \
     -H 'Content-Type: application/json' \
     -d '{"profession":"","firstName":"Lina","lastName":"Ben Ali","email":"lina@","phone":"123","professionalIdentifier":"ID-1"}' | jq
   ```
   Expect 400 with `"code": "VALIDATION_ERROR"`. `fieldErrors` holds the same English texts as before, and `fieldErrorCodes` = `{"profession":"REQUIRED","email":"INVALID_FORMAT","phone":"INVALID_FORMAT"}`.
2. **Too long.** Repeat step 1 with `"profession":"Médecin"`, a valid email and phone (`+21612345678`), and `"organization"` set to 161 characters. Expect only `"organization":"TOO_LONG"`.
3. **Valid body still works.** The step 2 body with a 10-character organization gives 2xx, and a second identical call gives the existing 409 `PROFESSIONAL_ACCESS_REQUEST_ALREADY_PENDING`, which is unchanged and has no `fieldErrorCodes`.
4. **No codes on non-validation errors.** Call any authenticated patient endpoint without a token. Expect the usual 401 body with no `fieldErrorCodes` key.
5. **Consultation unchanged (dashboard).** In the Angular dashboard, open a consultation and type a diagnosis label over its limit. The field message is the same as before (that path uses `ClinicalValidationAdvice`, which is unchanged).
6. **Dashboard elsewhere.** In platform admin or the secretary pages, submit a form with an empty required field. The same field message as before, with no new banner or console error.
7. **Patient app (optional).** The app's forms check required fields and name lengths themselves, so a server field error is hard to trigger from the UI. To see it end to end:
   - temporarily point a dev build at this backend;
   - from the « Accès professionnel » form, send a phone the app accepts but the backend rejects, if one exists in your build.

   Expect the French field-specific text (« Le format de ce champ n’est pas valide. ») instead of « Vérifiez ce champ. ». The app side is covered by the 1b-2 parser tests either way.
