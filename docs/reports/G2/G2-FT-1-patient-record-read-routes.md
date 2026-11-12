# G2 FT-1: Patient read routes for the « Dossier médical »

**Date:** 2026-11-11 · **Repos:** OmniCare-BackEnd (Spring), omnicare-mrs (Go) · **App:** not changed

## 1. Goal card and status

> GOAL G-2: Connect the patient Flutter app to the real backend without changing the current UI, with a report at every step.
> Done when every patient screen reachable from production main.dart shows real data or an honest "indisponible" state (no fixture, no mock), the release build passes the G-2 gate (§8), and every step has a report in OmniCare-App/docs/reports/G2/.

Task FT-1: Spring read-only routes for the passport's current treatments, completed consultations (summary) and finalized prescriptions/certificates, served from MRS. Decision: patient medical data lives in MRS (CTO, 2026-11-11).

| Deliverable | Status |
|---|---|
| Spring routes: medications, consultations, artifacts, medical-data (any subject) | ✅ done, tested |
| Additive read-only MRS routes (two) | ✅ done, tested (incl. against a real Postgres) |
| Ownership, same 404, MRS audit, no PHI in logs, stable codes | ✅ |
| App binding of the passport | ⏳ not in scope (Phase 4 app step; blocked on the 1b-3 §2.3 decision) |

No STOP condition was hit. The MRS change is additive and read-only, in a new package. It does not touch consultation write paths, completion, workspace, QR or direct-consent code. It does not touch the Spring consultation, clinicalrecord, clinicalorder, medicalsharing or mrs/projection packages.

## 2. Plan (as found before editing)

### 2a. What each section of the screen needs, and where it comes from

| Section (file:line) | Fields the screen reads | Existing source | Verdict |
|---|---|---|---|
| Identity (`passport_identity_card.dart`) | name, phone, email, OmniCare id | `GET /api/v1/profile` | Not medical; already served |
| Blood type, allergies, chronic conditions, measurements (`passport_essential_info_card.dart`, `passport_measurements_card.dart`) | bloodGroup, allergies, chronicConditions, heightCm, weightKg (`patient_passport_view_models.dart:119-131`) | `GET /api/v1/profile/medical-data` → MRS `LIFE_SAFETY` and `BODY_MEASUREMENTS` records | SELF only (see 2c) |
| Traitements (`passport_medications_card.dart:217,224,241-243`) | name, instruction (dosage · frequency), current or past, stop label | MRS `GET /internal/mrs/patients/{id}/medications` (`medical_records.go:189`) returns `current` + `past`, audited (`medications/service.go:61-69`) | Route exists; **no Spring caller** |
| Historique (`passport_history_tab.dart:41,137-140,207,227,233,267`; `patient_passport_screen.dart:244-263,324-346`) | consultationId, date, doctor, reason, specialty, status, shareable, sharingVersion | MRS `GET …/consultation-history` (`consultation_completion.go:37`) | **Not usable** (see below) |
| Ordonnances, certificats | type, date, PDF | `GET /api/v1/patient/consultations/{cid}/artifacts` (per consultation), MRS `…/consultations/{cid}/artifacts` (`official_artifacts.go:31`) | **No list across consultations** |
| Documents tab | — | Phase 5 | Out of scope |

Why the existing MRS `consultation-history` route can't be used:
- **Unreachable.** It requires scope `CONSULTATION_HISTORY` (`consultation_completion.go:47`), which is missing from the MRS scope allow-list (`middleware/internal_request.go:58-76`). Every patient call is rejected with `INVALID_SCOPE`.
- **Not audited.** `completion/service.go:414-468` has no audit run.
- **Not paginated.** It has a fixed `LIMIT 100`.
- **Not a summary.** It returns the whole decrypted clinical record (`payload`).

