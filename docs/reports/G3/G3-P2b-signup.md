# G3-P2b — Patient sign-up in 3 steps (UI only)

Date: 2026-11-12 · Repo: OmniCare-App, current working tree.
Builds on P1 widgets and P2a / P2a-fix (`OmniPressable`, bundled font, `AuthPromptLink`).
**Behaviour unchanged:** same validator rules, same `PhoneSignupDraft`, same controller calls, same navigation (§2).

## 1. Files changed

| File | Change |
|---|---|
| `lib/features/auth/widgets/auth_flow_frame.dart` | **New.** Shared frame: dark band (56 px under the safe area) with back « Retour », title 16 w700, close « Fermer »; white panel (top radius 24) with optional step progress, scrolling body, and the main button pinned at the bottom (the Scaffold resizes, so it stays above the keyboard). Max content width 480. |
| `lib/features/auth/signup_screen.dart` | **Rewritten UI, same class.** Step 1 « Compte » and step 2 « Identité » in one screen (`AnimatedSwitcher`: fade + 16 px slide, 250 ms, easeOutCubic; instant with reduced motion). Logic kept (§2). |
| `lib/features/auth/phone_input_screen.dart` | **Restyled, same class and constructor.** Same frame; « +216 » `OmniTextField`; French texts; keyboard « done » disabled while loading. E-mail sign-up only: 3/3 « Téléphone » bar, « Récapitulatif » card with « Modifier » links, terms, « Créer mon compte ». |
| `lib/features/auth/widgets/google_brand_button.dart` | `OmniPressable` inside (press scale, focus ring, 10 / 6 / 10 % layers), so the login sheet gets it too. |
| `lib/features/auth/widgets/login_sheet.dart` | Item f only: close tooltip → `commonClose`; phone-login button wrapped in `OmniPressable` (+ slate 10 / 6 / 10 % layers). Nothing else. |
| `lib/features/auth/widgets/password_rule_chip.dart` | Screen readers hear « label, respecté / non respecté »; bundled font. |
| `lib/core/widgets/omni_birth_date_picker.dart` | Close tooltip → `commonClose`; bundled font on its texts. |
| `lib/core/widgets/omni_step_progress.dart`, `lib/core/widgets/omni_segmented_choice.dart` | **Bundled font only** (their texts appear on these screens). |
| `test/auth_phase1_test.dart` | Only the small-phone sign-up test (≈ line 3988): `find.byType(ElevatedButton).hitTestable()` = « exactly one primary action visible on the current step », width check kept. Nothing else changed. |
| `lib/l10n/app_fr.arb` | 54 keys appended at the end (§3); `birthDatePickerClose` removed (§6.11). |
| `lib/l10n/omni_localizations*.dart` | Regenerated (`flutter gen-l10n`). |

Not changed: `auth_controller.dart`, repositories, services, DTOs, `PhoneSignupDraft`, `auth_error_messages.dart`, `main.dart`/routes, `otp_verification_screen.dart`, `web/index.html`, `pubspec.yaml`, global theme, `lib/features/doctor/**`.

## 2. What moved where

