# G-2 · P0 — Patient app data-wiring inventory

| | |
|---|---|
| Goal | G-2: connect the patient Flutter app to the real backend, no UI redesign |
| Phase | P0: factual inventory (input for every later phase) |
| Date | 2026-11-10 |
| Mode | READ-ONLY. No source, config, test or build file was modified in any repo. This file is the only write. Nothing was built or run. |
| Repos read | `OmniCare-App` · `OmniCare-BackEnd` · `omnicare-mrs` (none is a git repo at the workspace root, so no commit SHAs are recorded) |

**Path conventions.** App paths are relative to `OmniCare-App/` (for example `lib/main.dart:123`). `BE/` = `OmniCare-BackEnd/src/main/java/com/omnicare/app/`. `BE-res/` = `OmniCare-BackEnd/src/main/resources/`. `MRS/` = `omnicare-mrs/`. The Dio base URL is `<OMNICARE_API_BASE_URL>/api/v1` (`lib/core/config/app_environment.dart:47-52`, `lib/core/network/app_http_client.dart:54-73`), so a Dart path `/profile` is served at Spring `/api/v1/profile`.

**Masking.** Secrets, `.env` values, tokens and personal-looking fixture values are shown as `***`. Only `.env` key *names* are listed.

---

## 0. Plan and method

### 0.1 What was read
| Area | Folders |
|---|---|
| Flutter (patient) | `lib/main.dart`, `lib/main_*.dart`, `lib/core/**`, `lib/features/**` except `lib/features/doctor/**`, `lib/providers/**`, `lib/repositories/**`, `lib/services/**`, `lib/mock_data/**`, `lib/demo/**`, `lib/l10n/**`, `test/**` (file names only, plus a grep for class names), `pubspec.yaml` |
| Spring | `BE/**/*Controller.java` (all 97), the DTOs behind every endpoint the app calls, `BE/auth/config/AuthWebSecurityConfig.java`, the error handlers (`GlobalExceptionHandler`, `*ProblemDetailHandler`), `NotificationType`, `NotificationService`, `FcmDispatcher`, emitters, the template changelogs, `BE-res/application*.yaml` |
| MRS (Go) | `MRS/internal/api/**` route registration (documents, medical records, artifacts, consultation completion) |

### 0.2 How reachability was traced
1. **Import graph.** A script walked every `import`/`export`/`part` directive transitively from `lib/main.dart`. Result: 375 of 462 Dart files are import-reachable. With `lib/features/doctor/**` cut out of the walk, **276 files are patient-reachable**. Three files are reachable *only* through the doctor shell: `lib/core/api/consultations_api.dart`, `lib/core/models/consultation.dart`, `lib/mock_data/mock_consultations.dart`.
2. **Navigation.** Being importable does not make a screen visible. Each candidate screen was then traced to a concrete entry: the `routes:` table (`lib/main.dart:413-474`), `onGenerateRoute` (`lib/main.dart:475-527`), the home nested navigator (`lib/features/home/new_home_screen.dart:347-428`), bottom tabs (`new_home_screen.dart:294-306`), or a `Navigator.push*`/`showModalBottomSheet`/`showDialog` call site in an already-reachable screen. A screen with no such entry is listed as "import-reachable, not navigable".
3. **Data path.** For every navigable screen the chain was followed: widget → controller/provider → repository → API class → HTTP method + path. That was matched against an index of every Spring `@*Mapping`, and the controller was opened to confirm.
4. **Contract.** For each REAL endpoint, the Dart `fromJson`/`toJson` was compared with the Spring request/response DTO.
5. **Cross-cutting scans** were regex scans over the 276 patient-reachable files, then checked by hand where noted.

The work was split by domain across four read-only sub-inventories, and the key claims were re-verified directly: passport `denyAll`, urgent-cabinet prod mode, the `medicalInfo` drop, the +1 h slot shift, and `history_tab` reachability.

**Index caveat.** The generated endpoint index mislabels a few class-level prefixes (`PatientArtifactController`, `DoctorArtifactController`, `PatientRequestController`). Every match below was confirmed in the controller file itself.

---

## Executive summary (what P0 found)

| # | Finding | Evidence | Severity |
|---|---|---|---|
| F1 | **Booked slot is sent 1 h late.** Slots are shifted to a Tunis wall clock but stay flagged as UTC, and that shifted value is POSTed as the real start. | `lib/features/patient_doctor/data/doctor_directory_mapper.dart:107-108,226-227` → `lib/features/scheduled_care/application/patient_booking_controller.dart:261-263` → `lib/features/scheduled_care/domain/scheduled_care_models.dart:97` | P0 (wrong clinical booking) |
| F2 | **Urgent CABINET cannot work in production.** The backend has only the `DISABLED` and `LOCAL_DEVELOPMENT` modes plus a patient allow-list. The app's `p4Production` gate is fully open. | `BE/urgentcabinetrequest/UrgentCabinetAuthorizationMode.java:3-6`; `BE/urgentcabinetrequest/UrgentCabinetTargetedAccessPolicy.java:24-51`; `BE-res/application-prod.yaml:34`; `lib/main.dart:123` | P0 (backend decision) |
| F3 | **Medical record tab (tab 3) is STATIC fixture data.** Identity, blood group, allergies, conditions, meds, measurements, history and documents all come from a fixture; its editors save nothing. | `lib/features/patient_passport/presentation/patient_passport_screen.dart:8,38`; `lib/features/patient_passport/data/patient_passport_static_data.dart:4-106` | P0 (fake medical data) |
| F4 | **The patient medications API is unreachable.** `/api/v1/passport/**` has no security matcher and falls to `anyRequest().denyAll()`. The app's medication search is MOCK. | `BE/profile/controller/PassportController.java:21`; `BE/auth/config/AuthWebSecurityConfig.java:280`; `lib/core/api/medications_api.dart:43-68` | P0 |
| F5 | **Ma Santé (tab 1) shows empty medical data and silently drops edits.** `medicalInfo` is not a field of `UpdatePassportRequest`, and blood-type sentinels `'-'`/`'IDK'` get a 400 that the user never sees. | `lib/features/home/new_home_screen.dart:1715-1723`; `BE/profile/DTO/UpdatePassportRequest.java:9-15`; `lib/features/home/edit_medical_data_screen.dart:75,194-247` | P1 |
| F6 | **The real documents screen has no entry point.** `/medical-documents` is reachable only from the orphan `/medical-profile` → `/medications` chain. Ma Santé shows 3 hardcoded documents instead. | `lib/main.dart:423-437`; `lib/features/profile/medications_screen.dart:503`; `lib/features/home/new_home_screen.dart:1989-2007` | P1 |
| F7 | **Push taps fail for 3 booking notification types**, because FCM sends the template alias type. | `BE/notification/.../FcmDispatcher.java:116,130`; `BE/notification/.../NotificationService.java:157-171` | P1 |
| F8 | **Urgent-cabinet enum drift** (`CABINET_CREATED`, `LEGACY_LIFECYCLE_REMEDIATION`, an ABORTED-consultation phase) makes Dart reject the whole snapshot. | See §c | P1 |
| F9 | **The HOME urgent flow is a dead end**: "send" goes to the unavailable screen although the `/me/urgent-home/*` patient endpoints exist. | `lib/features/emergency/emergency_review_screen.dart:90-92` | P1 (scope decision) |
| F10 | **Home feed is FIXTURE/STATIC**: network stats, referral code, OmniBand progress, greeting fallback name. **Clinic detail** shows invented doctors, hours and insurers. | `lib/features/home/patient_home_feed.dart:42-67,129,537,802-805,1168,1265`; `lib/features/patient_clinic/presentation/clinic_presentation_metadata.dart:348-440` | P1 |
| F11 | **Five backend error envelopes**; English server messages reach patient widgets in 8 places. | §f | P2 |
| F12 | **~1,476 hardcoded UI strings** (870 FR / 254 EN / 352 ambiguous) in 117 files. `AppLocalizations` is used by only 1 patient screen, and the default locale is `en`. | §d.1; `lib/main.dart:372` | P2 |

---

## a) Screen table: every patient screen reachable from `lib/main.dart`

Legend:
- **Source**: REAL (backend), MOCK (`lib/mock_data` or `*mock*`), FIXTURE (hardcoded sample records), STATIC (hardcoded content that should come from the server, or a purely static screen), DEAD (an action that does nothing or leads nowhere), DEVICE (GPS/sensors), LOCAL (on-device state by design).
- **L/E/Err**: loading / empty / error state present (y/n/n-a).
- **Spring**: `BE/` path:line plus the method name.

### a.1 Auth and onboarding

| Screen | Route / entry | VM / provider | Repo / API | HTTP | Spring | Source | L/E/Err | Tests |
|---|---|---|---|---|---|---|---|---|
| `lib/features/auth/splash_screen.dart` | `home:` `lib/main.dart:411` | AuthController (`auth_controller.dart:89-115`) | AuthRepository → AuthApi | POST /auth/refresh (if expired); GET /auth/me (`auth_api.dart:100-102`); GET /profile?includeMedical=false (`auth_api.dart:112-114`) | `auth/api/AuthController.java:89` refresh, `:97` currentUser; `profile/controller/ProfileController.java:41` getProfile | REAL (debug-only "Clear Local Session" `:111-121`) | y / n-a / y (`:77-105`) | auth_phase1_test, clinic_phase1_test |
| `lib/features/auth/login_screen.dart` | `/login`, `/auth-entry`, `/professional-login` `lib/main.dart:416-418` | AuthController | AuthRepository → AuthApi | POST /auth/login (`auth_api.dart:38-46`); POST /auth/google/initiate (`:58-66`) | `AuthController.java:81` login, `:285` googleInitiate | REAL. No "forgot password" link | y / n-a / y | auth_phase1_test |
| `lib/features/auth/signup_screen.dart` | push `login_screen.dart:366-368` | AuthController | (draft → PhoneInputScreen) | POST /auth/google/initiate | `AuthController.java:285` | REAL | y / n-a / y | auth_phase1_test |
| `lib/features/auth/phone_input_screen.dart` | push `login_screen.dart:122,150`; `signup_screen.dart:120,201` | AuthController | AuthRepository | POST /auth/login/phone/initiate; /auth/signup/phone/initiate; /auth/signup/complete (OTP flag off); /auth/google/phone/initiate; /auth/google/complete (`auth_api.dart:16-72`) | `AuthController.java:380, 195, 227, 301, 340` | REAL | y / n-a / y | **none** |
| `lib/features/auth/otp_verification_screen.dart` | push `phone_input_screen.dart:83-90`, `login_screen.dart:62` | AuthController | AuthRepository | POST /auth/login/phone/verify; /auth/signup/phone/verify + /complete; /auth/google/phone/verify + /complete | `AuthController.java:258, 216, 227, 327, 340` | REAL | y / n-a / y | **none** |
| `lib/features/auth/google_account_link_sheet.dart` | bottom sheet `login_screen.dart:96-102` | AuthController | AuthRepository | POST /auth/google/link | `AuthController.java:315` | REAL | y / n-a / y | auth_phase1_test |
| `lib/features/auth/reset_password_screen.dart` | `/change-password-required` `lib/main.dart:442` | AuthController | AuthRepository | POST /auth/password/change | `AuthController.java:113` | REAL (the only patient screen using `AppLocalizations`) | y / n-a / y | auth_phase1_test |
| `lib/features/auth/professional_access_request_screen.dart` | `/professional-access-request` `lib/main.dart:419-422` | local | ProfessionalAccessRequestApi | POST /professional-access-requests | `professionalaccess/api/ProfessionalAccessRequestController.java:23` | REAL | y / n-a / y (server message shown, §f) | auth_phase1_test |
| `lib/features/onboarding/conversational_onboarding_screen.dart` | `/conversational-onboarding` `lib/main.dart:438-441` | UserOnboardingProvider, UserProvider | AccountApi; MedicationsApi (MOCK) | GET /profile (`:194,:303`); POST /profile/onboarding/step/{1..4} (`:309-363`); PATCH /profile/passport (`:321`) | `profile/controller/OnboardingController.java:26`; `ProfileController.java:66, :41` | **MIXED**: REAL save. MOCK medication autocomplete (`:1760` → `medications_api.dart:43-55`). STATIC condition list (`:51-66`). STATIC frequency `'1x daily'` (`:294`). **DEAD skip**: "Skip" only navigates (`:555-557`), never calls `POST /profile/onboarding/skip` (`OnboardingController.java:37`) | y / n-a / y (server message in SnackBar `:375`) | none (source scan only: phase2_auth_network_boundary_test) |
| `lib/features/onboarding/onboarding_complete_screen.dart` | pushReplacement `conversational_onboarding_screen.dart:383-386` | — | — | none | — | **STATIC**: renders a client-built QR whose payload embeds the user's email or phone plus a timestamp (`:43-44,137`); it is not a server identity | n-a | none |

