# G-2 · 1a-2b — « Je ne sais pas » never erases a blood type; demo documents "+" hidden
_Date: 2026-11-11 · Branch: `feature/g2-flutter-hardening` · Follows `G2-1a-2-blood-type-and-save-errors.md` (risks R1, R4)_
_Testing rule (CTO, 2026-11-11): automated tests cover logic only; screens are tested by hand (§8)._

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

| # | Deliverable | Status after 1a-2b |
|---|---|---|
| 1 | Roadmap | ✅ done (v1.2) |
| 2 | Patient app wired | 🔨 Phase 1a: C1, C3 and its guard delivered (not yet committed); 1a-3 → 1a-5 to do |
| 3 | Report per step | 🔨 4 reports (P0, 1a-1, 1a-2, 1a-2b) |
| 4 | Prompts | ✅ done |

**Result:**
- « Je ne sais pas » can no longer erase a stored blood type or trigger the backend's "cannot be cleared" 400.
- On onboarding resume, a stored blood type is pre-selected.
- The Ma Santé documents "+" that opened the demo editor is hidden. Nothing else is hidden.

## 2. Plan findings and what changed

### 2.1 How onboarding learns the stored blood type
- `GET /profile` (already called on onboarding start) **does not carry a blood type**. `ProfileResponse` has no medical field (`BE/profile/DTO/ProfileResponse.java`), and the legacy column is cleared on every write (`UserProfile.clearLegacyMedicalFields`, `UserProfile.java:155-159`).
- The only read is **`GET /api/v1/profile/medical-data` → `lifeSafety.bloodType`** (`ProfileController.java:78-86` → `UserProfileService.getMedicalData`, `:106-121`). It is MRS-backed with a fallback to the legacy column, PATIENT-only, and `authenticated()` (`AuthWebSecurityConfig.java:213`). The value is normalised (`A+`… or null; the backend never stores `unknown`).
- This is the app's **first call to that endpoint**. It is a single narrow read (blood type only) used only by onboarding. Phase 3 still owns the full medical-data repository and the decision on MRS as source of truth.

### 2.2 Decision rule (pure functions, `onboarding_basics_payload.dart`)
`StoredBloodType` is a sealed type: `Known(value or null)` once the server answered, `Unavailable` before that or on failure.

