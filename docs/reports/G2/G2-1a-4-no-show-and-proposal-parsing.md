# G-2 · 1a-4 — NO_SHOW request status (C10), schedule-proposal parsing without UI (C11), onboarding "already saved" message
_Date: 2026-11-11 · Repo: OmniCare-App only (backend read only) · Rows: inventory C10, C11; 1a-6 R1_
_Testing rule (CTO): automated tests cover logic only; screens are tested by hand (§9)._

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

| # | Deliverable | Status after 1a-4 |
|---|---|---|
| 1 | Roadmap | Done (v1.2) |
| 2 | App connected | Phase 1a: 1a-1, 1a-2/2b, 1a-3, 1a-6, dev WebSocket origins and now 1a-4 are done (uncommitted). 1a-5 (push semantic type) is left. |
| 3 | Reports | This file |
| 4 | Prompts | Unchanged |

**Result:**
- **NO_SHOW** is now a known, final status labelled « Rendez-vous manqué ».
- The **schedule proposal and the accept/reject actions** are parsed into the model. No UI uses them (design gap, R2).
- **Onboarding** now says « Ces informations sont déjà enregistrées… » when a patient changes an already-saved page and presses « Continuer ». Nothing is sent, as before.
- **Checks:** `flutter analyze` shows the same 388 issues as the baseline (0 new). `flutter test`: 1848 passed, 7 skipped (+20 new tests).

## 2. Plan findings (step 1)

### a) Where a request status is parsed, labelled, filtered and turned into actions
| Concern | Where | Rule |
|---|---|---|
| Parse | `request_vocabulary.dart:78-117` (`PatientRequestStatus.parse`), called from `request_models.dart` (list item and detail) | Unknown string → `unknown` |
| Final or not | `PatientRequestStatus.isTerminal` (`request_vocabulary.dart:104`), mirrors the backend `isTerminal()` | Hides « What happens next » (`patient_request_detail_screen.dart:129`) |
| Label, colour, icon | `RequestStatusCopy.of` (`request_status_copy.dart:29`), used by the list card (`my_requests_screen.dart:159`) and the detail status card | One entry per status |
| Journey | `PatientRequestJourneyMapper.fromStatus` (`patient_request_journey.dart:52`) | Final statuses stop the timeline (`_terminal`) |
| Active vs past | **Server-side.** The filter chips send `filter=` (`PatientRequestListFilter`). The backend `PatientRequestListFilter.CANCELLED_DECLINED` already contains `NO_SHOW` and `ACTIVE` does not. | The app has no client-side split, so there was nothing to change here |
| Actions | Server-driven `availableActions`: Cancel button only if `CANCEL` is present (`patient_request_detail_screen.dart:138`, `patient_requests_controller.dart:158`); the information form only if `PROVIDE_INFORMATION` is present (`request_models.dart:169`) | Unknown actions are dropped |

### b) What NO_SHOW means in the backend
- **Who sets it.**
  - Only clinic staff can set it, with the `CLINIC_NO_SHOW_RECORD` capability, through `POST /api/v1/clinics/{clinicId}/cases/{caseId}/no-show` (`ClinicCaseController.java:124`).
  - The call chain is `ClinicCaseCancellationService.recordNoShow` (`:142`), then `PatientRequestStatusProjectionService.recordNoShow` (`:128`), then `AppointmentRequest.recordNoShow` (`:329`).
- **When.**
  - The request must be **CONFIRMED** and the patient must not have arrived.
  - The confirmed start time plus the clinic's grace period must be over.
- **Final.**
  - `PatientRequestStatus.isTerminal()` includes `NO_SHOW`, so `PatientRequestAction.availableFor` gives no `CANCEL`. The patient therefore has **no action**.
  - The patient also gets the push notification `CLINIC_PATIENT_NO_SHOW_OUTCOME`, whose text is rendered by the server.
- **Before this step, the app showed NO_SHOW as `unknown`.** The status read « Status updated », the request was not final, the « What happens next » card was visible, and the journey said "Refresh for the latest status". The request also looked live although it was over.

