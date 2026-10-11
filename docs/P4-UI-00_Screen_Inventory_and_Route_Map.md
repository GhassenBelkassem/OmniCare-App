# P4-UI-00 — Screen Inventory and Route Map

**Milestone:** Static UX inspection and gap assessment

**Inspection date:** 2026-10-10

**Scope:** Flutter Patient and Doctor urgent-care UI only

**Change boundary:** Documentation only; no Flutter, backend, Liquibase, MRS, Angular or deployment change

## 1. Evidence convention

- **VERIFIED** means the behavior is present in inspected Flutter source or an existing widget test.
- **PROPOSED** means required by the approved P4/P4-01E/P4-02 contracts but not implemented or certified in Flutter.
- Existing widget tests were inspected as implementation evidence. They were not treated as proof of backend, authorization, concurrency, privacy or production behavior.
- No screen was connected, launched against an API, or populated with live Patient data during this inspection.

## 2. Actual route map

### 2.1 Patient HOME route as implemented

```text
Patient home
  -> /emergency-step0                 mode choice
  -> /emergency-step1                 SELF / family selection
  -> /emergency-step2                 body map, pain, narrative
  -> /emergency-step3                 exact HOME destination
  -> /emergency-review                Patient-owned review
  -> /doctor-selection                synthetic accepted-Doctor list
  -> /review-confirm                  legacy consultation creation + payment choice
  -> /doctor-calling                  legacy polling + timed auto-navigation
  -> /doctor-arriving                 synthetic countdown + dev completion
  -> /consultation-qr                 Patient-identifying QR + dev completion
  -> /consultation-complete            post-consultation UI
```

The route chain is registered twice: globally in `lib/main.dart:321-429` and inside the Patient nested navigator in `lib/features/home/new_home_screen.dart:345-432`. Both branches pass mutable `Map<String, dynamic>` payloads.

The chain is not one coherent P4 journey. The first screens are reusable static collection UI, matching is synthetic, and the screens after Doctor choice call the legacy consultation API or enter P5-owned clinical behavior.

### 2.2 Patient CABINET route as implemented

```text
/emergency-step0
  -> /doctor/cabinet/who-needs-care
  -> DoctorCabinetEntryScreen
  -> WhoNeedsCareScreen(RequestKind.doctor, cabinetNewPatient)
  -> DoctorDirectoryScreen(scheduledBookingWorkflow: true)
  -> DoctorDetailScreen
  -> cabinet availability / slot selection
  -> scheduled booking request/review/status
```

This is a scheduled-care booking flow, not the approved P4 urgent CABINET flow. It selects a subject, queries the production Doctor directory, fetches availability slots and creates a scheduled request. It has no targeted urgent attempt, Doctor accept/decline, shared urgent capacity claim, failure notification or Patient-controlled retry.

### 2.3 Doctor route as implemented

```text
DoctorAppShell / Urgences tab
  offline
  -> available
  -> offerReceived
  -> acceptedWaitingPatient
  -> selected
  -> enRoute
  -> arrived
  -> DoctorUrgentQrScannerScreen
  -> DoctorMedicalRecordScreen(fullDemo)
```

The controller is an in-memory `ChangeNotifier` with timers and a single synthetic HOME request (`doctor_urgent_controller.dart:5-133`). The Doctor shell retains it while navigating tabs (`doctor_app_shell.dart:48-60,138-177`), which is a useful static interaction pattern but not authoritative journey recovery.

## 3. Patient screen inventory

