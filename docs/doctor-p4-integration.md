# Doctor P4 Flutter integration

**Last reviewed:** 2026-10-20
**Branch:** `feature/fozenp3`
**Authority:** authenticated Spring Boot Doctor APIs; local Doctor fixtures remain debug/test presentation only

This is the single consolidated reference for the Flutter Doctor P4 integration. No earlier
consolidated Doctor integration document was present when D-FLUTTER-03A was completed.

## Certified scope

| Milestone | Flutter responsibility | Authoritative backend surface | Operational boundary |
|---|---|---|---|
| D-FLUTTER-01 | Account-scoped Doctor workspace bootstrap and capability-driven navigation | `GET /api/v1/me/care-capabilities`, urgent configuration/readiness, practice locations, and runtime reads | Local onboarding and stored demo services are not professional authority. |
| D-FLUTTER-02A | HOME/CABINET runtime-intent presentation and controlled mutation | `/api/v1/me/urgent-runtime` | Runtime intent does not grant eligibility, create offers, or replace configuration/readiness. |
| D-FLUTTER-02B | Foreground HOME operational presence | `/api/v1/me/urgent-runtime/location-presence` | GPS is session-bound operational presence, not offer or clinical authority. |
| D-FLUTTER-03A | Bounded Doctor HOME offer inbox and current-detail refresh | `GET /api/v1/me/urgent-home/offers` and `GET /api/v1/me/urgent-home/offers/{offerId}` | No local/demo offer is business authority. |
| D-FLUTTER-03B | One-shot Doctor acceptance and decline from a freshly verified pending offer | `POST /api/v1/me/urgent-home/offers/{offerId}/accept` and `/decline` | Acceptance creates only a temporary `HOME_HOLD`; no Patient selection, commitment, mission, destination, navigation, QR, MRS, or consultation authority is inferred. |
| D-FLUTTER-04-01 | Confirmed HOME commitment discovery and restart recovery | `GET /api/v1/me/urgent-home/commitments/active` and exact commitment detail | Read-only responsibility status; no Patient context, mission action, navigation, arrival, QR, or MRS authority. |
| D-FLUTTER-04-02A | Active-commitment-bound synthetic dispatch context | `GET /api/v1/me/urgent-home/commitments/{commitmentId}/dispatch-context` | Confirmed address only; no Patient identity, route, ETA, map, travel state, arrival, QR, MRS, or mission command. |
| P4-CAB-03A | Targeted urgent CABINET request decisions and commitment recovery | `/api/v1/me/urgent-cabinet/targeted-requests` and `/api/v1/me/urgent-cabinet/commitments` | Synthetic-development authority only; no Patient identity, arrival, QR, consultation, clinical handoff, or MRS authority. |
| P4-CAB-03B-03 | Patient urgent CABINET waiting, cancellation, outcomes, and receipt recovery | `/api/v1/me/urgent-cabinet/requests/{requestId}`, `/cancel`, `/recovery`, and `/active` | Presentation/recovery architecture only. Patient submission remains hard-disabled; no live synthetic E2E execution. |
| P4-CAB-05 | Patient post-acceptance withdrawal and commitment-bound arrival handoff | Patient `/withdraw` and `/arrival-handoffs`; Doctor `/arrival-verifications`; existing request and commitment recovery reads | Arrival is operational evidence only. It never starts consultation, grants MRS access, releases capacity, or invents no-show policy. |

The authenticated shell constructs service-dependent navigation only after the server bootstrap.
`HOME_VISIT` remains hidden from the V1 mobile service set without changing historical backend
data. HOME-only Doctors do not require a Cabinet. Runtime OFF keeps configured navigation visible;
unsupported actions remain disabled with server-grounded explanations.

## D-FLUTTER-03A/03B offer contract

The list request uses the authenticated `AppHttpClient` and never accepts a Doctor ID. Its first
page is `limit=20`. Further pages use the backend cursor pair `beforeUpdatedAt` and
`beforeOfferId`; page numbers and offsets are not invented. The detail request is performed when
the Doctor opens an item so the list snapshot is never treated as current command authority.

The exact response projection is:

- `offerId`, `status`, `revision`;
- `responseDeadlineAt`, optional `holdExpiresAt`, and `holdCurrentlyValid`;
- optional immutable `quotedHomeFeeTnd` and `currency`;
- optional controlled `withdrawalReason`;
- `replayed`, `updatedAt`, and `evaluatedAt`.

The closed status parser covers `PENDING_RESPONSE`, `ACCEPTED_HELD`, `HOLD_EXPIRED`,
`DOCTOR_WITHDRAWN`, `DECLINED`, `SELECTED_COMMITTED`, `NOT_SELECTED`, `SELECTION_CLOSED`,
`INVALIDATED`, `EXPIRED`, `SUPERSEDED`, and `CANCELLED`. Unknown or internally inconsistent
projections fail closed. The list itself accepts only current pending and physically accepted-held
rows, matching the backend query. A later detail read may truthfully return a terminal state.

Fees are rendered at exactly three TND decimal places. Null means no quoted fee; `0.000` remains an
explicit zero quote. A valid `ACCEPTED_HELD` item is described as a temporary hold only. It is not
presented as Patient selection or `HOME_COMMITMENT`. A physically held row whose deadline is no
longer valid is shown as expired/pending materialization rather than actionable.

### Response commands

Both commands use the authenticated `AppHttpClient`, send `Cache-Control: no-store`, and carry one
stable `Idempotency-Key` header. Their complete JSON body is:

```json
{"expectedRevision": 2}
```

Flutter never sends a Doctor ID, Patient ID, price, coordinates, destination, capacity token, or
fence. Opening the detail sheet performs a GET, and pressing either action performs another fresh
GET before the key is generated. The POST is allowed only when that response is
`PENDING_RESPONSE`, its strict server-evaluated deadline is still future, and its revision is used
as `expectedRevision`. A single controller-wide command lock prevents double taps and concurrent
accept-versus-decline submissions.

A new explicit logical command receives a cryptographically random UUID key. An ambiguous timeout,
5xx, malformed command response, or `HOME_OFFER_COMMAND_IN_PROGRESS` first causes a detail GET.
If the offer remains pending at the exact captured revision, the UI permits only an explicit retry
with the same key, offer ID, action, and revision. It never creates a replacement key
automatically. If reconciliation proves the requested terminal/held outcome, Flutter adopts it
without another POST. A failed reconciliation leaves only a GET-based **Vérifier le statut
serveur** action. State/revision changes and terminal/deadline outcomes permanently close that
captured command.

