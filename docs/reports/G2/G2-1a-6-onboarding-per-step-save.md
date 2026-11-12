# G-2 · 1a-6 — Onboarding saves each page on « Continuer » and resumes where the patient stopped
_Date: 2026-11-11 · Branch: `feature/g2-flutter-hardening` · Trigger: CTO manual test ("Continue sends no request; closing the app mid-onboarding loses everything")_
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

| # | Deliverable | Status after 1a-6 |
|---|---|---|
| 1 | Roadmap | ✅ done (v1.2) |
| 2 | Patient app wired | 🔨 Phase 1a: C1, C3 (+guard), C4–C6, C8, C9 and onboarding per-step save delivered (not yet committed); 1a-4, 1a-5 to do |
| 3 | Report per step | 🔨 6 reports (P0, 1a-1, 1a-2, 1a-2b, 1a-3, 1a-6) |
| 4 | Prompts | ✅ done |

**Result:**
- Every « Continue » now saves its page on the server before moving on.
- A failed save keeps the page and what was typed, and shows « Impossible d'enregistrer. Vérifiez votre connexion et réessayez. ».
- A double tap sends one request.
- Reopening an unfinished onboarding opens the first unsaved page, with saved identity, blood type, height and weight pre-filled. The 1a-2b blood-type guard still holds.
- Skip, the destinations, texts and layout are unchanged.

## 2. Plan findings (step 1)

### a) When the app sent the onboarding requests (before)
- `_nextPage` (`conversational_onboarding_screen.dart:240-258`, before) only validated the page and called `nextPage`. **No request.**
- Everything was sent once, from the last page, in `_completeOnboarding` (`:260-386`, before): `GET /profile`, then step 1, `PATCH /profile/passport`, steps 2, 3 and 4 in sequence, guarded by `currentStep <= N`.
- All typed data lived only in memory (the widget state and `UserOnboardingProvider`), so closing the app lost it.

### b) The 5 dots vs the server steps (no destination changed)
| Dot / page | Server request | What it stores, where |
|---|---|---|
| 0 Identity | `POST /profile/onboarding/step/1` `{firstName,lastName,dateOfBirth,gender}` | `UserProfile` (main DB, `OnboardingService.java:62-70` → `updateBasicInfo`) |
| 1 Blood type + height/weight | `PATCH /profile/passport` `{bloodType?, heightCm?, weightKg?}` | MRS LIFE_SAFETY / BODY_MEASUREMENTS (`UserProfileService.updatePassportFields` → `MrsMedicalDataService.updateBasics`) |
| 2 Allergies | `POST …/step/2` `{allergies}` or `{noKnownAllergies:true}` | `passport_allergies` (main DB, `PassportService.saveAllergies`, replace-all) |
| 3 Conditions | `POST …/step/3` `{conditions}` or `{noKnownConditions:true}` | `passport_conditions` (main DB, replace-all) |
| 4 Medications | `POST …/step/4` `{medications}` or `{noKnownMedications:true}` | `passport_medications` (main DB), then `MrsOnboardingSyncService.sync`, then onboarding marked complete |

Before, step 1 also carried blood type, height and weight. Those went through `MrsOnboardingSyncService.syncBasics` → `MrsMedicalDataService.updateBasics`, **the same MRS call** the page-1 PATCH already made a moment later. They now go only through the page-1 PATCH, so the destination is unchanged.

### c) What the server stores and exposes about progress
- **Where to resume: yes.** `GET /profile` returns `onboardingStep` (1–4, the next step expected; `UserProfile.java:116,166`) and `onboardingCompleted` (`ProfileResponse.java:24-25`). So there was no STOP.
- **Saved values:**
  - identity: readable (`GET /profile`);
  - blood type, height, weight: readable (`GET /profile/medical-data`);
  - **allergies and conditions: not readable during onboarding.** They sit in `passport_*`, `/api/v1/passport/**` is `denyAll` (`AuthWebSecurityConfig.java:280`), and MRS only gets them at step 4. Resume opens *after* them, so this matters only if the patient goes back (R1, R2).
