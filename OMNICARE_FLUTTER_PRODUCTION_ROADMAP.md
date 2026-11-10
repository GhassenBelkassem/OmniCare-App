# OmniCare Flutter Production Hardening Roadmap

Roadmap date: 2026-11-08  
Launch-scope decision date: 2026-11-09  
Repository: `OmniCare-App`  
Baseline branch/commit: `deployrailway` / `ff88c76`  
Source audit: `OMNICARE_FLUTTER_PRODUCTION_AUDIT.md`  
Phase 0 status: **COMPLETE — GOVERNANCE APPROVED**

This document is the execution contract for production hardening. It does not implement F-01 through F-17, alter application behavior, redesign the approved UI/UX, replace Provider/ChangeNotifier, change backend contracts, or authorize lower-priority cleanup ahead of clinical correctness.

## Current launch-scope decision

**Urgent HOME — DEFERRED / FAIL-CLOSED.** Urgent HOME is not launch-critical for the current production release. The launch invariant is: **Unavailable is acceptable; fabricated clinical success is not.**

| Boundary | Current launch status |
|---|---|
| Flutter Phase 1 | **COMPLETE FOR CURRENT LAUNCH SCOPE — URGENT HOME FUNCTIONALITY DEFERRED** |
| Production safety | **COMPLETE** |
| Urgent HOME feature functionality | **DEFERRED** |
| Backend B1 | **COMPLETE / DORMANT** |
| Backend B2-B8 | **DEFERRED — resume only through explicit CTO/product scope decision** |
| Flutter Phase 1B | **DEFERRED — resume only through explicit CTO/product scope decision** |
| Next active roadmap phase | **Phase 2 — Auth & Network Resilience** |

For the current launch, production Flutter must route Urgent HOME to the approved unavailable state. It must not reach synthetic matching, show demo Doctors, fabricate Doctor acceptance, travel or arrival, create mock consultation success, or expose an actionable state implying that Urgent HOME works. Backend production HOME capability remains disabled and advertises no supported production states or actions while disabled. Synthetic/dev implementations remain available only through explicit test/development injection.

The completed Backend B1 implementation, Module 04 Amendment v1.2, P4/P5 ownership decisions, production contract certification, protected intake foundation, future B2-B8 roadmap, and Flutter Phase 1B plan are retained as historical and future-scope evidence. They are all **DEFERRED — resume only through explicit CTO/product scope decision**. Later hardening phases must not depend on Urgent HOME being enabled.

## 1. Mission

Transform the existing OmniCare Flutter client into a production-ready Android/iOS healthcare application without redesigning the approved UX and without unnecessary architecture rewrites.

The sequence is deliberate:

```text
clinical correctness
  -> network and authentication resilience
  -> lifecycle and recovery
  -> deterministic release engineering
  -> architecture/state convergence
  -> realtime/cache/observability
  -> integration and physical-device evidence
  -> performance/accessibility/localization
  -> controlled modernization
  -> staged production rollout
```

No phase may claim completion solely from static inspection when its acceptance criteria require runtime, signed-build, backend-connected, or physical-device evidence.

## 2. Current baseline

### Audit baseline

- Readiness: **3.5/10 — NOT READY**.
- Confirmed blockers: F-01 through F-06.
- Confirmed high/medium findings: F-07 through F-17.
- The audit remains the evidence source for finding details, file/line references, consequences, and validation procedures. This roadmap does not reinterpret or downgrade them.

### Repository and toolchain baseline

| Item | Phase 0 baseline |
|---|---|
| Branch | `deployrailway` |
| Commit | `ff88c76` — `feat(deploy): add Railway Flutter web deployment` |
| Initial status | Audit report untracked; no tracked application-source change present before Phase 0 edits |
| Flutter | **3.41.2**, stable channel, framework revision `90673a4eef` |
| Dart | **3.11.0**, stable |
| DevTools | 2.54.1 |
| Dart constraint | `^3.11.0` |
| Application version | `1.0.0+1` |
| Android | minSdk 24; compileSdk 36; targetSdk 36 under Flutter 3.41.2 |
| Java/Kotlin bytecode | Java 17 / Kotlin JVM target 17 |
| Local JDK reported by doctor | OpenJDK 21.0.11 |
| iOS | Deployment target 14.0 |
| SDK pin before Phase 0 | None for local/mobile; Docker web image alone used Flutter 3.41.4 |
| SDK pin added in Phase 0 | Exact `environment.flutter: 3.41.2`; existing Docker image aligned from 3.41.4 to 3.41.2 |

The exact engineering baseline is:

```text
Flutter: 3.41.2
Dart: 3.11.0
Channel: stable
```

The repository already uses `pubspec.yaml` and a pinned Docker image, so Phase 0 uses those mechanisms rather than introducing FVM, mise, or asdf. The exact Flutter environment constraint makes incompatible local/CI dependency resolution fail; the Docker adjustment removes the known checked-in toolchain mismatch. Mobile CI must install this exact version when Phase 4 is implemented.

### Production entrypoint classification

Exactly one Phase-1 production entrypoint is declared: **`lib/main.dart`**.

| Entrypoint | Classification | Evidence/constraint |
|---|---|---|
| `lib/main.dart` | **PRODUCTION** | Full configuration, auth, shared networking, providers, realtime, notifications, and patient/doctor/clinic routing. Default `flutter run/build` target. |
| `lib/main_demo.dart` | DEMO | Web-only static demo, demo auth/token storage, custom fake Dio adapter, invalid static backend URL. Must never produce a production artifact. |
| `lib/main_doctor_urgent_cabinet_preview.dart` | PREVIEW | Debug-gated doctor cabinet fixture preview. |
| `lib/main_maps_smoke.dart` | TEST/SMOKE | Synthetic maps smoke screen only. |
| `lib/main_p4_cabinet_synthetic.dart` | DEVELOPMENT | Starts the production shell with an explicit synthetic submission activation gate. Must never be selected for production. |
| `lib/main_p4_recovery_preview.dart` | PREVIEW | Debug-only recovery fixture and local decision source. |

Demo/preview code is not imported back into `lib/main.dart` through those alternate entrypoints. The Phase 1A historical audit proved that the baseline production route chain defaulted to demo Doctor matching, mock `ConsultationsApi` success, and a synthetic-default `ReservationProvider`. The current production entrypoint no longer registers those paths: Urgent HOME review and stale/direct legacy routes fail closed at `ClinicalFeatureUnavailableScreen`; the root synthetic reservation provider is absent; matching requires explicit non-production source injection. The full baseline evidence is retained in Phase 1A below.

### Configuration baseline and classification

| Configuration | Current injection | Class | Phase 0 rule |
|---|---|---|---|
| `OMNICARE_API_BASE_URL` | Compile-time Dart define; Docker build argument forwards it | C — environment-specific public client configuration | Required in release; production must use an approved HTTPS host. Current code fails closed when absent but does not enforce a host allowlist. |
| Debug API fallback | `AppEnvironment` platform-specific localhost fallback | A — public development configuration | Debug only; forbidden as a production input. |
| `API_BASE_URL` in `.env` | Bundled asset but not consumed by `AppEnvironment` | C — environment-specific public configuration | Configuration ambiguity; document only in Phase 0. |
| `OMNICARE_PHONE_VERIFICATION_ENABLED` | Compile-time Dart define | C — environment-specific public configuration | Release pipeline must set and attest the intended value. |
| Android `MAPS_API_KEY` | Gradle property or environment variable -> manifest placeholder | C — environment-specific public client configuration | Key ships in the app; enforce platform/application/API restrictions outside source. |
| iOS `MAPS_API_KEY` | Protected Xcode/CI setting expected by `Info.plist`; example file checked in | C — environment-specific public client configuration | Real value must be injected by protected build configuration. |
| Web `GOOGLE_MAPS_WEB_API_KEY` | Docker argument -> Dart define | C — environment-specific public client configuration | Browser restriction and approved-origin policy required. |
| Cloudinary cloud name/upload preset | Tracked `.env` asset -> `StorageService` | A/C — public, environment-specific client configuration | Treat as extractable. Unsigned upload controls, allowed formats/size, and backend policy must provide security. |
| Firebase Android/iOS app config | Not present and no evidenced injection pipeline | C — environment-specific public client configuration | Required build input in Phase 4; it is not a server secret. |
| FCM/APNs server credentials | Not in the client repository | D — server-side/CI secret | Must never ship in the binary or roadmap. |
| Android signing key/passwords | Debug signing currently selected; no production material in repo | D — protected release secret | Production keystore and credentials must remain outside source. |
| Cloudinary API secret | Not identified in client source | D — server-side-only secret | Must never ship in the binary. |
| Demo/preview Dart defines | Alternate entrypoints and explicit debug fixtures | A — public development configuration | Never permitted in a production artifact. |

Sensitive configuration detected in `.env`. Value redacted. Client-bundled configuration is extractable and must never be treated as a secret. No value is reproduced in this roadmap.

### Confirmed finding register

| Finding | Severity | Baseline disposition |
|---|---|---|
| F-01 synthetic urgent HOME clinical success | P0 | Phase 1 production safety complete; feature deferred |
| F-02 transient refresh failure clears session | P1 | Phase 2 |
| F-03 Android release uses debug signing | P1 | Phase 4 |
| F-04 no evidenced push-capable mobile build; silent failure | P1 | Phase 4 |
| F-05 clinic in-flight recovery is unwired | P1 | Phase 3 |
| F-06 tests fail and hang | P1 | Phase 4 |
| F-07 no production observability | P2 | Phase 9 |
| F-08 no mobile CI/environment/signing separation | P2 | Phase 4 |
| F-09 no send timeout; generic replay unsafe for uploads | P2 | Phase 2 |
| F-10 fixed endless realtime reconnect | P2 | Phase 7 |
| F-11 unchecked in-memory route arguments/no restoration | P2 | Phase 3 |
| F-12 incomplete localization/accessibility | P2 | Phase 13 |
| F-13 personal image cache lacks account purge policy | P2 | Phase 8 |
| F-14 controllers constructed in `build` | P3 | Phase 5 |
| F-15 bundled config and temporary-file retention | P3 | Phases 8 and 14 |
| F-16 389 analyzer issues | P3 | Phases 4 and 14 |
| F-17 medical-document upload buffers full file/no cancellation | P2 | Phase 2 |

### Strengths that are frozen for preservation

- One shared production `AppHttpClient`, secure token store, refresh coordinator, and authenticated realtime transport are created at bootstrap.
- Refresh is single-flight and original requests have one-replay fencing.
- Modern critical writes use explicit idempotency/operation keys instead of blind retry.
- Cancellation, generation, owner, and disposed checks prevent many stale async writes.
- Realtime events generally invalidate and trigger authoritative REST reconciliation.
- Urgent-cabinet recovery and notification entry use account-scoped stable identifiers and backend authorization.
- Secure session persistence is versioned and migrates legacy token keys.
- Logout/account switching clears broad session-scoped state and stops realtime/push.
- Release API configuration fails closed when missing.
- No production TLS bypass, release cleartext opt-in, or sensitive Dio payload logger was found.

## 3. Target architecture

The target for new or materially modified production features is a responsibility model, not a mandatory folder structure:

```text
View
  -> ViewModel / Controller (ChangeNotifier remains valid)
      -> UseCase [optional; complex/reused/recoverable workflow only]
          -> Repository (client-side domain source of truth)
              -> Service
                  -> REST / shared Dio
                  -> secure or approved local persistence
                  -> WebSocket
                  -> Firebase
                  -> camera / QR
                  -> location
                      -> backend or external platform

Backend = authoritative clinical and business lifecycle state
```

Existing `Controller` names remain valid. Existing working features are not renamed or moved for architecture purity.

### UI rules

- Widgets do not create arbitrary Dio clients.
- Widgets do not own clinical/business lifecycle rules.
- Widgets render explicit state and forward user intent.
- UI never fabricates server success, assignment, access, availability, or completion.

### ViewModel/controller rules

- Own view state and action lifecycle.
- Own feature cancellation, stale-response fencing, and disposal.
- Translate repository results/failures into display state.
- Remain domain-scoped; do not accumulate unrelated navigation, storage, transport, and business responsibilities.

### Optional use-case rules

Use a use case only when a workflow spans repositories/services, contains complex/reused business rules, or requires isolated recovery/idempotency/state-transition logic. Do not create trivial one-method wrappers.

### Repository rules

- Repositories are client-side domain sources of truth.
- They coordinate approved remote/local sources, reconciliation, and domain-oriented operations.
- They hide transport and persistence implementation from UI.
- They do not override backend clinical authority.

### Service rules

Services encapsulate external mechanisms such as Dio, Firebase, WebSocket, secure storage, filesystem, camera, and location. They do not render widgets or navigate UI.

### Preferred explicit-state pattern

New or materially changed critical workflows use explicit states when multiple booleans would permit contradictions:

```text
Idle -> Loading -> Ready -> Submitting -> Recovering
                         -> Offline / RecoverableFailure / TerminalFailure
```

Where the backend owns a lifecycle, client projections mirror server names such as `SUBMITTED`, `BROADCASTING`, `DOCTOR_SELECTED`, `EN_ROUTE`, `ARRIVED`, `IN_CONSULTATION`, and `COMPLETED`. The client must not invent a competing lifecycle.

### Networking standard

Preserve the shared client, secure token storage, single-flight refresh, one-replay fence, typed failures, and cancellation. Evolve toward:

```text
AppHttpClient
  -> authentication interceptor
  -> refresh coordinator
  -> timeout policy
  -> transport error classification
  -> response/error mapping
  -> request cancellation
  -> explicit replay eligibility
```

There will be no blind global retry. DNS/TLS/timeout/5xx differ from invalid credentials. Writes require explicit idempotency semantics. Upload bodies require dedicated replay/cancellation rules. HTTP/transport errors map to typed application failures.

### Realtime standard

```text
WebSocket event
  -> change/invalidation signal
  -> authoritative REST refresh/reconciliation
  -> Repository/ViewModel state
```

Future transport hardening adds bounded exponential reconnect, jitter, lifecycle/connectivity awareness, and PHI-safe reconnect telemetry without replacing REST reconciliation.

### Cache policy categories

| Category | Examples | Rule |
|---|---|---|
| CACHEABLE | Specialties, public professional metadata, clinic metadata, non-sensitive catalogs | May use a bounded/versioned cache with defined TTL/invalidation. |
| SHORT-LIVED / REVALIDATED | Profile, appointment summaries, directory results, approved Ma Santé projection | Show freshness and revalidate against backend; account-scope all entries. |
| SERVER-AUTHORITATIVE / DO NOT TRUST CACHE | Urgent request, doctor assignment, consultation, access grants, QR validity, booking mutation outcomes | Cache may aid rendering/recovery only; never decide current clinical/business state. |
| RESTRICTED / SECURITY REVIEW REQUIRED | Medical Passport, diagnoses, prescriptions, clinical notes, medical documents | No generic cache. Require explicit privacy, encryption, retention, migration, logout, and threat review. |

No database/cache technology is selected in Phase 0.

### Test pyramid and critical journeys

```text
Unit tests
  -> repository/service contract tests
  -> widget tests
  -> integration tests
  -> physical-device critical journeys
```

Required future integration journeys: login/session restore, logout, family switch, scheduled appointment, clinic request, urgent HOME, urgent CABINET, process-death recovery, notification launch, QR medical access, doctor consultation, and file/document upload.

### Mandatory future release gate

```text
pinned Flutter SDK
  -> locked dependency resolution
  -> flutter analyze
  -> unit/widget tests
  -> integration tests
  -> Android release build
  -> iOS release build
  -> signing verification
  -> Firebase/APNs configuration validation
  -> physical-device smoke tests
  -> staging rollout
```

A mandatory-stage failure blocks production release.

## 4. Engineering invariants

1. No mock/demo/synthetic clinical success in production.
2. Backend is authoritative for clinical/business lifecycle state.
3. WebSocket is a change signal; authoritative REST/state reconciliation follows when required.
4. Every important write operation has explicitly defined retry/idempotency semantics.
5. An ambiguous write outcome is recoverable after process death.
6. Temporary network failure does not automatically become logout.
7. Medical/clinical content does not enter generic logging or telemetry.
8. Medical content is not generically persisted to device caches.
9. Logout/account switch clears account-scoped client state.
10. Critical routes reconstruct from stable identifiers/server state rather than only in-memory objects.
11. Critical user actions are protected against duplicate execution.
12. Production code fails closed when required production configuration is missing.
13. Realtime recovery converges to backend truth.
14. Performance claims require profile-mode physical-device evidence.
15. Production release requires deterministic automated validation.

Forbidden for new production code: synthetic success, new feature-local Dio clients, secrets in client assets/source, untyped generic retry, navigation from transport services, PHI-bearing console/telemetry output, medical caching without review, UI-owned server truth, unchecked production route payload casts, and new critical workflows represented by contradictory booleans when an explicit state is warranted.

## 5. Phase 0 — Baseline

**Status: COMPLETE — GOVERNANCE APPROVED**

### Objective

Freeze scope and establish a reproducible toolchain, production entrypoint, configuration classification, architecture responsibility model, invariants, command baseline, and ordered execution plan.

### Audit findings covered

All F-01 through F-17 are registered and routed; none is implemented in this phase.

### Dependencies

Completed production-readiness audit, readable repository, local Flutter 3.41.2 installation, and engineering-owner approval of this governance baseline.

### Work items

- Read and preserve the audit evidence.
- Record branch/commit/status and platform/toolchain constraints.
- Pin Flutter 3.41.2 using existing repository mechanisms.
- Declare `lib/main.dart` as the sole production entrypoint.
- Classify configuration without exposing values.
- Record preserved/forbidden patterns, state/network/realtime/cache/test/release standards.
- Record all blockers and phase ordering.
- Capture baseline diagnostics without rerunning the indefinite full suite.

### Architecture/pattern changes

None at runtime. Only governance and SDK/build-toolchain constraints are added.

### Explicitly out of scope

Fixing any F-01 through F-17 item, application behavior, UI/UX, navigation, backend contracts, dependency upgrades, broad formatting, or state-management migration.

### Acceptance criteria

- Exact Flutter/Dart/channel and platform constraints are recorded.
- Local/pubspec/Docker Flutter baseline is 3.41.2.
- Exactly one production entrypoint is declared.
- Configuration and sensitive-value handling are classified.
- All findings, strengths, invariants, release gate, and phases are recorded.
- Baseline commands and known failures are reproducible.
- Git diff contains no functional application-source change.

### Required tests

`flutter --version`, `dart --version`, `flutter doctor -v`, and `flutter analyze --no-pub`. Use the audit's known full/targeted test outcomes; do not rerun the hanging suite indefinitely.

### Runtime/device validation

None; Phase 0 makes no runtime behavior claim.

### Rollback considerations

If Flutter 3.41.2 cannot be installed in an approved runner, revert only the pinning declarations after an explicit baseline decision; never silently build with another SDK.

### Exit decision

**APPROVED.** The SDK, sole production entrypoint, invariants, configuration classification, and phase order are accepted. Phase 0B was inserted as a deterministic safety gate before any Phase 1 implementation.

## Phase 0B — Deterministic Test Safety Baseline

**Status: COMPLETE**

### Objective and reason

Establish a terminating, fully classified Flutter test baseline before F-01 work so an existing failure or deadlock cannot hide a Phase 1 regression. This phase did not implement F-01 or change the urgent HOME production path.

### Investigation result

The non-terminating `review_screen_test.dart` awaited `RequestSubmissionController.beginNewRequest()`, which awaited deletion through the real `flutter_secure_storage` method channel. That native channel never completed in the widget-test process. The test now injects an in-memory secure-storage backend. Bounded inventory exposed 14 initial failures, the hang, and two further failures hidden behind it: 17 classified test conditions in total.

| Classification | Count | Disposition |
|---|---:|---|
| PRODUCT_DEFECT | 4 | Corrected isolated calendar-day matching, care-need matching, and dialog controller lifetime defects. |
| STALE_TEST | 7 | Aligned obsolete copy/count/canvas/polling assertions to frozen behavior without changing the approved UI. |
| TEST_INFRASTRUCTURE | 6 | Corrected storage/SSE/family/session fixtures, asynchronous pumping, and the document event fixture. |
| FLAKY_TIMING / ENVIRONMENT / UNKNOWN | 0 | No remaining failure required one of these classifications. |

### `PHASE_1_SAFETY_SUITE`

Run before and after every F-01 change:

```bash
perl -e 'alarm shift; exec @ARGV' 300 flutter test --no-pub --reporter compact --timeout 60s \
  test/patient_home_feed_test.dart \
  test/patient_route_transition_test.dart \
  test/emergency_nested_navigation_test.dart \
  test/emergency_body_map_test.dart \
  test/emergency_request_step1_test.dart \
  test/emergency_request_step2_test.dart \
  test/emergency_request_step3_test.dart \
  test/emergency_review_screen_test.dart \
  test/doctor_selection_screen_test.dart \
  test/auth_phase1_test.dart \
  test/request_core_test.dart
```

Baseline result: **201 passed, 7 intentionally skipped, 0 failed, 43 seconds**. Existing tests cover urgent entry, intake, review, matching/selection, navigation, auth/session/network refresh, and repository safeguards. No existing test directly covers `ReviewConfirmScreen`, `DoctorCallingScreen`, `DoctorArrivingScreen`, or the legacy `ConsultationsApi`; Phase 1 must add authoritative-path tests for those gaps as implementation begins.

### Acceptance and final result

- The complete suite is process-bounded to ten minutes and each test is bounded to 60 seconds.
- Final complete-suite result: **1,619 passed, 7 intentionally skipped, 0 failed; terminated in 4 minutes 34 seconds**.
- Analyzer result: **389 findings = 0 errors, 31 warnings, 358 infos**, exactly matching the Phase 0 baseline; no error or warning was introduced.
- No test was deleted or skipped, no assertion was weakened to a non-specific matcher, no dependency was upgraded, and no Git write operation was performed.
- Phase 0 remains intact and approved. At the Phase 0B exit, Phase 1 had not
  started; its current status is recorded below.

## 6. Phase 1 — Clinical correctness

**Status: COMPLETE FOR CURRENT LAUNCH SCOPE — URGENT HOME FUNCTIONALITY DEFERRED**

- **Production safety: COMPLETE.** The P0 safety defect is contained by the verified fail-closed boundary.
- **Feature functionality: DEFERRED.** This status does not claim that authoritative Urgent HOME functionality is complete.
- **Flutter Phase 1B: DEFERRED — resume only through explicit CTO/product scope decision.**
- **Backend B2-B8: DEFERRED — resume only through explicit CTO/product scope decision.**

Safety mitigation record: `PHASE_1_CLINICAL_CORRECTNESS_MITIGATION.md`.

### Objective

Ensure production can never fabricate a clinical request, clinician assignment, consultation, access decision, or success state.

### Audit findings covered

Primary: F-01. Also every production-reachable mock/demo/synthetic path discovered from `lib/main.dart`.

### Dependencies

For the current launch-scope exit: approved Phase 0 baseline and the verified fail-closed production boundary. The backend product contract and authoritative release-like environment remain dependencies only for a future explicit Urgent HOME resumption.

### Work items

Current launch: preserve the regression boundary proving that no `mock`, `demo`, `fixture`, `synthetic`, timer-driven decision, `devAutoComplete`, synthetic reservation/provider flow, or legacy HOME completion path is reachable from production. Future feature resumption must replace the unavailable boundary with authoritative repository operations and require server-created stable identity before success UI.

### Architecture/pattern changes

Converge urgent HOME on View -> controller -> repository -> service, backend-authoritative state, explicit operation identity, and recovery semantics. Preserve the approved UI unless truthfulness requires disabling an unavailable action.

### Explicitly out of scope

General widget cleanup, state-library migration, unrelated analyzer cleanup, cache technology, performance tuning, or release signing.

### Acceptance criteria

No production route can show Urgent HOME clinical success without authoritative evidence. All alternate/demo entrypoints are excluded from production artifacts. Production reaches the approved unavailable state and exposes no actionable Urgent HOME capability. This safety criterion is complete for the current launch; authoritative feature completion is deferred.

### Required tests

Unit/repository/widget tests for success/failure/timeout/duplicate tap; production-entrypoint integration test proving HTTP/backend identity and no fixture source.

### Runtime/device validation

Current launch: negative production-path validation proves the backend-unavailable/disabled case fails closed. A release-like successful Urgent HOME journey with captured network calls and backend record/clinician visibility is retained as future deferred evidence and is not a launch dependency.

### Rollback considerations

Rollback must fail closed by disabling the unsafe journey, never restore synthetic success.

### Exit decision

**Exited for current launch scope.** The P0 defect is contained because production cannot reach synthetic Urgent HOME success. Full Urgent HOME feature functionality has not exited and remains deferred.

### Current launch deferral boundary

Do not begin or activate B2 matching productionization, travel/location, arrival, P4/P5 handoff, QR, HOME consultation integration, HOME realtime, HOME push, or Flutter Phase 1B. Do not let Phase 2 or any later hardening phase depend on Urgent HOME being enabled.

Retain B1, Module 04 v1.2, ownership/certification evidence, protected intake, the B2-B8 roadmap, and the Phase 1B plan without deleting or reinterpreting them. They may resume only through an explicit CTO/product scope decision.

### Current launch fail-closed regression gate

Status on 2026-11-09: **PASS**.

- `flutter test test/phase1_clinical_correctness_boundary_test.dart` — **6 passed, 0 failed**. It proves the approved unavailable state contains no success copy; production route graphs cannot reference `DemoDoctorMatchingSource`, `createDemoUrgentDoctors`, mock `ConsultationsApi`, synthetic reservation defaults, timer-driven confirmation, fabricated travel/arrival, or legacy completion widgets; review drops the intake payload; demo matching requires explicit injection; and the authoritative Doctor shell cannot mount the legacy HOME simulation.
- `./mvnw -q -Dtest=HomeProductionCapabilityServiceTest,HomeProductionStartupValidatorTest,HomeIntakeAccessPolicyTest test` — **passed**. It proves disabled backend production HOME advertises `enabled=false`, no contract version, no product states, no available actions, and no travel, arrival, QR, consultation, or realtime capability; enabled production fails closed when required safeguards are absent; and synthetic authority remains explicitly gated.
- Existing B1 startup, synthetic-isolation, protected-intake, and no-side-effect tests remain retained. Explicit test/demo injection remains available; no production dependency defaults to a synthetic implementation.

### Phase 1A — Urgent HOME Investigation

**Status: COMPLETE — BLOCKED_BACKEND_CONTRACT**

This investigation changed documentation only. It did not change routes, application state, API calls, production dependency injection, UI/UX, dependencies, or tests.

While the investigation report was being written, concurrent uncommitted workspace changes appeared in `lib/main.dart`, `NewHomeScreen`, `EmergencyReviewScreen`, `DoctorSelectionScreen`, `DoctorAppShell`, a new `clinical_safety` screen, and a new boundary test. They were not authored by Phase 1A and were preserved. They now fail closed at review and disconnect the legacy clinical routes in the current worktree. The audited `ff88c76` flow below remains the evidence for F-01; the concurrent mitigation is recorded separately and is not treated as an authoritative implementation or as Phase 1A output.

