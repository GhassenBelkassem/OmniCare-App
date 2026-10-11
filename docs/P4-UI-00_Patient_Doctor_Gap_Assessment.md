# P4-UI-00 — Patient and Doctor Gap Assessment

**Baseline:** P4-01E-REV-01 M2 architecture and P4-02A-REV-01 security direction v1.1

**Assessment type:** Static source and test inspection; not runtime or backend certification

## 1. Contract errata for implementation-readiness review

These four corrections are normative for subsequent Flutter work.

| ID | Erratum | UI consequence |
|---|---|---|
| UI-E1 | Mode is immutable on each `UrgentAttempt`; an explicit HOME-to-CABINET fallback creates a linked CABINET attempt inside the same active journey. | Do not mutate a HOME screen/model into CABINET. Show journey continuity and preserved subject/triage reference while creating a new mode-specific attempt. |
| UI-E2 | In urgent CABINET, the Patient selects the Doctor/Cabinet target before that Doctor accepts. | Directory action is “Request this Doctor/Cabinet,” followed by target confirmation and `AWAITING_DOCTOR`; it is not a list of Doctors who already accepted and not a slot booking. |
| UI-E3 | Cross-account canonical subject equivalence does not grant journey access. | A matching subject key never makes another account's journey visible. The UI renders only projections authorized to the current account and handles `not found/no longer visible` without revealing another journey. |
| UI-E4 | HOME commitment requires a live accepted hold plus explicit Patient selection. There is no `FREE -> COMMITTED` or arbitrary Doctor-ID shortcut. | The choose action submits a `holdId`/version from the current projection. Expired, replaced or lost holds are removed or fail safely; selection cannot call legacy consultation creation. |

## 2. Patient HOME gap report

### 2.1 Entry, subject and safety

**EXISTING:** The mode cards, explicit HOME subject selection, family cards, add-family workflow, body map, pain scale and emergency safety message are polished and testable.

**GAPS / REPAIRS:**

- Resume an existing active journey instead of silently starting another.
- Represent SELF or FAMILY_MEMBER as an opaque selection until the server resolves canonical subject and account access.
- Add subject-loading, no-family, failed-load, no-longer-authorized, ownership-changed and active-journey-conflict states.
- Make safety escalation prominent, accessible and localized. It must not imply that OmniCare dispatch replaces emergency services.
- Replace free-form body labels with the clinically/privacy-approved code set when approved. Preserve the distinction between the approved Doctor projection and Patient-private narrative.
- Remove the urgent Medical Passport/MRS-sharing affordance. Voice remains disabled.

### 2.2 HOME destination and privacy

**EXISTING:** The destination chooser offers GPS, search, map and manual recovery without selecting a default location. Permission-denied and unavailable-service paths exist.

**GAPS / REPAIRS:**

- State explicitly that the exact destination is for HOME dispatch only.
- Show fix accuracy, capture time and `fresh / stale / unavailable` state; never fabricate progress from a timer.
- Provide offline/degraded behavior that keeps a local draft without claiming it was submitted.
- Keep exact address, coordinates and arrival instructions out of uncommitted Doctor cards, notification payloads, analytics, crash text and generic route/event objects.
- Patient-facing candidate distance must be an approved band or generic availability label; server-side ETA computation may use exact positions without returning Doctor availability coordinates.
- Sparse-area policy may suppress zone/distance when it could identify a Patient or Doctor. Precision, TTL, heartbeat staleness and suppression thresholds remain external configuration decisions.

### 2.3 Matching waves, holds and actual choices

**EXISTING:** Synthetic candidates arrive progressively and the Patient can choose or wait. Searching, waiting-longer and error/retry states exist.

**MISSING:**

