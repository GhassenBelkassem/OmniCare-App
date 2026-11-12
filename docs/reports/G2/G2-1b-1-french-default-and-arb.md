# G-2 · 1b-1 — French as the default language, official translation files (ARB + gen-l10n)
_Date: 2026-11-11 · Repo: OmniCare-App only · Roadmap: Phase 1b item 6, §4.1 Q10_
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

| # | Deliverable | Status after 1b-1 |
|---|---|---|
| 1 | Roadmap | Done (v1.2) |
| 2 | App connected | Phase 1a done except 1a-5. **Phase 1b has started: item 6 (locale + ARB) is done.** |
| 3 | Reports | This file |
| 4 | Prompts | Unchanged |

**Result:**
- The app now always runs in **French**.
- Its texts come from **`lib/l10n/app_fr.arb`**, compiled by Flutter's official `gen-l10n` into the class `OmniLocalizations`.
- `pending_fr_strings.dart` and the hand-written `app_localizations.dart` are **deleted**.
- **Checks:**
  - `flutter analyze` shows 388 issues, the same lines as the baseline.
  - `flutter test`: 1858 passed, 7 skipped (+10 new tests).
  - A drift test fails if an ARB key and the code disagree. I checked that it fails by adding an unused key.

## 2. Plan findings (step 1)

### a) Official guide followed (Flutter 3.41.2 installed)
Sections of https://docs.flutter.dev/ui/internationalization:
- **"Setting up an internationalized app: the flutter_localizations package".**
  - `flutter_localizations` (SDK) and `intl` were already dependencies (`pubspec.yaml:34,48`), so nothing was added.
  - Delegates and supported locales are set on `MaterialApp`.
- **"Adding your own localized messages"**:
  - step 2: `flutter: generate: true`;
  - step 3: `l10n.yaml` with `arb-dir`, `template-arb-file` and `output-localization-file`;
  - step 4: `@key` metadata with a `description`;
  - step 7: `localizationsDelegates` and `supportedLocales` taken from the generated class.
- **"Configuring the l10n.yaml file"**:
  - `output-class` (to avoid a name clash);
  - `nullable-getter: false` (so the code needs no null checks);
  - `[no-]required-resource-attributes` (every key must have a description).
- **"Specifying the app's supportedLocales parameter"**: if the device locale is not supported, Flutter uses the first supported locale.

**Where the generated files go.**
- The web guide still describes the old "synthetic package" as the default.
- **The installed SDK removed it.** `flutter_tools/lib/src/localizations/localizations_utils.dart:490-505` stops the build if `synthetic-package: true` and warns if it is set to false (see flutter.dev/to/flutter-gen-deprecation).
- So, as the guide's option table says for that case, the files are generated **in the `arb-dir`** (`lib/l10n/`) and imported from there (`import 'l10n/omni_localizations.dart'`). This is the same import style as the guide's step 7.
- They are **committed**, so a fresh checkout analyzes without first running `flutter pub get`. `flutter pub get` regenerates them anyway because `generate: true` is set.

### b) Locale logic before this step
- **Before (`lib/main.dart:372-378`):**
  - The locale started as **`en`**. The profile's `preferredLanguage` won if a profile was loaded, otherwise the onboarding language choice.
  - Supported locales: en, fr, ar.
  - The backend default for `preferredLanguage` is `"fr"` (`UserProfile.java:115`). So a signed-in patient was usually in French, while **every screen before sign-in (login, OTP, sign-up) ran in English**. That includes Material widgets: date picker, tooltips, `MaterialLocalizations` dates.
- **Language choosers:**
  - `LanguageSelectionScreen` is opened only from `PopulationSelectionScreen`, which nothing constructs, so it is **unreachable**.
  - The language sheet on the old `HomeScreen` is unreachable too.

### c) Users of the old string sources
**`AppLocalizations` (hand-written, 101 keys × en/fr/ar).**
- 4 files use it: `home_screen.dart` (old home, unreachable), `forgot_password_screen.dart` (unreachable), `language_selection_screen.dart` (unreachable) and `reset_password_screen.dart` (**reachable**: route `/change-password-required`). Also `main.dart`.
- **Only 40 of the 101 keys are used**, and 37 of those are in unreachable screens.
- `lib/features/doctor/**` does **not** use the map, so nothing was changed there.

**`PendingFrStrings` (13 entries).**
- Used in logic with no `BuildContext`: `saveErrorMessage`, `onboardingSaveErrorMessage`, `BloodType.label`, `RequestStatusCopy.of`.
- Also used in widgets: the urgent-cabinet search and detail screens, the medical data editor, the onboarding screen and the request journey.