### a.2 Home hub (`/home` → `NewHomeScreen`, `lib/main.dart:444`)

Bottom nav (`new_home_screen.dart:3420-3480`): tab 0 Accueil (nested navigator `:297,:347-428`) · tab 1 Ma Santé (`:299,:1262`) · tab 3 Dossier médical → PatientPassportScreen (`:300-301`) · tab 4 Profil → PatientProfileScreen (`:302-303,:1164`). The centre "care" button is in the middle slot.

| Screen | Route / entry | VM / provider | Repo / API | HTTP | Spring | Source | L/E/Err | Tests |
|---|---|---|---|---|---|---|---|---|
| `lib/features/home/new_home_screen.dart` (shell + Ma Santé tab) | `/home` `lib/main.dart:444` | UserProvider, FamilyProvider, AuthController, NotificationCenterController | UserRepository (AccountApi + FilesApi), FamilyRepository | GET /profile/family-members (`:162-172`); POST /auth/logout (`:176-183`); PATCH /profile/passport {bloodType, **medicalInfo**} (`:1715-1723`) | `profile/.../FamilyMemberController.java:42`; `AuthController.java:128`; `ProfileController.java:66` | **MIXED**. Ma Santé passport card reads `medicalInfo`/`bloodGroup`, which `UserProvider` never fills (`user_provider.dart:217-228`), so it is always empty (**STATIC-empty**). 3 hardcoded documents (`:1989-2007`, STATIC). Documents "+" opens the editor with FIXTURE meds and a no-op save (`:1923-1960`, DEAD). Family grid REAL | y / y (family) / y (`:226-252`) | new_home_screen_test, patient_route_transition_test, emergency_nested_navigation_test |
| `lib/features/home/patient_home_feed.dart` | tab 0 nested `/patient-home` (`new_home_screen.dart:404,431-438`) | none | none | none | — | **FIXTURE/STATIC** throughout: health highlights (`:42-67`), greeting fallback first name `***` (`:129`), OmniBand `0 / 5` (`:537`), network stats "350 Médecins / 100 Kinés / 150 Infirmiers / 10 Cliniques" (`:802-805,:863`), referral `0 / 2` + code `OMNI-***` + invite URL (`:1168,:1265,:2065-2070`), "Service client 24 h/24" (`:967`). The language sheet does nothing (`:2105-2135`, DEAD). The "Voir mes notifications" search item opens a duplicate feed (`:1871` → `new_home_screen.dart:424`, DEAD/bug) | n / y (search) / n | patient_home_feed_test, request_history_widget_test |
| `lib/features/home/patient_care_destinations.dart` (metadata) | used by the feed and by `provider_selection_screen.dart` | — | — | none | — | STATIC (4 destinations `:32-65`) | n-a | indirect |
| `lib/features/home/add_family_member_screen.dart` | push `new_home_screen.dart:88-89,2441-2444`; `patient_home_feed.dart:2040-2043`; `who_needs_care_screen.dart`; `emergency_request_step1.dart`; `urgent_cabinet_care_subject_screen.dart` | FamilyProvider | FamilyRepository → FamilyApi | POST /profile/family-members (`family_api.dart:41-62`); PATCH /profile/family-members/{id} (`:64-86`) | `FamilyMemberController.java:32, :57` | REAL | y / n-a / y (server fieldErrors shown, §f) | emergency_request_step1_test, urgent_cabinet_care_subject_test |
| `lib/features/home/family_member_detail_screen.dart` | push `new_home_screen.dart:2302-2307` | FamilyProvider | FamilyApi; MedicalShareQrApi | PATCH /profile/family-members/{id}/passport {bloodType} (`family_api.dart:98-110`); POST /patient/medical-sharing/qr | `FamilyMemberController.java:76`; `medicalsharing/api/PatientMedicalSharingController.java:91` | **MIXED**. Displayed data is STATIC: blood type `'-'`, empty conditions, meds and docs (`new_home_screen.dart:69-84`). Condition and med edits stay local (`:74-79`). The `'-'` default gets a 400 (§c) | n / y / n | p5_06_patient_qr_test |
| `lib/features/home/edit_medical_data_screen.dart` | push `new_home_screen.dart:1689` (self), `:1925` (fixture), `family_member_detail_screen.dart:60` | none (`onSave` callback) | MedicationsApi (MOCK) | via caller | — | MIXED: MOCK med search (`:501`), STATIC conditions, local-only documents (`:169-180`). **No catch** around `onSave` (`:194-247`) | y / y / **n** | none |
| `lib/features/home/document_viewer_screen.dart` | push `new_home_screen.dart:2068-2076` | — | — | none | — | STATIC placeholder (`:190`). DEAD share (`:81-83`), download (`:87-89`), print (`:232-234`) and open (`:259-261`) | n/n/n | none |
| `lib/features/home/qr_code_modal.dart` | dialog `new_home_screen.dart:1443-1450`; `family_member_detail_screen.dart:359-365`; `patient_passport_screen.dart:422-432` | MedicalShareQrController | MedicalShareQrApi | POST /patient/medical-sharing/qr + Idempotency-Key (`medical_share_qr_api.dart:22-41`) | `PatientMedicalSharingController.java:91` | REAL. In `kDebugMode` only, a failed call shows a FIXTURE payload (`medical_share_qr_controller.dart:12,93-96`) | y / y (expired) / y | p5_06_patient_qr_test |

**Home destinations with defects** (the full label → target list is in the scratch working notes and is summarised here):
- The centre care button is **DEAD on tabs 1, 3 and 4**: its nested navigator exists only on tab 0 (`new_home_screen.dart:3490-3501`).
- The feed privacy strip opens the language sheet (`patient_home_feed.dart:1541`). The language sheet changes nothing (`:2105-2135`).
- About 15 builder methods in `new_home_screen.dart` are never called (for example `_buildUrgentCareCard :440`, `_buildDoctorsList :987`, `_buildUpcomingAppointment :3066`, `_buildHealthMetrics :3284`).

### a.3 Medical record, profile and documents

| Screen | Route / entry | VM / provider | Repo / API | HTTP | Spring | Source | L/E/Err | Tests |
|---|---|---|---|---|---|---|---|---|
| `lib/features/patient_passport/presentation/patient_passport_screen.dart` | tab 3 `new_home_screen.dart:301,3466` | local state from `PatientPassportStaticData.current` (`:38`); FamilyProvider; MedicalSharingController; DirectPatientAuthorizationController | FamilyApi + sharing APIs | GET /profile/family-members | `FamilyMemberController.java:42` | **MIXED, mostly STATIC/FIXTURE**: identity, phone, email, OmniCare ID, blood group, allergies, conditions, medications, measurements and consultation history all come from `patient_passport_static_data.dart:4-106`. Family selector is REAL when non-empty, else FIXTURE (`:286-309`). The per-consultation sharing toggle never fires because fixture consultations have no id (`:323-326`, DEAD). The documents tab is STATIC "0 documents" (`widgets/passport_documents_tab.dart:22-30`) | n / n / partial (`:386-397`) | patient_passport_screen_test, p5_06_patient_qr_test |
| `.../medical_data_editor_screen.dart` | push `patient_passport_screen.dart:368-374` | local | none | none | — | STATIC: save only pops the edited view-model (`:257-275`) | n/n/n | none |
| `.../medical_document_editor_screen.dart` | push `patient_passport_screen.dart:358-364` | local | none | none | — | STATIC: "Fichier simulé" (`:124-137`); save uploads nothing (`:184-185`) | n/n/n | none |
| `.../widgets/medical_sharing_settings_sheet.dart` | sheet `patient_passport_screen.dart:400-410` | MedicalSharingController, DirectPatientAuthorizationController | MedicalSharingApi, DirectPatientAuthorizationApi | GET/PUT /patient/medical-sharing/policy; GET/PUT /patient/medical-sharing/consultations/{id}; GET /me/consultations/medical-sharing; GET /me/consultations/{id}/medical-sharing/access; POST …/approve, …/revoke | `PatientMedicalSharingController.java:42,52,66,78`; `medicalsharing/api/DirectPatientAuthorizationController.java:36,46,56,64` | REAL | y / y / y (server `detail` shown, §f) | medical_sharing_controller_test, direct_patient_authorization_controller_test |
| `.../widgets/family_passport_selector_sheet.dart`, `passport_history_filter_sheet.dart` | sheets `patient_passport_screen.dart:276-284, 311-318` | local | — | — | — | MIXED / STATIC filters over fixture data | — | none |
| `lib/features/profile/patient_profile_screen.dart` | tab 4 `new_home_screen.dart:303,1169` | UserProvider, FamilyProvider | UserRepository → AccountApi, FilesApi; FamilyApi | GET/PATCH /profile; PATCH/DELETE /profile/avatar (`files_api.dart:74-97`); family CRUD | `ProfileController.java:41,54`; `profile/.../ProfileAvatarController.java:38,49`; `FamilyMemberController.java:32,42,57,67` | REAL (the mock branch in `user_repository.dart:31-40` runs only when no API is injected; production injects one at `lib/main.dart:284-289`) | y / y / y | patient_appointments_test, patient_profile_test |
| `lib/features/profile/vital_info_screen.dart` | `/medical-profile` `lib/main.dart:423`. **No push site anywhere** | UserOnboardingProvider (in-memory) | none | none | — | STATIC + in-memory. **Orphan route** | n / y / n | none |
| `lib/features/profile/medications_screen.dart` | `/medications` `lib/main.dart:424`; pushed only from the orphan `vital_info_screen.dart:347` | UserOnboardingProvider | MedicationsApi (MOCK) | none | catalog search MISSING; patient med CRUD denied (§g) | **MOCK** (`medications_api.dart:43-56`) + in-memory. **Orphan** | spinner / y / swallowed (`medication_search_field.dart:101-106`) | none |
| `lib/features/profile/medical_documents_screen.dart` | `/medical-documents` `lib/main.dart:425-437`; pushed only from the orphan `medications_screen.dart:503` | MedicalDocumentUploadController (`lib/main.dart:262-268`) | DocumentsApi, AccountApi | GET /documents?patientId&limit=50 (`documents_api.dart:319-326`); POST /documents multipart + Idempotency-Key (`:456-471`); GET /documents/uploads/recovery (`:487-492`); GET /documents/{id} (`:504-508`); GET /documents/{id}/events SSE (`:525-540`); DELETE /documents/{id} (`:613-624`) | `profile/controller/DocumentController.java:83,65,94,104,114,148` (class PATIENT `:43`). The SSE upstream MRS route **does not exist** (`BE/mrs/HttpMrsDocumentEventClient.java:74-76` vs `MRS/internal/api/documents.go:63-76`); the screen falls back to polling | **REAL but unreachable in production UI**. Only the first 50 documents are shown (no cursor). The list shows raw enums for type and status (no `displayName` in the response) | disabled buttons / y (`:1510-1528`) / y | features/profile/medical_documents_screen_test, medical_document_upload_recovery_test, core/api/documents_api_test |
| `lib/features/patient/artifact/patient_artifact_card.dart` (widget) | embedded in `confirmed_scheduled_appointment_screen.dart:263-267` | local | ArtifactApi (`lib/features/doctor/artifact/artifact_api.dart`) | GET /patient/consultations/{cid}/artifacts (`:23-40`); GET …/{aid}/download (bytes, `:124-139`) | `artifact/api/PatientArtifactController.java:16,18` (PATIENT `:13`) | REAL. MRS returns only FINALIZED items to patients (`MRS/internal/artifacts/service_read.go:114`) | y / y / y | **none** |

