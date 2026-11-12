# Phase 1 — Clinical Correctness Safety Mitigation

Date: 2026-11-08  
Status: **IMPLEMENTED AND VERIFIED — PHASE 1 REMAINS BLOCKED ON THE PRODUCTION URGENT-HOME CONTRACT**

## Outcome

The production entrypoint can no longer display a fabricated urgent HOME
request, clinician assignment, consultation, clinic request, reservation, or
appointment confirmation from the audited legacy synthetic flows.

Unsupported clinical actions now terminate at a neutral fail-closed screen that
states explicitly that no request, reservation, or consultation was created.
The screen receives no clinical route payload and performs no network mutation.

This is a safety mitigation, not an authoritative urgent-HOME implementation.
The Phase 1A investigation in the roadmap remains the source of truth for the
missing backend/product/security contract and the requirements for a later
Phase 1B.

## Backend contract decision

The backend `/api/v1/me/urgent-home/journeys` family is explicitly classified
by its own P4-07 record as synthetic-development-only. Production activation is
blocked because the approved protected intake/location persistence, worker
activation, realtime delivery, arrival/check-in, and actionable consultation
source contracts do not exist end to end.

The Flutter client therefore does not connect the legacy urgent HOME UI to
those endpoints. A development seam is not valid authority for real patient
traffic.

## Production reachability closure

| Previous production-reachable path | Safety issue | Mitigation |
|---|---|---|
| Emergency review -> Doctor matching -> confirmation -> calling/arrival/QR/completion | Demo Doctors, timer-driven assignment and synthetic `ConsultationsApi` success | Review routes to the fail-closed screen. Legacy route names resolve to that screen. Unsafe screens are no longer imported by either production route graph. |
| Legacy provider list -> time selection -> `ReservationProvider` | Default repository called `useMock()` and returned fabricated reservation success | Provider registration removed from `main.dart`; legacy submission/result routes fail closed. |
| `/clinic-request` | Timer-only submission displayed “Demande envoyée” without a backend write | Production route resolves to the fail-closed screen. |
| Appointment confirmation -> booking confirmed | Hard-coded slots and local success navigation | Both production route names resolve to the fail-closed screen. |
| Authoritative Doctor HOME workspace -> legacy QR subtree | Shell-created legacy controller exposed `DoctorUrgentRequest.demo` patient data | Authoritative workspaces return the backend workspace directly and do not mount the legacy HOME QR/medical-record subtree or expose its callback. |
| Direct `DoctorSelectionScreen` construction | Optional source silently defaulted to `DemoDoctorMatchingSource` | `matchingSource` is required. No screen-level fallback can start demo matching accidentally. |

Stale compatibility route names ignore all arguments. Malformed or PHI-bearing
legacy payloads are not cast, rendered, logged, or forwarded to the unavailable
screen.

## Preserved authoritative paths

- Module 05 request submission remains on the shared authenticated client,
  repository, stable operation identity and backend reconciliation.
- Patient scheduled care remains on `PatientBookingController` and
  `ScheduledCareRepository`.
- Patient and Doctor urgent CABINET remain backend-backed.
- Doctor urgent HOME offer, presence, commitment and dispatch reads remain
  backend-backed and available according to server capability/configuration.
- Canonical Doctor consultations continue to use UUID identity, clinical
  record, prescription/order/artifact APIs and idempotent finish. The old
  noncanonical `ConsultationsApi` screens are not production routes.

## Security, reliability and performance

- No endpoint, feature-local client, dependency, cache, polling, retry, or
  persistent state was added.
- No synthetic success was replaced with optimistic local success.
- Unsupported actions are O(1) route transitions with no network or database
  operation.
- Existing backend authorization and object-level access checks are unchanged.
- Rollback must keep these workflows disabled; restoring synthetic routes is
  not an acceptable rollback.

## Executable boundary

`test/phase1_clinical_correctness_boundary_test.dart` verifies that production
route graphs do not construct the disconnected outcome screens, the mock
reservation composition is absent, urgent review drops its intake payload at
the fail-closed boundary, legacy matching requires explicit source injection,
and authoritative Doctor workspaces cannot mount the legacy HOME simulation.

## Validation

| Validation | Result |
|---|---|
| Focused boundary/review/matching/Doctor-shell tests | 23 passed, 0 failed |
| Expanded `PHASE_1_SAFETY_SUITE` | 206 passed, 7 intentionally skipped, 0 failed; 44 seconds |
| Complete bounded Flutter suite | 1,624 passed, 7 intentionally skipped, 0 failed; 4 minutes 24 seconds |
| `flutter analyze --no-pub` | 389 findings: 0 errors, 31 warnings, 358 infos; exact approved baseline |

The complete suite used a ten-minute process bound and 60-second per-test
timeout. No test was deleted or newly skipped.

## Remaining Phase 1 blocker

Phase 1B cannot begin until backend/product/security owners approve and provide
the production contract enumerated by Phase 1A. After that implementation,
Phase 1 still requires a release-like Android/iOS urgent-HOME journey with
captured network traffic, backend record/clinician evidence, and a negative
backend-unavailable test before `PHASE_1_COMPLETE` may be declared.