It lives in completion code (G-1's), so I left it unchanged and added a new route instead.

Doctor name and specialty are not stored in MRS. MRS has `professional_actor_id` (`mrs_consultation_finalizations`, `mrs_official_artifacts`). Spring resolves it against `professional_profiles` and `user_profiles` with one batch query per page, the same query `patientchart` already uses (`PatientChartRecordsRepository.java:223-237`).

Model fields the history card does **not** render are not served: diagnosis, per-consultation medications, assessment, plan and notes. The CANCELLED status isn't served either, because the rule is completed only.

### 2b. Route design
Spring: `GET /api/v1/me/medical-record/{medications|consultations|artifacts|medical-data}?subject=SELF|FAMILY:{familyMemberId}`.
- **Paging:** lists take `size` (default 20; a larger value is capped at 50) and an opaque keyset `cursor`.
- **Subject:** the server resolves the MRS patient from the caller (`CareSubjectResolver`); the app never sends an MRS id.
- **Naming:** `size`, `cursor` and `nextCursor` follow the existing `patientchart` convention.

### 2c. Does `/profile/medical-data` support a family member? **No.**
`ProfileController.java:78-86` reads only the caller's own profile. So `GET /api/v1/me/medical-record/medical-data?subject=…` is included. For SELF it returns the same values as `/profile/medical-data`: MRS first, then the legacy profile columns. For a family member it reads MRS only, per the CTO decision. It also returns the list statuses `UNKNOWN`, `NONE_KNOWN` and `LIST`, which `/profile/medical-data` drops. The app needs them to tell "never recorded" (« indisponible ») from "recorded as none".

### 2d. MRS changes (additive, read-only, named)

| Route | Package | Reads (never writes) |
|---|---|---|
| `GET /internal/mrs/patients/{mrsPatientID}/consultation-summaries?limit=&after_at=&after_id=` | new `internal/patientrecord` | `mrs_consultation_finalizations`, `medical_records` (chief complaint only), `mrs_consultation_sharing_policies`, `mrs_care_contexts` |
| `GET /internal/mrs/patients/{mrsPatientID}/official-artifacts?limit=&after_at=&after_id=` | new `internal/patientrecord` | `mrs_official_artifacts`, `mrs_official_artifact_renders`, finalizations, care contexts (metadata only, nothing decrypted) |

## 3. What changed

### omnicare-mrs
| File | Change |
|---|---|
| `internal/patientrecord/model.go` | **New.** Page input and cursor; summary-only response types; limits 20 / 50 |
| `internal/patientrecord/repository.go` | **New.** Two keyset SQL queries (parameterized), plus the account-holder check |
| `internal/patientrecord/service.go` | **New.** Validate → audit → read-only transaction (10 s timeout) → own check → page. The consultation path decrypts only to extract the chief complaint (`records.ChiefComplaintOf`); the key and plaintext are zeroed |
| `internal/api/patient_record.go` | **New.** Handler: role PATIENT, purpose `SELF_SERVICE`/`FAMILY_MANAGEMENT`, scope check, page parsing, stable error codes |
| `internal/api/router.go` | +4 lines: register the handler |
| `internal/bootstrap/medical_records.go` | +4 lines: build the service, add a field (the file also has G-1's uncommitted hunks) |
| `cmd/mrs-api/main.go` | +1 line: pass the handler to the router |
| `internal/api/patient_record_test.go` | **New.** 4 transport tests |
| `internal/patientrecord/service_integration_test.go` | **New.** 6 DB tests (`MRS_TEST_DATABASE_URL`) |

### OmniCare-BackEnd
| File | Change |
|---|---|
| `patientrecord/api/PatientMedicalRecordController.java` | **New.** 4 GET routes, `no-store` |
| `patientrecord/api/PatientMedicalRecordDtos.java` | **New.** Response records (summary fields; no MRS id; no professional id) |
| `patientrecord/application/PatientMedicalRecordService.java` | **New.** Validate → resolve the subject → MRS (no transaction) → name lookup. Logs carry the section, subject kind, outcome and code |
| `patientrecord/application/RecordRequestParams.java` | **New.** Parsing of `subject`, `size`, `group` and the cursor; `VALIDATION_ERROR` with `fieldErrorCodes` |
| `patientrecord/application/RecordProfessionals.java` | **New.** Batch name/specialty lookup, `@Transactional(readOnly = true)`, one query per page |
| `patientrecord/mrs/MrsPatientRecordClient.java`, `HttpMrsPatientRecordClient.java` | **New.** MRS client on the existing signed `mrsRestClient`. Headers: PATIENT role, own purpose, request id propagated. Error mapping: 403/404 → `RESOURCE_NOT_FOUND`, anything else → `MRS_UNAVAILABLE` |
| `profile/service/UserProfileService.java` | Extracted `withLegacyProfileValues(profile, snapshot)` from `getMedicalData`; it now keeps the list statuses. `/profile/medical-data` output is unchanged, since it never exposed them |
| `auth/config/AuthWebSecurityConfig.java` | +2 lines: `GET /api/v1/me/medical-record/**` → PATIENT (otherwise `denyAll`) |
| `src/test/…/patientrecord/*` | **New.** WebMvc (34), service (9), HTTP client (5) |

## 4. Evidence

| Command | Result |
|---|---|
| `go build ./... && go vet ./...` (MRS) | clean; `gofmt -l` empty |
| `go test ./internal/api -run PatientRecord` | ok (4 tests) |
| `MRS_TEST_DATABASE_URL=… go test ./internal/patientrecord -v` (throwaway `postgres:16`, migrations applied) | **6/6 pass** |
| `MRS_TEST_DATABASE_URL=… go test ./... -p 1` | all packages ok except 2 failures outside this change (below) |
| `./mvnw test -Dtest='PatientMedicalRecord*Test,HttpMrsPatientRecordClientTest,ProfileControllerTest,UserProfileService*Test'` | **56/56 pass** (48 new + 8 profile) |
| Affected packages: profile, auth, patientrecord, mrs, artifact, access | 643 run, 0 failures, 9 errors outside this change (below) |

The DB tests cover these cases:
- the owner pages through completed consultations newest first, with no repeat or skip;
- aborted and still-open consultations are excluded;
- `SHAREABLE` with its version, and `LOCKED` with no version when no policy row exists;
- a family member of the holder is readable;
- another holder is denied for both lists, and each denial leaves a `FAILED` audit row;
- each read leaves `ATTEMPTED` and `COMPLETED` audit rows (`CONSULTATION_HISTORY_READ`, `MRS_DECRYPT`, `OFFICIAL_ARTIFACT_READ`);
- no complaint text reaches the audit;
- artifacts are finalized only, from completed consultations only;
- a bad page or role fails before anything is read or audited.

The `@WebMvcTest` cases run per route through the real security chain and the real service:
- the owner gets 200 with `no-store`;
- the owner's family member gets 200;
- another account's family member gets 404, with a body identical to "unknown id" apart from the timestamp, and MRS is never called;
- another patient's record denied by MRS gets 404;
- unauthenticated gets 401;
- a doctor gets 403;
- MRS down gets 503 `MRS_UNAVAILABLE`;
- a malformed subject gets 400 before resolution;
- `size=500` is capped to 50, `size=0` is 400 `OUT_OF_RANGE`, and a bad cursor is 400.

**Failures outside this change, not fixed:**
- **MRS `artifacts` integration test** (`verification INVALID`). That package has G-1's uncommitted changes (`internal/artifacts/service.go` +80 lines) and doesn't import the new code. G-1 should look at it.
- **MRS ClamAV test.** No scanner is reachable from the host.
- **Spring test compilation.** `src/test/java/com/omnicare/app/followup/` is untracked work from another session, created today, and references a class that doesn't exist yet (`NotificationOutboxWakeup`). I ran the tests from a scratch copy without that folder and did not touch it.
- **8 full-context Spring tests.** The local urgent CABINET startup guard requires "the exact authorized PostgreSQL omnicare database", which Testcontainers doesn't provide.

## 5. Contract per route

All Spring routes use the existing error envelope `{code, message, fieldErrors, fieldErrorCodes}`, are PATIENT only, and send `Cache-Control: no-store`. Common errors: 401 `UNAUTHORIZED`; 403 `FORBIDDEN` (not a patient); 400 `VALIDATION_ERROR` (`fieldErrorCodes.subject|size|cursor|group` = `REQUIRED`/`INVALID_FORMAT`/`OUT_OF_RANGE`); 404 `RESOURCE_NOT_FOUND` (not yours or not found, same body); 409 `CLINICAL_SUBJECT_UNAVAILABLE` (an owned subject with no medical record yet); 503 `MRS_UNAVAILABLE`.

| Method · path | Request | Response 200 |
|---|---|---|
| GET `/api/v1/me/medical-record/medications` | `subject`, `group=CURRENT`(default)`|PAST`, `size`, `cursor` | `{items:[{medicationStatementId, consultationId, name, strength, doseAmount, doseUnit, dosageText, route, timesPerDay, frequencyText, startedOn, expectedEndOn, displayStatus}], nextCursor}` |
| GET `/api/v1/me/medical-record/consultations` | `subject`, `size`, `cursor` | `{items:[{consultationId, completedAt, professional:{firstName,lastName,specialty}\|null, reason, sharingState: LOCKED\|SHAREABLE, sharingPolicyVersion\|null}], nextCursor}` |
| GET `/api/v1/me/medical-record/artifacts` | `subject`, `size`, `cursor` | `{items:[{artifactId, consultationId, artifactType: PRESCRIPTION\|SICK_LEAVE_CERTIFICATE\|MEDICAL_CERTIFICATE\|LAB_ORDER\|IMAGING_ORDER, finalizedAt, professional, renderStatus, pageCount, sizeBytes}], nextCursor}`. Download: the existing `GET /api/v1/patient/consultations/{consultationId}/artifacts/{artifactId}/download?subjectType=…` (unchanged) |
| GET `/api/v1/me/medical-record/medical-data` | `subject` | `{lifeSafety:{bloodType, allergies[], allergiesStatus, criticalConditions[], conditionsStatus}, bodyMeasurements:{heightCm, weightKg, bmi, measuredAt}}`; statuses are `UNKNOWN\|NONE_KNOWN\|LIST` |

**MRS (internal):** headers `X-Actor-Role: PATIENT`, `X-Purpose: SELF_SERVICE|FAMILY_MANAGEMENT`, plus `X-Subject-Mrs-Patient-Id` equal to the path id.

| Route | Scope | Query | 200 | Errors |
|---|---|---|---|---|
| `GET …/consultation-summaries` | `FULL_PASSPORT` | `limit` 1..50 (default 20); `after_at` (RFC 3339) and `after_id` together | `{consultations:[{consultation_id, finalized_at, professional_actor_id, chief_complaint\|null, sharing_state, sharing_policy_version\|null}], has_more}` | 400 `INVALID_INTERNAL_REQUEST`, `INVALID_PAGE`; 403 `ACCESS_DENIED`; 503 `MRS_KEY_UNAVAILABLE`, `AUDIT_UNAVAILABLE`; 500 `INTERNAL_ERROR` |
| `GET …/official-artifacts` | `OFFICIAL_ARTIFACT` | same | `{artifacts:[{artifact_id, consultation_id, artifact_type, artifact_version, finalized_at, professional_actor_id, render_status, page_count, size_bytes}], has_more}` | same |

## 6. Complexity, memory, transactions, privacy
- **Consultations and artifacts:** true keyset pagination in MRS (`(time, id) < cursor`, `LIMIT size+1`).
  - Consultations use `idx_mrs_consultation_finalizations_patient_time`.
  - Artifacts filter on `mrs_patient_id` (per-patient rows, small) and sort in Postgres. There is no dedicated index; add `(mrs_patient_id, finalized_at DESC, id DESC) WHERE status='FINALIZED'` if volume grows.
  - Decryption is O(page) and per page; only the chief complaint string leaves MRS.
- **Medications:** MRS has no paging, so Spring cuts the page from the full list: O(n log n) for n statements of one patient, with all n decrypted in MRS on each page. That's acceptable for one patient's list; a paged MRS route is the follow-up if lists grow.
- **Doctor names:** one SQL query per page (at most 50 ids). There is no N+1: the service builds a `Map<id, ref>` once.
- **Transactions:**
  - Subject resolution runs in its own short read-only transaction (`ProfilePatientSubjectDirectory`).
  - The MRS call runs outside any transaction; the service is deliberately not `@Transactional`.
  - The name lookup is `@Transactional(readOnly = true)`, after the MRS call.
  - MRS reads run in a `ReadOnly` pgx transaction.
- **Logs:**
  - Spring logs `patient_record_read section=… subject=SELF|FAMILY_MEMBER outcome=OK|FAILED code=…`, with the request id from the MDC.
  - The MRS client logs only the status and a sanitized MRS code (`[A-Z0-9_]{1,64}`, else `UNKNOWN`).
  - No ids, names or medical text are logged. No URL carries medical content; ids in the path are opaque UUIDs. No metrics labels were added.

## 7. Risks, open questions, not done
1. **Error code choice: tell me if you want `MEDICAL_RECORD_UNAVAILABLE` instead.** I reused the existing stable `MRS_UNAVAILABLE` (503); the task gave the new code only as an example. Adding a new code means editing `ErrorCode.java`, which still holds G-1's uncommitted `ARTIFACT_NOT_DISCARDABLE`. The app already maps `MRS_UNAVAILABLE` to French text (`api_failure_message.dart`). It's a one-line change either way.
2. **Download edge case.** The existing download route also checks the Spring consultation's requester (`PatientArtifactService.java` `resolve`). An artifact from a consultation recorded under another requester (for example a practice patient claimed later) would be listed but return 404 on download. No case like this exists today; to be checked when authority transfer goes live.
3. **The existing `/profile/medical-data` holds a read-only DB transaction across the MRS call** (`UserProfileService.java:106`). I didn't change it (existing behaviour); the new route doesn't do this.
4. **The existing MRS `consultation-history` route is dead code** (unreachable scope, no audit). G-1 owns it and should remove or fix it.
5. **Family medical data has no legacy fallback.** It comes from MRS only, so a family member with no MRS singleton reads `UNKNOWN`; the app must show « indisponible », never "none".
6. **Specialty is the stored code** from `professional_profiles.specialty`; the app translates it to French via ARB.
7. **No Testcontainers test for `RecordProfessionals`.** Its SQL is copied from `patientchart`, which is tested there. Spring full-context tests are blocked locally by the urgent CABINET database guard.
8. **Not served:** CANCELLED consultations (rule: completed only); per-consultation detail (diagnosis, plan); documents (Phase 5).
9. **Concurrent edit:** `AuthWebSecurityConfig.java` also contains another session's uncommitted G-1 D4 lines (`/me/follow-up-proposals`) right next to mine. See the commit note below.

## 8. Manual test steps for the CTO
These are backend steps: the app doesn't call these routes yet (the Phase 4 app binding does). Use a patient session from the app or the login API; keep the token in a shell variable and never paste it anywhere.
1. Rebuild and restart the MRS API container (`omnicare-mrs-api`) and Spring, so both run this code.
2. As patient A: `GET /api/v1/me/medical-record/consultations?subject=SELF`. Expect 200; completed consultations newest first, each with the doctor's name, the reason and the sharing state; no MRS id anywhere in the body.
3. Repeat with `&size=1`, then pass the returned `nextCursor` as `cursor`. Expect the next consultation, never the same one twice; on the last page `nextCursor` is null.
4. `GET …/artifacts?subject=SELF`. Expect only signed (finalized) documents. Download one with the existing `/api/v1/patient/consultations/{consultationId}/artifacts/{artifactId}/download?subjectType=SELF`. Expect a PDF.
5. `GET …/medications?subject=SELF`, then `&group=PAST`. Expect current, then past treatments.
6. `GET …/medical-data?subject=FAMILY:<id of one of A's family members>`. Expect 200. Then use patient B's family member id, and then a random UUID. Expect 404 with the same `code` and `message` both times.
7. Without the token, expect 401. With a doctor's session, expect 403.
8. Stop the MRS container and repeat step 2. Expect 503 `MRS_UNAVAILABLE`. Restart it.
9. In the MRS database, `mrs_audit_events` shows `ATTEMPTED` and `COMPLETED` rows for your reads (`CONSULTATION_HISTORY_READ`, `MRS_DECRYPT`, `OFFICIAL_ARTIFACT_READ`, purposes `PATIENT_*`) and `FAILED` rows for step 6. The Spring log shows `patient_record_read` lines with no names, ids or medical text.
10. Regression: `GET /api/v1/profile/medical-data` returns the same values as before.

## 9. Path to deliver G-2
1. **You:** review, run section 8, decide on risk 1 (the error code), and commit the two backend repos. Paths and the shared-file caveat are below; the app repo is unchanged by FT-1.
2. **Phase 4, app step:** bind the « Dossier médical » sections to these four routes with honest « indisponible » states. This depends on the 1b-3 §2.3 decision (hide the tab, or design the state); the guard's static-data list then becomes empty. Also stream the PDF to a temp file.
3. **Then:** the rest of Phase 1b, Phase 1c, Phase 5 (documents), Phase 9 (`/masante` aggregate built on these reads), and the release gate.

### Commit note (the user commits)
- **Spring:**
  ```
  git add src/main/java/com/omnicare/app/patientrecord src/test/java/com/omnicare/app/patientrecord src/main/java/com/omnicare/app/profile/service/UserProfileService.java
  ```
  Then `AuthWebSecurityConfig.java`: its hunk mixes my 2 lines with another session's 4 lines. Commit it together with that session, or use `git add -p` → `e` to keep only the `medical-record` lines.
- **MRS:**
  ```
  git add internal/patientrecord internal/api/patient_record.go internal/api/patient_record_test.go internal/api/router.go cmd/mrs-api/main.go
  ```
  Then `git add -p internal/bootstrap/medical_records.go` and take only the `patientrecord` hunks (import, struct field, `PatientRecord:` line); the other hunks are G-1's.