### a.4 Security

| Screen | Route / entry | VM | API | HTTP | Spring | Source | L/E/Err | Tests |
|---|---|---|---|---|---|---|---|---|
| `lib/features/security/account_security_screen.dart` | push `new_home_screen.dart:1243-1245` | AccountSecurityProvider | AccountSecurityApi | GET /auth/me, /auth/devices, /auth/phone-change; POST /auth/password/change or /auth/password/set | `AuthController.java:97,144,113`; `PhoneChangeController.java:39`; `AccountSecurityController.java:24` | REAL (app lock is LOCAL) | y / n / y (server text, §f) | **none** |
| AppLockSettingsScreen (`account_security_screen.dart:437`) | push `:105-108` | AppLockService | — | none | — | LOCAL | — / — / y | none |
| `lib/features/security/phone_change_screen.dart` | push `account_security_screen.dart:73-76` | AccountSecurityProvider | AccountSecurityApi | GET /auth/phone-change; POST /auth/phone-change/current/initiate, /current/verify, /new/initiate, /new/verify, /reverse | `PhoneChangeController.java:39,44,55,63,76,84` | REAL | y / n-a / y | none |
| `lib/features/security/device_management_screen.dart` | push `new_home_screen.dart:1246-1248` | AccountSecurityProvider | AccountSecurityApi | GET /auth/devices; POST /auth/devices/{id}/logout, /auth/devices/logout-others, /auth/logout-all | `AuthController.java:144,163,175,135` | REAL | y / y / y (server text) | none |
| `lib/features/security/login_history_screen.dart` | push `new_home_screen.dart:1249-1251` | AccountSecurityProvider | AccountSecurityApi | GET /auth/history?page&size; POST /auth/history/{id}/report | `AuthHistoryController.java:27,36` | REAL | y / y / y | none |
| `lib/features/security/phone_change_reversal_screen.dart` | `onGenerateRoute` `/security/phone-change/reverse?token=` `lib/main.dart:477-485` | AccountSecurityProvider | AccountSecurityApi | POST /auth/phone-change/reverse-token | `PhoneChangeController.java:89` | REAL | y / n-a / y | none |
| `lib/features/security/app_lock_gate.dart` | wraps every route `lib/main.dart:396-401` | AppLockService | — | none | — | LOCAL | — / — / y | none |

### a.5 Urgent care (HOME and CABINET)

"Consultation" itself is out of G-2 scope. The patient urgent-cabinet journey stops at the accepted screen (status text only) and the arrival QR.

| Screen | Route / entry | VM | API | HTTP | Spring | Source | L/E/Err | Tests |
|---|---|---|---|---|---|---|---|---|
| `lib/features/emergency/emergency_request_step0.dart` | `/emergency-step0` `lib/main.dart:446`; `new_home_screen.dart:407` | none | none | none | — | STATIC (2 cards) | n/n/n | emergency_nested_navigation_test, patient_route_transition_test |
| `lib/features/emergency/urgent_care_mode_selection_screen.dart` | `/urgent-care-mode-selection` `lib/main.dart:447` | none | none | none | — | STATIC (HOME → step1, CABINET → shell) | n/n/n | emergency_nested_navigation_test |
| `lib/features/emergency/emergency_request_step1.dart` (HOME) | `/emergency-step1` `lib/main.dart:451` | FamilyProvider, UserProvider | FamilyRepository | family list | `FamilyMemberController.java:42` | REAL (family) / STATIC | n/n/n | emergency_request_step1_test |
| `lib/features/emergency/emergency_request_step2.dart` | `/emergency-step2` `lib/main.dart:487-491` | none | none | none | — | STATIC (body map, pain) | n/n/n | emergency_request_step2_test |
| `lib/features/emergency/emergency_request_step3.dart` | `/emergency-step3` `lib/main.dart:493-498` | none | Geolocator, native Places channel (`:131`) | none to Spring | — | DEVICE | y / n / y (UNVERIFIED in detail) | emergency_request_step3_test |
| `lib/features/emergency/emergency_review_screen.dart` | `/emergency-review` `lib/main.dart:500-505` | none | none | **none**: "send" → `/clinical-request-unavailable` (`:90-92`) | `/me/urgent-home/*` exists (§g) | **DEAD end** for HOME urgent | n/n/n | emergency_review_screen_test |
| `lib/features/clinical_safety/clinical_feature_unavailable_screen.dart` | `/clinical-request-unavailable`, `/clinic-request`, plus 11 legacy routes (`lib/main.dart:452,457,506-524`) | none | none | none | — | STATIC honest "unavailable" | n-a | phase1_clinical_correctness_boundary_test |
| `.../urgent_cabinet/urgent_cabinet_flow_shell.dart` | `/urgent-cabinet/care-subject` `lib/main.dart:449`; `new_home_screen.dart:410`; notification deep link `lib/main.dart:650-663` | UrgentCabinetFlowController, UrgentCabinetPatientLifecycleController | AppUrgentCabinetTargetedRequestRepository | children + polling | below | REAL | — | urgent_cabinet_* tests |
| `.../urgent_cabinet_care_subject_screen.dart` | in-shell initial route | FamilyProvider, lifecycle.recover | SubmissionCoordinator | GET /me/urgent-cabinet/requests/recovery (Idempotency-Key = stored receipt) or GET …/requests/active?subjectType… | `professionalcare/api/MePatientUrgentCabinetTargetedRequestController.java:59,66` | REAL | n/n/n | urgent_cabinet_care_subject_test |
| `.../urgent_cabinet_clinical_intake_screen.dart` | in-shell | FlowController | none | none | — | LOCAL draft | n/n/n | urgent_cabinet_clinical_intake_test |
| `.../urgent_cabinet_doctor_directory_screen.dart` | in-shell | UrgentCabinetDiscoveryController | AppUrgentCabinetDiscoveryRepository | GET /me/urgent-cabinet/discovery/facets; POST …/discovery/search (page size 20) | `MePatientUrgentCabinetDiscoveryController.java:43,35` | REAL (FIXTURE only when a source is injected in tests or alternate entries) | y/y/y | urgent_cabinet_doctor_directory_test, urgent_cabinet_discovery_integration_test |
| `.../urgent_cabinet_doctor_detail_screen.dart` | in-shell | local | Discovery repo | GET …/discovery/doctors/{d}/practice-locations/{l} | `MePatientUrgentCabinetDiscoveryController.java:50` | REAL | y/y/y | urgent_cabinet_doctor_detail_test |
| `.../urgent_cabinet_request_confirmation_screen.dart` | in-shell | FlowController, LifecycleController | Discovery + Targeted repos | GET detail (re-validation, `:105`); POST /me/urgent-cabinet/requests + Idempotency-Key; GET …/recovery on an ambiguous outcome | `MePatientUrgentCabinetTargetedRequestController.java:40,59` | REAL | y/n/y | urgent_cabinet_request_confirmation_test, urgent_cabinet_targeted_submission_test |
| `.../urgent_cabinet_request_waiting_screen.dart` | in-shell | LifecycleController | Targeted repo | **poll** GET /me/urgent-cabinet/requests/{id} every 20 s (`urgent_cabinet_patient_lifecycle_controller.dart:48,881-890`); POST …/{id}/cancel + key | `MePatientUrgentCabinetTargetedRequestController.java:52,75` | REAL | y/n/y | urgent_cabinet_request_waiting_test |
| `.../urgent_cabinet_request_accepted_screen.dart` | in-shell | LifecycleController | Targeted repo | same poll; POST …/{id}/withdraw + key | `MePatientUrgentCabinetOperationalController.java:41` | REAL. `CONSULTATION_IN_PROGRESS`/`CARE_COMPLETED` are shown as text only (`:368-383`), which is the **consultation boundary** | y/n/y | urgent_cabinet_request_accepted_test, urgent_cabinet_patient_lifecycle_test |
| `.../urgent_cabinet_arrival_instructions_screen.dart` | in-shell | FlowController | none | none (snapshot) | — | REAL (projection) | n/n/y | urgent_cabinet_arrival_instructions_test |
| `.../urgent_cabinet_patient_qr_preview_screen.dart` | in-shell | LifecycleController | Targeted repo | POST /me/urgent-cabinet/requests/{id}/arrival-handoffs + key | `MePatientUrgentCabinetOperationalController.java:51` | REAL (+ debug-only scenarios) | y/n/y | urgent_cabinet_patient_qr_preview_test |
| `.../urgent_cabinet_request_recovery_screen.dart` | in-shell | Flow/Lifecycle | none confirmed | none (UNVERIFIED that `beginNewJourneyAfterTerminal` makes no call) | — | REAL (terminal) | n/n/y | urgent_cabinet_request_recovery_test |

**Production gate and fixture verdict.**
- `UrgentCabinetSubmissionActivationGate.p4Production` (`lib/main.dart:123`) sets all four flags to true (`urgent_cabinet_submission_activation_gate.dart:27-32`). It disables nothing.
- The production shell is built with no doctor source (`lib/main.dart:449-450`, `new_home_screen.dart:410`), so the directory, detail and confirmation screens use the real discovery repository.
- `urgent_cabinet_doctor_fixture.dart` (408 LOC) **cannot render in release**: its `forCurrentBuild()` factories have 0 callers in `lib/` and return Unavailable when `!kDebugMode` (`:371-382`). Its synthetic data still **ships in the binary**, because four production screens import it (`flow_shell:16`, `doctor_directory_screen:17`, `doctor_detail_screen:15`, `request_confirmation_screen:13`).

### a.6 Care requests (M05) and history