### c) The schedule proposal (C11)
- `PatientRequestResponse.scheduleProposal` is a `PatientScheduleReadPort.Summary`. It contains:
  - the proposal: id, change type, status, revision, proposed start, confirmed start, duration, expiry, schedule version, `actionable`;
  - an optional `currentConfirmedSchedule`;
  - an optional `activeDelay`.
- It is built in `ClinicScheduleConvergenceService.findCurrent` (`:102-126`). It is the PROPOSED revision when there is one, otherwise the CONFIRMED one.
- `ACCEPT_SCHEDULE_PROPOSAL` and `REJECT_SCHEDULE_PROPOSAL` are offered only on `WAITING_FOR_CONFIRMATION` or `CONFIRMED` with a proposal the patient can still answer (`PatientRequestAction.java`).
- The app used to drop both the field and the two actions.

### d) Onboarding (1a-6 R1)
- The backend cannot update a step that has already been passed: re-sending the previous step does nothing, and an older step returns 400.
- The controller already skipped those requests (`shouldSendOnboardingStep`), so an edit was lost without a word.
- Allergies and conditions cannot be read back during onboarding (1a-6 R2). The only honest reference is therefore what the page held when it was saved, or what it showed on resume.

## 3. What changed

| File | Change |
|---|---|
| `lib/features/request_core/domain/request_vocabulary.dart` | Adds `PatientRequestStatus.noShow('NO_SHOW')`, now part of `isTerminal`. Adds `PatientRequestAction.acceptScheduleProposal` and `rejectScheduleProposal`. Adds `ScheduleProposalChangeType` and `ScheduleProposalStatus` (each with an `unknown` fallback). |
| `lib/features/request_core/data/request_models.dart` | Adds `PatientRequest.scheduleProposal` (optional). New `PatientScheduleProposal`, `PatientConfirmedSchedule` and `PatientScheduleDelay`, parsed like `informationRequest`: absent or null gives null, a non-object is a contract error, ids and versions are required, enums fall back to unknown. |
| `lib/features/request_history/presentation/request_status_copy.dart` | NO_SHOW entry: French label, description and action line, the `event_busy` icon, and the same slate colours as « Cancelled » (existing palette, existing chip and card). |
| `…/patient_request_journey.dart` | Adds `PatientRequestJourneyTerminal.noShow`. The timeline ends with « Rendez-vous manqué », drawn like the other final statuses. |
| `…/patient_request_detail_screen.dart` | One line: NO_SHOW has no next steps (the switch must be exhaustive). |
| `lib/core/l10n/pending_fr_strings.dart` | `requestNoShowLabel`, `requestNoShowDescription`, `requestNoShowActionMessage`, `onboardingPageAlreadySaved` |
| `lib/features/onboarding/onboarding_progress.dart` | Stores the body each saved page held, as described in the next row. Adds `rememberShownValues` (for resume). `OnboardingSaved.alreadySavedPageEdited` is true only when the page « Continuer » is pressed on (identity, allergies or conditions) is already saved and differs from that reference. Request sending is unchanged. |
| `lib/features/onboarding/onboarding_progress.dart` (reference rule) | The reference is the body that was sent. For a page already saved when the screen opened, it is the body first seen. |
| `lib/features/onboarding/conversational_onboarding_screen.dart` | Shows the message in the existing `SnackBar`, then moves to the next page as before. After the resume pre-fill, records what the saved pages show. `_buildDraft` is split into the provider writes plus a side-effect-free `_readDraft` (same values). |

No layout, style or navigation change: the NO_SHOW chip and card are the existing widgets with an existing colour pair. Not touched: `lib/features/doctor/**`, the backend, and pubspec.

## 4. Evidence
- **New file `test/request_no_show_and_schedule_proposal_test.dart` (11 tests):**
  - NO_SHOW is parsed from the list and the detail.
  - It is final: terminal, the journey ends with `noShow`, and there are no actions or buttons.
  - The `CANCELLED_DECLINED` filter is the one sent.
  - The French label and the same palette as « Cancelled ».
  - An unknown status falls back to `unknown`, not final.
  - A reschedule proposal with its confirmed schedule, delay and the two actions is parsed field by field.
  - An initial proposal without the optional parts.
  - A confirmed schedule.
  - An absent or null proposal, and unknown enums giving `unknown`.
  - A malformed proposal or a missing `proposalId` gives `RequestContractException`.
  - The action wire values.
  - The JSON follows the backend records with Spring's default Jackson output. **It was not captured from a running server.**
