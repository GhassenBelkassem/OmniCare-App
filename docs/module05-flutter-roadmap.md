# Module 05 — Flutter Patient Request Roadmap

Continuity reference for the OmniCare **Flutter** side of Module 05. Decisions and boundaries
only. The backend roadmap lives in `OmniCare-BackEnd/docs/module05-request-roadmap.md` and is not
duplicated here.

Status: **M05-F01 ✅ APPROVED**. **M05-F02 implemented and verified** — real
patient Clinic selection and submission UX. **M05-F03 ✅ APPROVED**.

M05-F03 provides backend-paginated My Requests, authoritative detail,
centralized patient-safe status copy, backend-driven CANCEL with the observed
version, 409 authoritative refresh (without automatic cancellation retry), and
F02 success-to-detail navigation. The active patient home care section exposes
the `Mes demandes` entry and routes to `/m05/requests`. MRS medical context
remains deferred for V1 and no legacy reservation layer is used.

---

## 1. Architecture

Feature-first, mirroring `lib/features/clinic/`. Provider / `ChangeNotifier` only; no new state
management technology.

```
lib/features/request_core/
  domain/       request_vocabulary.dart      typed wire enums
                request_subject.dart         SELF / FAMILY_MEMBER value model
                clinic_request_intent.dart   clinic id + subject (value equality)
  identity/     request_operation_id.dart    requestId value type + factory
                in_flight_request_store.dart versioned secure retry record
  data/         request_models.dart          immutable wire models
                request_failure.dart         RequestFailure / RequestFailureKind
                request_api.dart             transport, shared AppHttpClient required
                request_repository.dart      API -> domain, errors -> RequestFailure
  application/  request_submission_controller.dart  ChangeNotifier, one logical submission
```

Shared helper extracted to `lib/core/utils/uuid_v4.dart` (`generateUuidV4`, `isCanonicalUuid`);
`DeviceIdentityService` now uses it instead of its private copy. No UUID package was added.

Layering matches the Flutter architecture guide (view model → repository → service) using the
project's existing, more specific naming: `application/` holds the controller, `data/` holds the
repository and the transport service.

## 2. Shared HTTP client

`RequestApi(AppHttpClient)` — required positional dependency. There is **no** optional parameter
and no `?? AppHttpClient(tokenStore: SecureTokenStore())` fallback. That legacy pattern (still in
`AccountApi`, `FamilyApi`, `FilesApi`) creates a second Dio, a second `AuthInterceptor` and a second
`AuthRefreshCoordinator`, which means two refreshes racing for one rotating refresh token. Module 05
is registered in `main.dart` against the single `AppHttpClient` built there. Legacy API classes were
deliberately not refactored in this milestone.

No `LogInterceptor`. No request or response body is logged anywhere in the module.

## 3. requestId lifecycle

`RequestOperationId` is the identity of one logical submission, not of one HTTP call.

| Event | Operation id |
|---|---|
| new logical request (`beginNewRequest`) | new |
| intent changed **before** any attempt | unchanged |
| intent changed **after** an attempt | rotated (it is a different submission) |
| HTTP timeout | same |
| connection failure | same |
| 401 → refresh → retry | same (Dio replays the original body) |
| `201` created | same, operation finished |
| `200` replayed | same, operation finished |
| `409 REQUEST_IDEMPOTENCY_CONFLICT` | same, and burned — never silently rotated |

The controller enforces single-flight submission, a generation counter, a per-operation
`CancelToken` and a stale-response guard, following `ClinicContextController`.

## 4. Secure in-flight persistence

`InFlightRequestStore`, versioned (`omnicare_request_inflight_v1`, schema 1),
`flutter_secure_storage` via `SecureTokenStorageBackend` — never `SharedPreferences`.

Stored: `requestId`, `kind`, `clinicId`, `subjectType`, `familyMemberId?`,
`situation`, and the exact confirmed ambulance pickup when applicable. Schema
2 is deliberate: it lets an ambiguous ambulance retry reuse the original
coordinates/address and `capturedAt` without reacquiring GPS.
Never stored: medical text, symptoms, diagnosis, documents, patient profile, `patientId`,
`mrsPatientId`, tokens.