| Screen | Route / entry | VM | API | HTTP | Spring | Source | L/E/Err | Tests |
|---|---|---|---|---|---|---|---|---|
| `lib/features/request/provider_selection_screen.dart` | `/request-care`, `/provider-selection` `lib/main.dart:454-455`; centre button | none | none | none | — | STATIC (kiné and nurse disabled `:10`) | n/n/n | patient_care_navigation_test |
| `lib/features/request_flow/screens/request_flow_entry_screen.dart` | `/m05/request` `lib/main.dart:460` | RequestSubmissionController | none | none | — | wrapper | n/n/n | **none** |
| `.../doctor_cabinet_entry_screen.dart` | `/doctor/cabinet/who-needs-care` `lib/main.dart:461` | wraps WhoNeedsCare(doctor) | none | none | — | STATIC → DoctorDirectoryScreen | n/n/n | doctor_cabinet_navigation_test |
| `.../who_needs_care_screen.dart` | `/m05/who-needs-care` `lib/main.dart:463` | RequestSubmissionController, FamilyProvider, PatientBookingController | FamilyRepository | family list | `FamilyMemberController.java:42` | REAL (family) | n/n/n | who_needs_care_screen_test |
| `.../situation_screen.dart` | `/m05/situation` `lib/main.dart:468`; push `clinic_directory_screen.dart:180` | RequestSubmissionController, PatientClinicDirectoryController | PatientClinicApi | GET /patient/clinics/{id} | `clinic/api/PatientClinicDirectoryController.java:43` | REAL | UNVERIFIED | situation_screen_test |
| `.../pickup_screen.dart` | `/m05/pickup` `lib/main.dart:469` | RequestSubmissionController | none | none | — | DEVICE (`capturedAt = DateTime.now()` `:118,134,152`) | y/n/y | **none** |
| `.../review_screen.dart` | `/m05/review` `lib/main.dart:470` | RequestSubmissionController, PatientClinicDirectoryController | RequestRepository → RequestApi | POST /appointment-requests/clinic (body `requestId`); GET /patient/clinics/{id} | `request/api/PatientRequestController.java:113` | REAL | y/n/y | review_screen_test, request_core_test |
| `.../request_received_screen.dart` | `/m05/received` `lib/main.dart:471` | RequestSubmissionController | none | none | — | REAL (in-memory result) | n/n/n | **none** |
| `lib/features/request_history/presentation/my_requests_screen.dart` | `/m05/requests` `lib/main.dart:472`; `new_home_screen.dart:1253`; `patient_home_feed.dart:700` | PatientRequestsController | RequestApi | GET /appointment-requests?page&pageSize&filter (no polling) | `PatientRequestController.java:129` | REAL | y/y/y | request_history_widget_test, patient_requests_controller_test, request_history_contract_test |
| `.../patient_request_detail_screen.dart` | push `my_requests_screen.dart:178`; `request_received_screen.dart:63-65`; `post_auth_navigation.dart:117` | PatientRequestsController | RequestApi | GET /appointment-requests/{id}; POST …/{id}/cancel; POST …/{id}/information-response | `PatientRequestController.java:145,164,190` | REAL. Schedule-proposal accept/reject are **not wired** (§c, §g) | y/n/y | patient_request_status_matrix_test, patient_request_journey_test |

### a.7 Scheduled care and directories

| Screen | Route / entry | VM | API | HTTP | Spring | Source | L/E/Err | Tests |
|---|---|---|---|---|---|---|---|---|
| `lib/features/scheduled_care/presentation/patient_scheduled_care_screen.dart` | push `new_home_screen.dart:93-96` → `patient_appointments_screen.dart:35` (no controller injected → real screen) | PatientScheduledCareController | ScheduledCareRepository → PatientScheduledCareApi | GET /patient/scheduled-care (`scheduled_care_api.dart:151`); STOMP `/user/queue/scheduled-care` | `scheduledcare/api/PatientScheduledCareController.java:35`; `WebSocketConfig.java:38` | REAL | y/y/y | patient_scheduled_care_test |
| `.../pending_booking_request_screen.dart` | `ScheduledCareResourceResolver.openRequest` (`scheduled_care_resource_resolver.dart:26-31`) from the list, the inbox and a push tap | PatientBookingController | ScheduledCareApi | GET /doctor-booking-requests/{id}; POST …/cancel, …/proposals/{pid}/accept, …/decline (Idempotency-Key); GET /appointments/{id} | `PatientBookingRequestController.java:61,68,78,90`; `appointment/controller/AppointmentController.java:100` | REAL | y / n-a / partial (an initial-load failure shows "Demande indisponible." with no retry, `:150-152`) | scheduled_care_lifecycle_test, scheduled_care_foundation_test |
| `.../confirmed_scheduled_appointment_screen.dart` | resolver `openAppointment`; `pending_booking_request_screen.dart:118,135` | PatientBookingController | ScheduledCareApi, ScheduledAppointmentCancellationApi, PatientScheduledConsultationApi | GET /appointments/{id}; POST /appointments/{id}/cancel (key); GET /patient/appointments/{id}/consultation | `AppointmentController.java:100`; `ScheduledAppointmentCancellationController.java:36`; `PatientScheduledConsultationController.java:28` | REAL (+ PatientArtifactCard, a.3) | y / n-a / y | scheduled_care_lifecycle_test, patient_scheduled_care_test |
| `.../booking_review_screen.dart` | push `doctor_availability_sheet.dart:434` | PatientBookingController | ScheduledCareRepository | POST /doctor-booking-requests (body `requestId`, no header); reconcile GET | `PatientBookingRequestController.java:50` | REAL. **Slot sent +1 h (F1).** Pre-submit price comes from the directory DTO | y/y/y | doctor_detail_availability_test, scheduled_care_foundation_test |
| `lib/features/patient_doctor/presentation/doctor_directory_screen.dart` | `/m05/doctor-directory` `lib/main.dart:466`; push `who_needs_care_screen.dart:72` | DoctorDirectoryController | DoctorDirectoryApi | GET /doctors?q= | `DoctorDirectoryController.java:30` | **MIXED**: list REAL. Filters are STATIC and act on fields the mapper hard-codes (rating 0.0, empty lists: `doctor_directory_mapper.dart:17,28-36`), so "Mieux notés" and the language/insurance filters act on placeholders. `/doctors/search` is unused | y/y/y | doctor_detail_availability_test, doctor_cabinet_navigation_test |
| `.../doctor_detail_screen.dart` | push `doctor_directory_screen.dart:72`; nested `/m05/doctor-detail` | DoctorDirectoryController | DoctorDirectoryApi | GET /doctors/{id}; GET /appointments/availability/slots?doctorId&practiceLocationId&from&to | `DoctorDirectoryController.java:62`; `AvailabilityController.java:89` | MIXED: REAL, except STATIC portrait/gallery fallback (`doctor_presentation_metadata.dart:84-116`). openingHours, gallery and coverage are always `[]` (`mapper:210-218`) | y/y/y | doctor_detail_availability_test |
| `.../doctor_availability_sheet.dart` | sheet `doctor_detail_screen.dart:173` | DoctorDirectoryController | same | GET slots (31-day window) | `AvailabilityController.java:89` | REAL | y/y/y | doctor_detail_availability_test |
| `lib/features/patient_clinic/presentation/clinic_directory_screen.dart` | `/m05/clinic-directory` `lib/main.dart:464`; push `who_needs_care_screen.dart:76` | PatientClinicDirectoryController | PatientClinicApi | GET /patient/clinics?q&city&page&pageSize | `PatientClinicDirectoryController.java:30` | MIXED: list REAL; specialty, locality, distance and filters are STATIC (`clinic_card.dart:29-101`; `clinic_filter_model.dart:152-179`) | y/y/y | clinic_directory_screen_test |
| `.../clinic_detail_screen.dart` | push `clinic_directory_screen.dart:396` | PatientClinicDirectoryController | PatientClinicApi | GET /patient/clinics/{id} | `PatientClinicDirectoryController.java:43` | **MIXED**: REAL name, about, address, images and accepting flag. **STATIC** `ClinicPresentationCatalog.defaultClinic` (`clinic_presentation_metadata.dart:348-440`): clinic type, specialties, availability chips, 2 invented doctor names (`***`), insurers, facilities, hours, "24/7", languages, badges, distance and demo photos | y / n-a / y | clinic_detail_screen_test |

`lib/features/clinic/**` is professional-only and OUT OF SCOPE. A patient reaching `/clinic` gets "access unavailable" with no network call (`lib/features/clinic/application/clinic_context_controller.dart:112-120`).

### a.8 Notifications

| Screen | Route / entry | VM | API | HTTP | Spring | Source | L/E/Err | Tests |
|---|---|---|---|---|---|---|---|---|
| `lib/features/notifications/notifications_screen.dart` | `/notifications` `lib/main.dart:459`; bell `new_home_screen.dart:2786-2790` | NotificationCenterController | NotificationRepository → NotificationApi | GET /notifications; GET /notifications/unread-count; POST /notifications/{id}/read; POST /notifications/read-all; STOMP `/user/queue/notifications` | `notification/.../NotificationCenterController.java:27,62,68,76` | REAL (title and body are server-rendered FR templates `:448,:471`) | y/y/y | notification_center_test, p3_r5a_hardening_test |
| `.../presentation/notification_badge.dart` | `new_home_screen.dart:2786` | same | same | unread-count | `:62` | REAL (errors swallowed `notification_center_controller.dart:156-159`) | — | notification_center_test |
| (no UI) NotificationPushCoordinator | `lib/main.dart:153` | — | — | POST/DELETE /notifications/token {token, platform} | `DeviceTokenController.java:27,34` | REAL. UNVERIFIED: the `messaging.register()`/`onRegistered`/`unregister()` calls (`notification_push_coordinator.dart:48,73,94`) need a build against firebase_messaging ^17 | — | **none** |

**Screens with no test reference at all:** phone_input, otp_verification, onboarding (both), every security screen, vital_info, medications, both passport editors, document_viewer, edit_medical_data, PatientArtifactCard, request_flow_entry, pickup, request_received, NotificationPushCoordinator.

---

## b) Unreachable code

### b.1 Not import-reachable from `lib/main.dart` (patient side; 20 doctor files excluded)

