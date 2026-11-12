# G3-P1 — Auth visual building blocks (UI only)

Date: 2026-11-12 · Repo: OmniCare-App, current working tree (no git command run) · No screen uses these widgets yet (P2).

## 1. Files created or edited (complete list)

| File | Status |
|---|---|
| `lib/core/widgets/omni_text_field.dart` | created |
| `lib/features/auth/widgets/password_rule_chip.dart` | created |
| `lib/core/widgets/omni_birth_date_picker.dart` | created |
| `lib/core/widgets/omni_segmented_choice.dart` | created |
| `lib/features/auth/widgets/trusted_device_switch.dart` | created |
| `lib/core/widgets/omni_step_progress.dart` | created |
| `lib/features/auth/widgets/google_brand_button.dart` | created |
| `lib/core/theme/omni_theme.dart` | edited, **additive `switchTheme` only** (lines 570-580). Nothing else changed |
| `lib/l10n/app_fr.arb` | edited, 10 keys appended at the end (lines 706-760) |
| `lib/l10n/omni_localizations.dart`, `lib/l10n/omni_localizations_fr.dart` | **regenerated** by `flutter gen-l10n` (generated from the ARB, see Q1). Not hand-edited |
| `docs/reports/G3/G3-P1-auth-widgets.md` | this report |

Not touched: screens, routes, `main.dart`, controller, repositories, DTOs, validators, `auth_error_messages.dart`, `web/index.html`, `pubspec.yaml`, the global input/button/checkbox themes, `lib/features/doctor/**`, tests.

## 2. Widget APIs (as built)

All widgets are pure UI: values and callbacks come from the screen. They contain no business rule, provider, service or network call. The only context they read is `Theme` and `OmniLocalizations`.

### a) `OmniTextField` (`lib/core/widgets/omni_text_field.dart`)
```dart
const OmniTextField({
  required String label,              // shown ABOVE the field, 14 w600 textPrimary, gap 6
  Key? fieldKey,                      // key of the inner TextFormField
  TextEditingController? controller,
  FormFieldValidator<String>? validator, // the screen's existing validator, unchanged
  String? hintText,
  IconData? prefixIcon,
  String? prefixText,                 // « +216 » segment: slateSoft, right divider
  Widget? suffix,                     // e.g. the screen's eye-toggle IconButton
  int? maxLength,                     // counter hidden
  TextInputType? keyboardType,
  TextInputAction? textInputAction,
  Iterable<String>? autofillHints,
  bool obscureText = false,
  AutovalidateMode? autovalidateMode,
  ValueChanged<String>? onChanged,
  ValueChanged<String>? onFieldSubmitted,
  FocusNode? focusNode,
  bool enabled = true,
  bool readOnly = false,
  VoidCallback? onTap,
  List<TextInputFormatter>? inputFormatters,
  String? helperText,                 // 13 w500 textSecondary
  String? successText,                // 13 w600 deepTeal, shown when isSuccess
  bool isSuccess = false,             // freshMint 1.75 border + deepTeal check icon
})
```
- **Wraps a `TextFormField`,** so `Form.validate()` and the existing validators keep working.
- **Decoration built locally:** radius `OmniRadii.field` (12), white fill, 1 px `borderLight`, focus `freshMint` 1.75, error `OmniColors.error` 1 / 1.75 focused. Content padding is read from the theme (h16 v14), error text is 13 w600 error.
- **Input text** is 15 w500 and hint 15 w500 textTertiary (weight ≥ 500).
- **Error wins over success:** while the validator returns a message, `TextFormField` hides the helper/success line.
- The global `inputDecorationTheme` is unchanged.

### b) `PasswordRuleChip` (`lib/features/auth/widgets/password_rule_chip.dart`)
```dart
enum PasswordRuleState { idle, met, failed }
const PasswordRuleChip({required String label, required PasswordRuleState state})
```
- Pill (`OmniRadii.pill`), 13 w600.
- Backgrounds: slateSoft / mintSoft / errorSoft. Text and icon: textSecondary / deepTeal / error.
- Icons: ○ / ✓ / ✕. They are excluded from semantics (see Q3).

### c) `showOmniBirthDatePicker` (`lib/core/widgets/omni_birth_date_picker.dart`)
```dart
Future<DateTime?> showOmniBirthDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? lastDateError,
})
```
- **Sheet:** `showModalBottomSheet(isScrollControlled: true, useSafeArea: true)` styled by `bottomSheetTheme` (radius 24, drag handle). Title « Date de naissance » (20 w700), close `IconButton` (44 px min, tooltip « Fermer »).
- **Wheels:** labels JOUR · MOIS · ANNÉE (12 w700 textSecondary). Three `ListWheelScrollView.useDelegate` with `FixedExtentScrollController` + `FixedExtentScrollPhysics`, itemExtent 44, 5 visible rows (220 px), flex 2:3:2.
- **Selection band:** mintSoft, radius 12, behind the middle row.
- **Row styles:** selected 22 w700 textPrimary; ±1 rows 18 w500 textSecondary; others 16 w500 textTertiary. Text uses `FittedBox.scaleDown`, so long months (« septembre ») never overflow at scale 1.3.
- **Months:** `intl` `DateFormat.MMMM(<app locale>)`, i.e. French (« janvier »). Lower-case, as intl returns (Q4).
- **Day clamp:** the day follows the month length (31 → 30 / 29 / 28) via `DateUtils.getDaysInMonth`, and the wheel jumps to the clamped day.
- **Limits:** years run `firstDate.year … lastDate.year`. The initial year is clamped into that range.
  - After `lastDate`: shows `lastDateError` in an errorSoft box (live region) and disables « Valider ».
  - Before `firstDate`: only disables « Valider » (no text was specified, Q5).