The command error mapper covers `RESOURCE_STATE_CONFLICT`, `HOME_OFFER_NOT_ACTIONABLE`,
`HOME_OFFER_IDEMPOTENCY_CONFLICT`, `HOME_OFFER_COMMAND_IN_PROGRESS`,
`HOME_HOLD_BUDGET_FULL`, `HOME_DOCTOR_CAPACITY_CONFLICT`,
`HOME_OFFER_ELIGIBILITY_CHANGED`, `LOCATION_PRESENCE_UNAVAILABLE`,
`HOME_ROUTE_VERIFICATION_UNAVAILABLE`, `HOME_OFFER_NOT_FOUND`,
`URGENT_RUNTIME_UNAVAILABLE`, 401/403, unknown HTTP failures, and ambiguous transport failure. K,
capacity, eligibility, GPS, and road-route failures are displayed as server rejections; Flutter
does not bypass or locally repair them.

An accept response is adopted exactly as returned, including the immutable three-decimal TND fee,
explicit `0.000`, hold deadline, validity, revision, and replay marker. `ACCEPTED_HELD` is labelled
**En attente du choix du patient**. `SELECTED_COMMITTED`, if observed during reconciliation, is
labelled **Médecin confirmé par le patient** but remains informational: this milestone exposes no
mission or protected Patient data. Decline adopts the returned terminal state and removes both
response actions.

## Loading, ownership, and recovery

The inbox is activated only while an authenticated Doctor with `URGENT_HOME` is viewing the HOME
mode. CABINET-only Doctors issue no HOME offer request. The controller supports explicit refresh,
safe foreground refresh, and at most three retained pages (60 default-size rows). There is no
polling loop or local persistence.

Every read is fenced by a controller generation and authenticated Doctor identity. Refresh, mode
exit, account switch, logout, capability removal, and disposal cancel pending Dio reads. Commands
are additionally fenced by Doctor identity, exact pending-command identity, and cancellation token.
Account switch, logout, capability removal, and disposal invalidate a late command response; merely
leaving the HOME mode does not interrupt an already-sent server command, and re-entry performs the
normal authoritative refresh. Late work cannot restore the preceding account's state.

Presentation states are distinct:

- loading: bounded server read in progress;
- empty: authoritative empty inbox, with no demo fallback;
- unavailable: the backend rollout gate returned `URGENT_RUNTIME_UNAVAILABLE`;
- failure: offline/timeout, 5xx, or malformed response, with explicit retry;
- ready: minimized pending/accepted-hold projection;
- stale detail: a non-enumerating 404 removes the stale list item.

HTTP 401/403 invokes the protected-flow session rejection boundary. No response, notification,
WebSocket hint, Redis presence, local fixture, or cached row is treated as business authority.

## Privacy and frozen UI

The inbox stores and renders only the backend projection above. It contains no Patient identity,
symptoms, phone, destination, coordinates, clinical narrative, route, ETA, rating, capacity token,
or fence. It writes no offer data to preferences, secure storage, telemetry, or logs.

The single Doctor `Urgences` destination and existing HOME/CABINET segmented interaction are
preserved. The authenticated HOME surface places the inbox and response commands behind the
existing backend gate. Legacy static HOME cards and command simulation remain reachable only
through explicit preview/test construction; they are not production handlers for the authenticated
server inbox. CABINET simulation, HOME runtime/GPS controllers, and P3 scheduled care were not
changed by D-FLUTTER-03B.

## D-FLUTTER-03A/03B files

Added:

- `lib/features/doctor/urgent/doctor_home_offer.dart`
- `lib/features/doctor/urgent/doctor_home_offer_repository.dart`
- `lib/features/doctor/urgent/doctor_home_offer_inbox_controller.dart`
- `lib/features/doctor/urgent/doctor_home_offer_inbox_section.dart`
- `test/doctor_home_offer_inbox_test.dart`

Integrated:

- `lib/features/doctor/doctor_auth_shell_screen.dart`
- `lib/features/doctor/shell/doctor_app_shell.dart`
- `lib/features/doctor/urgent/doctor_urgent_workspace_screen.dart`

D-FLUTTER-03B extends the four offer files and their existing test above; it adds no second command
store, route, screen, persistence layer, GPS source, or mission controller. This consolidated
document is the only documentation file amended.

## Verification

- Focused D-FLUTTER-03A/03B contract/controller/widget tests: **50/50 passed**.
- Affected bootstrap/navigation/runtime/GPS/shell/P3 realtime set: **149/149 passed**.
- Complete Doctor-scoped `test/doctor_*.dart` plus scheduled-care realtime: **513/513 passed**.
- Exact affected production/test-file analyzer: **0 issues**.
- Repository-wide `flutter analyze`: **414 existing warning/info findings** outside the affected
  files; this legacy baseline is disclosed, not relabelled as clean and not modified here.
- Patient/Clinic suites were intentionally not run or changed; their independent workstream is not
  relabelled as green.

## Synthetic manual procedure

1. Sign in as a server-configured Doctor with `URGENT_HOME`; open **Urgences > À domicile**.
2. Confirm the first page loads from the private endpoint and that an empty response shows an empty
   server inbox rather than fixture cards.
3. With a controlled pending fixture, open **Actualiser le statut**. Confirm that **Accepter** and
   **Décliner** appear only after the fresh detail read.
4. Accept once. Confirm **En attente du choix du patient**, the exact immutable three-decimal TND
   quote (including a separate `0.000` fixture), the backend hold deadline/validity, and the absence
   of destination, navigation, mission, QR, or medical-record actions.
5. Decline a separate pending fixture and confirm the terminal result removes both actions. Repeat
   with expired and not-selected detail fixtures and confirm no POST is issued.
6. Simulate two taps and competing accept/decline taps; verify one POST. Drop the command response,
   leave the detail GET pending, and verify that only reconciliation or an explicit same-key retry
   is offered—never an automatic new-key POST.
7. Exercise stale revision, K-full, capacity conflict, eligibility change, unavailable GPS/route,
   401/403, rollout 404, and 5xx fixtures; confirm each remains fail-closed and server-grounded.
