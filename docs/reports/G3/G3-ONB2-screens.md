# G3-ONB2 — Onboarding screens: approved design, 100 % French, same logic and data

The approved onboarding design is applied to `conversational_onboarding_screen.dart` and `onboarding_complete_screen.dart`, built from the ONB-1 blocks.

The same requests are sent with the same bodies in the same order (checked end to end, §5). These were not edited: `onboarding_progress.dart`, `onboarding_basics_payload.dart`, `UserOnboardingProvider`, the APIs, the routes, the global themes, the auth files and `lib/features/doctor/**`. No git command was run.

## 1. Files

| File | Change |
|---|---|
| `lib/features/onboarding/conversational_onboarding_screen.dart` | UI rebuilt (§2). Logic methods kept verbatim (§3) |
| `lib/features/onboarding/onboarding_complete_screen.dart` | Rewritten. QR, confetti, « Take a Quick Demo » and emoji removed; check pop, summary and « Accéder à mon espace » (same `/home` navigation) |
| `lib/features/onboarding/widgets/onboarding_intro.dart` | **New** intro (outside the PageView) |
| `lib/features/onboarding/onboarding_labels.dart` | **New** display helpers: gender labels, the 14 French condition labels, accent-free search key |
| `lib/features/onboarding/widgets/onboarding_frame.dart` (ONB-1) | **Additive** `primaryLoading` (spinner in the button, taps ignored, enabled look kept) |
| `lib/core/widgets/omni_text_field.dart` (P1) | **Additive** `textCapitalization` (default none), so names stay capitalized by word as before |
| `lib/core/widgets/omni_choice_tile.dart` (ONB-1) | Horizontal padding 20 → 8 px, so « AB+ » fits a 3-column row at 320 px / text size 1.3 |
| `lib/l10n/app_fr.arb` + generated `omni_localizations*.dart` | 94 keys appended (direct edit after re-reading from disk; `flutter gen-l10n`) |
| `test/blood_type_and_medical_save_test.dart` | 3 lines: tap « Commencer » before the fling (§6) |

## 2. Widget tree per page (7 visual steps)

The screen root is a `Stack`:
- **Bottom layer:** the unchanged 5-page `PageView`, in `Offstage` + `TickerMode`. It is always mounted, so `_loadResume`'s `jumpToPage` works under the covers.
- **Intro:** `OnboardingIntro`, while `_showIntro`.
- **Initial load:** a full-screen white spinner, while the resume read runs (`_resumeReady == false`).

Each page is an `OnboardingFrame` with:
- progress = step / 7;
- « Passer » = `_skip` (the former AppBar « Skip », same `pushReplacementNamed('/home')`);
- `primaryLoading: _saving` (the same flag the screen used for its overlay).

