# G3-ONB-P0 — Patient medical onboarding: factual inspection (read-only)

Scope: the current 5-page patient onboarding and the endpoints it calls, in App, Spring and MRS. The aim is to build the approved redesign without changing data or logic.

This was read-only. The only file written is this report. No git command was run and the app was not started. `flutter analyze` was run on the onboarding files only (§g). No health value or real patient data appears below.

Paths: **App** = `OmniCare-App/`, **BE** = `OmniCare-BackEnd/src/main/java/com/omnicare/app/`, **MRS** = `omnicare-mrs/internal/`.

## Plan (as executed)

- **Entry:** `navigateAfterAuthentication` (`lib/features/auth/application/post_auth_navigation.dart:24`) calls `pushNamedAndRemoveUntil(auth.nextRoute)` (`:101-102`).
  - `nextRoute` maps `AuthRouteDecision.onboarding` to `'/conversational-onboarding'` (`auth_controller.dart:92`).
  - The decision is made when a PATIENT has `profile.onboardingCompleted == false` (`auth_flow_models.dart:77-80`).
  - The route is defined in `lib/main.dart:438-441` → `ConversationalOnboardingScreen(accountApi: AccountApi(...))`.
- **Files read from there (imports only):**
  - `lib/features/onboarding/` (4 files)
  - `lib/providers/user_onboarding_provider.dart`
  - `lib/core/api/account_api.dart`, `lib/core/api/medications_api.dart`
  - `lib/core/widgets/medication_search_field.dart`
  - `lib/core/models/blood_type.dart`, `lib/core/l10n/blood_type_label.dart`, `lib/core/models/patient_profile.dart`
- **Spring:** the controller for each path, then the service and DTO, then `PassportService`, `MrsOnboardingSyncService`, `MrsMedicalDataService` and the MRS client.
- **MRS:** the route registered for the client path, then the record-type validators.
- **Tests:** files that import an onboarding file.
- **Roadmap:** `docs/roadmap/OmniCare_G2_Patient_Flutter_Roadmap.md` (current, v1.20+). The older `G2_Patient_Flutter_Roadmap.md` was also checked.

---

## a) Screen map

All 5 pages are one `PageView` inside one route (`conversational_onboarding_screen.dart:602-614`). Pages can also be swiped (no `physics` lock), so `_validateThrough` re-validates every earlier page (`:303-315`).
- Back: an AppBar arrow on pages > 0 calls `previousPage` (`:569-582`).
- « Skip » (`:584-597`) goes to `/home`.
- Pinned « Continue / Complete » button (`:644-667`).
- Progress: 5 dots, `SmoothPageIndicator` (`:631-642`).
- The UI calls `OnboardingProgressController` (`onboarding_progress.dart:146`), which calls `AccountApi`. There is no ChangeNotifier for onboarding state. `UserOnboardingProvider` is used as a scratch store (§i).

| # | Page (file:line) | Saved by | HTTP | Spring handler | MRS | When saved | Platforms |
|---|---|---|---|---|---|---|---|
| 0 | Identity « Confirm your profile » `_buildBasicProfilePage` `:686` | `_sendStep(1, …)` `onboarding_progress.dart:247-248` | POST `/api/v1/profile/onboarding/step/1` (`account_api.dart:39-48`) | `OnboardingController.saveStep` `BE profile/controller/OnboardingController.java:26-35` → `OnboardingService.saveStep` case 1 `OnboardingService.java:62-72` | `syncBasics` with null basics (the app sends none) → no MRS write (`MrsOnboardingSyncService.java:26-44`, `MrsMedicalDataService.java:79,101`) | On « Continue » of page 0, only while server `onboardingStep ≤ 1` (`onboarding_progress.dart:39-40`) | Android, iOS, web (no `kIsWeb` branch in `lib/features/onboarding`) |
| 1 | Blood type + height/weight `_buildBloodTypePage` `:902` | `_saveBody` `onboarding_progress.dart:337-362` | PATCH `/api/v1/profile/passport` (`account_api.dart:52-63`) | `ProfileController.updatePassport` `ProfileController.java:66-76` → `UserProfileService.updatePassportFields` `UserProfileService.java:82-104` → `MrsMedicalDataService.updateBasics` `:58-125` | Outbox → `PUT /internal/mrs/patients/{id}/singleton-records/{LIFE_SAFETY\|BODY_MEASUREMENTS}` (`HttpMrsMedicalRecordClient.java:63-75`) → `upsertSingletonRecord` (`MRS api/medical_records.go:113-116`) | On « Continue » of page 1, only the fields that differ from the server (`onboarding_progress.dart:343-351`); skipped once onboarding is complete (`:338`) | same |
| 2 | Allergies `_buildAllergiesPage` `:1117` | `_sendStep(2, onboardingStep2Body)` `:251-256` | POST `/profile/onboarding/step/2` | `OnboardingService.java:73-79` → `PassportService.saveAllergies`/`clearAllergies` `PassportService.java:39-58` (table `passport_allergies`) | **None at this step.** Allergy *names* reach MRS LIFE_SAFETY only at step 4 / skip via `MrsOnboardingSyncService.sync` (`:46-66`) | On « Continue » of page 2 while server step ≤ 2 | same |
| 3 | Chronic conditions `_buildConditionsPage` `:1404` | `_sendStep(3, …)` `:257-262` | POST `/profile/onboarding/step/3` | `OnboardingService.java:80-86` → `PassportService.saveConditions`/`clearConditions` `:67-85` (`passport_conditions`) | **Never** from onboarding: `sync` sends only conditions with `criticalOptIn == true` (`MrsOnboardingSyncService.java:56-59`), and the app always sends `false` (`onboarding_basics_payload.dart:76`) | On « Continue » of page 3 while server step ≤ 3 | same |
| 4 | Medications `_buildMedicationsPage` `:1579` | `_sendStep(4, …)` `:263-267` | POST `/profile/onboarding/step/4` | `OnboardingService.java:87-95`: `ensureRequiredProfileFields`, then `savePatientOwnedMedications`/`clearMedications` (`PassportService.java:94-117`, `passport_medications`), then `sync`, then `markOnboardingCompleted` (`:103-104`) | `sync` writes LIFE_SAFETY v2 (blood type + allergy names) (`MrsOnboardingSyncService.java:46-66`). Medications are **not** sent to MRS (not in `sync`) | On « Complete »; then `_finishOnboarding` (`conversational_onboarding_screen.dart:404-416`) → `OnboardingCompleteScreen` | same |
| — | Completion `OnboardingCompleteScreen` `onboarding_complete_screen.dart:9` | — | none | — | — | No data saved; « Take a Quick Demo » and « Go to Dashboard » both go to `/home` (`:185-188`, `:219-221`) | same |