| File | LOC | Note |
|---|---|---|
| lib/main_demo.dart | 120 | Separate entry. Imports `lib/demo/*` and `main.dart show OmniCareApp` |
| lib/main_doctor_urgent_cabinet_preview.dart | 164 | Separate entry (doctor preview) |
| lib/main_maps_smoke.dart | 20 | Separate entry |
| lib/main_p4_cabinet_synthetic.dart | 6 | Separate entry. Calls `app.startOmniCare` with a synthetic gate |
| lib/main_p4_recovery_preview.dart | 162 | Separate entry. Imports `urgent_cabinet_doctor_fixture.dart:9` |
| lib/demo/demo_auth_repository.dart · demo_http_adapter.dart · demo_token_storage.dart · demo_toolbar.dart | 165 · 338 · 18 · 174 | Only `main_demo.dart` imports them |
| lib/mock_data/mock_doctors.dart · mock_patients.dart · mock_reservations.dart | 104 · 77 · 28 | Imported only by unreachable APIs and repositories |
| lib/core/api/doctors_api.dart · medical_acts_api.dart · patients_api.dart · provider_me_api.dart · reservations_api.dart · storage_service.dart | 17 · 18 · 54 · 27 · 40 · 51 | Legacy mock APIs; `storage_service` reads `CLOUDINARY_*` env keys |
| lib/core/models/patient.dart · patient_models.dart · user.dart | 25 · 239 · 15 | |
| lib/core/network/retry_delay.dart; lib/core/utils/console_log_web.dart | 44 · 5 | |
| lib/core/config/p4_cabinet_local_development_activation.dart · p4_cabinet_synthetic_activation.dart | 107 · 103 | Used by alternate entries |
| lib/core/maps/* (provider_native, provider_web, javascript_loader*, synthetic_maps_smoke_screen) | 41 · 29 · 2 · 1 · 94 · 262 | Platform-conditional or smoke-only. **UNVERIFIED** whether conditional imports pull `*_web`/`*_native` into a release build; the graph script did not resolve `if (dart.library…)` |
| lib/core/auth/google_web_sign_in_button_web.dart; lib/features/auth/application/google_sign_in_session_web.dart | 204 · 18 | Same conditional-import caveat |
| lib/features/auth/email_input_screen.dart · forgot_password_screen.dart · language_selection_screen.dart · medical_data_welcome_screen.dart · population_selection_screen.dart | 222 · 222 · 218 · 239 · 161 | Orphan screens. `forgot_password` simulates its work with `Future.delayed` (`:34`) |
| lib/features/emergency/consultation_complete_screen.dart · consultation_qr_screen.dart · doctor_arriving_screen.dart · doctor_calling_screen.dart | 456 · 428 · 992 · 346 | Legacy consultation runtime (OUT OF SCOPE). Their routes map to the unavailable screen (`lib/main.dart:506-524`) |
| lib/features/emergency/doctor_matching.dart · doctor_selection_screen.dart · review_confirm_screen.dart | 321 · 1000 · 636 | Legacy |
| lib/features/home/consultation_detail_screen.dart · history_tab.dart · home_screen.dart | 1252 · 981 · 1116 | Legacy. history_tab is **not** reached via the passport tab, which uses its own `PassportHistoryTab` (`patient_passport_screen.dart:20,168`) |
| lib/features/notifications/appointment_confirmation_screen.dart · booking_confirmed_screen.dart | 633 · 376 | Legacy |
| lib/features/patient/prescription/patient_prescription_api.dart | 27 | Only importer is the unreachable `consultation_detail_screen.dart:8`. Its endpoint exists (`prescription/api/PatientPrescriptionController.java:24`) |
| lib/features/patient_clinic/presentation/widgets/clinic_gallery.dart | 145 | |
| lib/features/request/clinic_request_screen.dart · consultation_type_screen.dart · provider_list_screen.dart · provider_map_screen.dart · request_submitted_screen.dart · time_selection_screen.dart | 364 · 212 · 1456 · 418 · 280 · 994 | Legacy request flow |
| lib/features/request_core/data/clinic_target_models.dart | 72 | |
| lib/providers/reservation_provider.dart; lib/repositories/consultation_repository.dart · doctor_repository.dart · file_repository.dart · medical_act_repository.dart · medication_repository.dart · patient_repository.dart · reservation_repository.dart | 73 · 150 · 39 · 66 · 39 · 48 · 92 · 54 | Legacy repositories |

Totals: 87 unreachable files in `lib/` (20 under `features/doctor`). The patient-side unreachable LOC is about 21,000.

### b.2 Import-reachable but not navigable in production

| File | LOC | Why |
|---|---|---|
| lib/features/profile/vital_info_screen.dart → medications_screen.dart → medical_documents_screen.dart | 373 · 529 · 1652 | Registered routes (`lib/main.dart:423-437`) with no push site for `/medical-profile` |
| lib/features/patient_appointments/** (controller 155, detail 422, filter sheet 337, models + widgets ≈480) | ≈1,400 | Renders only when a controller is injected. The production caller passes none (`new_home_screen.dart:95`) |
| lib/features/onboarding/onboarding_complete_screen.dart | — | Reachable but STATIC (see a.1) |
| `DoctorDirectoryApi.bookAppointment` (`doctor_directory_api.dart:116-141`) → POST /appointments | — | DEAD: no caller, and **no backend endpoint** (`AuthWebSecurityConfig.java:225` denies POST /api/v1/appointments) |
| ≈15 private builders in `new_home_screen.dart` (see a.2) | — | Never invoked |

### b.3 Every production-reachable import of mock / fixture / static / demo code

| Importer (reachable) | Imports | Executed in release? |
|---|---|---|
| lib/core/api/medications_api.dart:1 | lib/mock_data/mock_medications.dart (166 LOC) | **YES**. Feeds `MedicationSearchField` in onboarding (`conversational_onboarding_screen.dart:1760`) and EditMedicalDataScreen (`edit_medical_data_screen.dart:501`) |
| lib/features/patient_passport/presentation/patient_passport_screen.dart:8 | data/patient_passport_static_data.dart (107) | **YES** (tab 3) |
| lib/repositories/user_repository.dart:6 | lib/mock_data/mock_users.dart (45) | No. Only when the API is null (`user_repository.dart:31`); production injects it (`lib/main.dart:285-287`) |
| lib/features/patient_appointments/application/patient_appointments_controller.dart:4 | data/patient_appointment_mock_data.dart (283) | No (branch never rendered, b.2), but compiled in |
| urgent_cabinet_flow_shell.dart:16 · doctor_directory_screen.dart:17 · doctor_detail_screen.dart:15 · request_confirmation_screen.dart:13 | urgent_cabinet_doctor_fixture.dart (408) | No (debug-gated), but compiled in |
| lib/core/api/consultations_api.dart:1 (doctor-shell only) | lib/mock_data/mock_consultations.dart (88) | Not from the patient UI |
| lib/core/api/files_api.dart:110-119 `uploadFile` | returns a `mock.cloudinary.com` URL | Callers are unreachable (`file_repository.dart:37`, `consultation_detail_screen.dart:210`) |
| none | lib/demo/** | `lib/demo/**` is never imported by production code |

**Build-time note.** `pubspec.yaml:113` bundles `.env` as a Flutter asset. Its keys are `API_BASE_URL`, `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_UPLOAD_PRESET` and `GOOGLE_MAPS_WEB_API_KEY` (values not read). Anything in it is extractable from a release artifact. Release builds take the API URL only from `--dart-define=OMNICARE_API_BASE_URL` (`app_environment.dart:25-45`).

---

## c) Contract check for REAL endpoints: mismatches only

Endpoints whose Dart model matches the Spring DTO (names, types, enums, nullability, dates) were checked and are listed at the end of this section.

| # | Endpoint | Aspect | Dart | Spring | Effect |
|---|---|---|---|---|---|
| C1 | POST /doctor-booking-requests | date/timezone | `requestedSlot.start` = `toTunisWallClock(utc)` = UTC + 1 h, still flagged UTC (`doctor_directory_mapper.dart:107,226-227`; `patient_booking_controller.dart:261-263`; `scheduled_care_models.dart:97`) | `Instant start/end`, re-validated against the slot grid | **Booking 1 h late**, or `SLOT_NO_LONGER_AVAILABLE`. Tests build slots with `start == startIso` (`test/scheduled_care_foundation_test.dart:542-560`), so they miss it |
| C2 | PATCH /profile/passport | field | sends `medicalInfo{chronicConditions,currentMedications}` (`account_api.dart:38-51`; `new_home_screen.dart:1718-1722`) | `UpdatePassportRequest` has only `bloodType, heightCm, weightKg` (`BE/profile/DTO/UpdatePassportRequest.java:9-15`). Unknown properties are ignored globally; only DocumentController enables FAIL_ON_UNKNOWN (`DocumentController.java:61`) | Conditions and meds are **silently lost** |
| C3 | PATCH /profile/passport, PATCH /profile/family-members/{id}/passport, POST /profile/onboarding/step/1 | enum | blood type `'-'` default (`edit_medical_data_screen.dart:75,111-112`; `new_home_screen.dart:76`); `'IDK'` option (`conversational_onboarding_screen.dart:48,940`) | A±, B±, AB±, O±, blank or `unknown` only (`BE/mrs/MrsMedicalDataService.java:27-29,265-273`) | 400 INVALID_INPUT. EditMedicalData has no catch, so there is no user feedback |
| C4 | GET /me/urgent-cabinet/requests/* | enum `state` | CABINET_PENDING, CABINET_COMMITTED, CABINET_CANCELLED (`urgent_cabinet_targeted_request_models.dart:203-206`) | `UrgentAttemptState` also has **CABINET_CREATED** (+ HOME_*) (`BE/urgentfoundation/domain/UrgentAttemptState.java`) | FormatException → request "unavailable" |
| C5 | same | enum `terminalReason` | 4 values (`models:261-265`) | + **LEGACY_LIFECYCLE_REMEDIATION** (`BE/urgentcabinetrequest/UrgentCabinetTerminalReason.java:8`; DB allows it) | FormatException |
| C6 | same | `clinicalPhase` invariant | `ARRIVED_WAITING_FOR_DOCTOR` requires `consultationId == null` (`models:540-544`) | Returned with a consultation id when the consultation is ABORTED (`BE/urgentcabinetrequest/UrgentCabinetPatientClinicalProjection.java:12-28`) | FormatException. The COMPLETED/non-COMPLETED case is UNVERIFIED |
| C7 | POST /me/urgent-cabinet/requests | money | `acknowledgedQuote.amountTnd` = millimes/1000 as a JSON **double** (`models:81`) | `BigDecimal @Digits(8,3)` | Round-trips today; fragile (not sent as a string) |
| C8 | POST /me/urgent-cabinet/discovery/search | length | no max length on the query (`patient_doctor/presentation/widgets/doctor_search_field.dart`) | `@Size(max=120)` | over 120 chars → 400 → "invalid response" |
| C9 | urgent-cabinet discovery | error codes | expects 403 `URGENT_RUNTIME_DEVELOPMENT_ONLY` / `URGENT_RUNTIME_ACCESS_DISABLED` (`urgent_cabinet_discovery_repository.dart:79-80`) | Never emitted; the backend sends 404 `URGENT_CABINET_REQUEST_UNAVAILABLE`/`NOT_AUTHORIZED` | Dead branch; 404 is mapped differently for search and for detail |
| C10 | GET /appointment-requests[/{id}] | enum | `PatientRequestStatus` 10 values (`request_vocabulary.dart:78-91`) | 11, including **NO_SHOW** (`BE/request/domain/PatientRequestStatus.java`) | NO_SHOW → `unknown` (non-terminal) |
| C11 | same | actions + field | actions CANCEL, PROVIDE_INFORMATION; `scheduleProposal` not parsed (`request_models.dart:173-208`) | + ACCEPT_SCHEDULE_PROPOSAL, REJECT_SCHEDULE_PROPOSAL; `scheduleProposal` summary (`BE/request/domain/PatientRequestAction.java`; `PatientRequestResponse.java`) | The proposal is invisible and cannot be answered |
| C12 | GET /appointments/{id} | shape | `ConfirmedScheduledAppointment.fromJson` (`scheduled_care_models.dart:579-608`) | Falls back to the legacy `AppointmentResponse` (`startTime`, `quotedPriceTnd`…) for non-scheduled-care appointments (`AppointmentController.java:105-108`) | ScheduledCareContractException |
| C13 | GET /patient/scheduled-care | nullability | cabinet address, city and governorate required (`patient_scheduled_care_models.dart:110-114`) | SQL does not coalesce them (`ScheduledCareReadRepository.java:165-167,212-213`) | One null breaks the whole page (real data UNVERIFIED) |
| C14 | GET /doctor-booking-requests/{id} | nullability | all cabinet strings required (`scheduled_care_models.dart:150-183`) | raw `*_snapshot` columns (`PatientDoctorBookingRequestQueryService.java:89-92`) | Same risk (UNVERIFIED) |
| C15 | STOMP `/user/queue/scheduled-care` | enum | 12 event types (`scheduled_care_event.dart:3-17`) | 17 (`ScheduledCareEventType.java:4-20`); missing CLINICAL_ORDER_UPDATED, PRESCRIPTION_UPDATED, PRESCRIPTION_FINALIZED, ARTIFACT_UPDATED, DOCUMENT_READY | Mapped to `unknown`; list-only refresh |
| C16 | GET /notifications?category= | enum | upper-cases any string (`notification_api.dart:214`) | `valueOf` → IllegalArgumentException → **500** (`NotificationCenterController.java:42`; `GlobalExceptionHandler.java:185`) | Only if an invalid category is sent |
| C17 | auth role | enum | PATIENT, DOCTOR, CLINIC_* (`auth_role_family.dart:13-27`) | Role also has NURSE, KINE, SECRETARY, ADMIN | Those accounts are logged out (by design; noted) |
| C18 | GET /profile; GET /profile/family-members | nullability | `displayName` and family `gender` required (`patient_profile.dart:76-94`; `family_models.dart:70`) | `displayName` is a DB-generated column (`UserProfile.java:39-40`); family `gender` column is nullable (`FamilyMember.java:29-30`) | A null would block login or the family list (UNVERIFIED) |
| C19 | GET /documents | pagination + display | sends `limit=50`, never a cursor; shows raw `documentType`/`status` (`documents_api.dart:319-326`; `medical_documents_screen.dart:1593-1603`) | cursor supported; no `displayName` in `DocumentResponse` (`DocumentResponse.java:11-23`) | Only the first 50 documents; the user-entered name is never shown |
| C20 | GET /me/consultations/{id}/medical-sharing/access | string | `_optionalString` throws on `""` (`direct_patient_authorization.dart:109-115`) | `specialty` passed raw (`DirectPatientAuthorizationService.java:158-160`) | UNVERIFIED |
| C21 | Money in scheduled care and the directory | decimal | `double` (`scheduled_care_models.dart:728-732`; `doctor_directory_models.dart:51,124`) | `BigDecimal`, `NUMERIC(10,2)` | Display only today; "TND" is hard-coded on both sides |

**Checked and matching:**
- All `/auth/*` session, OTP, Google, password and phone-change DTOs, including the `ClientPlatform` enum.
- `/auth/me`, `/auth/devices`, `/auth/history`.
- `/profile` GET/PATCH and `/profile/avatar`.
- `/profile/family-members` CRUD, including the relationship enum.
- Onboarding step field names.
- `/patient/medical-sharing/*` (policy, consultation state LOCKED/SHAREABLE, QR).
- `/me/consultations/*/medical-sharing/*` (status enum).
- `/patient/consultations/{cid}/artifacts` (ArtifactType).
- `/documents` (status enum, recovery state, upload metadata, mime/size 20 MiB).
- `/professional-access-requests`.
- Urgent-cabinet discovery (body-area codes, distance method) and the submit, cancel, withdraw and handoff bodies.
- M05 submit, list and cancel; the info-request enums.
- Booking-request status, actions and cancellation reasons.
- `AppointmentStatus`; slots (timezone Africa/Tunis on both sides).
- `/patient/clinics`; `/doctors`; `/notifications` page; the realtime envelopes.
- Instants: Spring writes ISO-8601 `…Z` (no Jackson override; Hibernate `jdbc.time_zone: UTC`, `BE-res/application.yaml:29`), and Dart parses with `toUtc()`.

---

## d) Cross-cutting counts (patient-reachable files only, 276)

### d.1 Hardcoded user-visible strings

Method: regex over widget contexts (`Text(`, `label:`, `title:`, `hintText:`, `message:`, `content:`, `tooltip:` and similar, multi-line). Classified FR when accents or French stop-words are present, EN on English stop-words, otherwise ambiguous. Approximate; the full row list was kept in scratch.

| Total | FR | EN | Ambiguous | Files |
|---|---|---|---|---|
| ≈1,476 | 870 | 254 | 352 | 117 |

- `AppLocalizations` is used only in `lib/features/auth/reset_password_screen.dart` among patient screens. `lib/l10n/app_localizations.dart` is 538 LOC. The default locale is `en` unless the profile or onboarding sets one (`lib/main.dart:372-378`).
- **English-dominant patient files** (French app target): `request_history/presentation/patient_request_detail_screen.dart` (28 EN), `patient_clinic/presentation/clinic_detail_screen.dart` (20), `onboarding/conversational_onboarding_screen.dart` (19, incl. `'Failed to save: …'` `:375`), `request_history/presentation/request_status_copy.dart` (19), `request_core/data/request_failure.dart` (18), `request_flow/screens/situation_screen.dart` (16), `pickup_screen.dart` (16), `profile/medical_documents_screen.dart` (16), `new_home_screen.dart` (15 EN / 46 FR), `profile/medications_screen.dart` (9), `patient_clinic/presentation/widgets/clinic_filter_sheet.dart` (8), `doctor_directory_failure.dart` (6), `patient_clinic_failure.dart` (5), `request_flow/screens/review_screen.dart`, `request_received_screen.dart`, `who_needs_care_screen.dart`, `patient/artifact/patient_artifact_card.dart`.
- **Largest FR files**: `profile/patient_profile_screen.dart` (53), `home/patient_home_feed.dart` (55), `new_home_screen.dart` (46), `urgent_cabinet_request_waiting_screen.dart` (30), `emergency_request_step3.dart` (28), `urgent_cabinet_request_recovery_screen.dart` (28), `security/phone_change_screen.dart` (28).
- The whole M05 request flow, the request history and the clinic directory are English; urgent cabinet, scheduled care, passport and security are French.

### d.2 `DateTime.now()`: 54 call sites

| Category | Sites |
|---|---|
| Sent to the server or part of server identity | `request_flow/screens/pickup_screen.dart:118,134,152` (`capturedAt`, part of the server idempotency fingerprint `BE/request/application/PickupLocationFingerprint.java:37`); `profile/medical_documents_screen.dart:389` (`documentDate`); `onboarding/conversational_onboarding_screen.dart:359` (med `startDate`); `core/models/patient_profile.dart:190` (`updatedAt` in the local copy) |
| Compared with server instants (skew-sensitive) | `auth/data/auth_repository.dart:314,319` (token expiry); `core/network/auth_refresh_coordinator.dart:107`; `notifications/application/notification_navigation_resolver.dart:28,116`; `notifications/domain/notification_models.dart:59`; `notifications/notifications_screen.dart:528`; `scheduled_care/application/patient_booking_controller.dart:340`; `scheduled_care/presentation/confirmed_scheduled_appointment_screen.dart:167`; `scheduled_care/presentation/pending_booking_request_screen.dart:65`; `patient_doctor/application/doctor_directory_controller.dart:186,206,223,240`; `patient_doctor/data/doctor_directory_mapper.dart:155`; `patient_doctor/presentation/doctor_availability_sheet.dart:52,58`; `patient_doctor/presentation/doctor_detail_screen.dart:873`; `scheduled_care/presentation/patient_scheduled_care_screen.dart:602`; `emergency/urgent_cabinet/urgent_cabinet_flow_controller.dart:278`; `emergency/urgent_cabinet/urgent_cabinet_request_review.dart:293` (no-op in prod: `expiresAt` is never set) |
| Local IDs (collision-prone) | `home/edit_medical_data_screen.dart:173` (`doc-<ms>`); `core/services/file_picker_service.dart:28` (temp file name); `onboarding/onboarding_complete_screen.dart:44` (QR payload with email/phone + ms) |
| Local UI and validation (age, calendar, timers) | `core/models/family_models.dart:54`; `auth/signup_screen.dart:52,455`; `home/add_family_member_screen.dart:65`; `onboarding/conversational_onboarding_screen.dart:397,498`; `profile/patient_profile_screen.dart:1710`; `security/phone_change_screen.dart:567`; `profile/medical_documents_screen.dart:477,827,918,1562`; `security/app_lock_gate.dart:36,40`; `security/app_lock_service.dart:117,119,256`; `request_core/application/request_submission_controller.dart:517`; `request_core/identity/in_flight_request_store.dart:281`; `patient_appointments/**` (`controller:82`, `mock_data:5`, `filter_sheet:65`; not rendered) |
| Professional-only (out of scope) | `features/clinic/screens/clinic_operational_list_screens.dart:512`, `clinic_task_detail_screen.dart:1116` |

### d.3 `print` / `debugPrint`: 18 sites

- `lib/core/utils/console_log_stub.dart:2` (`print`).
- `lib/core/utils/logger.dart:7,11,15,19,23,27,29,32`: `debugPrint` with **error and stack**. Release behaviour depends on the caller; `debugPrint` is not stripped in release.
- `lib/main.dart:188` (runtimeType only).
- `lib/services/notification_service.dart:255,292,296,333,337,379,392,427`: legacy "Doctors Found / Doctor On Way / Doctor Arrived / test" notification logs.

### d.4 Idempotency-Key builders

| Site | Format | Length | Persisted / reused | Server rule |
|---|---|---|---|---|
| `core/api/documents_api.dart:654-661` (upload `:369`, delete `:607`) | `upload:`/`delete:` + 32 hex (`Random.secure`, `:309`) | 39 | Upload persisted 24 h in secure storage for recovery (`medical_document_upload_controller.dart:21,53-67`) | `[A-Za-z0-9._:-]{8,128}` (`BE/profile/service/DocumentService.java:30`) ✓ |
| `emergency/urgent_cabinet/urgent_cabinet_submission_coordinator.dart:260,484-485,507-512` | UUIDv4 (`core/utils/uuid_v4.dart:14-30`) | 36 | **Persisted before POST**, reused for recovery | `@Size(max=128)` ✓ |
| `emergency/urgent_cabinet/urgent_cabinet_patient_lifecycle_controller.dart:456-457` (cancel), `:567-568` (withdraw), `:624-625` (arrival QR) | UUIDv4 | 36 | Memory only; stable per request | `@Size(min=32,max=128)` (`MePatientUrgentCabinetOperationalController.java:45,55`) ✓ |
| `scheduled_care/data/scheduled_care_api.dart:90-102,190-202`; keys from `patient_booking_controller.dart:110` | UUIDv4 | 36 | Pending mutation held in the controller | `@Size(max=128)` ✓ |
| `patient_passport/sharing/medical_sharing_api.dart:131-144`; keys `medical_sharing_controller.dart:69,119` | UUIDv4 | 36 | New per call (no retry reuse) | `@Size(max=128)` ✓ |
| `patient_passport/sharing/medical_share_qr_api.dart:34,53-60`; `medical_share_qr_controller.dart:20` | UUIDv4 | 36 | Reused on retry | ✓ |
| `patient_passport/sharing/direct_patient_authorization_api.dart:108,138-145`; `..._controller.dart:89,93` | UUIDv4 | 36 | New per call | ✓ |
| Body `requestId` (not a header): M05 `request_core/identity/request_operation_id.dart:67-72`; booking `patient_booking_controller.dart:109` | UUIDv4 | 36 | M05 persisted (`in_flight_request_store.dart:92,180-196`) | `@NotNull UUID` ✓ |
| `core/network/request_replay_policy.dart:42` | reads the header to allow replay | — | — | — |

### d.5 File bytes held in memory

| Site | What | Cap |
|---|---|---|
| `profile/medical_documents_screen.dart:242,361` → `core/api/documents_api.dart:258,333,433-434` | `withData: kIsWeb`, so bytes only on web; native streams with `fromFile`. Bytes are retained on the operation for retry | 20 MiB (`documents_api.dart:299`) |
| `core/api/files_api.dart:55,66` | Avatar `readAsBytes()` → `MultipartFile.fromBytes` | 8 MiB (`:32`); picker 2048×2048 |
| `patient/artifact/patient_artifact_card.dart:75-85` + `doctor/artifact/artifact_api.dart:134-139` | Whole artifact PDF as `Uint8List`, then `FilePicker.saveFile(bytes:)` | **No client cap** |

### d.6 `ListView(children: …)` over server data

- `lib/features/security/device_management_screen.dart:37` (iterates `provider.devices` at `:50`)
- `lib/features/security/login_history_screen.dart:46` (iterates `provider.history` at `:75`; server-paged)
- `lib/features/patient_doctor/presentation/doctor_availability_sheet.dart:388` (slots of the visible month at `:393,408`)
- `lib/features/patient_doctor/presentation/doctor_detail_screen.dart:891,1107` (days, equipment)

These lists are small or bounded in practice. Every other `ListView(children:)` in the 26 patient sites iterates local constants. Long server lists use `ListView.separated`/`builder` (`urgent_cabinet_doctor_directory_screen.dart:457`, `my_requests_screen.dart:98`).

### d.7 Nested loops over server lists (O(n²) candidates)

None unbounded. Candidates for the record:
- `patient_doctor/presentation/doctor_filter_model.dart:310-345`: per doctor, `filters.x.any(doctor.list.contains)` with List lookups → O(doctors × filters × list).
- `patient_clinic/presentation/clinic_filter_model.dart:259-275`: per clinic, careNeeds × substring scan.
- `features/home/edit_medical_data_screen.dart:377-378`: conditions × `List.contains`.
- `patient_appointments/presentation/patient_appointments_screen.dart:319-329`: year/month/item grouping, linear overall; not rendered.
- `patient_home_feed.dart:1701`: sections × items over local constants.

---

## e) Push and notifications: backend → patient vs app routing

Mechanics:
- The inbox `type` is the semantic outbox type (`NotificationOutboxWorkService.java:194,207`).
- **FCM data `type` is the TEMPLATE type** (`FcmDispatcher.java:116,130`), produced by aliasing (`NotificationService.java:157-171`).
- Routing: inbox tap goes through `notifications_screen.dart:104-158` → `notification_navigation_resolver.dart:65-89,163-252`. Push or local tap goes through `services/notification_service.dart:79-120` → `lib/main.dart:620-664`.

| Type (emitted to PATIENT) | Emitter | Inbox tap | Push tap | Payload |
|---|---|---|---|---|
| APPOINTMENT_CONFIRMED | `DoctorBookingDecisionWriter.java:103`; `SecretaryAppointmentService.java:110` | → ConfirmedScheduledAppointmentScreen via `appointment_id` (resolver `:204-208`). The secretary emission has no `appointment_id` → "Cette destination n'est pas disponible." | same | appointment_id, request_id, appointment_date (raw Instant) |
| APPOINTMENT_CANCELLED_BY_PROFESSIONAL | `ScheduledAppointmentCancellationWriter.java:93`; `BookingService.java:87`; `SecretaryAppointmentService.java:172` | → appointment if `appointment_id` is present (`:214-218`); the legacy and secretary emissions have none → unavailable | same | appointment_id?, appointment_date, doctor_name="Médecin", reason_code |
| DOCTOR_BOOKING_TIME_PROPOSED | `DoctorBookingDecisionWriter.java:169` | → PendingBookingRequestScreen (`:169-173`) | **Not routed**: FCM type is `APPOINTMENT_RESCHEDULED` | request_id, appointment_date |
| DOCTOR_BOOKING_REQUEST_DECLINED | `DoctorBookingDecisionWriter.java:214` | → booking request (`:174-178`) | **Not routed**: alias `APPOINTMENT_CANCELLED_BY_PROFESSIONAL` needs `appointment_id` (`notification_service.dart:106-107`) | request_id, doctor_name, reason_code |
| DOCTOR_BOOKING_REQUEST_EXPIRED | `BookingRequestExpiryService.java:217` | → booking request (`:194-198`) | **Not routed** (same alias) | request_id, expiry_reason, expired_at |
| URGENT_CABINET_REQUEST_ACCEPTED / DECLINED / EXPIRED / CANCELLED | `UrgentCabinetNotificationOutbox.java:25-60` (callers `UrgentCabinetDecisionWriter.java:195,199,242`; `UrgentCabinetLifecycleWriter.java:106,158`) | → lifecycle recovery → `/urgent-cabinet/care-subject` | same (`lib/main.dart:650-664`) | destination, request_id, outcome |
| APPOINTMENT_RESCHEDULED | `SecretaryAppointmentService.java:146` | Not routed | Not routed | previous/new appointment_date |
| APPOINTMENT_REMINDER_24H / _2H | `AppointmentReminderWorker.java:47,80` | Not routed | Not routed | **empty**, so template placeholders stay literal (`TemplateEngine.java:33`) |
| URGENT_DOCTOR_SELECTED · URGENT_REQUEST_NO_DOCTORS · URGENT_DOCTOR_ARRIVED | `UrgentRequestService.java:193,243,375`; `UrgentRequestTimeoutWorker.java:75,163` | Not routed (legacy urgent) | Not routed | doctor_name / none |
| CLINIC_SCHEDULE_PROPOSED · CLINIC_APPOINTMENT_RESCHEDULED · CLINIC_APPOINTMENT_CONFIRMED · CLINIC_RESCHEDULE_PROPOSED · CLINIC_SIGNIFICANT_DELAY · CLINIC_APPOINTMENT_CANCELLED · CLINIC_PATIENT_NO_SHOW_OUTCOME · CLINIC_CASE_COMPLETED | `ClinicCoordinationFinalizationService.java:257`; `ClinicScheduleConvergenceService.java:269,282`; `ClinicScheduleManagementService.java:104,158`; `ClinicCaseCancellationService.java:135,178`; `ClinicCaseClosureService.java:232` | **Not routed** (8 types) | Not routed | clinic ids, schedule revisions |

Notes:
- **Routed: 9 types. Not routed: 13 types**, plus 3 types whose push path breaks.
- Template text is server-rendered French, but dates are raw `Instant.toString()` (`DoctorBookingDecisionWriter.java:106,172,219`) or UTC `dd/MM/yyyy HH:mm` (`BookingService.java:37-38`), never local time.
- Defined in `NotificationType.java:16-97` but never emitted: MEDICATION_*, PASSPORT_*, KINE_*, NURSE_*, NEW_MESSAGE/INCOMING_CALL/MISSED_CALL and others.
- **Foreground local notifications.** `NotificationService` still carries legacy "Doctors Found / Doctor On Way / Doctor Arrived" helpers (`services/notification_service.dart:255-427`). UNVERIFIED whether any reachable code calls them.

---

## f) Error handling

### f.1 Backend envelopes (five shapes)

1. `ErrorResponse{code, message, timestamp, fieldErrors, requestId?}`: `BE/shared/error/ErrorResponse.java:13-19`, produced by `GlobalExceptionHandler.java:32-209` and `SecurityErrorResponseWriter.java:29-38` (most 401/403). Messages are **English** (`ErrorCode.java:8-24`).
2. Session-limit map `{code, message, timestamp, activeSessions}` (`GlobalExceptionHandler.java:225-236`).
3. RFC 9457 `ProblemDetail` + `errorCode, requestId, timestamp`: BookingRequest (`:26,68-74`), Availability (`:25-28`), Clinic (`:29-33,181-187`), Consultation, Artifact, MedicalSharing, Prescription, Request, and the global `MrsProblemDetailHandler.java:21,45-47`.
4. `ProblemDetail` with **`code`** instead of `errorCode`: CareCapability (`:109-113`, used by urgent cabinet), Coverage, Equipment, PracticeLocation, ProfessionalQualification.
5. Security problem map `{type,title,status,detail,instance,code,requestId,timestamp}` for `/me/urgent-*` and other `/me/*` professional paths (`SecurityErrorResponseWriter.java:41-89`).

### f.2 App parsers

| Parser | Reads | Used by |
|---|---|---|
| `ApiErrorResponse.fromJson` (`auth/data/models/auth_dtos.dart:49-72`), requires `code`+`message` | envelope 1 only. A ProblemDetail body → "Unexpected server error response." | auth, `account_api.dart:132-158`, `family_api.dart:153-176`, `files_api.dart:128-152` |
| `ApiException` (`core/network/api_exception.dart:1-19`); `apiErrorMessage(e)` = `e.toString()` (`core/api/api_error_utils.dart:1-3`) | message pass-through | onboarding, legacy |
| `scheduled_care_failure.dart:188-192` | `errorCode ?? code` → local FR | scheduled care |
| `medical_sharing_api.dart:154-165` | `errorCode ?? code`, **`detail ?? message`** | sharing |
| `medical_share_qr_api.dart:74`; `direct_patient_authorization_api.dart:154-165` | `errorCode ?? code` → local | QR, direct authorisation |
| `urgent_cabinet_targeted_request_repository.dart:546-550` | `code` → local FR | urgent cabinet |
| `patient_clinic_failure.dart:71-91`, `doctor_directory_failure.dart:79-101`, `notification_repository.dart:21-59` | HTTP status only → local (EN for clinic/doctor) | directories, inbox |
| `account_security_api.dart:365-381`, `professional_access_request_api.dart:18-29` | `message`, `code`, `fieldErrors` | security, professional request |
| `documents_api.dart:695-775` | `code` → local EN | documents |
| `auth_error_messages.dart:29-80` | code → local | auth |
| `request_failure.dart` | code → local EN | M05 |

### f.3 Server `message`/`detail` text reaching a patient widget

1. `professional_access_request_screen.dart:71` → `Text` `:266`
2. `account_security_provider.dart:336` → `device_management_screen.dart:42-45`
3. `account_security_screen.dart:353,582` (`error.toString()`) → `:268,:467`
4. `medical_sharing_controller.dart:176-185` → `medical_sharing_settings_sheet.dart:159,211,371`
5. `user_provider.dart:284-288` → `new_home_screen.dart:238,1202-1203`
6. `family_provider.dart:62,206-218` → `new_home_screen.dart:149,1216`; `add_family_member_screen.dart:422-425`. Server `fieldErrors` → `add_family_member_screen.dart:142,279-280,320,398,495`
7. `patient_profile_screen.dart:2058-2062` → `:1684-1686`; fieldErrors `:1604,1615,1701`
8. `conversational_onboarding_screen.dart:375`: `'Failed to save: ${apiErrorMessage(e)}'`
9. `new_home_screen.dart:185`: `Text(e.toString())` on logout (exception type UNVERIFIED)

Not error text, but server text: notification `titleFr`/`bodyFr` (`notifications_screen.dart:448,471`; `notification_service.dart:169,197-198,219,247-248`).

---

## g) Backend gaps (patient-side needs with no usable endpoint)

| # | Need (screen) | Backend state | Verdict |
|---|---|---|---|
| G1 | Urgent CABINET in production (urgent_cabinet/**) | Modes `DISABLED`/`LOCAL_DEVELOPMENT` + allow-list only (`UrgentCabinetTargetedAccessPolicy.java:24-51`; `UrgentCabinetAuthorizationMode.java:3-6`; `BE-res/application-prod.yaml:34`) | **MISSING production authorisation mode** |
| G2 | Patient medications list/CRUD (passport tab, Ma Santé, onboarding) | `PassportController` `/api/v1/passport/{patientId}/medications` (GET/POST/DELETE `:139,151,179`, PATIENT) but **denied** by `anyRequest().denyAll()` (`AuthWebSecurityConfig.java:280`; no matcher). No update. MRS `GET /internal/mrs/patients/{id}/medications` (`MRS/internal/api/medical_records.go:184-190`) is not proxied | **Effectively MISSING** |
| G3 | Medication catalog search (MedicationSearchField) | No drug/DCI search endpoint | **MISSING** |
| G4 | Patient medical data read (passport tab, Ma Santé) | `GET/PATCH /profile/medical-data` exists (`ProfileController.java:78,88`; blood type, allergies, conditions, measurements, no meds) but **the app never calls it** | App gap (endpoint exists) |
| G5 | Consultation history for the patient (passport history tab) | Only `GET /patient/scheduled-care?bucket=PAST` and `GET /patient/appointments/{id}/consultation`. MRS `consultation-history` (`MRS/internal/api/consultation_completion.go:24`) is not proxied. `/patients/{id}/chart/consultations` is DOCTOR/SECRETARY | **MISSING** (general history across urgent, home, cabinet and clinic) |
| G6 | Finalized artifacts (prescriptions, reports, certificates) | `/patient/consultations/{cid}/artifacts[/{aid}[/download]]` + `/patient/consultations/{cid}/prescription` (PATIENT) | PRESENT, per consultation only. There is **no "all my documents/artifacts" list** |
| G7 | Medical documents list, status and view (Ma Santé docs, passport docs tab, document viewer) | list + status PRESENT (`DocumentController.java:83,104`). `GET /documents/{id}/download` is **always FORBIDDEN** (`:141-146`). No patient view/preview endpoint (preview is DOCTOR/SECRETARY, `PatientChartController.java:126,137`). **SSE events: MRS route missing** (`HttpMrsDocumentEventClient.java:74-76` vs `MRS/internal/api/documents.go:63-76`) | View/download MISSING; live status BROKEN upstream |
| G8 | Forgot/reset password while logged out | Only authenticated `/auth/password/change` and Google `/auth/password/set` | **MISSING** (there is also no UI entry today) |
| G9 | Home-feed content (stats, referral, OmniBand, articles, support) | Nothing | **MISSING** (product decision: drop vs build) |
| G10 | Family-member medical data (family detail) | `FamilyMemberResponse` has no medical fields; the family passport endpoint only takes bloodType/height/weight. `patientId` is exposed (`FamilyMemberResponse.java:20`); whether the account holder may use `/passport/{patientId}/*` or `/profile/medical-data` for it is UNVERIFIED | MISSING / UNVERIFIED |
| G11 | Patient realtime for urgent cabinet and M05 | Polling only (20 s); STOMP channels are scheduled-care and notifications only (`authenticated_realtime_transport.dart:149-150`) | Optional gap |
| G12 | Clinic metadata shown in clinic detail (type, specialties, hours, insurers, doctors, facilities) | Not in `PatientClinicDetailResponse` | MISSING (or remove STATIC from the UI) |
| G13 | Doctor rating, languages, insurance, age group, gallery, opening hours (directory filters and detail) | Not in DTOs; `education`/`certifications`/`careCapabilities` exist but are unparsed | Partly MISSING, partly app gap |

**Backend endpoints that exist but are unwired in the app** (app gaps, not backend gaps):
- `/me/urgent-home/*` (HOME urgent)
- `POST /appointment-requests/{id}/schedule-proposal/accept|reject` (`PatientRequestController.java:204,214`)
- `GET /appointment-requests/{id}/information-request` (Dart method `request_api.dart:119-128`, 0 callers)
- `POST /profile/onboarding/skip`
- `GET/PATCH /profile/medical-data`
- `DELETE /account`
- `POST /auth/sessions/{id}/revoke`
- `GET /me/account-security`
- `GET /profile/family-members/{id}`
- `GET /doctors/search`

---

## Proposed wiring order (phases 1–8)

**The roadmap could not be compared.** `claude/OmniCare_G2_Patient_Flutter_Roadmap.md` does not exist anywhere under `/Users/rouge/Desktop/omnicare` (searched by name and by `*patient*roadmap*` / `*G2*`). Its phases 1–8 therefore could not be confirmed or challenged line by line (**UNVERIFIED**). The order below is derived from the evidence and is offered for comparison once the roadmap is supplied.

| Phase | Content | Why this position | Blockers |
|---|---|---|---|
| 1 | **Correctness fixes on already-REAL flows**: C1 (slot +1 h), C3 (blood-type sentinels + missing catch), C2 (stop sending `medicalInfo`), C4–C6 (urgent-cabinet enums/phase), C10–C11 (NO_SHOW + schedule-proposal parsing), C8 (query max length), F7 (push alias routing) | Real users hit these today; no new UI needed | C11 accept/reject: **NO UI** (see below); backend fix for F7 or app alias mapping (decision) |
| 2 | **Honest states**: replace FIXTURE/STATIC with REAL or "indisponible" on the home feed (`patient_home_feed.dart`), Ma Santé documents, document viewer DEAD buttons, clinic-detail STATIC catalog, doctor-detail portrait catalog, doctor filters on placeholder fields | The G-2 "done" rule: no fixture or mock visible | Product decision per block (G9, G12, G13) |
| 3 | **Medical record (tab 3) + Ma Santé read path**: wire `GET /profile/medical-data` (+ PATCH for allergies/conditions) into PatientPassportScreen and Ma Santé; family selector REAL only | The largest STATIC surface; the endpoint exists (G4) | G2 (medications) blocks the meds card → "indisponible" until fixed |
| 4 | **Documents**: give `/medical-documents` an entry point from existing UI (Ma Santé "documents" or passport documents tab), add cursor pagination, show the name | REAL code exists but is unreachable (F6) | **No existing navigation control is explicitly labelled for it** (see below); G7 view/download; MRS SSE |
| 5 | **Medications**: backend security matcher + update endpoint (G2), catalog search (G3); wire the onboarding/edit search, passport meds card | Depends on backend | G2, G3 (backend) |
| 6 | **Requests and scheduling completion**: schedule-proposal accept/reject (C11), information-request GET, C12–C14 hardening, scheduled-care realtime events (C15) | REAL flows, incomplete | Proposal UI does not exist (NO UI) |
| 7 | **Notifications**: route the 13 unrouted patient types to existing screens where one exists; else inbox only; reminder payloads; localised dates | Depends on phases 1 and 6 | CLINIC_* targets: a patient clinic-case screen **does not exist** (NO UI) |
| 8 | **Cross-cutting and gate**: one error envelope parser (5 shapes), no server text in widgets, l10n FR/EN consistency, `debugPrint` policy, artifact PDF cap, `.env` asset removal, delete or quarantine unreachable code (b.1), tests for untested screens; the release build runs the G-2 gate | Last, because it touches everything | G-2 gate definition is missing (open question) |

**Scope-dependent (not ordered):** urgent CABINET (G1, backend) and urgent HOME (F9, wiring the existing backend vs keeping "indisponible").

### Functions with no existing UI (we will not invent UI)

| Function | Where it would belong | Evidence |
|---|---|---|
| Accept/reject a clinic schedule proposal (M05) | `patient_request_detail_screen.dart` | No widget renders `scheduleProposal`; actions dropped (`request_models.dart:196-208`) |
| Answer the information-request GET (reading the question) | request detail | 0 callers of `request_api.dart:119-128`. A response form exists, so UNVERIFIED whether the GET is needed |
| Medical-documents entry point | Ma Santé / passport docs tab | Only the orphan chain pushes `/medical-documents`. A Ma Santé "documents" section and "+" exist but are bound to static data. **Ambiguous** whether re-binding counts as "no UI change" (open question) |
| Forgot password | login | No link; the orphan `forgot_password_screen.dart` simulates its work |
| Account deletion | profile | `DELETE /account` has no UI |
| View or download a medical document | document viewer | Backend forbids download; the viewer is a placeholder |
| Patient clinic-case / clinic appointment screen (for CLINIC_* notifications) | — | No patient screen for clinic cases beyond M05 request detail |
| Consultation history list (general) | passport history tab | The UI exists (static); the backend is missing (G5) |
| Session revoke per session / account-security summary | security | Endpoints exist; no matching control |

---

## Open questions (not decided here)

1. **Roadmap file.** Where is `claude/OmniCare_G2_Patient_Flutter_Roadmap.md`? It is absent from the workspace.
2. **G-2 gate.** What exactly is the "G-2 gate" for the release build (analyzer, tests, `--dart-define` set, mock-import ban, golden tests)? No definition was found in any repo.
3. **Urgent CABINET.** Will the backend get a production authorisation mode in the G-2 window, or does urgent cabinet stay "indisponible" (G1)?
4. **Urgent HOME.** Is wiring `/me/urgent-home/*` in G-2 scope, or does the review screen keep routing to "indisponible" (F9)? Is HOME urgent considered "consultation"?
5. **Home feed blocks.** Remove, hide, or show "indisponible" for stats, referral, OmniBand and support (G9)? Is hiding a block a "UI change"?
6. **Clinic and doctor presentation catalogs.** Drop the STATIC fields, or request backend fields (G12, G13)?
7. **Documents entry.** Can the existing Ma Santé documents section / passport documents tab be re-bound to MedicalDocumentsScreen without counting as a redesign?
8. **Push alias (F7).** Fix it in the backend (send the semantic type in FCM data) or map aliases in the app?
9. **Family-member medical data (G10).** May the account holder read/write a family member's passport via `patientId`?
10. **Languages.** French-only, or FR/EN/AR via `AppLocalizations`? The default locale is `en` (`lib/main.dart:372`) while most copy is FR.
11. **Role exclusions.** Should NURSE, KINE, SECRETARY and ADMIN keep being force-logged-out in this app (C17)?
12. **Legacy code.** Delete the unreachable files in b.1 in G-2, or leave them for a later cleanup? Their mock imports keep `lib/mock_data` alive.
13. **Phone-OTP flags.** The client and server flags are configured independently. Which is authoritative for production?

---

## Path to deliver G-2

1. **Unblock the inputs.** Supply the roadmap file and the G-2 gate definition, and answer open questions 3–8. Those decisions change phases 2–7.
2. **Phase 1 first (no UI change, high value).** Fix C1, C2, C3, C4–C6, C8, C10, F7. Each fix gets a contract test that builds the payload from the real mapper (C1 slipped through because tests bypassed `groupAvailabilitySlots`).
3. **Make every reachable screen honest (phase 2).** Each STATIC/FIXTURE/MOCK block listed in a.1–a.8 and b.3 becomes either REAL or an explicit "indisponible" state. A lint/CI check then forbids importing `lib/mock_data/**`, `*_fixture.dart`, `*_mock_data.dart` and `*_static_data.dart` from production-reachable files (b.3 gives the exact current violators: `medications_api.dart:1`, `patient_passport_screen.dart:8`, `patient_appointments_controller.dart:4`, 4 urgent-cabinet screens, `user_repository.dart:6`).
4. **Wire the existing endpoints (phases 3, 4, 6).** `/profile/medical-data`, documents entry + pagination, schedule proposal (only if UI exists; otherwise record it as a gap), information-request.
5. **Track backend work in parallel (phases 5 and 7 depend on it).** G1, G2, G3, G5, G7 (view + MRS SSE), G8, and the push alias. Until each lands, the screen shows "indisponible", never a fixture.
6. **Cross-cutting hardening (phase 8).** A single error-envelope parser covering the 5 shapes with local FR messages only (remove the 9 server-text sinks in f.3); l10n alignment; artifact PDF size cap; `debugPrint` of error/stack only in debug; remove `.env` from assets; tests for the screens listed as untested in §a.
7. **Gate.** The release build (`--dart-define=OMNICARE_API_BASE_URL=…`) passes the G-2 gate. A re-run of this inventory's import-graph and mock-import scans shows 0 production-reachable mock/fixture imports and 0 navigable STATIC/FIXTURE rows. Every phase has a report under `docs/reports/G2/`.

---

### Appendix: verification log for high-impact claims (re-checked directly)

| Claim | Check |
|---|---|
| Slot +1 h | `doctor_directory_mapper.dart:107-108,226-227`; `patient_booking_controller.dart:228-230,261-263`; `scheduled_care_models.dart:96-98` |
| Passport denyAll | `PassportController.java:21`; `AuthWebSecurityConfig.java:23` (only API chain), `:280` (`anyRequest().denyAll()`), only `/api/v1/profile/**` is matched nearby; `ManagementSecurityConfiguration.java:39` (actuator only) |
| Urgent cabinet prod | `UrgentCabinetAuthorizationMode.java:3-6`; `UrgentCabinetTargetedAccessPolicy.java:24-51`; `application-prod.yaml:34` |
| `medicalInfo` dropped | `UpdatePassportRequest.java:7-15`; FAIL_ON_UNKNOWN enabled only at `DocumentController.java:61` |
| history_tab unreachable | No importer outside itself; the passport uses `widgets/passport_history_tab.dart` (`patient_passport_screen.dart:20,168`) |
| consultations_api patient-unreachable | Import path exists only via `lib/features/doctor/doctor_auth_shell_screen.dart` → `doctor/shell/doctor_app_shell.dart` → `doctor/consultation_detail_screen.dart` |