#### Production flow today

At the Phase 1A investigation baseline, the same urgent-HOME chain was registered by both the root `MaterialApp` router in `lib/main.dart` and the patient-content navigator in `lib/features/home/new_home_screen.dart`. All state through review was an in-memory `Map<String, dynamic>` passed in route arguments. No urgent request was created before the doctor-selection screen started.

| Transition | Route and widget | Controller/provider/repository/API | State and authority today |
|---|---|---|---|
| Patient home -> care entry | `/emergency-step0` -> `EmergencyRequestStep0` | `PatientHomeFeed` or `NewHomeScreen`; no urgent controller/repository | Real user/family providers may already be loaded; the transition itself is local navigation. |
| Care entry -> urgent mode | `/urgent-care-mode-selection` -> `UrgentCareModeSelectionScreen` | None | Local route arguments only. |
| HOME mode -> care subject | `/emergency-step1` -> `EmergencyRequestStep1` | `UserProvider`, `FamilyProvider` | SELF/family selection is based on real account/family projections, then copied into the route map. No urgent backend call. |
| Subject -> clinical intake | `/emergency-step2` -> `EmergencyRequestStep2` | Screen-local state and `EmergencySymptomIntakeValue` | Body regions, pain, narrative, and share-record choice are memory-only. No urgent backend call. |
| Intake -> destination | `/emergency-step3` -> `EmergencyRequestStep3` | `DeviceEmergencyLocationGateway`, places gateway, Geolocator/geocoding/maps plugins | Device/place data can be real, but it is only copied into the route map. It is not bound to a server request. |
| Destination -> review | `/emergency-review` -> `EmergencyReviewScreen` | Screen-local map | Review/edit state is memory-only. |
| Send -> matching | `/doctor-selection` -> `DoctorSelectionScreen` | `DoctorMatchingController` -> default `DemoDoctorMatchingSource` | No POST occurs. Timers emit hardcoded doctors and the UI says the request was transmitted. |
| Doctor selection -> confirmation | `/review-confirm` -> `ReviewConfirmScreen` | Local `Doctor` object; no injected authoritative dependency | The selected identity is a hardcoded `doc-*` identifier. |
| Confirm -> calling | `/doctor-calling` -> `DoctorCallingScreen` | Directly constructed `ConsultationsApi` | `createConsultation()` returns fixed `consult-new`; `getConsultation()` returns the first mock consultation. No Dio/backend operation occurs. |
| Calling -> en route | `/doctor-arriving` -> `DoctorArrivingScreen` | Local timers plus `NotificationService` | The screen displays `Demande Confirmée`; a five-second timer advances regardless of server state. The two-second mock poll can instead see fixed `COMPLETED` and jump directly to completion. |
| En route -> arrival/handoff | `/consultation-qr` -> `ConsultationQRScreen`, or automatic completion | Local ETA/distance countdown, local notifications, direct `ConsultationsApi` | ETA, distance, arrival, QR identity, diagnosis, treatment, and completion are fabricated or locally derived. |
| Handoff -> completion | `/consultation-complete` -> `ConsultationCompleteScreen` | Route arguments only | Displays successful completion without authoritative consultation state. |

Audited `ff88c76` sequence:

```text
PatientHomeFeed / NewHomeScreen
  -> /emergency-step0 EmergencyRequestStep0
  -> /urgent-care-mode-selection UrgentCareModeSelectionScreen
  -> /emergency-step1 EmergencyRequestStep1
       -> UserProvider + FamilyProvider reads
  -> /emergency-step2 EmergencyRequestStep2
       -> in-memory symptoms/body/pain
  -> /emergency-step3 EmergencyRequestStep3
       -> device location / places / map result, still in memory
  -> /emergency-review EmergencyReviewScreen
       -> Send: navigation only; NO urgent HOME POST
  -> /doctor-selection DoctorSelectionScreen
       -> DemoDoctorMatchingSource
       -> Timer -> DoctorAccepted(hardcoded Doctor)
  -> /review-confirm ReviewConfirmScreen
       -> ConsultationsApi.createConsultation() -> fixed mock `consult-new`
       -> ConsultationsApi.getConsultation() -> unrelated fixed mock detail
  -> /doctor-calling DoctorCallingScreen
       -> immediately renders `Demande Confirmée`
       -> local notification + mock poll + five-second navigation timer
  -> /doctor-arriving DoctorArrivingScreen
       -> local ETA/distance countdown + local arrival notification
       -> ConsultationsApi.devAutoCompleteConsultation() -> fixed success map
  -> /consultation-qr and/or /consultation-complete
       -> fabricated completion UI
```

Current uncommitted worktree sequence after the concurrent mitigation:

```text
PatientHomeFeed / NewHomeScreen
  -> /emergency-step0
  -> /urgent-care-mode-selection
  -> /emergency-step1
  -> /emergency-step2
  -> /emergency-step3
  -> /emergency-review
       -> Send: /clinical-request-unavailable
       -> ClinicalFeatureUnavailableScreen
       -> no request/Doctor/consultation identity and no intake arguments forwarded

Any direct/stale route to:
  /doctor-selection, /review-confirm, /doctor-calling, /doctor-arriving,
  /consultation-qr, /consultation-complete, /consultation-type,
  /provider-list, /time-selection, /appointment-confirmation, or /booking-confirmed
       -> ClinicalFeatureUnavailableScreen
```

The concurrent worktree also removes the root `ReservationProvider`, makes `DoctorSelectionScreen.matchingSource` mandatory for explicit non-production injection, and prevents the authoritative Doctor shell from mounting its legacy HOME simulation. Those changes remove the observed production-reachable synthetic success in the current uncommitted tree, but they do not supply authoritative HOME care and have not passed the complete Phase 1 exit evidence.

#### Synthetic reachability inventory

| Phase 1A baseline classification | Component | Audited reachability and current worktree disposition |
|---|---|---|
| C — PRODUCTION_REACHABLE | `DemoDoctorMatchingSource` and `DoctorMatchingController` in `lib/features/emergency/doctor_matching.dart` | At baseline, `DoctorSelectionScreen` constructed this source by default and timers generated acceptance/waiting. Current worktree: legacy screen has no production route and requires an explicit source. |
| C — PRODUCTION_REACHABLE | `createDemoUrgentDoctors()` | At baseline, supplied hardcoded `doc-1`/`doc-2`/`doc-3` identities, names, phones, fees, ratings, distances, ETAs, biographies, and reviews. Current worktree: retained for tests/legacy source but disconnected from production routers. |
| C — PRODUCTION_REACHABLE | `ConsultationsApi` in `lib/core/api/consultations_api.dart` | Constructor ignores `dio`; every method returns mock data. Current worktree: legacy consumer screens remain in source but are intercepted by the fail-closed production routers. |
| C — PRODUCTION_REACHABLE | `ReviewConfirmScreen` | At baseline, directly constructed the mock API and accepted its fabricated ID. Current worktree: no production construction found. |
| C — PRODUCTION_REACHABLE | `DoctorCallingScreen` | At baseline, displayed confirmed state, emitted an on-way notification, polled the mock API, and advanced on timers. Current worktree: no production construction found. |
| C — PRODUCTION_REACHABLE | `DoctorArrivingScreen` | At baseline, simulated ETA/distance/arrival and called `devAutoCompleteConsultation()`. Current worktree: no production construction found. |
| C — PRODUCTION_REACHABLE | `ConsultationQRScreen` and `ConsultationCompleteScreen` | At baseline, mock completion and route trust could produce success. Current worktree: route names resolve to the fail-closed screen. |
| C — PRODUCTION_REACHABLE, adjacent legacy route | `DoctorsApi`, `ProviderListScreen`, `ReservationProvider`, and default-mock `ReservationRepository` | At baseline, root provider and legacy routes were registered. Current worktree: root provider is removed and the legacy route names fail closed. |
| C — PRODUCTION_REACHABLE, conditional Doctor shell fallback | `DoctorHomeDemoState` | At baseline, `DoctorHomeScreen` could fall back to demo operational cards when its real controller was absent. Current worktree: the authoritative shell prevents legacy HOME simulation/QR mounting; the demo state remains available to non-authoritative/test contexts. |
| B — DEBUG/PREVIEW_ONLY | `main_demo.dart`, `main_doctor_urgent_cabinet_preview.dart`, `main_maps_smoke.dart`, `main_p4_cabinet_synthetic.dart`, `main_p4_recovery_preview.dart`, and `lib/demo/demo_http_adapter.dart` | Alternate entrypoints are not imported by `lib/main.dart`. They must remain excluded from production artifacts. |
| B — DEBUG/PREVIEW_ONLY | Urgent-CABINET development fixtures and simulation controls | Their activation is explicitly gated by debug/build seams and fixture provenance. They are not the source of F-01 and are not to be removed by Phase 1B. |
| A — TEST_ONLY | Test fakes, scripted matching sources, in-memory stores, and fixtures under `test/` | Reachable only through explicit test injection; they are valid test seams, not production defects. |
| D — UNKNOWN | None retained after the route/import/configuration trace | Every urgent-HOME synthetic family found was classifiable from `lib/main.dart`, alternate-entrypoint isolation, or explicit injection/gating. |

#### Existing real urgent-HOME infrastructure

**Flutter patient side:** no usable authoritative implementation exists. Repository-wide search found no patient client for `POST /me/urgent-home/journeys`, journey status, accepted doctors, selection, submission recovery, or HOME activity. There are no patient HOME DTOs, repository, controller, persisted receipt, production dependency injection, HOME realtime subscription, or restart reconciliation.

**Flutter Doctor side:** a partial, modern REST implementation exists and should be reused rather than duplicated:

- `DoctorHomeOffer`, `DoctorHomeOfferRepository`, and `DoctorHomeOfferInboxController` model/list/get/accept/decline Doctor offers through `/me/urgent-home/offers`, use the shared `AppHttpClient`, validate DTOs, use `CancelToken`, stable idempotency keys, and reconcile ambiguous commands.
- `DoctorHomeCommitment`, `DoctorHomeCommitmentRepository`, and `DoctorHomeCommitmentController` read `/me/urgent-home/commitments/active` and commitment detail.
- `DoctorHomeDispatchContextRepository` and `DoctorHomeDispatchContextController` read the purpose-scoped confirmed destination for an active commitment.
- `DoctorAuthShellScreen` constructs these repositories from the shared `AppHttpClient` and owns their lifecycle.
- `DoctorActiveConsultationApi` and `DoctorActiveConsultationController` recognize `URGENT_HOME` as a canonical consultation source, but the backend source adapter currently rejects urgent-HOME start as not actionable because arrival/check-in authority is deferred.

**Flutter realtime:** `AuthenticatedRealtimeTransport` subscribes only to `/user/queue/scheduled-care` and `/user/queue/notifications`. It has no `/user/queue/home` subscription or HOME history/reconciliation coordinator.

**Backend:** the repository contains a coherent development-only HOME aggregate and API:

- Patient submission/status: `MePatientHomeSubmissionController`, `HomeSubmissionService`, and `HomeSubmissionRecoveryService`.
- Matching: `HomeMatchingWaveCoordinator`, explicit `HomeMatchingWaveWorker`, and recovery coordinator.
- Doctor offer/hold: `MeDoctorHomeOfferController` and the `urgentoffer` package.
- Patient accepted-doctor/selection: `MePatientHomeSelectionController` and `HomeSelectionService`.
- Doctor commitment/dispatch reads: `MeDoctorHomeCommitmentController` and `MeDoctorHomeDispatchContextController`.
- Recipient history and reserved invalidation contract: `MeHomeSyncController` and the `urgentnotification` package.
- Canonical consultation source type: `URGENT_HOME` in the consultation aggregate.

This is not a usable production backend contract. `docs/p4-07-patient-home-integration.md` defines patient intake as synthetic development only; `HomeIntakeAccessPolicy` requires development runtime access, explicit synthetic latches, an isolated database, and an account allowlist. The default is disabled and production profiles cannot activate it. Real protected triage/location persistence has scaffolding and a startup validator, but no production submission strategy is wired to `HomeSubmissionService`; `URGENT_HOME_PROTECTED_SUBMIT_V1` is not used by a production intake path. The matching worker is explicitly invoked and has no production scheduler. `docs/p4-06-home-lifecycle-delivery.md` reserves `/user/queue/home` but installs only a fake no-I/O publisher and forbids production WebSocket publication. Arrival/check-in authority is deferred, and `UrgentHomeConsultationSourceAdapter` always returns `CONSULTATION_SOURCE_NOT_ACTIONABLE`.

#### Backend lifecycle contract found

The actual server vocabulary is different from the conceptual lifecycle in the roadmap.

| Server authority | Trigger | Current state/projection | Flutter production display today |
|---|---|---|---|
| Journey and attempt creation | Development-only `POST /api/v1/me/urgent-home/journeys` with `Idempotency-Key` | Journey `ACTIVE`; attempt progresses `HOME_CREATED` -> `HOME_MATCHING`; first matching wave is created | No request is made; Flutter immediately begins demo matching. |
| Matching wave | Explicit development worker and internal discovery | `PENDING`/`RETRYABLE` -> `OFFERS_ISSUED`, or `NO_NEW_OFFERS`, `RADIUS_EXHAUSTED`, `MATCHING_EXHAUSTED`, `RECOVERY_REQUIRED`, `DEADLINE_REACHED`, `CANCELLED`, or `SUPERSEDED` | Timers fabricate accepted doctors and waiting state. |
| Doctor response/hold | Doctor `POST .../offers/{offerId}/accept` | Offer `ACCEPTED_HELD`; attempt `HOME_HELD`; other offer terminal states use the `HomeDoctorOfferState` enum | Hardcoded Doctor objects are treated as accepted. |
| Patient accepted-doctor read | Development-only `GET .../journeys/{journeyId}/accepted-doctors` | Actor-owned, currently valid held offers with offer ID, Doctor ID, fee, expiry, distance, epoch, and attempt revision | No authoritative read. |
| Patient selection | Development-only `POST .../journeys/{journeyId}/selection` with selected offer, expected attempt revision, and `Idempotency-Key` | Attempt `HOME_COMMITTED`; commitment `ACTIVE`; selected offer `SELECTED_COMMITTED`; siblings are closed | Local selection followed by mock consultation creation. |
| Doctor commitment/dispatch read | `GET /me/urgent-home/commitments/active`, detail, and dispatch context | Commitment `ACTIVE`, `CANCELLED`, or `INVALIDATED`; destination is a separate purpose-scoped read | Flutter patient screens simulate calling, travel, and arrival. |
| Consultation start | `POST /doctor/consultations/start` with source type `URGENT_HOME` and commitment ID/version | Contract exists, but the current HOME source adapter unconditionally rejects start as not actionable | Legacy patient flow fabricates a consultation and later auto-completes it. |
| En route / arrived / check-in | No production HOME authority found | Not represented by the current HOME aggregate; explicitly deferred | Local timers invent ETA, distance, arrival, QR, and completion. |

The backend therefore supports a development progression roughly equivalent to `HOME_MATCHING -> HOME_HELD -> HOME_COMMITTED`, not the assumed production sequence `SUBMITTED -> BROADCASTING -> PARTIALLY_ACCEPTED -> DOCTOR_SELECTED -> EN_ROUTE -> ARRIVED -> IN_CONSULTATION -> COMPLETED`. The latter names must not be introduced into Flutter until backend/product owners approve exact production states and transitions.

#### Reusable modern components/patterns

- Reuse the singleton `AppHttpClient` and existing auth/refresh ownership from `lib/main.dart`; do not create a feature-local Dio.
- Follow `DoctorHomeOfferRepository` for strict DTO parsing, `CancelToken`, typed command failures, stable idempotency keys, and verify-before-retry reconciliation.
- Follow `UrgentCabinetTargetedRequestRepository`, `UrgentCabinetSubmissionCoordinator`, and `UrgentCabinetPatientLifecycleController` for account-scoped recovery receipts, ambiguous-outcome recovery, generation fencing, cancellation, and backend-authoritative navigation.
- Reuse `generateUuidV4` for client command keys after the backend confirms the key lifecycle.
- Follow `RequestOperationId`/`InFlightRequestStore` and `RequestSubmissionController` conceptually for a versioned secure receipt, but do not reuse their clinic payload schema or repeat the Phase-3 unwired-restore defect.
- Follow `ScheduledCareRealtimeCoordinator`, `NotificationRealtimeCoordinator`, and `CoalescedRefresh` for connection-epoch/foreground invalidation followed by REST reconciliation.
- Preserve `AuthenticatedRealtimeTransport` as the single session socket; extend it only after the backend enables a real HOME publisher and the transport interface can expose HOME hints without conflating them with scheduled care or notifications.
- Follow `NotificationNavigationResolver` and urgent-CABINET notification recovery: an opaque identifier is only a navigation hint; the destination must re-fetch and authorize current server state.

#### Missing components

**Backend/product contract required before Phase 1B:**

1. Approved production persistence/retention/audit contract for real symptom narrative and exact HOME destination, including the wired protected submission mode and canonical SELF/family identity.
2. Production authorization and scheduling for matching/recovery workers, with truthful worker/readiness exposure.
3. Production-enabled Doctor offer, Patient selection, commitment, and cancellation rules, including exact terminal/error codes and availability actions.
4. Authoritative travel/arrival/check-in/QR contract, or an explicit decision that those legacy screens remain disabled until a later backend phase.
5. Actionable `URGENT_HOME` consultation-start contract and source-version ownership, plus finish/release behavior.
6. Production realtime/push decision. If HOME realtime remains unavailable, the approved bounded polling/foreground-resync contract must be specified instead.
7. Active-journey discovery/recovery policy when the app retains a journey ID, only an idempotency key, or neither.

**Flutter components after that contract is approved:**

- Patient `UrgentHomeApiService` using the shared client for submission, status, accepted-doctor list, selection, recovery, and any approved cancellation/read endpoints.
- Strict immutable DTO/domain models for actual journey, attempt, wave, offer, commitment, and allowed actions.
- `UrgentHomeRepository` as the client source of truth and error/reconciliation boundary.
- Account-scoped `UrgentHomeController` with explicit states, cancellation/generation fencing, duplicate-action protection, and server-derived navigation eligibility.
- Minimal versioned secure recovery receipt containing only approved opaque account/operation/journey identifiers and timestamps; no symptoms, address, coordinates, or Doctor profile cache.
- Production bootstrap/injection from `lib/main.dart`, route adapters that reconstruct from stable IDs, and a HOME invalidation coordinator only when the transport contract is real.

#### Recommended target architecture

One implementation path is preferred; no parallel urgent-care architecture should be added:

```text
Existing urgent HOME views (approved presentation retained)
  -> UrgentHomeController
      -> UrgentHomeRepository
          -> UrgentHomeApiService
              -> shared AppHttpClient
                  -> approved production /me/urgent-home contract

AuthenticatedRealtimeTransport [only after production HOME publication exists]
  -> HOME_STATE_CHANGED invalidation
      -> UrgentHomeController coalesced reconcile
          -> REST status / accepted doctors / commitment authority

Secure recovery receipt (opaque IDs/key only)
  -> authentication/account validation
      -> recovery-by-key or read-by-journey
          -> REST authority
              -> correct existing screen, or truthful unavailable/terminal state
```

Views may keep their approved layout, but must stop owning lifecycle timers and direct APIs. The controller must expose server-derived explicit states such as draft, submitting, matching, offers available, selecting, committed, recoverable failure, terminal failure, and unavailable. Exact names must mirror the approved contract rather than invent `EN_ROUTE` or `ARRIVED`.

#### Idempotency/recovery contract

The development backend contract already demonstrates the intended mechanics:

- Submission uses a client-supplied `Idempotency-Key`; same key and normalized payload replays the same journey, while changed payload conflicts.
- Creation returns opaque `journeyId`, `attemptId`, and `waveId`; `GET /journeys/{journeyId}` is the actor-owned restoration read.
- `GET /submissions/recovery` accepts the original `Idempotency-Key`, performs no new write, and returns the completed submission projection with `replayed=true` when the retained key is valid.
- Selection has a distinct stable idempotency key and includes `selectedOfferId` plus `expectedAttemptRevision`; conflict or ambiguous outcome requires authoritative re-read, never a new blind selection.
- No bounded active-journey discovery endpoint exists when both journey ID and submission key are lost.

Phase 1B must not adopt these semantics for production until the protected intake scope and production access policy are wired. Once approved, the client should persist the submission key before POST, retain it across an unknown outcome, recover by the same key after restart, then persist the returned journey ID. A separate selection key should be stable for the selected offer/revision until its outcome is reconciled. Logout/account switch must clear or quarantine receipts by account. No clinical narrative or exact destination belongs in the generic receipt.

#### Realtime/reconciliation contract

The backend defines these durable lifecycle facts, but only in a synthetic development generation:

| Event family | Source | Required client action | REST reconciliation required? |
|---|---|---|---|
| `HOME_OFFER_ISSUED` | Offer creation -> Doctor recipient | Refresh Doctor offer list/detail. | Yes. |
| `HOME_HOLD_ACCEPTED` | Doctor acceptance -> Patient recipient | Refresh journey status and accepted-doctor list. | Yes. |
| `HOME_COMMITMENT_CREATED` | Patient selection -> Patient/Doctor recipients | Refresh journey/commitment; only REST may enable committed UI. | Yes. |
| `HOME_OFFER_DECLINED`, `HOME_OFFER_EXPIRED`, `HOME_OFFER_CLOSED`, `HOME_HOLD_EXPIRED`, `HOME_HOLD_WITHDRAWN`, `HOME_OFFER_NOT_SELECTED`, `HOME_OFFER_SELECTION_CLOSED` | Offer/hold terminal transitions | Refresh the relevant offer, accepted list, journey, or commitment and remove stale actions. | Yes. |
| `HOME_MATCHING_EXHAUSTED`, `HOME_MATCHING_DEADLINE_REACHED`, `HOME_MATCHING_RECOVERY_REQUIRED` | Matching wave terminal/recovery transition | Refresh journey status and render the server-allowed terminal/recovery action. | Yes. |

The reserved socket payload is only `HOME_STATE_CHANGED` with opaque event/aggregate identity and `resyncRequired=true`; it is never business truth. `/user/queue/home` publication is currently fake/no-I/O, `/me/urgent-home/activity` is development-gated history, and Flutter subscribes to neither. Therefore Phase 1B cannot claim realtime. After production enablement, connection epoch, foreground resume, duplicate hint, sequence gap, or malformed hint must trigger a coalesced REST reconciliation. Socket loss must leave the last server-confirmed state visible as stale/reconnecting and use approved bounded REST resync; it must never advance lifecycle state locally.

#### Required Phase 1B tests

No Phase 1B test was added during this investigation. The implementation phase must add, at minimum:

1. A production-wiring test proving `DoctorSelectionScreen` cannot receive the default demo source from `lib/main.dart`.
2. API/repository contract tests proving submit uses the shared client, exact approved payload, one stable idempotency key, and strict response parsing.
3. Controller/widget tests proving a server `journeyId` is required before any submitted/matching success state.
4. Accepted-doctor/selection tests proving displayed and selected Doctor/offer identities come from the actor-owned backend response and the selection command carries the expected attempt revision.
5. Backend unavailable, timeout, 5xx, offline, malformed response, and authorization tests proving no confirmed Doctor/consultation UI is shown.
6. Duplicate-tap and concurrent-submit tests proving one in-flight command and one stable key.
7. Commit-before-response/restart tests proving recovery uses the stored key, reuses server identity, and never creates a second journey.
8. Reconnect/foreground tests proving HOME hints or connection epochs only trigger coalesced REST reconciliation.
9. Stale revision, expired hold, selected Doctor withdrawal, matching exhaustion, cancellation, and unknown-state tests proving safe truthful states.
10. Calling/en-route/arrival/QR/completion screen tests proving each screen requires an approved authoritative state; until such states exist, navigation is denied/fails closed.
11. Production-entrypoint integration tests with captured HTTP proving no `DemoDoctorMatchingSource`, `createDemoUrgentDoctors`, `ConsultationsApi`, or mock reservation/doctor API services the urgent-HOME journey.
12. Explicit test/demo wiring tests proving synthetic APIs and fixtures remain usable only through test injection or non-production entrypoints.
13. Account/family-switch/logout tests proving recovery receipts and responses cannot cross owners.
14. Backend-connected contract tests proving the production profile accepts real intake, runs matching, exposes accepted Doctors, commits selection, and supports the approved handoff before client rollout.

The existing safety suite remains a mandatory before/after gate for every later F-01 change.

#### Failure behavior

- Backend unavailable, offline, timeout, TLS/DNS failure, 5xx, or malformed response: remain unconfirmed; offer retry/reconcile using the same operation identity; never show a Doctor assignment or success.
- No Doctors/zero acceptances: show server-reported matching, deadline, exhausted, or recovery state. An empty accepted list is not itself success or terminal authority.
- Rejection/cancellation/expired hold: discard stale actions after REST reconciliation and show the truthful terminal/retry state allowed by the server.
- WebSocket disconnect: mark realtime stale, keep only the last confirmed projection, and reconcile through approved REST reads on reconnect/foreground. Do not synthesize progress.
- Selected Doctor disappears or revision changes: selection fails closed, refresh accepted Doctors/status, and require a new authoritative choice when permitted.
- App kill/reopen: validate the account-scoped receipt, recover by the same submission key or journey ID, then route from the returned server state. Missing recovery authority must show an interrupted/unavailable state, not restart silently.
- Unknown server enum or invalid identity/payload: treat as an incompatible response and block progression.
- No backend authority: no confirmed Doctor, en-route, arrival, consultation, or completion UI.

#### Risks

- Wiring the existing `/me/urgent-home` endpoints without changing their backend gate would either fail in production or tempt activation of a synthetic plaintext/allowlisted development path for real patients.
- The current Flutter body-map values, family identifiers, location provenance, and arrival instructions do not directly equal the strict development DTO; mapping them without an approved production contract could misbind a patient or protected location.
- The modern backend stops at commitment and explicitly rejects consultation start; adapting only submission/matching would still leave the most safety-sensitive legacy screens unauthoritative.
- HOME realtime and push are not production-capable. Treating the reserved queue/history API as live would create another silent-delivery failure.
- There is no active-journey scan when both client identifiers are lost. Receipt retention and restart UX require an explicit policy.
- Direct route-map casts and memory-only payloads remain process-death/crash risks until stable-ID reconstruction is implemented.
- The adjacent legacy provider/reservation and conditional Doctor-home demo paths can reintroduce synthetic clinical claims if Phase 1B only replaces the primary matching source.

#### Final decision