- **Reads on open:** `_loadResume` (`conversational_onboarding_screen.dart:203-245`) runs `OnboardingProgressController.load` (`onboarding_progress.dart:169-197`).
  - `GET /api/v1/profile?includeMedical=false` (`account_api.dart:16-22`) → `ProfileController.getProfile` (`:41-52`).
  - `GET /api/v1/profile/medical-data` (`account_api.dart:31-33`) → `ProfileController.getMedicalData` (`:78-86`), which reads the MRS snapshot.
  - It then jumps to the first unsaved page (`onboardingResumePage`, `onboarding_progress.dart:46-59`).
- **Global « Skip »** (`conversational_onboarding_screen.dart:584-587`) only calls `pushReplacementNamed('/home')`.
  - It does **not** call the existing `POST /api/v1/profile/onboarding/skip` (`OnboardingController.java:37-42`, `OnboardingService.skipOnboarding` `:123-139`). There is no caller in `lib/` (grep `onboarding/skip|skipOnboarding`: 0 hits).
  - The server still has `onboardingCompleted = false`, so the next sign-in or restore routes back to onboarding (`auth_flow_models.dart:78-80`).

## b) Data per step

| Step | Field | Widget (file:line) | Dart type | Allowed values / unit | App validator (file:line) | Sent as | Server rule (file:line) | Mismatch |
|---|---|---|---|---|---|---|---|---|
| 0 | First name | `TextField` `_buildProfileTextField` `:726-731`, `:820-854` | `String` (trimmed) | free text, no max length | non-empty `:420-421` | `firstName` (`onboarding_basics_payload.dart:57-62`) | `@Size(max=100)` `BE profile/DTO/OnboardingStepRequest.java:18-19`; blank keeps stored value `UserProfile.java:138-139` | **Yes**: no max length in the app (101+ characters → 400) |
| 0 | Last name | `:733-738` | `String` | same | non-empty `:422-423` | `lastName` | `@Size(max=100)` `:20-21` | **Yes**: same |
| 0 | Birth date | read-only `TextField` + Material `showDatePicker` `:740-779`, `:526-539` | `DateTime` → `yyyy-MM-dd` (`:541-546`) | 1900-01-01 … today (`:531-532`); no age rule | set, and before now (`:424-427`) | `dateOfBirth` | `LocalDate`, no constraint (`OnboardingStepRequest.java:22`) | No (but sign-up requires 18+; onboarding accepts any past date, see Q5) |
| 0 | Gender | 3 tiles `_buildGenderOption` `:790-814`, `:856-900` | `String?` | `'M'` « Male », `'F'` « Female », `'autre'` « Other » | non-empty `:428-429` | `gender` | normalized to M/F/autre `OnboardingService.java:153-163`; DB `CHECK (gender IN ('M','F','autre'))` `src/main/resources/db/changelog/modules/02-profile/0200-profile-schema.yaml:165` | No. Note: sign-up offers only M/F (P2b); onboarding adds « Other » |
| 1 | Blood type | 3×3 grid of tiles `:953-1010` | `String?` wire value in `UserOnboardingProvider.bloodGroup` (`user_onboarding_provider.dart:74,120-123`) → `BloodType` | A+, A-, B+, B-, AB+, AB-, O+, O-, `unknown` (« Je ne sais pas », `blood_type.dart:7-16`, `blood_type_label.dart:7-8`, ARB `bloodTypeUnknown` `app_fr.arb:163`) | none (optional) | `bloodType`, only if changed, with the « unknown never erases » guard (`onboarding_basics_payload.dart:33-46`, `onboarding_progress.dart:339-343`) | `ALLOWED_BLOOD_TYPES` = 8 groups `MrsMedicalDataService.java:27-29`; `unknown` → null (`:277-286`); clearing a stored type → 400 (`:80-86`); MRS v2 accepts 8 groups + UNKNOWN (`MRS records/life_safety_v2.go:20,30`) | No |
| 1 | Height | `TextField` `_buildMeasurementField` `:1024-1028`, `:1082-1115` (keyboard: integers) | `int?` (`int.tryParse`, `:183`) | cm (suffix `'cm'`) | required, then `0 < h < 300` (`:448-453`) | `heightCm` (`account_api.dart:57-60`) | Spring `@Positive` `UpdatePassportRequest.java:11-12`; MRS write guard `30 ≤ h ≤ 300` `MrsMedicalDataService.java:206`; MRS validator `30..300` `MRS records/registry.go:324`, `body_measurements_v2.go:24-25` | **Yes**: the app accepts 1–29 (rejected by the server → 400), rejects 300 (accepted by the server), and rejects decimals (« 170.5 » → `int.tryParse` null → « Please enter a valid height. ») |
| 1 | Weight | same `:1031-1037` (decimal keyboard) | `double?` (`,` → `.` at `:184-185`) | kg (suffix `'kg'`) | required, then `0 < w < 500` (`:449-456`) | `weightKg` | Spring `@Positive` `UpdatePassportRequest.java:13-14`; MRS `0 < w ≤ 500` `MrsMedicalDataService.java:206`, `registry.go:324`, `body_measurements_v2.go:26,51` | **Yes, small**: 500 rejected by the app, accepted by the server |
| 1 | Height + weight together | — | — | — | both required on the page (`:448-451`) | both sent when either changed (`onboarding_progress.dart:344-351`) | « must be provided together » `MrsMedicalDataService.java:101-105` | No |
| 2 | Allergy name (per card) | `TextField` `:1215-1248` | `String` | free text, no max length | a name is required when the card is marked life-threatening (`:472-474`) | `allergies[].name` (`user_onboarding_provider.dart:35-39`) | `@NotBlank @Size(max=200)` `OnboardingStepRequest.java:45-47`; MRS LIFE_SAFETY v2 items ≤ 50, each ≤ 160 characters (`MRS records/life_safety_v2.go:34-35,137-138`) | **Yes**: the app has no limit; 161–200 characters pass Spring at step 2 but exceed MRS when `sync` writes at step 4 (outbox, async: the failure path is **UNVERIFIED**, outbox job not read) |
| 2 | Severity | 3 chips `_buildSeverityOption` `:1259-1279`, `:1372-1402` | `String` | `'légère'` « Mild », `'modérée'` « Moderate » (default, `:137`), `'sévère'` « Severe » | non-empty when a name is set (`:476-478`); always true because of the default | `allergies[].severity` | `@NotBlank` only (no enum) `OnboardingStepRequest.java:48-49`; column `length=20` `PassportAllergy.java:28-29`; **not** sent to MRS (names only, `MrsOnboardingSyncService.java:53-55`) | No; the server accepts any text |
| 2 | Life-threatening | `SwitchListTile.adaptive` `:1281-1305` | `bool` | true/false, default false (`:138`) | — | `allergies[].lifeSafety` | stored in `passport_allergies` (`PassportService.java:43-49`); **not** sent to MRS | No |
| 3 | Conditions | search `TextField` `:1455-1487`, selected `Chip`s `:1489-1522`, `ListView` of `ListTile`s with check icons `:1523-1573` | `List<String>` in `UserOnboardingProvider.chronicConditions` (`:78,136-146`) | 14 English constants (`conversational_onboarding_screen.dart:60-75`): Diabetes, Hypertension, Asthma, Heart Disease, Arthritis, Thyroid Disorder, Kidney Disease, Liver Disease, Cancer, Epilepsy, COPD, Depression, Anxiety, Migraine. No free text | none | `conditions[] = {name, criticalOptIn:false}` (`onboarding_basics_payload.dart:72-82`); `diagnosedAt` not sent | `@NotBlank @Size(max=200)` `OnboardingStepRequest.java:56-58` | No (values are the English strings above) |
| 4 | Medication name | `MedicationSearchField` `:1790-1812` | `String` + `medicationId` (`:84`) + `MedicationSearchResult` (`:85`) | must be picked from catalog suggestions | an id is required when a row has input (`:374-381`) | `medications[].drugName` (`onboarding_basics_payload.dart:93`); `medicationId` **not** sent | `@NotBlank @Size(max=255)` `OnboardingStepRequest.java:66-68` | **Blocking, see §i R1**: the catalog always throws (`medications_api.dart:49-52`), so no id can be set |
| 4 | Dosage | `TextField` `:1839-1873` | `String` | free text (« e.g., 100mg, 2x daily ») | required when a row has a name (`:383-390`) | `medications[].dosage` (empty → null) | none (`:69`) | No |
| 4 | Frequency | — (not shown) | `String` | hard-coded `'1x daily'` (`:397`) | — | `medications[].frequency` | none (`:70`) | — (always this constant) |
| 4 | Start date | — (not shown) | `String` | today, `yyyy-MM-dd` (`:360`) | — | `medications[].startDate` | `@NotNull` `:72-73` | No |

