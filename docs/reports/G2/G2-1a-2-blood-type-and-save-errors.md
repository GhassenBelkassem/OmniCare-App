# G-2 · 1a-2 — Blood-type values, missing save error, silent loss of conditions/medications
_Date: 2026-11-10 · Branch: `feature/g2-flutter-hardening` · Roadmap v1.2 §3 Phase 1a item 2 · Inventory rows C3, C2 (honesty only), F5_

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

| # | Deliverable | Status after 1a-2 |
|---|---|---|
| 1 | Roadmap | ✅ done (v1.2) |
| 2 | Patient app wired | 🔨 2 of 5 Phase 1a fixes delivered (C1, C3), not yet committed |
| 3 | Report per step | 🔨 3 reports (P0, 1a-1, this one) |
| 4 | Prompts | ✅ done |

**Result:**
- No request can carry `'-'`, `'IDK'` or `medicalInfo`; this is enforced by types.
- An untouched blood type is never sent.
- Every medical-data save failure shows a French message and never the server's text.
- Changing conditions or medications now shows « Les antécédents et traitements ne peuvent pas encore être enregistrés. »

## 2. Plan findings (step 1) and what changed

### 2.1 Where a blood-type value is created, shown or sent (before this change)
| Place | Value set | Wire value | Result |
|---|---|---|---|
| `EditMedicalDataScreen` dropdown (`edit_medical_data_screen.dart:75-85,111-112`), used by Ma Santé self, family detail and a fixture | `'-'` + 8 ABO types; `'-'` is the default whenever the input is empty or unrecognised | the selected string as-is | Ma Santé self opens on `'-'` because `UserProvider` never fills `bloodGroup` (P0), so **every save sent `'-'` → 400** |
| Family detail (`new_home_screen.dart:76` → `family_member_detail_screen.dart:64-72`) | always `'-'` (static, not loaded from the server) | `'-'` | **400** on every save |
| Onboarding blood tiles (`conversational_onboarding_screen.dart:39-49,933-967`) | 8 ABO types + `'IDK'`, with the tile showing "IDK" | step 1 `'bloodType': provider.bloodGroup` (null if no tile chosen, sent as JSON null); then `PATCH /profile/passport` | `'IDK'` → **400** (with English "Failed to save: <server text>") |
| Display: Ma Santé card (`new_home_screen.dart:1546`), family card (`family_member_detail_screen.dart:452`) | raw string / `'-'` | — | — |
| Not sent (verified): `vital_info_screen.dart:14` (orphan, in memory, valid ABO only), `patient_passport/.../medical_data_editor_screen.dart` (no API call, P0) | — | — | — |

### 2.2 Backend semantics (read only), so no STOP was needed
All three endpoints end in `MrsMedicalDataService.updateBasics` (`MrsMedicalDataService.java:58-98`):
| Field value | Effect |
|---|---|
| **absent / null** | **keeps the stored value** (`requestedBloodType == null ? current…`) |
| `unknown` or blank | normalised to null (`:265-268`). **Clears** the stored blood type when allergies or critical conditions exist, **400 INVALID_INPUT** ("cannot be cleared") when blood type is the only stored item, no-op when nothing is stored |
| A±, B±, AB±, O± (any case) | stored |
| anything else (`'-'`, `'IDK'`) | **400 INVALID_INPUT** |

- Self `PATCH /profile/passport`: `ProfileController.java:66` → `UserProfileService.java:84-94`. Absent falls back to the legacy profile column, which is null after `clearLegacyMedicalFields`, so absent keeps the MRS value.
- Family `PATCH /profile/family-members/{id}/passport`: `FamilyMemberController.java:76` → `FamilyMemberService.java:141`. Absent keeps the value.
- Onboarding `POST /profile/onboarding/step/1`: `OnboardingService.java:62-70` → `MrsOnboardingSyncService.java:28-40`. Absent or null keeps the value.
- `UpdatePassportRequest` has only `bloodType, heightCm, weightKg`. `medicalInfo` is silently ignored (unknown properties are not rejected).