- **Re-sending a step is not an update:**
  - re-sending the step just before the current one returns "Étape enregistrée" **without saving** (`OnboardingService.java:42-48`);
  - an older step gets **400 INVALID_STATE** (`:51-53`);
  - a step that does run replaces all rows (`PassportService.java:39-116`);
  - once complete, only step 4 is accepted (re-sync).
- **One trap found:** the `PageView` can be swiped forward without pressing Continue. A purely per-page save would then skip a server step and hit the 400 on the next one. So each Continue saves **every unsaved page up to the current one, in order**. Swiping changes nothing for the server.

## 3. What changed

| File | Change |
|---|---|
| `lib/features/onboarding/onboarding_progress.dart` (new) | `OnboardingProgressController` (plain class, constructor-injected `AccountApi`): `load()` reads `GET /profile` + `GET /profile/medical-data` and never throws; `saveThrough(page, draft)` saves each unsaved page up to `page`, each request at most once, with an in-flight guard (second tap → `OnboardingSaveIgnored`) and sealed outcomes `Saved` / `Ignored` / `Failed`. Pure rules: `shouldSendOnboardingStep` (the former `currentStep <= N` rule), `onboardingResumePage`, `onboardingSaveErrorMessage`. Body page: sends only what differs from the server (blood type through the 1a-2b `bloodTypeToSend` guard, plus a "last sent" check so `unknown` goes once; height and weight only when changed) |
| `lib/features/onboarding/onboarding_basics_payload.dart` | `onboardingStep1Body` = identity only. `onboardingStep2Body` / `3Body` / `4Body` extracted **unchanged** from the old `_completeOnboarding` |
| `lib/features/onboarding/conversational_onboarding_screen.dart` | On open: `_loadResume()` replaces the two old prefill reads, pre-fills identity, height and weight (only into empty fields), pre-selects the stored blood type (only if no tile was chosen), and `jumpToPage(resume.page)` if the patient is still on page 0. Continue: `_nextPage()` validates pages ≤ current with the existing validators, builds the draft (and still fills `UserOnboardingProvider` as before), calls `saveThrough`, moves on only on success, and shows the French snackbar on failure. The last page refreshes the user, then opens `OnboardingCompleteScreen` as before. `_completeOnboarding`, `_prefillBasicProfile`, `_loadStoredBloodType` were removed. The medication-row validation is kept as is (`_collectMedications`) |
| `lib/core/api/account_api.dart` | `getStoredBloodType()` → `getStoredMedicalBasics()`: blood type, height and weight from `GET /profile/medical-data`. A malformed shape is an error, never "nothing stored" |
| `lib/core/l10n/pending_fr_strings.dart` | `onboardingSaveFailed` = the CTO's text |
| `test/onboarding_per_step_save_test.dart` (new, 23 logic tests) | see §4 |
| `test/onboarding_blood_type_guard_test.dart` | API group moved to `getStoredMedicalBasics` (+ body measurements and malformed weight). The 5 old "end-of-onboarding" scenarios are replaced by the controller tests in the new file (they mirrored the removed `_completeOnboarding`) |
| `test/blood_type_and_medical_save_test.dart` | The onboarding group now asserts that step 1 carries identity only and the blood type goes through PATCH (the new contract) |

Unchanged: Skip (`:586`, still only navigates), texts and validation messages (still English, Phase 1b), layout, the medication search (still the MOCK catalogue), the conditions/medications destinations, `lib/features/doctor/**`, backend repos, pubspec.

## 4. Evidence
| Check | Result |
|---|---|
| `flutter analyze` | 388 issues. Set difference against the baseline: **0 new, 0 removed** |
| `flutter test` (full) | **1,828 passed, 7 skipped, 0 failed** (1,809 + 23 new − 4 replaced old-flow scenarios) |
| `dart format` on touched files | clean |
| **Mutation check:** "always send", no in-flight guard, "always resume at page 0"; new file run; restored | **16 failures** as expected (per-page sequence, last page, double tap, re-Continue, failure/retry, lost response, 4 resume rules, load, resume-then-save, 4 guard tests). Restored: 23/23 |