## c) States: today, and what each new choice maps to

| Step | State | How the app shows it today | What is sent | What is stored |
|---|---|---|---|---|
| Blood type | Not answered | no tile selected | `bloodType` omitted (`onboarding_basics_payload.dart:37`) | unchanged |
| Blood type | « Je ne sais pas » | `unknown` tile (`conversational_onboarding_screen.dart:57`) | `'unknown'` only if the server confirmed nothing is stored, else omitted (`onboarding_basics_payload.dart:42-44`) | MRS `blood_type: UNKNOWN` or unchanged |
| Height/weight | Not answered | **impossible**: required (`:448-451`) | — | — |
| Allergies | None known | link « I don't have known allergies » clears the cards (`:1352-1365`, `_clearAllergies` `:507-524`); an empty card gives the same result | `{"noKnownAllergies": true}` (`onboarding_basics_payload.dart:66`) | Spring: table emptied (`PassportService.java:55-58`). MRS at step 4: `allergies {status: UNKNOWN}`. The patient side never writes `NONE_KNOWN` (`MrsMedicalDataService.java:193-196`, `:389-394`) |
| Allergies | List | cards with a name | `{"allergies":[…]}` | Spring rows; MRS `LIST` (names) at step 4 |
| Conditions | None | nothing selected (no explicit control) | `{"noKnownConditions": true}` (`onboarding_basics_payload.dart:79`) | Spring emptied; MRS untouched |
| Conditions | List | ticked items | `{"conditions":[…]}` | Spring rows; not in MRS |
| Medications | None | link « I'm not taking any medications » clears the rows (`:1924-1946`); empty rows give the same result | `{"noKnownMedications": true}` (`onboarding_basics_payload.dart:101`) | Spring emptied |
| Medications | List | rows with a selected catalog item | `{"medications":[…]}` | Spring rows. **Unreachable today** (§i R1) |
| Whole flow | Skip | AppBar « Skip » | nothing | progress stays; onboarding is shown again next sign-in |