The record is written *before* the POST and cleared *after* the response is captured. A retryable
failure keeps it; a terminal failure (including idempotency conflict) drops it. Any record that is
unreadable, of another schema version or structurally inconsistent is deleted, not repaired.

Intent drift is detected by value equality on `ClinicRequestIntent` rather than a client-side hash:
it answers the same question with no extra dependency and no opaque persisted value. The server
keeps its own authoritative SHA-256 fingerprint, which the client cannot and must not recompute.

## 5. Verified API contracts

Base URL already contains `/api/v1`. Verified against the backend records, not inferred.

| Call | Contract |
|---|---|
| `GET /patient/clinics` | `q?`, `city?`, `page`, `pageSize`; patient-only active Clinic Slice `{contractVersion, items, page, pageSize, hasNext}` |
| `GET /patient/clinics/{clinicId}` | `{clinicId, displayName, about?, city?, governorate?, address?, primaryImageUrl?, acceptingRequests, gallery:[{imageUrl}]}` |
| `POST /appointment-requests/clinic` | body `{requestId, clinicId, situation, subject:{type[, familyMemberId]}, pickupLocation?}`; **201** created, **200** replayed, identical bodies |
| `GET /appointment-requests` | `page`, `pageSize` query params; server clamps to `[1,50]`, default 20 |
| `GET /appointment-requests/{requestId}` | detail; a foreign id answers 404 like a missing one |
| `POST /appointment-requests/{requestId}/cancel` | body `{expectedVersion}` (mandatory) |

Response shapes:

- submit → `requestId, clinicId, kind, situation, patientStatus, submittedAt, version`
- detail/cancel → `requestId, kind, targetType, targetId, subjectType, situation, patientStatus,
  submittedAt, cancelledAt, version, availableActions`
- list → `contractVersion ("1.0"), items[], page, pageSize, hasNext` — deliberately no total count
- `Instant` → ISO-8601 string (Spring Boot default, `WRITE_DATES_AS_TIMESTAMPS` disabled)
- `availableActions` → JSON array of strings, `[]` when none
- `version` → JSON number (`long`), echoed back as `expectedVersion`
- created-vs-replayed comes from the **status code**, never from the body

Unknown status/kind/target values degrade to `unknown`; unknown actions are dropped so they can
never render as a control.

## 6. Subject-ID rule

`familyMemberId` is the only identifier this app may put in a request subject, and it is a claim,
not a grant: the backend re-resolves ownership from the authenticated principal.

- `SELF` → `{"type":"SELF"}`, the key is omitted entirely.
- `FAMILY_MEMBER` → `{"type":"FAMILY_MEMBER","familyMemberId":<FamilyMember.id>}`.
- Never sent: `FamilyMember.patientId`, `mrsPatientId`, `accountHolderId`.
- There is no "other person" mode in Module 05.

`RequestSubject.forFamilyMember(FamilyMember)` is the preferred constructor because it removes the
opportunity to pass the wrong field. The legacy emergency flow still sends `patientId`; it is
untouched and is not a precedent.

## 7. Failure mapping

`RequestFailure` / `RequestFailureKind`, modelled on `ClinicFailure`. Only RFC 9457 `errorCode` is
read; `detail`, `title`, `instance`, `type`, `timestamp` and the backend correlation `requestId` are
ignored. Messages are local constants; `error.toString()` is never shown to a patient.

| Server | Kind | Retryable |
|---|---|---|
| `REQUEST_SUBJECT_FORBIDDEN` (403) | `subjectForbidden` | no |
| `REQUEST_TARGET_UNAVAILABLE` (422) | `targetUnavailable` | no |
| `REQUEST_INVALID` (400) | `invalid` | no |
| `REQUEST_VERSION_CONFLICT` (409) | `versionConflict` | no — re-fetch |
| `REQUEST_TRANSITION_INVALID` (409) | `transitionInvalid` | no — re-fetch |
| `REQUEST_IDEMPOTENCY_CONFLICT` (409) | `idempotencyConflict` | no — terminal for that id |
| `REQUEST_NOT_FOUND` (404) | `notFound` | no |
| 401 | `sessionExpired` | no |
| 5xx | `server` | yes |
| timeouts | `timeout` | yes |
| connection error | `network` | yes |
| malformed payload | `contract` | yes |
| local cancel | `cancelled` | no |