**OPTION D — BACKEND CONTRACT ALSO MISSING (for production).** A substantial synthetic-development backend and partial Doctor Flutter client exist, but no production-authorized patient HOME intake/matching/realtime/arrival/consultation contract is available. The development endpoints are explicit evidence for architecture, not authority to process real patient traffic.

**Phase 1A decision at investigation time: BLOCKED_BACKEND_CONTRACT.** That historical decision and its implementation sequence are retained below as future evidence. The current launch-scope decision supersedes authorization to continue: Flutter Phase 1B is **DEFERRED — resume only through explicit CTO/product scope decision**, even if its technical prerequisites later become available.

Future implementation sequence after an explicit scope-resumption decision:

1. Certify the production backend boundary: protected intake, worker activation, exact states/actions/errors, cancellation, recovery retention, and arrival/consultation handoff.
2. Freeze backend contract fixtures and add failing Flutter API/repository/controller/production-wiring tests.
3. Implement strict patient HOME models and one `UrgentHomeApiService`/`UrgentHomeRepository` on the shared `AppHttpClient`.
4. Implement one account-scoped `UrgentHomeController` plus minimal opaque recovery receipt and lifecycle hooks.
5. Inject those components from `lib/main.dart`; adapt the existing intake/review/selection screens without redesign and disconnect all production demo defaults.
6. Enable calling/travel/arrival/QR/consultation screens only for backend states that actually exist; otherwise fail closed and keep them unreachable.
7. Add HOME invalidation/history integration only after production publication is enabled; always reconcile through REST.
8. Run the safety suite, new Phase 1B tests, full bounded suite, backend-connected integration journey, and release-like negative network capture before changing the Phase 1 exit status.

Validation for this investigation: `PHASE_1_SAFETY_SUITE` completed against the current fail-closed worktree with **201 passed, 7 intentionally skipped, 0 failed** in approximately 25 seconds. Phase 1A added no test. The concurrently created untracked boundary test was not part of this safety command and was not authored or modified by Phase 1A, so no Phase 1A before/after test pair was required.

## 7. Phase 2 — Auth & Network Resilience

**Status: ACTIVE — PHASE 2C AUTOMATED CODE COMPLETE; PHYSICAL-DEVICE VALIDATION PENDING**

Implementation evidence: `PHASE_2_AUTH_NETWORK_RESILIENCE.md`.

### Objective

Make authentication and critical network operations safe under Tunisian mobile-network loss, handoff, timeout, server failure, and ambiguous upload/write outcomes.

### Audit findings covered

F-02, F-09, and F-17.

### Dependencies

Phase 1 production-safety boundary; backend refresh/idempotency/upload contracts; reproducible fault injection. Urgent HOME activation or functionality is not a dependency.

### Work items

Add typed transport/auth failure classification, retain sessions on transient refresh failure, define send timeout, make replay eligibility explicit, define upload cancellation/progress/size/memory behavior, and preserve idempotency for ambiguous outcomes.

### Architecture/pattern changes

Evolve shared `AppHttpClient` and refresh coordinator; do not add feature-local clients or blind global retry.

### Explicitly out of scope

Changing credentials/backend contracts without coordination, retrying non-idempotent writes blindly, caching clinical state, or replacing Dio.

### Acceptance criteria

Invalid credentials invalidate; DNS/TLS/timeout/5xx do not. Ten simultaneous 401s still refresh once. Every replayable write/upload documents idempotency/body replay semantics. Large document limits and cancellation are enforced safely.

### Required tests

Refresh outcome matrix, 401 concurrency, one-replay, multipart replay rejection/allowance, send timeout, cancellation, duplicate action, malformed response, and file size boundary tests.

### Runtime/device validation

Offline startup, Wi-Fi/mobile handoff, packet loss, stalled uplink, refresh outage, token expiry, large upload, cancellation, background/kill, and backend-result reconciliation.

### Rollback considerations

Network changes must be independently reversible; rollback must preserve single-flight and never reinstate transient-failure logout or unsafe write retry.

### Exit decision

Exit only with deterministic fault-matrix evidence and no regression in session security/idempotency.

### Current phase decision

Phase 2 is active and remains limited to F-02, F-09, and F-17. Phase 2B shared auth/network/upload hardening and Phase 2C upload process-death recovery are complete from automated evidence. The backend recovery dependency is implemented and consumed. Physical Android/iOS network-handoff, stalled-uplink, background/kill, restart, and backend-reconciliation evidence remains pending, so Phase 2 does not exit. The stable Phase 2 contracts are sufficient for Phase 3 engineering to begin in parallel with device validation; Phase 3 remains not started by this work and may not claim the pending Phase 2 runtime evidence.

Phase 2 must not implement, enable, or depend on Urgent HOME.

## Phase 2A — Auth & Network Investigation

**Investigation date:** 2026-11-09  
**Status:** **COMPLETE — PARTIALLY_READY FOR PHASE 2B**  
**Scope:** investigation and design only; no Phase 2 production implementation is authorized by this record.

This investigation distinguishes the audited repository baseline from concurrent, uncommitted worktree changes. The baseline proves F-02, F-09, and F-17. The worktree currently contains candidate changes in the shared auth/network and document-upload paths, plus focused tests; those changes were inspected and tested as evidence but were not authored, modified, adopted, or certified by Phase 2A. Phase 2B must review them against this contract rather than treating their presence as completion.

### Current network architecture

The production bootstrap creates one `SecureTokenStore`, one `AppHttpClient`, one `AuthRefreshCoordinator`, one `AuthRepository`, and one `AuthController`. A standard `AppHttpClient` owns two Dio instances with the same normalized `/api/v1` base URL:

```text
lib/main.dart
  -> SecureTokenStore
  -> AppHttpClient
       -> authenticated Dio
            -> AuthInterceptor
                 -> bearer injection
                 -> shared AuthRefreshCoordinator
                 -> at-most-one replay fence
       -> refresh/public Dio
            -> no AuthInterceptor
            -> POST /auth/refresh
  -> AuthRepository
       -> AuthApi
       -> /auth/me
       -> PATIENT /profile validation when applicable
  -> AuthController
       -> authenticated / unauthenticated / failure routing
```

| Construction | Classification | Dio count and behavior | Finding |
|---|---|---|---|
| Production `lib/main.dart` `AppHttpClient` | **PRODUCTION STANDARD** | Two: authenticated plus refresh/public; one refresh coordinator; base URL owned by `AppEnvironment`/`AppHttpClient` | Correct standard and the only intended production network authority. |
| `AppHttpClient` fallback inside `OmniCareApp.build` | **POTENTIAL BYPASS** | Another two if production bootstrap does not inject the standard client | Valid as a test/embedding seam, but production wiring must prove the fallback is never selected. |
| Optional fallbacks in `AccountApi`, `FamilyApi`, `FilesApi`, and `DocumentsApi` | **LEGACY / POTENTIAL BYPASS** | Each default construction creates two more Dio instances, a token store, and an isolated refresh coordinator | Production call sites must inject the shared client; default construction can race rotating refresh credentials and miss root invalidation callbacks. |
| Direct default API construction in legacy screens/providers | **POTENTIAL BYPASS** | Found in conversational onboarding, family/provider paths, legacy Doctor screens, `NewHomeScreen`, consultation detail, and the default medical-documents seam | Must be inventoried and either proved non-production or changed to required shared injection during bounded Phase 2B work. |
| `lib/main_demo.dart` | **DEMO/TEST** | One explicitly constructed Dio passed into an `AppHttpClient`; static demo adapter and invalid host | Must remain excluded from production artifacts. |
| Direct Dio under `test/` | **DEMO/TEST** | Test adapters and isolated coordinators | Explicit test seams only. |

No other direct production `Dio()` construction was found. The standard authenticated Dio has exactly one `AuthInterceptor`; the refresh/public Dio deliberately has none. There is no production `LogInterceptor`. The only bootstrap networking diagnostic found logs the notification-initialization exception type, not payloads or credentials.

At the audited baseline, both standard clients had 30-second connect and receive timeouts and no send timeout. The current worktree candidate adds a 30-second default send timeout, gives document upload a two-minute send timeout, and gives document SSE a five-second send/45-second receive-silence policy. These are candidate values, not Phase 2A certification.

### Cold-start session restoration and F-02 root cause

Cold launch reads one versioned JSON `StoredSession` from secure storage. A locally expired refresh token is terminal and the record is cleared. An expired access token with a still-valid refresh token invokes the same single-flight refresh coordinator used by intercepted 401 responses. After a valid refresh, the rotated session is stored, `/auth/me` revalidates current identity and role, PATIENT sessions load the non-medical profile projection, and only then may the authenticated route open.

At the audited baseline, the exact F-02 defect is the catch-all in `AuthRefreshCoordinator._performRefresh`: every exception from reading the session, sending `/auth/refresh`, parsing its payload, storing rotated credentials, or invoking the refresh callback executed `invalidateSession()` and returned `null`. `AuthRepository.restoreSession` then interpreted the missing refresh result as unauthenticated. Consequently, timeout, DNS, connection, TLS, 429, 5xx, and malformed-success conditions destroyed valid persisted credentials. The baseline interceptor also invalidated after any second 401, without requiring an authoritative backend auth code.

The backend contract establishes `AUTH_REFRESH_TOKEN_INVALID`, `AUTH_SESSION_INVALID`, and `AUTH_SESSION_EXPIRED` as explicit `401 UNAUTHORIZED` results. Logout, logout-all, revocation, reuse, and expiry converge on these credential/session codes. A generic 400, 403, or other 4xx is not sufficient evidence to delete credentials.

| Refresh outcome | Audited baseline behavior | Current worktree candidate | Correct desired behavior |
|---|---|---|---|
| 2xx with complete valid session | Store rotated session; notify; replay | Typed `refreshed`; same | Store atomically; notify; allow only eligible replay. |
| 400 validation/invalid request | Catch-all clears session | Preserves unless an exact invalid-session code is present | Preserve by default; surface client/contract failure. A status class alone is not credential authority. |
| 401 with `AUTH_REFRESH_TOKEN_INVALID`, `AUTH_SESSION_INVALID`, or `AUTH_SESSION_EXPIRED` | Clears session | Typed `credentialsRejected`; clears | Clear once and notify unauthenticated. |
| 401 without an authoritative code | Clears session | Preserves | Preserve; report malformed/unknown auth response and fail closed pending retry. |
| 403 | Clears session | Preserves | Preserve unless a future backend contract adds an explicit terminal-session code; do not infer from status alone. |
| Timeout | Clears session | Typed temporary unavailable; preserves | Preserve; bounded retry/retry UI. |
| Connection refused/reset | Clears session | Preserves | Preserve; classify as no connection/transport failure. |
| DNS | Clears session | Preserves | Preserve; classify as DNS/no connection. |
| TLS/certificate/handshake | Clears session | Preserves | Preserve credentials, block access requiring server validation, and surface a non-sensitive security/transport failure. |
| 429 | Clears session | Preserves | Preserve; honor `Retry-After` where valid. |
| 500 | Clears session | Preserves | Preserve; server unavailable. |
| 503 | Clears session | Preserves | Preserve; server unavailable and retry only under bounded policy. |
| Malformed 2xx payload | Clears session | Typed malformed response; preserves | Preserve; fail closed as incompatible server response. |
| Second 401 after successful refresh | Baseline invalidates unconditionally | Invalidates only for exact authoritative code | One replay maximum. Invalidate only for exact terminal auth evidence; otherwise return the classified failure without a loop. |

The session-destruction rule is therefore:

> Persisted session credentials may be destroyed only after local refresh expiry/corruption, explicit user logout/account switch/security action, or an authoritative backend result proving that the refresh/session credential is expired, invalid, or revoked. Transport, rate-limit, server-availability, and malformed-response failures preserve the record.

On retry or app restart, the same stored session is re-evaluated. Logout and account switch fence any in-flight refresh, attempt server logout where applicable, then clear locally regardless of transport outcome. Server revocation is applied when an authoritative code is received. A temporarily unreachable server must leave `AuthController` in a recoverable failure/loading boundary rather than falsely authenticated or unauthenticated; authenticated application routes remain gated until required `/auth/me` validation succeeds. A new global offline mode is neither necessary nor authorized.

### Refresh concurrency and replay

The existing coordinator's `_refreshInFlight` is the important preserved strength. The first 401 creates the refresh Future; the next nine callers receive the identical Future, so ten simultaneous 401 responses produce one refresh call. Rotated credentials are stored before the Future completes, and each eligible caller reconstructs its own request with the new access token. `omnicare_auth_retry` in request `extra` prevents a second replay loop. Logout/session end increments a generation, drains and fences the refresh, and clears locally.

The refresh request itself is not caller-cancellable and, under the current candidate defaults, can consume separate connect/send/receive bounds rather than a guaranteed 30-second wall-clock maximum. Cancelling an original request while it awaits the shared refresh does not cancel the refresh for other callers; Phase 2B must ensure the cancelled caller does not later replay. Shared refresh must remain independent of any single consumer's `CancelToken`.

| Request/body form | Generic post-refresh replay classification | Reason |
|---|---|---|
| GET / HEAD / OPTIONS with reconstructable request state | **SAFE** | Semantically safe; still preserve cancellation and one-replay fence. |
| DELETE | **SAFE ONLY WITH IDEMPOTENCY OR CERTIFIED ENDPOINT SEMANTICS** | HTTP idempotence does not prove application recovery semantics or reconstructability. |
| JSON POST / PATCH / PUT | **SAFE ONLY WITH IDEMPOTENCY AND A RECONSTRUCTABLE IMMUTABLE BODY** | A stable backend operation key and unchanged payload are required. |
| JSON write with operation identity only inside the body | **UNKNOWN UNTIL DECLARED** | The backend may be safe, but the interceptor cannot infer that contract from arbitrary JSON. |
| FormData using bytes or file paths | **UNSAFE TO GENERICALLY REPLAY** | Multipart bodies are consumable and must be rebuilt by the owning API/repository. |
| `MultipartFile.fromBytes` / `MultipartFile.fromFile` | **UNSAFE TO GENERICALLY REPLAY** | The `MultipartFile` stream is single-use even when its source could be rebuilt. |
| Arbitrary `Stream` body | **UNSAFE TO GENERICALLY REPLAY** | Consumption/reconstruction is unknown. |
| Download GET | **SAFE only as a fresh request** | Restart from zero is safe for ordinary GET; partial/resumable downloads need Range/validator semantics. |

Replay eligibility must be explicit request metadata owned by the shared network contract, not guessed only from the HTTP method and not represented by feature code knowing interceptor implementation keys. The recommended declaration has three values: automatic safe read; declared idempotent/reconstructable write; never generic replay. The declared-write branch requires a non-empty stable idempotency/operation identity, immutable reconstructable body, and endpoint certification. Multipart/upload APIs receive a typed “refresh succeeded; rebuild and retry explicitly” result, then reconstruct a fresh body with the same key. Unknown requests default to no generic replay.

### Timeout, failure mapping, and cancellation findings

| Category | Audited baseline | Required Phase 2 policy |
|---|---|---|
| Normal JSON read/write | Connect 30s; receive 30s; no send bound | Separate bounded connect/send/receive values, with operation-level cancellation. |
| Authentication/refresh | Same defaults; shared refresh not caller-cancellable | Strict bounded refresh attempt; preserve the shared Future; transport failure preserves credentials. |
| Medical-document upload | Inherited no send bound | Explicit larger upload send bound, progress, user cancellation, stable operation identity, and explicit multipart rebuild. |
| Avatar/image upload | Inherited defaults; full bytes | Explicit image-upload bound and cancellation; keep its 8 MB and magic-byte validation. |
| Downloads | Inherited receive bound; byte responses can still allocate the full object | Distinguish small downloads from large/resumable files and define storage/memory limits. |
| SSE/status stream | Ordinary receive timeout did not express heartbeat silence | Stream-specific connect/send and heartbeat/silence timeout, followed by REST reconciliation. |

The smallest useful central transport model is `timeout`, `noConnection`, `dns`, `tls`, `cancelled`, `rateLimited`, `serverUnavailable`, `unauthorized`, `forbidden`, `conflict`, `notFound`, `invalidResponse`, and `unknown`, with safe status/code/retry metadata. `AuthRefreshResult` remains a specialized auth decision layered on that classification. Repositories continue mapping transport failures into domain failures; views must not receive raw `DioException`. Current mapping is feature-local and uneven: auth, documents, scheduled care, clinic/request, and sharing paths have partial domain mapping, while several thin APIs can still expose raw Dio errors.

`CancelToken` is already used well in scheduled care, patient/Doctor directories, notification center, request history, urgent CABINET, Doctor workspace/agenda/offer controllers, and clinic flows. These controllers generally replace tokens for new generations and cancel on disposal. Gaps include the shared refresh wait, many account/auth writes, avatar upload, push token registration, and legacy API calls. Cancellation has three distinct meanings:

- UI cancellation stops awaiting/rendering and suppresses stale callbacks.
- Network cancellation aborts the local Dio exchange where supported.
- Business cancellation is a separate authoritative server command.

Neither of the first two proves that a server write did not commit. An ambiguous write must reconcile by its stable operation identity or authoritative read.

No connectivity-status package is justified by this investigation. Wi-Fi/mobile handoff or temporary loss causes the active socket/request to succeed, fail, or time out according to the OS and Dio; it is not migrated by application code. Recovery should be driven by classified request outcomes and authoritative reconciliation. Physical Android/iOS tests remain required for handoff, stalled uplink, background suspension, and reconnect timing.

There is no global lifecycle cancellation for ordinary Dio requests or refresh. While the process remains alive, they may continue until cancellation or timeout; background suspension timing is platform-controlled. Medical-document status watching pauses outside the active lifecycle and resumes/reconciles, but an upload is only cancelled by explicit user action or widget disposal in the candidate worktree. Process kill terminates in-memory work and loses an in-memory upload operation/key. These runtime effects cannot be certified statically.

### Critical write inventory

This is the Phase 2 replay-certification inventory, not authorization to change endpoint contracts. Urgent HOME is excluded.

| Operation | Endpoint family/body authority | Stable identity today | Generic replay disposition and risk |
|---|---|---|---|
| Clinic request submission | `POST /appointment-requests/clinic`; JSON includes client `requestId` | Body operation ID; backend returns created/replayed | Potentially safe after endpoint declaration, but no idempotency header/metadata tells the interceptor; ambiguous response already has recovery concepts. |
| Clinic request cancel/info response | `POST /appointment-requests/{id}/cancel` and `/information-response`; versioned JSON | Expected version, no interceptor-visible key | Do not generic replay until backend semantics and declaration are certified. |
| Scheduled booking create | `POST /doctor-booking-requests`; JSON includes client `requestId` | Body request ID | Likely recoverable but currently not marked; certify exact replay contract. |
| Scheduled cancel/accept/decline and appointment cancel | Versioned POST commands | Explicit `Idempotency-Key` | Candidate for declared JSON replay after immutable-body tests. |
| Clinic staff task/case/handover transitions | Versioned POST command families | Expected version; no explicit idempotency header found | No generic replay; reconcile current task/case/handover authority. |
| Urgent CABINET targeted submission/decisions | JSON command families | Stable keys and secure recovery receipt | Declared replay/recovery patterns are strong; preserve account scoping and reconciliation. |
| Doctor consultation start/finish | Canonical POST start/finish | Explicit stable key | Candidate for declared JSON replay; active-consultation/read reconciliation remains mandatory. |
| Clinical record/order/prescription/artifact mutations | JSON POST/PUT command families | Explicit `Idempotency-Key` on modern APIs | Candidate only after each command's backend replay and body reconstruction are certified. |
| Medical-share QR issue/access actions | JSON POST | Explicit stable key on QR/sharing commands | Candidate for declared JSON replay; consumption/verification commands must retain single-use authority and authoritative reread. |
| Profile/onboarding/passport/family changes | POST/PATCH/DELETE JSON | No stable header in legacy APIs | Never generic replay; duplicate create/deactivate and unknown profile outcomes require endpoint-specific treatment. |
| Account security/password/phone/device/session changes | Auth/security POST families | No general stable key | Never generic replay. Password/session revocation commands require explicit user retry/revalidation. |
| Notification read/read-all | POST | No stable key | Low business impact but no generic replay declaration; safe reconciliation is inbox reread. |
| Push token register/unregister | `POST`/`DELETE /notifications/token` | Token is natural identity but no replay declaration | Best-effort today; certify server upsert/delete semantics before automatic replay. |
| Medical-document upload/delete | Multipart `POST /documents`; idempotent delete | Explicit generated key | Upload must rebuild multipart explicitly with same key; never interceptor replay. Delete JSON-free request may be declared after contract test. |
| Avatar upload/remove | Multipart `PATCH /profile/avatar`; `DELETE /profile/avatar` | No stable key | Never generic replay; multipart must be rebuilt and unknown outcome reconciled by profile read. |

The present write surface mixes explicit headers, body operation IDs, optimistic versions, natural keys, and unmarked writes. Phase 2B must certify and annotate existing contracts rather than add blind global retry.

### F-17 medical-document upload findings

The audited path was:

```text
MedicalDocumentsScreen
  -> FilePicker.pickFiles(withData: true)
  -> PlatformFile.bytes
  -> DocumentsApi.startUpload(Uint8List)
  -> MultipartFile.fromBytes
  -> FormData
  -> AppHttpClient.dio.post(/documents)
  -> backend scan/status via REST + SSE
```

The UI displayed and picker dialog checked a 20 MB limit only after `withData: true` had already loaded the file. `DocumentsApi` itself accepted the full `Uint8List` without an independent size/source check, inherited the missing send timeout, provided no `CancelToken` or `onSendProgress`, and held the operation only in memory. It did generate an idempotency key, but a generic interceptor replay could reuse consumed FormData, and process kill lost the key before an unknown outcome could be reconciled.

The backend is the final authority at 20 MiB: Spring `max-file-size` is 20 MB, `max-request-size` is 21 MB, and `DocumentService.MAX_FILE_SIZE_BYTES` is `20 * 1024 * 1024`. The UI text also says 20 MB. The audited client lacked an API-layer limit; the current candidate adds the same 20 MiB check. The backend independently validates type/metadata and size.

The current candidate demonstrates that no dependency change is needed: native `PlatformFile.path` plus `MultipartFile.fromFile` supports path-based streaming; web retains bytes because a stable native path is unavailable. It also demonstrates Dio `CancelToken`, `onSendProgress`, a dedicated upload send timeout, and reconstructing fresh multipart data with the same in-memory key after a refresh-required or ambiguous failure. Phase 2A does not certify its UI changes or process-death behavior.

Memory analysis is code-derived, not a measured RAM claim:

| Selected file | Audited `withData: true` path | Candidate native path | Candidate web path |
|---:|---|---|---|
| 5 MB | At least one 5 MB `Uint8List` retained by `PlatformFile`/operation; multipart and transport add encoding/chunk overhead. App code does not explicitly clone the list, but zero-copy cannot be guaranteed. | Size checked, path retained, `fromFile` streams; no intentional full-file Dart buffer. | At least one 5 MB byte buffer plus multipart/transport overhead. |
| 20 MB | Same pattern at the maximum accepted size; at least 20 MB retained before upload. | Accepted and path-streamed. | Accepted; at least 20 MB buffered because web picker returns data. |
| 50 MB | The picker can allocate the full bytes before the dialog rejects it. | Rejected from `PlatformFile.size` before reading the native path. | May already allocate roughly the selected payload before the 20 MiB check rejects it. |
| 100 MB | Same selection-time full-buffer risk, with larger transient pressure. | Rejected before native file read. | Same web selection-time prebuffer risk; rejection occurs after picker data materialization. |

`MultipartFile.fromBytes` is built from the supplied list; this application does not call `Uint8List.fromList`, so a second explicit full copy is not proved. Dio's multipart encoding, adapter, and platform transport can allocate additional chunks or copies. Profile avatar handling is useful but not a document template: it checks an 8 MiB size before `readAsBytes`, validates JPEG/PNG magic bytes, can compress a native image into a temporary JPEG, reports progress, then still buffers the entire image and uses `MultipartFile.fromBytes`. It has no `CancelToken`, stable idempotency key, or explicit upload timeout. PDFs must not be image-compressed, and temporary image cleanup is a separate retention concern.

The recommended upload ownership is:

```text
existing view
  -> document upload controller/view-model state
      -> DocumentsRepository / DocumentsApi
          -> native path source or bounded web bytes
          -> fresh FormData per attempt
          -> shared authenticated Dio
          -> CancelToken + onSendProgress + upload timeout
          -> stable operation key
          -> authoritative status/list reconciliation
```

The existing presentation need not be redesigned; progress can feed an existing loading/progress affordance. Leaving the screen or pressing an approved cancel action may cancel the local network operation, but must display/reconcile an unknown outcome when the server may have committed. Backgrounding must not promise continued upload. Process kill requires an account-scoped opaque receipt and server lookup/recovery by idempotency key or another authoritative correlation mechanism; the current document API can read by `documentId` only after that ID is known and has no recovery-by-key endpoint.

### Error, logging, security, and lifecycle boundaries

- Bearer injection and refresh credentials remain inside the shared network/token layers. `StoredSession.toString` redacts token values.
- No request/response body logger or `LogInterceptor` is installed. Phase 2B must retain a prohibition on tokens, medical bodies/files, phone, patient identity, GPS, QR/grant material, and MRS content in logs or telemetry.
- Feature-level `debugPrint`/`consoleLog` calls observed in the relevant path report fixed text or an exception type; no secret value was reproduced by this investigation.
- `SecureTokenStore` clears malformed/corrupt/unsupported local records and explicit logout/session invalidation. Storage write failure cannot report authentication success.
- A transport cancellation is not server rollback; a lifecycle pause is not cancellation; a socket reconnect is not proof of request outcome.

### Backend dependencies and readiness decision

No backend change is required to implement and validate F-02, add bounded send timeouts, centralize transport classification, preserve single-flight refresh, or make replay opt-in. Existing modern endpoints already provide enough stable keys/revisions for many critical writes.

At the Phase 2A investigation boundary, one narrow backend contract dependency remained for complete F-17 process-kill/response-loss recovery: after multipart commit and response loss, Flutter had no authoritative read by idempotency key. That historical blocker has since been implemented by the backend dependency task and consumed by Flutter Phase 2C. Phase 2A correctly prohibited a process-death claim before those later changes and did not expand into Urgent HOME or unrelated backend redesign.

**Historical decision: PARTIALLY_READY.** Phase 2B was permitted only through an explicit implementation instruction. Its backend-dependent process-kill criterion is now superseded by the completed backend recovery contract and Phase 2C Flutter consumption; the remaining current gap is physical-device validation.

### Required Phase 2B sequence