**Mapping of the redesign's choices to existing states:**

| New choice | Blood type | Height / weight | Allergies | Conditions | Medications |
|---|---|---|---|---|---|
| Oui | — | — | list (existing) | list (existing) | list (existing, but **blocked by the catalog**, §i R1) |
| Non | — | — | `noKnownAllergies:true` (existing) | `noKnownConditions:true` (existing) | `noKnownMedications:true` (existing) |
| Je ne sais pas | `unknown` tile (existing) | **no existing state** (required) → PARKED | **no existing state** → PARKED | **no existing state** → PARKED | **no existing state** → PARKED |
| Passer (per step) | « not answered » = omitted (existing) | **no existing state** (required) → PARKED | **no existing state** → PARKED | **no existing state** → PARKED | **no existing state** → PARKED |
| Passer (global) | existing « Skip »: leaves for `/home` without saving the current page | | | | |

- **Why « Je ne sais pas » / « Passer » have no state for lists:**
  - The app sends either a list or `noKnown*: true` (`onboarding_basics_payload.dart:65-104`). With today's code, both choices would send « none known », which is a false clinical statement (§i).
  - The server accepts a step with neither field and saves nothing (`OnboardingService.java:73-95`, only `if` branches), so an empty body would advance the step without writing. But no app code sends it. Using it means changing the payload builder (logic, not UI).
  - In storage, Spring cannot tell « none » from « not answered » (an empty table either way). MRS has `UNKNOWN | NONE_KNOWN | LIST` (`MRS records/life_safety_v2.go:16-18,26-28`), but the patient side always writes `UNKNOWN` for an empty list.
  - The three-state model is planned in G-2.1 (ADR-012: « emptied = NONE_KNOWN », roadmap `OmniCare_G2_Patient_Flutter_Roadmap.md:122,124`; B1/SB2 `:130,136`).

## d) Profile step

- **Prefilled from the server:** yes, via `GET /profile` in `_loadResume` (`conversational_onboarding_screen.dart:209-224`).
  - First name, last name, birth date and gender are filled only where the field is still empty.
  - The model has nullable `dateOfBirth` and `gender` (`patient_profile.dart:60-64`).
  - If that read fails, the page opens empty (`onboarding_progress.dart:178-180`).
- **Does « Continue » send them again?**
  - On a fresh account, yes. The server step starts at 1 (`UserProfile.java:116`), so « Continue » sends step 1 with the shown values (`onboarding_progress.dart:314-333`). The server overwrites non-blank values (`UserProfile.java:138-143`).
  - Once the server is past step 1, nothing is sent (`shouldSendOnboardingStep`, `:39-40`).
  - If the server is exactly one step ahead, it answers OK without saving (`OnboardingService.java:42-49`).