### 2.3 Where conditions/medications were edited and sent as `medicalInfo`
- Ma Santé self: `new_home_screen.dart:1704-1723` sent `medicalInfo{chronicConditions, currentMedications}`, which the backend dropped silently (C2).
- Family detail: edits were applied **locally only** (`family_member_detail_screen.dart:75-80`, before this change) and looked saved until the screen closed.
- `UserRepository.patchMedicalPassport` forwarded `medicalInfo`, but nothing called it. Removed.
- Not sent (verified): `AccountUser.toJson` / `AccountFamilyMember.toJson` (`account_models.dart:171,220`) are in-memory only, and `PATCH /profile` (`PatientProfileUpdate.toJson`) has no medical field. `UserOnboardingProvider.toMedicalPassportJson` has no caller (dead code, Phase 1c).

### 2.4 Files changed
| File | Change |
|---|---|
| `lib/core/models/blood_type.dart` (new) | `enum BloodType` with 8 ABO values + `unknown`. Each has one `wireValue` matching `ALLOWED_BLOOD_TYPES` plus `unknown`. `label` uses an exhaustive switch (« Je ne sais pas » for `unknown`). `fromWire` maps null, blank or legacy `'-'` to `null` (not provided) and any unrecognised value to `unknown`. "Not provided" is the absence of a value, never a wire value |
| `lib/core/l10n/pending_fr_strings.dart` (new) | French strings awaiting ARB (Phase 1b). None of these screens used a localization mechanism |
| `lib/core/network/save_error_message.dart` (new) | Maps a failure to French: `INVALID_INPUT`/`VALIDATION_ERROR` → invalid; `MRS_UNAVAILABLE` or 5xx → unavailable; no response → network; anything else → generic. **Never reads server text.** Interim until the Phase 1b `ApiFailure` parser |
| `lib/core/api/account_api.dart` | `patchMedicalPassport({BloodType?, int?, double?})`. The **`medicalInfo` parameter is removed**, and null fields are omitted (`'k': ?v`) |
| `lib/core/api/family_api.dart`, `lib/repositories/family_repository.dart`, `lib/providers/family_provider.dart` | family PATCH takes a **required** `BloodType`, so the family path cannot send "no value" |
| `lib/repositories/user_repository.dart` | removed the unused `patchMedicalPassport` that forwarded `medicalInfo` |
| `lib/features/home/edit_medical_data_screen.dart` | `bloodType` is now a `BloodType?`. The dropdown and its items are unchanged (`'-'` is still shown). `onSave` receives a typed `MedicalDataEdit`: `bloodType` is set only when the patient picked a *different* value that isn't `'-'`, and `conditionsOrMedicationsChanged` is set when those lists differ from the opening values. Medications are copied at open, so editing no longer mutates the caller's objects before a save. **`onSave` is wrapped in try/catch**: on failure the screen stays open with the existing red snackbar and a French message. After a successful save that changed conditions or medications, the honesty snackbar is shown. The existing medication-validation snackbar reuses the same helper (same style) |
| `lib/features/home/medical_data_save.dart` (new) | `saveOwnMedicalEdit`: sends `PATCH /profile/passport {bloodType}` only when the blood type changed, never conditions or medications |
| `lib/features/home/new_home_screen.dart` | Ma Santé self save goes through `saveOwnMedicalEdit`, and the user profile refreshes only when a request was made. The family detail model gets `bloodType: null` instead of `'-'`. The card shows `BloodType.label` or `'-'`. The fixture editor is adapted to the new signature (behaviour unchanged, see R4) |
| `lib/features/home/family_member_detail_screen.dart` | `FamilyMember.bloodType` is a `BloodType?`. Save sends only a changed blood type. Conditions and medications are **no longer shown as if saved** (see R2). The card shows the label or `'-'` |
| `lib/features/onboarding/onboarding_basics_payload.dart` (new) | Step-1 body builder that omits `bloodType` when none was chosen |
| `lib/features/onboarding/conversational_onboarding_screen.dart` | Tiles are typed `BloodType`. The "IDK" tile now reads « Je ne sais pas » and stores `unknown`, with `textAlign: center` so the two lines centre. Step 1 and the passport PATCH send the typed value. The save-error snackbar shows a French message instead of `'Failed to save: <server text>'` |
| `test/blood_type_and_medical_save_test.dart` (new, 26 tests) | see §3 |
| `test/p5_06_patient_qr_test.dart` | fixture `bloodType: 'O+'` → `BloodType.oPositive` (it still displays `O+`) |

