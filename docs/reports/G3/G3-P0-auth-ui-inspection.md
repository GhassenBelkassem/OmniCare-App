# G3-P0 — Patient login & sign-up UI inspection (read-only)

Date: 2026-11-11 · Repos: OmniCare-App (read), OmniCare-BackEnd (auth module, read) · No source, config, test or build file changed.
All paths are relative to `OmniCare-App/` unless prefixed `BE:` (= `OmniCare-BackEnd/src/main/java/com/omnicare/app/`).

## 0. Plan (as executed)

- **Entry files (found with grep on `auth|login|regist|sign|password|otp|verif|splash|theme`):** `lib/features/auth/*.dart`, `lib/core/auth/google_web_sign_in_button*.dart`, `lib/core/theme/omni_theme.dart`, `lib/main.dart` (routes only).
- **Folders read:** `lib/features/auth/{application,data,data/models}`, `lib/core/config/app_environment.dart`, `lib/core/network/api_failure_message.dart`, `lib/core/device/device_identity_service.dart` (grep only), `lib/l10n/app_fr.arb` (auth keys), `pubspec.yaml`/`pubspec.lock`, `web/index.html` (Google tags, client id masked), `test/auth_phase1_test.dart`, `docs/roadmap/G2_Patient_Flutter_Roadmap.md` §Phase 2.
- **Spring:** `BE:auth/api/AuthController.java`, `auth/api/dto/{LoginRequest,SignupCompleteRequest,GoogleInitiateRequest,ChangePasswordRequest,PhoneRequest}.java`, `auth/application/{PhoneSignupService,LoginService,DeviceManagementService,GoogleAuthService}.java` (relevant methods), `auth/entity/UserDevice.java`, `auth/config/GoogleOAuthProperties.java`, `shared/error/ErrorCode.java`.
- **Tracing:** followed `import` lines from each screen → controller → repository → API → DTO; matched each HTTP path to its `@PostMapping`.
- **Skipped (out of scope):** `professional_access_request_screen.dart` (pro flow, only linked from login); `post_auth_navigation.dart` imports into emergency/request modules (not read beyond the routing function); `UserOnboardingProvider` (phone input only calls `setPhoneNumber`); doctor/consultation/medical record.
- `flutter analyze lib/features/auth lib/core/auth lib/core/theme`: **6 issues, 0 errors**. Four are `withOpacity` deprecations in orphan screens (`email_input_screen.dart:189`, `forgot_password_screen.dart:187`, `language_selection_screen.dart:139,146,180`), plus one unused local (`forgot_password_screen.dart:50`). It ran an implicit `pub get`; `pubspec.lock` is unchanged (mtime Nov 9).

---

## a) Screen map

| # | Screen | File:line | Route | Controller | Repository → API | HTTP | Spring method | Platforms |
|---|---|---|---|---|---|---|---|---|
| 1 | Splash | `lib/features/auth/splash_screen.dart:8` | `home:` (`main.dart:411`), then `pushReplacementNamed('/login')` (`:44`) | `AuthController.initialize` (`auth_controller.dart:101`) | `restoreSession` (`auth_repository.dart:310`) → `/auth/me`, `/profile` | GET `/api/v1/auth/me` | `AuthController.currentUser` (BE `:97`) | Android / iOS / web |
| 2 | Login (email + password) | `login_screen.dart:19` | `/login`, `/auth-entry`, `/professional-login` (`main.dart:416-418`) | `loginWithEmailPassword` (`auth_controller.dart:155`) | `auth_repository.dart:244` → `auth_api.dart:38` | POST `/api/v1/auth/login` | `login` (BE `AuthController.java:81`) | A / iOS / web |
| 3 | Google button (inside 2 and 5) | `login_screen.dart:356`, `signup_screen.dart:566` | – | `startGoogleAuth` (`:196`) | `auth_api.dart:58` | POST `/auth/google/initiate` | `googleInitiate` (BE `:285`) | web = GIS button; A/iOS = `google_sign_in` (see e) |
| 4 | Google account-link sheet | `google_account_link_sheet.dart:11` | modal from `login_screen.dart:105` only | `linkGoogleAccount` (`:252`) | `auth_api.dart:88` | POST `/auth/google/link` | `googleLink` (BE `:315`) | A / iOS / web |
| 5 | Sign-up (patient) | `signup_screen.dart:16` | no name; pushed from `login_screen.dart:375` | none: builds `PhoneSignupDraft` (`:193-200`) | – | – | – | A / iOS / web |
| 6 | Phone input (sign-up step 2, phone login, Google sign-up) | `phone_input_screen.dart:13` | pushed (`signup :203`, `login :159`, `login :131`) | `startPhoneSignup` `:324` / `startPhoneLogin` `:129` / `startGooglePhoneSignup` `:298` | `auth_api.dart:16,24,34,68,78` | POST `/auth/signup/phone/initiate` (OTP on) or `/auth/signup/complete` (OTP off); `/auth/login/phone/initiate`; `/auth/google/phone/initiate` or `/auth/google/complete` | BE `:195`, `:227`, `:380`, `:301`, `:340` | A / iOS / web |
| 7 | OTP verification | `otp_verification_screen.dart:11` | pushed (`phone_input :84`, `login :68`) | `verifyPhoneLoginOtp` `:273`, `verifyPhoneSignupOtp` `:352`, `resendOtp` `:390` | `auth_api.dart:20,48,74` | POST `/auth/login/phone/verify`, `/auth/signup/phone/verify` (then `/signup/complete`), `/auth/google/phone/verify` (then `/google/complete`) | BE `:258`, `:216`, `:327` | only when `OMNICARE_PHONE_VERIFICATION_ENABLED=true` (default **false**, `app_environment.dart:19-22`) |
| 8 | Forced password change | `reset_password_screen.dart:8` | `/change-password-required` (`main.dart:442`) | `changeRequiredPassword` (`:444`) | `auth_api.dart:108` | POST `/auth/password/change` | `changePassword` (BE `:113`) | A / iOS / web |
| 9 | Forgot password | `forgot_password_screen.dart:5` | **none; nothing navigates to it** (grep) | none | none (fake 2 s delay, `:31-45`) | – | **MISSING** (no reset endpoint in `BE:auth/api`) | – (unreachable) |
| – | Orphans (no caller, grep) | `email_input_screen.dart`, `population_selection_screen.dart`, `language_selection_screen.dart`, `medical_data_welcome_screen.dart` | none | – | – | – | – | unreachable |