| Step | Page (`OnboardingPage`) | Tree | Main button |
|---|---|---|---|
| — | Intro (new, fresh start only) | Dark top: `deepTealActive` + `AuthDecorativeCircles` + `OmniLogoBadge` 96 px + 4 white chips. White card radius 28: title, text, « Environ 1 minute », « Vous pourrez les modifier à tout moment ». Pinned « Commencer » / « Plus tard » | « Commencer » shows the PageView; « Plus tard » = `_skip` |
| 1 | 0 identity | `ProfileSummaryCard` (name, birth date, gender) with « Modifier ». Or, when « Modifier » is tapped, a value is missing or the check fails, the fields: `OmniTextField` Prénom / Nom (maxLength 100, word capitalization), read-only Date de naissance → `OmniBirthDatePicker` (1900 … today), `OmniSegmentedChoice` Homme / Femme / Autre (`M` / `F` / `autre`) | « C’est bien moi » (card) or « Continuer » (form), always enabled → `_nextPage` |
| 2 | 1 body, sub-step 0 | `OmniChoiceTile` rows 3 / 3 / 2 (8 groups) + `OmniChoiceTile.wide` « Je ne sais pas », in a `radioGroup`; `provider.setBloodGroup(wireValue)` as before | « Continuer », always enabled → sub-step 1 (no save) |
| 3 | 1 body, sub-step 1 | `OmniNumberWheel` 30–299 cm; value = `_heightCm` (null → « — »); writes `_heightController.text` | Enabled once a height exists → sub-step 2 |
| 4 | 1 body, sub-step 2 | `OmniWeightRuler` 1–499 kg; value = `_weightKg` (null → « — »); writes `_weightController.text`. « Saisir au clavier » opens `OmniTextField` on `_weightController` (decimal keyboard, comma accepted as before). BMI preview: same `_bmiPreview`, French « IMC 22,5 » | Enabled once a weight exists → `_nextPage` (the page-1 save) |
| 5 | 2 allergies | `OmniOptionGroup` « Oui » / « Non, aucune allergie connue ». « Non » = `_clearAllergies()`. « Oui » = cards: `OmniTextField` « Nom de l’allergie » (maxLength 160), « Gravité » `OmniSegmentedChoice` (`légère` / `modérée` / `sévère`, default `modérée`), « Risque vital » switch row, remove (×, only with > 1 card), dashed « Ajouter une allergie » (`_addAllergyFields`) | Enabled once Oui / Non is chosen, or when a name was already typed → `_nextPage` |
| 6 | 3 conditions | `OmniOptionGroup` « Oui » / « Non ». « Non » = empty selection, by removing each selected item through `provider.removeChronicCondition`. « Oui » = `OmniTextField` « Rechercher une maladie… », removable chips, checkbox rows (`add/removeChronicCondition`). Labels in French; values stay the English constants | Enabled once answered, or when conditions are already selected |
| 7 | 4 medications | `OmniOptionGroup` « Oui » / « Non, aucun médicament ». « Non » = `_clearMedications()` (the former « not taking any » body). « Oui » = `OnboardingNote` « L’ajout de médicaments sera bientôt disponible ». No medication cards | « Terminer », enabled only after « Non » → `_nextPage` (Complete) |

**Back:**
- Page 0 has no back (as before).
- Page 1 goes back one sub-step first, then `_previousPage` (the former back arrow body).
- Pages 2–4 use `_previousPage`.

**Other behaviour:**
- Swiping between pages is unchanged.
- **Final screen:** check pop (`easeOutBack`, 520 ms, none with reduced motion), « Vos informations sont enregistrées », the text, `OnboardingSummaryList`, and a pinned « Accéder à mon espace » → `/home`.
  - The summary is built from `UserOnboardingProvider`, which `_buildDraft` fills as before.
  - A row is omitted when its value is missing. The allergies and conditions rows appear only when not empty (§8.4).

## 3. What stayed where (verbatim bodies)

| Method | Status |
|---|---|
| `_addMedicationFields`, `_addAllergyFields`, `_removeAllergyFields`, `_heightCm`, `_weightKg`, `_bmiPreview`, `_refreshBodyMeasurementPreview`, `_loadResume`, `_formatWeight`, `_nextPage`, `_validateThrough`, `_buildDraft`, `_readDraft`, `_finishOnboarding`, `_collectAllergies`, `_clearAllergies`, `_formatDateOnly`, `_formatDobDisplay`, `_pageCount`, `_lastPageIndex`, `bloodTypes`, `availableConditions`, every controller and list | **Verbatim** |
| `_collectMedications` | Verbatim except the 2 SnackBar texts → ARB (same rule; unreachable now, since no rows are shown) |
| `_validateBasicProfile`, `_validateBodyMeasurements`, `_validateAllergies` | Same checks and order. Texts → ARB; sink SnackBar → `_showInlineError` (inline; a profile failure also opens the fields) |
| `_filterConditions` | Matches the **French label**, accent-free (« diabete » finds « Diabète »), as asked; the list still holds the English values |
| `_pickDateOfBirth` | `showDatePicker` → `showOmniBirthDatePicker`, same initial date (25 years ago, 1 Jan) and limits (1900 … today) |
| `didChangeDependencies` | Calls `_startResume()`, which `await`s the unchanged `_loadResume()` and then decides the intro (page index 0 after resume) |
| AppBar back / « Skip » / « not taking any » inline closures | Moved unchanged into `_previousPage`, `_skip`, `_clearMedications` |
| Removed | The medication card UI (cards, chips, `MedicationSearchField`, 💊), `_removeMedicationFields` (only used by those cards), the `_saving` full-screen overlay (now a spinner in the button), `SmoothPageIndicator`, `GoogleFonts` |