**New tests (logic only).** The fake server applies the backend's step rules: order enforced, no-op on the previous step, 400 on older steps, completion, and the `unknown` "cannot clear" 400.
- **Once per page:**
  - pages 0→4 send exactly `[step 1]`, `[PATCH]`, `[step 2]`, `[step 3]`, `[step 4]`;
  - step 1 body is identity only, and the PATCH body is blood type, height and weight;
  - the last page completes onboarding;
  - **a double tap sends one request** (the second returns `Ignored` while the first is in flight);
  - Continue again on a saved page sends nothing;
  - swiping to page 3 then Continue sends steps 1, PATCH, 2, 3 in order with **no 400**;
  - when onboarding is already complete, nothing is sent.
- **Failure:**
  - a 503 on step 2 sends no later step, leaves the server at step 2, and leaves the draft untouched; the retry sends the same body once;
  - **a lost response** (saved on the server, timeout in the app) is retried with no 400;
  - the message is the CTO's text for network, 503 and unexpected errors, the "invalid" text for `INVALID_INPUT`, and never the server text.
- **Resume:**
  - the six-row rule table (fresh, identity saved, identity + body, allergies, conditions, completed);
  - `load()` returns the right page and the stored values;
  - a failed profile read opens page 0;
  - after resuming at step 3, only step 3 is sent.
- **1a-2b guard after resume:**
  - **stored A+ then « Je ne sais pas » → PATCH without `bloodType`**, and A+ is kept;
  - A+ kept with the same measurements → no request;
  - **nothing stored then « Je ne sais pas » → `unknown`, sent once** over two Continues;
  - medical-data read failed then « Je ne sais pas » → omitted.

## 5. Contract table
| Method | Path | When | Request | Response used | Errors → patient |
|---|---|---|---|---|---|
| GET | `/profile` | onboarding opens; before the first save if that read failed | — | `onboardingStep`, `onboardingCompleted`, identity | failure → page 0, no pre-fill (as before) |
| GET | `/profile/medical-data` | onboarding opens | — | `lifeSafety.bloodType`, `bodyMeasurements.heightCm/weightKg` | failure → no pre-fill, blood guard conservative |
| POST | `/profile/onboarding/step/1` | Continue on page 0 (or later pages) while the server is at step 1 | identity | `nextStep`, `onboardingCompleted` | `INVALID_INPUT`/`VALIDATION_ERROR` → « Certaines informations ne sont pas valides… »; anything else → « Impossible d'enregistrer. Vérifiez votre connexion et réessayez. » |
| PATCH | `/profile/passport` | Continue on page ≥ 1 when blood type, height or weight differs from the server | `bloodType?` (guarded), `heightCm`+`weightKg` (together) | — | same |
| POST | `/profile/onboarding/step/2`, `/3`, `/4` | Continue on page ≥ 2 / 3 / 4 while the server is at or before that step | unchanged content | `nextStep`, `onboardingCompleted` | same |

## 6. Complexity and memory
- Each Continue loops over at most 5 pages and makes at most one request per unsaved page. Opening onboarding makes 2 GETs.
- The controller holds 5 scalars (server step, stored blood type, saved height/weight, last sent blood type) plus a flag. Nothing is persisted on the device; the server is the source of truth.