8. Exercise **Afficher plus** with more than 20 rows and confirm stable keyset continuation stops
   after the third retained page.
9. Disable networking and refresh, then restore networking and retry. Separately disable the P4
   rollout gate and confirm the unavailable state is distinct from empty.
10. Start a delayed command, log out, remove HOME capability, or switch accounts, then release it;
    confirm no previous Doctor state reappears.
11. Sign in as a CABINET-only Doctor and verify that opening **Urgences** causes no HOME inbox call.
12. Background and resume the app while HOME is visible; confirm one safe refresh and no polling.

The current real Patient-to-Doctor producer, rollout gate, and matching workers may remain inactive,
so a permanently empty inbox is a valid certified result. D-FLUTTER-03B certifies only offer
response commands; it does not claim real matching, Patient selection, committed dispatch,
notification delivery, mission tracking, arrival, QR, consultation, or MRS access is operational.

## D-FLUTTER-04-01 confirmed commitment and restart recovery

D-FLUTTER-04-01 adds a read-only, account-scoped projection of the P4-08-BE-01 Doctor commitment
authority. It uses the existing authenticated `AppHttpClient` and only these two endpoints:

- `GET /api/v1/me/urgent-home/commitments/active` on Doctor login, app resume, explicit refresh,
  and an authorized invalidation callback; and
- `GET /api/v1/me/urgent-home/commitments/{commitmentId}` only to reconcile the exact commitment
  identity already observed in the current in-memory Doctor session.

The active envelope accepts only `ACTIVE_COMMITMENT` with one internally active commitment or
`NO_ACTIVE_COMMITMENT` with a null commitment. The detail accepts only `ACTIVE`, `CANCELLED`, or
`INVALIDATED`. It parses the commitment, journey, and selected-offer UUIDs; nonnegative revision;
immutable three-decimal TND fee; committed, terminal, updated, and evaluation times; and the exact
empty `availableActions` list. Unknown status/action shapes, mismatched identities, malformed fee
precision, invalid terminal shape, and incompatible DTOs fail closed.

The scoped controller states are `initial`, `loading`, `noActiveCommitment`, `activeCommitment`,
`terminalCommitment`, `unavailable`, and `failure`. `NO_ACTIVE_COMMITMENT` alone is authoritative
empty. Network failure, 5xx, and `HOME_COMMITMENT_READ_UNAVAILABLE` never become empty. A known ID
is reconciled after an empty active lookup so cancellation or invalidation stops the active
presentation. `HOME_COMMITMENT_NOT_FOUND` is non-enumerating and clears only that known current-
session identity. No history-list endpoint is invented.

Startup launches workspace bootstrap and commitment recovery independently for the authenticated
Doctor. App resume and the card refresh action repeat the active check. A newly observed
`SELECTED_COMMITTED` offer invokes only a commitment refetch; it does not authorize a mission by
itself. `ACCEPTED_HELD` remains a temporary hold. The controller also exposes the same bounded
refetch entry point for a future authenticated HOME invalidation hint, but this milestone adds no
WebSocket subscription because production HOME publication remains unavailable.

Every request is fenced by Doctor identity, a monotonic controller generation, and cancellable
Dio tokens. Logout, account replacement, disposal, and a newer refresh invalidate late active and
detail responses. Commitment data has no local persistence, logging, notification payload, or
second HTTP client. A 401/403 uses the existing protected-flow logout boundary.

### Frozen presentation boundary

The legacy static HOME controller contains fictional Patient name, age, symptoms, complaint,
address, route, distance, ETA, arrival, QR, and medical-record fixtures. P4-08 does not authorize
those fields, so an active server commitment does not open that demo selected/en-route/arrival
workflow. The authenticated HOME workspace instead renders one design-system status card with:

- server commitment status, short opaque reference, revision, immutable fee, and lifecycle time;
- an explicit privacy/authority explanation; and
- no Patient identity, destination, symptoms, route, navigation, arrival, QR, MRS, consultation,
  cancellation, capacity, or other mission command.

Current service eligibility and existing responsibility are separate navigation inputs. If
`URGENT_HOME` is later removed or runtime HOME is OFF, an already known active or terminal
commitment keeps the HOME responsibility surface reachable. Capability removal hides runtime,
GPS, and offer controls; it does not erase or mutate responsibility. Terminal presentation never
re-enables runtime. On a cold restart, only the active endpoint can rediscover responsibility;
terminal history cannot be restored because the backend intentionally exposes no Doctor history
list.

### D-FLUTTER-04-01 files

Added:

- `lib/features/doctor/urgent/doctor_home_commitment.dart`
- `lib/features/doctor/urgent/doctor_home_commitment_repository.dart`
- `lib/features/doctor/urgent/doctor_home_commitment_controller.dart`
- `lib/features/doctor/urgent/doctor_home_commitment_section.dart`
- `test/doctor_home_commitment_test.dart`

Integrated:

- `lib/features/doctor/doctor_auth_shell_screen.dart`
- `lib/features/doctor/shell/doctor_app_shell.dart`
- `lib/features/doctor/urgent/doctor_urgent_workspace_screen.dart`
- `lib/features/doctor/urgent/doctor_home_offer_inbox_controller.dart`
- `test/doctor_home_offer_inbox_test.dart`
- `test/doctor_auth_shell_bootstrap_test.dart`

### D-FLUTTER-04-01 verification

- Focused commitment/offer/workspace/navigation/authentication tests: **75/75 passed**.
- Complete Doctor-scoped tests plus scheduled-care realtime: **527/527 passed**.
- Exact affected production and test file analyzer: **0 issues**.

## D-FLUTTER-04-02A authenticated dispatch context

D-FLUTTER-04-02A integrates the narrow P4-08-BE-02A response through the existing authenticated
`AppHttpClient`:

`GET /api/v1/me/urgent-home/commitments/{commitmentId}/dispatch-context`