| Screen / source | EXISTING and working static functionality | INCOMPLETE, WRONG or obsolete | SECURITY / PRIVACY mismatch | Reuse and required action |
|---|---|---|---|---|
| Urgent entry / `EmergencyRequestStep0` | Two polished mode cards, close action and responsive scrolling (`emergency_request_step0.dart:6-87`). | CABINET copy says “make an appointment” and routes to scheduled care. No active-journey resume, safety context or linked-fallback presentation. | No direct disclosure issue on this screen. Route choice does not establish an attempt-scoped immutable mode. | **REUSE** layout, cards and illustrations. **REPAIR** copy and route into a synthetic P4 journey coordinator; show HOME and urgent CABINET as attempt modes. |
| HOME subject / `EmergencyRequestStep1` | Explicit SELF/family choice; Continue disabled until selection; add-family flow; edit-from-review behavior; scrolling and form-error tests (`emergency_request_step1_test.dart`). | Uses legacy `patientType` strings and passes raw `patientId`, `backendPatientId`, name, age and relationship in route maps (`emergency_request_step1.dart:90-134`). No active-journey collision, inaccessible subject or ownership-change state. | A client-carried backend Patient ID cannot establish canonical subject or access. Cross-account canonical equivalence cannot confer journey visibility. | **REUSE** cards and explicit-selection interaction. **REPLACE** payload with a typed opaque subject selection and server-resolved access state in a later integration milestone. Add loading/empty/error/revoked/ownership-changed states. |
| CABINET subject / `WhoNeedsCareScreen` | Reuses family profiles and add-family UI (`who_needs_care_screen.dart:18-51,125-217`). | `null` represents SELF and initial state, so Continue defaults to SELF without an explicit choice. It immediately prepares scheduled care and directory navigation (`who_needs_care_screen.dart:54-122`). | Same canonical-subject and access caveat as HOME; scheduled realtime is unrelated to P4. | **REUSE** profile grid only. **REPAIR** explicit selection semantics. Do not reuse scheduled-care controller behavior for urgent CABINET. |
| Structured triage / `EmergencyRequestStep2` | Front/back body map, pain slider, keyboard-aware scrolling, disabled voice segment and safety message; good focused widget coverage (`emergency_request_step2.dart:22-99,190-253`; `emergency_request_step2_test.dart`). | Free text is mandatory; specialty suggestions are demo-only; a Medical Passport sharing toggle remains in the urgent form. Exact clinical/privacy allowlist is not approved. | Free text, raw body labels and “share medical record” must not reach uncommitted Doctors. P4 cannot grant MRS access. Voice must remain disabled. | **REUSE** body-map mechanics, pain control, safety panel and responsive structure. **REPAIR** into approved structured codes/bands; remove the P4 Passport-sharing choice; label any retained narrative as Patient-private and policy-gated. |
| HOME destination / `EmergencyRequestStep3` | Current GPS, address search, map selection and manual address; permission-denied/service-disabled recovery; optional arrival instructions; no inferred location on open; debounce/stale-result tests (`emergency_request_step3.dart:13-115,407-545`; `emergency_request_step3_test.dart`). | No accuracy/freshness display, stale fix state, offline draft policy or explicit “HOME only” contract. A debug web fallback can proceed without coordinates. | Exact address/coordinates are carried in a general route map (`emergency_request_step3.dart:83-95`). They must remain Patient-owned until a fenced HOME commitment and must never enter generic events/logs. | **REUSE** chooser, permission recovery and address correction. **REPAIR** typed protected draft, accuracy/freshness/degraded states and privacy copy. Never use for CABINET. |
| Patient review / `EmergencyReviewScreen` | Editable Patient, triage and destination sections; narrow/large-text coverage; no network call in this screen (`emergency_review_screen.dart:45-169`). | Shows legacy Passport-sharing status and says the request will be sent to Doctors without explaining the minimized projection. Non-HOME fallback route points to the generic provider list. | Patient may review their own details, but the copy must state that offered Doctors receive only the approved structured minimum, coarse zone/ETA and fee context. | **REUSE** review/edit shell. **REPAIR** attempt-mode summary, disclosure explanation and synthetic submit state. Remove Passport/MRS semantics. |
| HOME matching / `DoctorSelectionScreen` + `DoctorMatchingController` | Deterministic synthetic stream; searching, candidates, wait-longer, error/retry; progressive cards; duplicate-tap prevention; reduced-motion and viewport/large-text handling (`doctor_matching.dart:59-223`; `doctor_selection_screen_test.dart`). | Candidates accumulate indefinitely. There is no attempt/epoch, bounded K, hold ID, server time, expiry, wave expansion, stale removal, selection conflict, recovery or cancellation. Selection passes a Doctor ID only (`doctor_selection_screen.dart:40-55`). | Exact distance is displayed. Candidate cards omit the fee. The UI cannot prove that displayed choices remain live at decision time. | **REUSE** animation, card anatomy and synthetic source interface. **REPLACE** state model with actual-live-hold fixtures; show fee amount/currency/version, expiry, ETA band and selection conflict/recovery. |
| HOME confirmation / `ReviewConfirmScreen` | Visual Doctor/Patient/triage/location summary and fee display. | Calls `ConsultationsApi.createConsultation` with free text and exact GPS, then fetches a consultation (`review_confirm_screen.dart:22-116`). Includes a payment-method choice; P4 has no payment processing. Price appears only after selection and has no currency/version snapshot object. | Direct legacy submission bypasses journey, attempt, offer, live hold, Patient selection and P5 separation. This route must not be used by P4. | **REPLACE** for P4. A static confirmation should confirm a specific live `holdId` and immutable quoted amount/currency/version, with no payment collection. |
| Commitment pending / `DoctorCallingScreen` | Polished acknowledgement animation. | Polls legacy consultations, emits a Doctor-name local notification, advances after five seconds and may jump to consultation completion (`doctor_calling_screen.dart:24-103`). | Timer and legacy consultation status are not authoritative. Lock-screen copy may reveal a professional relationship. | **REPLACE** behavior; possibly reuse illustration. Required state is authoritative selection/commit pending, safe generic notifications, reconnect/refetch and explicit failure/cancel recovery. |
| HOME en route / `DoctorArrivingScreen` | Patient-facing Doctor journey presentation, contact affordances and map-style UI. | ETA/distance decrement locally; invokes dev auto-completion with diagnosis/treatment/clinical notes and advances to consultation complete (`doctor_arriving_screen.dart:21-129`). | Fabricated tracking and P4 clinical completion cross the P4/P5 boundary. Doctor-name notification content requires privacy review. | **REUSE** visual layout selectively. **REPLACE** state behavior with authoritative en-route, stale/degraded GPS, reconnect, cancellation and arrival/handoff-pending states. |
| Patient QR / `ConsultationQRScreen` | QR presentation and invalid/error handling UI. | Generates a QR containing consultation ID or raw Patient ID/name and can auto-complete a consultation (`consultation_qr_screen.dart:27-104`). | P5 alone verifies handoff and creates grants/MRS access. Patient identifiers must not be embedded in a P4 fallback QR or logged. | **DO NOT REUSE in P4.** Replace the P4 route with `CLINICAL_HANDOFF_PENDING`; any future QR belongs to the approved P5 contract. |
| Consultation complete / `ConsultationCompleteScreen` | Existing post-consultation completion presentation. | It is outside P4, which ends at arrival and handoff pending. | P4 must not infer consultation completion or clinical outcome. | **EXCLUDE from P4 route map.** P5 may own an independently reviewed completion UX. |
| CABINET directory / `DoctorDirectoryScreen` | Mature paginated directory, search/filter, first-load/empty/error/retry/load-more states, optional location filtering, detail navigation (`doctor_directory_screen.dart:17-180,404-485`). | Current CABINET entry uses `cabinetNewPatient`, general consultation pricing, Doctor detail, availability slots and scheduled booking. It does not model urgent target acceptance. | Current directory uses a backend repository and device location. P4-UI static inspection must not reuse it as an urgent API path or expose raw Doctor availability coordinates. | **REUSE** visual directory/card/filter primitives and public practice metadata only. Create an urgent-CABINET synthetic adapter and urgent fee projection; do not alter scheduled care. |
| CABINET target/detail/slot flow | Public Doctor/cabinet detail, accessibility, address and slot selection are implemented for scheduled care. | Slot selection and Appointment/request semantics are wrong for P4 urgent CABINET. Missing target confirmation, pending acceptance, decline/unavailable reason, choose-another and HOME fallback. | General consultation price is not the independent urgent CABINET fee snapshot. | **REUSE** public Doctor/cabinet presentation. **REPLACE** slot/booking continuation with targeted urgent-attempt static screens. |

