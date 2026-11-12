# G2 FT-2: Patient documents: list and status contract (MRS-02), plus the signature check

**Date:** 2026-11-11 · **Repos:** OmniCare-BackEnd (Spring), omnicare-mrs (Go; tests only) · **App:** not changed

## 1. Goal card and status

> GOAL G-2: Connect the patient Flutter app to the real backend without changing the current UI, with a report at every step.
> Done when every patient screen reachable from production main.dart shows real data or an honest "indisponible" state (no fixture, no mock), the release build passes the G-2 gate (§8), and every step has a report in OmniCare-App/docs/reports/G2/.

| Item | Status |
|---|---|
| Patient documents **list** and **status** in Spring (`/api/v1/me/medical-record/documents…`) | ✅ done, tested |
| MRS list and status (keyset, max 50, audited) | ✅ **already in MRS** (G-1 commit `cd206f9`); I proved the patient path with DB tests; no new routes added (§3a) |
| Dead Spring call to the missing MRS `…/events` route | ✅ removed, with the whole SSE chain |
| Upload limit: one value, 15 MB, pdf/jpg/png | ✅ already true in Spring and MRS; the app allows 20 MB (reported, not changed) |
| Security check: does the signature cover the actor/purpose/subject headers? | ✅ **Yes**, both sides (§4) |
| **Patient viewing** | ⛔ **STOP**: there is no patient viewing path in Spring or MRS (§3c) |
| IDOR-01 (clinician document requests) | Reported, not changed (§7) |

## 2. Plan: what I found before editing

### 2a. Every Spring → MRS documents call

| Spring call (file:line) | MRS route | Served? |
|---|---|---|
| `POST …/documents/init` (`HttpMrsDocumentClient.java:117`) | `documents.go:66` | ✅ |
| `POST …/documents/{id}/content` (`:142`) | `:68` | ✅ |
| `GET …/documents/uploads/recovery` (`:194`) | `:67` | ✅ |
| `GET …/documents?limit&cursor` (`:232`) | `:64` | ✅ **now** (added by G-1 in `cd206f9`, after P0) |
| `GET …/documents/{id}/status` (`:281`) | `:65` | ✅ **now** (same commit) |
| `DELETE …/documents/{id}` (`:323`) | `:72-75` | ✅ |
| `GET …/documents/{id}/events` SSE (`HttpMrsDocumentEventClient.java:75`) | — | ❌ **no such route**: the only dead call |
| View sessions and pages (doctor chart only, `patientchart/mrs/HttpMrsPatientChartClient.java:259-290`) | `:69-71` | ✅ for doctors; never for patients (§3c) |

### 2b. What the existing documents screen needs
`MedicalDocumentsScreen` reads `MedicalDocumentRecord` (`documents_api.dart:16-37`): id, documentType, status, fileMimeType, fileSizeBytes, pageCount, createdAt and updatedAt. It shows the raw type enum, because there is no title (C19). MRS already returns a `title` (the user-entered title, else the file name; `list.go:109-117`), but Spring's client dropped it. The new route returns it. The screen also polls nothing: it opens the SSE stream (`medical_documents_screen.dart:524` → `documents_api.dart:526`), which has never worked, because MRS has no events route.

### 2c. Upload limits per layer

| Layer | Size | Types | Where |
|---|---|---|---|
| App | **20 MB** | pdf, jpg, jpeg, png | `documents_api.dart:299`, `medical_documents_screen.dart:243` |
| Spring | 15 MB (multipart 15 MB file / 16 MB request) | application/pdf, image/jpeg, image/png, plus an extension match | `DocumentService.java:28,32-35,244-250,291-293`; `application.yaml:7-8` |
| MRS | 15 MB (`MRS_DOCUMENT_MAX_FILE_BYTES`), at most 100 PDF pages, gateway body 16 MB | pdf, jpeg, png, with magic-byte check | `config.go:289,341,345`; `validator.go:147-152,220-238`; `.env.example:101` |

