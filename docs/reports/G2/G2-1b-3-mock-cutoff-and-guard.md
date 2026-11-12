# G-2 · 1b-3 — mock cut-off, typed « indisponible » failure, and the import guard

_Date: 2026-11-11 · Repo: **OmniCare-App** (uncommitted, on top of 1a, 1b-1, 1b-2 and 1b-2c)_
_Testing rule (CTO): automated tests cover logic only; the CTO tests by hand through the app's screens (§9)._

> **Stopped on one item, as the task requires.** « Dossier médical » is not converted: five of its seven medical sections have no honest « indisponible » state to reuse (§2.3). The fixture « Sarah Ben Ahmed » therefore still shows on that tab. The guard lists it explicitly as the only allowed exception. Everything else is done.

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

| Deliverable | Status after this step |
|---|---|
| 2. App connected | No mock or fixture file is import-reachable from patient code any more, except the blocked « Dossier médical » fixture (§2.3). Medication search no longer invents suggestions. A typed `ApiFailure.featureUnavailable` now exists for every not-yet-wired feature. A guard test keeps mock data from coming back. |
| 3. Report per step | This file. |

## 2. Plan findings (step 1)

### 2.1 Method

- **Walk:** I walked the import graph from `lib/main.dart` over `import`, `export` and `part` directives. Every branch of a conditional import counts, because both branches ship, and multi-line directives are read whole. The walk is the same code as the guard test (§4).
- **Patient graph:** following P0 (§b.1, §d), the "patient graph" does not enter `lib/features/doctor/**`. Doctor-side findings are reported, not changed (§2.4).
- **Size:** 349 patient-reachable files and 450 in the full graph. These counts include conditional branches, which P0's 276 did not.
- **Doctor imports from patient code:** `patient_artifact_card.dart` and `scheduled_care_realtime_coordinator.dart` import doctor files (6 edges). I checked those 6 doctor files and everything they import (23 files): no mock is reachable through them.

### 2.2 Every production-reachable path into mock / fixture / demo data (before this step)

| # | Path (importer:line → data) | Executed in production? | What the patient sees | Existing state reused | Action |
|---|---|---|---|---|---|
| 1 | `core/api/medications_api.dart:1` → `mock_data/mock_medications.dart`; used by `MedicationSearchField` (`core/widgets/medication_search_field.dart:95`) | **Yes**: suggestions while typing a treatment in onboarding (`conversational_onboarding_screen.dart:1790`), « Modifier mes données médicales » (`edit_medical_data_screen.dart:587`) and the orphan `/medications` route (`medications_screen.dart:73`) | Invented medication suggestions | The field already catches errors (`medication_search_field.dart:101-106`): no dropdown, free text stays | **Cut**: search fails with `featureUnavailable` (§3). The field is unchanged. |
| 2 | `repositories/user_repository.dart:6` → `mock_data/mock_users.dart` | No: `main.dart` injects the real API. The mock was served only when `UserProvider` had no repository (`user_provider.dart:12`, `..useMock()`), which only tests do | — | Profile error state from 1b-2 (`profileLoadFailed`) | **Cut**: no API means `featureUnavailable` on every call; `useMock()`, `isMock` and the mock profile and avatar URL were deleted |
| 3 | `patient_appointments/application/patient_appointments_controller.dart:4,9` → `data/patient_appointment_mock_data.dart` | No: `new_home_screen.dart:101` builds `PatientAppointmentsScreen()` with no controller, which renders the real `PatientScheduledCareScreen` (`patient_appointments_screen.dart:35`) | Real scheduled care | — | **Cut**: `appointments` is now required; the mock default and its import were removed |
| 4 | `urgent_cabinet_flow_shell.dart:16`, `…_doctor_detail_screen.dart:16`, `…_doctor_directory_screen.dart:18`, `…_request_confirmation_screen.dart:13` → `urgent_cabinet_doctor_fixture.dart` | No: production injects no source, so the screens use the real repositories. The import existed because the **interface** `UrgentCabinetDoctorSource` lived in the fixture file | Real data | `UrgentCabinetDoctorUnavailableSource` (already existed) | **Cut**: the interface, the unavailable source and its exception moved to a new `urgent_cabinet_doctor_source.dart`. The 4 screens import that file. The fixture re-exports it for tests and the preview entry points. |
| 5 | `patient_passport/presentation/patient_passport_screen.dart:8,38` → `data/patient_passport_static_data.dart` | **Yes**: tab « Dossier médical » (`new_home_screen.dart:301`) | « Sarah Ben Ahmed »: fake identity, contact, blood group, allergies, conditions, 4 medications, 3 consultations, 5 fake relatives (when the real family list is empty, `:286-288`) | See §2.3 | **Blocked, not changed** |
| 6 | `providers/reservation_provider.dart:10` `..useMock()` → `repositories/reservation_repository.dart:2` → `mock_data/mock_reservations.dart` | No: not import-reachable from `main.dart` | — | — | **Removed** as asked: no `useMock()`; a missing API gives `featureUnavailable` |
| — | `lib/demo/**` | Never imported by production code | — | — | Nothing to do |