1. **2B-1 — Auth classification:** replace destructive catch-all behavior with the authoritative outcome matrix; preserve single-flight/generation fencing; add the smallest recoverable startup failure state without granting unvalidated access.
2. **2B-2 — Shared transport policy:** introduce central safe transport classification, bounded category timeouts, and explicit replay metadata defaulting to no write replay.
3. **2B-3 — Write-path certification:** inventory every production write, require shared-client injection, certify stable key/body reconstruction/reconciliation, and annotate only approved operations as replayable.
4. **2B-4 — Medical-document upload:** enforce the backend-aligned limit before native read, stream from native path, bound web bytes, rebuild multipart explicitly, add network cancellation/progress/timeouts, and retain the same operation key for safe in-process retry. Keep process-kill recovery unclaimed until the narrow backend dependency is resolved.
5. Run the focused tests, full bounded regression gate appropriate to touched shared networking, and physical Android/iOS fault matrix before changing Phase 2 status.

### Required tests and current evidence

Phase 2B must add or retain deterministic tests for every refresh outcome in the matrix; ten concurrent 401s/one refresh; rotated-token replay; logout racing refresh; caller cancellation during refresh wait; one-replay fencing; authoritative and non-authoritative second 401; GET/HEAD/OPTIONS/DELETE/POST/PUT/PATCH replay declarations; immutable JSON reconstruction; FormData/MultipartFile/stream rejection; upload timeout/cancel/progress/20 MiB boundary; same-key multipart rebuild; commit-before-response reconciliation; account switch/logout isolation; raw-Dio containment; and production shared-client wiring.

Runtime/device gaps remain: DNS/TLS fault injection, 429 `Retry-After`, stalled uplink, Wi-Fi/mobile handoff, upload at 5/20 MiB, web selection pressure, background/resume, OS kill before/during/after server commit, and backend result reconciliation on physical Android and iOS.

Focused validation against the inspected worktree:

- `flutter test --no-pub --reporter compact --timeout 60s test/auth_phase1_test.dart test/core/api/documents_api_test.dart test/features/profile/medical_documents_screen_test.dart test/phase1_clinical_correctness_boundary_test.dart` — **111 passed, 7 intentionally skipped, 0 failed**.
- `flutter test --no-pub --reporter compact --timeout 60s test/phase1_clinical_correctness_boundary_test.dart` — **6 passed, 0 failed**; the Urgent HOME fail-closed boundary remains green.

Phase 2A changed documentation only. It changed no production code, UI/UX, backend contract, dependency, or phase status and performed no Git write operation.

## Phase 2B — Auth & Network Implementation

**Implementation date:** 2026-11-09  
**Overall status:** **AUTOMATED IMPLEMENTATION COMPLETE WITH PHASE 2C; DEVICE VALIDATION PENDING**

| Exit dimension | Status | Evidence / boundary |
|---|---|---|
| Code correctness | **COMPLETE FROM AUTOMATED EVIDENCE** | Focused Phase 2B gate, bounded full Flutter suite, analyzer, and Phase 1 boundary pass. |
| Backend-contract completeness | **IMPLEMENTED AND CONSUMED IN PHASE 2C** | `GET /api/v1/documents/uploads/recovery` provides an actor/subject-scoped, non-mutating recovery read by the original upload key; Flutter now persists the minimal receipt and consumes all recovery outcomes. |
| Device/network certification | **PENDING** | Physical Android/iOS DNS, TLS, handoff, stalled-uplink, background, termination, and upload memory/runtime evidence has not been executed. |

This phase implemented only F-02, F-09, and the client-owned portion of F-17. It did not implement or enable Urgent HOME, change the approved UI/UX, replace Provider/ChangeNotifier or Dio, upgrade a dependency, start Phase 3, or perform a Git write operation.

### Root cause and implementation

| Finding | Root cause | Implementation | Current finding status |
|---|---|---|---|
| F-02 | Refresh used a destructive catch-all: transport, 429/5xx, malformed success, and generic auth HTTP failures were treated as credential rejection. A repeated 401 also invalidated without requiring authoritative backend evidence. | `AuthRefreshCoordinator` now returns typed refresh outcomes and clears credentials only for local invalid/expired storage, explicit session end, or exact terminal codes `AUTH_REFRESH_TOKEN_INVALID`, `AUTH_SESSION_INVALID`, and `AUTH_SESSION_EXPIRED`. Temporary and malformed outcomes retain the stored session. Cold-start validation remains fail-closed in the recoverable bootstrap state. A cancelled consumer cannot replay after the shared refresh, while other consumers retain the single-flight result. The second-401 path is one-replay-only and invalidates only for an exact terminal code. | **AUTOMATED CODE COMPLETE; DEVICE FAULT VALIDATION PENDING** |
| F-09 | Standard clients had no send timeout; replay eligibility was inferred from method/body/header combinations; production-reachable legacy API construction could create isolated clients and refresh coordinators. | Added category-specific timeout policy, safe central `TransportFailure`, and explicit `RequestReplayPolicy` values `automaticSafeRead`, `declaredIdempotentWrite`, and `never`. Unknown writes default to no replay. Declared writes require a stable `Idempotency-Key` and reconstructable immutable JSON. FormData, MultipartFile, Stream, and unknown bodies are never interceptor-replayed. Production onboarding, patient-home passport edit, Doctor family reads, consultation attachment upload, and document routes now resolve the bootstrap-owned client. | **AUTOMATED CODE COMPLETE FOR CERTIFIED PATHS; DEVICE VALIDATION PENDING** |
| F-17 | Native document selection loaded full bytes before the 20 MiB check; uploads had no cancellation/progress/send bound; FormData was consumable; an in-memory operation key could not recover a committed response after process death. | Native selection keeps `PlatformFile.path`, validates `PlatformFile.size`, then uses `MultipartFile.fromFile`; web remains bounded to `20 * 1024 * 1024` bytes. `DocumentsApi` creates fresh MultipartFile/FormData for every attempt, explicitly forbids interceptor replay, retains the same operation key, uses `CancelToken`, progress, and a two-minute send bound. Phase 2C persists only opaque recovery identity before dispatch and resolves ambiguous/cold-start outcomes through the backend recovery GET without resending multipart. | **AUTOMATED CODE COMPLETE; PHYSICAL PROCESS-KILL/DEVICE VALIDATION PENDING** |

### Shared transport and timeout contract

`TransportFailure` retains only a category, HTTP status, stable problem code, and bounded retry-after duration. It does not retain request/response bodies, authorization headers, medical content, identity, GPS, tokens, or uploaded bytes. Current categories are timeout, no connection, DNS, TLS, cancelled, rate-limited, server unavailable, unauthorized, forbidden, conflict, not found, invalid response, and unknown. Auth and document APIs translate this safe transport boundary into their existing `ApiException`/domain behavior; views do not receive raw Dio failures.

Timeouts remain phase bounds rather than a promised wall-clock maximum:

| Category | Connect | Send | Receive / silence |
|---|---:|---:|---:|
| Standard JSON | 30 s | 30 s | 30 s |
| Auth refresh | 30 s | 30 s | 30 s |
| Medical-document upload | 30 s inherited from the shared client | 2 min | 30 s |
| Document SSE | 30 s inherited from the shared client | 5 s | 45 s receive-silence bound |

### Write-path certification

**Declared replayable:** scheduled-care Patient and Doctor commands that already carry stable idempotency keys; canonical Doctor consultation start and finish; modern clinical record, order, prescription, artifact, and medical-access mutations with existing stable keys; medical-share QR/sharing commands with existing stable keys; and modern Urgent CABINET decisions/submission/cancellation/withdrawal/arrival commands. These APIs opt in through shared replay metadata; the interceptor still requires immutable reconstructable JSON and the same non-empty key.

**Explicitly no generic replay:** profile and passport mutation, family mutation, password/phone/account-security actions, uncertified legacy clinic transitions, notification mutations, push registration, and other unannotated writes remain conservative by default. Avatar multipart is explicitly `never` while preserving its existing 8 MiB and magic-byte validation. Medical-document multipart is explicitly `never`; only `DocumentsApi` may rebuild it with the same operation key. Deferred Urgent HOME paths were not certified or modified.

### Production shared-client wiring

The production bootstrap remains the sole owner of one `AppHttpClient`, one `SecureTokenStore`, one `AuthRefreshCoordinator`, one authenticated Dio, and one refresh/public Dio. Production-reachable default construction was removed from conversational onboarding, the patient-home passport edit, legacy Doctor family reads, and consultation attachment upload. The medical-document production route already injects shared `DocumentsApi` and `AccountApi`; optional constructors remain only as explicit test/embedding seams. A source regression test proves no additional `Dio()` construction exists under production `lib/` outside `AppHttpClient` and the isolated demo entrypoint.

### Medical-document architecture and recovery boundary

```text
existing MedicalDocumentsScreen presentation
  -> account-scoped upload operation and UI state
      -> DocumentsApi
          -> native file path or bounded web bytes
          -> fresh multipart body per attempt
          -> shared authenticated Dio
          -> stable idempotency key + CancelToken + progress + upload timeout
          -> authoritative list/status/SSE reconciliation
```

No medical bytes are persisted for recovery. Backgrounding does not promise continued upload. When local cancellation, disposal, account change, timeout, or response loss leaves commit status uncertain, the client requires authoritative reconciliation and does not claim server rollback.

`PROCESS_DEATH_UPLOAD_RECOVERY — CONTRACT CONSUMED; DEVICE EVIDENCE PENDING`: the backend exposes `GET /api/v1/documents/uploads/recovery?patientId=...` using the original `Idempotency-Key`. Spring revalidates the authenticated account and operational Patient ownership; MRS revalidates the MRS subject and resolves its existing initialization receipt to the authoritative document. Flutter Phase 2C persists a versioned secure receipt containing only account scope, Patient ID, operation key, and creation time before multipart dispatch. Cold start and same-session ambiguous outcomes query recovery before any resend. `SUCCEEDED` accepts/reconciles the document and clears the receipt; `IN_PROGRESS` retains it; `FAILED`, non-enumerating not-found, and local 24-hour expiry clear it without resubmission. Temporary recovery failure retains it. Logout/account change cancels and generation-fences the operation and clears the owning receipt. No file data, path, filename, MIME, medical metadata, or credential is persisted. Physical Android/iOS process-kill and restart evidence remains pending, so Phase 2 does not exit.

### Material files changed

- Shared auth/network: `lib/core/network/auth_refresh_coordinator.dart`, `auth_interceptor.dart`, `app_http_client.dart`, new `transport_failure.dart`, new `request_replay_policy.dart`, and new `network_timeout_policy.dart`.
- Auth/domain mapping: `lib/features/auth/data/auth_api.dart` and the existing recoverable `AuthController`/repository behavior retained by tests.
- Upload: `lib/core/api/documents_api.dart`, `lib/core/api/files_api.dart`, `lib/features/profile/medical_documents_screen.dart`, and new `lib/features/profile/medical_document_upload_controller.dart`.
- Shared-client production call sites: `lib/main.dart`, conversational onboarding, patient `NewHomeScreen`, legacy Doctor request/dashboard family reads, and patient consultation detail.
- Certified write APIs: scheduled care, Doctor scheduled care, consultation start/finish, clinical record/order/prescription/artifact/medical access, medical sharing/QR, and Patient/Doctor Urgent CABINET repositories.
- Tests: `test/auth_phase1_test.dart`, `test/core/api/documents_api_test.dart`, `test/features/profile/medical_documents_screen_test.dart`, new `test/features/profile/medical_document_upload_recovery_test.dart`, new `test/core/network/transport_failure_test.dart`, and new `test/phase2_auth_network_boundary_test.dart`.

### Validation record

- Focused Phase 2C + Phase 1 gate: **153 passed, 7 intentionally skipped, 0 failed**. It covers the Phase 2B matrix plus secure receipt content/schema, receipt-before-dispatch ordering, cold-start recovery without the original file, same-session response-loss recovery without a second POST, `IN_PROGRESS`, `SUCCEEDED`, `FAILED`, non-enumerating not-found, temporary recovery failure, 24-hour expiry, explicit new-key behavior after terminal resolution, logout/account isolation, and late callback fencing.
- Full bounded Flutter suite: **1,688 passed, 7 intentionally skipped, 0 failed in 3 minutes 38 seconds** under a ten-minute process alarm and per-test 60-second timeout.
- Analyzer: **388 findings = 0 errors, 31 warnings, 357 infos**. No analyzer error or warning was introduced; the warning count remains the Phase 0 baseline of 31. Unrelated infos were not cleaned broadly.
- Standalone Phase 1 boundary: **6 passed, 0 failed**. Urgent HOME remains deferred and fail-closed.

### Remaining runtime and exit decision

Physical Android and iOS evidence remains required for offline cold start and retry, DNS/TLS faults, 429/retry-after behavior, Wi-Fi/mobile handoff, packet loss, connection reset, stalled uplink, token expiry during 5/20 MiB upload, explicit cancellation, background/resume, termination before/during/after commit, memory behavior on native and web selection, and backend-result reconciliation. These are not certified by source or widget tests.

**Exit decision:** automated code correctness for 2B-1 through 2B-4 and Phase 2C process-death recovery is complete. The backend recovery contract is implemented and consumed, but physical Android/iOS process-kill/network certification is pending. Phase 2 therefore does not exit. Phase 3 engineering is **authorized to begin in parallel** because its typed-failure, idempotency, and recovery dependencies are stable; it is not started by this work and cannot claim or waive the pending Phase 2 device evidence.

## Phase 2C — Medical-document upload process-death recovery

**Implementation date:** 2026-11-09  
**Status:** **AUTOMATED CODE COMPLETE — PHYSICAL ANDROID/iOS VALIDATION PENDING**

Phase 2C consumes the existing backend recovery read without changing backend or MRS source. One eager, account-scoped `MedicalDocumentUploadController` is injected from `lib/main.dart` and uses the bootstrap-owned `DocumentsApi`/`AppHttpClient`. Before multipart dispatch it persists one secure schema-v1 receipt containing only account scope, operational Patient ID, original idempotency key, and creation time. It persists no file bytes, path, filename, MIME, display metadata, clinical data, or credentials.

Cold start waits for authenticated account and Patient identity, reads only that account's receipt, and calls recovery with the original key. Same-session timeout/cancellation/response loss after possible dispatch follows the same recovery-first path. It never starts another multipart POST while a receipt is unresolved. `SUCCEEDED` reconciles the authoritative document and clears the receipt; `IN_PROGRESS` retains it and resumes authoritative status reconciliation; `FAILED` and `DOCUMENT_UPLOAD_RECOVERY_NOT_FOUND` clear it and require explicit new user intent; temporary transport/server failure keeps it. The local 24-hour horizon matches the backend minimum recovery contract. Owner change/logout cancels local work, clears the owning receipt, and generation-fences late callbacks.

Automated evidence is the focused **153 passed, 7 skipped, 0 failed** gate, full **1,688 passed, 7 skipped, 0 failed** suite, analyzer **0 errors / 31 baseline warnings / 357 infos**, and standalone Phase 1 boundary **6 passed, 0 failed**. Physical Android/iOS validation must still cover termination before dispatch, during transfer, after commit before response, during `IN_PROGRESS`, after terminal recovery, background/resume, account switch, stalled uplink, and one-document backend convergence. No physical claim is made.

## 8. Phase 3 — Lifecycle & Recovery

**Status: ACTIVE — PHASE 3B AUTOMATED CODE COMPLETE; PHYSICAL ANDROID/iOS VALIDATION PENDING**

### Objective

Recover critical workflows from Android process death, iOS termination/suspension, stale routes, and unknown write outcomes.

### Audit findings covered

F-05 and F-11.

### Dependencies

Phase 2 typed failures and idempotency semantics; stable backend identifiers/reconciliation endpoints.

### Work items

Wire account-validated in-flight restore before new clinic operation creation, orchestrate verify/retry UX, define operation receipt lifecycle/TTL, validate route payloads, and reconstruct critical destinations from identifiers plus current authorization/server state.

### Architecture/pattern changes

Recovery belongs in domain controllers/repositories or an optional workflow use case, not route widgets or raw storage services.

### Explicitly out of scope

Generic restoration of every cosmetic route, background execution promises, navigation-framework replacement, or offline clinical authority.

### Acceptance criteria

Process death cannot lose/duplicate a committed request. Critical routes reject malformed/stale input and rebuild authorized state from identifiers.

### Required tests

Store migration/account mismatch/TTL tests, committed-before-response recovery, no-commit retry, logout during recovery, malformed route args, stale notification, and reconstruction tests.

### Runtime/device validation

OS kill at each write boundary, cold relaunch, upgrade over stored receipts, account switch, delayed notification, and background/foreground transitions on Android/iOS.

### Rollback considerations

Persisted schema changes need forward/backward handling. A rollback must not discard unknown-outcome receipts or generate a new operation ID silently.

### Exit decision

Exit only when critical workflow state converges to backend truth after process loss.

## Phase 3A — Lifecycle & Recovery Investigation

**Investigation date:** 2026-11-09

**Status:** **COMPLETE — READY_FOR_PHASE_3B**

**Scope:** investigation and design only; no Phase 3 production implementation is authorized by this record.

This investigation traced launch-critical business recovery, persisted receipts, route arguments,
notification entry, account/family isolation, controller ownership, and the available backend reads.
It did not implement F-05 or F-11, modify application behavior, change backend/MRS code or contracts,
alter Urgent HOME, redesign UI/UX, replace Provider/ChangeNotifier, migrate navigation, upgrade a
dependency, or perform a Git write operation. Phase 2 physical Android/iOS validation remains open.

### F-05 exact current defect

The clinic request flow already has the right operation identity and most of the required backend
authority, but its production lifecycle is wired in the wrong order:

```text
RequestOperationId (client UUIDv4; also backend request/resource identity)
  -> InFlightRequestStore (secure schema v2 record)
  -> RequestSubmissionController.submit()
       -> save receipt before POST
       -> RequestRepository
       -> RequestApi POST /appointment-requests/clinic
  -> backend 201 created or 200 exact replay
  -> controller clears the receipt after success

process restart today
  -> RequestSubmissionController is constructed lazily
  -> restoreInFlightOperation() is never called by production bootstrap
  -> opening RequestFlowEntryScreen calls beginNewRequest()
  -> beginNewRequest() mints a new ID and clears the unresolved secure record
```

`restoreInFlightOperation()` works in isolation and deliberately restores an interrupted/retryable
state without auto-sending, but no production call site invokes it. `RequestFlowEntryScreen` instead
starts a new operation after its first frame. `DoctorCabinetEntryScreen` uses the same controller
entry behavior even though that path does not submit the Patient clinic request, so it can also
erase an unrelated unresolved record.

The current receipt is written before the network call, but storage failure is swallowed and the
POST is allowed to proceed. Its single global secure-storage record contains `requestId`, kind,
clinic ID, SELF/family subject, situation, and—when AMBULANCE is selected—the complete pickup JSON.
That pickup includes exact coordinates or postal address and capture time. Despite the store's
documentation, this is sensitive location data and violates the target opaque-receipt rule. The
record is schema-versioned (`2`) and subject-scoped, but has no authenticated account scope,
creation time, TTL, backend-retention metadata, or separately recorded resource ID. Unknown schema,
malformed content, and invalid intent shape are deleted. Retryable failure retains the record;
terminal failure, success, explicit clear, an intent change after an attempt, or `beginNewRequest()`
clears it. Logout/session invalidation clears it, but the direct authenticated account-change branch
does not clear or generation-fence `RequestSubmissionController`.

The backend contract is already sufficient. `requestId` is both command identity and resource ID;
an exact same-ID/same-payload POST replays the original request, a changed payload conflicts, and
`GET /api/v1/appointment-requests/{requestId}` performs an owner-authorized, non-enumerating read.
F-05 is therefore a client-only recovery/wiring defect, not a backend-contract gap.

### Clinic unknown-outcome matrix

| Boundary | Current behavior | Required Phase 3B behavior |
|---|---|---|
| Before dispatch | An operation ID exists, but no durable dispatch fact is recorded. A new operation is safe only when dispatch is known not to have occurred. | Distinguish draft from a durably prepared/dispatched operation. Do not preserve a never-dispatched draft as server truth. |
| Receipt saved; request sent; no response | Retryable failure retains the record in-process, but restart recovery is unwired. | After authenticated owner validation, GET by the same `requestId`; never mint a replacement ID while outcome is unresolved. |
| Backend committed; app died | Backend has the request and accepts exact replay, but production startup does not consume the stored ID. | Reconcile by owner-authorized GET. Route from the returned request status. Same-ID POST is only an explicit fallback after an authoritative not-found and a still-valid reconstructable intent. |
| Backend rejected terminally | Controller clears the receipt for a classified terminal failure. | Clear only when non-commit is authoritative or the idempotency conflict is safely surfaced. Never infer rejection from transport loss. |
| Restart hours later | No local TTL exists. The owner-authorized resource read remains available. | Use the resource read first. Set a client horizon only from documented backend/resource authority; do not invent legal retention. |
| Account switch | Logout clears, but direct authenticated owner change omits this controller; the store itself has no account field. | Store account scope, reject mismatch without consuming another owner's key, cancel/fence old work, and clear/quarantine according to explicit logout/switch policy. |
| Family subject changed | Family ID is stored, but current ownership is not locally revalidated before the interrupted state is exposed. | Treat the subject as an opaque reference; revalidate current family ownership through authenticated backend authority before retry or navigation. |
| User starts another request | `beginNewRequest()` silently clears the unresolved record. | Resolve, explicitly abandon, or safely terminalize the prior operation before minting a new ID. Never clear it merely because the route opened. |

The recovered destination must be derived from the backend projection: unknown/submitting stays in a
recovery boundary; created/pending/information-required/cancelled opens the stable-ID request detail
with its current server actions; not-found permits an explicit same-key recovery decision; forbidden
or account/subject mismatch fails closed. Persisted UI state never chooses the destination.

### Launch-critical workflow recovery inventory

| Workflow | Classification | Identity, authority, and current recovery evidence | Remaining Phase 3 concern |
|---|---|---|---|
| Authentication/session restore | **SAFE** | Secure schema-v1 `StoredSession`; legacy-key migration; refresh/session validation; `/auth/me` and Patient profile validation precede protected routing; transient Phase 2 failures preserve valid credentials. | Operation recovery must run only after the authenticated owner is known and must not hold startup indefinitely. |
| Profile/family subject selection | **SAFE for authority / NONCRITICAL for cosmetic restoration** | Family members are loaded for the authenticated account and server ownership is rechecked on protected operations. Provider generations clear stale family data on logout. | Selected UI subject is generally memory-only. Critical receipts must carry only an opaque family reference and revalidate it; do not restore a stale `FamilyMember` object. |
| Clinic appointment request submission | **UNSAFE** | Stable `requestId`, pre-POST secure record, exact replay, owner-authorized resource GET, controller generation and cancellation exist. | Restore is unwired; route entry destroys the record; no account/time scope; storage failure is tolerated; exact pickup location is persisted. This is F-05 and Phase 3B priority one. |
| Clinic request history/detail | **SAFE** | List passes a typed `RequestOperationId`; detail loads `GET /appointment-requests/{requestId}` and renders current backend status/actions. | Reuse this detail as the recovered destination; do not pass the submission result DTO. |
| Scheduled-care booking creation | **PARTIAL** | A stable client `requestId`, `createOrReconcile`, owner GET, immutable intent checks, controller generations, and conflict refresh exist. Detail routes carry only request/appointment IDs and fetch authority. | Creation identity and intent are memory-only across process death; no secure receipt deterministically reconnects a lost create response. Add only if launch policy requires automatic unknown-outcome recovery. |
| Scheduled-care request decisions and appointment cancellation | **PARTIAL** | Stable resource IDs, expected versions, per-intent idempotency keys, read-after-ambiguous/conflict reconciliation, and safe server actions exist. | Mutation keys are memory-only. After restart a GET safely reveals current state, but the app cannot resume the exact pending command intent; explicit user re-action is required when it did not commit. |
| Legacy Patient appointment detail | **PARTIAL** | The route carries `appointmentId`, but `PatientAppointmentDetailScreen` reads only the already-loaded controller list via `byId`. | A cold/stale route cannot independently fetch. Prefer the modern scheduled-care stable-ID resolver for production destinations; do not persist the appointment DTO. |
| Urgent CABINET | **SAFE** | Secure account-scoped opaque key; receipt-first submission; recovery by key and subject-scoped active read; notification recovery by request ID; backend REST authority; generation/account fencing; logout cleanup. Post-auth recovery runs before navigation. | No concrete Phase 3 defect found. Preserve it unchanged and reuse the ownership/recovery ordering conceptually. |
| Notification navigation | **PARTIAL** | Durable inbox resolver validates exact UUID, role, type, and expiry; Patient scheduled-care and Urgent CABINET destinations re-fetch backend state; Doctor callbacks open ID-based controllers. | FCM/local-notification cold-open handling is special-cased to Urgent CABINET. Generic push opens fall back to an in-memory inbox action and can be lost before a navigator/session exists. |
| Medical-document upload | **SAFE in automated code; device evidence pending** | Secure schema-v1 account/Patient/key/time receipt; 24-hour contract horizon; eager post-auth owner recovery; backend recovery-by-key; generation fencing; no file content/path/metadata stored. | Keep document-specific multipart and `IN_PROGRESS` behavior isolated. Phase 2 physical kill/restart validation remains open. |
| Medical sharing and QR access | **SAFE for authorization / PARTIAL for command resumption** | Policies and consultation scope are server-read/versioned. QR is short-lived server authority; generation, expiry timer, logout clear, and retry key exist. No QR material is persisted. | QR/share mutation keys are memory-only. On process death, fail closed and re-read/reissue through server authority; never persist QR material merely to restore a screen. |
| Doctor scheduled-care and tasks | **SAFE for destination reads / PARTIAL for pending commands** | Request/appointment/task IDs open owner-authorized detail reads; controllers use generations, cancellation, expected versions, idempotency keys, and conflict refresh. | Process death loses in-memory mutation identity and open route. Current resource reads safely converge, but exact command resumption is not persisted. |
| Doctor consultation | **SAFE for active-consultation recovery / PARTIAL for legacy presentation routes** | Doctor bootstrap attaches the authenticated Doctor then calls the canonical active-consultation read. Start reconciles ambiguous failure via `getActive`; realtime only invalidates. | Some legacy consultation presentation still accepts in-memory maps/domain snapshots. Critical continuation should reconstruct from canonical active consultation/consultation ID and current medical-access authority. |
| Doctor workspace bootstrap | **SAFE** | Authenticated Doctor ID loads server bootstrap/capabilities and then attaches domain controllers; local workspace storage is explicitly debug-only and not production authority. | Preserve server bootstrap as the cold-start entry. Do not restore production role/capability from local config. |
| Clinic professional workspace | **SAFE for bootstrap; PARTIAL for task command recovery** | Secure clinic-ID hint is revalidated against `/me/clinics`; task routes carry a task ID and fetch it under selected clinic membership; controller refreshes lists/detail after commands. | Missing task args currently render an empty body rather than an explicit fail-closed state. Pending command keys/state are not durable, but authoritative task detail can reconcile after restart. |
| Urgent HOME | **DEFERRED** | Production routers fail closed and no HOME authority is active for this launch. | Its unchecked map routes are recorded only as regression evidence. Phase 3 must not implement or enable HOME. |