- **What an « edit » does today:** the identity page *is* the edit form.
  - Before step 1 is saved, an edit is sent by « Continue ».
  - After step 1 is saved, an edit is **not** sent. A SnackBar `onboardingPageAlreadySaved` is shown instead (`conversational_onboarding_screen.dart:282-291`, detection `onboarding_progress.dart:287-291`).
  - `PATCH /profile` exists (`account_api.dart:35-37`, `ProfileController.java:54-64`) but onboarding never calls it.
  - A « confirmation card + edit » UI that ends in the same « Continue » keeps the same behaviour. Making a late edit actually save would need a logic change (Q3).

## e) Height, weight, BMI

- **Types:**
  - Height is `int` cm (`:183`); a decimal is refused.
  - Weight is `double` kg (`:184-185`); a comma is accepted.
  - The resume prefill prints a whole weight without decimals (`_formatWeight` `:247-250`).
- **BMI in onboarding:**
  - `_bmiPreview` = weight / (height/100)² (`:187-195`). It is recomputed on every keystroke (listeners `:93-94`).
  - Shown as `'BMI ${bmi.toStringAsFixed(1)}'`, or the hint « BMI will be calculated after height and weight. » (`:1042-1076`).
  - There are **no categories or thresholds** in onboarding.
  - It is not sent; the server never receives a BMI from onboarding.
- **Elsewhere (only to note where it shows up):**
  - Spring computes `bmi` for the medical record (`PatientMedicalRecordService.java:289-290`).
  - The app passport card shows « IMC » (`lib/features/patient_passport/presentation/widgets/passport_measurements_card.dart:36,77,92`).
  - The editor has its own `_calculateBmi` (`medical_data_editor_screen.dart:55,69`).
  - The roadmap records an « IMC pill hard-coded « Normal » » as a health claim (`OmniCare_G2_Patient_Flutter_Roadmap.md:169`). I did not find it in `passport_measurements_card.dart` (grep « Normal » found nothing), so it is **UNVERIFIED** here and may already be fixed or live in another file.
- **Limits** (§b): app `0 < h < 300`, `0 < w < 500`; server/MRS `30 ≤ h ≤ 300`, `0 < w ≤ 500`.
  - MRS also has configurable « usual » ranges that produce warnings (`MRS records/measurement_limits.go:17-18,64-76`). These are not reached by the v1 path that Spring uses (schema 1 for BODY_MEASUREMENTS, `HttpMrsMedicalRecordClient.java:23,38-48`; v1 validator `registry.go:316-333`).
- **REQUIRES MEDICAL VALIDATION:** any range or category shown to the patient.

## f) Chronic conditions

- **Client-side constants:** 14 English strings in the screen (`conversational_onboarding_screen.dart:60-75`). There is no server list or catalog call.
- **Search is local:** a case-insensitive `contains` over the constants (`_filterConditions` `:165-178`).
- **No free text:** a condition not in the list cannot be added.
- **Stored in English:** the English names are what is sent and stored (`onboarding_basics_payload.dart:76`), so translating the *sent* value would be a data change. Translating only the *label* is UI-only.

## g) Look today

- **Theme:** hardly used.
  - Every style is local `GoogleFonts.plusJakartaSans(...)` (the runtime-fetched 400 face; see P2a-fix §F).
  - Hardcoded colours: **115** `Color(0x…)` in `conversational_onboarding_screen.dart` and **18** in `onboarding_complete_screen.dart` (grep count).
  - Background `#F4F5F7` (`:565`), mint `#1FBF9A`, teal `#0F6F73`, greys `#1D2939/#4B5563/#667085/#9CA3AF/#E5E7EB/#F9FAFB`, mint soft `#F0FDF9`.
  - No `OmniColors` / `OmniSpacing` import.
- **Illustrations / assets:**
  - 140 px mint circles with an icon (`:692-706`, `:1123-1137`), or `assets/images/blood_type.png` (`:918-930`), `chronic_conditions.png` (`:1420-1432`), `medications.png` (`:1595-1607`). All exist in `assets/images/`.
  - Completion screen: confetti (`onboarding_complete_screen.dart:5,23-29,257-274`) and a QR code (`:136-143`).
  - An **orphan** `lib/features/auth/medical_data_welcome_screen.dart` (asset `medical_data_welcome.png`, `:67`) is not referenced anywhere in `lib/` or `test/`. It has English texts `:89,107,151,189,217`.