Cancellation: keep the observed `version`, send it as `expectedVersion`. On `versionConflict` the
future detail controller must re-fetch current state — never retry blindly with a guessed version.

## 8. Security rules

No logging of request bodies, patient / family / clinic identifiers or fingerprints. No raw
`DioException` reaches the UI. No medical content is stored or sent. `patientId` and `mrsPatientId`
are never emitted. No client-side authorization is trusted. No direct document upload. No mock
success anywhere — there is no `useMock()` / `useApi()` switch. `toString()` on every Module 05
type is identifier-free. A source-scanning test enforces these guarantees.

## 9. Performance rules

No API call from `build()`. No polling, no `Timer.periodic`. No GET after a successful POST — the
POST response already describes the request. `CancelToken` cancels superseded calls. Bounded list
contract only, no materialized request history. Immutable models. No caching before measured need.

## 10. M05-F02 implemented flow

`Who needs care` → `Choose clinic` → `Situation` → `Pickup` (AMBULANCE only)
→ `Review` → `Request received`.

- Subject selection supports only SELF and an owned `FamilyMember.id`; Continue
  is explicit.
- The real patient Clinic directory debounces/cancels search, uses backend
  Slice pagination, opens a full detail/gallery screen, and does not display
  ratings, prices, reviews, rankings, or services. Unavailable Clinics remain
  readable but cannot be selected/submitted.
- Situation uses exact values `APPOINTMENT`, `URGENT`, `AMBULANCE`; it is an
  explicit patient choice, never inferred.
- Ambulance pickup supports explicit one-shot DEVICE_GPS confirmation,
  MAP_SELECTION through the already-configured Google Maps integration, and
  bounded MANUAL_ADDRESS (`addressLine`, `addressDetails?`, `city`,
  `governorate?`). GPS is never requested in `initState`, never streamed, and
  no coordinates are logged. No medical context, body areas, pain, symptoms,
  or patient description exist in the V1 UI or payload.
- Success is only HTTP 201/200 and renders the safe `REQUEST_RECEIVED`
  semantics. There is no detail/history/cancel UI here.

## 11. Milestones

| Milestone | Scope | State |
|---|---|---|
| **M05-F01** | Request core: vocabulary, subject, operation id, secure in-flight store, API, wire models, failure model, repository, submission controller, DI, logout teardown, tests | **✅ APPROVED** |
| **M05-F02** | V1 Clinic flow, real directory/detail/gallery, situation, ambulance pickup, idempotent submission and success semantics | **implemented — verification recorded below** |
| **M05-F03** | Request list + authoritative detail + backend-authorized cancellation UI | **✅ APPROVED** |

## 12. Historical blockers (resolved for F02)

1. Patient-safe Clinic directory is available at `/patient/clinics`; F02 uses
   it and never uses `/me/clinics`, admin Clinic endpoints, or removed targets.
2. Patient request routes are used through the shared authenticated client.

## 13. Verification

F02 verification runs `dart format`, focused request/directory tests, `flutter
analyze`, and `git diff --check`.

F03 final verification: 70 Module 05 tests passed, including deterministic
controller stale-response/duplicate-pagination coverage, 409 authoritative
refresh/no-retry coverage, cancellation ambiguity/redaction coverage, request
list/detail widget coverage, and active-home navigation coverage. The
auth/Clinic regression suite passed 76 tests. Scoped F03 analysis has zero
issues (including zero `curly_braces_in_flow_control_structures` advisories).
Full-project analysis has zero compile errors and 534 unrelated legacy/project
advisories. Privacy checks confirm no patient-facing raw identifiers, pickup,
MRS data, payloads, tokens, or raw transport/server errors; list/detail access
remains bounded and lazy with no per-row Clinic, family, or detail requests.

Patient-navigation integration correction: the active Home Clinic card had
still targeted the obsolete `/clinic-request` form and the center OmniCare care
chooser omitted Clinic. Both now use the shared four-destination presentation
registry and route Clinic to canonical `/m05/request` (M05-F02). The existing
patient header and bottom navigation own a nested authenticated content stack
for the chooser and M05 request/list routes, so they remain visible through
normal M05 navigation. M05-F02 and M05-F03 remain approved.