## 4. ARB keys (94, prefix `onboarding…`)

- **Intro (10):** `IntroChipBlood`, `IntroChipAllergies`, `IntroChipMedications`, `IntroChipFollowUp`, `IntroTitle`, `IntroBody`, `IntroDuration`, `IntroEditable`, `IntroStart`, `IntroLater`.
- **Common (5):** `Continue`, `Finish`, `Yes`, `No`, `Loading` (spinner label).
- **Profile (10):** `ProfileTitle`, `ProfileSubtitle`, `ProfileConfirm`, `FirstName`, `LastName`, `BirthDate`, `Gender`, `GenderMale`, `GenderFemale`, `GenderOther`.
- **Checks (13):** `ErrorFirstName`, `ErrorLastName`, `ErrorBirthDate`, `ErrorBirthDatePast`, `ErrorGender`, `ErrorHeight`, `ErrorWeight`, `ErrorHeightInvalid`, `ErrorWeightInvalid`, `ErrorAllergyName`, `ErrorAllergySeverity`, `ErrorMedicationSelect`, `ErrorMedicationDosage`.
- **Body (12):** `BloodTitle`, `BloodSubtitle`, `HeightTitle`, `HeightLabel`, `WeightTitle`, `WeightLabel`, `WeightTypeIn`, `WeightFieldLabel`, `UnitCm`, `UnitKg`, `Bmi` ({value}), `BmiPending`.
- **Allergies (12):** `AllergiesTitle`, `AllergiesSubtitle`, `AllergiesNo`, `AllergyCardTitle` ({index}), `AllergyRemove` ({index}), `AllergyName`, `AllergySeverity`, `SeverityMild`, `SeverityModerate`, `SeveritySevere`, `AllergyLifeThreatening`, `AllergyLifeThreateningHint`, `AllergyAdd`.
- **Conditions (19):** `ConditionsTitle`, `ConditionsSubtitle`, `ConditionsSearch`, `ConditionsNoMatch`, `ConditionRemove` ({name}), plus 14 labels `ConditionDiabetes` … `ConditionMigraine`.
- **Medications (5):** `MedicationsTitle`, `MedicationsSubtitle`, `MedicationsNo`, `MedicationsSoonTitle`, `MedicationsSoonBody`.
- **Final (7):** `DoneTitle`, `DoneBody`, `DoneCta`, `SummaryName`, `SummaryBlood`, `SummaryAllergies`, `SummaryConditions`.

Reused: `authLogoLabel`, `bloodTypeUnknown` (« Je ne sais pas », via `BloodType.label`), `authBack`, `onboardingSkip`, `onboardingProgressLabel`, `onboardingPageAlreadySaved`, `onboardingSaveFailed`.

## 5. Translated strings (P0 §g list → French)

- **AppBar and buttons:** Skip → « Passer » · Continue → « Continuer » · Complete → « Terminer ».
- **Profile:** Confirm your profile → « C’est bien vous ? » · These details… → « Vérifiez les informations de votre compte. » · First name / Last name / Birth date / Gender → « Prénom » / « Nom » / « Date de naissance » / « Genre » · Male / Female / Other → « Homme » / « Femme » / « Autre ».
- **Body:**
  - What is your blood type? → « Quel est votre groupe sanguin ? »
  - The **« blood supply » claim** is removed, replaced by « Vous pourrez le modifier plus tard dans votre dossier. ».
  - Height and weight / Height / Weight → « Quelle est votre taille ? » / « Quel est votre poids ? » / « Taille » / « Poids ».
  - BMI x.x → « IMC x,x » · BMI will be calculated… → « L’IMC sera calculé à partir de votre taille et de votre poids. ».