| Before (`signup_screen.dart`) | After |
|---|---|
| `_handleGoogleIdToken`, `_handleGoogleSignUp`, `_routeAuthenticated` | **Verbatim.** Only the SnackBar fallback text now comes from the ARB (same words). |
| `_formatDobDisplay`, `_isAtLeast18` | **Verbatim.** |
| Validators: e-mail (`:326-332`), password (`:354-360`), confirm (`:384-391`), names (`:403-420`), DOB (`:449-455`) | Same rules on the step fields. Texts moved to the ARB with the same words. 12 / 128 became named constants with the same values. New: `autovalidateMode.onUserInteraction`, and `maxLength` 255 / 128 / 100 (typing stops at the limit, no counter). |
| Single form + `_handleEmailSignUp` | Step 1 form → `_continueFromAccount` (validates step 1, shows every step-1 error). Step 2 form → `_handleEmailSignUp`: the same checks in the same order. The 3 SnackBars became inline errors (gender under the segmented control; the two DOB messages under the date field). The draft is built **exactly** as before, then `PhoneInputScreen(mode: signup, signupDraft, rememberDevice)` is pushed. The only addition: the push awaits an `int?` (0 / 1 from « Modifier ») to reopen step 1 / 2. |
| `showDatePicker` | `showOmniBirthDatePicker`: initial `_selectedDateOfBirth ?? 1 Jan (now − 20)` as before, first date 1900-01-01. Last date = the latest date `_isAtLeast18` accepts today, derived from the rule itself (so 29 February is handled). Its error text is the 18+ sentence from the ARB. After a pick, the step-2 form is validated (as the whole form was before). Display `dd/MM/yyyy` unchanged. |
| `_GenderCard` ×2 (M / F) | `OmniSegmentedChoice<String>` Homme / Femme → `'M'` / `'F'`, semantic label « Genre ». |
| Trusted-device checkbox (always shown) | `TrustedDeviceSwitch` on step 2 **only when** `AppEnvironment.phoneVerificationEnabled` (the login's flag). Otherwise hidden; the same `_rememberDevice` (false) is sent. |
| « Vous avez déjà un compte ? Se connecter » (`pushReplacement(LoginScreen)`) | Kept at the bottom of step 1 as an `AuthPromptLink`, same navigation (§6.1). |
| Terms sentence | On the phone step of the e-mail sign-up (spec), same words. |

`phone_input_screen.dart`:
- **Unchanged:** `_submitPhone`, `TunisianPhoneNumber.normalize`, the `UserOnboardingProvider.setPhoneNumber` call, the three controller branches, OTP routing and `navigateAfterAuthentication`.
- **Validator:** same rule. « Phone number is required » → « Numéro de téléphone requis ». The normalizer's English message → « Saisissez les 8 chiffres de votre numéro. » (`tunisian_phone_number.dart` untouched). The fallback « Unable to continue. » → « Impossible de continuer. ».

**`PhoneInputScreen` in its 3 flows:**

| Flow | Opened from | Header title | Step bar / summary / terms | Button |
|---|---|---|---|---|
| E-mail sign-up | sign-up step 2 (draft present) | « Créer un compte patient » | 3/3 « Téléphone » + « Récapitulatif » + terms | « Créer mon compte » (haptic) → same `_submitPhone` → `startPhoneSignup(draft, …)` |
| Phone login | login sheet (only if phone verification on) | « Numéro de téléphone » | none | « Envoyer le code » / « Continuer » as before → `startPhoneLogin` |
| Google sign-up | login sheet or sign-up step 1, after Google | « Numéro de téléphone » | none | as before → `startGooglePhoneSignup` |

**Navigation:**
- Back = previous step (header or system back via `PopScope`); on step 1 it pops to the screen below.
- Close « Fermer » pops to the first route (the welcome screen). It is disabled while loading.

## 3. ARB keys

- **Reused:** `authEmailLabel`, `authPasswordLabel`, `authShowPassword`, `authHidePassword`, `authSignIn`, `authContinueWithGoogle`, `passwordsNotMatch`, `sendCode`, `birthDatePickerTitle` (« Date de naissance » field label).
- **New (54, each with `@` description):**
  - **Common / chip:** `commonClose`, `authBack`, `authContinue`, `passwordRuleMet`, `passwordRuleNotMet`.
  - **Sign-up steps:** `signupTitle`, `signupStepAccount` / `Identity` / `Phone`, `signupAccountTitle` / `Subtitle`, `signupOrWithEmail`, `signupConfirmPasswordLabel`, `signupPasswordRuleMinLength`, `signupPasswordsMatch`, `signupFieldRequired`, `signupEmailInvalid`, `signupPasswordTooShort` / `TooLong`, `signupIdentityTitle` / `Subtitle`, `signupFirstNameLabel`, `signupLastNameLabel`, `signupAgeRequirement`, `signupAgeTooYoung`, `signupGenderLabel` / `Male` / `Female`, `signupSelectGender`, `signupSelectBirthDate`, `signupGoogleFailed`, `signupHaveAccount`.
  - **Terms and summary:** `signupTermsIntro` / `Conditions` / `And` / `Privacy`, `signupSummaryTitle`, `signupEdit`, `signupEditAccount`, `signupEditIdentity`, `signupCreateAccount`.
  - **Phone:** `phoneScreenTitle`, `phoneLoginTitle`, `phoneVerifyTitle`, `phoneContactTitle`, `phoneLoginSubtitle`, `phoneVerifySubtitle`, `phoneContactSubtitle`, `phoneHint`, `phoneFormatHelper`, `phonePrefix`, `phoneRequired`, `phoneDigitsInvalid`, `phoneUnableToContinue`.
- **Removed:** `birthDatePickerClose` (replaced by `commonClose`, §6.11).

## 4. Checks

- **`flutter analyze --no-pub`** on every touched file (sign-up, phone, `widgets/`, `lib/core/widgets/`, `lib/l10n/`, `auth_phase1_test.dart`): **No issues found.**
- **`flutter test test/auth_phase1_test.dart test/l10n_arb_contract_test.dart`:** `+112 ~7: All other tests passed!` Only the ≈3988 assertion was edited; the LoginScreen and link-sheet tests are unchanged.
- **Throwaway end-to-end check** (session scratchpad, not in the repo), 5/5 passed, with the real controller and a fake repository:
  - **Full sign-up:**
    - empty step 1 → 3 × « Champ requis » and chip « non respecté »; live « Adresse e-mail invalide »;
    - « Utilisez au moins 12 caractères » → chip « respecté »; confirm mismatch → match (« Les mots de passe correspondent ») → password edited → mismatch again;
    - step 2 → back keeps values; empty step 2 → 3 × « Champ requis »;
    - picker « Valider » → `01/01/<now − 20>`; no gender → inline « Sélectionnez votre genre. » (no SnackBar);
    - phone step shows « Étape 3 sur 3 · Téléphone », the summary « Amel Testeur », « 01/01/… · Femme », « Créer mon compte »;
    - « Modifier » identity → step 2 with values; « Modifier » account → step 1;
    - phone errors « Numéro de téléphone requis » / « Saisissez les 8 chiffres de votre numéro. »;
    - « 12 345 678 » → **`completePhoneSignup` called once with phone `+21612345678` and the same draft** (e-mail, password, names, `F`, `dateOfBirthIso`), `rememberDevice: false` → destination route reached.
  - **Under-18:** a date after the limit in the picker → the 18+ sentence in the error box and « Valider » disabled.
  - **Phone-login and Google flows:** their titles, no step bar, no summary, « Continuer » (phone verification off).
  - **360×640 and 360×520 at text scale 1.3, with a 260 px keyboard:** no overflow, exactly one hit-testable primary button. The first run found a 21 px overflow in the « ou avec votre e-mail » divider; it was fixed (the label now wraps, max 70 % width).
- **`flutter test` (full suite, `--no-pub`):** `02:29 +1946 ~7: All other tests passed!` (exit 0): **1946 passed, 7 skipped, 0 failed.**

## 5. Rules check

- **Text:** no `print` / `debugPrint`; nothing typed is logged.
- **Tokens and font:** Omni tokens only (14 px radius literal as in P2a); every text on these screens uses the bundled family at w500 or more.
- **Touch targets:** 44 px minimum (header icons, eye toggles, « Modifier », links).

## 6. Deviations (reported, not hidden)

1. **« Vous avez déjà un compte ? Se connecter »** is kept on step 1 (not in the spec) so the existing navigation stays reachable.
2. **Terms:** they appear only on the phone step of the e-mail sign-up (spec). The Google sign-up path no longer shows them before Google (before, they were visible on the sign-up screen).
3. **Trusted device and Google:** the switch is on step 2, behind the phone-verification flag. The Google button (step 1) therefore always sends `rememberDevice: false` from sign-up. Before, a user could tick the box before tapping Google. This only matters when the flag is on, since the server ignores it otherwise (P0 §c).
4. **Prénom / Nom** are side by side only when the form is at least 390 px wide (the existing responsive rule), so they stack on most phones.
5. **« Créer mon compte »** is used in the e-mail sign-up even when phone verification is ON. In that case the button sends the SMS code first and the account is created after the OTP, as before (Q1).
6. **Phone screen:** server errors still show as a SnackBar (inline errors were specified for step 2 only). The 64 px phone icon tile is gone. « Format tunisien à 8 chiffres » is now the field helper, hidden while an error shows.
7. **Picker limit** derived from `_isAtLeast18` (not a new formula); the rule itself is unchanged.
8. **Two DOB submit checks** (null / under 18) are kept in order but can't trigger, because the field validator catches both first. They now render inline under the field.
9. **`maxLength`** stops typing at the limit (Flutter's default enforcement) instead of only validating.
10. **« Fermer »** pops to the first route. From the phone-login flow (opened over the login sheet) it closes the sheet as well.
11. **ARB edits:**
    - The 54 keys were added by a script that rewrote the file with its original text kept byte-for-byte and the keys appended at the end.
    - `birthDatePickerClose` (my own P1 key) was removed with a targeted edit: once the picker used `commonClose`, it was unused, and the ARB contract test requires every key to be used.
12. **Font:** the bundled family was added to 4 P1 widgets (step progress, segmented choice, picker, chip), since their texts appear here.
13. **Process:** I ran one read-only `git diff --stat` by mistake (no output, no change). No other git command was used.

## 7. Open questions

1. With phone verification ON, should the e-mail sign-up button read « Recevoir le code » instead of « Créer mon compte »?
2. Should the terms also appear on step 1, before the Google button (§6.2)?
3. Should Prénom / Nom always be side by side (risk: narrow fields at 360 px with large text), or keep the 390 px rule?
4. Phone screen: inline banner instead of SnackBar for server errors (as in the login sheet)?
5. Should « Fermer » on the sign-up ask for confirmation when fields are filled (data loss)?

## 8. Manual test checklist for the CTO (web + Android)

1. **Full sign-up with a test account:** welcome → « Créer un compte ».
   - Step 1: e-mail, password (≥ 12), confirm → « Continuer ».
   - Step 2: Prénom, Nom, date (wheel picker), Genre → « Continuer ».
   - Step 3: phone `12 345 678` → summary correct → « Créer mon compte » → you land where a new account landed before (onboarding). Log out and log in with the same e-mail and password.
2. **Step 1 errors:**
   - « Continuer » on an empty step → all three fields show « Champ requis » and the chip turns red.
   - `abc` → « Adresse e-mail invalide » while typing.
   - Password `court` → « Utilisez au moins 12 caractères »; at 12 characters the chip turns green.
3. **Password mismatch then match:** confirm differs → « Les mots de passe ne correspondent pas »; make it equal → green border, ✓ and « Les mots de passe correspondent ». Change the first password → it turns red again.
4. **Step 2 errors:** empty names → « Champ requis »; no date → « Champ requis »; no gender → « Sélectionnez votre genre. » under Homme / Femme (no SnackBar).
5. **Under-18:** in the picker, choose a date less than 18 years ago → red box « Vous devez avoir au moins 18 ans pour créer un compte. » and « Valider » greyed. The day wheel clamps (31 → 30 / 28 / 29). Month names are in French.
6. **« Modifier » links:** on step 3, « Modifier » next to the e-mail → step 1 with values kept; next to the name → step 2 with values kept.
7. **Phone errors:** empty → « Numéro de téléphone requis »; `123` → « Saisissez les 8 chiffres de votre numéro. »; during loading, the keyboard « OK » does nothing.
8. **Back / close:** header ← and system back on step 2 → step 1; on step 1 → welcome. « Fermer » (×) → welcome from any step.
9. **Phone-login flow unchanged** (only if phone verification is on): login sheet → « Continuer avec un numéro de téléphone » → « Connexion par téléphone », no step bar or summary, « Envoyer le code » → OTP as before.
10. **Google flows unchanged:**
    - Android: « Continuer avec Google » on step 1 → new account → phone screen « Votre numéro de téléphone » (no summary) → as before.
    - Web: the Google-rendered button in French.
11. **Press / hover / focus:**
    - buttons and links shrink slightly and tint on press; the Google button too (also in the login sheet);
    - Android: vibration on « Continuer » and « Créer mon compte »;
    - web: hover tint and hand cursor; Tab shows the mint focus ring.
12. **Reduced motion:** steps switch instantly; no press shrink.
13. **Small phone** (360×640, large text): every step scrolls, nothing cut, the button stays at the bottom.
14. **Keyboard open:** the « Continuer » / « Créer mon compte » button stays visible just above the keyboard.

## Path to deliver G-3

1. **CTO manual pass** on P2b (§8, web + Android) with a real test account; answer §7 and the parked P2a-fix §F.1 (global font fix).
2. **Close the auth page:** apply the checklist fixes only. Then publish the auth-page summary (ranked fix list done, target approved, UI-only prompts P1 → P2b) as the G-3 reference.
3. **Next page** from the CTO's screenshots: same loop (P0 inspection → ranked fix list → approved design → UI-only prompt), reusing `AuthFlowFrame`, `OmniPressable`, `OmniLogoBadge` and the bundled font. Backend items stay parked (P0 §g: password reset, precise age/gender codes, Google flag, trusted device without OTP).

---

# P2b-fix — Button label and terms on the phone step

Logic unchanged: same `_submitPhone`, same controller calls, same flag (`AppEnvironment.phoneVerificationEnabled`).

## A. Files changed
| File | Change |
|---|---|
| `lib/features/auth/phone_input_screen.dart` | 1) E-mail sign-up button label: « Recevoir le code » when the flag is on, « Créer mon compte » when it is off (same handler). 2) `_TermsText` now shows whenever `mode != login` (e-mail **and** Google sign-up), still the last item of the body, right above the pinned button. Not in phone login. Doc comment updated. |
| `lib/l10n/app_fr.arb` | 1 key appended at the end by a direct text edit (file re-read from disk right before): `signupReceiveCode` « Recevoir le code ». |
| `lib/l10n/omni_localizations*.dart` | Regenerated by `flutter gen-l10n`. |

