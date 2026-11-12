# G3-ONB1 — Onboarding building blocks (pure UI)

These are the visual building blocks for the approved onboarding redesign. Values and callbacks come from the screen; the widgets hold no business rule, provider, service or network call. **No screen uses them yet.**

No screen, provider, controller, `onboarding_progress.dart`, `onboarding_basics_payload.dart`, `UserOnboardingProvider`, `AccountApi`, `medications_api.dart`, route or global theme was changed. No git command was run.

Every widget:
- has one widget per file (plus its small data class) and `const` constructors;
- wraps every tappable in `OmniPressable` (InkWell or Material button with the shared `statesController` and `OmniPressable.overlay`);
- uses the bundled font `'Plus Jakarta Sans'` at weights ≥ 500 and Omni tokens only (no `Color(0x…)` literal);
- has touch targets ≥ 44 px and no `print`/`debugPrint`.

## 1. Files and public APIs

| File | Public API |
|---|---|
| `lib/features/onboarding/widgets/onboarding_frame.dart` | `OnboardingFrame({required double progress, required String title, required Widget child, required String primaryLabel, required VoidCallback? onPrimary, String? subtitle, VoidCallback? onBack, VoidCallback? onSkip, bool primaryEnabled = true, double? previousProgress})` |
| `lib/core/widgets/omni_option_row.dart` | `OmniOptionRow({required String label, required IconData icon, required bool selected, required VoidCallback? onTap})` · `OmniOption<T>({required T value, required String label, required IconData icon})` · `OmniOptionGroup<T>({required List<OmniOption<T>> options, required T? value, required ValueChanged<T>? onChanged, String? semanticLabel})` |
| `lib/core/widgets/omni_choice_tile.dart` | `OmniChoiceTile({required String label, required bool selected, required VoidCallback? onTap})` · `OmniChoiceTile.wide(...)` (same parameters, full width) |
| `lib/core/widgets/omni_number_wheel.dart` | `OmniNumberWheel({required int min, required int max, required int? value, required String unit, required ValueChanged<int> onChanged, required int initialPosition, String? semanticLabel})` |
| `lib/core/widgets/omni_weight_ruler.dart` | `OmniWeightRuler({required int min, required int max, required double? value, required String unit, required ValueChanged<int> onChanged, required int initialPosition, String? semanticLabel})` |
| `lib/features/onboarding/widgets/profile_summary_card.dart` | `ProfileSummaryCard({required String fullName, required List<ProfileSummaryRow> rows, String? subLabel, VoidCallback? onEdit})` · `ProfileSummaryRow({required String label, required String value})` |
| `lib/features/onboarding/widgets/onboarding_note.dart` | `OnboardingNote({required String title, required String body, IconData icon = Icons.info_outline_rounded})` |
| `lib/features/onboarding/widgets/onboarding_summary_list.dart` | `OnboardingSummaryList({required List<OnboardingSummaryItem> items})` · `OnboardingSummaryItem({required String label, required String value, VoidCallback? onEdit})` |

**Behaviour notes**

- **OnboardingFrame:**
  - White Scaffold, content width capped at 480 with a 20 px side gutter.
  - Top row:
    - Back is a 44 px `slateSoft` circle with tooltip « Retour », hidden when `onBack` is null.
    - The thin bar is 4 px, radius 2, `borderLight` track and `deepTeal` fill. It animates its width over 450 ms with `easeOut` from the current value, or from `previousProgress` on the first build. There is no animation with reduced motion. Semantics: « Progression », value « 40 % ».
    - « Passer » is `textSecondary` 14 w600, hidden when `onSkip` is null.
  - Content: title 28 w800 (ls −0.6, header semantics), subtitle 15 w500, then `child`.
  - Pinned button:
    - `primaryAction`, radius 14, height ≥ 52, full width, 16 w700 label, haptic on tap.
    - A 32 px white fade sits above it.
    - `primaryEnabled: false` gives the `borderLight` background and `textTertiary` label, and the button is not tappable.
  - The Scaffold resizes for the keyboard, so the button stays above it.