## 4. Doctor screen inventory

| Screen / source | EXISTING and working static functionality | INCOMPLETE, WRONG or obsolete | SECURITY / PRIVACY mismatch | Reuse and required action |
|---|---|---|---|---|
| Doctor shell / `DoctorAppShell` | Stable Urgences tab, retained controller and embedded urgent/QR/medical-record subflow (`doctor_app_shell.dart:48-60,138-177,206-240`). | In-memory state is lost on process death and is not reconciled with authoritative journey/capacity state. | Shell can enter a demo medical-record route directly from P4. | **REUSE** shell, tab and in-tab navigation. **REPAIR** workflow destinations to end at handoff pending; remove P4 medical-record destination. |
| Runtime availability / `DoctorUrgentScreen` | Offline/online switch, available queue, incoming offer, countdown, accept/decline, waiting, selected, en-route and arrived compositions. Existing tests check privacy before selection and phone-size fit (`doctor_urgent_test.dart`). | A local enum and switch stand in for shared P4/P5 admission. No HOME/CABINET mode, clinical-busy, capacity conflict, dependency unavailable, post-handoff unavailable or explicit reactivation. | UI may imply availability when the authoritative admission service is uncertain. | **REUSE** cards and state transitions as static components. **REPLACE** controller with typed synthetic admission snapshots and fail-closed states. |
| Incoming offer | Pre-selection name/address redaction is test-backed. Accept/decline and expiry are present. | Current offer shows free-form complaint/symptoms, exact `1.8 km`, and no applicable HOME/CABINET fee. The “available” queue is not scoped by attempt/epoch/offer. | D6 permits only approved structured triage minimum, coarse zone/ETA and applicable fee; no identity, exact location, free text, voice or peer offers. | **REPAIR** projection and semantics. Add mode, offer expiry, fee/currency/version, coarse ETA/zone and generic failure states. |
| Accepted, awaiting Patient | Correctly remains anonymous and says the Patient is choosing. | No accepted hold identity/expiry, capacity claim, loss/expiry outcome or withdrawal action. | Acceptance must not reveal Patient identity or exact location. Current redaction is useful but the free-form complaint remains excessive. | **REUSE** waiting card. Add hold timer based on server time, expiry/lost/released states and privacy-safe refetch. |
| Selected / committed HOME | Reveals synthetic Patient name/address after simulated selection and supports route start. | `simulateSelection()` advances locally from accepted to selected; there is no proof of a live accepted hold or explicit Patient command. | This cannot be interpreted as commitment authority. Contact fields are not purpose-limited. | **REUSE** confirmed-card layout. Only render from a commitment projection with matching fence; use approved relay/contact data. |
| En route / map | Synthetic map, external Maps action, Patient card, visit reason and arrival button; map fallback UI exists (`doctor_urgent_screen.dart:760-1004,1061+`). | Fixed demo coordinates, no GPS accuracy/freshness, offline/reconnect, route-telemetry state, destination revocation or cancellation recovery. | Exact HOME destination is valid only for the currently fenced committed Doctor. Full symptom text must follow the approved post-commit allowlist. | **REUSE** map container/fallback and actions. Add stale/degraded/no-permission/revoked/cancelled states and confidentiality copy. |
| Arrived / QR | Arrival state is retained and QR screen can show ready/verifying/invalid/success fixtures. | Local arrival immediately offers P4 QR scanning. The scanner claims access is authorized and opens `DoctorMedicalRecordScreen(fullDemo)` (`doctor_urgent_qr_scanner_screen.dart:13-17,51-75,190-266`). | Arrival is not a P5 grant. P4 must not verify QR, authorize records or access MRS. Existing test expecting medical-record access encodes obsolete behavior. | **REPLACE** with `CLINICAL_HANDOFF_PENDING`, responsibility-transfer status and recovery. P5 owns any verified QR/grant UI. |
| CABINET Doctor operations | None specific to P4 urgent CABINET. | No targeted urgent offer, own-cabinet context, accept/decline/cannot-accept reason, Patient notification or shared admission state. | Must not reveal Patient location; CABINET arrival/no-show mechanism is unapproved. | **ADD** synthetic CABINET offer/wait/commit/recovery variants using shared visual primitives. Keep arrival/no-show disabled and visibly blocked. |