Untouched: `login_sheet.dart`, controller, services, repositories, DTOs, `PhoneSignupDraft`, validators, `auth_error_messages.dart`, routes, global themes, `lib/features/doctor/**`, tests.

## B. Button labels on the phone step (after the fix)
| Flow | Flag off | Flag on |
|---|---|---|
| E-mail sign-up (step 3/3) | « Créer mon compte » | **« Recevoir le code »** (new) |
| Google sign-up | « Continuer » | « Envoyer le code » |
| Phone login | « Continuer » | « Envoyer le code » |

Terms: e-mail sign-up ✔, Google sign-up ✔ (new), phone login ✘.

## C. Checks
- `flutter gen-l10n`: OK. `flutter analyze` (phone_input_screen.dart, lib/l10n): **No issues found**.
- `test/l10n_arb_contract_test.dart`: **+10, all passed**.
- Full `flutter test`: `01:45 +1946 ~7: All tests passed!` (**1946 passed, 7 skipped, 0 failed**).
- Throwaway checks (scratchpad, copied into `test/` only for the run, then deleted; not in the repo):
  - P2b e2e (5/5) plus new asserts: terms absent in phone login and present in Google sign-up.
  - Flag on (`--dart-define=OMNICARE_PHONE_VERIFICATION_ENABLED=true`): the e-mail sign-up shows « Recevoir le code » with no « Créer mon compte », and terms appear; Google sign-up shows « Envoyer le code » with the terms (1/1).