Also found: because of operator precedence, `repository ?? ReservationRepository()..useMock()` used to force mock mode **even on an injected repository**. That is gone.

### 2.3 Blocked: « Dossier médical » (medical safety rule) — CTO decision needed

**What the rule allows.** I checked every medical section of the screen for an honest « indisponible » state:

| Section | Widget (file:line) | Honest « indisponible » state to reuse? | What « no data » would show today |
|---|---|---|---|
| Blood group | `PassportEssentialInfoCard`, `_EssentialRow.value` (`passport_essential_info_card.dart:27-33`) | A plain text slot: « Indisponible » fits with no new UI. | — |
| Allergies | same (`:35-41`) | A plain text slot, as above. | — |
| Chronic conditions | chips `Wrap` over `data.chronicConditions` (`:62-90`) | **None** | An empty area under the title, which reads as "no conditions". An « Indisponible » chip would look like a condition named « Indisponible ». |
| Medications | `PassportMedicationsCard` (`passport_medications_card.dart:28-31,65`) | **None** | « 0 traitement(s) actif(s) » and an empty list: a false medical statement |
| Measurements | `PassportMeasurementsCard` takes `double heightCm, weightKg` and computes BMI (`passport_measurements_card.dart:7-54`); the view model **defaults to 180 cm / 78 kg** (`patient_passport_view_models.dart:139-140`) | **None** | Numbers only (0 cm, 0 kg, BMI 0.0) |
| History | `PassportHistoryTab` (`passport_history_tab.dart:115,123-128`) | **None** | « 0 consultations » + « Aucune consultation trouvée. »: an empty-list state, forbidden |
| Documents | `PassportDocumentsTab` (`passport_documents_tab.dart:28,77`) | **None** | Hardcoded « 0 documents enregistrés » + « Aucun document médical disponible »: an empty-list state, forbidden |

The app's only other "unavailable" component is `ClinicalFeatureUnavailableScreen`. It is a full-page route whose copy is about care requests (« Aucune demande, réservation ou consultation n’a été créée »), not a section state.

**Why I could not do part of it.** Putting the real identity (from `GET /profile`) above the fixture's medical sections would show Sarah's « Diabète Type 2 » and Metformine under the real patient's name. That is worse than today, so the screen is left exactly as it was.

**Options for the CTO:**

| Option | What it means | Pros | Cons |
|---|---|---|---|
| **A. Hide the « Dossier médical » tab until Phase 4** | Allowed by §1.3 ("hide the entry point of a feature that cannot work yet"). No new UI. | Fastest; removes the false record now | The header holds G-1's entry points: sharing settings and the secure medical QR (`patient_passport_screen.dart:118-123,196-198`). Hiding the tab hides them too, so **G-1 must agree** |
| **B. Design one section-level « indisponible » state in Figma, then wire the screen** | Identity from `GET /profile`. Blood group and allergies read « Indisponible ». Conditions, medications, measurements, history and documents use the approved state. | The honest end state the task describes | Needs design first (roadmap §1.3: "design goes through Figma first") |
| **C. Text slots only, as an interim** | Blood group and allergies read « Indisponible ». The medications subtitle and the history / documents count lines become « Indisponible ». | Little UI change | Conditions, measurements and the two empty-list cards still need a design decision, so this does **not** fully satisfy the rule |

**Recommendation:** decide **A now** as a safety stop-gap if G-1 agrees, and **B** for Phase 4. Until a decision, the fixture stays; it is listed in the guard as the single allowed exception (§4).

### 2.4 Doctor side: reported, not changed

| Doctor importer | Data | Use |
|---|---|---|
| `features/doctor/consultation_detail_screen.dart` → `core/api/consultations_api.dart:1` | `mock_data/mock_consultations.dart` | `ConsultationsApi` returns mock consultations (`:10,:18`) to the doctor consultation-detail screen in the doctor shell (reachable from `main.dart` through `doctor_auth_shell_screen.dart`) |
| `features/doctor/medical_record/doctor_medical_record_access.dart:2,123` | `patient_passport_static_data.dart` | `DoctorMedicalRecordAccess.fullDemo(...)`, documented as "test/preview-only" |

Also noted, outside the forbidden name patterns: `features/doctor/demo/doctor_demo_profile.dart`, `doctor/agenda/doctor_demo_appointment.dart` and `doctor/home/doctor_home_demo_state.dart`. The guard pins the doctor-side list (§4), so it cannot grow unnoticed.