- **`test/onboarding_per_step_save_test.dart` (+9 tests):**
  - Changing identity, allergies or conditions after saving: the message flag is on and **no request is sent**.
  - An unchanged saved page gives no message.
  - **The blood-type page still sends `PATCH {bloodType:"A-"}`.**
  - A first save is never flagged.
  - After resume, the comparison uses what the page showed.
  - The message only concerns the page « Continuer » is pressed on.
  - The exact text.
- `test/request_core_test.dart`: the vocabulary lists now include `NO_SHOW` and the two actions, and `noShow.isTerminal` is checked.
- `flutter analyze`: 388 issues, the same lines as the baseline (0 new).
- `flutter test`: 1848 passed, 7 skipped (it was 1828 + 20). The request and onboarding tests also pass under `TZ=UTC` (121).

## 5. Contract table
| Field | Backend | App now |
|---|---|---|
| `patientStatus` | 11 values incl. `NO_SHOW` (`PatientRequestStatus.java`) | 11 + `unknown` fallback |
| `availableActions` | `CANCEL`, `PROVIDE_INFORMATION`, `ACCEPT_SCHEDULE_PROPOSAL`, `REJECT_SCHEDULE_PROPOSAL` | All 4 parsed. Unknown actions are still dropped. **Only CANCEL and PROVIDE_INFORMATION have UI.** |
| `scheduleProposal` | `Summary(proposalId, changeType, status, revisionNumber, proposedStartAt, confirmedStartAt, expectedDurationMinutes, proposalExpiresAt, scheduleVersion, actionable, currentConfirmedSchedule, activeDelay)` | `PatientScheduleProposal` with every field. **No UI.** |
| list `filter` | `CANCELLED_DECLINED` ⊇ `NO_SHOW` | Unchanged (the « Cancelled » chip) |

## 6. Complexity and memory
- **Requests:** parsing is O(n) in the payload. The proposal adds 3 small objects per request detail and nothing per list item.
- **Onboarding:** stores at most 3 short JSON strings per screen and compares them only on « Continuer ».
- No new state, stream or timer.

## 7. Risks, open questions, things not done
- **R1. Mixed language on the request screens.**
  - The request history screens are still in English (« Cancelled », « Request declined », « Your request journey »…). The NO_SHOW texts are French as asked, so this status alone is French.
  - All of it moves to ARB in Phase 1b. **Decide:** keep this until then, or translate the request history screens in 1b first.
- **R2. C11 is a design gap (NO UI).**
  - When the clinic proposes a time, the patient sees nothing of it and cannot accept or reject.
  - On WAITING_FOR_CONFIRMATION the screen shows the existing "waiting" card. On a reschedule while CONFIRMED, the patient sees « Confirmed » only.
  - The data needed for the commands is now in the model: `proposalId`, `scheduleVersion` and the request `version`.
  - **Needs:** a design for the proposal card and its accept/reject buttons (roadmap Phase 1, item 6), then the two command calls.
- **R3. Stricter detail parsing.**
  - A malformed `scheduleProposal` (not an object, or no `proposalId`, `revisionNumber`, duration or `scheduleVersion`) now fails the detail screen with the existing error state. Before, it was ignored.
  - This is the same rule as `informationRequest`, and the backend always fills these fields (`ClinicScheduleConvergenceService.java:122-124`).
- **R4. Onboarding message details (my choices; tell me if you want otherwise).**
  - After the message the patient **moves on** to the next page. Nothing can be saved, so staying would block them.
  - The changed values **stay in the fields**; they are not put back.
  - Unselecting and reselecting a condition changes the list order, which counts as a change.
  - If `GET /profile` failed when the screen opened, there is no reference, so there is no message (as before).
  - The real fix is a backend path to update those steps, or editing them later from the profile.