- **OmniOptionRow / OmniOptionGroup:**
  - Row: min height 64, radius 14, 1 px `borderLight`. When selected: `deepTeal` border + 1 px ring (spread shadow) + `mintSoft` fill, and the 36 px icon tile turns from `slateSoft` to white.
  - Label 16 w600, 22 px radio (ring + 10 px dot).
  - Group: `SemanticsRole.radioGroup` with each row checked/unchecked in a mutually exclusive group. `HapticFeedback.selectionClick` plays only when the value actually changes.
- **OmniChoiceTile:**
  - Min height 68, radius 14, 20 w800 label, same selected style as the row.
  - An 18 px `deepTeal` check badge (white check) sits top-right when selected.
  - Radio semantics per tile: the screen wraps the grid in a `radioGroup`.
- **OmniNumberWheel:**
  - `ListWheelScrollView.useDelegate` with `FixedExtentScrollController`, itemExtent 56, 5 rows (280 px), a `mintSoft` band with radius 14 behind the centre row, and 72 px white fades at the top and bottom.
  - Readout: 56 w800 value + unit 20 w700 `textSecondary`.
  - **Null rule:**
    - With `value == null` the readout shows « — », no row is styled as selected, and the wheel rests on `initialPosition`.
    - Placing the wheel (first build, or a new `value` from the screen) never calls `onChanged`.
    - A user drag calls it for each row crossed, with a haptic. A drag that ends on the same row still picks it.
    - Tapping a row picks it and animates to it.
  - Screen readers get one slider: value « 170 cm » / « Non renseigné », increase and decrease actions.
- **OmniWeightRuler:**
  - One tick per unit, 12 px apart; every 5th medium, every 10th long with a 12 w600 label. `deepTeal` 3 px centre indicator, 48 px side fades.
  - Readout: 64 w800 value + unit 20 w700.
  - Snapping:
    - The ruler snaps to whole units and `onChanged(int)` fires for each unit crossed, with a haptic. After release it aligns exactly on the unit.
    - A decimal `value` (typed in a fallback field) shows with one French decimal (« 68,5 ») and places the ruler at that point.
  - Same null rule as the wheel. Slider semantics with one-unit actions.
- **ProfileSummaryCard:**
  - Initials avatar (56 px, `mintSoft`, `deepTeal` 20 w800, up to 2 letters), full name 18 w700, optional sub-label.
  - « Modifier » (44 px target, announced « Modifier : <nom> », hidden when `onEdit` is null).
  - Rows are 12 w500 / 15 w600, separated by `borderLight` lines, each row merged for screen readers.
- **OnboardingNote:** `mintSoft` box with radius 16, info icon, title 15 w700 + body 14 w500 in `deepTeal`, `SemanticsRole.status`.
- **OnboardingSummaryList:** a card of label/value rows with an optional « Modifier » per row (announced « Modifier : <label> »).

## 2. ARB keys (5, appended at the end of `app_fr.arb` by a direct edit, after re-reading the file)

| Key | Text | Used by |
|---|---|---|
| `onboardingSkip` | Passer | frame |
| `onboardingProgressLabel` | Progression | frame (bar semantics) |
| `commonEdit` | Modifier | profile card, summary list |
| `commonEditItem` | Modifier : {item} | « Modifier » semantics |
| `pickerNoValue` | Non renseigné | wheel/ruler semantics while null |

Reused: `authBack` (« Retour ») for the back tooltip.

## 3. Checks

- `flutter gen-l10n`: OK.
- `flutter analyze` on the 8 new files + `lib/l10n`: **No issues found**.
- `test/l10n_arb_contract_test.dart`: all passed.
- Full `flutter test` (exit 0): `01:30 +1971 ~7: All tests passed!` → **1971 passed, 7 skipped, 0 failed.** The total is above P2c's 1946 because of other chats' tests.
  - This run came before the last edit, which only replaced 3 transparent-white gradient ends with `OmniColors.surfacePrimary.withValues(alpha: 0)`.
  - After that edit: analyze is clean, and the contract test plus the throwaway checks pass (+16).