The typed response contains exactly `commitmentId`, nonnegative `commitmentRevision`, UTC
`evaluatedAt`, and a destination with finite in-range latitude/longitude, nonblank confirmed
address, closed acquisition mode, closed provenance, and UTC `confirmedAt`. Supported acquisition
modes are `CURRENT_GPS`, `ADDRESS_SEARCH`, `MAP_PIN`, and `MANUAL_ADDRESS`; supported provenance
values are `DEVICE_GPS`, `ADDRESS_RESULT`, `PATIENT_MOVED_PIN`, and `MANUAL_ENTRY`. Flutter also
validates the backend-supported mode/provenance pair. Unsupported enums, malformed UUIDs or
timestamps, invalid coordinates, negative revisions, missing destination fields, and mismatched
response identities fail closed.

The request is made only after the commitment controller has authoritatively reached an exact
ACTIVE commitment. An offer hold—including `ACCEPTED_HELD`—and an observed
`SELECTED_COMMITTED` offer are not dispatch authority and cause no context request. The returned
commitment ID and revision must exactly match the attached active commitment before the
destination becomes visible. There is no polling and duplicate notifications for the same
in-flight or already verified authority do not create another request.

### Session, revocation, and sensitive-memory boundary

Dispatch context exists only in the account-scoped controller's memory. It is never written to
preferences, secure storage, logs, notification payloads, or a general-purpose cache. Commitment
revalidation clears the address before the active lookup starts. Resume therefore preserves the
current Accueil/Urgences destination and HOME/CABINET selection while hiding the address until the
commitment and its exact revision have both been re-established.

No active commitment, a terminal cancellation/invalidation, 404
`HOME_DISPATCH_CONTEXT_NOT_FOUND`, 503 `HOME_DISPATCH_CONTEXT_UNAVAILABLE`, offline failure,
malformed payload, or stale revision exposes a prior address. Safe commitment responsibility is a
separate presentation state and remains visible when the destination is unavailable. Logout,
account replacement, capability removal, disposal, and newer commitment work invalidate prior
request generations; a late response cannot repopulate another session. Runtime HOME OFF and
permanent `URGENT_HOME` capability removal do not erase an otherwise known active responsibility
or its successfully revalidated context.

### Frozen UI source map

The polished legacy `DoctorUrgentScreen` remains a preview/test-only demo and is not used as
authenticated commitment presentation. Its sources were mapped as follows:

- `DoctorUrgentRequest.demo` supplies the fictional Amina Chaari identity, age 45, chest-pain
  complaint and symptoms, Tunis area, `1,8 km`, `≈ 6 min`, and Avenue Habib Bourguiba address;
- `DoctorUrgentScreen` additionally hard-codes waiting/request Patient ages, symptoms, the second
  nearby request, the recent-visit names and outcomes, route/ETA labels, messaging, start-route,
  arrival, and QR transitions;
- `DoctorUrgentMapDemo` supplies static Doctor/destination coordinates, a static polyline, and the
  external Google Maps URI; and
- `DoctorUrgentController` owns only the local demo transitions from offline through selected,
  en-route, and arrived.

None of those values or transitions is bound to authenticated data. The existing authenticated
`DoctorHomeCommitmentSection` remains the confirmed-responsibility presentation. Its existing fact
row pattern now renders only the verified `confirmedAddress`, or a nonsensitive verification/
unavailable label. No card, typography, spacing, animation, navigation, bottom sheet, map, or
mission action was added or replaced, so no further visual approval is required for this bounded
mapping. Coordinates, acquisition metadata, and provenance are validated but not rendered.

### D-FLUTTER-04-02A files

Added:

- `lib/features/doctor/urgent/doctor_home_dispatch_context.dart`
- `lib/features/doctor/urgent/doctor_home_dispatch_context_repository.dart`
- `lib/features/doctor/urgent/doctor_home_dispatch_context_controller.dart`
- `test/doctor_home_dispatch_context_test.dart`

Integrated:

- `lib/features/doctor/doctor_auth_shell_screen.dart`
- `lib/features/doctor/shell/doctor_app_shell.dart`
- `lib/features/doctor/urgent/doctor_urgent_workspace_screen.dart`
- `lib/features/doctor/urgent/doctor_home_commitment_section.dart`
- `test/doctor_auth_shell_bootstrap_test.dart`

### D-FLUTTER-04-02A verification

- Focused dispatch-context, authentication lifecycle, and commitment tests: **33/33 passed**.
- Complete Doctor-scoped tests plus scheduled-care realtime: **550/550 passed**.
- Exact affected production/test-file analyzer: **0 issues**.
- Patient, Clinic, Backend, Angular, and MRS suites were intentionally not run or changed.

Remaining blockers are the production prohibition on the current synthetic source, authorized
real-Patient dispatch data, responsibility recovery policy for a suspended/deactivated Doctor,
real HOME realtime publication and mobile subscription, approved route/navigation/tracking,
travel-state and arrival commands, QR verification, consultation and clinical/MRS access,
postcommitment cancellation, and physical-device manual QA. This milestone does not claim
real-Patient dispatch or navigation is operational.

## P4-MAPS-01A cross-platform Maps foundation

The selected rendering package remains the locked `google_maps_flutter` dependency. No Navigation
SDK, Routes API, external-directions flow, authenticated destination renderer, route, ETA, travel,
arrival, QR, or MRS behavior is introduced. The authenticated Doctor HOME workspace continues to
exclude the legacy static map.

Android continues to source `MAPS_API_KEY` from the ignored `android/local.properties`, a Gradle
property, or the process environment. Gradle and the native configuration bridge report only a
generic configured/unconfigured state and never return or log the key. The existing package ID,
Maps manifest entry, Places SDK integration, minimum SDK, and signing identity are unchanged.
Production release signing remains unresolved because the current release build still uses the
debug signing configuration; Google Cloud restrictions must distinguish local debug, reviewed
release, and Play App Signing certificate fingerprints.

iOS `Debug.xcconfig` and `Release.xcconfig` optionally include the Git-ignored
`Flutter/MapsConfig.xcconfig`. Copy `MapsConfig.xcconfig.example` locally and set the restricted iOS
key, or generate the ignored file from a protected CI secret. `Info.plist` still expands only
`$(MAPS_API_KEY)`, and `AppDelegate` rejects missing, unresolved, or placeholder-shaped values
without disclosing them. The iOS 14 target, CocoaPods dependencies, bundle identifier, sign-in, and
foreground-location configuration are unchanged.

Web Maps JavaScript is loaded once, on demand, from the compile-time
`GOOGLE_MAPS_WEB_API_KEY` Dart define. Copy `config/maps.web.local.example.json` to the ignored
`config/maps.web.local.json`, then launch the isolated harness with:

```sh
flutter run -d chrome -t lib/main_maps_smoke.dart \
  --dart-define-from-file=config/maps.web.local.json
```

The tracked HTML never contains or receives a real key. Its application-wide `no-referrer` policy
is retained; only the generated Maps script opts into `strict-origin-when-cross-origin` and
Google's origin-only authorization parameter so an origin-restricted website key can authenticate
without sending a path. Script-load, authentication, namespace, and timeout failures become one
neutral unavailable state, and a single cached load future prevents duplicate injection or retry
loops.

`lib/main_maps_smoke.dart` is an explicit developer-only entry point, not an application route. It
centers an interactive map on the synthetic `0°, 0°` coordinate with one marker and no identity,
clinical data, polyline, distance, ETA, navigation, or journey state. It exposes loading, measured
ready time, and neutral failure states and disposes its controller when removed. Native smoke runs
use `flutter run -t lib/main_maps_smoke.dart` after configuring the relevant local platform key.

Before manual certification, a Google Cloud administrator must confirm billing, enable Maps SDK
for Android, Maps SDK for iOS, and Maps JavaScript API, then create separate API- and
application-restricted keys for the Android package/signing certificates, iOS bundle identifier,
and exact approved HTTPS Web origins. Quotas, budget alerts, unexpected-usage alerts, and key usage
monitoring remain administrative requirements. Only synthetic coordinates are permitted until a
later approved authenticated renderer milestone.

## P4-CAB-03A targeted requests and commitment integration

P4-CAB-03A connects the existing frozen Doctor CABINET presentation to the authenticated
P4-CAB-02A/02B backend. The dashboard shell, bottom navigation, `Urgences` destination,
HOME/CABINET segmented control, request cards, detail bottom sheet, accepted card, and accepted
detail sheet retain their approved structure. The former authenticated in-app preview is no longer
the shell's business source; explicit preview/test entry points remain development-only.

The frozen presentation now uses server data only for authenticated behavior. A request card and
detail may show the configured Cabinet snapshot, exact three-decimal TND quote, authorized closed
body-area values, pain score, server timestamps, and masked **Patient concerné** copy. It never
creates a Patient name, telephone number, medical history, free-text clinical narrative, scheduled
appointment, or HOME hold. The existing check-in/QR preview stays restricted to a debug fixture;
server commitments cannot launch it. The visible arrival affordance therefore remains an explicit
future/unavailable boundary and sends no arrival, QR, consultation, handoff, or MRS command.

### Authenticated API and DTO mapping

The account-scoped repository uses the existing `AppHttpClient` and only these routes:

- `GET /api/v1/me/urgent-cabinet/targeted-requests?limit=20`;
- `GET /api/v1/me/urgent-cabinet/targeted-requests/{requestId}`;
- `POST /api/v1/me/urgent-cabinet/targeted-requests/{requestId}/accept`;
- `POST /api/v1/me/urgent-cabinet/targeted-requests/{requestId}/decline`;
- `GET /api/v1/me/urgent-cabinet/commitments?limit=20`; and
- `GET /api/v1/me/urgent-cabinet/commitments/{commitmentId}`.

The pending-request parser retains exactly `requestId`, `practiceLocationId`, `requestRevision`,
`bodyAreaCodes`, `painScore`, `quotedFeeTnd`, `currency`, `createdAt`, optional
`responseDeadlineAt`, `evaluatedAt`, and the backend state/action fields needed to prove the row is
`PENDING` / `CABINET_PENDING` with only `ACCEPT` and `DECLINE`. It requires null response and
commitment fields, response revision zero, canonical UUIDs, UTC timestamps, TND with at most three
decimal places, pain in `[0,10]`, unique known body-area codes, a bounded list, and the current
authenticated Doctor/Cabinet context. Unknown or inconsistent shapes fail closed. Extra Patient
identity is neither modeled nor rendered.

The commitment parser retains `commitmentId`, `requestId`, `practiceLocationId`, `status`,
`revision`, immutable quote/currency and quote-configuration revision, `committedAt`, optional
`terminalAt`, `updatedAt`, empty `allowedActions`, and `evaluatedAt`. Its closed statuses are
`ACTIVE`, `CANCELLED`, and `INVALIDATED`. Terminal and timestamp shapes are strict, duplicate
identities and more than one active commitment fail closed, and an inconsistent backend authority
is surfaced as unavailable rather than accepted.

### Inbox, detail, and decision behavior

An authenticated Doctor with the urgent CABINET capability receives a bounded manual-refresh
inbox. An empty server list remains empty; no demo fallback is inserted. Multiple pending requests
remain independent and at most the existing three-card frozen preview is shown. Opening a card
fetches that exact request before displaying its sheet. No local countdown changes a request into
a terminal outcome.

Accept and decline send only:

```json
{"expectedRequestRevision": 1}
```

The URL carries the exact request UUID and the header carries a cryptographically random mandatory
`Idempotency-Key`. One logical `(request, action, revision)` decision owns one key. An ambiguous
network, 5xx, malformed-response, or command-in-progress result retains that key for an identical
explicit retry; another request, action, or revision cannot reuse it. A controller token and
in-progress state reject double taps and competing accept/decline commands.

The repository strictly verifies the returned request, Cabinet, fee, revision, timestamps,
`replayed`, terminal action list, and accept-versus-decline shape. Acceptance is represented only
as an exclusive CABINET commitment; it is not a HOME hold or appointment. Decline requires null
commitment fields. Stale/not-actionable, eligibility, capacity, idempotency, missing target,
rollout, session, network, and server-unavailable outcomes never synthesize success. After every
server decision the controller refetches both the inbox and commitments. A competing pending row
remains pending when capacity is occupied, but its actions are disabled until authoritative
reconciliation; it is never auto-declined or auto-accepted.

### Recovery, session, and concurrency boundary

Commitments are recovered independently from current urgent-CABINET capability whenever the same
authenticated Doctor still has an exact Cabinet context. Startup, app resume, explicit refresh,
decision completion, runtime OFF, and capability refresh preserve or revalidate the active
responsibility. The shell keeps the `Urgences > Cabinet` route available while that responsibility
is visible. A later `CANCELLED` or `INVALIDATED` commitment removes the accepted responsibility;
a transient commitment-read failure does not silently erase the last verified active one.

