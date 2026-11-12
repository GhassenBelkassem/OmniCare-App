# G2 1b-3b: « Dossier médical »: temporary state behind a build switch

**Date:** 2026-11-11 · **Repo:** OmniCare-App · **Approved exception:** the CTO allowed this temporary UI change to "UI unchanged".

## 1. Goal card and status

> GOAL G-2: Connect the patient Flutter app to the real backend without changing the current UI, with a report at every step.
> Done when every patient screen reachable from production main.dart shows real data or an honest "indisponible" state (no fixture, no mock), the release build passes the G-2 gate (§8), and every step has a report in OmniCare-App/docs/reports/G2/.

| Item | Status |
|---|---|
| Build switch `MEDICAL_RECORD_LIVE` (`--dart-define`), default off, read in one place | ✅ `lib/features/patient_passport/medical_record_switch.dart` |
| Switch off: the tab stays visible; header and identity from the real profile and family; G-1's share and secure-QR actions unchanged; one temporary message below; no pencil | ✅ |
| 180/78 defaults removed | ✅ |
| « Sarah Ben Ahmed » fixture unreachable from patient code, covered by the guard | ✅ (proven by a failing run) |
| Fixture file kept: `lib/features/doctor/**` (G-1) still imports it | ✅ reported (§5) |
| Logic tests; analyze; test | ✅ (§4) |

## 2. What the patient sees (switch off: every release build)
« Dossier médical » tab, top to bottom:
1. **Header row** (`passport_header.dart`): « Passeport médical · {real name} » with the family selector. The share icon (G-1's sharing settings) is unchanged. **No edit pencil.**
2. **Identity card** (`passport_identity_card.dart`), which holds G-1's « Afficher le QR »: real name, the account holder's phone and e-mail. « ID OMNICARE » reads « Non renseigné », because no real OmniCare ID exists (§5).
3. **One card** with « Votre dossier médical n'est pas encore disponible dans l'application. ». It uses this screen's existing empty-state style: a `PassportCard` with centered text, as in the history tab's « Aucune consultation trouvée. ».

The section tabs (Résumé, Historique, Documents) and every medical card are not shown.

« Mon QR sécurisé » is in the identity card, not in the header row. That's why the identity card is kept visible, as part of "the header".

**Family selector:** the account holder (« Mon passeport ») plus the real family members from `FamilyProvider`. Avatars are the app's neutral illustrated avatars, chosen by the same rule as the request flow (`care_subject_card.dart`). The fixture used stock photos of doctors.

## 3. What changed

| File | Change |
|---|---|
| `features/patient_passport/medical_record_switch.dart` | **New.** `const bool medicalRecordLive = bool.fromEnvironment('MEDICAL_RECORD_LIVE')`: the only read |
| `features/patient_passport/application/passport_identity.dart` | **New.** Members, selection, record subject and identity, from `PatientProfile` and `FamilyMember` only |
| `features/patient_passport/presentation/patient_passport_screen.dart` | No fixture import. Identity from `UserProvider`/`FamilyProvider`. Switch off → identity and one message. Pencil never passed. The local-only editor path (`_openMedicalDataEditor`) removed |
| `features/patient_passport/presentation/widgets/passport_header.dart` | `onEdit` is optional; the pencil is hidden when it is null |
| `features/patient_passport/models/patient_passport_view_models.dart` | `heightCm`/`weightKg` are now `double?` with **no default** (was 180/78); `PatientPassportViewData.identity(...)` added |
| `features/patient_passport/data/patient_passport_static_data.dart` | Explicit `heightCm: 180, weightKg: 78`, so the doctor preview that still reads this fixture is unchanged |
| `features/patient_passport/presentation/medical_data_editor_screen.dart` | Null-safe measurements (an empty field, no default). The screen is no longer reachable (pencil hidden) and is kept for Phase 3 |
| `l10n/app_fr.arb` (+ generated) | `passportRecordNotYetAvailable`, `passportSelfRelationship`, `medicalRecordNotRecorded` |
| `test/production_mock_import_guard_test.dart` | `toRemoveIn1c` is now **empty**. New: "the fixture is not reachable from patient code"; "doctor-side static data is exactly the reported one" (pins the fixture as doctor-only) |
| `test/patient_passport_screen_test.dart` | **Deleted.** Its three widget tests asserted the fixture itself (« Metformine », « Sarah », the pencil editor), which this step removes. The CTO rule forbids new widget tests, so the behaviour is covered by logic tests (`test/medical_record_test.dart`) and the guard |
| `test/p5_06_patient_qr_test.dart` | G-1's two passport QR tests kept: added localization delegates, and the family test opens the selector from the header arrow instead of tapping « Sarah Ben Ahmed » |

## 4. Evidence
- **Guard proof:** with `import '../data/patient_passport_static_data.dart'` temporarily added to the passport screen, 3 guard tests failed and printed the chain `…static_data.dart <- …patient_passport_screen.dart <- …new_home_screen.dart <- lib/main.dart`. After restoring the file, 9/9 pass.
- **Logic tests** (`test/medical_record_test.dart`, shared with FT-3):
  - the switch is off by default, and with it off no request is made;
  - members and identity come only from the profile and family, with no « Sarah »;
  - missing values read « Non renseigné »;
  - avatars are neutral, never stock photos;
  - a removed family member falls back to the holder.
- `flutter analyze`: 388 issues, the same set as the baseline (diff empty).
- `flutter test` (full, same run as FT-3): 1946 passed, 7 skipped, 0 failed.

## 5. Findings and decisions to know
1. **The fixture is kept.** `lib/features/doctor/medical_record/doctor_medical_record_access.dart:2,123` (`fullDemo`, G-1) imports it. It is reachable from `main.dart` only through doctor code, and the guard pins that. G-1 can delete it once `fullDemo` stops using it.
2. **No real OmniCare ID.** The profile has none, and the only other values in the app are fixtures (`OMNI-12345` here, `OMNI-SARAH` in `patient_home_feed.dart`), so the row reads « Non renseigné ». Decide whether the row stays, or gets a real ID later.
3. **Family identity card:** phone and e-mail are the account holder's, as before; family members have no contact of their own.
4. **Screenshot protection** (FLAG_SECURE) is on only with the switch on: with it off, the screen shows no medical data.

## 6. Manual test steps for the CTO (switch off: a normal build, no `--dart-define`)
1. Start the app against your local backend and log in as a test patient who has at least one family member.
2. Open « Dossier médical ». The header reads « Passeport médical · {your name} », never « Sarah Ben Ahmed », and has no pencil icon.
3. The identity card shows your name, phone and e-mail, and « ID OMNICARE » reads « Non renseigné ».
4. Below it there is exactly one card: « Votre dossier médical n'est pas encore disponible dans l'application. ». There are no Résumé / Historique / Documents tabs, and no medication, measurement (no 180 cm / 78 kg) or consultation.
5. Tap « Afficher le QR »: your secure QR opens as before. Close it.
6. Tap the share icon: the sharing settings sheet opens as before. Close it.
7. Tap your name in the header: the selector lists « Mon passeport » and your real family members, with illustrated avatars (no doctor photos). Pick a family member: the header and the identity card show their name, and the QR and sharing work for them. Switch back to yourself.