Spring and MRS already agree on 15 MB, so nothing was changed. The app's 20 MB lets a 15–20 MB file reach Spring, which then rejects it with `FILE_TOO_LARGE`. Fix the app constant in the app step (FT-3).

### 2d. How viewing works today
Viewing goes through MRS view sessions: watermarked pages rendered one by one, and raw download is blocked (`DocumentController.java` `denyRawDownload`).
- **Who can open one:** MRS allows it only for a **doctor**, with a document-view grant, a chart GRANTED access with the DOCUMENTS section, or chart custody (`view_authority.go:26-58`). Every page re-checks that authority (`:62-89`).
- **Spring:** only the doctor chart calls it (`PatientChartService.java:437-439`).
- **Patient:** there is no patient route in Spring, and MRS refuses PATIENT.

## 3. Decisions

### 3a. MRS list and status: reused, not duplicated
The task asked for new additive MRS routes in their own package, on the premise that they don't exist. They do exist, with exactly the requested properties:
- **Paging:** keyset `(created_at, id)`, default 20, max 50 (`list.go:20-23,154`; `list_repository.go:43-51`).
- **Transaction:** read-only (`list.go:186,241`).
- **Access:** PATIENT is allowed when they are the account holder, so a family member works (`authorization.go:55-73`); deleted documents are hidden.
- **Audit:** every read is audited as attempted / completed / failed with purpose and scope (`list.go:166,239`).

A second copy would be duplicate code, against §5. So I kept them, and added the patient-path DB tests that were missing; the existing tests only covered the doctor/chart path (`chart_integration_test.go:173`). No MRS production code changed.

### 3b. SSE: removed, clients poll status
Following the roadmap (Phase 5: "drop the SSE events route and poll status with backoff"), I removed the Spring relay instead of rebuilding it on server-side polling, which would mean one long-lived connection per watcher. Removed:
- Spring endpoint `GET /api/v1/documents/{id}/events`;
- `HttpMrsDocumentEventClient`, `DocumentEventSource`;
- `DocumentEventStreamService`, `DocumentEventConnectionLimiter`, `DocumentEventStreamingConfiguration` (virtual-thread async executor, used by nothing else; `MrsProperties` stays registered by `@ConfigurationPropertiesScan`, `OmniCareBackEndApplication.java:10`);
- two YAML keys.

The app's orphaned screen still calls the removed endpoint, but that call never worked. FT-3 replaces it with polling of the new status route (backoff: 2 s → 4 s → 8 s, capped at 30 s, stop on AVAILABLE or SCAN_FAILED).

### 3c. ⛔ STOP: patient viewing
The task says "viewing stays on the existing view-session path". **There is no existing patient path.** MRS view sessions are doctor-only by design (§2d). Letting a patient view would need:
1. a new MRS rule in `internal/documents/view_authority.go`, a PATIENT account holder opening a session with no grant;
2. a new Spring patient route that creates a session and streams watermarked pages;
3. a watermark text for patients.

Item 1 changes the authority code of G-1's chart document access, and none of the three is specified. I didn't design them.

**Decision needed:**
- **A** (recommended): a small follow-up task FT-2b for "patient views own document", with G-1 owning the `view_authority.go` change. It reuses the existing page rendering; the watermark shows the patient's own name or id and the date.
- **B:** documents stay list-only in V1. The app shows the list and status, and « Aperçu indisponible » on tap, an honest state.