No layout, navigation or theme change. No new component, pubspec change or backend change. Nothing under `lib/features/doctor/**` or `patient_passport/sharing/**` was touched, and `/profile/medical-data` is not wired.

## 3. Evidence

| Check | Result |
|---|---|
| `flutter analyze` | 388 issues, same as the baseline. Set difference: **0 new, 0 removed**. (One intermediate new error, an old test fixture passing a `String` blood type, was fixed.) |
| `flutter test` (full) | **1,745 passed, 7 skipped, 0 failed** (1,719 before + 26 new) |
| New file under `TZ=Africa/Tunis`, `UTC`, `America/Los_Angeles` | 26/26 in each |
| `dart format` on touched files | clean |
| **Mutation check**: removed the editor's try/catch and the "unchanged value" comparison, ran the new file, restored | **6 failures** as expected (re-chosen value sent; 400/503/network/non-API errors not caught on self and family). Restored: 26/26 |
| Static sweep | Only 3 places in patient code write `bloodType`, all from `BloodType.wireValue` (`account_api.dart:47`, `family_api.dart:106`, `onboarding_basics_payload.dart:20`). No `'IDK'` left in `lib`. `medicalInfo` is no longer written into any request |

### New tests (all requests captured at the real `AppHttpClient` adapter)
- **Mapping (6):** a full UI↔wire table with round trip; labels; case and space tolerance; unrecognised values (`Z+`, `IDK`, `A`, `AB`) map to `unknown`; null, blank and `'-'` map to not provided; no wire value equals `'-'` or `IDK`.
- **Ma Santé self, real editor → `saveOwnMedicalEdit` → `AccountApi` (10):**
  - untouched: no request;
  - changed: body is exactly `{bloodType:"B+"}`;
  - `'-'` over a value: nothing sent;
  - re-chosen current value: nothing sent;
  - conditions only: no request plus the honesty message;
  - conditions + blood type: only `{bloodType}` plus the honesty message;
  - 400 `INVALID_INPUT`: French message, no server text, editor stays open;
  - 503 `MRS_UNAVAILABLE`: French message;
  - connection error: « Connexion impossible. Réessayez. »;
  - thrown `StateError`: generic message, no crash.
- **Family, real `FamilyMemberDetailScreen` → `FamilyProvider` → `FamilyRepository` → `FamilyApi` (4):**
  - untouched `'-'`: no request;
  - changed: `PATCH /profile/family-members/fm-1/passport {bloodType:"A-"}`, and the card shows `A-`;
  - condition edit: no request, honesty message, condition not shown;
  - 400: French message.
- **Onboarding (4):**
  - no choice: `bloodType` absent from step 1 and from the passport PATCH;
  - « Je ne sais pas » is sent as `unknown`;
  - an ABO choice is sent as its wire value;
  - **real `ConversationalOnboardingScreen` at 320 px width**: no "IDK", « Je ne sais pas » renders with no layout exception, and a tap stores `unknown`.
- **API surface (2):** an untouched edit sends nothing; the `FamilyApi` body is exactly the wire value.
- Every request-capturing test also asserts that no body contains `medicalInfo`, `'-'` or `'IDK'`.