- **Allergies:** Any allergies? → « Avez-vous des allergies ? » · Add medication, food… → « Médicaments, aliments ou autres (ex. latex). » · Allergy n → « Allergie n » · Remove allergy → « Supprimer l’allergie n » · Allergy name → « Nom de l’allergie » · Severity → « Gravité » · Mild / Moderate / Severe → « Légère » / « Modérée » / « Sévère » · Life-threatening → « Risque vital » · Highlight this allergy… → « Elle sera mise en évidence pour les soignants. » · Add Another Allergy → « Ajouter une allergie » · I don't have known allergies → « Non, aucune allergie connue ».
- **Conditions:**
  - Any chronic conditions? → « Avez-vous une maladie chronique ? »
  - The **« 100% safe » claim** is removed, replaced by « Vos médecins en tiennent compte pour votre suivi. ».
  - Search conditions... → « Rechercher une maladie… »
  - The 14 names → Diabète, Hypertension artérielle, Asthme, Maladie cardiaque, Arthrite, Trouble de la thyroïde, Maladie rénale, Maladie du foie, Cancer, Épilepsie, BPCO, Dépression, Anxiété, Migraine (display only).
- **Medications:** Current Medications → « Prenez-vous des médicaments ? » · Add any medications… 💊 → « Indiquez ceux que vous prenez en ce moment. » · I'm not taking any medications → « Non, aucun médicament ». Medication n / Remove medication / Medicine name / Dosage / Add Another Medication / Soluble are removed with the cards.
- **SnackBars, now inline:**
  - The 11 « Please … » profile, height, weight and allergy messages → the `onboardingError…` keys above.
  - The 2 medication messages → `onboardingErrorMedicationSelect` / `…Dosage` (still SnackBars, unreachable).
- **Final screen:** Thank You! 🎉 → « Vos informations sont enregistrées » · Your medical information helps… → « Vous pourrez les compléter à tout moment depuis « Dossier médical ». » · Your Medical QR Code / the QR warning / Take a Quick Demo → removed · Go to Dashboard → « Accéder à mon espace ».
- **Emoji:** all removed (💊 ×3, 🎉).
- **Colours:** every `Color(0x…)` / `Colors.*` in the two screens is now an `OmniColors` token.

## 6. Tests

- **Only test change:** `test/blood_type_and_medical_save_test.dart`, 3 lines before the fling: a comment, `tap(find.text('Commencer'))` and `pumpAndSettle()`. Assertions are unchanged. No other test asserted the translated English texts (grep: the « Continue » / « Complete » / « Skip » hits are other screens).
- `flutter analyze` on `lib/features/onboarding`, `omni_text_field.dart`, `omni_choice_tile.dart`, `lib/l10n` and that test: **No issues found**.
- `test/l10n_arb_contract_test.dart`: all passed. Onboarding logic tests (`onboarding_per_step_save_test`, `onboarding_blood_type_guard_test`, `error_sinks_french_test`) pass **unchanged**.
- Full `flutter test` (exit 0): `01:40 +1971 ~7: All tests passed!` → **1971 passed, 7 skipped, 0 failed**. No failures in untouched files.
- **Throwaway end-to-end check, 8/8:** in the scratchpad, copied into `test/` only for the run, then deleted; no new repo tests.
  1. **Fresh account through to home:**
     - intro, then the card, then « C’est bien moi » → `step1` with the same 4 fields;
     - AB+;
     - height starts at « — » with the button disabled, then a drag;
     - weight starts at « — », typed in as 68,5, BMI shown;
     - back from weight goes to height;
     - `passport` {AB+, 171, 68.5};
     - allergies Oui + 2 cards, then Non → `{noKnownAllergies:true}`;
     - « diabete » → Diabète → `{conditions:[{name:Diabetes, criticalOptIn:false}]}`;
     - medications Oui → note, button disabled, then Non → `step4 {noKnownMedications}`;
     - order `step1, passport, step2, step3, step4`;
     - summary without QR → home.
  2. Resume at server step 3: no intro, conditions page; « Passer » → home, nothing sent.
  3. Intro « Plus tard » → home, nothing sent.
  4. Profile read failed: the form opens, « Saisissez votre prénom. » shows inline with no SnackBar, and clears on typing.
  5. Saving: spinner inside the button; a double tap sends `step1` once.
  6. 360×640 and 7. 320×568, both at text size 1.3: every page and sub-step, keyboard (260 px) open and closed, scrolled to the end. No overflow; the main button stays visible.
  8. Final screen at 320×568, text size 1.3, reduced motion: no overflow, button visible.

## 7. Deviations (reported)