- journey, attempt and matching-epoch context;
- bounded candidate/hold count and wave-expansion messaging;
- live hold identifier, server-based expiry and per-card expiry state;
- removal of expired/withdrawn/no-longer-eligible choices;
- “actual choices now” count derived from live accepted holds;
- selection-in-flight, success, exact-expiry loss, version conflict, sibling release and refetch states;
- no-response, search exhausted, Patient cancellation, HOME rematch and explicit CABINET fallback;
- reconnect/relaunch restoration from an authorized projection.

The current list reports Doctors that accepted at any earlier moment and never expires them. It therefore cannot support the P4-01E “choices available at decision time” contract.

### 2.4 Fee visibility and immutable confirmation

**WRONG:** The HOME candidate model contains a numeric price, but candidate cards/details intentionally omit it; an existing test asserts no `100 TND` text. The price appears only after Doctor selection on a screen that also selects a payment method.

**REQUIRED:**

- Show each Doctor-authored HOME quote before Patient selection.
- Carry integer minor units, ISO currency and fee version in the synthetic UI model.
- On selection, show that exact quote as immutable and record the selected quote version in the confirmation view.
- If a hold expires or the Patient starts a new attempt/epoch, show any newly quoted version before a new selection.
- Do not show platform commission, automatic distance surcharge, silent repricing or P4 payment processing.

### 2.5 Commitment, cancellation, navigation and arrival

**WRONG:** `ReviewConfirmScreen` creates a legacy consultation directly. Later screens poll or auto-complete that consultation, decrement ETA locally and advance by timer.

**REQUIRED UI states:**

```text
SELECTING_HOLD
  -> SELECTION_SUBMITTING
  -> COMMITTED
  -> DOCTOR_EN_ROUTE
  -> DOCTOR_NEARBY / LOCATION_STALE / LOCATION_UNAVAILABLE
  -> ARRIVAL_RECORDED
  -> CLINICAL_HANDOFF_PENDING
```

At every non-terminal step, model Patient cancel availability, Doctor withdrawal, capacity revocation, network loss, stale event/refetch and safe recovery. Cancellation is a command with an authoritative outcome, not an optimistic pop. Realtime is only a hint; reconnect refetches the REST projection.

P4 stops at `CLINICAL_HANDOFF_PENDING`. No P4 screen may display a grant, medical record, diagnosis, consultation completion or P5 success inferred from arrival.

## 3. Patient CABINET gap report

### 3.1 What can be reused

- Doctor directory cards, search/filter layout, public identity and practice-location presentation.
- First-load, empty, error, reload and page-error shells.
- Public cabinet address, accessibility and approved contact metadata.
- SELF/family presentation after explicit-selection repair.

### 3.2 What is wrong

The existing route is scheduled care. It requests availability slots and creates scheduled booking/request objects. It uses a general consultation price rather than an independent urgent CABINET fee/version. It does not implement the Patient-selects-target-first contract.

### 3.3 Required urgent CABINET static journey

```text
Choose CABINET attempt
  -> select authorized SELF/FAMILY_MEMBER
  -> enter/review approved structured triage
  -> urgent-capable Doctor/Cabinet directory
  -> target confirmation with urgent CABINET fee snapshot
  -> AWAITING_DOCTOR
       -> ACCEPTED / CABINET_COMMITTED
       -> DECLINED
       -> DOCTOR_UNAVAILABLE / CAPACITY_CONFLICT
       -> EXPIRED / NETWORK_UNCERTAIN
  -> Patient chooses: another Doctor/Cabinet, HOME fallback, or cancel
```

No failure may automatically assign another Doctor. A retry creates a new targeted CABINET attempt while preserving the journey's subject and protected triage reference. The UI must make clear when a refreshed target has a different fee version.

### 3.4 CABINET arrival/no-show block

The arrival/no-show actor and evidence mechanism are not approved. Therefore:

- do not add “I arrived,” proximity detection, appointment-presence inference, geofence arrival or secretary confirmation as an authoritative P4 action;
- do not treat a scheduled appointment state or device GPS as CABINET arrival;
- render a static `BLOCKED_PENDING_CABINET_ARRIVAL_CONTRACT` placeholder in implementation fixtures if the route reaches that boundary;
- stop implementation at accepted CABINET commitment plus approved preparation/status information until product, P5 and security owners approve the mechanism.