---

## b) Current theme, as built

**Material 3 enabled** (`omni_theme.dart:359`). **Light only**: `Brightness.light` (`:325`) and no `darkTheme`/`themeMode` in `main.dart:410`. App locale is fixed to `fr` (`lib/core/l10n/app_locale.dart:8`, `main.dart:390`).

### Color tokens (`lib/core/theme/omni_theme.dart`)
| Token | Hex | Line | Role |
|---|---|---|---|
| freshMint | #1FBF9A | 32 | brand / selection / success; also `colorScheme.primary` (330) |
| mintSoft | #EDFBF6 | 35 | selected surface |
| primaryAction | #0F826D | 48 | primary CTA background |
| primaryActionPressed | #0C6F5F | 51 | CTA pressed |
| deepTeal | #176B5B | 56 | links / text on light |
| deepTealHover | #12594C | 58 | |
| deepTealActive (= textOnMint) | #0D473D | 61, 171 | text on mint, checkbox tick |
| infoBlue / Strong / Soft | #2563EB / #1D4ED8 / #EFF6FF | 68, 71, 74 | info (phone/OTP icon tile) |
| clinicalCyan / Soft | #0E7490 / #ECFEFF | 81, 84 | |
| violet / Soft | #6941C6 / #F4F3FF | 92, 95 | identity (reset-password icon tile) |
| amber / Soft | #B54708 / #FFFAEB | 103, 106 | warning |
| urgentCoral / Soft | #C4320A / #FFF4ED | 114, 116 | |
| error / errorSoft | #D92D20 / #FEF3F2 | 123, 126 | errors |
| slateBlue / slateSoft | #294B63 / #F2F7FA | 134, 137 | outlined buttons, neutral surfaces |
| pageBackground / surfacePrimary | #FFFFFF | 144, 146 | canvas |
| surfaceSecondary | = slateSoft | 152 | |
| textPrimary / Secondary / Tertiary / Disabled | #1D2939 / #667085 / #98A2B3 / #D0D5DD | 158-164 | |
| borderLight / borderStrong / borderFocus | #E4E7EC / #D0D5DD / = freshMint | 177-182 | |
| shadowSm / Md / Card / Search | 0x0A000000 b8 y2 / 0x0F000000 b14 y4 / 0x140F172A b18 y6 / 0x0F0F172A b14 y4 | 205-235 | none used in auth screens |

**Hardcoded colors in reachable auth screens:**
- `splash_screen.dart`: `:57` #F4F5F7 (no token; canvas token is white), `:72` #1FBF9A, `:81` #667085, `:89` #475467 (no token), `:100` and `:106` #1FBF9A.
- `login_screen.dart:326` and `signup_screen.dart:300`: `Colors.white` (spinner). `signup_screen.dart:686`: `Colors.white` (gender card).
- Orphan `forgot_password_screen.dart`: #101828 (`:59,102`), #F0FDF9 (`:76`), #1FBF9A (`:89,154,182`), #667085, #1D2939, #9CA3AF (`:139`, ≠ textTertiary), #E5E7EB (`:145`, ≠ borderLight), #DC2626 (`:160`, ≠ error #D92D20).
- Other orphans (email/language/population/medical_data_welcome) are hardcoded the same way.