1. **Validators:** same rules and order. Only the texts (French ARB) and the sink (inline instead of SnackBar) changed, as the task asked for « inline, in French ».
2. **One inline message area per page, under the page's fields,** rather than under each field: a validator returns one message, not a field. A profile failure also opens the profile form.
3. **Initial load:** a full-screen spinner now shows while the resume read runs. It is needed to know whether to show the intro, and the user asked for it. The read itself is unchanged.
4. **The intro also shows when the profile read fails** (resume then defaults to page 0, as before).
5. **The intro's two buttons are pinned** at the bottom of the white card area. Not pinned, « Commencer » fell below the fold on 320–360 px phones (found by the pinned test at 320×720).
6. **Page 0 form-mode button** reads « Continuer ». The spec gives « C’est bien moi » for the card only.
7. **Rest positions:** wheel 170 cm, ruler 70 kg (not in the spec). These are REQUIRES MEDICAL VALIDATION, Q3.
8. **Blood grid:** built as rows of 3 / 3 / 2 instead of a fixed-ratio `GridView`, so tiles can grow with text size.
9. **Small additions:** `onboardingConditionsNoMatch` (empty search), `onboardingLoading` (spinner label) and remove labels for screen readers.
10. **Additive parameters:** `primaryLoading` on the frame and `textCapitalization` on `OmniTextField`. The choice-tile padding was narrowed.
11. **`confetti` is no longer used** anywhere in `lib/` (`qr_flutter` and `smooth_page_indicator` still have other users). `pubspec.yaml` is untouched.

## 8. Open questions

1. **Inline error placement:** one message per page (now), or a field-by-field mapping? The second would need the validators to return a field, which is a logic change.
2. **Weight decimals:** the ruler sends whole kg and replaces a typed 68,5 when dragged. Keep that?
3. **Rest positions** 170 cm / 70 kg, and the wheel/ruler ranges 30–299 / 1–499: medical validation.
4. **Final summary:** allergies and conditions show only when entered this session. An empty list in memory can also mean « saved in an earlier session », so « Aucune allergie connue » is never shown. Is that wanted, or should these rows be dropped entirely?
5. **Medications « Oui »:** the patient cannot finish while « Oui » is selected (button disabled until « Non »). Is that acceptable until free-text medications land (G-2.1 A3), or should « Oui » also allow « Terminer »? The latter would send `noKnownMedications: true`, a false statement.
6. **The `confetti` package is now unused:** remove it in a pubspec prompt?

## 9. Android checklist (CTO)

1. **Fresh account** (new test patient): sign up → intro (dark top, logo, 4 chips, card) → « Commencer » → « C’est bien vous ? » card → « C’est bien moi » → groupe sanguin → taille → poids → allergies → maladies → médicaments → « Terminer » → « Vos informations sont enregistrées » with the summary → « Accéder à mon espace » → home. The progress bar advances over 7 steps.
2. **Resume:** start again with a new account, answer up to the allergies page (page 2), close the app, reopen and sign in. Expect no intro and the first unsaved page.
3. **« Passer »:** on any page, and « Plus tard » on the intro → home. On the next sign-in, onboarding shows again (unchanged behaviour).
4. **Height and weight start at « — »:** « Continuer » stays grey until the wheel or ruler is moved.
5. **Type-in weight:** « Saisir au clavier » → type 68,5 → the readout shows « 68,5 » and « IMC … » updates.
6. **Allergies:** « Oui » → fill a card, « Ajouter une allergie » → 2 cards → then « Non, aucune allergie connue ». The cards are cleared and « Continuer » saves « none known ».
7. **Conditions:** « Oui » → type « diabete » → « Diabète » appears; tick it, see the chip, tap the chip to remove it.
8. **Medications:** « Oui » → the note appears and « Terminer » stays grey → « Non, aucun médicament » → « Terminer ».
9. **Profile edit:** « Modifier » on the card opens the fields. Empty the first name → « Continuer » → « Saisissez votre prénom. » under the fields.
10. **Small phone** (≤ 360 dp) at the largest text size: every page scrolls, nothing is cut, and the button stays above the keyboard.
11. **Reduced motion** (Developer options → animation scale off): no intro entrance, no progress animation, no check pop.

