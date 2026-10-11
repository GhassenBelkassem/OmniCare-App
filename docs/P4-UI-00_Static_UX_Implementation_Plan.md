# P4-UI-00 — Static UX Implementation Plan

**Authorization:** Planning only. This document does not authorize Flutter or backend implementation.

**Data rule:** Use synthetic fixtures only until the P4 backend and privacy projections are separately approved and certified.

## 1. KEEP / REUSE / REPAIR / REPLACE

| Decision | Flutter components / behavior |
|---|---|
| KEEP | OmniCare theme and shells; explicit Patient choice; Patient-controlled Doctor selection/retry; HOME/CABINET visual distinction; emergency safety messaging; P4 ending at `CLINICAL_HANDOFF_PENDING` |
| REUSE | Mode cards and illustrations; `CareSubjectCard`; add-family presentation; body map and pain control; location gateways/permission recovery; Patient review/edit shell; matching animation and Doctor cards; directory/list/detail visual primitives; Doctor urgent cards; map fallback; reduced-motion and responsive patterns |
| REPAIR | Subject selection model; triage field set/copy; exact-location draft boundary; candidate fee/hold/expiry display; cancellation/recovery states; Doctor offer projection; availability/admission states; navigation quality/reconnect; localization, semantics and privacy-safe notifications |
| REPLACE | Raw `Map<String, dynamic>` urgent state; arbitrary Doctor-ID selection; `ReviewConfirmScreen` legacy consultation submission; timer-driven Doctor calling/arrival; scheduled-care CABINET continuation; P4 Patient QR; P4 Doctor QR-to-medical-record flow |
| DO NOT WIRE | Legacy urgent/consultation endpoints, scheduled-care request endpoints for P4 CABINET, MRS or medical-record access, production push/realtime, real Patient/Doctor/location/clinical data |

## 2. Proposed static architecture

The first static implementation should introduce a UI-only, typed projection layer. It is not a backend DTO and must not encode unapproved production timing defaults.

```text
SyntheticUrgentJourneyFixtureSource
  -> UrgentJourneyUiProjection
       journeyRef
       authorizedAccountRole
       subjectDisplayProjection
       activeAttempt
       linkedAttemptSummaries
       availablePatientCommands
       safeFailure

UrgentAttemptUiProjection
  -> immutable mode: HOME | CABINET
  -> attemptRef + version
  -> stage
  -> structuredTriageProjection
  -> HOME: destination draft / epoch / live holds / commitment / route quality
  -> CABINET: directory target / response / commitment / recovery choices
  -> fee quote: amountMinor + currency + feeVersion
```

Command buttons consume only commands allowed by the current synthetic projection. Static transitions return a new versioned projection. They must never infer authority from a timer, local switch, navigation history, canonical-subject equality or realtime event.

K and TTL values belong to named fixture policies. `K=2 / TTL=120` may be one development fixture, not a constant or production default.

## 3. Priority plan

### P0 — containment in the static design

Before extending the urgent UI:

1. Declare `ReviewConfirmScreen`, `DoctorCallingScreen`, `DoctorArrivingScreen` dev-completion behavior, `ConsultationQRScreen` and the Doctor QR-to-record flow prohibited P4 continuations.
2. Keep P4 synthetic routes unable to resolve or instantiate `ConsultationsApi`, scheduled-care submission repositories, MRS/medical-record screens, push publishers or production realtime.
3. Add test guards that fail if the new P4 coordinator imports those dependencies.
4. Use only synthetic identities, addresses, fees, triage codes and coordinates clearly marked as fixtures.

### P1 — typed journey foundation

1. Add immutable UI types for journey, attempt, actor projection, subject selection, structured triage, destination, fee quote, offer, hold, commitment, recovery and safe failure.
2. Add a UI-only state coordinator with deterministic HOME and CABINET scenario fixtures.
3. Establish one route owner and remove new dependence on duplicated named-route map casting.
4. Cover restart/reconnect by rehydrating a fixture projection rather than replaying local actions.
5. Encode errata UI-E1 through UI-E4 in type invariants and tests.

### P2 — Patient HOME static flow

1. Migrate mode, subject, triage, destination and review screens to the typed coordinator while preserving approved visuals.
2. Add matching epochs, actual-live-choice count, bounded holds, expiry, fee display, selection submission/conflict and wave/retry/cancel/fallback states.
3. Replace legacy confirmation with live-hold and immutable-quote confirmation.
4. Add committed/en-route states with GPS quality, stale/degraded/reconnect/cancel behavior.
5. End at `CLINICAL_HANDOFF_PENDING`; expose no QR, grant, MRS or consultation-complete action.

### P3 — Patient CABINET static flow

1. Reuse directory presentation with a synthetic urgent source filtered to urgent CABINET capability.
2. Add target confirmation and urgent CABINET quote before attempt creation.
3. Add awaiting, accepted, declined, unavailable, expired and network-uncertain states.
4. Offer explicit choose-another, HOME fallback and cancel commands; never auto-assign.
5. Stop before CABINET arrival/no-show and show the blocked contract state.

### P4 — Doctor urgent static operations

1. Add HOME/CABINET offer variants and approved pre-commit projections.
2. Add shared-admission UI states, fail-closed dependency state, capacity conflicts, clinical busy, post-handoff unavailable and explicit reactivation.
3. Add HOME hold acceptance/expiry and “Patient selected another Doctor” recovery.
4. Add fenced commitment, route quality, cancellation/revocation and reconnect states.
5. Replace QR/medical record with handoff pending and responsibility-transfer status.