## 4. Doctor urgent operations gap report

### 4.1 Runtime availability and shared admission

**EXISTING:** A clear online/offline toggle and distinct offer/wait/selected/en-route/arrived compositions.

**MISSING / REQUIRED:** The UI must distinguish:

- `OFFLINE_BY_DOCTOR`;
- `AVAILABLE`;
- `P4_HOME_HOLD` with expiry;
- `P4_HOME_COMMITTED`;
- `P4_CABINET_COMMITTED`;
- `P5_CLINICAL_BUSY`;
- `POST_HANDOFF_UNAVAILABLE`;
- `REACTIVATION_REQUIRED` and reactivation submitting/failed;
- `ADMISSION_AUTHORITY_UNAVAILABLE` or uncertain, which fails closed.

The Doctor must not appear available merely because a local switch is on. Explicit reactivation is a separate action after the approved unavailable period and authoritative checks. Cache/realtime state cannot enable acceptance.

### 4.2 HOME offer and hold

**EXISTING:** Identity and address remain hidden through Doctor acceptance; countdown and accept/decline controls exist.

**REPAIRS:**

- label mode `HOME` and show only the approved structured triage minimum;
- remove narrative complaint/symptom strings and exact distance from pre-commit UI;
- show coarse zone/ETA band or a sparse-area-safe generic label;
- show this Doctor's applicable HOME fee amount/currency/version;
- show offer expiry separately from accepted-hold expiry;
- after acceptance, show a hold/capacity state with server-time semantics;
- support expiry, Patient chose another Doctor, Patient cancelled, eligibility changed, clinical-busy conflict and safe retry/refetch;
- never show peer offers or other Doctors attached to the same journey.

### 4.3 CABINET targeted offer

A new static mode variant is required. It receives a target request only after the Patient chose the Doctor/Cabinet. It shows own cabinet, approved minimum triage, own urgent CABINET fee, expiry and accept/decline/cannot-accept outcomes. Patient identity remains hidden until commitment. It must not show Patient GPS or HOME destination.

### 4.4 Committed HOME, navigation and contact

After a matching commitment fence, the Doctor may receive the exact HOME destination, minimum identity, immutable quote and the approved operational triage projection. Required states include:

- location permission denied, GPS low accuracy and stale Doctor fix;
- map unavailable with privacy-safe external navigation recovery;
- reconnect/refetch after suspension or process death;
- commitment cancelled/revoked while viewing the route;
- purpose-limited Patient relay/contact unavailable or failed;
- arrival submitting, duplicate/replayed arrival and authoritative result.

The current full name/address and generic message affordance are synthetic. Final contact fields require the P4-02 D6 product/privacy allowlist.

### 4.5 Handoff and P5 boundary

The Doctor QR screen is not a P4 implementation foundation. It claims a grant and opens a demo medical record after a local delay. Replace it in the P4 flow with:

- `CLINICAL_HANDOFF_PENDING`;
- “P5 verification pending / unavailable / retrying / transferred” status without clinical detail;
- responsibility-transfer status that does not imply distributed atomicity;
- cancellation/transfer race outcome from the authoritative projection;
- `POST_HANDOFF_UNAVAILABLE` and explicit reactivation when P5 responsibility ends.

P5 alone owns QR verification, consultation access grants and MRS access.

## 5. Cross-cutting state coverage