## 4. Security check from the FT-1 review: ✅ covered, no STOP
- **Spring signs them.** Spring's canonical request includes `x-request-id`, `x-actor-id`, `x-actor-role`, `x-subject-mrs-patient-id`, `x-purpose`, `x-scope` and `idempotency-key`, plus method, target, timestamp, nonce and body digest (`MrsGatewayRequestSigner.java:208-231`). It is applied as an interceptor on `mrsRestClient` (`MrsClientConfiguration.java:32-42`); the document client's list and status calls use that client (`HttpMrsDocumentClient.java:76-81,235,285`).
- **MRS checks the same string.** It rebuilds the identical lines (`serviceauth/protocol.go:35-47`) and verifies them in the router's `authenticate` middleware when `MRS_AUTH_MODE=trusted_gateway` (`cmd/mrs-api/main.go:69-92`).
- **Production can't run unsigned:**
  - MRS refuses to start without `trusted_gateway` (`config.go:480`) and TLS (`config.go:474`), and rejects `development_headers` outside development (`config.go:442`).
  - Spring refuses to start without the HMAC key outside local/dev/test (`MrsGatewayRequestSigner.java:81-88`).
- **Residual (not a STOP):** in local, dev and test both sides run unsigned by design.

## 5. What changed

### OmniCare-BackEnd
| File | Change |
|---|---|
| `patientrecord/api/PatientMedicalRecordController.java` | +2 routes: `GET /documents`, `GET /documents/{documentId}/status` |
| `patientrecord/api/PatientMedicalRecordDtos.java` | + `DocumentItem` and `DocumentPage` (with `title`; no MRS id) |
| `patientrecord/application/PatientMedicalRecordService.java` | + `documents` and `documentStatus`. Same flow as FT-1: validate, resolve the subject, call MRS outside any transaction, log. Error mapping: a denial is the same 404; a rejected cursor is a field error; anything else is the plain `MRS_UNAVAILABLE` envelope |
| `patientrecord/application/RecordRequestParams.java` | + `documentCursor` (the MRS opaque cursor passed through; shape-checked: base64url, at most 200 characters) |
| `mrs/MrsDocumentClient.java` | `DocumentSummary` + `title`; subject-aware `listPatientDocuments` / `getPatientDocumentStatus` (the old signatures delegate as SELF) |
| `mrs/HttpMrsDocumentClient.java` | Reads `title` (blank or over 512 characters reads as absent). Purpose is `FAMILY_MANAGEMENT` for a family member, `SELF_SERVICE` for SELF |
| `profile/controller/DocumentController.java` | − the SSE `/events` endpoint and its dependencies |
| `mrs/DocumentEventSource.java`, `mrs/HttpMrsDocumentEventClient.java`, `profile/service/DocumentEventStreamService.java`, `profile/service/DocumentEventConnectionLimiter.java`, `profile/config/DocumentEventStreamingConfiguration.java` | **Deleted** |
| `resources/application.yaml` | − `event-stream-max-connections*`; `event-stream-timeout` is kept with a comment (see §7, item 4) |
| Tests | WebMvc (50, was 34), service (11, was 9), new `HttpMrsDocumentClientPatientSubjectTest` (2), `DocumentServiceTest` and `DocumentUploadRecoverySecurityWebMvcTest` adjusted |

### omnicare-mrs
| File | Change |
|---|---|
| `internal/documents/patient_list_integration_test.go` | **New.** 4 DB tests on the patient path. No production change |

## 6. Contract per route