- No git command was run.

## D. Not done / reported
1. **Item 4 « Fixes from the CTO test »** was still the `<paste here>` placeholder in the prompt, so no CTO fixes were applied. Send the list and I'll do it as a follow-up.
2. **« same wording and links »:** the existing terms text has no links (two highlighted words, no tap action; no terms/privacy URL exists in the app). It is shown as-is. Making « conditions » / « politique de confidentialité » tappable needs the target URLs or pages. Parked.
3. **Placement:** the terms stay the last item of the scrolling body, right above the pinned button, as in P2b. They are not inside the pinned bar. On a short screen with the keyboard open, the user may need to scroll to see them. Moving them into the pinned bar is possible if you want them always visible.
4. P2b §7 question 2 (terms on step 1 for « S'inscrire avec Google » from step 1) is still open. This fix covers the Google sign-up **phone** step only.

## E. Manual test checklist (CTO)
1. Flag **off**, e-mail sign-up → step 3: button « Créer mon compte », terms above it.
2. Flag **on** (`--dart-define=OMNICARE_PHONE_VERIFICATION_ENABLED=true`), e-mail sign-up → step 3: button « Recevoir le code »; pressing it opens the OTP screen as before.
3. Google sign-up for a new account → phone step: terms shown above the button; label unchanged (« Continuer » / « Envoyer le code »).
4. Login sheet → « Continuer avec le téléphone »: **no** terms; label unchanged.
5. 360×640, text size 1.3, keyboard open, on the e-mail and Google phone steps: no overflow; the terms are reachable by scrolling.

## Path to deliver G-3
1. **CTO:** send the item-4 fixes, run §E and §8, and answer the open items (§7, D.2 terms links, D.3 placement, P2a-fix §F.1 global font).
2. **Close the auth page:** apply only those fixes, then publish the auth-page summary as the G-3 reference.
3. **Next page** from your screenshots: same loop (inspection → ranked fix list → approved design → UI-only prompt), reusing `AuthFlowFrame`, `OmniPressable` and the bundled font; backend items stay parked.