All request, detail, commitment, and decision reads are fenced by account/context epochs,
generations, exact identities, and Dio cancellation tokens. Logout, account switch, incompatible
Cabinet context, controller clear, and disposal cancel work, clear the in-memory idempotency-key
registry, and prevent late responses from repopulating the next session. HTTP 401/403 invokes the
protected-flow exit boundary. Nothing is persisted to preferences or secure storage, and no
request, commitment, Patient data, token, or idempotency key is logged.

### P4-CAB-03A files

Added:

- `lib/features/doctor/urgent_cabinet/doctor_urgent_cabinet_commitment.dart`
- `lib/features/doctor/urgent_cabinet/doctor_urgent_cabinet_commitment_source.dart`
- `lib/features/doctor/urgent_cabinet/doctor_urgent_cabinet_repository.dart`
- `test/doctor_urgent_cabinet_backend_integration_test.dart`

Integrated without redesign:

- `lib/features/doctor/doctor_auth_shell_screen.dart`
- `lib/features/doctor/shell/doctor_app_shell.dart`
- `lib/features/doctor/urgent_cabinet/doctor_urgent_cabinet_controller.dart`
- `lib/features/doctor/urgent_cabinet/doctor_urgent_cabinet_decision.dart`
- `lib/features/doctor/urgent_cabinet/doctor_urgent_cabinet_decision_source.dart`
- `lib/features/doctor/urgent_cabinet/doctor_urgent_cabinet_request.dart`
- `lib/features/doctor/urgent_cabinet/doctor_urgent_cabinet_request_source.dart`
- `lib/features/doctor/urgent_cabinet/doctor_urgent_cabinet_screen.dart`
- `lib/features/doctor/urgent_cabinet/doctor_urgent_cabinet_request_card.dart`
- `lib/features/doctor/urgent_cabinet/doctor_urgent_cabinet_request_sheet.dart`
- `lib/features/doctor/urgent_cabinet/doctor_urgent_cabinet_accepted_card.dart`
- `lib/features/doctor/urgent_cabinet/doctor_urgent_cabinet_accepted_sheet.dart`
- `test/doctor_urgent_cabinet_request_test.dart`
- `test/doctor_urgent_cabinet_decision_test.dart`
- `test/doctor_urgent_cabinet_accepted_test.dart`

### P4-CAB-03A verification

- Focused repository/controller, request-model/source, HOME commitment-isolation, Doctor workspace,
  and P3 scheduled-care realtime tests: **93/93 passed**.
- Exact affected production and integration-test analyzer: **0 issues**.
- Automated widget, browser, emulator, and physical-device UI tests were intentionally not run.
- Backend, Patient Flutter, Angular, Clinic, MRS, Maps, and package configuration were not changed.

### P4-CAB-03A manual synthetic procedure

1. Sign in as a synthetic-development Doctor whose workspace has an exact Cabinet and urgent
   CABINET capability. Open **Urgences > Cabinet** and verify the shell and segmented control are
   visually unchanged.
2. With no targeted rows, refresh and verify the authoritative empty state contains no demo card.
   Then seed two targeted synthetic rows and verify both retain distinct request IDs, triage,
   exact fee, and masked Patient copy.
3. Open each card and verify an exact detail GET occurs before the sheet appears. Confirm there is
   no Patient name, phone, history, destination, HOME hold, notification, or countdown claim.
4. Double-click **Accepter**, then race accept against decline. Verify only one logical command is
   in flight and its body uses the displayed server revision. Drop one response and retry only the
   identical action; verify the same idempotency key and a replayed authoritative outcome.
5. Accept one request. Verify it becomes a confirmed CABINET responsibility, the other pending
   request is not relabelled terminal, and its actions are disabled while capacity is occupied.
6. Decline a separate request and verify no commitment is created. Repeat with stale revision,
   not-actionable, eligibility-change, capacity-conflict, missing-target, 401/403, offline, and 5xx
   responses; verify none appears accepted.
7. Background/resume, refresh the workspace, switch CABINET runtime OFF, and remove the permanent
   capability while retaining the same Cabinet. Verify the active commitment remains accessible
   and is revalidated from the commitment list/detail APIs.
8. Return a terminal commitment and verify the accepted responsibility disappears. During a
   transient commitment-read failure, verify the last confirmed responsibility is not falsely
   converted to empty.
9. Start delayed inbox/detail/commitment/decision calls, then log out and switch accounts before
   releasing them. Verify no card, accepted responsibility, key, or masked context reappears.
10. Open the accepted sheet and verify server-backed data cannot launch arrival or QR. Confirm
    HOME navigation, HOME commitment recovery, P3 Agenda, booking requests, appointments, and
    scheduled-care realtime still behave independently.

No automated widget, browser, emulator, or physical-device UI test was run for this milestone.
Manual visual/device certification remains required. Real Patient submission, realtime/FCM/SMS,
arrival, QR, consultation, clinical handoff, MRS, Maps navigation, and Patient tracking remain out
of scope.

## P4-CAB-03B-03 Patient lifecycle boundary

The Patient urgent CABINET flow now has a session-scoped authoritative lifecycle controller behind
the existing frozen screens. Strict request snapshots map `PENDING` to waiting, `ACCEPTED` only to
the confirmed Doctor/Cabinet/fee screen, and `DECLINED`, `CANCELLED`, and `EXPIRED` to distinct
recovery outcomes. An accepted service snapshot cannot enter the development arrival or QR routes.
Malformed identities, revision rollback, impossible commitment shapes, missing recovery authority,
and unavailable reads fail closed without invoking local Doctor-decision fixtures.

While the waiting route is foregrounded, reads are serialized and bounded to a 20-second cadence,
with immediate reconciliation on route entry, app resume, an exposed reconnect signal, and the
server deadline. The displayed deadline uses `responseDeadlineAt` relative to `evaluatedAt`; the
client clock never creates `EXPIRED`. Polling stops on a terminal response, route disposal, or
session invalidation. Transient network failures retain bounded reconciliation so restored
connectivity can recover authority.

Patient cancellation is available only for an exact pending snapshot whose `allowedActions`
contains `CANCEL`. The command carries the current response, attempt/request, and journey revisions
plus a dedicated retained idempotency key. Only one mutation may run. Any failure or conflict is
followed by an exact status read before presentation changes, so a concurrent Doctor acceptance is
preserved. Closing the waiting screen does not send cancellation.