- **Emoji:** 💊 at `:1622`, `:1657`, `:1762`; 🎉 at `onboarding_complete_screen.dart:76`.
- **Visible English strings** (`conversational_onboarding_screen.dart` unless noted):
  - **AppBar and buttons:** `:589` Skip · `:659` Complete · `:660` Continue.
  - **Profile page:** `:709` Confirm your profile · `:718` These details help us keep your medical passport accurate. · `:728` First name · `:735` Last name · `:749` Birth date · `:782` Gender · `:795` Male · `:803` Female · `:812` Other.
  - **Blood type page:** `:936` What is your blood type? · `:945` This helps our emergency team prepare the right blood supply for you. · `:1013` Height and weight · `:1026` Height · `:1034` Weight · `:1063` BMI will be calculated after height and weight. · `:1064` BMI x.x.
  - **Allergies page:** `:1140` Any allergies? · `:1149` Add medication, food, or material allergies doctors should know about. · `:1194` Allergy n · `:1205` Remove allergy (tooltip) · `:1225` Allergy name · `:1251` Severity · `:1266` Mild · `:1271` Moderate · `:1276` Severe · `:1285` Life-threatening · `:1293` Highlight this allergy for emergency care. · `:1340` Add Another Allergy · `:1356` I don't have known allergies.
  - **Conditions page:** `:1438` Any chronic conditions? · `:1447` Doctors use this to ensure your treatment plan is 100% safe. · `:1463` Search conditions... · `:61-74` the 14 condition names.
  - **Medications page:** `:1613` Current Medications · `:1622` Add any medications you're currently taking 💊 · `:1697`, `:1826` Soluble · `:1769` Medication n · `:1780` Remove medication · `:1793` Medicine name (e.g., Aspirin) · `:1846` Dosage (e.g., 100mg, 2x daily) · `:1911` Add Another Medication · `:1937` I'm not taking any medications.
  - **SnackBars:** `:377` Please select a medication from the list. · `:386` Please enter a dosage for the selected medication. · `:421` Please enter your first name. · `:423` Please enter your last name. · `:425` Please select your birth date. · `:427` Please select a birth date in the past. · `:429` Please select your gender. · `:449` Please enter your height. · `:451` Please enter your weight. · `:453` Please enter a valid height. · `:455` Please enter a valid weight. · `:473` Please enter the allergy name. · `:477` Please select allergy severity.
  - **`onboarding_complete_screen.dart`:** `:76` Thank You! 🎉 · `:87` Your medical information helps… · `:118` Your Medical QR Code · `:162` To secure your personal data, only share this QR code with your doctors · `:203` Take a Quick Demo · `:238` Go to Dashboard.
  - **Already French (ARB):** `bloodTypeUnknown`, `onboardingPageAlreadySaved`, `onboardingSaveFailed` / `onboardingSaveErrorMessage` (`onboarding_progress.dart:368-371`).
- **Reusable P1/P2 widgets:**
  - `OmniTextField`: names, the type-in weight/height fallback, allergy name, dosage, condition search.
  - `OmniBirthDatePicker`: birth date. Its `lastDate` is a parameter, so today's « any past date » can be kept.
  - `OmniSegmentedChoice`: gender, severity, Oui/Non/Je ne sais pas. It supports 2–3 options (`omni_segmented_choice.dart:32-34`), so M/F/« Other » and the 3 severities fit.
  - `OmniStepProgress`: the thin bar; it currently shows a label « Étape x sur y » (`omni_step_progress.dart:15-21`).
  - `OmniPressable`: every tile and button.
  - `AuthFlowFrame`: dark header band, so it does **not** fit « white screens » as is.
  - `OmniLogoBadge`: intro screen only, optional.
- **`flutter analyze lib/features/onboarding lib/providers/user_onboarding_provider.dart`:** 3 infos, all in `onboarding_complete_screen.dart` (`withOpacity` `:104`, `:109`; QR `foregroundColor` `:141`), 0 warnings, 0 errors.

## h) Redesign fit check