### P5 — quality and certification preparation

1. Localize every urgent string through app localization for English, French and Arabic; verify RTL.
2. Add semantics/live-region strategy for time-sensitive states.
3. Test 320–430px widths, tablets, landscape, text scaling, keyboard, screen reader, reduced motion and high contrast.
4. Add golden/state-matrix tests and dependency-boundary tests.
5. Obtain clinical/privacy copy approval for safety and D6 projection fields before any integration task.

## 4. Required synthetic scenario catalogue

| Scenario | Required fixture outcomes |
|---|---|
| HOME happy path | two accepted live holds, visible quotes, explicit selection, sibling release, commitment, en route, arrival, handoff pending |
| HOME exact-expiry race | selected hold expires at server boundary; generic conflict; refetch leaves valid choices or recovery |
| HOME changing choices | hold appears, expires/withdraws before decision; actual choice count updates without historical inflation |
| HOME no response | waves expand, search remains safe, Patient chooses rematch/CABINET/cancel |
| HOME cancellation | pre-commit cancel; committed cancel pending; Doctor withdrawal; stale callback ignored |
| HOME location degradation | permission denied, low accuracy, stale telemetry, map unavailable, reconnect |
| CABINET accept | Patient target + quote, Doctor accepts, commitment shown |
| CABINET recovery | decline, unavailable, expiry and capacity conflict each notify Patient and require explicit next choice |
| CABINET fallback | new HOME attempt linked to same journey; CABINET attempt remains immutable/terminal |
| Subject access | SELF, family, cross-account-equivalent-but-not-owned, ownership changed, active journey conflict |
| Doctor admission | available, HOME hold, HOME/CABINET commitment, P5 busy, dependency unavailable, post-handoff unavailable, explicit reactivation |
| Handoff | arrival recorded, pending, transfer delayed, callback replay, cancellation wins/loses, P5 transfer complete; no MRS data |

## 5. Focused static test plan

### Contract and privacy tests

- A HOME attempt cannot change mode; fallback creates a new linked CABINET attempt.
- CABINET target selection precedes Doctor acceptance.
- An equivalent canonical subject owned by another account remains non-enumerable and inaccessible.
- HOME selection requires a currently live accepted `holdId`; Doctor ID alone is rejected by the coordinator.
- Offered/accepted-unselected Doctor widgets contain no Patient name, exact address/GPS, free text, voice, family relation or peer offers.
- Candidate and target cards show amount, ISO currency and fee version before the Patient command.
- Patient candidate fixtures contain no raw Doctor availability coordinate.
- CABINET Doctor fixtures contain no HOME destination or Patient location.
- P4 route graph cannot open QR grant, medical record or consultation completion.

### State and race presentation tests

- Expiry at the selection boundary removes the hold and renders safe recovery.
- Stale versions/events never advance the UI; a refetched projection wins.
- Duplicate taps produce one in-flight command and one rendered result.
- Cancellation, Doctor withdrawal and commitment callbacks render according to the newest projection version.
- Admission dependency uncertainty disables accept/reactivate and explains safe retry.
- Post-handoff unavailability remains until an explicit permitted reactivation result.
- Process-restart fixtures reconstruct current state without revealing previously revoked data.

### Quality tests

- No overflow across supported phone/tablet dimensions and 2.0x text scale.
- Screen-reader labels announce mode, fee, expiry and state without hidden sensitive fields.
- Reduced motion removes nonessential radar/pulse animation.
- English, French and Arabic copy fits; RTL ordering is correct.
- Offline, empty, expired, stale, degraded and permission-denied states retain an accessible next action.

## 6. Dependencies and release gates

| Dependency | Needed for static implementation | Needed before integration/release |
|---|---:|---:|
| Final P4 state/command vocabulary | Yes | Yes |
| D6 structured triage and contact allowlists | Safe placeholders can be used | Required |
| Urgent HOME/CABINET fee DTO contract | Shape required; synthetic values | Required |
| Server-time/hold-expiry semantics | Shape required | Required and PostgreSQL certified |
| Canonical-subject authorization projection | Synthetic cases | Required |
| Geolocation precision/TTL/sparse-area values | Named placeholders | Required |
| CABINET arrival/no-show mechanism | No; keep blocked | Required to continue past commitment |
| P5 handoff/grant protocol | Handoff-pending fixtures only | Required; P5-owned implementation |
| KMS/TLS/retention/legal approvals | No capability claims in static UI | Required for production integration |

## 7. Exact next implementation task

**P4-UI-01A — Typed Synthetic Urgent Journey Foundation and Safe Route Cutover**

Implement a Flutter-only, API-free foundation that:

1. defines immutable typed UI projections for journey, attempt, subject, triage, HOME destination, fee, offer, hold, commitment and recovery;
2. provides deterministic synthetic HOME and CABINET fixtures, including expired/offline/stale/conflict states;
3. establishes one P4 route coordinator and migrates only entry, explicit subject choice and mode-specific continuation to it;
4. prevents the new P4 route from reaching `ConsultationsApi`, scheduled-care submission, QR/grant, medical-record or MRS code;
5. includes contract tests for UI-E1 through UI-E4 and dependency-boundary tests;
6. preserves current visuals and does not wire any production API.

Do not begin matching, commitment or navigation API integration in P4-UI-01A. Its acceptance criterion is a typed, synthetic, privacy-safe route foundation on which the later static screens can be built without inheriting the legacy flow.