Restart recovery checks the opaque account-scoped receipt before the active request for the exact
SELF/FAMILY_MEMBER subject. Terminal receipt authority is retained until the Patient deliberately
starts another journey. Logout, account switch, authorization loss, and family ownership revocation
cancel work, fence stale callbacks, clear all route projections and clinical draft state, and clear
the applicable secure receipt. No sensitive request or clinical values are logged or persisted.

Patient submission is still explicitly OFF: the confirmation action retains `const canSubmit =
false`, `UrgentCabinetSubmissionActivationGate.p4Cab03B02` retains all four false authorities, and
`back-trap-upper` remains unmapped. The lifecycle was certified with injected synthetic repository
responses only; no shared database or live backend request was used.

## P4-CAB-03D normal local-development integration

P4-CAB-03D connects the existing Patient and Doctor CABINET surfaces to the normal `lib/main.dart`
application and the normal local Spring Boot service. The Patient sequence is now locked to SELF or
authorized family member, the existing anatomical/pain/description intake, authoritative Doctor
discovery, the exact Doctor/Cabinet detail and fee, confirmation, waiting, and the authoritative
outcome. Explicit preview sources retain their isolated historical navigation so they cannot be
mistaken for the normal service path.

The normal submission gate opens only when all independent Flutter local-development authorities
are present and the API base URL is loopback. The backend separately requires the `local` Spring
profile, database `omnicare`, the CABINET local-development authorization mode, runtime and
database latches, approved Patient and Doctor allowlists, a five-minute response deadline, the
30-second expiry worker, and valid protected-intake key configuration. HOME activation remains
independent. Default and production configuration remain closed.

Anatomical categories, pain, and the short description are stored through the protected triage
envelope rather than as plaintext operational columns. The Doctor receives only the targeted
request projection and short description required for the decision. `back-trap-upper` remains
unmapped and therefore fails closed. Submission revalidates the exact Doctor, Cabinet, fee, and
configuration/runtime/location revisions and uses the existing retained idempotency key and
receipt-recovery boundary.

Acceptance atomically creates one exclusive CABINET commitment and captures an immutable committed
Doctor/practice/address/coordinate snapshot. Patient refresh therefore displays the committed
Cabinet rather than mutable current practice data. Valid coordinates expose only an external
directions action; no ETA or route is invented. Authoritative acceptance exposes no arrival, QR,
consultation, prescription, or MRS action. Doctor runtime OFF does not erase an existing
responsibility.

The local activation defines for both normal Patient and Doctor browser sessions are:

```text
--dart-define=OMNICARE_API_BASE_URL=http://127.0.0.1:8080
--dart-define=OMNICARE_P4CAB_LOCAL_DEVELOPMENT_AUTHORIZED=true
--dart-define=OMNICARE_P4CAB_LOCAL_BACKEND_LIFECYCLE_READY=true
--dart-define=OMNICARE_P4CAB_NORMAL_DATABASE_AUTHORIZED=true
--dart-define=OMNICARE_P4CAB_LOCAL_WAITING_RECOVERY_INTEGRATED=true
```

Use `lib/main.dart` on ports 7357 and 7358 for isolated Patient and Doctor browser sessions. This
is local-development authorization only. Production still requires a certified external key
provider, production audit certification, MRS authorization/certification, rollout governance, and
production operational testing.

P4-CAB-05 remains separately fail-closed at backend startup and requires the operational settings
documented below. Full manual lifecycle testing remains deferred until the remaining P4
integrations are complete.

## P4-CAB-05 post-acceptance operational lifecycle

P4-CAB-05 extends the accepted commitment; it does not replace the request, journey, attempt,
capacity, recovery, or frozen screen architecture. The Patient continues to receive the immutable
committed Doctor, Cabinet, address, coordinates, fee, and directions from the existing accepted
projection. Browser refresh and reconnect re-read server authority. No locally cached lifecycle
status or QR token is treated as authorization.

### Patient withdrawal

An accepted, not-yet-arrived Patient may use the dedicated **Je ne peux plus venir** action. The
command is `POST /api/v1/me/urgent-cabinet/requests/{requestId}/withdraw`, with a mandatory retained
idempotency key and the exact response, attempt, journey, and commitment revisions. The backend
re-resolves SELF/family ownership, locks the existing lifecycle authority, cancels the exact active
commitment and request, terminalizes the attempt and journey, and releases only the matching
CABINET capacity claim/token/fence. A conflict or ambiguous transport failure is followed by an
authoritative status read; Flutter never fabricates withdrawal.

The preserved request terminal reason is `PATIENT_WITHDREW_AFTER_ACCEPTANCE`. The commitment and
its immutable practice snapshot remain historical records; no row is deleted or recreated.
Withdrawal is unavailable after arrival verification so it cannot race a verified on-site handoff.

### Arrival QR handoff

The Patient requests a handoff with
`POST /api/v1/me/urgent-cabinet/requests/{requestId}/arrival-handoffs`. The server issues an
`OCAB1` HMAC-SHA256 token bound to one handoff, commitment, request, targeted Doctor, and
operational Patient. The default lifetime is five minutes, with at most three minutes of accepted
clock skew. Only the SHA-256 token digest and operational bindings are stored. The returned token
is held in memory for QR rendering and is cleared on logout, account replacement, new recovery,
withdrawal, or authoritative arrival. It is never written to preferences, secure storage, logs,
or audit payloads.

The authenticated targeted Doctor verifies scanner-read content with
`POST /api/v1/me/urgent-cabinet/commitments/{commitmentId}/arrival-verifications`. The body carries
only the token and expected commitment revision; the Doctor identity comes from the session. HMAC
tampering, wrong Doctor/commitment/request/Patient bindings, future-issued tokens, expiry, stale
revision, and prior consumption fail closed. The handoff row is locked and conditionally consumed
once in the same transaction that records `arrival_verified_at/by`, completes the idempotency
receipt, and writes audit evidence. A completed identical command replays its recorded result;
another command cannot consume the handoff again.

