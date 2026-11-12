# G2 FT-3: « Dossier médical » wired to the FT-1 routes

**Date:** 2026-11-11 · **Repo:** OmniCare-App · **Switch:** `MEDICAL_RECORD_LIVE` stays **off** by default; everything below is visible only in a build with `--dart-define=MEDICAL_RECORD_LIVE=true`. The switch-off state is reported in `G2-1b-3b-medical-record-temporary-state.md`.

## 1. Goal card and status

> GOAL G-2: Connect the patient Flutter app to the real backend without changing the current UI, with a report at every step.
> Done when every patient screen reachable from production main.dart shows real data or an honest "indisponible" state (no fixture, no mock), the release build passes the G-2 gate (§8), and every step has a report in OmniCare-App/docs/reports/G2/.

The first version of this report stopped at the plan with six questions. The CTO's decisions, as implemented:

| # | Decision | Done |
|---|---|---|
| 1 | Antécédents UNKNOWN / NONE_KNOWN: plain text in the card's body style; LIST → chips | ✅ |
| 2 | Per-card error: French text from `apiFailureMessage` + « Réessayer » (retries that card only); loading: default `CircularProgressIndicator` | ✅ |
| 3 | Ordonnances/certificats not in the passport for V1; `patient_artifact_card.dart` untouched | ✅ (not wired, not touched) |
| 4 | Pencil hidden for SELF and family, in both switch states | ✅ |
| 5 | Empty texts for current and past treatments | ✅ |
| 6 | History: first page (20) only, filters on the loaded page, no "see more" | ✅ |
| 7 | One repository (`Result<T>`), subject SELF/FAMILY, cancel and clear on switch, clear on logout, Tunis dates, FLAG_SECURE, `MRS_UNAVAILABLE` text | ✅ (specialty: see §6, item 1) |
| 8 | Logic tests, analyze, test | ✅ (§7) |

## 2. Plan as built: each card → route → honest states