These follow FT-1's rules: PATIENT only; `subject=SELF|FAMILY:{familyMemberId}` (the app never sends an MRS id); `Cache-Control: no-store`; the `{code, message, fieldErrors, fieldErrorCodes}` envelope; logs `patient_record_read section=DOCUMENTS|DOCUMENT_STATUS subject=… outcome=… code=…`.
- **Common errors:** 401 `UNAUTHORIZED`; 403 `FORBIDDEN` (not a patient); 400 `VALIDATION_ERROR` (`fieldErrorCodes.subject|size|cursor`); 404 `RESOURCE_NOT_FOUND` (foreign subject, another patient's record or document, deleted document: same body); 409 `CLINICAL_SUBJECT_UNAVAILABLE`; 429 `TOO_MANY_REQUESTS`; 503 `MRS_UNAVAILABLE`.

| Method · path | Request | 200 |
|---|---|---|
| GET `/api/v1/me/medical-record/documents` | `subject`, `size` (default 20, capped at 50), `cursor` (opaque, from the previous page) | `{items:[{documentId, documentType, title, status, contentType, sizeBytes, pageCount, createdAt, updatedAt, uploadCompletedAt, scanCompletedAt}], nextCursor}`. Newest first; deleted documents never listed |
| GET `/api/v1/me/medical-record/documents/{documentId}/status` | `subject` | one `DocumentItem`. `status`: `UPLOAD_INITIATED`, `SCAN_PENDING`, `AVAILABLE` or `SCAN_FAILED`. Poll while not `AVAILABLE`/`SCAN_FAILED` |
| ~~GET `/api/v1/documents/{id}/events`~~ | — | **removed** (never worked) |

The MRS internal routes are unchanged and reused: `GET /internal/mrs/patients/{id}/documents?limit=1..50&cursor=` → `{documents:[{document_id, document_type, status, content_type, size_bytes, page_count, created_at, updated_at, upload_completed_at, scan_completed_at, title}], next_cursor}`; `GET …/documents/{documentId}/status` → one summary. Errors: 400 `INVALID_DOCUMENT_LIST_REQUEST`, 403 `DOCUMENT_ACCESS_DENIED`, 404 `DOCUMENT_NOT_FOUND`, 503 audit or key unavailable. Headers sent: `X-Actor-Role: PATIENT`, `X-Purpose: SELF_SERVICE|FAMILY_MANAGEMENT`, `X-Scope: FULL_PASSPORT`, signed (§4).

## 7. Risks, findings, not done
1. **Patient viewing: STOP, decision needed (§3c).**
2. **IDOR-01, reported only.** `POST /api/v1/document-requests` lets any clinician role create a request for any `patientId` and `consultationId`, with no check that they treat the patient or own the consultation (`DocumentRequestController.java:33-48`, `DocumentRequestService.java:33-43`). The response uses the placeholder `"Dr. TODO"` (`DocumentRequestService.java:91`). **Today the whole `/api/v1/document-requests/**` tree is unreachable:** it has no security matcher, so `anyRequest().denyAll()` blocks it (`AuthWebSecurityConfig.java:286`). The flaw goes live the day someone adds a matcher. Fix the ownership check before that.
3. **App limit is 20 MB vs 15 MB in Spring and MRS** (§2c). Fix in FT-3.
4. **`omnicare.mrs.event-stream-timeout` is now unused** but still declared in `MrsProperties`. G-1's `MedicalSharingComposedIntegrationTest.java:235-244` builds `MrsProperties` with that component, so removing it means editing a G-1 file. Remove it together with G-1.
5. **Legacy `GET /api/v1/documents`** accepts `limit` 51–100 (`DocumentService.java:29-30,156-157`), which MRS now rejects as a 400. Not changed (existing route); the app moves to the new route in FT-3.
6. **MRS audit type:** list and status are audited as `MRS_DECRYPT` (the title is decrypted) with purpose and scope, not as a dedicated "document list" type. That's acceptable; noted for audit reporting.
7. **Concurrent edits:**
   - `application.yaml` has G-1's uncommitted hunks besides my one hunk (the SSE keys).
   - `patientrecord/**` is still uncommitted from FT-1.

## 8. Evidence

| Command | Result |
|---|---|
| `go vet ./internal/documents ./internal/api` | clean; gofmt clean |
| `MRS_TEST_DATABASE_URL=… go test ./internal/documents ./internal/api ./internal/serviceauth` (throwaway `postgres:16`, removed afterwards) | api ok, serviceauth ok; documents ok **except** `TestClamAVScannerDetectsEICAR` (no scanner reachable; environment). Rerun without it: ok |
| New MRS patient-path DB tests (4) | **4/4 pass** |
| Spring `patientrecord.**`, `mrs.*`, `profile.**` | **178 run, 0 failures, 0 errors** |
| Spring `auth.**`, `access.**`, `artifact.**`, `patientchart.**` (because a `WebMvcConfigurer` was removed) | 559 run, 0 failures, 8 errors: the known local urgent CABINET database guard ("requires the exact authorized PostgreSQL omnicare database"), same as FT-1 |

The MRS DB tests cover:
- the holder's list newest first across 2 pages, with titles;
- a limit above 50 rejected;
- the family member of the holder allowed;
- another holder denied, and the holder denied on another record;
- status for their own document OK;
- another patient's document under their own record: not found;
- audit rows: 2 ATTEMPTED, 1 COMPLETED, 1 FAILED, all with purpose `SELF_SERVICE` and scope `FULL_PASSPORT`.

The Spring `@WebMvcTest` runs these per route, for both document routes too:
- owner OK;
- own family member OK, with `FAMILY_MANAGEMENT` sent;
- foreign family member 404, the same body as unknown, and MRS never called;
- other patient 404, from an MRS denial;
- another patient's document id under one's own record: 404;
- no login 401;
- doctor 403;
- MRS down 503 `MRS_UNAVAILABLE`;
- malformed subject or cursor 400.

The Spring tests ran from a scratch copy without the untracked `followup/` tests of another session; they reference a class that doesn't exist yet and block test compilation in place.

**Manual check:** no command-line steps, as asked. You check through the app after FT-3b (documents list with names, upload, the status changing to available, family member switch).

## 9. Path to deliver G-2
1. **You:**
   - decide §3c (A: FT-2b patient viewing with G-1; or B: list-only with « Aperçu indisponible »);
   - commit FT-1 and FT-2 (commands below);
   - ask G-1 to drop `eventStreamTimeout` from their test (§7, item 4).
2. **FT-3 (app):** bind the passport and Ma Santé documents sections to `/me/medical-record/documents`. Show the title (C19), replace SSE with status polling with backoff, set the upload limit to 15 MB, use cursor paging, and show honest states.
3. **Then:** FT-3b (your check in the app), Phase 4 passport binding (after the 1b-3 §2.3 decision), Phase 6 push, and the release gate.

### Commit note (the user commits)
- **Spring (FT-1 and FT-2 together; all `patientrecord` work is still uncommitted):**
  ```
  git add src/main/java/com/omnicare/app/patientrecord src/test/java/com/omnicare/app/patientrecord src/main/java/com/omnicare/app/profile/service/UserProfileService.java src/main/java/com/omnicare/app/mrs/MrsDocumentClient.java src/main/java/com/omnicare/app/mrs/HttpMrsDocumentClient.java src/main/java/com/omnicare/app/profile/controller/DocumentController.java src/test/java/com/omnicare/app/mrs/HttpMrsDocumentClientPatientSubjectTest.java src/test/java/com/omnicare/app/profile/service/DocumentServiceTest.java src/test/java/com/omnicare/app/profile/controller/DocumentUploadRecoverySecurityWebMvcTest.java
  git rm src/main/java/com/omnicare/app/mrs/DocumentEventSource.java src/main/java/com/omnicare/app/mrs/HttpMrsDocumentEventClient.java src/main/java/com/omnicare/app/profile/service/DocumentEventStreamService.java src/main/java/com/omnicare/app/profile/service/DocumentEventConnectionLimiter.java src/main/java/com/omnicare/app/profile/config/DocumentEventStreamingConfiguration.java
  git add -p src/main/resources/application.yaml
  ```
  In `application.yaml`, take only the `event-stream` hunk. For `AuthWebSecurityConfig.java`, see the FT-1 note.
- **MRS:** `git add internal/documents/patient_list_integration_test.go`, plus the FT-1 paths listed in the FT-1 report.