## 5. Controllers, state and data dependencies

| Area | Verified dependency | Assessment for P4 static work |
|---|---|---|
| Patient navigation | Named routes plus raw mutable maps; duplicated global/nested registration | Replace with typed route/state objects before adding more states. Preserve current shell transitions. |
| Patient subject | `UserProvider`, `FamilyProvider`, add-family repository | Reusable display source. It is not canonical-subject or journey-access authority. Static fixtures must cover inaccessible/changed ownership. |
| Triage | Local widget state; demo specialty assistant; no voice implementation | Suitable for synthetic static prototyping after removing Passport/MRS semantics and separating structured minimum from private narrative. |
| HOME destination | `Geolocator`, `geocoding`, Google Maps/Places abstractions | Strong UI seam. Static tests can inject gateways. Production protection, logging and server-side ETA remain separate gates. |
| HOME matching | `DemoDoctorMatchingSource` timers | Safe synthetic seam, but model must be replaced with attempt/epoch/offer/hold projections. |
| Legacy HOME continuation | `ConsultationsApi`, local notifications and timers | Prohibited P4 dependency. Do not wire or reuse. |
| CABINET discovery | `DoctorDirectoryRepository`, `Geolocator`, scheduled-care controllers/repositories | Production scheduled-care path, not P4. Reuse presentation through a synthetic urgent adapter only. |
| Doctor urgent | In-memory `DoctorUrgentController`, fixed `DoctorUrgentRequest.demo` | Static-only. Must not be called authoritative despite an existing test label using that word. |
| Doctor navigation | Google Maps static destination and URL launcher | Reusable presentation seam after commitment; currently synthetic. |
| P4/P5 handoff | P4 QR and demo medical-record screens | Wrong boundary. No valid P4 handoff UI exists yet. |