### 2.5 Left for Phase 1c (not reachable from `main.dart`; not deleted, as instructed)

- `useMock()` remains in `consultation_repository`, `medical_act_repository`, `doctor_repository`, `file_repository`, `patient_repository` and `medication_repository`.
- `mock_data/mock_{doctors,patients,reservations,users,medications}.dart`, `patient_appointment_mock_data.dart`, `lib/demo/**`, `main_demo.dart` and `main_p4_recovery_preview.dart` are all now unreachable (or reachable only from the doctor side, for `mock_consultations`).
- STATIC content (home stats, clinic catalog) is untouched, as instructed; those files are not named `*_static_data.dart`.

## 3. What changed

- **Typed failure** (`core/network/api_failure.dart`):
  - new `ApiFailureKind.featureUnavailable`;
  - new `ApiFailure.featureUnavailable` (local code `FEATURE_UNAVAILABLE`) and `isFeatureUnavailable`.
  - `apiFailureMessage` maps it to « Cette fonctionnalité est indisponible pour le moment. » (new ARB key `apiErrorFeatureUnavailable`).
  - It works with `Result<T>`: `guardApiCall` gives `Err(featureUnavailable)`.
- **Medication search** (`core/api/medications_api.dart`): the mock import is gone. `searchTop10` and `searchDistinctDciTop20` throw `featureUnavailable` for any non-empty query, and an empty query still returns `[]`. `MedicationSearchField` is unchanged: it catches the error and shows no dropdown, and free text still works.
- **User profile** (`repositories/user_repository.dart`, `providers/user_provider.dart`): the mock import, `useMock()`, `isMock`, the mock profile and the fake avatar URLs are gone. With no API, all five calls throw `featureUnavailable`, including `saveOnboardingStep`, which used to return `null`, i.e. a silent fake success. `UserProvider()` defaults to `UserRepository()`.
- **Appointments** (`patient_appointments_controller.dart`): `appointments` is required, and the mock default and its import are gone.
- **Urgent CABINET:** new `urgent_cabinet_doctor_source.dart` holds the interface, the unavailable source and its exception, moved verbatim. The 4 screens import it; the fixture file imports and re-exports it.
- **Reservations** (unreachable): `ReservationProvider` no longer calls `useMock()`. `ReservationRepository` lost `useMock()`, `isMock` and the mock import, and its 3 no-API branches throw `featureUnavailable`.
- **Not touched:**
  - the « Dossier médical » screen, its widgets and its fixture (§2.3);
  - `lib/features/doctor/**`, `patient_passport/sharing/**`, STATIC content and the backend;
  - every layout and style. No screen file changed except the import line of the 4 urgent CABINET screens.

## 4. Guard test: `test/production_mock_import_guard_test.dart`

**What it checks:**
- **Walker** (pure Dart): it starts at `lib/main.dart` and follows `import`, `export` and `part`. It reads every URI of conditional imports, reads multi-line directives whole, and ignores comments. Its cost is O(files + directives).
- **Rules:**
  1. The **patient graph** reaches no `lib/mock_data/**`, `lib/demo/**`, `*_fixture.dart` or `*_mock_data.dart` file. A failure prints the full import chain.
  2. Every reachable `*_static_data.dart` file is on the explicit list **`toRemoveIn1c`**, so a **new** static file fails. Today the list holds one entry, the blocked passport fixture, with its reason.
  3. No stale entries: every file on `toRemoveIn1c` must still be reachable, so the list shrinks as files go.
  4. The forbidden files reached **only** through `lib/features/doctor/**` must equal **`reportedDoctorSideOnly`** exactly: today, `mock_consultations.dart`. A new doctor-side mock is noticed; a removed one forces the list to be updated.
  5. Sanity: the walk reaches more than 200 files, including a conditional-import branch, so a broken walker cannot pass by reaching nothing.
- **Walker self-tests:** a synthetic tree proves the walker follows package, relative, conditional, `export` and `part` URIs; skips commented imports; catches mock and fixture files; and stops at the doctor boundary.

**Proof that it fails (done for real, then reverted).** I temporarily added to `lib/features/home/new_home_screen.dart`:

```dart
import '../../mock_data/mock_users.dart';
import 'home_proof_static_data.dart'; // a new empty file
```

`flutter test test/production_mock_import_guard_test.dart` then failed on exactly the two rules:

```
[E] no mock, fixture or demo file is reachable from patient code
    lib/mock_data/mock_users.dart <- lib/features/home/new_home_screen.dart <- lib/main.dart
[E] every reachable *_static_data.dart file is on the 1c list
    lib/features/home/home_proof_static_data.dart <- lib/features/home/new_home_screen.dart <- lib/main.dart
+5 -2: Some tests failed.
```