| Redesign item | Verdict | Where it would live | Notes / flags |
|---|---|---|---|
| Intro screen | **NEW** (UI-only) | new widget, e.g. `lib/features/onboarding/widgets/onboarding_intro.dart`, shown **before** the `PageView` (or as an overlay) | It must not become a page of the `PageView`: page indexes are used by `OnboardingPage` constants and by resume `jumpToPage(resume.page)` (`onboarding_progress.dart:12-27`, `conversational_onboarding_screen.dart:242-244`). Show it only when the resume page is 0 (Q1). The orphan `medical_data_welcome_screen.dart` could be its visual base |
| Profile confirmation card (+ edit) | **EXTEND** | `conversational_onboarding_screen.dart` page 0 (`:686`) + new `widgets/profile_summary_card.dart` | Same fields and controllers, same « Continue » → step 1. Missing values (e.g. Google sign-up without birth date or gender) must open the form. Late edit = SnackBar, as today (§d) |
| Blood type tiles + « Je ne sais pas » | **REUSE** (restyle) | same file `:953-1010` | Same `provider.setBloodGroup(wire)`; the `unknown` tile already exists |
| Height wheel (cm) | **NEW** (UI-only) | `lib/core/widgets/omni_number_wheel.dart` (pattern of `omni_birth_date_picker.dart`) writing `_heightController.text` | Integer cm keeps `_heightCm`. Range choice: the validator allows 1–299, the server 30–300 (Q6). A wheel must still allow « no value yet » because the validator requires a value |
| Weight ruler (kg) + type-in fallback | **NEW** + **REUSE** | `lib/core/widgets/omni_weight_ruler.dart` writing `_weightController.text`; fallback = existing field | Step (0.1 kg?) and range are a choice (Q6). REQUIRES MEDICAL VALIDATION for any shown range |
| Allergies Oui / Non | **NEW UI over existing states** | same file, new `widgets/yes_no_unknown.dart` (or `OmniSegmentedChoice`) | Oui = cards; Non = existing clear → `noKnownAllergies:true` |
| Allergies « Je ne sais pas » | **PARKED** | — | No existing state (§c). Today it would send « none known »: clinically false. Needs the G-2.1 three-state write path (B1/SB1/SB2/A3) |
| Allergy cards | **REUSE** (restyle) | same file `:1157-1310` | Name, 3 severity values (French values kept), life-threatening switch. Labels → French ARB |
| Conditions Oui / Non | **NEW UI over existing states** | same | Non = empty selection → `noKnownConditions:true` |
| Conditions « Je ne sais pas » | **PARKED** | — | No existing state |
| Search + chips + checkbox list | **REUSE** (restyle) | same file `:1455-1573` | Local search over 14 constants. French *labels* are UI-only; sent values stay English (Q7). The list is REQUIRES MEDICAL VALIDATION |
| Medications Oui / Non | Non: **existing**; Oui: **PARKED** | same | Oui cannot complete today: the catalog throws (`medications_api.dart:49-52`) and the id is required (`:374-381`). Free-text medications = roadmap A3 (`OmniCare_G2_Patient_Flutter_Roadmap.md:140`) + B3 |
| Medications « Je ne sais pas » | **PARKED** | — | No existing state |
| Medication cards | **REUSE** UI only, effectively **PARKED** | same `:1730-1878` | Can be restyled, but no medication can be saved until the catalog or free-text change lands |
| « Votre dossier est prêt » summary | **EXTEND** (replace content) | `onboarding_complete_screen.dart` | Values are in memory (`UserOnboardingProvider`, set by `_buildDraft` `:319-343`). Removing the fake QR and confetti is UI-only. « prêt » is shown before the async MRS outbox has run (Q8) |
| White screens, thin progress, back, « Passer », pinned button | **EXTEND** | same file `:562-683`; progress from `OmniStepProgress` (variant without label, or new `OmniThinProgress`); white frame = new `lib/features/onboarding/widgets/onboarding_frame.dart` (`AuthFlowFrame` is dark) | « Passer » keeps today's global Skip (to `/home`, no server call). Per-step « Passer » is PARKED for allergies, conditions and medications, and for height/weight (required) |

**Needs backend or data-model change (will NOT be done):**
- « Je ne sais pas » and per-step « Passer » for allergies, conditions and medications (three-state lists): ADR-012, roadmap B1/SB1/SB2/A3.
- Free-text medications (A3, B3).
- Making the global « Passer » call `POST /onboarding/skip`: the endpoint exists, but calling it is an app logic change and it marks onboarding completed (`UserProfile.java:175-178`). Q2.
- Conditions reaching MRS (SB2).
- Height and weight optional.

## i) Risks

- **R1 — medications cannot be saved.**
  - `MedicationsApi.searchTop10` always throws `featureUnavailable` (`medications_api.dart:40-52`). The field swallows the error and shows no suggestions (`medication_search_field.dart:94-108`).
  - So `_medicationIds[i]` stays null, and « Complete » with any typed medication shows « Please select a medication from the list. » (`conversational_onboarding_screen.dart:374-381`).
  - Today the medications page only completes with no medication.
- **R2 — logic inside the widget.** `_ConversationalOnboardingScreenState` holds validation (`:418-489`), payload assembly (`:317-402`), resume (`:203-245`), navigation (`:254-301`, `:404-416`) and parallel lists of controllers (`:79-85`).
  - A restyle must keep these methods intact, and keep the page count (`_pageCount = 5`, `:180`) and page order (`OnboardingPage`).
  - `UserOnboardingProvider` is the blood-type and conditions store (`:965-969`, `:1493-1568`). Moving that state would be a logic change.
- **R3 — tests that pin the current UI:**
  - `test/blood_type_and_medical_save_test.dart:330-365` (widget test) needs a `PageView` (`find.byType(PageView)` + fling `:354`), the « Je ne sais pas » tile text (`:358`), no « IDK » (`:357`), and the tile tap → `onboarding.bloodGroup == 'unknown'`. An intro screen in front of the `PageView`, or a different swipe model, breaks it.
  - Logic tests that pin request bodies and save order:
    - `test/onboarding_per_step_save_test.dart` (groups `:57`, `:188`, `:283`, `:340`, `:412`);
    - `test/onboarding_blood_type_guard_test.dart`;
    - `test/blood_type_and_medical_save_test.dart:291-299` (step-1 path/body);
    - `test/error_sinks_french_test.dart:319-324`;
    - `test/l10n_arb_contract_test.dart:174-185,231-241` (onboarding ARB keys).
  - A UI-only change must not touch `onboarding_progress.dart` or `onboarding_basics_payload.dart`.