Across these workflows, death before a command leaves no server mutation; death after receipt save
must preserve the same operation identity; death during send or after commit requires an
authoritative read; death after response but before clear may safely rediscover the same resource;
death during navigation or while a screen is visible must reconstruct from stable identity. A Dart
`Future`, background task, route stack, or socket is never a recovery guarantee on Android or iOS.

### Persisted-state and receipt inventory

| Record | Storage/schema | Scope and identity | Time/retention | Sensitive content and lifecycle |
|---|---|---|---|---|
| Auth session | Secure storage, schema 1, legacy multi-key migration | User ID, role, optional session ID, access/refresh credentials | Token expiries are explicit | Credentials are required and redacted from `toString`; malformed/unsupported state clears; logout clears session but preserves installation ID. |
| Clinic in-flight request | Secure storage, schema 2, one global key | Request ID; clinic; SELF/family; situation; **no account scope** | No created time or TTL | Stores exact AMBULANCE GPS/address despite opaque-receipt target; best-effort write; invalid schema clears; logout clears but direct owner switch is incomplete. |
| Urgent CABINET | Secure storage, schema 1, one global key | Account scope and idempotency key only; subject/resource resolved by server | No local timestamp/TTL | No clinical/target/family/profile data; mismatch cannot consume another account; malformed/unsupported clears; logout invalidates owner receipt. |
| Medical-document upload | Secure storage, schema 1, one global key | Account, operational Patient ID, operation key | `createdAt`; 24-hour local/backend recovery horizon | No bytes/path/name/MIME/medical metadata/credential; malformed/unsupported clears; owner change/logout cancels and clears; terminal recovery clears. |
| Clinic selection hint | Secure storage, schema 1 | Clinic ID only; no account embedded | No TTL | Optional hint, always membership-revalidated; malformed/unsupported and logout clear. Not business authority. |
| Notification pending open | Memory only; no schema | One Urgent CABINET request UUID, not owner-scoped | No timestamp/TTL | Contains no clinical payload, but is lost on process death and is claimed by role-specific REST recovery. Generic destinations have no pending-open record. |
| Scheduled-care/consultation/clinic command identities | Memory only | Resource/version/action/idempotency identities in their controllers | Controller lifetime only | No persisted PHI, but exact command intent cannot resume after process death. Resource GETs still converge current state. |
| Doctor workspace local config | Secure storage, per-Doctor key; debug fixture only | Doctor ID and demo config | None | Not read by authenticated production shell and must remain non-authoritative. |

The secure receipt stores repeat useful mechanics—version field, strict parsing, delete-on-corruption,
account matching, and minimal JSON—but their business semantics differ. Phase 3B may align a small
storage/envelope utility or convention (`schemaVersion`, `accountScope`, `operationType`,
`operationKey`, optional opaque resource/subject reference, `createdAt`). It must not introduce a
generic business state machine, mass-refactor the working Urgent CABINET/document controllers, or
force one TTL/terminal policy across different backend contracts.

Schema migration must be workflow-specific. A supported old record may be transformed without
changing its operation identity. An unsupported record must fail closed and must never silently
create a replacement write. For the current clinic schema, Phase 3B needs an explicit migration or
safe quarantine decision because deletion can lose an unresolved server commit; simply retaining
the present GPS-bearing schema is not acceptable.

### F-11 route and external-entry findings

| Pattern | Classification | Evidence and rule |
|---|---|---|
| Root `/emergency-step2`, `/emergency-step3`, `/emergency-review` and the duplicate Patient nested navigator | **UNSAFE but DEFERRED** | `settings.arguments as Map<String, dynamic>` is unchecked and the entire HOME intake exists only in memory. Malformed/stale entry can throw. Urgent HOME remains fail-closed and Phase 3B must not activate or redesign it. |
| Nested `/m05/doctor-detail` | **PARTIAL** | Unchecked `as String`; the value is a stable Doctor ID, but malformed/missing arguments can throw before the destination fetches authority. Validate shape and fail closed. |
| Clinic task detail | **PARTIAL, close to SAFE** | Caller passes only `taskId`; destination checks `args is String`, uses the currently validated clinic, and fetches detail. Missing/empty args silently render empty content; add an explicit unavailable/not-found boundary. |
| Clinic request detail/history | **SAFE** | Typed stable request ID; destination calls the owner-authorized detail repository and handles not-found/failure. |
| Patient/Doctor scheduled-care detail | **SAFE** | Stable request/appointment ID only; destination controller fetches current authorized resource and rejects identity mismatch. |
| Legacy Patient appointment detail | **PARTIAL** | Stable ID is carried, but the destination trusts a loaded controller snapshot and has no independent by-ID read. |
| Doctor active consultation/medical record | **SAFE at canonical bootstrap; PARTIAL at legacy route composition** | Active consultation and access are server-reconciled, but some presentation constructors still accept maps or domain snapshots. Critical re-entry must use the canonical active read/consultation ID. |
| Inbox notifications | **SAFE as hints** | Resolver accepts only known type/role and exact UUID; destinations re-read authority. Expired non-CABINET notifications fail closed; CABINET expiry still performs a safe authority lookup. |
| FCM/local-notification cold entry | **PARTIAL** | `getInitialMessage()` exists, but only `destination=URGENT_CABINET_REQUEST` is retained and recovered. Other types are not passed through the typed resolver during cold open. The pending urgent intent is memory-only. |
| Phone-change external route | **SAFE boundary** | Route carries only a token string parsed from the URI; backend security action remains authoritative. No production app/universal-link clinical route framework was found. |
| Family/profile and cosmetic page routes | **NONCRITICAL for Phase 3** | Some direct `MaterialPageRoute` calls pass view objects/providers, but no server write outcome depends on restoring those cosmetic stacks. They should not expand Phase 3 into generic Navigator restoration. |

The Phase 3 stable-entry rule is:

```text
route / notification / QR open
  -> validate a small opaque identifier and expected resource kind
  -> wait for authenticated account/role and, where applicable, subject/clinic membership
  -> repository performs owner-authorized backend read
  -> controller generation rejects stale owner/route callbacks
  -> UI renders the current server projection or a safe unavailable/not-found state
```

Critical routes must never require a DTO, Doctor/Patient profile, clinical record, GPS, QR payload,
controller instance, or localized notification copy to reconstruct business truth. State restoration
for tabs, scroll, sheets, and cosmetic stacks is outside this phase.

### Session ordering, notification entry, and isolation

The required cold-start ordering is: restore secure session; refresh/validate it; establish the
current account and role; load the minimum Patient/Doctor/clinic subject authority; read only that
owner's operation receipts; reconcile through REST; then offer or perform the server-derived route.
Independent recovery jobs should be bounded and generation-fenced so one temporarily unavailable
workflow does not block the entire authenticated shell indefinitely.

Account A's receipt, operation key, result, or late callback must never become visible or usable by
Account B. Urgent CABINET and documents already enforce this. The clinic store does not. Logout
clears the clinic controller, but direct authenticated account replacement omits it; this is a
concrete Phase 3B isolation fix. Family-member changes inside one account must compare opaque subject
identity and require current server ownership before replay. A family mismatch must fail closed; it
must not rotate the operation ID or silently resubmit for SELF.

Notification payloads remain navigation hints. Durable inbox opens already satisfy UUID/role checks
and authoritative reads. Phase 3B should route FCM/local-notification foreground, background, and
cold-start opens through the same typed resolver after session ownership is known, retain at most a
minimal pending destination identity until it can be claimed, and discard it on logout/owner
change/invalid shape. It must not persist notification title/body or use payload state as authority.

### Backend dependencies and Phase 3B sequence

No blocking backend or product decision was found for F-05/F-11. Clinic submission has exact replay
and owner-authorized GET; scheduled care, Doctor consultation, clinic tasks, Urgent CABINET,
documents, and notification destinations expose stable resource reads sufficient to converge the
current state. Phase 3B must use those contracts before proposing any new endpoint. A future request
to automatically resume a write whose intent is not observable from its current resource may need a
narrow recovery read or product decision, but that is not required to begin the scoped Phase 3 work.

The smallest implementation sequence is:

1. **3B-1 — Clinic receipt safety and reconciliation:** add authenticated account/time scope; remove GPS/address from the durable receipt; make receipt persistence failure fail safely before dispatch; restore only after authenticated owner/subject validation; GET by `requestId` before any replay; preserve the same ID; prevent `beginNewRequest()` and unrelated Doctor entry from deleting unresolved work; fence direct account changes and logout.
2. **3B-2 — Minimal recovery orchestration:** place bounded post-auth recovery ordering outside route widgets, expose explicit interrupted/reconciling/created/not-found/unauthorized outcomes, and reuse only a small receipt-envelope convention where it materially reduces duplicated parsing. Do not generalize domain state machines.
3. **3B-3 — Critical stable-ID routes:** validate the non-deferred unsafe argument sites, make clinic task missing/stale IDs explicit, converge legacy appointment/consultation entries on existing authoritative reads, and preserve the Urgent HOME fail-closed boundary.
4. **3B-4 — Notification cold entry:** pass supported push/local opens through the existing resolver after owner validation, retain only opaque pending identity, re-fetch before navigation, and fence logout/account changes.
5. **3B-5 — Integration and device evidence:** add deterministic process-death/account/family/route tests, then combine physical Phase 3 kill/relaunch boundaries with the still-open Phase 2 Android/iOS network/upload matrix.

### Required Phase 3B tests and current evidence

Required tests are: clinic receipt-before-dispatch failure; commit-before-response; no-commit failure;
GET-first restart; exact same-key replay only after authoritative not-found; no duplicate write;
success-before-clear; explicit abandonment; new-flow refusal while unresolved; account mismatch/direct
switch/logout; SELF/family ownership change; expired/malformed/old-schema receipt; upgrade without
silent new write; delayed callback after owner change; malformed/missing/wrong-type route arguments;
deleted/not-owned resource; stale notification; generic FCM initial-message, background-open, and
foreground-open through the typed resolver; navigator-not-ready pending intent; Doctor active
consultation restart; scheduled-care/clinic task stable-ID reconstruction; and Urgent HOME boundary
regression. Device validation must kill Android/iOS before dispatch, during send, after commit before
response, after response before clear, during navigation, and on a visible destination; it must also
cover background/termination, account switch, and combined network-handoff/upload/request cases.

Existing tests cover the clinic store's schema/round-trip/corruption rules, same-ID retry, terminal
clear, and isolated `restoreInFlightOperation()` without auto-send. They do not cover production
startup wiring, account ownership, TTL/migration over an unresolved record, receipt-write failure,
GET-first reconciliation, route-entry preservation, or process kill. Notification tests cover
strict UUID/type/role/expiry mapping, session clearing, late-event fencing, and inbox behavior, but
not generic Firebase cold start or navigator-not-ready/account-mismatch open. Urgent CABINET and
medical-document suites provide the strongest account/restart examples.

Focused validation performed for this investigation:

- Combined auth/session, Phase 2 network boundary/classification, document API/recovery, clinic request core, Urgent CABINET submission/lifecycle/recovery, notifications, Patient/Doctor scheduled care, clinic bootstrap, and Phase 1 boundary suite: **409 passed, 7 intentionally skipped, 0 failed**.
- Standalone `test/phase1_clinical_correctness_boundary_test.dart`: **6 passed, 0 failed**.
- No full suite, analyzer, device test, backend test, or runtime process-kill claim was required or made by Phase 3A. The retained Phase 2 full-suite and physical-validation status is unchanged.

### Decision

**READY_FOR_PHASE_3B.** F-05 is a proven client lifecycle/receipt defect with sufficient backend
authority, and F-11 can be addressed incrementally with the existing stable-ID repositories and
route boundaries. Phase 3 remains not complete. This investigation does not begin Phase 3B.

## Phase 3B — Lifecycle & Recovery Implementation

**Implementation date:** 2026-11-09  
**Status:** **AUTOMATED_CODE_COMPLETE_DEVICE_VALIDATION_PENDING**

Phase 3B implements the client-owned F-05 and F-11 boundaries without changing a backend contract,
enabling Urgent HOME, redesigning the approved UI/UX, replacing Provider/ChangeNotifier or the
navigation framework, introducing generic offline authority, upgrading a dependency, or performing
a Git write operation.

### Automated code correctness

#### Clinic receipt and F-05 recovery

The clinic in-flight receipt is now secure schema v3 and contains only the authenticated account
scope, stable request ID, clinic ID, opaque SELF/family subject reference, minimal dispatch state,
creation time, and an owner-validation marker used for safe legacy quarantine. It does not contain
GPS coordinates, postal address, ambulance pickup JSON, situation narrative, a submission DTO,
profile data, or clinical content.

Receipt persistence is mandatory. The controller durably stores the prepared identity and then the
dispatch-attempt marker before sending the POST. Either storage failure blocks dispatch and returns
a recoverable local persistence failure. Once dispatch may have occurred, the same request ID remains
authoritative until reconciliation completes.

After authentication and owner attachment, recovery performs the owner-authorized
`GET /api/v1/appointment-requests/{requestId}` before any write. An existing request opens the
stable-ID detail from the current server projection. Temporary transport/server failure retains the
receipt. Unauthorized, forbidden, and owner mismatch fail closed. Authoritative not-found clears the
unresolved server identity; same-ID replay is permitted only in the same process when the exact
non-sensitive intent is still available. A cold restart never reconstructs a clinical payload and
never silently creates a replacement request ID.

`beginNewRequest()` now refuses to overwrite unresolved durable work. A new operation requires an
authoritatively resolved receipt or an explicit abandon action. Opening the Patient flow is not
abandonment. `DoctorCabinetEntryScreen` no longer touches the Patient clinic submission controller,
so unrelated Doctor entry cannot clear Patient recovery state.

Schema-v2 records are migrated by extracting only the stable opaque identifiers, discarding the old
pickup/situation payload, and writing a schema-v3 quarantine record for GET-first recovery after the
authenticated owner is known. If safe migration persistence fails, the legacy record is retained and
not consumed. Malformed or unsupported records fail closed and never trigger a new submission. The
new `createdAt` field is recorded, but no invented TTL deletes a still-authoritative unresolved ID.

Account replacement and logout cancel/fence controller work and prevent late callbacks. A record for
another account is neither consumed, queried, nor exposed. FAMILY_MEMBER recovery retains only the
opaque family ID; the backend-owned request read revalidates current ownership, and no fallback to
SELF or another family member is allowed.

#### Post-auth orchestration

Post-auth navigation attaches the authenticated owner and starts clinic recovery outside route
widgets. It remains domain-specific and independent of the existing Urgent CABINET and document
recovery implementations, so temporary clinic unavailability does not block the authenticated shell
or redefine another domain's outcome. A recovered clinic request navigates only by stable request ID
after the authoritative read. Owner changes generation-fence pending work.

#### F-11 routes and notification entry

- `/m05/doctor-detail` now accepts only a non-empty String Doctor ID. Malformed input renders a safe
  unavailable boundary; valid input continues through the existing authoritative Doctor fetch.
- Clinic task detail now rejects missing, wrong-type, or empty task IDs with an explicit safe boundary.
  A valid ID still uses the currently validated clinic context and owner-authorized task read.
- The production Patient appointment path already falls back to the modern scheduled-care stable-ID
  resolver when no legacy injected controller exists, so the demo/injected legacy presentation was
  not broadened or persisted.
- Canonical Doctor bootstrap already restores the active consultation through the authoritative
  active-consultation read. No production-reachable legacy snapshot route justified a change.
- Deferred Urgent HOME map routes remain intercepted by the fail-closed production boundary and were
  intentionally not repaired, restored, or activated.

Firebase initial messages, background taps, local-notification launches, and foreground/inbox opens
now converge on the existing typed `NotificationNavigationResolver` after authentication. If auth or
the navigator is not ready, only an in-memory opaque pending identity is retained: destination type,
resource UUID, optional known account scope, and receipt time. Notification title/body, clinical
content, names, and claimed business state are not retained. Role/account/type/UUID validation occurs
before resolution; destinations then perform their existing authoritative reads. Malformed, stale,
wrong-role, wrong-account, deleted, or revoked destinations fail closed. Logout/account replacement
clears pending identity and fences late resolution.

### Material implementation and tests

Primary production changes are in the clinic in-flight store/controller/failure model, post-auth
navigation, Patient/Doctor clinic entry screens, root account-transition wiring, Doctor shell,
notification service/coordinator/resolver, Patient Doctor-detail routing, and clinic task detail.
The focused regression boundary is `test/phase3_lifecycle_recovery_boundary_test.dart`; clinic
recovery/migration cases were added to `test/request_core_test.dart`, and notification ownership and
pending-entry cases were added to `test/notification_center_test.dart`.

Validation record:

- Focused Phase 3B clinic, migration, notification, route, clinic/Doctor entry, and Urgent HOME
  boundary gate: **159 passed, 0 failed**.
- Relevant Phase 2 auth/network/document recovery plus Phase 1/review regression gate:
  **172 passed, 7 intentionally skipped, 0 failed**.
- Full bounded Flutter suite: **1,703 passed, 7 intentionally skipped, 0 failed in 1 minute 40 seconds**.
- Analyzer: **388 findings = 0 errors, 31 baseline warnings, 357 infos**. No analyzer error or warning
  was introduced by Phase 3B.
- Standalone `test/phase1_clinical_correctness_boundary_test.dart`: **6 passed, 0 failed**.
- `git diff --check`: **passed**.

No backend dependency blocks the automated implementation. The existing exact-replay command and
owner-authorized request GET are sufficient. No backend, MRS, dependency, or Urgent HOME source was
changed.

### Physical Android/iOS evidence

Phase 3 remains active because source/widget tests do not certify OS process behavior. Android and
iOS validation must still cover termination before dispatch, after the durable prepared marker,
during send, after backend commit before response, after response before receipt clear, during
navigation, and while request detail is visible. It must also cover background/suspension, relaunch,
offline/reconnect and Wi-Fi/mobile handoff, account switch, family ownership change, notification
cold launch, and the still-open Phase 2 document-upload recovery matrix. No guaranteed background
execution claim is made.

### Exit decision

**AUTOMATED_CODE_COMPLETE_DEVICE_VALIDATION_PENDING.** F-05 and the scoped production-reachable F-11
boundaries are complete from automated evidence. Phase 3 is not globally complete until the physical
Android/iOS matrix passes. After review, Phase 4 investigation may be considered while Phase 2/3
device validation remains a mandatory release gate; Phase 4 is not started by this decision.

## 9. Phase 4 — Release Engineering

**Status: NOT STARTED**

### Objective

Create deterministic, signed, correctly configured Android/iOS artifacts with mandatory automated gates.

### Audit findings covered

F-03, F-04, F-06, F-08, plus the gate-relevant portion of F-16.

### Dependencies

Phases 1-3 behavior stabilized; protected signing/Firebase/APNs inputs; CI runner ownership; staging environment.

### Work items

Configure protected Android signing and Play ownership, iOS signing/provisioning/entitlements, Firebase project injection, APNs capability, environment separation/allowlists, versioning/artifact provenance, deterministic test timeouts, and mobile CI stages.

### Architecture/pattern changes

Build/release configuration only. No product architecture rewrite.

### Explicitly out of scope

Dependency modernization, UI redesign, suppressing valid tests/analyzer warnings, or weakening assertions to make gates green.

### Acceptance criteria

Clean runners produce signed staging artifacts using Flutter 3.41.2 and locked dependencies. Required configuration is validated. Analysis/tests terminate and pass. Certificate, endpoint, version, Firebase/APNs capability, and provenance are inspectable.

### Required tests

All unit/widget tests, bounded integration suite, Android/iOS release builds, certificate/profile/entitlement inspection, configuration-negative tests, and push smoke tests.

### Runtime/device validation

Install signed artifacts on physical Android/iOS; verify foreground/background/terminated push, token lifecycle, update continuity, and staging endpoint identity.

### Rollback considerations

Retain previous signed artifact and signing continuity. Configuration failure blocks promotion; never fall back to debug signing or an unknown endpoint.

### Exit decision

Exit only when the complete mandatory release gate passes from a clean runner.

## 10. Phase 5 — Architecture Convergence

**Status: NOT STARTED**

### Objective

Standardize responsibilities in touched/high-risk areas without a mass rewrite.

### Audit findings covered

F-14 and architecture contributors identified while resolving F-01/F-05/F-11; no finding is downgraded because a layer exists.

### Dependencies

Green deterministic gate from Phase 4 and observed change hotspots.

### Work items

Keep views focused on rendering/actions, make controllers own explicit UI lifecycle, use repositories as domain sources of truth, isolate external mechanisms in services, introduce use cases only for complex/reused recovery workflows, stabilize disposable ownership, and separate DTO/domain models only where contract fragility justifies it.

### Architecture/pattern changes

Incremental View -> Controller -> optional UseCase -> Repository -> Service convergence; immutable models/explicit states where useful.

### Explicitly out of scope

Provider/ChangeNotifier migration, folder reorganization, class renaming for style, Clean Architecture ceremony, or refactoring untouched stable features.

### Acceptance criteria

Touched critical features have documented authority/ownership, stable disposal, test seams, and no widget-owned transport/clinical rule.

### Required tests

Controller/repository/service unit tests and unchanged-behavior widget/integration tests for each touched feature.

### Runtime/device validation

Targeted regression journeys only where resource/plugin ownership changes.

### Rollback considerations

Small reviewable changes behind existing interfaces; avoid cross-feature flag days.

### Exit decision

Exit when priority hotspots conform without broad churn or behavior regression.

## 11. Phase 6 — State Integrity

**Status: NOT STARTED**

### Objective

Eliminate duplicated, contradictory, or stale projections of backend-owned state.

### Audit findings covered

State/source-of-truth risks from F-01, F-05, and F-11 after their correctness fixes; remaining duplicated caches/providers discovered by evidence.

### Dependencies

Architecture responsibility boundaries and recovery model established.

### Work items

Map domain authority, consolidate duplicate projections, define invalidation/revalidation, cancel stale owner/family/account work, use explicit states for complex workflows, and mirror backend lifecycle values.

### Architecture/pattern changes

Repository/controller convergence; no new state library.

### Explicitly out of scope

Generic global store, offline clinical authority, cache technology, and unrelated view refactors.

### Acceptance criteria

Each critical domain has one documented authority; account/family changes cannot display prior-owner data; mutations reconcile all projections.

### Required tests

Stale response, concurrent refresh/mutation, family/account switch, realtime+REST ordering, duplicate event, and optimistic rollback tests.

### Runtime/device validation

Long sessions with repeated switching, reconnects, backgrounding, and concurrent updates.

### Rollback considerations

Maintain server refresh escape hatches and avoid irreversible local state migration.

### Exit decision

Exit when critical UI state deterministically converges to authorized backend truth.

## 12. Phase 7 — Realtime Hardening

**Status: NOT STARTED**

### Objective

Make realtime efficient and observable through outages without changing its non-authoritative role.

### Audit findings covered

F-10.

### Dependencies

Stable state authority, network classification, lifecycle hooks, and observability design.

### Work items

Add bounded exponential reconnect, jitter, lifecycle/connectivity awareness, credential-change fencing, duplicate/order handling, and PHI-safe metrics; preserve foreground/reconnect REST reconciliation.

### Architecture/pattern changes

Enhance the single owned `AuthenticatedRealtimeTransport`; do not create per-screen sockets.

### Explicitly out of scope

Treating sockets as clinical truth, guaranteed background execution, or replacing STOMP without evidence.

### Acceptance criteria

Outages do not cause fixed-rate storms; resume/reconnect converges once; duplicate/stale sockets cannot mutate current state; metrics expose health without PHI.

### Required tests

Backoff/jitter bounds, lifecycle pause/resume, token/account change, duplicate event, reconnect epoch, auth rejection, and reconciliation tests.

### Runtime/device validation

Long outage, Wi-Fi/mobile handoff, background suspension, OEM restrictions, battery/network measurement, and broker recovery.

### Rollback considerations

Keep reconciliation independent from backoff algorithm; ability to disable faulty realtime while retaining manual/foreground REST refresh.

### Exit decision

Exit with convergence and endurance evidence, not connection-success alone.

## 13. Phase 8 — Selective Cache

**Status: NOT STARTED**

### Objective

Introduce or constrain caching only after data classification, with healthcare privacy and account isolation.

### Audit findings covered

F-13 and the temp/cache portion of F-15.

### Dependencies

State authority complete; privacy/security retention decisions; measured offline/product needs.

### Work items

Approve data categories, TTL/version/invalidation/account keys, logout purge, shared-device behavior, image cache policy, temp-file lifecycle, and migration/upgrade handling; evaluate technology only afterward.

### Architecture/pattern changes

Repositories coordinate approved cache services; UI never trusts cache for clinical lifecycle decisions.

### Explicitly out of scope

Generic Medical Passport/diagnosis/document caching, choosing Drift/Hive/Isar/SQLite before policy, or claiming full offline clinical operation.

### Acceptance criteria

Every cached datum has owner, purpose, sensitivity, TTL/version, invalidation, logout behavior, and authority documented/tested.

### Required tests

Account switch/logout purge, TTL/revalidation, schema migration, corrupted entry, stale server state, shared-device, and storage pressure tests.

### Runtime/device validation

Offline/refresh UX, OS cache eviction, upgrade, backup/restore, low storage, and cross-account artifact inspection.

### Rollback considerations

Cache removal must not lose authoritative data; schema migration supports safe invalidation.

### Exit decision

Exit only with approved data policy and no cache-derived clinical authority.

## 14. Phase 9 — Observability

**Status: NOT STARTED**

### Objective

Diagnose production crashes, errors, network/push/realtime health, and performance without exposing PHI, credentials, or location.

### Audit findings covered

F-07.

### Dependencies

Privacy review, environment/release identity, operational ownership, retention/access controls.

### Work items

Capture Flutter/platform/zone errors, release/version/device context, API failure categories, auth-refresh outcomes, push registration/init health, realtime reconnects, and approved performance signals; define redaction and prohibited fields.

### Architecture/pattern changes

Central typed telemetry boundary; no ad hoc medical payload logging.

### Explicitly out of scope

Notification bodies, patient identity, medical content, raw location, tokens, request bodies, or vendor adoption without privacy review.

### Acceptance criteria

Injected incidents appear with actionable non-PHI context; prohibited data tests pass; access/retention/runbooks exist.

### Required tests

Error capture, redaction, sampling, offline queue limits, release disable/config, and representative failure-category tests.

### Runtime/device validation

Staging crashes, push init failure, timeout, refresh outage, reconnect storm, and performance trace on Android/iOS.

### Rollback considerations

Remote disable/kill switch and bounded local buffering; removing telemetry must not affect clinical behavior.

### Exit decision

Exit after privacy/security/operations approval and staging incident reconstruction.

## 15. Phase 10 — Integration Test Harness

**Status: NOT STARTED**

### Objective

Build deterministic backend-connected and device-capable tests for critical journeys.