- **Result:** « Valider » (theme `ElevatedButton`) returns the date with no time part. Close / drag / back returns `null`.
- **No limit is computed here:** the screen passes `lastDate` (today − 18 y) and the 18+ text from its existing rule.

### d) `OmniSegmentedChoice<T>` (`lib/core/widgets/omni_segmented_choice.dart`)
```dart
class OmniChoiceOption<T> { const OmniChoiceOption({required T value, required String label}); }
const OmniSegmentedChoice({
  required List<OmniChoiceOption<T>> options,   // 2 or 3 (assert)
  required T? value,                            // null = nothing chosen
  required ValueChanged<T>? onChanged,          // null = disabled
  String? errorText,                            // error border 1.75 + 13 w600 message below
  String? semanticLabel,                        // group name, e.g. « Genre »
})
```
- **Container:** slateSoft, radius 12, padding 4.
- **Options:** min height 44, radius 10. Selected option is white + `shadowSm` + textPrimary; others are transparent + textSecondary; 15 w600.
- **Semantics:** the group has `SemanticsRole.radioGroup`. Each option is `inMutuallyExclusiveGroup` + `checked`, with a tap action. This passes Flutter's radio-group role check.

### e) `TrustedDeviceSwitch` (`lib/features/auth/widgets/trusted_device_switch.dart`)
```dart
const TrustedDeviceSwitch({required bool value, required ValueChanged<bool>? onChanged}) // null = disabled
```
- **Layout:** slateSoft row, radius 12, padding 14/12.
- **Text:** « Faire confiance à cet appareil » (14 w600) + « À utiliser uniquement sur un appareil personnel. » (12 w500 textSecondary); `Switch` on the right.
- **Interaction:** the whole row is tappable. `MergeSemantics` announces one toggle with both texts.
- **Theme:** colours come from the new additive `switchTheme`: thumb white, track `primaryAction` when on, `borderStrong` when off.

### f) `OmniStepProgress` (`lib/core/widgets/omni_step_progress.dart`)
```dart
const OmniStepProgress({required int current, required int total, required String stepName}) // current is 1-based
```
- `total` segments: 4 px, radius 2, gap 6. Done/current segments are freshMint, the rest borderLight.
- Label `stepProgressLabel(current, total, name)` → « Étape 2 sur 3 · Identité » (13 w600 textSecondary). Read by screen readers as that one sentence.

### g) `GoogleBrandButton` (`lib/features/auth/widgets/google_brand_button.dart`)
```dart
const GoogleBrandButton({required VoidCallback? onPressed}) // the screen's existing Google handler
```
- **Look:** white fill, 1 px `_googleStroke` #747775, text `_googleText` #1F1F1F, radius 14, height 52, full width.
- **Content:** existing `assets/icons/google_logo.svg` at 20 px, unchanged and excluded from semantics. Label « Continuer avec Google » (`authContinueWithGoogle`).
- **Colours:** the two hex values are private named constants with a link to the guideline. They are the only hex literals added in P1.
- The web GIS button (`google_web_sign_in_button_web.dart`) is not touched.

## 3. ARB keys

No existing key had these texts, so there was nothing to reuse (grep on `app_fr.arb`; the current screens hardcode them). New keys, each with an `@` description as `l10n.yaml` requires:

| Key | French text | Used by |
|---|---|---|
| `authTrustDeviceTitle` | Faire confiance à cet appareil | TrustedDeviceSwitch |
| `authTrustDeviceSubtitle` | À utiliser uniquement sur un appareil personnel. | TrustedDeviceSwitch |
| `authContinueWithGoogle` | Continuer avec Google | GoogleBrandButton |
| `birthDatePickerTitle` | Date de naissance | picker |
| `birthDatePickerDay` / `Month` / `Year` | JOUR / MOIS / ANNÉE | picker |
| `birthDatePickerConfirm` | Valider | picker |
| `birthDatePickerClose` | Fermer | picker close tooltip |
| `stepProgressLabel` | Étape {current} sur {total} · {name} (int, int, String) | OmniStepProgress |

Texts the screen passes in (field labels, chip labels, the 18+ error, gender labels, eye-toggle tooltips) are not added in P1. P2 will move them to ARB where the screens use them.

## 4. Checks