- **Not done:** no proposal UI and no accept/reject calls (as instructed). No change to the NO_SHOW push text, which the server renders.

## 8. Path to deliver G-2
1. **CTO:**
   - Run §9.
   - Decide R1 (language) and R2 (who designs the proposal card).
   - Commit Phase 1a. Every step since 1a-1 is uncommitted; this step's files are listed in the chat summary.
2. **1a-5:** the backend push carries the semantic event type (F7). That is the last Phase 1a item.
3. **Phase 1b:**
   - ARB/gen-l10n, which also handles R1.
   - The timezone package.
   - The remaining honesty items.
4. **Phase 1, item 6:**
   - The schedule-proposal card and accept/reject once designed (R2).
   - The information-request GET.
   - C12–C15.
5. **Release gate (§8):** run it, then the final G-2 report.

## 9. Manual test steps for the CTO
The onboarding button reads « Continue » on screen (English, as before); the task calls it « Continuer ». Use staging with a test patient. *detail* means `curl -s -H "Authorization: Bearer $TOKEN" $API/api/v1/appointment-requests/{requestId}`. Mask ids when you send things back.

**Getting a NO_SHOW request.**
- **(a) Real path.** A clinic user with the no-show capability opens a CONFIRMED test case after its start time plus the grace period, and records « no-show » (`POST /api/v1/clinics/{clinicId}/cases/{caseId}/no-show`).
- **(b) Staging only, if (a) is too slow.** Run `UPDATE appointment_requests SET patient_status='NO_SHOW' WHERE request_id='<test request>'`. The DB allows the value.
  - This leaves the clinic case unchanged, so use a throwaway request.
  - Tell me which way you used.

1. **List.** Home → « Mes demandes » → chip **« All »**.
   - Expected: the request card shows the chip **« Rendez-vous manqué »** in grey-blue, the same look as a cancelled one.
   - Tap the **« Active »** chip: the request is **not** there. Tap the **« Cancelled »** chip: it **is** there.
   - Send back: two screenshots (All, Cancelled).
2. **Detail.** Tap the request.
   - Expected:
     - The status card reads **« Rendez-vous manqué »** / « La clinique a indiqué que ce rendez-vous n’a pas eu lieu. » / « Demande terminée ».
     - The journey ends with **« Rendez-vous manqué »**.
     - There is **no** « What happens next » card and **no** « Cancel request » button.
   - Send back: one screenshot. If you can, also send the `patientStatus` and `availableActions` from *detail*.
3. **Schedule proposal (no UI expected).** On a CONFIRMED or WAITING_FOR_CONFIRMATION request where the clinic has proposed a time, open the detail.
   - Expected: the screen looks **exactly as before**, with no new card and no accept/reject buttons, and no error.
   - Send back: one screenshot plus the `scheduleProposal` object from *detail* with ids masked. I will check it against the test fixture.
4. **Onboarding, edit a saved page.** Sign up a new account.
   - Fill page 1 (name…) → **« Continue »**. Fill page 2 → **« Continue »**.
   - Tap back twice to page 1 → change the **first name** → **« Continue »**.
   - Expected:
     - The snackbar **« Ces informations sont déjà enregistrées. Vous pourrez les modifier plus tard depuis votre profil. »** appears and page 2 opens.
     - `GET /api/v1/profile` still shows the **old** first name.
   - Send back: a screenshot of the snackbar and the `firstName` value.
5. **Onboarding, no change means no message.** Go back to page 1 again, change nothing → **« Continue »**.
   - Expected: page 2 opens with **no** snackbar.
   - Send back: OK or not OK.
6. **Onboarding, the blood type still saves.** On page 2, change the blood type to **A-** → **« Continue »**.
   - Expected: **no** "already saved" snackbar, and `GET /api/v1/profile/medical-data` shows `"bloodType":"A-"`.
   - Send back: the JSON part.
7. **Onboarding, after resume.** Continue to the conditions page, then **force-close** the app and reopen.
   - It opens on the conditions page. Tap back to allergies → add an allergy → **« Continue »**.
   - Expected: the same "already saved" snackbar, and you move on to conditions.
   - Send back: a screenshot.