### d) Naming conflict
- The guide's default output (`lib/l10n/app_localizations.dart`, class `AppLocalizations`) is **exactly** the path and class of the hand-written file.
- I chose **`OmniLocalizations`** in `omni_localizations.dart`, so the two could exist side by side during the move. The old file is now gone.

### e) Date and number formatting after the switch to fr
- **Material and Cupertino widgets** (date and time pickers, `MaterialLocalizations.formatMediumDate` on the request cards, back and close tooltips) are now French **everywhere**, including before sign-in, where they used to be English.
- **`intl` `DateFormat(...)` without a locale is not affected.** Neither the generated class nor `flutter_localizations` sets `Intl.defaultLocale`; I checked the SDK source, where gen-l10n's `load` only returns `lookup…(locale)`.
  - These 5 patient-side calls keep today's behaviour, which formats like en_US:
    - `security/device_management_screen.dart:160`
    - `security/phone_change_screen.dart:636`
    - `security/login_history_screen.dart:230`
    - `profile/medical_documents_screen.dart:1603` (`'MMM dd, yyyy'`, so the month names are **English**)
    - `clinic/data/clinic_models.dart:1236`
  - Their fix is item 5 of Phase 1b (time/clock) or the translation pass (R3).
- **Numbers:** there is no `NumberFormat` in the patient code, so nothing changes.

## 3. What changed

| File | Change |
|---|---|
| `pubspec.yaml` | `flutter: generate: true` only. No dependency change. |
| `l10n.yaml` (new) | `arb-dir: lib/l10n`, `template-arb-file: app_fr.arb`, `output-localization-file: omni_localizations.dart`, `output-class: OmniLocalizations`, `nullable-getter: false`, `required-resource-attributes: true` |
| `lib/l10n/app_fr.arb` (new) | 53 keys, each with a description: the 40 used legacy keys (French values unchanged) and the 13 `PendingFrStrings` entries (text unchanged) |
| `lib/l10n/omni_localizations.dart`, `omni_localizations_fr.dart` (generated) | Output of `flutter gen-l10n` |
| `lib/l10n/app_localizations.dart` | **Deleted** (the hand-written map) |
| `lib/core/l10n/pending_fr_strings.dart` | **Deleted** |
| `lib/core/l10n/app_locale.dart` (new) | `const appLocale = Locale('fr')`, with the V1 rule documented |
| `lib/main.dart` | `locale: appLocale`, plus delegates and supported locales from `OmniLocalizations` (fr only). The profile and onboarding language are no longer read here; they are still parsed and stored by their models and providers. `Consumer2` is kept, so `MaterialApp` rebuilds exactly as before. |
| `lib/core/network/save_error_message.dart`, `lib/features/onboarding/onboarding_progress.dart` | `saveErrorMessage(error, l10n)` and `onboardingSaveErrorMessage(error, l10n)`: the messages are passed in (§5 dependency injection, no global lookup) |
| `lib/core/models/blood_type.dart` and `lib/core/l10n/blood_type_label.dart` (new) | The model no longer imports any text. The label comes from the extension `label(l10n)`: the wire value for known types, `bloodTypeUnknown` for `unknown`. |
| `request_status_copy.dart` | `RequestStatusCopy.of(status, l10n)`. Only NO_SHOW reads from it; the other statuses keep their English constants (R3). |
| Widget call sites | `OmniLocalizations.of(context)`: `new_home_screen`, `family_member_detail_screen`, `edit_medical_data_screen`, `conversational_onboarding_screen`, `urgent_cabinet_doctor_directory_screen`, `urgent_cabinet_doctor_detail_screen`, `patient_request_journey`, `my_requests_screen`, `patient_request_detail_screen` |
| `home_screen`, `forgot_password_screen`, `language_selection_screen`, `reset_password_screen` | `l10n?.key ?? 'English fallback'` becomes `l10n.key` (the English fallbacks are gone) |

No layout, style or navigation change. No backend change. `lib/features/doctor/**` is untouched.