### Typography
- **Family:** `GoogleFonts.plusJakartaSansTextTheme(ThemeData.light().textTheme)` (`omni_theme.dart:349-356`), with body/display color set to textPrimary.
- **Bundled weights:** Plus Jakarta Sans 500/600/700/800 (`pubspec.yaml:117-126`). **Weight 400 is not bundled**, yet M3 body styles default to w400 and `forgot_password_screen.dart:111,131` uses w400 explicitly. Whether google_fonts fetches 400 at runtime or falls back is UNVERIFIED (app not run).
- **Sizes and weights used in auth:**
  - Page title 26/w800/ls −0.4 (`login :203-208`, `signup :247-252`); 24/w800/−0.3 (`phone_input :160`, `otp :178`, `reset_password :164`).
  - Subtitle `bodyMedium` 14/h1.45 textSecondary (`login :214`, `signup :258`).
  - Checkbox label 13/w600 (`login :311`) vs 14/w600 + 12 subtitle (`signup :531-541`).
  - Links 14, action w700 deepTeal (`login :401-412`); terms 13/h1.6 textTertiary + deepTeal (`signup :587-616`); hint 12 (`signup :478`).
  - OTP digits 19/w700 (`otp :212`); link-sheet title 21/w700 (`google_account_link_sheet :99`).
- **Component text:** buttons 16/w700/ls −0.1 (`omni_theme.dart:294-300, 442-448`), AppBar title 18/w700 (`:385-391`), TextButton 14/w600 (`:459-463`), input hint 15 (`:479`), chips 13/w600 (`:616`).
- **TextTheme mapping:** screens pick `headlineSmall` / `bodyMedium` / `bodySmall` / `titleMedium` / `titleLarge` and override the size on each use, so no custom TextTheme scale exists.

### Shape and elevation
| Element | Value | Where |
|---|---|---|
| Inputs | radius 12 (`OmniRadii.field`); border 1 px borderLight; focus freshMint 1.75; error #D92D20 (1 / 1.75) | `omni_theme.dart:496-519` |
| Elevated/Filled button | radius **14 literal** (no token), min height 50, full width, elevation 0 | `:264-303` |
| Outlined button | radius 14, 1.25 px borderStrong, slate text, white fill | `:414-451` |
| Checkbox | radius 4, mint fill, deepTealActive tick | `:554-568` |
| Cards | 16 / 20 tokens (`OmniRadii.card`, `cardLarge`) | `:254-255` |
| Bottom sheet | top radius 24 (`OmniRadii.sheet`), drag handle on, barrier #59000000, elevation 0 | `:573-590` |
| Dialog | radius 20, elevation 8 | `:595-604` |
| Pill | `OmniRadii.pill = 999` exists, unused in auth | `:257` |
| AppBar | elevation 0, white, left title | `:378-392` |

### Spacing
- **Scale:** `OmniSpacing` xs 4 / sm 8 / md 12 / base 16 / lg 20 / xl 24 / xxl 32 / xxxl 40, pageHorizontal 20, pageVertical 24 (`omni_theme.dart:238-250`).
- **Auth screens:**
  - Login: padding h20 v24, maxWidth 420 (`login :177-182`).
  - Sign-up, phone, OTP, reset: LTRB 20/24(or 20)/20/32, maxWidth 480 (`signup :234-241`, `phone_input :124-131`).
  - Off-scale literals in sign-up: 14 (`:334,362,393,441,483,512`), 18 (`:273,276,278`), 6 (`:475`), 12 (`:502,551`).
  - Input content padding h16 v14 (`omni_theme.dart:474-477`).

### Shared components used by auth
- There is **no `AppButton` or `AppTextField`**. Screens use raw Material widgets styled by the theme:
  - `ElevatedButton` (primary), `OutlinedButton` (secondary, slate), `TextButton` (deepTeal)
  - `TextFormField` with `inputDecorationTheme` (floating `labelText` + prefix icon)
  - `CheckboxListTile`, `Divider`
- `lib/core/widgets/` holds only `medication_search_field.dart`.
- **Private, duplicated helpers:**
  - `_decoration` (`login :335`) and `_inputDecoration` (`signup :64`)
  - `_divider` (`login :340`) and `_buildDividerOr` (`signup :546`)
  - `_link` (`login :387`), `_GenderCard` (`signup :653`), `_PasswordField` (`reset_password :244`)
- `GoogleWebSignInButton` (`lib/core/auth/google_web_sign_in_button_web.dart:96`).
- **Bottom sheet:** the theme exists, and `showModalBottomSheet` is used once (Google link, `login :105`).
- **Date picker:** Material `showDatePicker` (`signup :460`) with no `datePickerTheme`. No wheel or Cupertino date picker in auth. The only wheel/Cupertino usage is in `patient_request_detail_screen.dart` (out of scope, not inspected).
- No `switchTheme`. `SegmentedButton`/`SwitchListTile` appear in other features (`add_family_member_screen.dart`, `patient_profile_screen.dart`, not inspected).