The current web-compatible frozen sheet accepts content supplied by a QR reader/manual scanner
input. The historical simulated camera preview remains debug-only and cannot produce success.
Adding a native camera-decoder package is a separate device-integration decision; it is not an
authorization bypass and does not block server-authoritative verification with scanner-read data.

### Capacity, recovery, and audit boundary

Arrival verification leaves the exclusive Doctor capacity in `CABINET_COMMITMENT`, keeps the
journey and attempt committed, and exposes no new Patient or clinical data. It returns explicit
`consultationStarted: false` and `mrsAccessGranted: false`. Consultation start and clinical/MRS
authorization belong to P4-CAB-06.

Successful withdrawal, handoff issue, and arrival verification each write a privacy-minimized
transactional audit-outbox event. The payload contains operational IDs, controlled lifecycle
values, revisions, and server times; it excludes QR tokens, idempotency keys, symptoms, names,
addresses, coordinates, credentials, and clinical payloads. A failed transition rolls back its
receipt, mutation, and audit evidence together.

There is deliberately no automatic no-show timer, Doctor cancellation, administrative override,
or capacity release after arrival. The time threshold, authorized actor, reason taxonomy,
notification/escalation requirements, and effect on capacity are unresolved policy decisions. The
implementation therefore retains capacity until an already authorized terminal transition occurs.

The backend operational gate defaults OFF. Local development additionally requires the existing
CABINET local authorization/database latches plus:

```text
OMNICARE_URGENT_CABINET_OPERATIONAL_ENABLED=true
OMNICARE_URGENT_CABINET_ARRIVAL_TOKEN_TTL=5m
OMNICARE_URGENT_CABINET_ARRIVAL_CLOCK_SKEW=3m
OMNICARE_URGENT_CABINET_ARRIVAL_HMAC_KEY_B64=<base64 of at least 32 random bytes>
```

Production/default configuration remains closed. The HMAC secret is backend-only and its
configuration object redacts it from string output.

### P4-CAB-05 files and verification boundary

Backend additions are migration `0530-p4-cabinet-post-acceptance-lifecycle.yaml`, the operational
properties/validator, token codec, store/service, Patient and Doctor operational controllers and
DTOs, plus the three lifecycle audit events. Existing targeted request and commitment projections
now expose `arrivalVerifiedAt` and closed operational actions.

Flutter extends the existing Patient lifecycle/repository, accepted confirmation, arrival
instructions/QR presentation, Doctor commitment repository/controller, and frozen accepted/check-in
sheet. It introduces no parallel flow shell, HOME/P3 mutation, clinical route, or persisted token
store.

Automated verification covers startup fail-closed behavior, HMAC tamper and binding checks,
ownership, revision fencing, exact capacity release, atomic single-use consumption, replay,
expired/consumed/wrong-context rejection, non-clinical arrival results, logout clearing, rapid-tap
deduplication, refresh reconciliation, transactional audit calls, and representative CABINET,
HOME, and P3 regressions. No application, browser, database, Docker service, request submission, or
real QR scan is started by this milestone.

Final automated results on Java 21 and the repository's configured Flutter SDK:

- Backend focused lifecycle/security/audit plus representative HOME and P3 regressions: **67/67
  passed**.
- Flutter CABINET/Doctor/HOME/navigation/activation/recovery regression bundle: **430/430
  passed**.
- Scoped Flutter analysis for the affected implementation and tests: **0 issues**.

Migration `0530` was inspected and source-tested but was not applied to any database during this
milestone. It must be applied through the normal reviewed deployment/startup process before the new
runtime endpoints can be exercised.

## P4-CAB-NOTIF-01 authoritative notifications

Urgent CABINET now reuses Module 12's durable notification outbox, permanent intent keys, inbox,
private realtime invalidation, device-token registry, FCM dispatcher, bounded retry/dead-letter
handling, and notification preferences. No second delivery architecture is introduced.

Submission stages one `URGENT_CABINET_REQUEST_TARGETED` intent for the exact targeted Doctor inside
the same transaction as the request, receipt, and audit event. Its outbox expiry is the request's
authoritative response deadline. A delivery-time guard rechecks Doctor identity, `PENDING`,
`CABINET_PENDING`, active journey, and the server deadline before either inbox or push delivery.
Acceptance, decline, expiry, pending cancellation, and accepted withdrawal cancel only an unsent
Doctor offer intent and stage one account-owned Patient outcome intent in their existing lifecycle
transaction. Permanent keys (`type:request:recipient`) suppress replay duplicates. Push and inbox
payloads contain only destination, request UUID, and controlled outcome; symptoms, descriptions,
pain, anatomical areas, Patient names, and other clinical/identity projections are excluded.

The Flutter notification center recognizes these types only for the correct role. Patient taps
resolve the request again through the authenticated owner-scoped status API before projecting the
existing CABINET flow, including the backend-provided SELF/family subject. Doctor taps first refresh
the authenticated targeted inbox and expose a decision sheet only while the request remains
actionable. Foreground local alerts and background/cold-start push taps carry only the opaque request
UUID into those same role-bound recovery paths; they never trust the pushed outcome as authority.
Expired inbox links are unavailable. Logout/account replacement clears notification state and
foreground-alert deduplication state.

Authenticated realtime invalidations fetch the durable inbox row before showing a foreground
SnackBar/local alert, so localized copy and routing data come from the server-owned notification.
Mobile local alerts use the existing `omnicare_critical`/`omnicare_high` channels with sound and
vibration where the OS and user permissions allow. The backend sends high-priority Android/APNs
notification messages with default sound, a collapse/thread key, and bounded Android/APNs expiry.
Neither browser audio nor OS delivery can override browser, device, DND, battery, or permission
restrictions.

Flutter mobile push registration uses Firebase Messaging only after authentication and deactivates
the account-owned token on session stop. Firebase absence fails closed to the durable REST inbox and
private realtime fallback. Real mobile delivery requires separately provisioned Firebase platform
configuration (`flutterfire configure`, Android/iOS app registration, APNs capability/key for iOS)
and backend Admin SDK credentials. SMS remains disabled because the existing `SmsDispatcher` is a
stub and no authorized provider is configured.

Migration `1209-urgent-cabinet-notification-templates.yaml` adds only the six notification template
rows and is included append-only after `1208`; it is authored but not applied by this task. No
request, commitment, capacity, audit-history, P3, HOME, consultation, QR, or MRS schema/business
rule is changed.
