# G-2 · 1a-3 — Urgent CABINET: tolerant parsing (C4, C5, C6), one « indisponible » mapping (C9), 120-character search (C8)
_Date: 2026-11-11 · Branch: `feature/g2-flutter-hardening` · Roadmap v1.2 §3 Phase 1a item 3 · Inventory rows C4, C5, C6, C8, C9 (§a.5)_
_Testing rule (CTO): automated tests cover logic only; screens are tested by hand (§8)._

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

| # | Deliverable | Status after 1a-3 |
|---|---|---|
| 1 | Roadmap | ✅ done (v1.2) |
| 2 | Patient app wired | 🔨 Phase 1a: C1, C3 (+guard), C4–C6, C8, C9 delivered (not yet committed); 1a-4, 1a-5 to do |
| 3 | Report per step | 🔨 5 reports (P0, 1a-1, 1a-2, 1a-2b, 1a-3) |
| 4 | Prompts | ✅ done |

**Result:**
- An unknown server value no longer makes the whole urgent-CABINET snapshot fail to parse. The snapshot is parsed, marked *unrecognized*, and shown as the existing « indisponible » state.
- Three backend values the app did not know are now mapped to existing screens, each justified by backend code: `CABINET_CREATED`, `LEGACY_LIFECYCLE_REMEDIATION`, and arrival with an ABORTED consultation.
- Search and detail show the same « indisponible » message for the real backend refusal codes, and the dead 403 branch is gone.
- The search query is capped at 120 characters.
- Not touched (as instructed): `amountTnd` (Phase 7) and the production activation gate (decision #3).

## 2. Plan findings (step 1): what each unknown value means in the backend

| Value | Backend evidence | Meaning | Treatment on the EXISTING screens |
|---|---|---|---|
| `CABINET_CREATED` (`UrgentAttemptState`) | Initial state of a new attempt (`UrgentAttempt.java:36`). Its only transitions are → `CABINET_PENDING` or `CABINET_CANCELLED` (`:63`). The patient request writer moves it to `CABINET_PENDING` **before the first save**, in the same transaction (`UrgentCabinetTargetedWriter.java:137-142`). If it were ever read, `patientActions` would return `[]`, because CANCEL requires `CABINET_PENDING` (`UrgentCabinetTargetedService.java:507-516`) | Transient **pre-pending** state, never persisted for a targeted request | Accepted only in the pending shape with no action → existing **waiting (pending)** screen. Cancel is not offered because the server offers no CANCEL. If CANCEL came with it, that would be incoherent → FormatException (contract violation, not an unknown value) |
| `HOME_CREATED` … `HOME_CANCELLED` | DB check `chk_urgent_attempt_mode_state`: a CABINET attempt only holds `CABINET_%` states (`0508-p4-urgent-operational-foundation.yaml:74-76`). Targeted requests reference only the CABINET attempt created with them | **Cannot occur** on this endpoint | `unknown` → existing « indisponible » |
| `LEGACY_LIFECYCLE_REMEDIATION` (`UrgentCabinetTerminalReason`) | DB allows it only with `response_status='CANCELLED'`, no answer and no commitment (`0530-p4-cabinet-post-acceptance-lifecycle.yaml:72-76`; added by `0528` as "inert legacy-remediation reason support"). **No Java code writes it** | Administrative closure of a legacy request, before any answer. The backend reports `responseStatus = CANCELLED` | Accepted in the "cancelled before answer" shape. The screen is chosen by `responseStatus` → existing **cancelled** recovery screen (« Votre demande a été annulée »). See R2 |
| `ARRIVED_WAITING_FOR_DOCTOR` + consultation id + `ABORTED` (C6) | `UrgentCabinetPatientClinicalProjection.phase()` (`:12-28`) falls through to this phase when the commitment is ACTIVE, arrival is verified and the consultation is ABORTED. `Consultation.abort()` (`Consultation.java:165`) has **no production caller**. A new consultation can't be bound afterwards, because binding requires `consultation_id is null` (`UrgentCabinetClinicalSourceStore.java:131-134`) | Backend-authoritative phase: arrived, waiting for the doctor | Accepted → existing **arrived/waiting** state. With IN_PROGRESS, FINALIZING or COMPLETED this phase is still incoherent (FormatException). COMPLETED with an ACTIVE commitment can't be observed: `complete()` runs inside the finish transaction (`Propagation.MANDATORY`, `UrgentCabinetClinicalSourceStore.java:147`). See R3 |
| Any other unknown `responseStatus` / `state` / `commitmentStatus` / `terminalReason` / `clinicalPhase` / consultation status | — | Not knowable | Snapshot parsed with `isRecognized = false`, the combination is not validated, and the repository reports it as today's `invalidResponse` → the existing « indisponible » state (no guess) |
| An unknown entry in `allowedActions` | — | An action this app cannot offer | **Ignored.** The known actions are still validated exactly as before (a new backend action no longer blanks the whole feature). Duplicates are still rejected |

Nothing required a clinical or lifecycle guess, so there was no STOP.

**C9: discovery error codes** (`UrgentCabinetTargetedAccessPolicy.java:23-50`, used by search, facets and detail):
- `URGENT_CABINET_REQUEST_UNAVAILABLE` (runtime or development gate closed) and `URGENT_CABINET_REQUEST_NOT_AUTHORIZED` (account not allow-listed). Both are **404**, body key `code` (`CareCapabilityProblemDetailHandler.java:109`).
- `URGENT_CABINET_DIRECTORY_ENTRY_NOT_FOUND` is a 404 for a missing doctor or cabinet.
- `URGENT_RUNTIME_DEVELOPMENT_ONLY` / `URGENT_RUNTIME_ACCESS_DISABLED` (the 403 the app expected) **exist nowhere in the backend**.
- Before this change, search and facets turned any 404 into the "development gate" kind, with copy « Service de développement indisponible ». Detail turned it into « Médecin introuvable », and its "unavailable" copy (« Service bientôt disponible ») was reachable only through the dead 403 branch.

## 3. What changed

| File | Change |
|---|---|
| `lib/features/emergency/urgent_cabinet/urgent_cabinet_targeted_request_models.dart` | Every server enum has an explicit `unknown` (one generic `_parseOrUnknown`, no `FormatException` for a value). New values `cabinetCreated` and `legacyLifecycleRemediation`. `isRecognized` on the snapshot. The combination and clinical validation run only on recognized snapshots, via `_validateRecognizedState`; structural checks (ids, timestamps, fee, coordinates) always run. Pending accepts `CABINET_CREATED` with no action, cancelled-before-answer accepts the legacy reason, and the arrived phase accepts an ABORTED consultation. Unknown actions are dropped (`_knownActions`). All switches are exhaustive |
| `…/urgent_cabinet_targeted_request_repository.dart` | `_parse` reports an unrecognized snapshot as `unrecognizedSnapshot`: the same kind and message as an unparseable response, so screens behave exactly as today for unknowns |
| `…/urgent_cabinet_patient_lifecycle_controller.dart`, `…/urgent_cabinet_flow_controller.dart`, `…/urgent_cabinet_flow_shell.dart`, `…/urgent_cabinet_request_confirmation_screen.dart` | Exhaustive switches gained an `unknown` arm (unavailable / recovery). These arms are **unreachable**, because the repository never returns an unrecognized snapshot |
| `…/urgent_cabinet_discovery_repository.dart` | Kind `developmentGateUnavailable` replaced by `featureUnavailable`: a 404 with one of the two gate codes, or any 404 on a collection route (facets, search). The **dead 403 branch is removed** (any 403 → `forbidden`). Detail keeps `notFound` for other 404s |
| `…/urgent_cabinet_doctor_directory_screen.dart`, `…/urgent_cabinet_doctor_detail_screen.dart` | Both show **the same** text for `featureUnavailable` (see R1). Detail also maps the gate codes to its existing unavailable state during the pre-confirmation re-check (before: a snackbar) |
| `…/urgent_cabinet_request_confirmation_screen.dart` | `isNotFound \|\| isFeatureUnavailable` → existing « Tarif urgent indisponible » state, so behaviour is unchanged for the gate codes (before, they arrived as `notFound`) |
| `…/urgent_cabinet_discovery_models.dart` | `urgentCabinetSearchQueryMaxLength = 120`, `urgentCabinetSearchInputFormatters` (official `LengthLimitingTextInputFormatter`), and `clampToUtf16Length`. The request body's `query` is clamped to 120 UTF-16 units (what Java `@Size` counts) without splitting a character |
| `lib/features/patient_doctor/presentation/widgets/doctor_search_field.dart` | Optional `inputFormatters` parameter (default `null`, so the regular doctor directory is unchanged). No counter, no layout change |
| `lib/core/l10n/pending_fr_strings.dart` | `urgentCabinetUnavailableTitle` / `…Message` (moved to ARB in Phase 1b) |
| `test/urgent_cabinet_tolerant_parsing_test.dart` (new, 40 logic tests) | see §4 |
| `test/urgent_cabinet_targeted_submission_test.dart` | One existing assertion encoded the old contract (`responseStatus: 'WAITING'` → FormatException). It now asserts "parsed, not recognized". The second half (an impossible combination of known values throws) is unchanged |

Not touched: `amountTnd`, `UrgentCabinetSubmissionActivationGate`, `lib/features/doctor/**`, backend repos, pubspec.

## 4. Evidence
| Check | Result |
|---|---|
| `flutter analyze` | 388 issues. Set difference against the baseline: **0 new, 0 removed** (two intermediate infos fixed: an unbraced `if` and an unneeded import) |
| `flutter test` (full) | **1,809 passed, 7 skipped, 0 failed** (1,769 + 40 new) |
| `dart format` on touched files | clean |
| **Mutation check:** removed the repository gate, reverted the C6 rule and the C9 code mapping; ran the new file; restored | **6 failures** as expected (C6 parse; three repository tests; C9 for both gate codes). Restored: 40/40 |

**New tests (logic only, `test/urgent_cabinet_tolerant_parsing_test.dart`):**
- **Enum tables (6):** every known wire value of `responseStatus`, `state` (including all six `HOME_*` → `unknown`), `terminalReason`, `commitmentStatus` and `clinicalPhase`, plus unknown → `unknown` for each.
- **Whole-snapshot tolerance (12):** seven snapshots, each with one unknown field (HOME state, unknown state, status, reason, phase, commitment status, consultation status), all parse with `isRecognized = false`. An unknown action is ignored while CANCEL is kept. Duplicate actions still fail. An incoherent combination of known values still fails. A malformed id still fails.
- **C4 (2):** pending with `CABINET_CREATED` and no action → recognized pending; with CANCEL → incoherent.
- **C5 (2):** cancelled before answer with the legacy reason → recognized, terminal; the legacy reason after an acceptance → incoherent (the DB forbids it).
- **C6 (5):** arrived + ABORTED → recognized, with the consultation id; arrived without a consultation → fine; arrived + IN_PROGRESS / FINALIZING / COMPLETED → still incoherent.
- **Repository (3)**, through the real `AppHttpClient`: a `HOME_HELD` snapshot → `invalidResponse`, **the same kind as a malformed body**; the legacy and aborted cases come through as snapshots.
- **C9 (5):** both gate codes → `featureUnavailable` on **search, detail and facets**; detail `URGENT_CABINET_DIRECTORY_ENTRY_NOT_FOUND` → `notFound`; a search 404 without code → `featureUnavailable`; 403 with either old code or any other → `forbidden`.
- **C8 (5):** the formatter truncates a 200-character paste to 120; 120 characters pass; the body never exceeds 120 UTF-16 units; the clamp never splits an emoji; short queries are only trimmed.

## 5. Contract table
| Method | Path | Request | Response used | Error codes → app |
|---|---|---|---|---|
| GET | `/me/urgent-cabinet/requests/{id}` (+ `/active`, `/recovery`; same snapshot from POST create, cancel, withdraw) | unchanged | `UrgentCabinetTargetedRequestResponse`: `state`, `responseStatus`, `terminalReason`, `commitmentStatus`, `clinicalPhase`, `consultationStatus`, `allowedActions` now parse tolerantly (§2) | unchanged mapping; unknown values → `invalidResponse` (« indisponible ») |
| POST | `/me/urgent-cabinet/discovery/search` | `query` ≤ 120 UTF-16 units (backend `@Size(max=120)`) | unchanged | 404 any (collection) → `featureUnavailable`; 403 → `forbidden` |
| GET | `/me/urgent-cabinet/discovery/facets` | — | unchanged | same as search |
| GET | `/me/urgent-cabinet/discovery/doctors/{d}/practice-locations/{l}` | — | unchanged | 404 `URGENT_CABINET_REQUEST_UNAVAILABLE` / `…_NOT_AUTHORIZED` → `featureUnavailable`; other 404 (e.g. `URGENT_CABINET_DIRECTORY_ENTRY_NOT_FOUND`) → `notFound`; 403 → `forbidden` |

## 6. Complexity and memory
- Parsing stays O(fields). The unknown fallback is O(enum size ≤ 7) per field, and action filtering is O(actions ≤ 3).
- The clamp is O(query length ≤ the 120 the field already allows).
- No new state, caches, timers or streams. Polling behaviour is unchanged (unknowns follow today's invalid-response path).

## 7. Risks, open questions, things not done
- **R1. Copy choice (CTO to confirm).** Search and detail now share « **Service indisponible** — La demande urgente au cabinet n’est pas disponible pour le moment. » The two previous texts were different and said "développement" / "environnement", which is jargon and false in production. If you prefer other wording, it is one constant in `pending_fr_strings.dart`.
- **R2. Legacy closure uses the cancelled screen.** The visible title and message (« Votre demande a été annulée », « L’annulation a été confirmée… ») are true for an administrative cancellation. But the screen-reader label of that state says « annulée par le Patient », which would be wrong for this rare case. I did not change it (no reason-specific copy without a design decision).
- **R3. Aborted consultation leaves the patient "waiting" (backend, G-1).** After an abort, the commitment stays ACTIVE with the aborted consultation bound, and binding a new one requires `consultation_id is null`. So the patient would show « arrivé, en attente du médecin » with no way forward. `abort()` has no caller today, so this cannot happen yet. **Report to the G-1 chat before any abort path ships.**
- **R4.** `CABINET_CREATED` and `HOME_*` can't be produced by the current backend. Their handling is defensive and covered by logic tests only.
- **R5.** `URGENT_RUNTIME_UNAVAILABLE` (a 404 code) is not produced by discovery (the access policy converts runtime denial into `URGENT_CABINET_REQUEST_UNAVAILABLE`). On collection routes it would still be `featureUnavailable` (any 404); on detail it would be `notFound`.
- Not done (by design): `amountTnd` as a decimal string (Phase 7); the activation gate (decision #3); the urgent-cabinet English/jargon strings beyond the two messages above (Phase 1b).

## 8. Path to deliver G-2
1. **CTO:** run the manual steps (§9), confirm the R1 wording, and pass R3 to G-1. Then commit 1a-1 → 1a-3.
2. **Run 1a-4:** `NO_SHOW` status with a French label and terminal semantics (C10). Record C11 (schedule-proposal accept/reject) as a design gap.
3. **Run 1a-5:** backend `notification` module sends the semantic `type` and a separate `templateType` (F7). Then Phase 1b.

## 9. Manual test steps for the CTO
Use a staging backend and a test patient account. The urgent CABINET backend runs only in local-development mode with allow-listed accounts (`UrgentCabinetTargetedAccessPolicy`), so on a normal staging account steps 1–2 show the « indisponible » path. That is the C9 case.

1. **Search shows the shared « indisponible » (C9).**
   - Accueil → **« Demande urgente »** → **« Urgence au cabinet »** → **« Demande pour moi »** → **« Continuer »** → fill the short clinical form → go on to the doctor list.
   - Expected: title **« Service indisponible »**, message **« La demande urgente au cabinet n’est pas disponible pour le moment. »**. Before this change: « Impossible de charger les médecins. » / « Service de développement indisponible ». No layout change.
   - Send back: a screenshot.
2. **Detail shows the same text (C9), optional.** Only possible if the list loads for your account but the gate closes before you open a doctor (for example, remove the account from the allow-list between the two taps).
   - Expected on the doctor page: the **same** « Service indisponible » title and message.
   - Send back: a screenshot, or "skipped".
3. **Search limit (C8)**, on a backend where urgent CABINET is enabled for the account (local development):
   - On the doctor list, paste a text longer than 120 characters into « Rechercher un médecin ».
   - Expected: the field keeps the first 120 characters, there is no counter, the list does not show the old « invalid response » error, and the field looks the same as before.
   - Send back: a screenshot after the paste.
4. **Normal flow regression (enabled backend):**
   - Pick a doctor → send a request. Expected: the waiting screen, as before.
   - Then cancel it. Expected: the recovery screen « Votre demande a été annulée ».
   - Send back: two screenshots.
5. **Not manually reproducible (FYI):** `HOME_*`, `CABINET_CREATED`, `LEGACY_LIFECYCLE_REMEDIATION` and an aborted consultation can't be produced through the app or the current backend flows. They are covered by the logic tests in §4. Reply "OK" if that is acceptable, or ask for a local-only synthetic data script.