## 7. Risks, open questions, things not done
- **R1. Editing an already-saved page (open question).** If the patient goes back to identity, allergies or conditions *after* that page was saved and changes something, Continue does **not** re-send it. This is the same rule the old final save applied (`currentStep <= N`). The backend cannot update those steps during onboarding: the previous step is a silent no-op and older steps are a 400. The body page is the exception, because `PATCH /profile/passport` works any time. **Decide:** an honesty message on those pages, or a backend update path.
- **R2. Allergies and conditions are not pre-filled on resume.** The server keeps them where the app cannot read them during onboarding (`/passport/**` is denied; MRS gets them at step 4). Resume opens after them, but a patient who goes back sees empty fields (and R1 applies).
- **R3. Step 1 no longer carries blood type, height and weight.** The same MRS call is made by the page-1 PATCH, so the destination is unchanged. The backend legacy cleanup (`clearLegacyMedicalFields`) runs in both paths.
- **R4. "Screens with no data to save": none qualifies.** Every page writes something. An empty allergies, conditions or medications page sends the existing `noKnown…: true` (unchanged), and the server needs each step in order to reach completion.
- **R5. Validation messages and button labels are still English** (« Please enter your height. », « Continue », « Complete »). Unchanged; Phase 1b ARB.
- **R6. Waiting on the network.** Continue now waits for the server. The button is disabled during the save through the existing `_saving` state (no new component).
- Still open from 1a-2b: whether the 15 widget tests in `blood_type_and_medical_save_test.dart` should become logic tests.

## 8. Path to deliver G-2
1. **CTO:** run the manual steps (§9), decide R1, then commit 1a-1 → 1a-3 and this step.
2. **Run 1a-4:** `NO_SHOW` status with a French label and terminal semantics (C10). C11 is recorded as a design gap.
3. **Run 1a-5:** backend `notification` module sends the semantic `type` + `templateType` (F7). Then Phase 1b, which also translates the onboarding validation messages and buttons.

## 9. Manual test steps for the CTO
Use staging, a **new** test patient for each scenario, and `curl -s -H "Authorization: Bearer $TOKEN" $API/api/v1/profile` (call it *profile*) and `…/api/v1/profile/medical-data` (call it *medical-data*).

1. **Page 0 saves on Continue.** Sign up → onboarding page 1 (first dot) → fill name, birth date, gender → tap **« Continue »**.
   - Expected: the next page opens after a short wait. *profile* shows `"onboardingStep":2` and your name.
   - Send back: the `onboardingStep` and `firstName` values.
2. **Page 1 saves.** Choose **A+**, height **172**, weight **70** → **« Continue »**.
   - Expected: *medical-data* shows `"bloodType":"A+"`, `"heightCm":172`, `"weightKg":70.0`.
   - Send back: that JSON part.
3. **Close and resume.** On the allergies page, add one allergy → **« Continue »**. On the conditions page, **force-close the app** (swipe it away). Reopen and log in if asked.
   - Expected: onboarding opens **directly on the 4th dot (conditions)**. Swipe back to the 2nd dot: **A+, 172 and 70 are filled in**.
   - Send back: two screenshots.
4. **No network.** On any page, turn on airplane mode → **« Continue »**.
   - Expected: a snackbar **« Impossible d'enregistrer. Vérifiez votre connexion et réessayez. »**, you stay on the page, and what you typed is still there.
   - Turn airplane mode off → **« Continue »**. Expected: the next page opens.
   - Send back: a screenshot of the snackbar.
5. **Double tap.** On page 0 of a new account, tap **« Continue »** twice very fast.
   - Expected: one page forward. *profile* shows `"onboardingStep":2` (not an error, not 3).
   - Send back: the value.
6. **Finish.** Go through to the last dot → **« Complete »**.
   - Expected: the completion screen. *profile* shows `"onboardingCompleted":true`.
   - Send back: the value.
7. **Blood-type guard after resume (1a-2b).** Do steps 1–2 with **A+** on a new account → force-close → reopen. Swipe back to the 2nd dot (A+ is selected) → tap **« Je ne sais pas »** → **« Continue »**.
   - Expected: *medical-data* still shows **`"bloodType":"A+"`**.
   - Send back: the JSON.
8. **Swipe without Continue (optional).** On a new account, fill page 0, then **swipe** (don't tap Continue) to page 3 and fill the pages on the way → **« Continue »**.
   - Expected: no error. *profile* shows `"onboardingStep":4`.
   - Send back: the value.