## 4. Contract table
| Method | Path | Request (after) | Response | Error codes handled (French) |
|---|---|---|---|---|
| PATCH | `/profile/passport` (`ProfileController.java:66`) | `{bloodType?, heightCm?, weightKg?}`. `bloodType` ∈ {A+,A-,B+,B-,AB+,AB-,O+,O-,unknown}, **omitted when unchanged**. No `medicalInfo` | `ProfileResponse` (ignored; the app refreshes the profile) | `INVALID_INPUT`, `VALIDATION_ERROR` → invalid · `MRS_UNAVAILABLE`/5xx → unavailable · no response → network · other → generic |
| PATCH | `/profile/family-members/{id}/passport` (`FamilyMemberController.java:76`) | `{bloodType}`, **sent only when changed** (otherwise no request) | `FamilyMemberResponse` (ignored) | same |
| POST | `/profile/onboarding/step/1` (`OnboardingController.java:26` → `OnboardingService.java:62`) | `{firstName,lastName,dateOfBirth,gender,bloodType?,heightCm,weightKg}`. `bloodType` **omitted when no tile was chosen** | `OnboardingStepResponse` | same (also `INVALID_STATE` → generic) |

## 5. Complexity and memory
- The dirty check runs once per save: conditions are compared as sets, O(c), and medications as tuple lists, O(m). Both lists are short and user-entered (≤ 10 suggested conditions, a handful of medications).
- `BloodType.fromWire` is O(9).
- Medications are copied once when the editor opens (O(m)), which also removes the aliasing of the caller's mutable objects.
- No new caches, streams, timers or files. No list endpoints are involved.

## 6. Risks, open questions, things not done

**R1. « Je ne sais pas » clears a stored blood type.** The backend treats `unknown` as "clear": it clears the value when allergies or conditions exist and answers 400 when blood type is the only stored item (then the patient sees « Certaines informations ne sont pas valides… »). It is only offered in onboarding, where a new patient has nothing stored (a no-op). A patient who *resumes* onboarding after storing a blood type and picks « Je ne sais pas » would clear it or get that 400. **Open question (CTO):** is "I don't know" allowed to erase a known blood type? The backend's "cannot be cleared" 400 also deserves its own code; that is a backend item, not done.

**R2. Family detail: edited conditions and medications are no longer displayed after "Enregistrer".** Before, they appeared until the screen closed but were never saved. Now the honesty message says so and the screen shows nothing new, which follows from "tell the truth". Locally added *documents* are still applied locally only (not in scope, Phase 5).

**R3. Onboarding tile text.** "IDK" became « Je ne sais pas » (English→French is allowed by §1.3). It wraps onto two lines in the 3-column grid, so I added `textAlign: center` to that `Text` (a property of the existing widget, not a new component). The widget test at 320 px shows no overflow. **Please glance at it on a device.**

**R4. The DEAD fixture editor is still there.** The documents "+" on Ma Santé (`new_home_screen.dart:~1925`) opens the editor with invented data (A+, Metformine…) and a no-op save. It sends nothing (so no forbidden value), but a blood-type change there is silently not saved. It is scheduled for removal in Phase 1c; I recommend doing that first in 1c.

**R5. Ma Santé still opens on `'-'`**, because the read path (`UserProvider` never fills `bloodGroup`) is Phase 3. Untouched saves are now harmless, and a deliberate choice is saved.

**R6.** The onboarding save error no longer shows server text: one of the 9 sinks from P0 §f.3 is removed early. The other English strings on onboarding ("Please enter your first name.", "Height and weight", …) are untouched (Phase 1b ARB).

**Not done (by design):** `/profile/medical-data` wiring and conditions/medications persistence (Phase 3, decisions #1/#2); ARB migration (Phase 1b); deleting dead `toMedicalPassportJson` / `AccountUser.toJson.medicalInfo` (Phase 1c); the central `ApiFailure` parser (Phase 1b, which replaces `save_error_message.dart`).

## 7. Path to deliver G-2
1. **CTO:** review, answer R1 (may « Je ne sais pas » erase a known blood type?), glance at R3 on a device, then commit 1a-1 and 1a-2 as two commits.
2. **Run 1a-3:** urgent-cabinet tolerant parsing (unknown enum or phase → `unknown`, never a whole-snapshot `FormatException`), plus query max length 120, with contract tests from recorded server JSON.
3. **Then 1a-4** (`NO_SHOW`, C11 recorded as a design gap) **and 1a-5** (backend push semantic `type` + `templateType`), then Phase 1b, which absorbs `pending_fr_strings.dart` and `save_error_message.dart` into ARB and the `ApiFailure` parser.