- **`flutter analyze --no-pub`** on every created or edited file (7 widgets, `omni_theme.dart`, `lib/l10n/`): **No issues found.**
- **Throwaway render check** (kept in the session scratchpad, **not** added to the repo): 2/2 passed. It covered:
  - all 7 widgets at 360 px width and text scale 1.3, with no layout exception or overflow;
  - segment tap, switch row tap, radio-group semantics (checked, mutually exclusive);
  - picker French months, 31 Jan → février clamps to 29 (2008), « Valider » returns 2008-02-29;
  - a date after `lastDate` shows the error and disables « Valider »; « Fermer » returns `null`.
- **`flutter test` (full suite):** see §4.1.

### 4.1 `flutter test` output
**First run** (`flutter test --no-pub`): `+1945 ~7 -1`. The one failure was in my own new file:
```
test/l10n_arb_contract_test.dart: ARB ↔ code drift messages are only read as l10n / OmniLocalizations.of(context) [E]
  Expected: empty
    Actual: ['lib/core/widgets/omni_step_progress.dart: label']
```
The project rule is that `OmniLocalizations.of(context)` may only be assigned to a variable named `l10n`. I fixed `omni_step_progress.dart` to `final l10n = OmniLocalizations.of(context);` and re-ran:

```
02:31 +1946 ~7: 7 skipped tests.
02:31 +1946 ~7: All other tests passed!
exit=0
```
**1946 passed, 7 skipped, 0 failed**, including `test/auth_phase1_test.dart` and `test/l10n_arb_contract_test.dart`. The 7 skipped are the existing dead-population-flow tests (`auth_phase1_test.dart:3198-3370`), unchanged. The ARB contract test also confirms every new key is used and has a description.

## 5. Docs used
- `ListWheelScrollView.useDelegate`, `FixedExtentScrollController`, `FixedExtentScrollPhysics`: api.flutter.dev/flutter/widgets/ListWheelScrollView-class.html, …/FixedExtentScrollPhysics-class.html.
- Internationalization (ARB, `gen-l10n`, placeholders, `GlobalMaterialLocalizations` loading intl date data): docs.flutter.dev/ui/internationalization.
- Google custom button spec (white #FFFFFF, stroke #747775, text #1F1F1F, translated label allowed, « G » unchanged): developers.google.com/identity/branding-guidelines.
- Radio-group semantics: Flutter 3.41.2 SDK source `semantics.dart` `_semanticsRadioGroup` (role validation).

## 6. Deviations from the prompt (reported, not decided)
1. **`OmniTextField` has extra pass-through parameters:** `textInputAction`, `onFieldSubmitted`, `enabled`, `readOnly`, `onTap`, `inputFormatters`, `fieldKey`. The current screens use them (login submits on « done », sign-up's date field is `readOnly` + `onTap`, OTP/phone use formatters). Without them, P2 could not plug in unchanged.
2. **Segment height is a minimum** (`minHeight: 44`), not fixed, so labels at text scale 1.3 never clip.
3. **Picker sheet title** is 20 w700; the prompt gave no size.
4. **Generated l10n files** were regenerated (required by any ARB change; see Q1).

## 7. Open questions
1. `lib/l10n/omni_localizations*.dart` and `app_fr.arb` are still **untracked** (G-2 work, not committed). Another chat adding ARB keys at the same time could conflict on the final `}` of the ARB. Should ARB edits be serialised between G-2 and G-3?
2. **Disabled `GoogleBrandButton`** (`onPressed: null`, e.g. while login is loading) keeps the white fill. Its label falls back to the global outlined theme colour (slate). Should it show a dimmed brand look instead? Not specified.
3. **`PasswordRuleChip` states are only visual** (colour + icon). Screen readers hear the label only. Should we add ARB words such as « respecté » / « non respecté »?
4. **Month names** are lower-case (« janvier »), as intl returns them. Keep, or capitalise for display?
5. **Dates before `firstDate`** only disable « Valider », with no message. Is a text needed? With `firstDate = 1900-01-01` it cannot happen.
6. **Font:** the brand guideline names Google Sans Medium 14/20; the button uses the app font (Plus Jakarta Sans, theme outlined style 16 w700). Accept?
7. **Unselected `Switch` outline:** the theme sets no `trackOutlineColor`, so it uses the M3 default outline colour. Accept, or make it transparent?

## Path to deliver G-3
1. **P2a: welcome + bottom-sheet login.** Restyle `login_screen.dart` into the welcome screen and move `login_screen.dart:41-167` verbatim into `widgets/login_sheet.dart`. Use `OmniTextField`, `TrustedDeviceSwitch` and `GoogleBrandButton` (mobile), plus `locale: 'fr'` on the web GIS button. Restyle `google_account_link_sheet.dart`, keeping every pinned key and text.
2. **P2b: 3-step sign-up + review.** `OmniStepProgress`, `OmniTextField` (+ « +216 » segment for the phone), `PasswordRuleChip` (12–128 rule only), live confirm check (`isSuccess`), `showOmniBirthDatePicker` with the screen's 18+ limit, `OmniSegmentedChoice` for gender. Same `PhoneSignupDraft` and the same controller calls.
3. **CTO manual pass** on web + Android after each P2 (checklists in those reports). Then close the auth page in G-3 and move to the next page from the CTO's screenshots. Backend items stay parked (P0 §g).