| State | Current coverage | Required correction |
|---|---|---|
| Loading | Subject family load is implicit; directory/matching/location have loading variants | Standardize skeleton/progress plus cancellation-safe semantics per screen. |
| Empty | Directory and no-location states exist | Add no live HOME holds, no urgent CABINET targets and no eligible retry options. |
| Expired | Doctor offer timer exists | Add HOME offer/hold/selection deadline, CABINET target expiry and explicit authoritative recovery. |
| Offline | Doctor local offline exists | Add device/network offline, queued/no-submit state and reconnect/refetch for both actors. |
| Stale | Places search rejects stale results | Add stale journey version, stale event, stale GPS, stale Doctor position and stale fee/hold projection. |
| Degraded | Map fallback and longer search exist | Add server/realtime degraded, generic location suppression and admission dependency unavailable. |
| Permission denied | HOME destination and directory-distance filtering handle denial | Add Doctor navigation permission denial and make CABINET directory usable without Patient GPS. |
| Conflict | Not represented | Add active-subject journey, hold lost, concurrent selection, capacity conflict and cancellation-versus-commit outcomes. |
| Withdrawn/cancelled | Not represented end-to-end | Add Patient and Doctor cancellation eligibility, submitting, confirmed, rejected and recovery. |
| Reconnect | Not represented | Rebuild solely from authorized REST projection; discard stale local transitions. |

## 6. Accessibility, responsiveness, localization and polish

### Existing strengths

- Several urgent controls have `Semantics`, tooltips and meaningful labels.
- Matching and Doctor urgent animations respect reduced-motion settings in key places.
- Location, review, matching and Doctor urgent tests cover narrow screens, large text or several phone dimensions.
- Scrollable layouts and max-width constraints are common.

### Gaps before production-quality static readiness

- Urgent screens contain hard-coded French while CABINET subject screens contain hard-coded English; none of the inspected urgent files uses `AppLocalizations`, despite app support for English, French and Arabic.
- RTL layout, focus order, keyboard navigation, screen-reader live announcements and dynamic-type extremes are not certified.
- Countdown changes, hold expiry, incoming offer and commitment/cancellation outcomes need non-visual announcements without excessive repetition.
- Color contrast, error identification independent of color, 48dp targets and map alternatives need a documented audit.
- Sensitive values must not be duplicated into semantic labels before their disclosure stage. Current post-selection Doctor semantics hard-code a synthetic Patient name.
- Patient safety messaging and all operational errors need localized, plain-language copy reviewed for clinical and privacy accuracy.

## 7. Privacy projection checklist for static fixtures

| Actor/stage | Allowed fixture fields | Forbidden fixture fields |
|---|---|---|
| Offered HOME Doctor | attempt/offer reference, HOME mode, approved structured triage minimum, coarse zone/ETA, own fee/currency/version, expiry | Patient identity, exact address/GPS, free text, voice, family relation, peer offers |
| Accepted-but-unselected HOME Doctor | same minimum plus own hold/expiry state | identity, exact destination, Patient contact, peer offers |
| Committed HOME Doctor | approved minimum identity/contact, exact HOME destination, immutable quote, authorized operational triage | unrelated MRS data, other journeys, raw Patient account identifiers |
| Targeted CABINET Doctor before acceptance | CABINET mode, own target/cabinet, approved structured minimum, own CABINET fee, expiry | Patient GPS/address, identity, text, voice, peer offers |
| Committed CABINET Doctor | minimum identity and approved preparation triage | HOME destination/route telemetry, MRS data |
| Patient HOME candidates | public Doctor identity, ETA band, applicable HOME quote, live hold expiry/status | raw Doctor availability coordinate, internal capacity/clinical-busy detail |
| Patient CABINET directory/target | public Doctor/cabinet metadata, applicable urgent CABINET quote, response state | other Patients, internal Doctor location/capacity detail |

All example identifiers must remain synthetic and opaque.

## 8. Gap-assessment verdict

The Flutter code is visually ahead of its domain model. Static components are reusable, but the current HOME continuation, CABINET scheduling route and Doctor QR/medical-record path cannot be repaired by simply changing labels or adding API calls. A typed synthetic P4 journey/attempt projection must be introduced first, and the legacy/scheduled/P5 continuations must remain outside that coordinator.