### Audit findings covered

Test-depth gaps associated with F-01 through F-12 and F-17; F-06 gate stability must already be resolved.

### Dependencies

Stable staging contracts, seeded isolated accounts, signed/configured builds, device automation infrastructure.

### Work items

Implement the twelve critical journeys, deterministic fixtures through backend APIs, fault injection, process-kill/relaunch support, artifact/log redaction, and quarantine policy that cannot silently bypass mandatory journeys.

### Architecture/pattern changes

Test seams at repository/service/external-platform boundaries; no production-only bypasses.

### Explicitly out of scope

Replacing unit/widget tests, brittle pixel scripting for all screens, or synthetic clinical success in production code.

### Acceptance criteria

Mandatory critical journeys run repeatably on Android/iOS staging artifacts and produce diagnosable, redacted failures.

### Required tests

The harness is the required test set: login/restore, logout, family switch, appointment, clinic, urgent HOME/CABINET, process death, notification launch, QR, doctor consultation, document upload.

### Runtime/device validation

At least one physical Android and iOS lane plus emulator/simulator breadth; poor-network and lifecycle cases included.

### Rollback considerations

Harness changes cannot change production behavior; retain prior known-good staging datasets and runner images.

### Exit decision

Exit when mandatory journeys are deterministic enough to block release.

## 16. Phase 11 — Performance

**Status: NOT STARTED**

### Objective

Measure and remediate user-visible performance/resource problems with profile-mode physical-device evidence.

### Audit findings covered

Performance/memory risks including F-14/F-17 after correctness fixes; no severity is inferred from file size alone.

### Dependencies

Stable integration harness, observability, representative devices, agreed budgets.

### Work items

Measure cold/warm startup, screen latency, frame timing, memory, CPU, network, battery, app size, image decode, maps/scanner, long sessions, reconnects, and uploads; optimize only evidenced bottlenecks.

### Architecture/pattern changes

Targeted rebuild/resource/data-path improvements only when measurement identifies cause.

### Explicitly out of scope

Debug-mode performance claims, animation redesign, speculative broad refactors, or arbitrary benchmark numbers.

### Acceptance criteria

Budgets and repeatable profile benchmarks exist; critical journeys meet approved thresholds on the slowest supported class with no memory growth regression.

### Required tests

Profile integration benchmarks, frame/memory regression checks, large-file/image tests, and endurance scenarios.

### Runtime/device validation

Low-, mid-, and high-tier physical devices under constrained network, thermal, and long-session conditions.

### Rollback considerations

Each optimization retains behavioral tests and before/after traces; revert regressions independently.

### Exit decision

Exit from measured evidence and approved budgets, never subjective smoothness alone.

## 17. Phase 12 — Device Certification

**Status: NOT STARTED**

### Objective

Validate supported Android/iOS populations, native integrations, lifecycle, upgrades, and OEM restrictions.

### Audit findings covered

Runtime unknowns from Android/iOS, notifications, storage, biometric, GPS, camera/QR, maps, files, backgrounding, and process death.

### Dependencies

Signed staging artifacts, integration harness, observability, device matrix and support policy.

### Work items

Certify representative API/OS/RAM/OEM/screen classes; secure storage/biometrics; permissions; push; camera/QR; GPS/maps; file picker; background restrictions; process death; upgrades; app links if later supported.

### Architecture/pattern changes

Only evidence-driven plugin/native boundary hardening.

### Explicitly out of scope

Claiming every device model, procurement decisions, or unsupported background guarantees.

### Acceptance criteria

Approved matrix, results, known limitations, support floor, defect thresholds, and re-certification triggers exist.

### Required tests

Critical journey/device matrix, permission state matrix, upgrade/reinstall, biometric changes, OEM background/push, and storage-pressure tests.

### Runtime/device validation

This phase is entirely runtime/device validation, including API 24 low RAM, Android 13+ permission behavior, current Android, Samsung/aggressive-background OEM, iOS 14/current, small/large iPhone, and tablet where supported.

### Rollback considerations

Unsupported combinations are blocked/documented before release; retain last certified artifact.

### Exit decision

Exit only when the support policy is backed by representative physical-device evidence.

## 18. Phase 13 — Localization/Accessibility

**Status: NOT STARTED**

### Objective

Make claimed English/French/Arabic experiences and assistive-technology use reliable without redesigning approved UX.

### Audit findings covered

F-12.

### Dependencies

Stable UI flows, approved translations, device matrix, accessibility ownership.

### Work items

Complete localized strings/errors/plurals/dates/numbers, RTL, large text/reflow, semantics, labels, focus order, touch targets, validation announcements, contrast verification, and keyboard/switch support.

### Architecture/pattern changes

Central localization/semantic contracts; no visual redesign unless an approved robustness correction is necessary.

### Explicitly out of scope

Copy/product changes without approval, unsupported-language claims, or certification from source inspection alone.

### Acceptance criteria

All critical journeys work in en/fr/ar and RTL at approved text scales with no blocked action; automated and manual accessibility criteria pass.

### Required tests

Locale widget/integration matrix, RTL/golden where stable, semantics tests, text scale/reflow, keyboard/focus, and error announcement tests.

### Runtime/device validation

TalkBack, Accessibility Scanner, VoiceOver, iOS accessibility settings, display scaling, keyboard/switch, notches, tablets, and representative contrast review.

### Rollback considerations

Translation bundles and semantic changes remain independently releasable; never remove an existing accessible label to resolve layout.

### Exit decision

Exit only with manual assistive-technology sign-off for critical journeys.

## 19. Phase 14 — Controlled dependency modernization

**Status: NOT STARTED**

### Objective

Reduce analyzer/config/temp-file debt and modernize dependencies only after the runtime foundation and gates are stable.

### Audit findings covered

F-15 and F-16; dependency-outdated/discontinued-package evidence from the audit.

### Dependencies

Green release gate, integration harness, device certification coverage, rollback-capable release process.

### Work items

Classify and resolve analyzer warnings/high-risk infos, remove secret assumptions from bundled config, bound temp-file cleanup, review discontinued/old critical packages, modernize one bounded dependency group at a time, and record native migration implications.

### Architecture/pattern changes

None by default; package API adaptations remain minimal and behavior-preserving.

### Explicitly out of scope

Bulk `flutter pub upgrade`, simultaneous plugin migration, state-management replacement, formatter churn, or dependency changes without native/device tests.

### Acceptance criteria

Analyzer has an agreed clean enforced baseline; config policy is explicit; temp retention is bounded; each dependency change has purpose, changelog/native review, tests, and rollback.

### Required tests

Full gate plus package-specific Android/iOS integration, permissions, persistence migration, and upgrade tests.

### Runtime/device validation

Required for secure storage, Firebase/notifications, maps/location, camera/QR, pickers, WebSocket, local auth, and any native plugin changed.

### Rollback considerations

One bounded dependency change per reviewable unit; retain lockfile/artifact and documented downgrade constraints.

### Exit decision

Exit when modernization is evidence-driven and the full certified matrix remains green.

## 20. Phase 15 — Staged production rollout

**Status: NOT STARTED**

### Objective

Release gradually with PHI-safe health signals, explicit thresholds, rapid rollback, and clinical-operations ownership.

### Audit findings covered

Closure evidence for all F-01 through F-17 and all runtime unknowns required by the support/release policy.

### Dependencies

All prior mandatory phase exit decisions, store approvals, production backend readiness, support/on-call/runbooks, dashboards, and rollback artifact.

### Work items

Internal rollout -> 5% -> 25% -> 50% -> 100%; define cohort duration, crash-free/error/auth/push/realtime/clinical workflow thresholds, support feedback, incident ownership, and halt/rollback rules.

### Architecture/pattern changes

None; rollout is an operational validation of the hardened system.

### Explicitly out of scope

Skipping cohorts for schedule pressure, using patient PHI as telemetry, silent hotfixes outside the gate, or accepting synthetic/manual-only validation.

### Acceptance criteria

Every cohort meets pre-approved thresholds for the full observation window; no unresolved P0/P1; rollback is rehearsed; support/clinical owners approve progression.

### Required tests

Final release gate, store artifact verification, production smoke, update from prior version, rollback drill, and post-deploy synthetic/non-PHI health checks.

### Runtime/device validation

Real-world cohort monitoring segmented by app/OS/device/network without exposing PHI; verify push, auth, clinical write completion/reconciliation, and crash/error health.

### Rollback considerations

Automatic halt and operator rollback thresholds are defined before 5%; retain signed prior version and backend compatibility window.

### Exit decision

Advance 5% -> 25% -> 50% -> 100% only through explicit recorded decisions. Production-ready status is granted only after the 100% observation window passes.

## Phase 0 command baseline

| Command | 2026-11-08 result |
|---|---|
| `git status --short --branch` | `deployrailway...origin/deployrailway`; audit report untracked before Phase 0 edits |
| `git log -1 --oneline` | `ff88c76 feat(deploy): add Railway Flutter web deployment` |
| `flutter --version` | Flutter 3.41.2 stable; Dart 3.11.0; DevTools 2.54.1 |
| `dart --version` | Dart 3.11.0 stable on macOS arm64 |
| `flutter doctor -v` | Completed; Android license status unknown; iOS 27.2 simulator absent; macOS and Chrome only, no Android/iOS device |
| `flutter analyze --no-pub` | 389 findings: 0 errors, 31 warnings, 358 infos; baseline intentionally unchanged |

Known test baseline from the audit, not rerun indefinitely in Phase 0:

- Full `flutter test --reporter compact` reached `+1580 ~7 -13` at 6:07 and hung in `review_screen_test.dart`.
- `documents_api_test.dart`: 1 pass, 1 failure.
- `patient_request_status_matrix_test.dart`: 7 passes, 4 failures.
- Android release AAB attempt did not complete after 460.1 seconds; no artifact.
- No iOS signed build, integration/device suite, coverage, performance, notification, process-death, accessibility, or upgrade validation exists yet.

Phase 0 does not change these results and does not authorize Phase 1 implementation until its exit decision is approved.

## Phase 1 Backend Contract Certification

**Certification date:** 2026-11-09  
**Scope:** backend investigation and production-contract design only  
**Implementation status at certification time:** **NOT IMPLEMENTED**  
**Historical decision:** **CTO_DECISIONS_APPROVED — READY_FOR_BACKEND_IMPLEMENTATION**  
**Current disposition:** **B1 COMPLETE / DORMANT; B2-B8 AND FLUTTER PHASE 1B DEFERRED**

This section defines the one recommended production boundary that must exist before Flutter Phase 1B may begin. It does not authorize activation of the existing synthetic HOME endpoints, change the fail-closed Flutter mitigation, or certify runtime behavior that has not been implemented and tested.

### Evidence and governing documents

The certification traced the current backend controllers, services, repositories/stores, domain objects, migrations, workers, configuration, security tests, PostgreSQL integration tests, notification/realtime scaffolding, protected-data boundary, and consultation adapters. It also reconciled:

- Module 04 — Doctor Request Flow / Urgent Home Visit;
- Module 04 Amendment v1.1;
- ADR-002 through ADR-007;
- the current actor/subject identity contract;
- `P4-02D — Retention, Media and MRS Handoff Contract` v1.1; and
- the Flutter Phase 1A investigation and fail-closed mitigation.

Standalone Module 01 and Module 02 source documents were not present in the workspace. This certification therefore uses the current identity/subject contract and current P4-to-P5/MRS handoff contract for those boundaries and does not invent missing rules.

### Current backend reality

The backend is not production-capable for urgent HOME. It contains a coherent development generation and reusable concurrency foundations, but production profiles deliberately disable the flow.

| Area | Current code reality | Certification |
|---|---|---|
| Patient intake | `POST /api/v1/me/urgent-home/journeys`, status read, and recovery read exist. `HomeIntakeAccessPolicy` requires development runtime access, `SYNTHETIC_DEVELOPMENT`, an isolated database, explicit latches, and an account allowlist. Production fixes all of these to disabled. | Not production-capable. |
| Intake persistence | Migration 0523 stores synthetic triage and exact destination in plaintext development tables. Migration 0524 provides production-inert encrypted clinical and destination envelope foundations with independent wrapping and protected-operation audit, but no production HOME submission writer uses them. | Encrypted foundation reusable; production writer and policy missing. |
| Identity | `CareSubjectResolver` accepts only SELF or an owned `family_members.id` and resolves operational/MRS identity server-side. | Reuse unchanged; clients must never submit patient or MRS IDs. |
| Matching | First wave creation, expanding radii, retry/recovery states, leases, revision fences, and PostgreSQL `FOR UPDATE SKIP LOCKED` claiming exist. `HomeMatchingWaveWorker` and recovery worker are explicitly invoked, unscheduled, and development-gated. | Core mechanics reusable; production trigger, health, and access policy missing. |
| Doctor offers | List/detail/accept/decline/withdraw, hold expiry/recovery, eligibility recheck, capacity fences, stable command receipts, and strict ownership exist. | Reuse and remove only the development gate after production certification. |
| Patient selection | Accepted-Doctor read and revision-fenced idempotent selection exist. The transaction closes competing offers, promotes capacity, creates a commitment, and advances the attempt. | Reuse with additive DTO/capability changes. |
| Commitment | `ACTIVE`, `CANCELLED`, and `INVALIDATED` exist; Doctor active/detail and purpose-scoped exact-destination reads exist. There are no patient/Doctor commitment cancellation commands and no travel/arrival lifecycle. | Extend; current state is insufficient. |
| Travel/arrival | No authoritative start-travel, location relay, ETA, arrival, check-in, or HOME QR implementation exists. | New production boundary required; legacy Flutter travel screens remain disabled. |
| Realtime | Durable intent/history, lease/retry/dead-letter mechanics, and opaque `HOME_STATE_CHANGED` hints exist. The publisher is fake/no-I/O, the worker is unscheduled and development-only, and production rejects WebSocket publication. | Delivery mechanics reusable; real adapter/scheduler/health missing. |
| Push | Durable jobs, actionability recheck, generic templates, retry/backoff, and dead letters exist. Transport is dry-run only; production rejects external FCM. | Delivery mechanics reusable; real FCM adapter and token policy missing. |
| Audit | Protected envelope reads/writes have two-phase operation audit. HOME submission, offer, selection, commitment, travel, cancellation, and handoff do not have a complete ADR-006 lifecycle audit mapping. | Incomplete. |
| Consultation | The canonical Doctor consultation start/finish implementation is modern and reusable. `UrgentHomeConsultationSourceAdapter` always rejects HOME as not actionable, and finish does not release/complete an urgent-HOME source. | P5 handoff and HOME source convergence missing. |
| Tests | Broad domain, architecture-boundary, WebMvc security, worker, recovery, and PostgreSQL integration tests exist for the development generation. | Strong base, but no production-profile end-to-end contract evidence. |

The provisional command-receipt default is seven days, and its own code explicitly says this is not a production retention decision. No HOME lifecycle cancellation service was found. No HOME lifecycle audit event family was found beyond protected-envelope operations.

### Actual current state machine

The current implementation deliberately separates journey, attempt, matching wave, Doctor offer, and commitment. Transactions use PostgreSQL row locks, optimistic revisions, unique constraints, idempotency receipts, and capacity fences rather than one large status column.

| Owner | State | Entry | Permitted exit | Transaction/concurrency | Timeout/terminal behavior |
|---|---|---|---|---|---|
| Journey | `ACTIVE` | Submission transaction creates one active journey per care subject. | `COMPLETED`, `CANCELLED` | Subject guard, unique active-subject constraint, row lock, journey revision. | Terminal states do not reopen. No production HOME command currently drives them. |
| Attempt | `HOME_CREATED` | Same transaction as journey and initial wave. | `HOME_MATCHING`, `HOME_CANCELLED` | Journey/attempt locks and revision. | No autonomous expiry. |
| Attempt | `HOME_MATCHING` | Matching wave initialized or a held option returns to matching. | `HOME_HELD`, `HOME_EXHAUSTED`, `HOME_CANCELLED` | Current matching epoch, wave lease, attempt revision. | Deadline/exhaustion can produce `HOME_EXHAUSTED`. |
| Attempt | `HOME_HELD` | At least one valid Doctor hold exists. | `HOME_MATCHING`, `HOME_COMMITTED`, `HOME_CANCELLED` | Offer/hold/capacity locks plus attempt revision. | Hold expiry/withdrawal releases capacity and returns to matching when appropriate. |
| Attempt | `HOME_COMMITTED` | Patient selection transaction commits one held Doctor. | `HOME_CANCELLED` | Selection idempotency receipt, expected attempt revision, offer/capacity/attempt locks. | Current code has no command that safely completes travel or handoff. |
| Attempt | `HOME_EXHAUSTED` / `HOME_CANCELLED` | Matching terminal or cancellation transition. | None | Revision-fenced terminal transition. | Terminal. Cancellation orchestration is not implemented. |
| Wave | `PENDING`, `RETRYABLE` | Initial/expanded wave or retry. | `CANDIDATE_READY`, `OFFERS_ISSUED`, `NO_NEW_OFFERS`, recovery/terminal states | `SKIP LOCKED` claim, lease token/expiry, wave revision and matching epoch. External discovery runs outside the completion transaction. | Retries are bounded; stale leases are reclaimable. |
| Wave | `CANDIDATE_READY` | Candidate discovery produced a completion eligible for transactional revalidation/handoff. | `OFFERS_ISSUED`, `NO_NEW_OFFERS`, retry/recovery/terminal states | Same lease, revision and epoch must still own completion; eligibility/capacity are rechecked. | It cannot independently advance the attempt. |
| Wave | `OFFERS_ISSUED`, `NO_NEW_OFFERS`, `RADIUS_EXHAUSTED`, `MATCHING_EXHAUSTED`, `RECOVERY_REQUIRED`, `SUPERSEDED`, `DEADLINE_REACHED`, `CANCELLED` | Worker/coordinator outcome. | Only the coordinator may create a new wave or terminal attempt outcome. | Lease/revision replacement and epoch fencing. | Terminal per wave; journey outcome depends on attempt transition. |
| Offer | `PENDING_RESPONSE` | Matching completion issues an offer. | `ACCEPTED_HELD`, `DECLINED`, `EXPIRED`, `SUPERSEDED`, `CANCELLED`, `INVALIDATED`, `SELECTION_CLOSED` | Doctor ownership, expected offer revision, command receipt, eligibility/capacity recheck. | Response deadline closes stale offer. |
| Offer | `ACCEPTED_HELD` | Doctor accept wins and capacity becomes `HOME_HOLD`. | `SELECTED_COMMITTED`, `HOLD_EXPIRED`, `DOCTOR_WITHDRAWN`, `NOT_SELECTED`, `INVALIDATED`, `CANCELLED` | Hold budget, capacity token/fence, offer/attempt locks. | Default code values are configuration, not certified product policy. |
| Commitment | `ACTIVE` | Patient selection promotes `HOME_HOLD` to `HOME_COMMITMENT`. | `CANCELLED`, `INVALIDATED` | One selection receipt, attempt revision, capacity fence and commitment revision. | No travel, arrival, transfer, or completion states exist. |

### Resolved conflict with Module 04 and CTO ruling

Module 04 assigns the urgent-request module the flow through travel, QR, access grant, MRS skeleton, consultation, and completion. The newer CTO-directed P4-02D contract explicitly ends P4 clinical ownership at physical arrival: P4 records `CLINICAL_HANDOFF_PENDING`; P5 verifies the handoff, owns QR/access grants, creates or adopts the consultation, and performs all MRS access. These cannot both be normative.

ADR-005 also requires short-lived, server-signed, single-use QR nonces, while the older Module 04 payload binds request and MRS identifiers directly. The newer opaque P4-to-P5 handoff excludes MRS ID, clinical content, exact location, and grant data. Implementing the old QR literally would create a second grant and MRS authority.

The CTO-approved resolution is:

1. Issue a formal Module 04 v1.2 amendment declaring P4-02D v1.1 authoritative for arrival, QR, consultation grants, and MRS ownership.
2. Keep the current P4 journey/attempt/wave/offer aggregates canonical for dispatch and matching.
3. Extend the commitment with one dispatch/handoff phase machine; do not replace all aggregates with the product display vocabulary.
4. Keep the existing P5 consultation aggregate canonical for `IN_CONSULTATION` and `COMPLETED`.
5. Treat product lifecycle labels as a read projection only.

Module 04 Amendment v1.2 records that precedence. It historically authorized B1, which is now complete and dormant. It does not authorize B2-B8 or Flutter Phase 1B under the current launch scope. Production activation remains disabled and gated by a future explicit CTO/product scope decision in addition to P5/MRS schema and recovery sign-off, legal/DPO retention values, protected infrastructure, and required certification tests.

### Recommended lifecycle

**Model C is recommended:** the product lifecycle and backend aggregates represent different layers and coexist explicitly, with exactly one authority for each fact.

| Product lifecycle concept | Canonical backend fact | Equivalent? | Production gap | Recommendation |
|---|---|---:|---|---|
| `PENDING` | Journey `ACTIVE`, attempt `HOME_MATCHING`, current wave `PENDING`/`RETRYABLE`/discovery-ready, with no issued offer yet | Yes, as projection | Production intake writer absent | Project queued/discovery work as `PENDING`; do not persist another status. `HOME_CREATED` is an internal same-transaction precursor. |
| `BROADCASTING` | Attempt `HOME_MATCHING` plus an `OFFERS_ISSUED` wave and current `PENDING_RESPONSE` offers | Yes, as projection | No production worker | Project from attempt/wave/offer authority. |
| `PARTIALLY_ACCEPTED` | Attempt `HOME_HELD` plus at least one valid `ACCEPTED_HELD` offer | Yes, as projection | Production endpoints remain gated | Project from current holds. |
| `DOCTOR_SELECTED` | Attempt `HOME_COMMITTED`, one `ACTIVE` commitment and `HOME_COMMITMENT` capacity fence | Yes | Cancellation/dispatch commands missing | Preserve existing selection transaction. |
| `EN_ROUTE` | New commitment dispatch phase `EN_ROUTE` | No | No command, telemetry, ETA, privacy policy | Add to the commitment dispatch boundary only after approval. |
| `ARRIVED` | New P4 phase `CLINICAL_HANDOFF_PENDING` plus immutable arrival fact and handoff intent | No | No arrival/handoff implementation | P4 records arrival but creates no grant. |
| `IN_CONSULTATION` | P5 canonical consultation `IN_PROGRESS`, created after verified fenced transfer | No | HOME source is non-actionable | P5 projection only; P4 records opaque transfer outcome. |
| `COMPLETED` | P5 consultation `COMPLETED`; P4 journey/commitment receives an idempotent opaque terminal callback | No | HOME finish/source release missing | P5 owns clinical completion; P4 closes operational state. |
| `CANCELLED` | Journey/attempt/offer/commitment terminal facts determined by the winning authority/fence | Partial | No orchestration/API | Add one state-aware cancellation service. |

Recommended commitment dispatch/handoff phases are `SELECTED`, `EN_ROUTE`, `CLINICAL_HANDOFF_PENDING`, `HANDOFF_TRANSFER_AUTHORIZED`, `TRANSFERRED`, `COMPLETED`, `CANCELLED`, and `INVALIDATED`. P4 owns through the serialized `HANDOFF_TRANSFER_AUTHORIZED` transition; P5 owns responsibility afterward. The admission/capacity fence remains the cross-module serializer. No client timer may advance a phase.

### Production intake and protected-data contract

Retain `POST /api/v1/me/urgent-home/journeys`, but replace the synthetic writer with an explicitly enabled production strategy. Production startup must fail if the protected strategy, approved KEK/KMS backend, retention policy keys, audit availability, or required worker capability is missing. The synthetic strategy remains impossible to activate in a production profile.

**Actor and subject**

- Authentication: PATIENT session only.
- Request subject: `subjectType=SELF` with no `familyMemberId`, or `subjectType=FAMILY_MEMBER` with an owned `family_members.id`.
- The server resolves operational patient and optional MRS references. Patient, operational-patient, or MRS IDs supplied by a client are rejected as unknown fields.
- Ownership is revalidated for submission, every read, selection, cancellation, recovery, notification open, and handoff preparation.

**Request**

```json
{
  "subjectType": "SELF",
  "familyMemberId": null,
  "triage": {
    "bodyAreaCodes": ["CHEST"],
    "painScore": 7,
    "shortDescription": "free text, maximum 500 characters",
    "passportShareIntent": true
  },
  "destination": {
    "acquisitionMode": "CURRENT_LOCATION",
    "provenance": "DEVICE_GPS",
    "latitude": 36.8065,
    "longitude": 10.1815,
    "accuracyMeters": 18.0,
    "capturedAt": "2026-11-09T10:00:00Z",
    "confirmedAddress": "patient-confirmed display address",
    "providerReference": null,
    "confirmed": true
  },
  "contractVersion": 1
}
```

The final body-region catalog and permitted free-text policy require clinical/product approval. Unknown codes, unknown fields, unconfirmed destinations, stale/invalid coordinates, inconsistent SELF/family shape, oversized text, and unsupported contract versions fail with deterministic validation errors. `passportShareIntent` records intent only; it creates no access grant and exposes no passport data.

Apply per-account submission rate limits and a stricter per-subject active-journey constraint. Rate limits must not prevent reads, cancellation, or recovery. Limits and matching policy are versioned server configuration and are returned as safe capability metadata, not hard-coded into Flutter.

**Exact successful response**

```json
{
  "contractVersion": 1,
  "journeyId": "uuid",
  "attemptId": "uuid",
  "waveId": "uuid",
  "journeyRevision": 0,
  "attemptRevision": 1,
  "productState": "PENDING",
  "attemptState": "HOME_MATCHING",
  "waveState": "PENDING",
  "matchingEpoch": 1,
  "matchingDeadlineAt": "instant",
  "availableActions": ["CANCEL"],
  "replayed": false,
  "evaluatedAt": "instant"
}
```

Return `201 Created` with `Location` for first execution and `200 OK` with `replayed=true` for a completed replay. The initial response must not claim that a worker has run or that any Doctor received the request.

**Persistence and data boundary**

| Data | Main PostgreSQL | Protected/encrypted storage | MRS | Redis | Logs | Audit metadata |
|---|---|---|---|---|---|---|
| Aggregate IDs, revisions, state, opaque subject reference, timestamps | Yes | At-rest database controls | No | Optional short-lived cache only | Correlation ID only | Opaque IDs and transition outcome |
| Body regions, pain, symptoms/free text | Envelope reference and schema/version only | Required application envelope encryption with clinical key purpose | Not at intake; P5 may adopt under an approved verified handoff | Never | Never | Operation, purpose, outcome; no content |
| Exact destination/address/GPS | Envelope reference and provenance class only | Required independent destination envelope/key purpose | Never copied by P4 | Only purpose-bound ephemeral matching/route projection if needed | Never | Access purpose/outcome; no coordinates/address |
| Passport-share intent | Boolean/version permitted | Database encryption at rest | No grant until P5 verification | Never | Never | Intent change, not passport content |
| Doctor public/professional display projection | Approved projection | Sensitive fields minimized | No | Candidate/availability hints permitted | Never as payload | Selection/offer opaque references |
| Idempotency payload fingerprint | Hash/HMAC only | Secret-backed fingerprint recommended | No | No | Never key or fingerprint | Command outcome, not raw key |