---

## c) Form fields and validation

No auth form sets `autovalidateMode` (grep). Validators run only on submit, or when the whole form is re-validated after a date is picked (`signup :471`).

### Login (`login_screen.dart`) vs `BE:auth/api/dto/LoginRequest.java`
| Field | Widget | Dart validator | French text | Spring rule | Mismatch |
|---|---|---|---|---|---|
| E-mail | TextFormField (`:263`) | `:269-275` regex `^[^@\s]+@[^@\s]+\.[^@\s]+$` | « Adresse e-mail requise » / « Saisissez une adresse e-mail valide » | `identifier` `@NotBlank @Size(max=255)` (`:7-9`), no `@Email` | No (Flutter stricter; it has no 255 cap). Sent trimmed and lower-cased (`auth_repository.dart:252`) |
| Mot de passe | TextFormField (`:278`) | `:297-298` empty only | « Mot de passe requis » | `@NotBlank @Size(max=128)` (`:11-13`) | Minor yes: a whitespace-only password passes Flutter and fails `@NotBlank`, showing « Veuillez vérifier les informations saisies. » |
| Faire confiance à cet appareil | CheckboxListTile (`:300`) | – | – | `Boolean rememberDevice` (`:20`) | see below |

### Sign-up (`signup_screen.dart`) vs `BE:auth/api/dto/SignupCompleteRequest.java` + `PhoneSignupService.java`
| Field | Widget | Dart validator | French text | Spring rule | Mismatch |
|---|---|---|---|---|---|
| Adresse e-mail | TextFormField (`:317`) | `:326-332` same regex | « Champ requis » / « Adresse e-mail invalide » | `@NotBlank @Email @Size(max=255)` (`:30-33`) | Low: the Flutter regex differs from Bean Validation `@Email`; no max in Flutter |
| Mot de passe | TextFormField (`:335`) | `:354-360` length only | « Champ requis » / « Utilisez au moins 12 caractères » / « Utilisez 128 caractères maximum » | `@Size(min=12,max=128)` (`:35-37`) + HIBP breach check (`PhoneSignupService.java:172`) | No on length. Neither side has composition rules. A breached password returns `AUTH_PASSWORD_COMPROMISED` → « Ce mot de passe est compromis. Choisissez-en un autre. » |
| Confirmer le mot de passe | TextFormField (`:363`) | `:384-391` | « Champ requis » / « Les mots de passe ne correspondent pas » | client-only | Checked **only on submit** (`:163`) or after picking a date (`:471`). Not live |
| Prénom | TextFormField (`:396`) | `:403-407` trim non-empty | « Champ requis » | `@NotBlank @Size(1..100)` (`:11-13`) + trimmed ≤100 (`PhoneSignupService.java:302-304`) | **Yes**: no 100-char max in Flutter |
| Nom | TextFormField (`:409`) | `:416-420` | « Champ requis » | `:15-17` + `PhoneSignupService.java:305-307` | **Yes** (max 100) |
| Date de naissance | read-only TextFormField + Material `showDatePicker` (`:442-473`). Range 1900-01-01 → today, initial Jan 1 of (now − 20). Shown as `dd/MM/yyyy` (`:45-50`), sent as `yyyy-MM-dd` (`auth_flow_models.dart:42-52`) | `:449-455` + `_isAtLeast18` local time (`:52-62`) + snackbars (`:175-191`) | « Champ requis » / « Vous devez avoir au moins 18 ans »; snackbars « Sélectionnez votre date de naissance. », « Vous devez avoir au moins 18 ans pour créer un compte. » | `@NotNull @Past` (`:19-21`); service: `Period` < 18 years **in UTC** → `INVALID_INPUT` (`PhoneSignupService.java:308-309`) | **Yes**: (1) Flutter maps `INVALID_INPUT` to « Veuillez choisir un nouveau mot de passe différent. » (`auth_error_messages.dart:64`, `app_fr.arb:607`), so a server age rejection shows a password message. (2) Flutter checks age in local time, the server in UTC: around midnight Tunis on an 18th birthday the two disagree. (3) The picker allows under-18 dates and rejects them afterwards. French month names in the Material picker are expected from locale `fr` (UNVERIFIED, app not run) |
| Genre | `_GenderCard` × 2, values `M`/`F` (`:493-511`) | submit check (`:168-173`) | « Sélectionnez votre genre. » | `@NotBlank @Size(max=10)` (`:23-25`); service normalizes and accepts **`M`, `F`, `autre`** (`PhoneSignupService.java:311-322`), else `INVALID_INPUT` | Partial: the server supports « autre », Flutter offers 2 options. An invalid value would show the wrong password message (same mapping as above) |
| Téléphone (next screen) | TextFormField `+216` prefix (`phone_input_screen.dart:182-198`) | `:40-50` → `TunisianPhoneNumber.normalize` (`tunisian_phone_number.dart:13-28`) | **English**: « Phone number is required » / « Enter exactly eight Tunisian phone digits. » | `PhoneRequest` `@Pattern ^\+216[0-9]{8}$` (`PhoneRequest.java:10`); `SignupCompleteRequest.phone` `@NotBlank` (`:27-28`) | Format matches; **text is English** |
| Faire confiance à cet appareil | CheckboxListTile + subtitle « À utiliser uniquement sur un appareil personnel. » (`:518-543`) | – | – | `rememberDevice`; **ignored unless the phone was verified** (`PhoneSignupService.java:231`; Google: `GoogleAuthService.java:311`) | **Yes (behaviour)**: with phone verification off (Flutter default `false`, `app_environment.dart:19-22`) the sign-up checkbox has no effect |