- **R4 — overlap with G-2 roadmap** (`docs/roadmap/OmniCare_G2_Patient_Flutter_Roadmap.md`):
  - **A3** (`:140`) « Onboarding … on the same write path; English onboarding messages → ARB; free-text medications ». This is the same screen and the same strings: a direct file conflict with a G-3 restyle of `conversational_onboarding_screen.dart`.
  - **SB2** (`:136`) moves onboarding steps 2–4 to the SB1 services (backend).
  - **Phase 3a / DATA-01** (`:611`; older roadmap `G2_Patient_Flutter_Roadmap.md:201-209`, `:204`) redirects onboarding medical fields to MRS.
  - **G-2.1 Done-when** (`:113-114`) « enter an allergy in onboarding and see it in the record ».
  - Parked finding (`:169`) « onboarding conditions/meds never reach MRS » (confirmed in §a).
  - ADR-012 (`:122`) three-state lists.
  - The G-2.1 table shows A3 ⏳, after SB2 (`:145`).
- **R5 — fake QR with personal data.** `OnboardingCompleteScreen` encodes `OMNICARE_USER_<email or phone>_<timestamp>` in a QR (`onboarding_complete_screen.dart:42-44`, `:136-143`).
  - It is not a real medical QR (roadmap D1: the QR exists only during a consultation, `:150`).
  - It puts a contact identifier into an image, and can print `null`.
  - Its warning text calls it a medical QR (`:118`, `:162`).
- **R6 — global « Skip » loops.** No server call is made (§a), so the patient is sent back to onboarding on every sign-in.
- **R7 — allergy data split.** Severity and the life-threatening flag stay in Spring `passport_allergies`. Only names reach MRS, and only at step 4 or skip (`MrsOnboardingSyncService.java:46-66`). If the patient leaves after page 2, the allergies never reach MRS.
- **R8 — app/server limit mismatches** (§b): names > 100, allergy names > 160 (MRS), height 1–29 / 300 / decimals, weight 500.
- **R9 — date picker.** Material `showDatePicker` in English labels (`:528-533`). There is no age rule, unlike sign-up's 18+.
- **Clinical items — REQUIRES MEDICAL VALIDATION:**
  - allergy severity scale `légère / modérée / sévère` and its default `modérée` (`:137`, `:1263-1278`);
  - the life-threatening flag and its wording (`:1281-1305`);
  - BMI preview (`:187-195`, `:1062-1064`), any future range or category;
  - the 14-condition list (`:60-75`);
  - height/weight limits (§e);
  - the blood-type subtitle claim « prepare the right blood supply » (`:945`);
  - « 100% safe » (`:1447`).

## Open questions (not decided)

1. **Intro screen:** show it only on a fresh start (resume page 0), or every time onboarding opens? Does it replace the orphan `medical_data_welcome_screen.dart` (delete or keep)?
2. **« Passer »:** keep today's global Skip (to `/home`, no save, onboarding comes back next sign-in), or should it call the existing `POST /onboarding/skip`? The second is a logic change that marks onboarding completed.
3. **Profile « edit »** after step 1 is already saved: keep the « not sent » SnackBar (today), or is a real save via `PATCH /profile` wanted? The second is a logic change.
4. **« Je ne sais pas »** for allergies, conditions and medications: hide it until the G-2.1 three-state path (ADR-012) ships, or show it disabled? It must never send « none known ».
5. **Birth date:** keep « any past date » in onboarding, or align with sign-up's 18+? The second is a validation change.
6. **Wheel and ruler ranges and steps:** height 30–299 or 1–299? Weight 0.1 kg steps, up to 499.9? Both REQUIRE MEDICAL VALIDATION, and any range narrower than the validator is a behaviour change.
7. **Condition labels:** French labels with English stored values (UI-only), or French stored values (data change, G-2.1)?
8. **Summary wording:** « Votre dossier est prêt » appears before the async MRS sync. Is that acceptable, or « Vos informations sont enregistrées »? Keep the QR?
9. **Who owns `conversational_onboarding_screen.dart`:** G-3 (restyle) or G-2.1 A3 (same file, same strings)? Order them to avoid a conflict.
10. **Medications page while R1 stands:** show only « Non » plus a « bientôt disponible » note, or keep today's cards that cannot be saved?

## Path to deliver G-3

1. **CTO:** answer Q1–Q10, especially Q9 (file ownership with G-2.1 A3) and Q4/Q10 (parked choices). Approve the target design with the PARKED items removed or disabled.
2. **ONB-P1:** UI-only prompt for the parts with existing states. This covers the white frame, thin progress, intro (outside the `PageView`), profile card, blood-type tiles, height wheel, weight ruler + fallback, allergy and condition cards with Oui/Non, the medications « Non » path and the summary screen. All strings go to ARB.
   - Do not touch: `onboarding_progress.dart`, `onboarding_basics_payload.dart`, `UserOnboardingProvider`, `AccountApi`, `medications_api.dart`, or the backend.
   - Keep the `PageView` and the « Je ne sais pas » tile text for `blood_type_and_medical_save_test.dart:330-365`.
3. **Parked to G-2.1:** « Je ne sais pas » / per-step « Passer » (three-state lists), free-text medications, conditions in MRS, server skip. They return to G-3 as a small UI follow-up once A3 lands.
4. **Next G-3 page** from the CTO's screenshots, reusing `OmniPressable`, `OmniStepProgress`, the new wheel/ruler and the onboarding frame.