The P4 operational module never becomes a clinical record system and never writes the intake directly to MRS. Envelope decrypt is purpose-scoped and two-phase audited. Protected-data failure is fail-closed.

Retention remains keyed, not hard-coded: `P4_TRIAGE`, `P4_EXACT_LOCATION`, `P4_ROUTE_TELEMETRY`, `P4_IDEMPOTENCY`, `P4_OFFER`, `P4_COMMITTED`, `P4_NOTIFICATION`, and `AUDIT` require legal/DPO-approved durations. The provisional seven-day receipt value is not a production answer. No route history is retained by default.

### Proposed API surface

Existing `/api/v1` paths can remain because no production patient HOME client exists and old Flutter builds are fail-closed. DTO changes must be additive where an existing Doctor client already consumes them.

| Actor | Method and path | Purpose | Authority/idempotency |
|---|---|---|---|
| PATIENT | `POST /api/v1/me/urgent-home/journeys` | Protected production submission | `Idempotency-Key`; server subject resolution |
| PATIENT | `GET /api/v1/me/urgent-home/journeys/{journeyId}` | Authoritative product/aggregate projection | Owned journey; `no-store` |
| PATIENT | `GET /api/v1/me/urgent-home/journeys/active?subjectType=&familyMemberId=` | Recover current active journey | Owned resolved subject; bounded one-result read |
| PATIENT | `GET /api/v1/me/urgent-home/submissions/recovery` | Recover unknown POST by original key | `Idempotency-Key`; account-scoped receipt |
| PATIENT | `GET /api/v1/me/urgent-home/journeys/{journeyId}/accepted-doctors` | Current held Doctor options | REST authority; expired options omitted |
| PATIENT | `POST /api/v1/me/urgent-home/journeys/{journeyId}/selection` | Commit one held Doctor | Stable key plus selected offer and expected attempt revision |
| PATIENT | `POST /api/v1/me/urgent-home/journeys/{journeyId}/cancel` | State-aware cancellation | Stable key, expected journey/commitment revision, reason code |
| PATIENT | `GET /api/v1/me/urgent-home/journeys/{journeyId}/tracking` | Current server-calculated route projection | Only when selected commitment is `EN_ROUTE`; no history |
| DOCTOR | `GET /api/v1/me/urgent-home/offers` and `/{offerId}` | Existing owned offers | Reuse current cursor and `no-store` behavior |
| DOCTOR | `POST .../offers/{offerId}/accept`, `/decline`, `/withdraw` | Existing offer decisions | Stable key and expected offer revision |
| DOCTOR | `GET /api/v1/me/urgent-home/commitments/active` and `/{commitmentId}` | Current owned commitment | Reuse; add phase/actions additively |
| DOCTOR | `GET /api/v1/me/urgent-home/commitments/{commitmentId}/dispatch-context` | Purpose-scoped exact destination | Current commitment, Doctor, capacity and phase rechecked before and after decrypt |
| DOCTOR | `POST /api/v1/me/urgent-home/commitments/{commitmentId}/travel/start` | Authoritative `EN_ROUTE` transition | Stable key and expected commitment revision |
| DOCTOR | `PUT /api/v1/me/urgent-home/commitments/{commitmentId}/location` | Replace ephemeral latest location | Expected commitment revision, bounded frequency, current phase |
| DOCTOR | `POST /api/v1/me/urgent-home/commitments/{commitmentId}/arrival` | Record physical arrival and create handoff intent | Stable key, expected revision/admission fence |
| DOCTOR | `POST /api/v1/me/urgent-home/commitments/{commitmentId}/cancel` | Selected Doctor cancellation | Stable key, expected revision, approved reason |
| PATIENT | `POST /api/v1/me/urgent-home/journeys/{journeyId}/handoff-challenges` | Request short-lived P5-owned check-in QR/challenge after P4 arrival | Only in `CLINICAL_HANDOFF_PENDING`; server-signed single-use nonce |
| DOCTOR/P5 | `POST /api/v1/doctor/urgent-home/handoffs/{handoffIntentId}/verify` | Consume challenge and perform P5 verification | Stable key; nonce, actor, commitment, subject, expiry and fence binding |
| P5 service | `POST /internal/v1/urgent-home/handoffs/{handoffIntentId}/prepare-transfer` | Serialized P4 authority transfer | mTLS/service identity; expected aggregate/admission/handoff fences |
| DOCTOR | `POST /api/v1/doctor/consultations/start` | Existing canonical consultation start | `sourceType=URGENT_HOME`, `sourceId=commitmentId`, P5 transfer/source version |
| DOCTOR | `POST /api/v1/doctor/consultations/{consultationId}/finish` | Existing canonical completion | Existing consultation/clinical-record revisions and stable key |
| PATIENT/DOCTOR | `GET /api/v1/me/urgent-home/activity` | Durable opaque resync history | Current actor/recipient only; sequence pagination |

The handoff challenge endpoint may be physically hosted by P5, but P4 must not generate a grant or store a nonce/MRS identifier. The external route remains a product API; internal service transfer uses authenticated service identity and fencing.

### Idempotency and recovery

- Keys are client-generated UUIDv4 strings, scoped by authenticated actor plus command type; maximum 128 characters. A key is never shared across submit, select, cancel, travel, arrival, or consultation commands.
- Before the POST, Flutter persists the account-scoped submission key. The server stores a secret-backed normalized request fingerprint and completion projection, not the raw clinical payload.
- Same actor/scope/key plus the same normalized payload returns the original resource and current safe projection: `200`, `replayed=true`.
- Same actor/scope/key plus a different normalized payload returns `409 HOME_SUBMISSION_IDEMPOTENCY_CONFLICT` and never mutates the original journey.
- Concurrent same-key execution is serialized. The loser returns `409 HOME_SUBMISSION_COMMAND_IN_PROGRESS` with `Retry-After`, then recovery/read is safe. It never creates a second journey.
- A response lost after commit is recovered by the same POST/key or `GET /submissions/recovery` with the original key.
- Recovery by journey ID remains authoritative. New active-journey discovery is required when the app has neither key nor ID; it resolves the SELF/family subject server-side and returns at most the one active journey guaranteed by the subject constraint.
- Socket disconnect, notification launch, foreground resume, and app launch always perform a REST read. A notification or socket event is never a state transition.
- Receipt retention must be at least the approved mobile recovery horizon and cannot expire while its journey is active. Exact terminal retention is `LEGAL_POLICY_REQUIRED:P4_IDEMPOTENCY`; legal/DPO approval is an implementation prerequisite.
- If no active journey or receipt exists, the client shows an interrupted/not-found state and requires explicit new user intent. It never silently submits again.

### Matching productionization

Submission inserts the first due wave in the same transaction as the journey and attempt. A production scheduled trigger invokes the existing bounded matching and recovery workers on every eligible instance. PostgreSQL `FOR UPDATE SKIP LOCKED`, lease token/expiry, matching epoch, and wave revision already prevent double ownership; a global single-node lock would reduce availability and is not required.

Production requirements:

- remove the development-only access policy only for the protected production generation;
- schedule bounded ticks with configurable cadence and execution budget;
- retain external destination resolution, Redis discovery, and routing outside the state-transition transaction;
- revalidate Doctor eligibility, availability, suspension, route, fee, capacity, journey, epoch, and deadline inside the completion boundary;
- keep 5/10/20 km, three waves, offer wait, retry count, and ten-minute deadline as configuration pending product approval, not immutable contract values;
- expand/retry only through the coordinator; no controller or client starts a wave;
- on zero candidates or all declines/expiries, advance within the approved radius/deadline policy; when exhausted, set the authoritative exhausted outcome and notify the patient;
- reclaim expired worker leases and dead-letter/recovery-route poison work without issuing duplicate offers;
- expose readiness and metrics for scheduler enabled status, oldest due wave, runnable backlog, claim count, stale lease recovery, outcome counts, deadline misses, recovery-required count, and last successful cycle;
- fail startup if production HOME intake is enabled while matching/recovery workers or their dependencies are not ready.

### Doctor offer, patient selection, and commitment contract

Reuse the existing Doctor endpoints, DTO identities, stable keys, revision checks, hold budget, and shared capacity ledger. A Doctor may list/get only their own current offers. Pre-acceptance response contains only the minimum dispatch decision data approved by ADR-003; it never includes passport content, MRS ID, full clinical narrative, or exact destination.

Offer expiry and hold expiry are distinct. Accept rechecks current role, professional status, HOME availability, route eligibility, deadline, hold budget, and capacity. A replay returns the same offer. A stale revision or expired offer is a conflict, not a fresh acceptance. Concurrent Doctors may hold up to the configured attempt budget, but only patient selection can create the one commitment.

The accepted-Doctor read remains authoritative and returns `offerId`, backend `doctorId`, display name, specialty, quoted TND fee/currency, verified road distance, route verification time, hold expiry, offer revision, attempt revision, matching epoch, actions, and evaluation time. ETA is included only if a server route service supplies an `etaSeconds` with `etaEvaluatedAt`; Flutter must not calculate or invent it.

Selection carries `selectedOfferId`, `expectedAttemptRevision`, and a stable key. The winning transaction promotes the selected capacity, creates one commitment, closes siblings, and returns the commitment. Expired hold, stale revision, Doctor suspension, or capacity conflict causes a REST refresh and new authoritative choice; no local Doctor identity survives the conflict.

A production commitment contains commitment/journey/attempt/selected-offer IDs, Doctor and opaque care-subject references, matching epoch, dispatch phase, revision, admission fence, immutable fee/currency snapshot, committed/updated/terminal timestamps, cancellation reason, available actions, and evaluation time. Patients see the selected professional projection and tracking phase; Doctors see their own commitment and purpose-scoped dispatch context. Neither side sees internal patient/MRS IDs.

### Travel and location

The recommended production contract includes travel because the locked product journey requires it. Until all items below are implemented and approved, Flutter travel/arrival screens remain disabled.

`travel/start` is the sole authority for `SELECTED -> EN_ROUTE`. It is Doctor-only, revision/idempotency fenced, rechecks commitment, capacity, professional status and destination availability, and emits an opaque invalidation/push. A selection response or local timer cannot imply travel.

Doctor location publication replaces a single encrypted/ephemeral latest point. It is accepted only for the current Doctor/commitment in `EN_ROUTE`, is rate-limited, contains captured time/accuracy/mock metadata, and rejects stale or impossible updates. The patient tracking GET authorizes current journey ownership and returns only the latest point age, server-calculated distance/ETA, and stale flag. Suggested ingest cadence is at most every five seconds and ETA recalculation at most every thirty seconds, configurable by policy. The client stops publication on background, cancellation, arrival, suspension, or transfer.

No route history is retained by default. Redis may hold the latest point with a short TTL; durable location evidence, if legally required for an incident, needs a separate approved policy. Exact patient destination remains in the destination envelope and is exposed only to the selected Doctor for active dispatch. GPS never enters logs, push, WebSocket payloads, audit metadata, or metrics labels.

En-route Doctor cancellation is a serialized command. The current commitment is cancelled, access/location is revoked, capacity is released, the matching epoch advances, and the same journey may re-enter matching for the Amendment v1.1 rebroadcast window only if product policy, deadline, and patient state permit it. No new patient submission is created.

### Arrival, QR, P5 handoff, and consultation

The Doctor arrival command records an immutable physical-arrival fact, transitions the P4 commitment to `CLINICAL_HANDOFF_PENDING`, stops route telemetry, and writes one durable handoff intent/outbox event. P4 remains responsible and no passport/MRS access exists yet.

The check-in challenge follows ADR-005:

- generated and signed server-side by P5 after confirming the P4 handoff intent;
- opaque, audience-bound to the Patient subject, selected Doctor, commitment, handoff intent, and contract version;
- contains or references a cryptographically random nonce, no MRS ID or clinical data;
- expires after three minutes with the approved clock-skew policy;
- Types 1/2 nonce use is atomically single-use in the authoritative database;
- online verification is mandatory; screenshot/replay, wrong Doctor, wrong commitment, expired nonce, revoked intent, or fence mismatch fails closed;
- every attempt is Tier-1 medical-access audit with no QR material logged.

Successful verification does not let P4 issue a grant. P5 calls idempotent `prepare-transfer`; P4 serializes it against cancellation under journey, commitment, admission and handoff fences. The winning P4 transaction records `HANDOFF_TRANSFER_AUTHORIZED`, advances the admission ledger to `P5_CLINICAL_BUSY`, and emits a transfer event. This is the responsibility-transfer point.

P5 consumes the transfer authorization into a transfer-ready inbox. The existing `POST /api/v1/doctor/consultations/start` is then the single creation command: its P5-authoritative transaction creates/adopts the consultation, creates the consultation/subject/professional/purpose-scoped access grant, and initializes only the approved MRS consultation context. P5 emits an opaque callback; P4 stores only outcome/version. A lost callback is reconciled by handoff intent ID. P4 never stores grant credentials or medical payload.

The start request uses `sourceType=URGENT_HOME`, `sourceId=commitmentId`, and the transfer/source version returned by the verified handoff. It is Doctor-only, idempotent, and actionable only after transfer authorization; grant and MRS context creation are part of the same fail-closed start orchestration, not client preconditions or a second API success. The response is the existing canonical `ConsultationResponse`. A second active consultation, stale source version, wrong Doctor, unresolved subject, unavailable mandatory audit, or MRS context failure is a deterministic conflict/service failure; no second consultation is created.

The existing finish coordinator remains canonical. Clinical record, diagnosis, notes, orders/prescriptions and documents remain in MRS/P5—not matching tables. Finish must be extended to release the `URGENT_HOME` source, close/revoke the access grant, advance admission to `POST_HANDOFF_UNAVAILABLE`, and send an idempotent opaque completion outcome to P4. P4 then marks the operational commitment/journey completed and enables rating eligibility. P4 stores fee/dispatch/audit metadata only.

### Cancellation matrix

| Scenario | Allowed authority/state | Result | Required side effects |
|---|---|---|---|
| Patient cancels while created/matching | Owning Patient; pre-commit | Attempt/journey cancelled | Cancel waves/offers, release holds/capacity, revoke destination/triage access, stop delivery, notify affected Doctors, audit. |
| Patient cancels with accepted Doctors | Owning Patient; `HOME_HELD` | Attempt/journey cancelled | Close all held offers, release every capacity claim, notify held Doctors, audit. |
| Patient cancels after selection, before transfer | Owning Patient; `SELECTED`, `EN_ROUTE`, or handoff pending before `prepare-transfer` wins | Commitment and journey cancelled | Stop telemetry, revoke dispatch context/challenge, release capacity, notify Doctor, audit; compensation policy may apply outside this technical contract. |
| Patient requests stop after transfer | P5 consultation authority | P5 cancellation/revocation workflow | P4 records advisory/opaque outcome only; it cannot claim grant revocation. |
| Doctor declines | Offered Doctor; `PENDING_RESPONSE` | Offer `DECLINED`; matching continues | Re-evaluate wave/deadline, patient invalidation if needed, audit. |
| Doctor hold expires | System clock/worker; `ACCEPTED_HELD` | `HOLD_EXPIRED`; capacity released | Attempt returns to matching if no valid hold; notify both sides as applicable; audit. |
| Selected Doctor cancels before travel | Selected Doctor; `SELECTED` | Commitment cancelled; same journey rebroadcast if policy permits | Increment matching epoch, release capacity, new wave, patient high-priority notification, audit. |
| Selected Doctor cancels en route | Selected Doctor; `EN_ROUTE` | Commitment cancelled; telemetry revoked; controlled same-journey rebroadcast | Amendment v1.1 window/deadline applies; never create a second journey silently; high-priority patient notification and audit. |
| Doctor suspended before transfer | Security/admin authority | Offers/holds/commitment invalidated | Revoke dispatch access, telemetry and challenge; release or quarantine capacity; rebroadcast or terminal recovery by policy; notify/audit. |
| Doctor suspended after transfer | P5/security authority | P5 blocks/revokes clinical access | P4 records safe opaque status; no P4 grant action; Tier-1 audit. |
| Matching deadline/system timeout | Matching worker; created/matching/held as policy permits | Attempt exhausted; journey terminal or explicit retry action | Close offers/holds, release capacity, notify Patient, audit and metric. |
| Admin cancellation | Narrow support/security role with reason and step-up authorization | Same serialized state-aware cancellation as the owning authority | No direct SQL/state override; mandatory audit, notifications, access revocation and compensation workflow. |
| Cancel races with transfer | P4 locks/fences | Cancellation first rejects transfer; transfer first returns `P5_RESPONSIBILITY_TRANSFERRED` | Never report both successful cancellation and successful transfer. |

Every cancellation command is idempotent, revision-fenced, has an enumerated non-clinical reason, and returns the current authoritative projection. Rebroadcast reuses the journey and creates a new attempt/epoch; it never reuses a revoked commitment or creates a second active journey.

### Realtime and push

Production WebSocket follows `WebSocket = hint; REST = authority` on `/user/queue/home`. Reuse the durable lifecycle intent, generation, lease, retry, dead-letter, and recipient history machinery, but replace the fake publisher and add a production scheduled worker.

Envelope:

```json
{
  "eventId": "uuid",
  "eventType": "HOME_STATE_CHANGED",
  "aggregateType": "HOME_JOURNEY",
  "aggregateId": "uuid",
  "aggregateVersion": 12,
  "recipientSequence": 481,
  "occurredAt": "instant",
  "resyncRequired": true
}
```

No symptoms, address, GPS, patient/Doctor name, fee, QR, grant, or clinical state payload is sent. Delivery is at least once and may be delayed, duplicated, or out of order. Clients deduplicate by event ID, compare sequence/version only to detect gaps/staleness, coalesce refresh, and read REST on event, connection epoch, reconnect, foreground, push open, and suspected gap. A lower version never regresses client state.

If WebSocket publication is not ready when the rest of Phase 1 is implemented, the approved fallback is FCM invalidation plus REST: immediate foreground refresh on user action/event, bounded five-second matching/hold polling while the matching screen is visible, bounded five-to-ten-second committed/travel tracking reads while visible, and a foreground/resume read. Background polling is prohibited. These cadences remain server-configurable capabilities.

Required push transitions are:

| Recipient | Transition | Priority | Payload/action |
|---|---|---:|---|
| Doctor | New actionable offer | High, short TTL | `offerId`, navigation type, event ID only; open fetches offer. |
| Patient | First/new valid Doctor hold | High | `journeyId`, navigation type, event ID; open fetches status and accepted Doctors. |
| Patient and selected Doctor | Commitment created | High | Journey/commitment opaque IDs; both re-fetch. |
| Patient | Doctor started travel | High | Journey/commitment IDs; tracking read is authority. |
| Patient/Doctor | Arrival/check-in required or handoff verified | High where user action is required | Handoff/journey opaque ID; never QR/grant data. |
| Affected actor | Cancellation, withdrawal, suspension, expired hold, matching exhausted/recovery required | High when immediate safety/action impact; otherwise normal | Opaque aggregate/event IDs; open re-fetches current state. |
| Patient | Consultation completed/rating eligible | Normal | Journey/consultation opaque navigation ID; authorized read required. |

Token ownership, logout unregister, account switching, TTL/collapse keys, retry/dead-letter health, and production FCM/APNs configuration remain mandatory release inputs. Push copy contains no clinical truth and cannot advance UI state.

### Authorization, security, audit, and observability

| Endpoint family | Allowed actor | Object rule |
|---|---|---|
| Patient submit/status/recovery/active/accepted/select/cancel/tracking/challenge | PATIENT | Authenticated account owns SELF or the selected family member at every operation. |
| Doctor offers | DOCTOR | Offer recipient is the authenticated Doctor; current professional eligibility is rechecked for commands. |
| Doctor commitment/dispatch/travel/location/arrival/cancel | DOCTOR | Commitment Doctor equals authenticated Doctor; current phase, capacity and suspension fences pass. |
| Handoff verify / consultation | DOCTOR plus P5 policy | Selected Doctor, verified challenge, current transfer/grant, consultation scope. |
| Administrative cancel/suspension | Dedicated support/security permission, not generic ADMIN role | Step-up auth, reason, least privilege, mandatory audit; never passport access. |
| Internal prepare/callback | P4/P5 service identity | mTLS or approved service authentication, schema version, intent and fencing checks. |

Receiving an offer grants no Medical Passport access. A commitment grants only minimum dispatch context. Passport access begins only through the P5 consultation-scoped grant after verified transfer. Break-glass, if used, remains a separate step-up P5/ADR-003 workflow and never changes HOME matching authority.

| Field | Classification | Storage | Encryption | Logged? | Audited? |
|---|---|---|---|---:|---:|
| Symptoms/free text | Restricted health data | P4 clinical envelope until policy deletion; P5/MRS only after explicit verified adoption | Application envelope + database/disk controls | No | Access/operation only |
| Pain score/body regions | Restricted health data | Same clinical envelope | Application envelope | No | Access/operation only |
| Patient GPS/exact address | Highly sensitive location | Independent P4 destination envelope; ephemeral authorized projection | Application envelope; TLS in transit | No | Purpose/outcome only |
| Doctor GPS | Highly sensitive location | Latest ephemeral Redis value; no route history by default | TLS and protected Redis/infrastructure encryption | No | Start/stop/access outcome, not coordinates |
| Patient/Doctor IDs | Personal identifiers | Operational foreign keys/opaque references | Database encryption at rest | No raw IDs in general logs | Opaque reference where necessary |
| Journey/request/offer/commitment IDs | Pseudonymous operational identifiers; `journeyId` is the canonical request ID and no second client request identity is accepted | PostgreSQL | Database encryption at rest | Only approved correlation/structured context, never with medical payload | Yes for state changes |
| Consultation ID | Restricted clinical linkage | P5/consultation store; opaque P4 outcome only | Database encryption at rest | No | Yes, Tier 1/medical workflow |
| Price/fee | Personal commercial data | Immutable commitment snapshot | Database encryption at rest | No | Selection/commitment outcome |
| Timestamps | Operational/personal metadata | Relevant aggregate | Database encryption at rest | Coarse operational timing permitted | Yes for transitions |
| QR nonce/signature/grant/token | Credential/security material | P5 nonce/grant stores only | Server signing/HMAC key in KMS; hashes where possible | Never | Attempt/outcome only |

ADR-006 mapping:

- Tier 1 fail-closed: QR generation/verification, handoff verification/transfer, grant create/read/revoke, passport access, consultation start/finish, MRS read/write, and break-glass.
- Tier 2 transactional: submission, Doctor accept/decline/withdraw, patient selection, commitment/travel/arrival/cancellation transitions, professional suspension effects, and administrative action.
- Tier 3/operational: matching worker claims/outcomes, push/realtime delivery, reconciliation and retention jobs, recorded with aggregate counts/opaque references and without protected content.

Two-phase audit remains mandatory where a protected read/write can fail after an attempt. Audit unavailability blocks Tier-1 access and any transition whose policy requires synchronous audit. Audit metadata contains actor, role, operation, purpose, opaque aggregate, version, outcome, reason code, and trace ID—never symptoms, coordinates, address, QR, token, or MRS payload.

Production metrics use bounded labels such as environment, operation, outcome, state, failure class, worker generation, and provider. Required measurements include submissions, idempotent replays/conflicts, matching duration, waves/offers, acceptance and selection rates, exhaustion/deadline/cancellation reasons, active/expired holds, worker backlog/oldest age/lease recovery/dead letters, travel-location stale rate, handoff latency/failures, consultation-source failures, push/realtime attempts/failures/lag, and REST reconciliation failures. Patient, Doctor, journey, offer, commitment, consultation, device and notification IDs are forbidden labels.

### Definitive error catalog

All failures use RFC 7807/problem details with stable `code`, safe title/detail, trace correlation, and optional `retryAfterSeconds`/`currentRevision`/`availableActions`. Internal exception text is never exposed.