| Chosen tile | Stored: nothing (`Known(null)`) | Stored: a value (`Known(A+)`) | Read failed / not yet answered (`Unavailable`) |
|---|---|---|---|
| none | omit | omit | omit |
| « Je ne sais pas » | **`unknown`** (a backend no-op) | **omit** (A+ kept) | **omit** (can't prove nothing is stored) |
| same as stored (A+) | — | omit (no rewrite) | send A+ |
| other ABO (B+) | send B+ | send B+ | send B+ |

- `unknown` is sent only when the server **confirmed** nothing is stored. In that case `updateBasics` does nothing (`MrsMedicalDataService.java:79-84`). So the "cannot be cleared" 400 (blood type is the only stored item) and the "clear when allergies exist" path are both unreachable from onboarding.
- Pre-selection: on `Known(value)`, the stored tile is selected **only if the patient has not tapped one already**.

### 2.3 Files changed
| File | Change |
|---|---|
| `lib/features/onboarding/onboarding_basics_payload.dart` | Adds `StoredBloodType` (sealed: `StoredBloodTypeKnown`, `StoredBloodTypeUnavailable`), `bloodTypeToPreselect` and `bloodTypeToSend` (exhaustive switches). `onboardingStep1Body` is unchanged apart from its doc comment |
| `lib/core/api/account_api.dart` | `getStoredBloodType()`: `GET /profile/medical-data`. Parses only `lifeSafety.bloodType` through `BloodType.fromWire`. A missing `lifeSafety` or non-string value → `ApiException(MALFORMED_RESPONSE)`, never "nothing stored" |
| `lib/features/onboarding/conversational_onboarding_screen.dart` | `_storedBloodType` starts as `Unavailable`. `_loadStoredBloodType()` runs next to the existing profile prefill (post-frame), pre-selects, and logs on failure. Step 1 and the passport PATCH both send `bloodTypeToSend(...)`. No layout change |
| `lib/features/home/new_home_screen.dart` | The documents "+" `IconButton` is rendered only `if (_showDemoDocumentEditorEntry)`, a `static const false` with a G2-1c note. The demo editor call site is **kept** (Phase 1c deletes it). The title column is `Expanded`, so it simply has the row to itself |
| `test/onboarding_blood_type_guard_test.dart` (new, 24 logic tests) | see §3 |

Nothing under `lib/features/doctor/**`, backend repos or pubspec was touched.

## 3. Evidence
| Check | Result |
|---|---|
| `flutter analyze` | 388 issues. Set difference against the 388 baseline: **0 new** (the const flag raises no `dead_code`) |
| `flutter test` (full) | **1,769 passed, 7 skipped, 0 failed** (1,745 + 24 new) |
| `dart format` on touched files | clean |
| **Mutation check:** `bloodTypeToSend` replaced by the old "send what was picked", new file run, then restored | **6 failures** as expected (stored A+ + « Je ne sais pas »; read failed + « Je ne sais pas »; re-send of the stored value; the "unknown never sent unless confirmed empty" sweep; two request-body scenarios). Restored: 24/24 |

**New tests (logic only):**
- `bloodTypeToSend`: 10-row table (§2.2), plus a sweep over every stored value showing `unknown` is never sent unless the server confirmed nothing is stored.
- `bloodTypeToPreselect`: 2 tests.
- `getStoredBloodType` against a recorded `MedicalDataResponse` shape: reads A+; null means nothing stored; tolerates casing; missing `lifeSafety` → `MALFORMED_RESPONSE`; non-string value → error; 503 → `MRS_UNAVAILABLE`.
- **Request bodies, read → decision → step 1 + passport PATCH** through the real `AccountApi`:
  - **stored A+ then « Je ne sais pas » → no `bloodType` in either body**;
  - **nothing stored then « Je ne sais pas » → `unknown`**;
  - **nothing stored, nothing picked → no `bloodType`**;
  - read failed then « Je ne sais pas » → none;
  - stored A+ then B+ → B+.

## 4. Contract table
| Method | Path | Request | Response used | Errors |
|---|---|---|---|---|
| GET (new for the app) | `/profile/medical-data` | — | `lifeSafety.bloodType` (string or null) | any failure → state stays `Unavailable` (logged, nothing shown; onboarding continues) |
| POST | `/profile/onboarding/step/1` | `bloodType` only per §2.2, otherwise unchanged | unchanged | unchanged (French message from 1a-2) |
| PATCH | `/profile/passport` (onboarding) | `bloodType` only per §2.2; `heightCm`/`weightKg` unchanged | unchanged | unchanged |

## 5. Complexity and memory
One extra GET per onboarding screen open. The decision is O(1). Nothing is cached or kept beyond the screen state (one enum value). The response is parsed for one field only, so no other medical data is held in memory.

## 6. Risks, open questions, things not done
- **R1. Silent "keep".** When a value is stored and the patient taps « Je ne sais pas », the stored value stays and nothing tells them. This is the CTO rule; the stored value was pre-selected on screen, so the patient saw it.
- **R2. Read failure is conservative.** If `GET /profile/medical-data` fails (e.g. MRS down), there is no pre-selection and « Je ne sais pas » is omitted. For a new patient that's equivalent (`unknown` would have been a no-op).
- **R3. Ma Santé still shows « - » after a successful save.** Its read path (`UserProvider` never fills `bloodGroup`) is Phase 3. Expect this during the manual tests below; it is not a regression.
- **R4. Widget tests from 1a-2 (open question).** `test/blood_type_and_medical_save_test.dart` contains 15 widget tests written before this rule (editor, family detail and onboarding tile), alongside 11 logic tests. They pass. **Keep them, or convert them to logic tests plus manual steps?** I have not changed them without your answer.
- Not done: the full medical-data read (Phase 3); deleting the demo editor call site and the 3 hardcoded documents (Phase 1c).

## 7. Path to deliver G-2
1. **CTO:** run the manual steps (§8) and send back the results; answer R4. Then commit 1a-1, 1a-2 and 1a-2b.
2. **Run 1a-3:** urgent-cabinet tolerant parsing (unknown enum or phase → `unknown`, never a whole-snapshot failure) and query max length 120, with logic tests from recorded server JSON.
3. **Then 1a-4** (`NO_SHOW`; C11 recorded as a design gap) **and 1a-5** (backend push semantic `type` + `templateType`), then Phase 1b.

## 8. Manual test steps for the CTO
Use a staging backend and a **new** test patient account (no real data). `$API` = staging base URL; `$TOKEN` = that patient's access token.

1. **Ma Santé "+" hidden.** Log in as any patient → bottom tab **Ma Santé** → scroll to **« Mes Documents Médicaux »** (subtitle « Analyses et ordonnances »).
   - Expected: **no green "+" circle** to the right of the title. The rest of the section looks as before.
   - Send back: one screenshot of that section.
2. **New patient, « Je ne sais pas ».** Sign up a new patient → onboarding opens → fill page 1 → swipe to the **blood type page**.
   - Expected: **no tile selected**, and the last tile reads **« Je ne sais pas »** (two centred lines, no overflow stripes).
   - Tap « Je ne sais pas » → finish onboarding. Expected: it completes with no red message.
   - Then run `curl -s -H "Authorization: Bearer $TOKEN" $API/api/v1/profile/medical-data`. Expected: `"lifeSafety":{"bloodType":null,…}`.
   - Send back: a screenshot of the blood page and the `lifeSafety` part of the JSON (mask ids).
3. **Resume with a stored blood type (the R1 case from 1a-2).**
   - Sign up another new patient → onboarding → tap **« Skip »** (top right) → home.
   - Go to **Ma Santé** → passport card → **Modifier** → Groupe Sanguin **A+** → **« Enregistrer les Modifications »**. Expected: the editor closes with no red message (Ma Santé will still show « - », see R3).
   - Log out → log in again. Expected: onboarding opens again.
   - Swipe to the blood type page. Expected: **A+ is already selected**.
   - Tap **« Je ne sais pas »** → finish onboarding. Expected: it completes with no red message.
   - Run the `curl` from step 2. Expected: **`"bloodType":"A+"`** (not null).
   - Send back: a screenshot of the pre-selected A+ tile and the `lifeSafety` JSON.
4. **Resume and change the value.** Same as step 3, but on the blood type page tap **B+** instead.
   - Expected: `curl` shows **`"bloodType":"B+"`**.
   - Send back: the `lifeSafety` JSON.
5. **Network failure during resume (optional).** Repeat step 3 up to the second login, but turn on airplane mode **before** the onboarding screen opens. Then turn it back on before finishing.
   - Expected: **no tile pre-selected**. After « Je ne sais pas » → finish, `curl` still shows **`"bloodType":"A+"`**.
   - Send back: the JSON, or "skipped".