## 6. Existing static test evidence

The repository contains focused tests for Patient subject selection, body map/triage, location permission and search behavior, review editing, nested navigation, Doctor matching, Doctor urgent states and CABINET scheduled navigation. Particularly useful evidence includes:

- explicit subject selection, family-member creation failure/retry and narrow-device scrolling;
- voice disabled, local-only Passport toggle behavior and no Step 2 HTTP calls;
- no automatic location selection, permission denial recovery, debounced search and stale-result rejection;
- matching search/candidate/wait/error UI, duplicate-selection prevention and large-text layout;
- Doctor identity/address hidden before Patient selection and mobile-size coverage;
- directory filter constraints for the current scheduled CABINET route.

Tests also preserve obsolete expectations that must be changed during implementation: no fee on a HOME candidate card (`doctor_selection_screen_test.dart:83-129`), raw backend Patient IDs in route payloads, scheduled CABINET navigation, and Doctor QR access to a demo medical record (`doctor_urgent_test.dart:384-426`).

## 7. Inventory conclusion

The application has production-quality visual building blocks, but no end-to-end P4-compliant static journey. The safest reuse boundary is the presentation layer: cards, body map, location chooser, directory visuals, loading/error shells, map fallback, semantics and responsive composition. The current urgent route controllers, raw payloads, legacy consultation calls, scheduled CABINET continuation and P4 QR/medical-record continuation are not implementation foundations for the approved contract.