## Path to deliver G-3

1. **CTO:** run §9 on Android (and web) and answer §8 Q1–Q6.
2. **ONB-3** (if needed): only the fixes from that pass. Then close the onboarding page (ranked fix list ✔, approved design ✔, UI-only prompts ONB-1 / ONB-2 ✔).
3. **Parked to G-2.1:**
   - « Je ne sais pas » / per-step « Passer » for lists;
   - free-text medications (A3/B3), which will replace the « bientôt disponible » note;
   - conditions in MRS;
   - server skip.
4. **Next G-3 page** from the CTO's screenshots, reusing the frame, option rows, tiles, wheel/ruler, summary and note.

## ONB-3a — Animated BMI card (weight sub-step)

Display only. The value is the existing `_bmiPreview`, unchanged. There are no categories, no thresholds and no colours by range: those are clinical rules, REQUIRES MEDICAL VALIDATION, and out of scope.

**Files**
- **New:** `lib/features/onboarding/widgets/bmi_card.dart`, `BmiCard({bmi, heightCm})`.
- **`conversational_onboarding_screen.dart`:** in `_weightStep`, the BMI row is replaced by `BmiCard(bmi: _bmiPreview, heightCm: _heightCm)`. The now-unused `NumberFormat` import and local are removed. Nothing else changed.
- **`app_fr.arb`:** re-read from disk. 2 keys appended: `onboardingBmiTitle` « Votre IMC » and `onboardingBmiHeightNote` « Calculé avec votre taille ({height} cm) ». Then `flutter gen-l10n`.

**Behaviour**
- **No BMI yet:** the former neutral line (slateSoft, « L’IMC sera calculé… »), with the text now in textSecondary.
- **BMI available:** a mintSoft card (radius 16, padding 16) with:
  - a 44 px white tile holding a deepTeal heart-monitor icon (Material has no « activity » icon);
  - « Votre IMC » (13 w700 deepTeal);
  - the value (30 w800, tabular figures, `0.0` French format, e.g. « 23,4 »);
  - « Calculé avec votre taille (171 cm) » (12 w500 textSecondary).
- **Motion:**
  - Fade plus a 12 px slide up (300 ms easeOut), only the first time a value exists.
  - After that, `TweenAnimationBuilder<double>` counts from the value on screen to the new one (420 ms easeOutCubic).
  - With reduced motion there is no slide and no count.
- **Semantics:** a live region labelled « Votre IMC : 23,4 » with the final value only. The animated children are excluded from semantics.

**Deviations**
1. **`onboardingBmi` was edited in place.** It was the only change to an existing ARB entry. The old row's « IMC {value} » would have been left unused, which fails the ARB contract test. Its value is now « Votre IMC : {value} » and it serves as the screen-reader label.
2. **The entrance plays once per visit to the step.** If the BMI goes back to empty and then returns, the card reappears without the slide.
3. **The footnote is hidden if the height is missing.** That cannot happen while a BMI exists.

**Bug found and fixed during the check**
- The entrance controller was first created lazily, inside `dispose`, when no value had ever arrived. In debug, leaving the weight step that way threw « deactivated widget's ancestor ».
- The controller is now created in `initState`.

**Checks**
- `flutter analyze` on `lib/features/onboarding` and `lib/l10n`: no issues.
- `test/l10n_arb_contract_test.dart`: 10/10 passed.
- Full `flutter test`: 1971 passed, 7 skipped, 0 failed. No repo test changed, none added.
- Throwaway checks, run from `test/` and then deleted: 11/11 passed.
  - **Card (3):**
    - empty, then a value: the fade runs, then the count from 23,4 to 24,6, with the label already final mid-count;
    - with reduced motion the value updates instantly;
    - no overflow at 320 px and text size 1.3.
  - **ONB-2 end-to-end (8):** re-run with the card text in place of « IMC … »; same requests, no overflow at 360×640 and 320×568 at text size 1.3 with the keyboard open.

**Android checklist addition**
- Weight step: before a weight, the grey line shows.
- Move the ruler: the green card slides in, then the number rolls with each change.
- TalkBack reads « Votre IMC : … » once per change.
- With animations off, the number just changes.