**« Faire confiance à cet appareil », what it actually does:**
- **What Flutter sends:** `rememberDevice: bool` plus `deviceFingerprint`, `platform`, `deviceLabel`, `sharedDevice` (always `false`, `device_identity_service.dart:54`). This goes to login, Google initiate/complete, sign-up complete and phone-OTP verify (`auth_dtos.dart:259-305, 358-366, 419-428`).
- **What the server does:** it honours the flag only for patients (`DeviceManagementService.java:112`) and sets `trustedUntil = now + patientTrustTtl` unless the device is shared (`UserDevice.java:119-126`). A trusted device then gets the longer patient access and refresh token TTLs (`AccessTokenProperties.java:43-46`, `RefreshTokenProperties.java:43-46`).
- **Not verified:** whether trust also skips any OTP or MFA step (UNVERIFIED: `LoginFinalizationService` not read), and whether client-side token storage changes with the flag (UNVERIFIED).

---

## d) Error handling

- **Path:**
  1. Dio error → `AuthApi._mapDioException` (`auth_api.dart:185-212`) → `ApiException.fromFailure(ApiFailure.fromDio(e))`: the code, field kinds and retry delay are parsed, never the server text (`:209-211`).
  2. `AuthController._setFailure` stores the code and error (`auth_controller.dart:535-541`).
  3. At display time `AuthErrorMessages.message` maps auth codes to French (`auth_error_messages.dart:51-78`), then falls back to `apiFailureMessage` (code map `api_failure_message.dart:66-77`, then the message for the failure kind `:18-30`).
- **Raw server text:** never shown.
- **English local text is shown verbatim:**
  - `AuthFlowException` messages are returned as-is (`auth_error_messages.dart:43`) and are English (`auth_controller.dart:136-138, 171, 177-179, 183, 210, 227-229, 276, 282, 301, 362, 376`).
  - `PhoneNumberFormatException` (`tunisian_phone_number.dart:23`).
  - Screen fallbacks: `phone_input_screen.dart:42,99`, `otp_verification_screen.dart:83,108,126`, `splash_screen.dart:87,102` (and the debug-only `:120`).
- **Login failure:** unknown e-mail and wrong password both return `AUTH_INVALID_CREDENTIALS` (`BE:LoginService.java:60-62,137`; `LoginFinalizationService.java:368`). The user sees « Les identifiants sont incorrects. » (`app_fr.arb:375`) in a SnackBar. **No account enumeration on login.** Sign-up does reveal existing e-mails and phones (`PhoneSignupService.java:160-171`): backend design, parked.
- **Field errors:** the controller exposes `fieldErrors` (`auth_controller.dart:77`), but **no screen reads them**, so server field errors never land on a field.
- **Where errors appear:** SnackBar on login, sign-up and phone (`login :53-60`, `signup :105-112`, `phone_input :95-102`). Inline red box on OTP (`otp :240-256`) and the Google link sheet (`:175-194`).
- **Loading:** button spinner from local `_loading`/`_isLoading` (`login :320-328`, `phone_input :209-216`, `otp :281-289`) or `auth.isSubmitting` (`reset_password :109`). Sign-up's `_isLoading` is set only in the Google path (`signup :95`). The e-mail path validates locally and navigates.
- **Double-submit protection:**
  - Screen guards: `login :42,80`, `signup :94`, `otp :80`.
  - Controller guard `_submitting` (`auth_controller.dart:133,160,200,...`).
  - `phone_input_screen.dart:52` has **no re-entry guard**: a keyboard « done » during loading calls again. The controller then returns `false` with no new error, which can show « Unable to continue. » (code reading, not run).

---

## e) Google sign-in