| Endpoint/HTTP | Code | Condition | Retryable? | Flutter behavior |
|---|---|---|---:|---|
| Any / `400` | `VALIDATION_FAILED` | Shape, unknown field, unsupported enum, invalid key format | No until corrected | Keep draft; show field-safe error. |
| Submit / `400` | `HOME_TRIAGE_INVALID` | Triage catalog/score/text invalid | No until corrected | Keep unconfirmed draft. |
| Submit / `400` | `HOME_DESTINATION_INVALID` | Unconfirmed/stale/invalid destination | No until corrected | Reconfirm location/address. |
| Any / `401` | `AUTHENTICATION_REQUIRED` | Missing/expired invalid session | Auth flow only | Do not infer cancellation. |
| Any / `403` | `ROLE_NOT_ALLOWED` | Authenticated role cannot use endpoint | No | Fail closed. |
| Owned reads / `404` | `HOME_JOURNEY_NOT_FOUND`, `HOME_OFFER_NOT_FOUND`, `HOME_COMMITMENT_NOT_FOUND` | Absent or not owned; do not disclose existence | No; refresh/exit | Remove stale route. |
| Submit / `409` | `HOME_ACTIVE_JOURNEY_EXISTS` | Subject already has active journey | Yes via read, not new POST | Discover/recover existing journey. |
| Submit / `409` | `HOME_SUBMISSION_IDEMPOTENCY_CONFLICT` | Same key, different fingerprint | No | Stop; preserve original key; recover. |
| Submit / `409` | `HOME_SUBMISSION_COMMAND_IN_PROGRESS` | Concurrent same-key execution | Yes | Honor retry-after then recover. |
| Recovery / `404` | `HOME_SUBMISSION_RECOVERY_NOT_FOUND` | No completed unexpired receipt | No blind retry | Try active discovery; show interrupted state. |
| Recovery / `429` | `HOME_SUBMISSION_RECOVERY_RATE_LIMITED` | Excessive recovery reads | Yes | Back off. |
| Submit/worker / `503` | `HOME_PROTECTED_INTAKE_UNAVAILABLE` | KMS/envelope/audit/required worker not ready | Yes with same key | Stay unconfirmed; retry/recover. |
| Status read / `200` | `productState=MATCHING_EXHAUSTED` | Server terminal matching outcome/no Doctors within approved policy | Not an error or automatic POST | Show authoritative terminal and only server-provided retry/new-request action. |
| Status read / `200` | `productState=CANCELLED` | Authoritative cancellation won | Not retryable as the same operation | Stop matching/tracking and render terminal state. |
| Offers / `409` | `HOME_OFFER_NOT_ACTIONABLE` | Stale/terminal/wrong phase | No command retry | Refresh offer/list. |
| Offers / `409` | `HOME_OFFER_STALE_REVISION` | Expected revision differs | No blind retry | Refresh and require current action. |
| Offers / `409` | `HOME_HOLD_BUDGET_FULL` | Attempt accepted-hold limit reached | Potentially later | Refresh; do not claim acceptance. |
| Offers / `409` | `HOME_DOCTOR_CAPACITY_CONFLICT` | Doctor capacity changed | No blind retry | Refresh Doctor workspace. |
| Offers / `409` | `HOME_OFFER_ELIGIBILITY_CHANGED` | Availability/suspension/routing changed | No | Close action and refresh. |
| Routing / `503` | `HOME_ROUTE_VERIFICATION_UNAVAILABLE` | Authoritative route service unavailable | Yes same command/key | Stay pending; retry/reconcile. |
| Selection / `409` | `HOME_SELECTION_STALE_REVISION` | Attempt revision changed | No blind retry | Refresh accepted Doctors. |
| Selection / `409` | `HOME_HOLD_EXPIRED` | Selected hold expired | No | Refresh and choose current option. |
| Selection / `409` | `HOME_SELECTION_NOT_ACTIONABLE` | Journey/attempt/offer phase invalid | No | Refresh journey. |
| Selection / `409` | `HOME_SELECTION_IDEMPOTENCY_CONFLICT` / `HOME_SELECTION_COMMAND_IN_PROGRESS` | Key mismatch/concurrency | Conflict: no; in-progress: yes | Recover current journey/commitment. |
| Cancel / `409` | `HOME_CANCELLATION_NOT_ACTIONABLE` | State no longer P4-cancellable | No | Refresh; if transferred, follow P5 action. |
| Cancel / `409` | `P5_RESPONSIBILITY_TRANSFERRED` | Transfer won cancellation race | No P4 retry | Fetch consultation/P5 state. |
| Travel / `409` | `HOME_TRAVEL_NOT_ACTIONABLE` / `HOME_COMMITMENT_STALE_REVISION` | Wrong phase/version/current Doctor | No blind retry | Refresh commitment. |
| Location / `409` | `HOME_LOCATION_NOT_ACTIONABLE` | Not current en-route commitment | No | Stop publication. |
| Location / `429` | `HOME_LOCATION_RATE_LIMITED` | Publication exceeds policy | Yes after delay | Throttle. |
| Dispatch / `503` | `HOME_DISPATCH_CONTEXT_UNAVAILABLE` | Protected destination cannot be safely read | Yes | Do not start/continue route blindly; reconcile. |
| Arrival / `409` | `HOME_ARRIVAL_NOT_ACTIONABLE` | Wrong phase, stale fence, cancelled/suspended | No blind retry | Refresh commitment. |
| QR / `400` | `HOME_HANDOFF_CHALLENGE_INVALID` | Malformed challenge | No | Request a new authorized challenge. |
| QR / `409` | `HOME_HANDOFF_CHALLENGE_EXPIRED`, `..._CONSUMED`, `..._REVOKED` | Time/single-use/revocation failure | New challenge only if server permits | Remain handoff pending. |
| Handoff / `409` | `HOME_HANDOFF_FENCE_CONFLICT` | Cancellation/transfer/version race | No blind retry | Reconcile P4 and P5 outcomes. |
| Consultation start / `409` | `CONSULTATION_SOURCE_NOT_ACTIONABLE`, `CONSULTATION_SOURCE_VERSION_CONFLICT`, `ACTIVE_CONSULTATION_EXISTS` | Transfer/source invalid or active consultation exists | No blind retry | Read active consultation/source. |
| Handoff/MRS/audit / `503` | `HOME_HANDOFF_UNAVAILABLE`, `MRS_UNAVAILABLE`, `MANDATORY_AUDIT_UNAVAILABLE` | Required authority unavailable | Yes with same key | Remain in safe owner state; never grant locally. |
| Any write / `429` | `RATE_LIMITED` | Actor/device abuse control | Yes | Honor retry-after. |
| Any / `500` or `503` | `TRANSIENT_SERVER_FAILURE` | Safe classified internal/dependency failure | Yes only per command idempotency | Same key/recovery; no success UI. |

Existing current error names may be retained where semantics match; implementation must add the missing stale/expired/cancellation/travel/handoff distinctions rather than forcing Flutter to parse messages.

### Versioning and staged rollout

- Keep synthetic activation permanently impossible in production. Production capability is a separate explicit mode validated at startup.
- Add `contractVersion`, `productState`, `dispatchPhase`, `availableActions`, revisions, and safe capability metadata additively. Existing Doctor fields and paths remain stable.
- JSON enums are append-only within v1. The backend returns only states/actions supported by the negotiated contract capability; unknown values cause clients to fail closed and refresh, never infer progress.
- Publish machine-readable OpenAPI/contract fixtures and consumer tests before Flutter implementation.
- Add a server capability such as `urgentHome.productionContractVersion=1`; Flutter Phase 1B remains fail-closed unless the capability is present and compatible.
- Deploy dormant schema and readers first, then workers/adapters, then production capability for internal accounts, then new Flutter. Old Flutter remains on the unavailable screen and cannot accidentally activate synthetic endpoints.
- Breaking identity, ownership, or command-shape changes require `/api/v2`; additive projections and new actions do not.
- Realtime/push generations are independently enableable. REST remains correct when either delivery channel is disabled.

### Complete authoritative happy path

```text
PATIENT POST /me/urgent-home/journeys with stable submission key
  -> one protected P4 transaction resolves subject, writes encrypted envelopes,
     creates ACTIVE journey, advances its attempt HOME_CREATED -> HOME_MATCHING,
     inserts the due PENDING wave, and completes receipt + audit
  -> scheduled matching worker claims the wave under a PostgreSQL lease
  -> worker discovers candidates; coordinator revalidates and writes owned offers
  -> durable push/realtime intents notify each Doctor; Doctor GETs the offer
  -> Doctor POSTs accept with key/revision
  -> transaction creates ACCEPTED_HELD + HOME_HOLD capacity and patient invalidation
  -> Patient GETs journey and accepted-doctors REST authority
  -> Patient POSTs selection with offer, expected attempt revision and stable key
  -> transaction creates ACTIVE/SELECTED commitment, HOME_COMMITTED attempt,
     HOME_COMMITMENT capacity, closes sibling offers, and emits notifications
  -> Doctor GETs commitment and purpose-scoped dispatch context
  -> Doctor POSTs travel/start with commitment revision
  -> P4 transitions commitment dispatch phase to EN_ROUTE
  -> Doctor publishes bounded latest location; Patient GETs tracking projection
  -> Doctor POSTs arrival with current revision/admission fence
  -> P4 records arrival, CLINICAL_HANDOFF_PENDING and durable handoff intent
  -> Patient obtains P5 server-signed short-lived one-use check-in challenge
  -> selected Doctor verifies challenge through P5
  -> P5 calls fenced P4 prepare-transfer; P4 records HANDOFF_TRANSFER_AUTHORIZED
     and atomically moves admission to P5_CLINICAL_BUSY
  -> P5 records a transfer-ready inbox outcome
  -> Doctor POSTs existing /doctor/consultations/start with URGENT_HOME source
  -> one P5 transaction creates/adopts consultation + scoped grant + MRS context;
     canonical consultation becomes IN_PROGRESS and P4 records opaque outcome
  -> Doctor uses existing clinical record/order/prescription paths in P5/MRS
  -> Doctor POSTs existing consultation finish with stable key and versions
  -> P5 finalizes MRS, revokes grant, releases source/admission and emits outcome
  -> P4 idempotently marks operational commitment/journey completed
  -> Patient REST read shows COMPLETED and server-authorized rating eligibility
```

Every arrow is a server command, transaction, durable event, or REST reconciliation. WebSocket, push, UI timers, and route arguments are never lifecycle authority.

### Implementation delta and order

| Component | Current | Production-required | Disposition | Risk |
|---|---|---|---|---|
| Subject identity | Server-owned SELF/family resolver | Same plus coverage on every new endpoint | Reuse | Low |
| Protected intake | Envelopes/audit scaffold; synthetic writer only | Production writer, KMS/policy/startup gate | Modify/new | High—health/location data |
| Submission/status/recovery | Development-gated and proven idempotency | Production strategy plus active discovery and safe projection | Modify | High |
| Journey/attempt/wave domains | Strong operational aggregate/revisions | Preserve; add projection and cancellation orchestration | Reuse/modify | Medium |
| Matching engine | Lease-safe but manually invoked/dev-only | Scheduled production workers/readiness/dead-letter operations | Modify | High—availability |
| Offer/hold/capacity | Modern endpoints, fences, recovery | Production authorization/config/audit | Reuse/modify | Medium |
| Selection | Strong single-commit transaction | Production gate/audit/additive DTO | Reuse/modify | Medium |
| Commitment | Minimal ACTIVE/CANCELLED/INVALIDATED | Dispatch/handoff phases, patient projection, commands | Modify | High—responsibility |
| Cancellation/rebroadcast | Domain transition fragments only | One serialized matrix service and APIs | New | High—races |
| Travel/location/ETA | Absent | Start command, ephemeral relay, tracking projection, privacy/retention | New | High |
| Arrival/handoff | Absent | Arrival fact, intent/outbox, fences, P4/P5 transfer | New | Critical |
| QR/grant | Older Module 04 conflicts; P4 has none | ADR-005 P5 challenge and scoped grant | P5 new/modify | Critical |
| Consultation source | Adapter always rejects; finish cannot release HOME | Enable only after transfer; add finish/source callback | Modify | Critical |
| Realtime | Durable fake generation/no I/O | Real STOMP publisher, scheduler, health | Modify | Medium |
| Push | Durable dry run/no external FCM | Real provider adapter, tokens, scheduler, health | Modify | High—urgent delivery |
| Audit | Protected-data operations only | Full Tier 1/2/3 event catalog and fail-closed rules | Modify | Critical |
| Observability | Partial bounded metrics | Production dashboards/alerts/runbooks and capability health | Modify | Medium |
| Retention | Policy keys/provisional receipt duration | Legal/DPO periods, deletion/crypto-shred workers | New/modify | Critical compliance |
| Contract tests | Broad development tests | Production-profile, P4/P5, mobile consumer fixtures | New | High |

Governance prerequisite complete: Module 04 Amendment v1.2 records the approved lifecycle projection, P4/P5 ownership, travel scope, cancellation/rebroadcast rules, retention policy abstraction, and precedence over conflicting older QR/MRS language.

Approved backend implementation order:

1. Freeze OpenAPI schemas, state/action/error catalogs, contract fixtures, and production capability/version.
2. Implement protected production intake, active recovery, cancellation, lifecycle audit, and production startup validators.
3. Productionize matching/recovery scheduling and operational health without changing lease semantics.
4. Certify existing offer/selection/commitment paths; add dispatch phase and cancellation/rebroadcast.
5. Implement travel/latest-location/ETA with approved privacy and retention.
6. Implement P4 arrival, durable handoff intent, fencing, admission transfer, and reconciliation.
7. Implement P5 ADR-005 challenge, verification, scoped grant, MRS context and HOME consultation source/finish convergence.
8. Enable real realtime and FCM adapters with REST-authoritative client behavior.
9. Execute production-profile, multi-instance, P4/P5 integration, security, failure, and Flutter consumer-contract gates before enabling the capability.

### Required backend tests before Flutter Phase 1B

- Domain transition tests for every journey/attempt/wave/offer/commitment/dispatch/handoff state and forbidden edge.
- WebMvc/security tests for PATIENT, owned family subject, wrong account, DOCTOR ownership, support privilege, and internal service identity on every endpoint.
- Production-profile startup tests proving synthetic intake, fake realtime, dry-run push, local keys, missing retention policy, missing worker, and incomplete P5 capability cannot activate.
- Submission idempotency tests: lost response, exact replay, changed payload conflict, concurrent same key, receipt expiry policy, active-subject race, and normalized encrypted-payload fingerprint.
- Recovery tests for key only, journey ID only, neither identifier, app opened after hours, account/family switch, notification launch, and terminal receipt.
- Protected-data tests for encryption/wrapping rotation, purpose-bound decrypt, KMS failure, two-phase audit interruption, crypto-shred and no plaintext in logs/database projections.
- Matching tests for first-wave atomicity, radius expansion, deadline, zero Doctors, all decline/expire, dependency failure, retry exhaustion, stale lease, stale epoch, and recovery-required.
- Multi-instance tests proving two scheduled workers cannot complete/issue the same wave, offer, hold-expiry, realtime, push, deletion, or handoff job twice.
- Offer races: accept/decline/expire/withdraw/suspend/capacity conflicts and command replay.
- Selection races: two selected offers, stale attempt revision, hold expiry, professional suspension, duplicate key, and capacity promotion rollback.
- Cancellation-matrix tests including cancel versus accept, selection, travel, arrival, and `prepare-transfer`; same-journey rebroadcast and no duplicate active journey.
- Travel tests for authorization, stale/out-of-order/impossible GPS, rate limiting, TTL/staleness, cancellation, background stop, ETA failure and zero route history.
- ADR-005 tests for signing/key rotation, nonce expiry, atomic one-use, screenshot replay, wrong Doctor/subject/commitment, revoked intent, clock skew and audit failure.
- P4/P5 contract tests for duplicate/out-of-order intents and callbacks, cancellation fence precedence, P5 outage before/after transfer, grant failure, admission fencing and reconciliation.
- Consultation tests enabling HOME only after verified transfer, start replay, active-consultation conflict, MRS/audit failure, finish checkpoint replay, source release, grant revoke and P4 completion callback.
- Realtime/push tests for opaque schema, recipient ownership, actionability recheck, duplicate/out-of-order/gap, reconnect REST resync, provider retry/dead-letter, token rotation and PHI-free templates.
- Audit/log/metric tests proving prohibited health, address, GPS, identity, QR, token and high-cardinality labels never leave their boundaries.
- Flutter consumer-contract fixtures for submit/status/recovery/active, accepted Doctors, selection, commitment/tracking, cancellation, handoff and all stable errors/actions.
- Backend-connected release-like journey proving a real protected submission, scheduled matching, Doctor receipt/acceptance, Patient selection, travel, arrival, P5 verification, canonical consultation and completion.

No existing test result certifies this future contract. These tests are acceptance requirements, not claims of execution.

### Certification decision

**HISTORICAL CERTIFICATION — CTO DECISIONS APPROVED; CONTINUATION NOW DEFERRED**

Module 04 Amendment v1.2 resolves the architecture conflict and locks Model C, the P4/P5 ownership boundary, dispatch/handoff phases, Phase 1 travel, serialized cancellation/rebroadcast, ADR-005 check-in, the single P5 consultation system, REST-authoritative realtime, protected intake, retention gating, configurable matching policy, and the explicit production capability/version.

This certification authorized the contract fixtures and protected production foundation that are now complete in Backend B1. It is retained as historical evidence and does not authorize B2-B8, production activation, or Flutter Phase 1B under the current launch scope.

Remaining approvals and production gates are:

1. Legal/DPO approval of exact retention durations, legal-hold rules, backup behavior, and deletion evidence for every required policy key.
2. Clinical/product approval of body-area/free-text rules, matching/hold/expiry/cancellation values, fee/compensation policy, rate limits, and required notification behavior.
3. P5/MRS owner schema and operational-recovery sign-off for verification, grants, source actionability, completion, and handoff messages.
4. Security/operations acceptance of key management, service identity, FCM/APNs credentials, monitoring, and runbooks before production enablement.

The current Flutter fail-closed boundary is the required production behavior for this launch. Backend production HOME capability remains disabled regardless of future prerequisite availability until an explicit CTO/product scope decision resumes the feature.

This certification performed no backend implementation, changed no Flutter source or UI/UX, and used no Git write operation.

## Backend Phase B1 — Contract Foundation + Protected Intake

**Implementation date:** 2026-11-09  
**Status:** **COMPLETE / DORMANT**

B1 implements the backend-only foundation authorized by Module 04 v1.2. Its implementation is retained, but production activation remains disabled. Legal/DPO/key-provider prerequisites remain unresolved, and satisfying them would not itself authorize activation. B1 does not activate scheduled matching, travel, arrival/handoff, QR/grants, P5 consultation, realtime, push, or Flutter Phase 1B. This dormant state is an acceptance property, not a synthetic fallback.

| Work item | STATUS | FILES | TESTS | EVIDENCE | REMAINING RISK | NEXT DEPENDENCY |
|---|---|---|---|---|---|---|
| Contract version and capability | COMPLETE | `HomeProductionProperties`, `HomeProductionCapabilityService`, `MePatientHomeCapabilityController`, `HomeProductionCapabilityResponse` | `HomeB1ContractFixtureTest`; `HomeProductionStartupValidatorTest` | Contract version is exactly `1`; capability returns no future-phase readiness; disabled capability returns no supported states/actions. | Operational activation still needs certified external configuration. | Security/operations supplies the certified key provider and approved deployment values. |
| Frozen request/response contract | COMPLETE | `HomeSubmissionRequest`, `HomeTriageRequest`, `HomeSubmissionResponse`, `HomeJourneyStatusResponse`, cancellation DTOs | `HomeB1ContractFixtureTest`; submission WebMvc tests | Strict nested triage/destination shape; unknown authority fields rejected; responses expose only opaque IDs, revisions, safe states/actions, deadlines, replay and evaluation time. | OpenAPI generation is not configured in this repository; checked-in machine fixtures are the authority. | Flutter consumer tests may consume these fixtures only after backend production activation certification. |
| Subject authority | COMPLETE | Existing `CareSubjectResolver`; `HomeSubmissionService`; `HomeSubmissionRecoveryService`; `HomeCancellationWriter` | PostgreSQL ownership/family-revocation tests; WebMvc role tests | SELF and owned family subjects remain server-resolved; status, recovery, active discovery and cancellation revalidate current ownership; foreign reads are non-enumerating. | None within B1. | Preserve this resolver in B2 and later endpoints. |
| Protected intake preparation | COMPLETE | `ProtectedHomeIntakePreparer`, `PreparedProtectedHomeIntake`, `ProtectedHomeIntakeException`, existing P4 envelope cryptography/audit interfaces | `P4EnvelopeEncryptionTest`; `P4ProtectedIntakeStartupValidatorTest`; PostgreSQL protected-writer test | Clinical and exact-destination payloads use independent purposes/AAD bindings; remote key preparation happens before the database-locking writer transaction; plaintext key material is zeroed. | No production-certified provider is checked in, by design. | Deploy an approved provider before enabling capability. |
| Protected intake transaction | COMPLETE | `ProtectedHomeSubmissionWriter`, `ProtectedHomeIntakeBindingStore`, `HomeMatchingWaveCoordinator.startProtected` | `HomePatientSubmissionPostgresIntegrationTest` | One transaction creates journey, attempt, protected references, initial pending wave, receipt, protected audit completion and lifecycle audit. It creates no Doctor offer and invokes no discovery worker. | External KMS latency/availability still needs staging evidence. | B2 owns scheduled discovery after this committed boundary. |
| Data minimization and P4/P5 boundary | COMPLETE | Migration `0532`; protected writer/binding store | PostgreSQL protected-writer and no-side-effects tests; architecture boundary test | Operational binding table stores only envelope IDs, provenance category, share intent and version metadata; no narrative, address, coordinates, MRS write or grant creation. | Legal retention/deletion execution remains outside B1. | Retention worker/policy approval and later P5 handoff phases. |
| Submission idempotency | COMPLETE | `ProductionHomeSubmissionFingerprint`, `UrgentCommandReceipts`, production branch of `HomeSubmissionService` | PostgreSQL replay/conflict/concurrent-active-subject tests; recovery unit tests | Secret-backed HMAC fingerprint stores no raw payload; exact replay returns original resource, changed payload conflicts, same-key races serialize, and active-subject uniqueness prevents a second journey. | Multi-instance load evidence remains a B2/release concern. | B2 multi-instance worker and command-pressure validation. |
| Status read | COMPLETE | `HomeSubmissionService.status`; controller `GET /journeys/{journeyId}` | PostgreSQL owner/foreign/family-revocation tests; WebMvc tests | Actor ownership is revalidated, response is a safe projection, and response headers are private/no-store. | None within B1. | Future phases add states only through the projection mapper. |
| Recovery by idempotency key | COMPLETE | `HomeSubmissionRecoveryService`; recovery controller | `HomeSubmissionRecoveryServiceTest`; recovery WebMvc/security tests; PostgreSQL response-loss test | Account-scoped read performs no submission; returns the completed projection with `replayed=true`; rate limit is bounded; an active journey remains recoverable despite nominal receipt expiry. | Final legal receipt duration is not approved. | Legal/DPO retention decision. |
| Active journey discovery | COMPLETE | `HomeSubmissionService.active`; `GET /journeys/active` | PostgreSQL active-subject and ownership tests; contract fixture | Server-resolved subject yields at most one safe projection; no-active returns `204`; no patient/MRS identifier is accepted. | Dedicated endpoint WebMvc permutations can be expanded with the future Flutter consumer suite. | Flutter Phase 1B consumer integration after backend activation certification. |
| Pre-transfer cancellation | COMPLETE | `HomeCancellationService`, `HomeCancellationWriter`, `HomeCancellationStore`, `HomeMatchingWaveStore.cancelCurrent`, cancellation DTOs/reasons | `HomeCancellationWriterTest`; PostgreSQL cancellation transaction test; cancellation fixtures | PATIENT-owned HOME_CREATED/HOME_MATCHING/HOME_HELD cancellation is revision-fenced and idempotent; current wave closes; database triggers close offers/holds and release capacity; HOME_COMMITTED/future states fail closed. | Full cancellation-versus-worker/selection stress belongs to B2 and later transfer fencing. | B2 matching race matrix; later handoff cancellation matrix. |
| Product projection and actions | COMPLETE | `HomeProductProjectionMapper`, `HomeReadProjection`, `HomeProductState`, `HomeAvailableAction` | `HomeProductProjectionMapperTest`; fixture catalog test | Internal aggregates remain canonical. Only PENDING, BROADCASTING, PARTIALLY_ACCEPTED, DOCTOR_SELECTED, CANCELLED and MATCHING_EXHAUSTED are exposed; no travel/arrival/consultation/completion state is fabricated. | PARTIALLY_ACCEPTED/DOCTOR_SELECTED become reachable only through later certified phases. | B2 offer/matching certification. |
| Stable error catalog | COMPLETE | `CareCapabilityErrorCode`, `CareCapabilityProblemDetailHandler` existing safe mapper | Contract fixture and WebMvc validation/security tests | B1 validation, triage, destination, active conflict, idempotency, recovery, protected-intake, cancellation and transient codes are machine catalogued; platform `UNAUTHORIZED`/`FORBIDDEN` semantics are preserved. | Future phase codes remain intentionally absent. | Add only phase-owned errors when their authority exists. |
| Lifecycle/protected audit | COMPLETE | `HomeLifecycleAudit`; additions to `AuditEventType`; existing `P4ProtectedDataAudit` | Protected audit PostgreSQL test; protected architecture/startup tests; cancellation/submission transaction tests | Submission, subject failure, status, recovery, active discovery and cancellation events are mapped; envelope operations retain attempted/completed/failed two-phase audit; metadata is limited to opaque IDs/outcomes. | Production audit sink outage behavior still needs environment validation. | Operations staging failure injection. |
| Retention abstraction | COMPLETE | `HomeRetentionPolicyKey`, `HomeProductionProperties`, protected binding metadata | Startup-validator tests | Required keys are P4_TRIAGE, P4_EXACT_LOCATION, P4_IDEMPOTENCY, P4_OFFER, P4_NOTIFICATION and AUDIT; no production duration was invented; missing/zero values block startup. | Exact durations and legal-hold/backup rules remain unapproved. | Legal/DPO approval. |
| Production startup gate | COMPLETE | `HomeProductionStartupValidator`, `HomeIntakeModePolicy`, `application.yaml`, `application-prod.yaml`, existing P4 validator | `HomeProductionStartupValidatorTest`; `P4ProtectedIntakeStartupValidatorTest`; `HomeIntakeStartupValidatorTest` | Rejects incompatible version, synthetic latches, wrong mode, missing retention, short/invalid HMAC, missing/ambiguous certified provider, audit/store/recovery/cancellation dependency, or missing schema. Future components are not required. | A real production profile cannot yet start with HOME enabled because no certified provider or approved policy values are present. | Supply external prerequisites; do not weaken validator. |
| Synthetic isolation | COMPLETE | `HomeIntakeModePolicy`; `P4ProtectedIntakeMode.PROTECTED_PRODUCTION`; prod configuration | `HomeIntakeAccessPolicyTest`; startup-validator tests; protected PostgreSQL persistence test | Production and synthetic strategies are mutually exclusive; production writer never calls plaintext stores; prod config keeps synthetic authorization/latches false. | None within B1. | Preserve isolation in B2 scheduling. |
| Liquibase and database constraints | COMPLETE | `0532-p4-home-production-intake-b1.yaml`; master changelog include | PostgreSQL 17.8 integration suite; Liquibase startup validation | Additive tables, named FKs/checks/uniques/indexes; migration applied and subsequent validation reported database current with 200 changesets. | Migration was validated on the configured development PostgreSQL, not a production clone. | Repeat on staging backup/restore rehearsal before activation. |
| Contract fixtures | COMPLETE | `src/test/resources/contracts/urgent-home/b1/*` | `HomeB1ContractFixtureTest` | Separate fixtures cover submit request/response, status, active discovery, recovery, cancellation, capability/version, product states, actions and ProblemDetail codes; forbidden future states/identities are asserted absent. | Flutter has not consumed them yet and remains fail-closed. | Flutter Phase 1B only after backend capability is operationally certified. |

### B1 validation record

- `./mvnw -q -DskipTests compile` — passed.
- `./mvnw -q -DskipTests test-compile` — passed.
- Focused B1 contract/projection/startup/cancellation/validation/recovery, WebMvc security, synthetic-isolation, protected-encryption and architecture-boundary suite — passed with exit 0.
- `HomePatientSubmissionPostgresIntegrationTest` on PostgreSQL 17.8 — **17 passed, 0 failed, 0 errors**. This includes real protected-writer and cancellation transactions, replay/concurrency/ownership/recovery checks, no synthetic or MRS side effects, protected audit, and migration evidence.
- Liquibase — B1 changeset applied; final validation reported the configured database current with 200 previously applied changesets.
- `git diff --check` is part of the final hygiene gate recorded with the implementation handoff.

### B1 exit decision

**COMPLETE / DORMANT.** The B1 code and database boundary satisfy the approved implementation exit criteria. The production capability remains intentionally disabled. Security/operations has not supplied the required production-certified purpose-separated key provider, and Legal/DPO has not supplied explicit retention values. B1 must remain unreachable from current production Flutter.

Backend Phase B2 and all later Urgent HOME phases are **DEFERRED — resume only through explicit CTO/product scope decision**. Do not begin scheduled matching/recovery productionization or operational-health activation. Do not enable travel/location, arrival/handoff, QR/grants, consultation, realtime, push, or Flutter Phase 1B, and do not weaken the B1 capability/startup gate.