## 4. Evidence
- **New `test/l10n_arb_contract_test.dart` (10 tests, logic only: reads files and calls functions):**
  - **Drift:** the keys used in `lib/` and the ARB keys are the same set. I checked it bites by adding an unused key: the test failed with `Actual: Set:['zzUnusedProbe']`; then I restored the file.
  - **Access convention:** messages are only read as `l10n` / `OmniLocalizations.of(context)`, with no hidden `lookupOmniLocalizations` in `lib/`, so the drift scan cannot be bypassed.
  - Every key has a description, and `@@locale` is `fr`.
  - The generated getters equal the ARB keys (catches a forgotten `flutter gen-l10n`).
  - The old files and names are gone.
  - **French default:** the only supported locale is `[fr]`; en and ar are not supported; device locales en_US, ar_TN, fr_TN and none all resolve to `fr` (`basicLocaleListResolution`); `main.dart` sets `appLocale` and no longer reads `preferredLanguage` / `onboarding.language`.
  - **Same French text:** the 13 former `PendingFrStrings` values and the 3 reachable legacy keys are checked against the ARB word for word. The functions that use them return the same text:
    - `saveErrorMessage` for INVALID_INPUT, 503, network and other errors (1a-2);
    - `BloodType.unknown.label` (1a-2b);
    - `onboardingSaveErrorMessage` (1a-6);
    - `RequestStatusCopy` NO_SHOW (1a-4);
    - the urgent-cabinet "unavailable" texts (1a-3).
- **Updated tests:**
  - `blood_type_and_medical_save_test`, `onboarding_per_step_save_test` and `request_no_show_and_schedule_proposal_test` now compare against the **literal French text** instead of `PendingFrStrings`.
  - 8 existing widget-test `MaterialApp`s (in `blood_type_and_medical_save`, `p5_06_patient_qr`, `patient_request_status_matrix`, `request_history_widget` and `urgent_cabinet_doctor_detail`) got the generated delegates, as production has. They failed without them because the getter is non-null.
- `flutter analyze`: 388 issues, the same lines as the baseline.
- `flutter test`: **1858 passed, 7 skipped**. The 8 touched test files also pass under `TZ=UTC` (123).

### The 7 skipped tests (all in `test/auth_phase1_test.dart`, group "professional authentication milestone")
| Line | Test |
|---|---|
| 3169 | patient choice opens the existing language entry |
| 3181 | professional choice opens credential form and back works |
| 3207 | professional form shows validation and login errors inline |
| 3240 | professional credential form uses backend role for Doctor |
| 3268 | professional choice cannot turn a Patient into Doctor |
| 3290 | Doctor password-change requirement blocks the workspace |
| 3312 | unsupported professional role shows a sign-out state |

**Reason, the same for all 7.**
- Each test starts on the entry screen and taps « Je suis patient » or « Je suis professionnel de santé ».
- Those buttons exist only in `PopulationSelectionScreen` (`population_selection_screen.dart:60,71`), which is no longer used.
- Commit `9146535` (2026-09-26, "doctorDashboard") made `LoginScreen` the single role-neutral sign-in, pointed the test harness at it and added `skip: true` with no written reason.
- The flows they test either no longer exist in that form or are now covered through `LoginScreen`.
- **Decide:** delete them with the unreachable code (§4.1 Q12, Phase 1c) or rewrite them against `LoginScreen`.

## 5. Contract table (strings)
| Source | Before | After |
|---|---|---|
| Hand-written map | 101 keys × en/fr/ar; 40 used | 40 keys in `app_fr.arb` (French values unchanged). **61 unused keys and all en/ar values dropped** (R1) |
| `PendingFrStrings` | 13 constants | 13 ARB keys, same text |
| App language | en by default; profile or onboarding language could switch it | fr, fixed |

## 6. Complexity and memory
- The generated class is a const delegate with O(1) getters.
- `lookupOmniLocalizations` is a switch on the language code, called once per `Localizations` load.
- The drift test reads `lib/` once, O(source size).
- No new state.