- **Packages:** `google_sign_in: ^6.2.1` (`pubspec.yaml:67`), locked **6.3.0**; transitive `google_sign_in_web 0.12.4+4`, `_android 6.2.1`, `_ios 5.9.0` (`pubspec.lock:656-690`). The web build does **not** use `google_sign_in_web` for the button. It calls Google Identity Services through its own JS interop.
- **Web:**
  - `web/index.html:38` loads `https://accounts.google.com/gsi/client` with **no `hl`**. The client id comes from a meta tag (`web/index.html:24`, value masked).
  - `google_web_sign_in_button_web.dart:73-86` calls `google.accounts.id.initialize`. `:167-175` calls `renderButton` with `type: standard, theme: outline, size: large, text: continue_with, shape: rectangular, logo_alignment: left, width`.
  - The button is **Google's rendered DOM inside `HtmlElementView`** (`:197`), not our widget.
- **Why it shows English:** no `locale` option and no `?hl=` parameter. Per the GIS reference, the button then defaults to « the users Google Account or browser settings », and different users may see different languages and sizes. Source: developers.google.com/identity/gsi/web/reference/js-reference (checked 2026-11-11).
- **Android / iOS:** our own `OutlinedButton.icon` with `assets/icons/google_logo.svg` and the label « Continuer avec Google » (`login :356-370`, `signup :571-579`). It calls `GoogleSignIn(scopes: ['email']).signIn()` and reads `idToken` (`google_sign_in_session_native.dart:8,24-27`).
  - No `serverClientId` in code, no `GIDClientID`/reversed client id in `ios/Runner/Info.plist` (grep count 0), no `android/app/google-services.json`.
  - Without these, mobile sign-in probably returns no ID token or throws, and shows « Connexion Google impossible. » (UNVERIFIED: not run).
- **Server flag:** `omnicare.auth.google.enabled`, default `true` (`BE:auth/config/GoogleOAuthProperties.java:9-12`). When it is off, the server returns `AUTH_PROVIDER_UNAVAILABLE` (`GoogleAuthService.java:333-339`), shown as « Service de connexion momentanément indisponible. Réessayez plus tard. » (`app_fr.arb:379`). Flutter never reads this flag, so the button is always shown.
- **Restyling and localizing (official docs, checked 2026-11-11):**
  - **Web:**
    - GIS only allows sign-in through the SDK's own UI. The `google_sign_in_web` README says to « display the Widget returned by `renderButton` … because the GIS SDK only allows signing in using UI provided by the SDK ». That README is for v1.1.3; our lock has 0.12.4+4.
    - So we cannot replace the button with our own widget. We can set `locale: 'fr'` (GIS ref: « Display button text using the specified locale ») and `?hl=fr` on the script `src`, plus theme / shape (`pill`) / size / width / text.
  - **Android / iOS:**
    - A custom button is allowed. The branding guidelines (developers.google.com/identity/branding-guidelines) say « Localization of this text … is permitted and encouraged ».
    - Rules: standard-colour « G » on a white background, size and colour unchanged. Light spec: fill #FFFFFF, 1 px stroke #747775, text #1F1F1F, « button font is Google Sans Medium » 14/20.
    - The Google button must be at least as prominent as other third-party options.
    - Our current button uses Plus Jakarta Sans, a #D0D5DD 1.25 px stroke, slate text and radius 14, so strict compliance is an open question.

---

## f) Forgot password and phone/OTP

- **Forgot password:**
  - **Flutter:** the screen exists but is **unreachable** (no route or caller). It is **fake**: a 2 s delay, then the English snackbar « Password reset backend integration pending » (`forgot_password_screen.dart:31-45`). Hardcoded styles; uses l10n keys `resetPassword`, `resetPasswordSubtitle`, `emailOrPhone`, `sendCode`.
  - **Login:** has **no « Mot de passe oublié ? » link** (`login_screen.dart:259-333`).
  - **Spring:** **MISSING**. The only password endpoint is the authenticated `/auth/password/change` (BE `AuthController.java:113`).
  - Owned by G-2 Phase 2 (`docs/roadmap/G2_Patient_Flutter_Roadmap.md:197`). Parked.
- **Phone / OTP:**
  - Fully wired in Flutter (screens 6–7) and Spring (BE `AuthController.java:195,216,258,380,301,327`). Gated by the dart-define `OMNICARE_PHONE_VERIFICATION_ENABLED` (default false) and the server `phoneVerificationProperties.enabled()` (BE `:233,400`).
  - **With the flag off:** login hides the phone button (`login :226`). Sign-up **still collects the phone** and calls `/signup/complete` directly (`phone_input :157-159`, `auth_controller.dart:340-347`). The server requires `phone` (`SignupCompleteRequest.java:27-28`).
  - **OTP UI:** 6 single-digit `TextField`s with manual focus hopping, 60 s resend timer (`otp :26-30, 67-77, 195-238`). English « Please enter all 6 digits » (`:83`).

---

## g) Redesign fit check