- **Throwaway checks:** 6/6, in the scratchpad, copied into `test/` only for the run and then deleted. No new repo tests, as instructed.
  - Wheel and ruler:
    - « — » and no callback on the first build;
    - a programmatic value change makes no callback and updates the readout (« 68,5 »);
    - a drag of 2 rows gives 182; a ruler drag gives a whole unit;
    - a tiny drag on a null wheel picks 170;
    - slider semantics are correct.
  - Option group: tap selects; checked, mutually exclusive semantics; height ≥ 64.
  - Frame at 360×640, text scale 1.0 and 1.3, with every widget inside:
    - no overflow, scrolled to the end and with the keyboard (260 px);
    - back and « Passer » ≥ 44 px, button ≥ 52 px;
    - the button stays hit-testable with the keyboard;
    - progress semantics « 40 % »;
    - back and « Passer » hidden when their callbacks are null;
    - a disabled button is not tappable.
  - Progress: 0.2 → 0.6 in 450 ms; reduced motion jumps straight to the value.

## 4. Deviations and choices (reported)

1. **`previousProgress` added to the frame** (not in the spec). If each onboarding page builds its own frame, a new instance has no "previous value", so the bar could not animate from the last page without it. It is optional; when absent, nothing animates on the first build.
2. **Disabled main button is not tappable.** See Q1: today's screen validates on tap and shows the error.
3. **Haptic on the main button** (`OmniPressable.withHaptic`), as on sign-up. The choice tile has no haptic of its own, since the spec lists haptics only for b, d and e. The screen can add it.
4. **Wide choice tile:** same min height 68 and 20 w800 label as the grid tile (the spec gives no separate size).
5. **Selection ring:** drawn as a 1 px spread `BoxShadow` outside the 1 px border.
6. **Wheel/ruler semantic actions while null:** « increase / decrease » start from `initialPosition` ± 1.
7. **`commonEdit`** has the same text as the existing `signupEdit`. A neutral key was added rather than reusing a sign-up-named key outside sign-up.

## 5. Open questions

1. **Disabled main button:** keep it not tappable, or tappable with the disabled look so the screen can show which field is missing? Today the onboarding validates on « Continue ».
2. **Saving state:** the frame has no loading spinner on the main button. Today the screen covers itself with a full spinner overlay while saving. Add `primaryLoading` to the frame in ONB-2, or keep the overlay?
3. **Ranges and resting positions:** min, max and `initialPosition` for height and weight (see P0 Q6). They are passed by the screen and are REQUIRES MEDICAL VALIDATION.
4. **Ruler step:** whole kg only (as specified, `onChanged(int)`), with decimals only from the type-in fallback. Is 0.1 kg on the ruler wanted later?
5. **Option-row icons** for Oui / Non / Je ne sais pas: they are chosen by the screen; the design needs to name them.

## Path to deliver G-3

1. **CTO:** answer Q1–Q5 above, plus the onboarding P0 questions (Q1–Q10, especially Q9 on file ownership with G-2.1 A3, and the parked « Je ne sais pas » / « Passer » choices).
2. **ONB-2:** UI-only restyle of `conversational_onboarding_screen.dart` and `onboarding_complete_screen.dart` using these blocks.
   - Same `PageView`, same 5 pages and order, same controllers, validators, payloads and save calls.
   - The « Je ne sais pas » blood-type tile text stays (`blood_type_and_medical_save_test.dart:330-365`).
   - English strings go to the ARB.
   - Parked items are hidden or disabled.
3. **CTO manual pass** on web and Android with a new test account, then close the onboarding page.
4. **Next G-3 page** from the CTO's screenshots.