## 7. Risks, open questions, things not done
- **R1. "Move every key" and "every ARB key is used" conflicted. I chose the drift test.**
  - Moving all 101 keys would have put 61 unused keys in the ARB on day one and failed the drift test the task asks for.
  - So I moved the **40 used keys**. The other 61 (old marketing, demo pharmacies, sign-up and OTP texts that the current screens don't read) and the en/ar values stay in git history: `git show HEAD:lib/l10n/app_localizations.dart`.
  - Q10's "ARB keeps ar/en slots" is met by the setup: adding `app_ar.arb` or `app_en.arb` brings them back. Adding them now would also make them **supported** locales (gen-l10n generates `supportedLocales` from the files), which V1 forbids.
  - **Tell me** if you want the 61 keys kept anyway. The drift test would then need an explicit "unused, kept" list.
- **R2. Visible text changes. These come from the switch itself, not from new translations.**
  - **Before sign-in, Material widgets are now French**: the sign-up date picker, tooltips, OK/Cancel.
  - The **reset-password screen** (`/change-password-required`) now shows its 3 validation messages in French; before sign-in they used to be English.
  - The old screens lost their English fallbacks. They were unreachable, so no patient sees the difference.
- **R3. Most hardcoded text is still English.** This is out of scope for this step. **Top 10 files**, counted as visible-looking string literals with English words and no French. The count skips exception/log lines, `lib/features/doctor/**`, the professional-only `lib/features/clinic/**`, `mock_data` and `demo`; it is a heuristic. In total: 768 literals in 107 files.
  1. `request_history/presentation/patient_request_detail_screen.dart`: 53
  2. `request_core/data/request_failure.dart`: 44
  3. `core/api/documents_api.dart`: 37
  4. `request_history/presentation/request_status_copy.dart`: 32
  5. `notifications/application/notification_navigation_resolver.dart`: 29
  6. `onboarding/conversational_onboarding_screen.dart`: 27
  7. `emergency/widgets/body_map_widget.dart`: 27
  8. `emergency/urgent_cabinet/urgent_cabinet_anatomical_mapping.dart`: 25
  9. `scheduled_care/data/scheduled_care_failure.dart`: 22
  10. `profile/medical_documents_screen.dart`: 21
- **R4. The language field no longer does anything.**
  - The profile `preferredLanguage` and the onboarding choice are still read and stored but ignored.
  - `LanguageSelectionScreen` is unreachable today. If it is ever reconnected, it must be hidden (Q10) or it would offer a choice that does nothing.
- **R5. Five `DateFormat` calls without a locale** (§2e) still format English month names on one patient screen (`medical_documents_screen.dart:1603`). They are left for Phase 1b item 5 or the translation pass.
- **R6. Generated files are committed.** If someone edits `app_fr.arb` without running `flutter gen-l10n` (or `flutter pub get`), the drift test fails ("generated class matches the ARB").
- **Not done:** no screen translated, no ar/en ARB, no change to the language field model or provider.

## 8. Path to deliver G-2
1. **CTO:**
   - Run §9.
   - Decide R1 (drop or keep the 61 keys), R4 (the language screen) and the 7 skipped tests (§4).
   - Commit Phase 1a and this step.
2. **1a-5:** push semantic type (backend F7). That is the last Phase 1a item.
3. **Phase 1b, the rest:**
   - item 1: build config, which also removes `.env` from assets;
   - item 2: one `ApiFailure` parser plus the `code` → French catalog, written directly in `app_fr.arb`;
   - item 3: `Result<T>`;
   - item 4: logging;
   - item 5: Clock, `timezone` package and Africa/Tunis, which also fixes R5;
   - item 7: mock cut-off;
   - item 8: guard test.
4. **Translation pass:** move the R3 files to ARB, starting with the reachable patient screens. The drift test keeps the ARB honest as keys are added.
5. **Phase 1c and onwards** per the roadmap, then the §8 release gate and the final G-2 report.

## 9. Manual test steps for the CTO
Use a phone (or emulator) whose **system language is English**: that is where the change shows.

1. **Before sign-in is French.** Install the build and open the app, signed out → sign-up → open the **birth-date picker**.
   - Expected: French month and day names, and the buttons read **« ANNULER » / « OK »** (Material French). Before this step they were English.
   - Send back: one screenshot.
2. **A profile language does not switch the app.** Sign in as a test patient → home → back button and menus.
   - Expected: French. Optionally set `preferredLanguage` to `"en"` for that test patient (staging DB or API) → force-close → reopen. The app is **still French**.
   - Send back: OK or not OK (and whether you did the optional part).
3. **Earlier messages are unchanged** (each is a single quick check):
   - **(1a-2)** Open « Modifier Mes Données Médicales » (Ma Santé → edit), change the blood type with **airplane mode on** → **« Enregistrer les Modifications »**. Expected snackbar: « Connexion impossible. Réessayez. »
   - **(1a-2b)** Onboarding blood-type tiles: the last one reads « Je ne sais pas ».
   - **(1a-4)** If you still have the NO_SHOW request from 1a-4: « Rendez-vous manqué ».
   - **(1a-6)** Onboarding with airplane mode on → « Continue ». Expected: « Impossible d'enregistrer. Vérifiez votre connexion et réessayez. »
   - Send back: OK or not OK for each, with a screenshot of any difference.
4. **Reset password (if your staging can force it).** Sign in with an account that must change its password (`/change-password-required`) → leave both fields empty → submit.
   - Expected: « Le mot de passe est requis ». With two different passwords: « Les mots de passe ne correspondent pas ».
   - Send back: one screenshot.
5. **Request list dates.** « Mes demandes ».
   - Expected: the date on each card is in French (for example « 2 nov. 2026 »).
   - Send back: one screenshot.