I then restored the screen from a backup copy and deleted the temporary file. 0 « TEMP » lines are left, and the guard is green again (+7).

## 5. Evidence

- `flutter analyze`: **388 issues**, the same as the baseline, none new.
- `flutter test`: **1931 passed, 7 skipped** (1914 before, plus 17 new). The ARB drift test is green.
- **New tests:**
  - **`test/production_mock_import_guard_test.dart`, 7 tests:** the 5 guard rules plus 2 walker self-tests.
  - **`test/mock_cutoff_test.dart`, 10 tests:**
    - the failure is typed and French, and survives `ApiFailure.from`;
    - medication search: any query is unavailable, an empty query gives `[]`;
    - `UserRepository` without APIs: all 5 calls are unavailable, `guardApiCall` gives `Err`, and the default `UserProvider` keeps the failure and **no profile**;
    - reservations: the repository and the provider are unavailable (no forced mock);
    - the appointments controller shows only what it is given;
    - the urgent CABINET unavailable source fails, imported from the non-fixture file.
- **Updated tests:**
  - `api_failure_parser_test` adds the new kind to the per-kind message table;
  - `patient_appointments_test` passes the mock list explicitly, since tests may use fixtures.
- **Not written:** the requested "passport view model exposes real identity and unavailable for every medical section" test. That item is blocked (§2.3).

## 6. Complexity

- The guard walk is O(files + directives): one pass and one visited map.
- No runtime cost was added to the app. The failure is a `const`, and the removed code paths took no work.

## 7. Risks, open questions, things not done

| # | Item | Proposal |
|---|---|---|
| R1 | **« Dossier médical » still shows the « Sarah Ben Ahmed » fixture** in production: a fake medical record presented as the patient's own. | Decide §2.3 (recommended: A now, if G-1 agrees, then B). |
| R2 | The doctor side still reaches `mock_consultations` and the passport fixture (§2.4). | The doctor workstream; the guard pins the list. |
| R3 | Medication search now silently offers nothing. Patients type the name freely, which is the field's existing behaviour without results. | A real catalog needs the backend: P0 F4, `/api/v1/passport/**` is denied today. |
| R4 | `UserRepository` was touched but not converted to `Result<T>`: only its mock branches changed, and the provider contract is the same as in 1b-2. | Include it in the `Result` adoption step (1b-2c R2). |
| R5 | Urgent CABINET screens still contain `isDevelopmentFixture` branches (development badges). They can't trigger in production, since no fixture source is injected. | Phase 1c clean-up with the preview entry points. |

## 8. Path to deliver G-2

1. **CTO:** decide §2.3, run §9, and commit the app work (1a through 1b-3) and the backend 1b-2b paths.
2. **The « Dossier médical » step**, once decided: if A, hide the tab with G-1's agreement; if B, a Figma state, then identity from `GET /profile` and « indisponible » sections, with the view-model test this task asked for. The guard's `toRemoveIn1c` list then becomes empty.
3. **Rest of Phase 1b:** build config (`--dart-define-from-file`, no `.env` asset), logging, clock and Tunis time, timeouts, retry and the Idempotency-Key helper, and `Result` per patient-only repository.
4. **Phase 1c:** honest STATIC states (home stats, clinic catalog…), then delete the unreachable code in one PR (§2.5).
5. **Translation pass**, Phases 2–12 (push in Phase 6), the **release gate (§8)**, and the final G-2 report.

## 9. Manual test steps for the CTO (through the app's screens)

Run a debug build against the local backend, logged in as a patient.

1. **Onboarding, treatments.** Create a new account, or resume onboarding, and reach the treatments step. Type « dol ». **No suggestion list** appears (before: invented medications). Type a full name freely and continue: the step saves as before.
2. **Modifier mes données médicales.** From the home « Ma Santé » card, open the medical-data editor and type a medication name. No suggestions; free text is accepted; nothing else changed on the screen.
3. **Profile loads for real.** Open the profile. The name, phone and photo are yours (from the server), never a demo user. Then stop the backend, kill the app and reopen it. You see the existing French loading error (« Impossible de charger le profil. » or the connection message), never a fake profile.
4. **Mes rendez-vous.** Open appointments from the home screen. The real scheduled-care screen shows, unchanged.
5. **Urgent CABINET (regression).** Open the urgent CABINET doctor list, a doctor detail and the confirmation screen. You see real data or the existing error states, as before, with no "démonstration" badge.
6. **« Dossier médical » (unchanged, the blocked item).** Open the tab. It still shows « Sarah Ben Ahmed »; this is expected until the §2.3 decision. Confirm the share settings and the secure QR still open.
7. **Nothing else moved.** Browse home, family, requests, booking and documents: no visual change compared with the previous build.