| Card | Route (`GET /api/v1/me/medical-record/…?subject=`) | States |
|---|---|---|
| Header, identity, family selector | — (`UserProvider`, `FamilyProvider`) | as in 1b-3b |
| Groupe sanguin | `medical-data` · `lifeSafety.bloodType` | null → « Non renseigné » |
| Allergies | `allergies`, `allergiesStatus` | UNKNOWN (and any unknown value) → « Non renseigné » · NONE_KNOWN → « Aucune allergie connue » · LIST → items joined (an empty LIST → « Non renseigné ») |
| Conditions chroniques | `criticalConditions`, `conditionsStatus` | UNKNOWN → « Non renseigné » · NONE_KNOWN → « Aucun antécédent connu » (plain text, value style of the card) · LIST → the existing chips |
| Médicaments (Actuels / Anciens) | `medications?group=CURRENT|PAST&size=20`; past loads on the first tap of « Anciens » | empty → « Aucun traitement en cours prescrit sur OmniCare. » / « Aucun ancien traitement prescrit sur OmniCare. »; the count reads "20+" when more exist |
| Mesures corporelles | `medical-data` · `heightCm`, `weightKg`, `bmi` | each null → « Non renseigné » (unit hidden); never a default |
| Historique | `consultations?size=20`, loaded on the first visit to the tab | empty → the existing « Aucune consultation trouvée. »; row: date (Africa/Tunis, « 12 févr. 2026 »), « Dr {prénom nom} », reason · specialty (« Non renseigné » when missing), G-1's sharing toggle |
| Any card whose request fails | — | the French failure text (`MRS_UNAVAILABLE` → « Le dossier médical est temporairement indisponible. Réessayez plus tard. »; otherwise the kind's text, or « Impossible de charger ces informations. ») + « Réessayer »; **never an empty list** |
| Documents tab | — | unchanged (FT-3b) |

`medical-data` feeds two cards (essential info and measurements): they share one state, and « Réessayer » on either reloads that one request.

## 3. What changed (FT-3 part; the 1b-3b part is in its own report)

| File | Change |
|---|---|
| `features/patient_passport/data/medical_record_models.dart` | **New.** `RecordSubject` (SELF / `FAMILY:{id}`), `RecordListStatus` (unknown fallback), `MedicalDataRecord`, `MedicationRecord`, `ConsultationRecord`, `RecordPage`. Immutable, no `dynamic`; a missing id or date → `FormatException` (nothing partial) |
| `features/patient_passport/data/medical_record_api.dart` | **New.** `GET /me/medical-record/{medical-data,medications,consultations}` with `subject`, `Cache-Control: no-store`, and a `CancelToken` |
| `features/patient_passport/data/medical_record_repository.dart` | **New.** `Result<T>` through `guardApiCall`; lists are `size=20` only |
| `features/patient_passport/application/medical_record_view_model.dart` | **New.** One state per section (idle / loading / ready / failed). `show(subject)` loads medical data and current treatments; `ensureLoaded` loads past treatments and history on first use; `retry(section)` reloads one section. A subject change cancels in-flight requests and clears every section before reloading; a generation counter drops late answers. `clear()` is called at logout and on account change. With the switch off, no request is ever made |
| `features/patient_passport/presentation/medical_record_presenter.dart` | **New.** Pure status → text mapping, rows, Tunis dates, failure text, card status |
| `features/patient_passport/presentation/widgets/passport_card_status.dart` | **New.** The approved loading / failure + « Réessayer » body |
| `passport_essential_info_card.dart`, `passport_medications_card.dart`, `passport_measurements_card.dart`, `passport_history_tab.dart` | **Additive** optional parameters (`status`, `conditionsText`, `emptyText`, `hasMore`, nullable measurements + `bmi`). The doctor screen (G-1), which reuses three of these cards, keeps calling them unchanged with the same result; the measurement card looks up the « Non renseigné » text only when a value is missing |
| `patient_passport_screen.dart` | Cards bound to the view model; history filters applied to the loaded page; the sharing toggle updates the loaded consultation; FLAG_SECURE on and off |
| `core/platform/secure_screen.dart` + `android/…/MainActivity.kt` | **New** `omnicare/secure_screen` channel: `FLAG_SECURE` on while the screen is shown with the switch on, cleared on dispose (the tab body is rebuilt on each tab change, `new_home_screen.dart:314-326`). A no-op on iOS and web; no new dependency |
| `lib/main.dart` | Registers `MedicalRecordViewModel`; `clear()` on logout and on account change, next to G-1's sharing controllers |
| `l10n/app_fr.arb` (+ generated) | 9 FT-3 keys (texts above, `passportRetry`, `passportDoctorName`, `passportTimesPerDay`, `passportSectionLoadFailed`) |
| `test/medical_record_test.dart` | **New.** 16 logic tests (§7) |
| `test/l10n_arb_contract_test.dart` | The generated-class check now also accepts messages with placeholders (generated as methods); these are the first ones in the app |

## 4. Complexity, memory, privacy
- **Requests:** at most 4 per subject (medical data and current treatments on open; past treatments and history on first use), each at most 20 items. Nothing fetches a whole list.
- **Mapping:** O(page) mapping; the filters are O(page) on 20 items.
- **Memory:** record data lives only in `MedicalRecordViewModel`. It is replaced on a subject change, and cleared at logout or account change: the next patient never sees the previous one's data.
- **In-flight requests** are cancelled on a subject change, a clear or dispose; late answers are dropped.
- **Privacy:** no medical value is logged. The `subject` query carries only `SELF` or a family member id, never an MRS id.

## 5. Editing medical data today (decision 4)
The passport pencil is hidden. Where a patient can still edit:
- **Themself:** « Ma Santé » tab → edit medical data (`EditMedicalDataScreen`, opened at `new_home_screen.dart:~1735`). Only a changed **blood type** is saved, through `PATCH /api/v1/profile/passport` (`features/home/medical_data_save.dart:10-13`). Conditions and medications are not sent (Phase 3).
- **A family member:** the family member detail screen → `FamilyProvider.updateMedicalPassport` (`family_member_detail_screen.dart:79`) → `PATCH /api/v1/profile/family-members/{id}/passport`. **Blood type only.**
- **Onboarding** also saves the blood type (`onboarding_progress.dart:347`).

## 6. Risks, findings, not done
1. **Specialty is not a code.** `professional_profiles.specialty` is free text typed by the professional (`varchar(100)`, no enum; real values look like « Cardiologie », « Médecin généraliste »), so there is no code set to translate through ARB. It is shown as entered, as the patient doctor directory already does (`doctor_directory_mapper.dart:16`), and « Non renseigné » when missing. If you want codes, the backend needs a specialty list first.
2. **No real OmniCare ID** (see 1b-3b §5): that row reads « Non renseigné ».
3. **Documents tab with the switch on:** still the old empty card (« Aucun document médical disponible »). FT-3b replaces it before the switch is turned on.
4. **No pull-to-refresh** exists on this screen. Data is reloaded on a subject change, after logout, or with « Réessayer ». Reopening the tab for the same subject keeps the loaded data.
5. **The backend must have the FT-1 code** (Spring and MRS) for the switch-on build, and FT-1/FT-2 are still uncommitted.

## 7. Evidence
- **`test/medical_record_test.dart`: 16/16 pass.**
  - Honest texts: every allergies and conditions status (an unknown value is never "none"), blood type and measurements null → no default, both empty-treatment texts, the treatment row, the Tunis date (23:30 UTC on 11 Feb → « 12 févr. 2026 »), doctor, specialty and missing values.
  - Card status: `MRS_UNAVAILABLE` → its French text, and « Réessayer » calls the retry.
  - View model:
    - switch off → 0 requests;
    - `SELF` with `group=CURRENT&size=20`;
    - history `size=20`, loaded once;
    - a failure → a failed state (never an empty list);
    - a malformed body → `Err`;
    - « Réessayer » reloads only that section;
    - a family switch sends `FAMILY:fam-1` and clears the previous data;
    - a late answer from the previous subject is dropped, and the state stays loading;
    - logout clears every section, and the same subject is fetched again;
    - a sharing change updates one row.
  - Identity: covered by the 1b-3b report.
- **Affected suites:** `l10n_arb_contract_test`, `p5_06_patient_qr_test`, `doctor_medical_record_test`, `production_mock_import_guard_test` and `medical_record_test` pass (58 tests).
- **`flutter analyze`:** 388 issues, the same set as the baseline (diff empty).
- **`flutter test` (full):** **1946 passed, 7 skipped, 0 failed** (baseline 1931 + 16 new + 2 new guard tests − 3 deleted fixture widget tests).
  - An earlier full run, before the fixes, ran unusually long (about 19 minutes) and had 12–14 failures. Most were caused by this change, and all are fixed:
    - the ARB contract (`localeName`, a message read through another variable name, messages with placeholders);
    - G-1's QR tests without localization delegates;
    - the doctor test harness without delegates (the measurement card now looks up the text only when needed).
  - The other 2 (`patient_scheduled_care_test`) pass alone and in the final run: load-related flakes, not caused by this change.

## 8. Manual test steps for the CTO
Run with `flutter run --dart-define=MEDICAL_RECORD_LIVE=true` against a **local backend with the FT-1 code** (Spring and MRS). Use two test accounts: patient A, with at least one family member, and patient B. Ideally A has a completed consultation with a prescription, and a blood type recorded.
1. Log in as A and open « Dossier médical ». Each card shows a spinner, then your data. Blood type is real or « Non renseigné ». Allergies and conditions show the items, « Aucune allergie connue » / « Aucun antécédent connu », or « Non renseigné » (conditions as plain text, not a chip). Measurements are real or « Non renseigné », never 180 cm / 78 kg. There is no pencil icon.
2. Médicaments: « Actuels » lists your current treatments, or « Aucun traitement en cours prescrit sur OmniCare. ». Tap « Anciens »: a spinner, then past treatments, or « Aucun ancien traitement prescrit sur OmniCare. ».
3. Open « Historique »: your completed consultations, newest first, at most 20, each with the date in Tunisian time, « Dr {name} », reason · specialty, and the sharing toggle. With none: « Aucune consultation trouvée. ». Search and filters work on this list. Toggle sharing on one consultation: the icon updates.
4. Tap your name and pick your family member. Every card reloads (spinner) and shows that member's record, never yours; the Spring log shows `patient_record_read … subject=FAMILY_MEMBER`. Switch back to yourself: your data comes back.
5. Stop the MRS container, then switch to the family member again. Each card shows « Le dossier médical est temporairement indisponible. Réessayez plus tard. » with « Réessayer », and no empty list. Restart MRS and tap « Réessayer » on the measurements card: only that card reloads.
6. On Android, try a screenshot on « Dossier médical »: it is blocked, and the recent-apps preview is blank. Go to another tab: screenshots work again.
7. Log out, log in as B, and open « Dossier médical »: only B's data appears, nothing from A.
8. The « Documents » tab is unchanged in this step (FT-3b).
9. Rebuild without `--dart-define`: the 1b-3b temporary message is back, and no medical request reaches the backend (no `patient_record_read` line in the Spring log).

## 9. Path to deliver G-2
1. **You:** run the 1b-3b and FT-3 manual steps, and commit (the app, plus FT-1 and FT-2 in the backend repos).
2. **FT-3b:** the documents section on the FT-2 routes (status polling, title, 15 MB, cursor paging); patient viewing per your FT-2 §3c decision; then turn the switch on by default. **FT-4:** PDF download streamed to a temp file with a cap (`patient_artifact_card.dart`).
3. **Then:** Phase 3 (editing in MRS), Phase 6 (push), Phase 9 (Ma Santé on these reads), and the G-2 release gate.