| Item | Verdict | Where it would live | Notes / flags |
|---|---|---|---|
| Welcome screen | **NEW** | `lib/features/auth/welcome_screen.dart` | Splash goes to `'/login'` (`splash_screen.dart:44`) and a test pins that route (h). Either the welcome becomes the `LoginScreen` body (no route change) or a new `/welcome` route is added in `main.dart` (app wiring, see Q1). Logo asset `assets/images/logo.png` exists |
| Bottom-sheet login | **EXTEND** | `lib/features/auth/widgets/login_sheet.dart`, opened from the welcome screen | Keep the logic in `login_screen.dart:41-167` unchanged and move it into the sheet. `bottomSheetTheme` exists (`omni_theme.dart:573-590`). Risks: the Google link sheet becomes a sheet-on-sheet; the web GIS `HtmlElementView` inside an animated sheet is UNVERIFIED |
| 3-step sign-up + progress bar | **EXTEND** | `signup_screen.dart` (+ `widgets/signup_steps/*`) | `progressIndicatorTheme` exists (mint). The phone is **required by the server**, so one step must keep `PhoneInputScreen`. `PhoneSignupDraft` (`auth_flow_models.dart:25-53`) unchanged |
| Labels above fields | **NEW** (pattern) | `lib/core/widgets/omni_text_field.dart` | The theme uses floating `labelText`. Do it in the widget, not by changing the global theme (all app forms share `inputDecorationTheme`) |
| Pill text field + error/success states | **NEW** | same `omni_text_field.dart` | `OmniRadii.pill` exists. No success-border token: use `success`/`freshMint` locally. Global input radius 12 must stay for other screens |
| Password rule chips | **NEW** | `lib/features/auth/widgets/password_rules.dart` | Server rule is only 12–128 chars + breach check. Any other chip is client-only (Q4) |
| Live confirm-password check | **EXTEND** | `signup_screen.dart` (listener / `autovalidateMode.onUserInteraction`) | Client-only, no backend |
| Wheel date picker (3 columns, French months, max = today − 18 y) | **NEW** | `lib/core/widgets/omni_date_wheel_picker.dart` | Output `DateTime` → `PhoneSignupDraft`. Cap computed in local time; the server checks in UTC (birthday ±1 h edge, parked) |
| Gender segmented control | **EXTEND** (replace `_GenderCard`, `signup :653`) | `signup_screen.dart` or `omni_segmented.dart` | Values `M`/`F` (+ `autre` if product decides: the server already accepts it, **no backend change**) |
| Switch for trusted device | **EXTEND** | `CheckboxListTile` → `SwitchListTile` in login and sign-up; `switchTheme` to add in `omni_theme.dart` | **Behaviour flag:** no effect at sign-up when phone verification is off (server). Copy must not over-promise (Q6) |
| Summary / review step | **NEW** | `lib/features/auth/widgets/signup_review_step.dart` | Pure display of `PhoneSignupDraft` plus phone, with "Modifier" jumps |
| French Google button | **EXTEND** | web: `google_web_sign_in_button_web.dart:167` add `locale: 'fr'`; mobile: restyle `_googleButton` / `_buildGoogleButton` | `?hl=fr` would touch `web/index.html:38`, which is **not a Flutter UI file** (Q10). Mobile label is already French |

**Parked (needs backend or non-UI work; will NOT be done in G-3):**
1. Password reset (no endpoint).
2. Precise error codes for age and gender (today generic `INVALID_INPUT`).
3. A client-readable « Google enabled » flag.
4. `rememberDevice` being ignored at sign-up without OTP.
5. Sign-up revealing existing e-mail/phone.
6. Mobile Google client configuration (iOS plist / Android `serverClientId`).
7. The wrong `INVALID_INPUT` → password message is a Flutter **logic** file (`auth_error_messages.dart:64`), not UI (Q7).

---

## h) Risks for a UI-only change

1. **Logic inside widgets:**
   - Login submit, OTP routing, Google outcomes and account-link sheet handling (`login_screen.dart:41-167`).
   - Sign-up 18+ rule, gender and DOB checks, draft building (`signup_screen.dart:52-62, 162-213`).
   - The phone screen picks the flow (`phone_input_screen.dart:52-105`).
   - OTP timer and focus (`otp :67-129`).
   - Moving the UI risks dropping these branches; keep them verbatim.
2. **Divergent duplicate logic:**
   - Sign-up's Google handler has **no account-link branch** (`signup :93-132` vs `login :104-129`): an existing-e-mail Google user tapping Google on sign-up gets no UI.
   - Sign-up routes with its own `_routeAuthenticated` (`:152-160`) instead of `navigateAfterAuthentication` (no unsupported-role logout, no urgent-cabinet recovery).
   - Both are logic: flag to G-2 or decide (Q12).
3. **Tests that pin the current layout** (`test/auth_phase1_test.dart`; no auth goldens, `test/goldens/` holds only `patient_home_*.png`):
   - `:3642` splash → `'/login'`; `:3854` `/login` registered; `:3599` key `splash-retry-session`.
   - `:3671` LoginScreen RichText « Professionnel de santé ? Demander à rejoindre OmniCare »; `:3945` same text must be reachable at 360×520, 390×640, 430×720.
   - `:3697-3808` GoogleAccountLinkSheet texts and keys (`google-link-email-hint/password/error/submit/retry/cancel`, « Associer votre compte Google », « Associer et continuer », « Annuler »).
   - `:3988` SignupScreen: `find.byType(ElevatedButton)` **findsOneWidget** and width > 300. A multi-step sign-up with several ElevatedButtons breaks it.
   - Route helper `_entryApp` `:430-440`; 7 skipped tests for the dead population flow `:3198-3370`.
   - The standing rule is « logic-only tests, no new widget tests », so whether these existing widget tests get updated or retired is a decision (Q11).
4. **Global theme blast radius:** `inputDecorationTheme`, button style (radius 14, height 50) and `checkboxTheme` are app-wide. Pill fields and switches must be local widgets or additive theme entries.
5. **Font weight 400 not bundled** (b): new light body text may render differently per platform (UNVERIFIED).
6. **G-2 roadmap Phase 2 overlaps** (`G2_Patient_Flutter_Roadmap.md:193-199`):
   - « Phone OTP as primary sign-in » → `login_screen.dart`, `phone_input_screen.dart`, `otp_verification_screen.dart`.
   - « Google hidden unless server flag + mobile config » → Google button in `login_screen.dart`, `signup_screen.dart`, `google_web_sign_in_button_web.dart`.
   - « Password recovery … wire `ForgotPasswordScreen` » → `forgot_password_screen.dart`, login link.
   - G-2 1b error mapping reports also own `auth_error_messages.dart`.
   - **Overlap = every file G-3 would touch for login/sign-up.**

---

## Open questions (not decided)

1. Welcome screen: replace the `LoginScreen` body (no route change), or add a `/welcome` route in `main.dart` and change the splash target? Is `main.dart` route wiring allowed in a « UI files only » prompt?
2. The « Professionnel de santé ? » link: keep it on the welcome screen, in the login sheet, or both?
3. Gender: 2 options, or add « Autre » (server already accepts `autre`)?
4. Password chips: only the server rule (12–128), or add client-only rules (uppercase / digit / symbol) the server does not enforce?
5. Where does the mandatory phone go in the 3 steps (e.g. 1 Compte · 2 Identité · 3 Téléphone + récap), with OTP off by default?
6. Trusted-device switch on sign-up: keep, hide, or relabel, given it has no effect there while phone verification is off?
7. Fix the wrong « mot de passe différent » message for server `INVALID_INPUT` in G-3 (logic file) or park it to G-2?
8. Are the English strings in phone, OTP, splash and the controller (b, d) in G-3 scope (screen text) or G-2?
9. Mobile Google button: strict Google branding (Google Sans, #747775 stroke, #1F1F1F text) or OmniCare-styled within the guidelines?
10. Is editing `web/index.html` (`?hl=fr`) allowed, or only `locale: 'fr'` in the Dart widget?
11. Existing widget tests that the redesign will break (h.3): update them, or retire them under the logic-only test rule?
12. Sign-up's Google path lacks account-link handling and uses its own routing (h.2): fix in G-3 while restructuring, or park for G-2?
13. « Mot de passe oublié ? »: hide until the backend exists, or show a disabled « bientôt disponible » entry?
14. The orphan auth screens (forgot/email/population/language/medical-data welcome): leave for G-2's dead-code PR, or remove during G-3?

---

## Path to deliver G-3 (login / sign-up)

1. **CTO decisions and target design:** answer Q1–Q14, approve the target screens (welcome, login sheet, 3-step sign-up + review) from screenshots, and freeze the ranked fix list for this page. Install the modern-app design skills and use them to produce the approved mock-ups on our tokens (`OmniColors`, `OmniRadii`, `OmniSpacing`).
2. **Prompt P1, shared UI widgets (UI files only):**
   - `omni_text_field.dart` (label above, pill, error/success), `password_rules.dart`, `omni_date_wheel_picker.dart` (French months, max today − 18), segmented gender, trusted-device `SwitchListTile`, step progress bar.
   - Additive `switchTheme` in `omni_theme.dart`; no global input/button change.
   - Logic-only unit tests for any extracted pure function (age cap, rule evaluation); manual test steps for the CTO.
3. **Prompt P2, screens:**
   - Welcome + bottom-sheet login reusing `login_screen.dart` logic verbatim; French GIS button (`locale: 'fr'`).
   - Then the 3-step sign-up + review reusing `PhoneSignupDraft` and `PhoneInputScreen`.
   - Every backend-dependent item stays parked (g).
