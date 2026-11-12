# G-2 1b-2 appendix — backend error codes a patient screen can receive

_Read-only survey of OmniCare-BackEnd (branch `feature/g1-p2b-single-page`, HEAD `cebfd38`) made for G2-1b-2. Paths are relative to `OmniCare-BackEnd/src/main/java/com/omnicare/app/`. Two claims were re-checked by hand: `fieldErrorCodes` is never filled on patient paths, and `patient-max-sessions` defaults to 0._


Read-only inventory, built from the code on 2026-11-11. Every path below is relative to
`OmniCare-BackEnd/src/main/java/com/omnicare/app/`. `GEH` = `shared/error/GlobalExceptionHandler.java`,
`EC` = `shared/error/ErrorCode.java`, `SEC` = `auth/config/AuthWebSecurityConfig.java`,
`SERW` = `auth/security/SecurityErrorResponseWriter.java`.

**Shapes**
1 = `ErrorResponse{code,message,timestamp,fieldErrors,requestId?,fieldErrorCodes?}` (GEH)
2 = session-limit map `{code,message,timestamp,activeSessions[]}` (GEH:260-271)
3 = ProblemDetail + `errorCode` (+`requestId`,`timestamp`)
4 = ProblemDetail + `code` (+`requestId`,`timestamp`, optional `blockingReasons`)
5 = security problem map `{type,title,status,detail,instance,code,requestId,timestamp}` (SERW:42-70)

**Which handler covers which patient endpoint**

| App call (base `/api/v1`) | Controller | Advice that applies |
|---|---|---|
| `/auth/*` (login, refresh, me, signup, google, logout, devices, password, history, phone-change) | `auth/api/AuthController`, `AccountSecurityController`, `AuthHistoryController`, `PhoneChangeController` | GEH (global) → 1 / 2 |
| `/profile`, `/profile/medical-data`, `/profile/passport`, `/profile/onboarding/step/{n}`, `/profile/avatar`, `/profile/family-members/**` | `profile/controller/ProfileController`, `OnboardingController`, `ProfileAvatarController`, `FamilyMemberController` | GEH → 1 (and `MrsProblemDetailHandler` → 3 for `MrsGatewayException`) |
| `/documents/**` (list, upload, recovery, detail, SSE events, delete) | `profile/controller/DocumentController` | GEH → 1, plus `MrsProblemDetailHandler` → 3 |
| `/notifications/**`, `/notifications/token` | `notification/controller/NotificationCenterController`, `DeviceTokenController` | GEH → 1 |
| `/appointment-requests/**` (M05) | `request/api/PatientRequestController` | `RequestProblemDetailHandler` (basePackages `request.api`) → 3; anything it does not handle goes to GEH |
| `/patient/clinics/**` | `clinic/api/PatientClinicDirectoryController` | `ClinicProblemDetailHandler` (basePackages `access`, `clinic.api`, `professional.api`) → 3 |
| `/doctors`, `/doctors/{id}` | `directory/controller/DoctorDirectoryController` | GEH → 1 |
| `/appointments/availability/slots` | `appointment/controller/AvailabilityController` | `AvailabilityProblemDetailHandler` (assignableTypes) → 3 |
| `GET /appointments/{id}` | `appointment/controller/AppointmentController` | GEH → 1 (**not** the booking handler) |
| `POST /appointments` (deprecated app call) | none (path denied) | Spring Security `denyAll` (SEC:225) → 403, shape 1 |
| `/doctor-booking-requests/**`, `/patient/scheduled-care`, `POST /appointments/{id}/cancel` | `scheduledcare/api/PatientBookingRequestController`, `PatientScheduledCareController`, `ScheduledAppointmentCancellationController` | `BookingRequestProblemDetailHandler` (basePackages `scheduledcare.api`) → 3, plus `BookingRequestBodyLimitAdvice` |
| `/patient/appointments/{id}/consultation` | `consultation/api/PatientScheduledConsultationController` | `ConsultationProblemDetailHandler` → 3 |
| `/patient/consultations/{id}/prescription` | `prescription/api/PatientPrescriptionController` | `PrescriptionProblemDetailHandler` → 3 |
| `/patient/consultations/{id}/artifacts/**` (called from `lib/features/patient/artifact/patient_artifact_card.dart` through `lib/features/doctor/artifact/artifact_api.dart`) | `artifact/api/PatientArtifactController` | `ArtifactProblemDetailHandler` → 3 |
| `/me/urgent-cabinet/discovery/**`, `/me/urgent-cabinet/requests/**` | `professionalcare/api/MePatientUrgentCabinet{Discovery,TargetedRequest,Operational}Controller` | `CareCapabilityProblemDetailHandler` (basePackages `professionalcare.api`) → 4; security errors → 5 |
| `POST /professional-access-requests` | `professionalaccess/api/ProfessionalAccessRequestController` | GEH → 1 |
| `/patient/medical-sharing/**` (policy, consultations, qr) | `medicalsharing/api/PatientMedicalSharingController` | `MedicalSharingProblemDetailHandler` (assignableTypes) → 3 |
| `/me/consultations/**/medical-sharing/*` | `medicalsharing/api/DirectPatientAuthorizationController` | **GEH → 1** (this controller is not in the medical-sharing advice's `assignableTypes`, MedicalSharingProblemDetailHandler.java:25-29) |

The app's mock-only API classes (`lib/core/api/patients_api.dart`, `medications_api.dart`, `medical_acts_api.dart`, `reservations_api.dart`, `doctors_api.dart`, `consultations_api.dart`, `provider_me_api.dart`) make no HTTP calls, so they are left out.

---

## Section A: codes by area

### Auth (`/auth/*`), shape 1 unless noted
| code | HTTP | shape | backend meaning | evidence |
|---|---|---|---|---|
| VALIDATION_ERROR | 400 | 1 | `@Valid` DTO failure, a missing header, a type mismatch or a malformed JSON body (see B) | GEH:85-160; EC:12 |
| AUTH_INVALID_CREDENTIALS | 401 | 1 | Wrong email/password. On `/auth/password/change` and `/auth/password/set` it also means the current password is wrong, there is no credential, or the Google claim is missing or unverified | LoginService.java:137; LoginFinalizationService.java:368; ChangePasswordService.java:57,60; SetPasswordService.java:71,82,85 (all `auth/application/`) |
| AUTH_INVALID_OTP | 401 | 1 | OTP invalid or expired (signup verify, phone login verify, google phone verify, phone-change verify) | auth/api/AuthController.java:221,266; GoogleAuthService.java:195; PhoneChangeOtpService.java:151,198 |
| OTP_NOT_VERIFIED | 400 | 1 | Signup complete or google complete called before the phone was verified | AuthController.java:234; GoogleAuthService.java:242 |
| USER_NOT_FOUND | 404 | 1 | "No account found with this phone" (phone login verify); "User not found" | AuthController.java:269; PhoneSignupService.java:276; PhoneChangeService.java:92 |
| AUTH_PHONE_ALREADY_USED | 409 | 1 | Phone already linked to another account (signup initiate/complete, google, phone-change new) | AuthController.java:208; PhoneSignupService.java:165,194; GoogleAuthService.java:360; PhoneChangeOtpService.java:182; PhoneChangeService.java:114,130 |
| AUTH_EMAIL_ALREADY_USED | 409 | 1 | Email already registered (signup complete, google complete) | PhoneSignupService.java:171,209; GoogleAuthService.java:379 |
| DUPLICATE_IDENTITY | 409 | 1 | Google complete: "Identity already exists" or "Google account already linked" | GoogleAuthService.java:325,347 |
| AUTH_PASSWORD_COMPROMISED | 400 | 1 | Password found in the HIBP breach list (signup, change, set). On login it is caught and does not reach the client | password/HibpPasswordBreachCheckService.java:64; LoginService.java:88-91 |
| AUTH_ACCOUNT_NOT_ALLOWED | 403 | 1 | User cannot authenticate (`!canAuthenticate()`), login blocked, or email login has no verified phone for the OTP step | AuthSessionIssuer.java:84; LoginFinalizationService.java:145,271; GoogleAuthService.java:112,123; GoogleAccountLinkService.java:262 |
| AUTH_ROLE_NOT_ALLOWED | 403 | 1 | Google link: the account's role is not supported for linking | GoogleAccountLinkService.java:266 |
| AUTH_REFRESH_TOKEN_INVALID | 401 | 1 | `/auth/refresh` with an invalid, rotated or revoked refresh token | refresh/RefreshTokenService.java:343; DeviceAwareSessionPolicy.java:212; TokenRefreshService.java:80 |
| AUTH_EMAIL_NOT_VERIFIED | 401 | 1 | The Google ID token's email is not verified | config/GoogleTokenHelper.java:95 |
| AUTH_INVALID_TOKEN | 401 | 1 | Invalid Google ID token; on phone-change reverse-token, "Invalid reversal link" or "Reversal link has expired" | GoogleTokenHelper.java:143; PhoneChangeReversalTokenService.java:65,90; PhoneChangeService.java:187 |
| AUTH_GOOGLE_SIGNUP_EXPIRED / AUTH_GOOGLE_SIGNUP_INVALID | 401 | 1 | Google pending-signup token expired or invalid | GooglePendingSignupStore.java:85,147,155,183; GoogleAuthService.java:403 |
| AUTH_GOOGLE_LINK_EXPIRED / AUTH_GOOGLE_LINK_INVALID | 401 | 1 | Google account-link challenge expired or invalid | GoogleAccountLinkChallengeStore.java:60,116,140; GoogleAccountLinkService.java:129,134,239,250,256 |
| AUTH_GOOGLE_LINK_PASSWORD_INVALID | 401 | 1 | Wrong password during Google link | GoogleAccountLinkPasswordException.java:13 |
| AUTH_GOOGLE_LINK_PASSWORD_UNAVAILABLE | 409 | 1 | The candidate account has no password credential, so it cannot be linked by password | GoogleAccountLinkService.java:103,139 |
| AUTH_GOOGLE_IDENTITY_CONFLICT | 409 | 1 | The Google identity is already linked to another account | GoogleAccountLinkService.java:151,167 |
| AUTH_PROVIDER_UNAVAILABLE | 503 | 1 | SMS provider down, Google OAuth not configured or enabled, HIBP check unavailable, "Password verification was interrupted", Redis TTL not configured | OtpService.java:102; GooglePhoneOtpService.java:185; GoogleTokenHelper.java:69,81; GoogleAuthService.java:336; HibpPasswordBreachCheckService.java:94; LoginPasswordVerificationGate.java:69; PhoneChangeOtpService.java:266,290; GooglePendingSignupStore.java:163,191; GoogleAccountLinkChallengeStore.java:123,145 |
| TOO_MANY_REQUESTS | 429 (Retry-After 60) | 1 | "Too many OTP requests. Please wait." / phone-change OTP rate limit | OtpService.java:78; GooglePhoneOtpService.java:251; PhoneChangeOtpService.java:338; GEH:57-58 |
| INVALID_INPUT | 400 | 1 | "Invalid phone number"; "Invalid first/last name"; "Patient must be at least 18 years old"; "Invalid gender"; "Invalid platform"; "New password must be different…"; "New phone must be different"; history paging out of range | PhoneNumberNormalizer.java:19,30; PhoneSignupService.java:303-312; entity/ClientPlatform.java:20; ChangePasswordService.java:63; PhoneChangeOtpService.java:176; AuthHistoryService.java:82 |
| INVALID_STATE | 400 | 1 | "Phone verification is temporarily disabled"; "A password is already configured"; phone-change step errors ("Verify the current phone first", "Current phone verification expired", "No verified phone is available", "No phone change is active", "reversal window has expired"); history report ("cannot be reported", "already reported") | AuthController.java:402; SetPasswordService.java:73; PhoneChangeOtpService.java:171,219,235,241; PhoneChangeService.java:106,108,179,270; AuthHistoryService.java:116,120 |
| CONFLICT | 409 | 1 | "A phone change is already in progress" | PhoneChangeOtpService.java:228; PhoneChangeService.java:99 |
| FORBIDDEN | 403 | 1 | "Phone change is available to patients only" (service-level check) | PhoneChangeService.java:94 |
| RESOURCE_NOT_FOUND | 404 | 1 | "Device not found" / "Session not found" (device logout); "Auth event not found" (history report); phone-change transition owned by another user; user row missing while locking | DeviceManagementService.java:59,62,146,149; AuthHistoryService.java:113; PhoneChangeService.java:265; DeviceAwareSessionPolicy.java:63; LoginFinalizationService.java:215 |
| AUTH_MAX_SESSIONS_REACHED | 409 | **2** | Session limit reached when a session is issued; `activeSessions[] = {sessionId, deviceLabel, platform, lastSeenAt, context(null)}`. For PATIENT the limit defaults to 0 (= unlimited), see D | auth/exception/SessionLimitExceededException.java:16; DeviceAwareSessionPolicy.java:101-107; auth/api/dto/ActiveSessionInfo.java; GEH:260-271 |

### Profile / onboarding / passport / medical data (shape 1)
| code | HTTP | shape | backend meaning | evidence |
|---|---|---|---|---|
| VALIDATION_ERROR | 400 | 1 | `@Valid` DTO failure (UpdateProfileRequest, UpdatePassportRequest, UpdateMedicalDataRequest, OnboardingStepRequest) | GEH:85-109 |
| RESOURCE_NOT_FOUND | 404 | 1 | "Profile not found" | service/UserProfileService.java:51,57,63,84,133; service/OnboardingService.java:32,126 (`profile/`) |
| RESOURCE_ALREADY_EXISTS | 409 | 1 | "Profile already exists" | profile/service/UserProfileService.java:40 |
| INVALID_INPUT | 400 | 1 | "Use /api/v1/profile/avatar to manage profile photos"; "At least one medical section is required"; "Medical data is available from /api/v1/profile/medical-data"; onboarding "Invalid step"; MRS medical-data checks ("Invalid blood type", "Height and weight must be provided together", "Blood type cannot be cleared…", "…empty life-safety record", "Body measurements are outside MRS limits", "MRS medical labels must contain 1 to 160 characters…") | UserProfileService.java:67,130; ProfileController.java:105; OnboardingService.java:96; mrs/MrsMedicalDataService.java:84,103,141,154,207,283,298 |
| INVALID_STATE | 400 | 1 | Onboarding: "Onboarding already completed", "Expected step X but got Y", "Patient ID not set", "Basic profile information must be completed before finishing onboarding" | OnboardingService.java:39,52,58,147 |
| MRS_UNAVAILABLE | 503 (Retry-After 30) | 1 **or** 3 | Medical record service unavailable. Shape 1 when a service throws `ApiException(MRS_UNAVAILABLE)`; shape 3 when an MRS HTTP client throws `MrsGatewayException` | MrsMedicalDataService.java:247,252,268; mrs/MrsGatewayException.java; mrs/MrsProblemDetailHandler.java:20-53; HttpMrsMedicalRecordClient.java:254; HttpMrsPatientClient.java:129 |
| MRS_SINGLETON_SERIES_AMBIGUOUS | 409 | 1 | MRS reports `SINGLETON_SERIES_AMBIGUOUS` on a singleton upsert ("requires reconciliation before it can be updated"). Reachability from the patient medical-data write path is inferred, not traced end to end | mrs/HttpMrsMedicalRecordClient.java:86,257-261; EC:88 |
| RESOURCE_NOT_FOUND | 404 | 1 | MRS reports `SINGLETON_CANONICAL_SERIES_NOT_FOUND` | HttpMrsMedicalRecordClient.java:262-263 |

### Avatar (`/profile/avatar`), shape 1
| code | HTTP | shape | backend meaning | evidence |
|---|---|---|---|---|
| INVALID_INPUT | 400 | 1 | "Select a non-empty avatar image", "The avatar image is invalid or corrupted", "Avatar image dimensions are not allowed" | profile/avatar/AvatarImageProcessor.java:74,82,101,117,121 |
| FILE_TOO_LARGE | 413 | 1 | "Avatar image exceeds the 8 MB limit"; also any multipart over the servlet limit | AvatarImageProcessor.java:85; GEH:199-211 |
| UNSUPPORTED_FILE_TYPE | 415 | 1 | "Avatar must be a JPEG or PNG image" / "Avatar content does not match its MIME type" | AvatarImageProcessor.java:90,105,112,136 |
| TOO_MANY_REQUESTS | 429 (Retry-After 60) | 1 | "Avatar processing is busy…" (concurrency guard) | AvatarImageProcessor.java:62 |
| OBJECT_STORAGE_UNAVAILABLE | 503 | 1 | File storage temporarily unavailable | avatar/S3AvatarObjectStorage.java:47,63; LocalAvatarObjectStorage.java:51,64; UnavailableAvatarObjectStorage.java:10,15 |
| RESOURCE_NOT_FOUND | 404 | 1 | "Profile not found" | avatar/ProfileAvatarService.java:47,62 |

### Family members (`/profile/family-members/**`), shape 1
| code | HTTP | shape | backend meaning | evidence |
|---|---|---|---|---|
| VALIDATION_ERROR | 400 | 1 | FamilyMemberRequest `@Valid` failure | GEH:85-109; profile/DTO/FamilyMemberRequest.java |
| RESOURCE_NOT_FOUND | 404 | 1 | "Family member not found" | profile/service/FamilyMemberService.java:107 |
| INVALID_STATE | 400 | 1 | "Cannot update a graduated family member" / "Cannot deactivate a graduated family member" | FamilyMemberService.java:79,97 |
| INVALID_INPUT, MRS_UNAVAILABLE | 400 / 503 | 1 (MRS also 3) | Passport basics go through MrsMedicalDataService (same messages as the profile section) | FamilyMemberService.java:26 (uses MrsMedicalDataService) |

### Documents / files (`/documents/**`), shape 1 unless noted
| code | HTTP | shape | backend meaning | evidence |
|---|---|---|---|---|
| VALIDATION_ERROR | 400 | 1 | Upload metadata JSON missing, too long, unparsable or failing validation; "Idempotency-Key must contain 8 to 128 safe characters" | profile/controller/DocumentController.java:162,170,174; profile/service/DocumentService.java:301 |
| INVALID_INPUT | 400 | 1 | List `limit` out of range or cursor > 768 chars; empty file or no metadata; missing or invalid document type or display name (>200); unsafe filename; MRS 400/422 | DocumentService.java:158,161,242,260,267,274; mrs/HttpMrsDocumentClient.java:550 |
| FILE_TOO_LARGE | 413 | 1 | File over the per-file limit; MRS 413; multipart limit | DocumentService.java:245; HttpMrsDocumentClient.java:554; GEH:199-211 |
| UNSUPPORTED_FILE_TYPE | 415 | 1 | Disallowed MIME type; MRS 415 | DocumentService.java:251; HttpMrsDocumentClient.java:555 |
| RESOURCE_NOT_FOUND | 404 | 1 | Document not found or not owned; MRS 404; SSE stream target not found | DocumentService.java:184,205,226,230; HttpMrsDocumentClient.java:552; DocumentEventStreamService.java:40,45 |
| FORBIDDEN | 403 | 1 | "Raw medical document download is not available" (`GET /documents/{id}/download`); MRS 403 | DocumentController.java:140-145; HttpMrsDocumentClient.java:551 |
| CONFLICT | 409 | 1 | MRS returned 409 or 410 | HttpMrsDocumentClient.java:553 |
| DOCUMENT_UPLOAD_IDEMPOTENCY_CONFLICT | 409 | 1 | MRS `IDEMPOTENCY_CONFLICT`: the upload key was reused for different content | HttpMrsDocumentClient.java:563-564 |
| DOCUMENT_UPLOAD_COMMAND_IN_PROGRESS | 409 | 1 | MRS `IDEMPOTENCY_IN_PROGRESS` | HttpMrsDocumentClient.java:566-567 |
| DOCUMENT_UPLOAD_RECOVERY_NOT_FOUND | 404 | 1 | `/documents/uploads/recovery`: MRS has no upload for that key | HttpMrsDocumentClient.java:206-207 |
| TOO_MANY_REQUESTS | 429 (Retry-After 60) | 1 | Too many concurrent SSE event connections; MRS 429 | service/DocumentEventConnectionLimiter.java:45,59; HttpMrsDocumentClient.java:556; HttpMrsDocumentEventClient.java:68,168 |
| UNAUTHORIZED | 401 | 1 | No AuthenticatedUser principal in the controller or SSE limiter | DocumentController.java:181; DocumentEventConnectionLimiter.java:42 |
| MRS_UNAVAILABLE | 503 (Retry-After 30) | 1 **or** 3 | Shape 1 from `DocumentService`/`DocumentEventStreamService`; shape 3 from `HttpMrsDocument*Client` (`MrsGatewayException`) | DocumentService.java:115,121,138,141,232; DocumentEventStreamService.java:47; HttpMrsDocumentClient.java:620,642; HttpMrsDocumentEventClient.java:174 |

### Account security: sessions, devices, history, phone change, password
These are covered by the Auth table: RESOURCE_NOT_FOUND (device/session/event), INVALID_STATE, CONFLICT, FORBIDDEN, INVALID_INPUT, AUTH_INVALID_OTP, AUTH_PHONE_ALREADY_USED, AUTH_INVALID_TOKEN, TOO_MANY_REQUESTS, AUTH_PROVIDER_UNAVAILABLE, AUTH_INVALID_CREDENTIALS, AUTH_PASSWORD_COMPROMISED. Role gates (SEC:206-209: `/auth/history` and `/auth/phone-change/**` are PATIENT only) answer with FORBIDDEN 403 in shape 1.

### Notifications + device tokens, shape 1
| code | HTTP | shape | backend meaning | evidence |
|---|---|---|---|---|
| *(no body)* | 404 | none | `POST /notifications/{id}/read` when no row was updated: `ResponseEntity.notFound()` with an empty body | notification/controller/NotificationCenterController.java:73 |
| INTERNAL_SERVER_ERROR | 500 | 1 | `GET /notifications?category=<unknown>`: `NotificationCategory.valueOf` throws IllegalArgumentException and the catch-all handles it | NotificationCenterController.java:42; GEH:220-244 |
| VALIDATION_ERROR | 400 | 1 | Malformed body or bad `page`/`pageSize` type | GEH:132-160 |
(`DeviceTokenController` has no validation and no ApiException throws, notification/controller/DeviceTokenController.java:27-39.)

### M05 appointment requests (`/appointment-requests/**`), shape 3, enum `request/api/error/RequestErrorCode.java`
| code | HTTP | shape | backend meaning | evidence |
|---|---|---|---|---|
| REQUEST_INVALID | 400 | 3 | Any Bean Validation failure, unreadable body or malformed UUID (no field list); invalid subject selection; required field missing; invalid information response | RequestErrorCode.java:36-40; RequestProblemDetailHandler.java:91-113; api/dto/RequestSubjectRequest.java:33,38,44; api/dto/SubmitClinicRequestRequest.java:42,47; application/PatientInformationRequestService.java:177,197,315 |
| REQUEST_SUBJECT_FORBIDDEN | 403 | 3 | "This request cannot be submitted for the selected person." | RequestErrorCode.java:22-26; application/RequestSubjectResolver.java:66 |
| REQUEST_NOT_FOUND | 404 | 3 | "No such request is available." | RequestErrorCode.java:69-73; PatientRequestQueryService.java:110,114; PatientRequestCancellationService.java:121; PatientInformationRequestService.java:93,97,111,115 |
| REQUEST_TARGET_UNAVAILABLE | 422 | 3 | "The selected provider cannot receive requests right now." (clinic not active or not visible) | RequestErrorCode.java:29-33; integration/ClinicRequestTargetPort.java:43,46 |
| REQUEST_IDEMPOTENCY_CONFLICT | 409 | 3 | Submission identifier already used for a different request | RequestErrorCode.java:62-66; ClinicRequestSubmissionService.java:152,164,169; PatientInformationRequestService.java:121 |
| REQUEST_TRANSITION_INVALID | 409 | 3 | "This change is not allowed for the request." (cancel or information response in the wrong state) | RequestErrorCode.java:50-54; PatientRequestCancellationService.java:127,138,175,185; PatientInformationRequestService.java:124,127 |
| REQUEST_VERSION_CONFLICT | 409 | 3 | `expectedVersion` mismatch or an optimistic-lock failure at flush | RequestErrorCode.java:43-47; PatientRequestCancellationService.java:178; PatientInformationRequestService.java:130; RequestProblemDetailHandler.java:75-82 |
| SCHEDULE_PROPOSAL_CONFLICT / SCHEDULE_VERSION_CONFLICT / SCHEDULE_IDEMPOTENCY_CONFLICT | 409 | 3 | Exist only on `/{id}/schedule-proposals/{pid}/accept|reject`, which the app's `request_api.dart` does **not** call | RequestErrorCode.java:75-91; PatientScheduleProposalService.java |

### Patient clinics directory (`/patient/clinics/**`), shape 3
| code | HTTP | shape | backend meaning | evidence |
|---|---|---|---|---|
| CLINIC_DIRECTORY_NOT_FOUND | 404 | 3 | "The requested clinic is not available." (detail of a clinic that is not visible) | clinic/api/error/ClinicAccessErrorCode.java:16; clinic/application/PatientClinicDirectoryService.java:70 |
| *(no errorCode)* | 400 | 3 without `errorCode` | Malformed `clinicId` or a non-int `page`/`pageSize`: ProblemDetail with type `.../clinic/validation`, title "Invalid clinic request", **no `errorCode` property** | ClinicProblemDetailHandler.java:78-103 |
(The list endpoint clamps page and pageSize and never throws, PatientClinicDirectoryService.java:46-48.)

### Doctors directory + availability
| code | HTTP | shape | backend meaning | evidence |
|---|---|---|---|---|
| DOCTOR_NOT_FOUND | 404 | 1 | `GET /doctors/{id}`: doctor not found or not eligible | directory/service/DoctorDirectoryService.java:382; EC:28 |
| INVALID_INPUT | 400 | 1 | "lat and lng must be provided together", "lat must be within…", "directory query is required", "page must be between 0 and 10000", "size must be between 1 and 50", "maxDistanceKm requires lat and lng", "maxDistanceKm must be greater than 0 and at most 300" | DoctorDirectoryService.java:443-471 |
| VALIDATION_ERROR | 400 | 1 | Type mismatch on `lat`/`lng`/enums | GEH:132-146 |
| VALIDATION_FAILED | **422** | 3 | Slots: range missing, inverted or > 31 days; missing or mistyped `doctorId`/`from`/`to` | appointment/api/error/AvailabilityErrorCode.java:7-10; appointment/service/BookableSlotPolicy.java:26; AvailabilityProblemDetailHandler.java:42-54 |
| BOOKING_CONTEXT_NOT_AVAILABLE | 404 | 3 | Doctor or Cabinet is not open for new-patient Cabinet booking | AvailabilityErrorCode.java:11-14; appointment/service/SlotGenerationService.java:219-224 |
| LEGACY_AVAILABILITY_RETIRED | 410 | 3 | Slots called without `practiceLocationId` | AvailabilityErrorCode.java:15-18; appointment/controller/AvailabilityController.java:108-111 |

### Booking requests / appointments / scheduled care, shape 3, enum `scheduledcare/api/error/BookingRequestErrorCode.java`
| code | HTTP | shape | backend meaning | evidence |
|---|---|---|---|---|
| VALIDATION_FAILED | **422** | 3 | Any Bean Validation, ConstraintViolation, unreadable body (including body > 8 KiB), type mismatch or missing header; bad cursor; invalid scheduled-care query; invalid cancellation payload | BookingRequestErrorCode.java:6-7; BookingRequestProblemDetailHandler.java:52-58; BookingRequestBodyLimitAdvice.java (MAX_BODY_BYTES=8192); PatientScheduledCareCursorCodec.java:39; PatientScheduledCareQueryService.java:60; ScheduledAppointmentCancellationWriter.java:148,151; ScheduledCareCommandReceiptCoordinator.java:84 |
| BOOKING_CONTEXT_NOT_AVAILABLE | 404 | 3 | Booking context (doctor + cabinet) not available; also mapped from Availability's BOOKING_CONTEXT_NOT_AVAILABLE | BookingRequestErrorCode.java:8-9; DoctorBookingRequestCreationWriter.java:97,120; BookingRequestProblemDetailHandler.java:42-50 |
| SUBJECT_NOT_AVAILABLE | 404 | 3 | Selected subject (self or family member) not available; any `CareSubjectResolutionException` | BookingRequestErrorCode.java:10-11; DoctorBookingRequestCreationWriter.java:90; PatientScheduledCareQueryService.java:64; BookingRequestProblemDetailHandler.java:36-40 |
| SLOT_NO_LONGER_AVAILABLE | 409 | 3 | Requested slot no longer available | BookingRequestErrorCode.java:12-13; CreateDoctorBookingRequestService.java:47; DoctorBookingRequestCreationWriter.java:114,124 |
| VERSION_CONFLICT | 409 | 3 | Booking request or appointment changed; refresh | BookingRequestErrorCode.java:14-15; PatientBookingDecisionWriter.java:173; ScheduledAppointmentCancellationWriter.java:133 |
| REQUEST_STATE_CONFLICT | 409 | 3 | Booking request no longer in a compatible state | BookingRequestErrorCode.java:16-17; PatientBookingDecisionWriter.java:78,191,205,215,225; PatientDoctorBookingRequestQueryService.java:57; ScheduledAppointmentCancellationWriter.java:74,144 |
| REQUEST_EXPIRED | 409 | 3 | Response deadline has elapsed (proposal accept/decline) | BookingRequestErrorCode.java:18-19; PatientBookingDecisionService.java:83,96; PatientBookingDecisionWriter.java:179,185 |
| ACTION_NOT_ALLOWED | 409 | 3 | Action not available (appointment cancel) | BookingRequestErrorCode.java:20-21; ScheduledAppointmentCancellationWriter.java:71,136 |
| IDEMPOTENCY_CONFLICT | 409 | 3 | Idempotency identity reused with a different payload | BookingRequestErrorCode.java:22-24; CreateDoctorBookingRequestService.java:56,64,70; PatientBookingDecisionService.java:89; ScheduledAppointmentCancellationService.java:37; ScheduledCareCommandReceiptCoordinator.java:77 |
| NOT_FOUND | 404 | 3 | "No such booking request is available." (also an appointment not found on cancel) | BookingRequestErrorCode.java:25-26; PatientDoctorBookingRequestQueryService.java:54,109; PatientBookingDecisionWriter.java:168,199; ScheduledAppointmentCancellationService.java:54; ScheduledAppointmentCancellationWriter.java:164 |
| RESOURCE_NOT_FOUND | 404 | 1 | `GET /appointments/{id}`: "Appointment not found" | appointment/service/AppointmentQueryService.java:70 |
| FORBIDDEN | 403 | 1 | `GET /appointments/{id}`: "You can only view your own appointments" | AppointmentQueryService.java:72 |
| FORBIDDEN | 403 | 1 | `POST /appointments` (deprecated `bookAppointment`) is `denyAll` | SEC:225; auth/security/RestAccessDeniedHandler.java:32 |
| CONSULTATION_NOT_FOUND | 404 | 3 | `/patient/appointments/{id}/consultation`: no completed scheduled consultation for this requester | consultation/api/error/ConsultationErrorCode.java:29-30; consultation/application/ConsultationQueryService.java:38-44 |
| VALIDATION_FAILED | **400** | 3 | Consultation advice: malformed `appointmentId` and similar | ConsultationErrorCode.java:27-28; ConsultationProblemDetailHandler.java:38-49 |

### Prescription + artifacts (patient read), shape 3 (`ErrorCode` names in `errorCode`, detail = enum default message)
| code | HTTP | shape | backend meaning | evidence |
|---|---|---|---|---|
| RESOURCE_NOT_FOUND | 404 | 3 | Subject unresolvable, consultation not owned, or subject mismatch (prescription) | prescription/PatientPrescriptionService.java:30,34,38 |
| CLINICAL_SUBJECT_UNAVAILABLE | 409 | 3 | Subject has no MRS patient id | PatientPrescriptionService.java:32; artifact/PatientArtifactService.java:17; EC:104 |
| VALIDATION_ERROR | 400 | 3 | Invalid `subjectType`/`familyMemberId` combination | prescription/api/PatientPrescriptionController.java:32; artifact/api/PatientArtifactController.java:35 |
| PRESCRIPTION_NOT_FOUND / RESOURCE_NOT_FOUND / MRS_UNAVAILABLE | 404 / 404 / 503 (Retry-After 30) | 3 | Mapped from the MRS error code (`PRESCRIPTION_NOT_FOUND`, `PRESCRIPTION_CARE_CONTEXT_MISMATCH`, default) | prescription/HttpMrsPrescriptionClient.java:131-156 |
| ARTIFACT_NOT_FOUND | 404 | 3 | Subject or consultation not owned; MRS `ARTIFACT_NOT_FOUND`/`ARTIFACT_ACCESS_DENIED` | PatientArtifactService.java:17; artifact/HttpMrsArtifactClient.java:36 |
| ARTIFACT_RENDER_PENDING | 409 | 3 | Official PDF not ready yet | HttpMrsArtifactClient.java:36; EC:173 |
| ARTIFACT_RENDER_FAILED | 503 (Retry-After 30) | 3 | Temporary PDF rendering problem | HttpMrsArtifactClient.java:30,36; EC:174 |
| MRS_UNAVAILABLE | 503 (Retry-After 30) | 3 | Any other MRS failure | HttpMrsArtifactClient.java:20-36 |

### Urgent cabinet (patient side), shape 4 (`code`), enum `professionalcare/api/error/CareCapabilityErrorCode.java`
| code | HTTP | shape | backend meaning | evidence |
|---|---|---|---|---|
| VALIDATION_FAILED | **400** | 4 | Bean Validation, header constraint, unreadable body or missing header; discovery lat/lng/sort inconsistency; replay payload invalid | CareCapabilityErrorCode.java:270-271; CareCapabilityProblemDetailHandler.java:74-82; professionalcare/urgentcabinet/UrgentCabinetDiscoveryService.java:159; urgentcabinetrequest/UrgentCabinetTargetedService.java:347,374 |
| RESOURCE_STATE_CONFLICT | 409 | 4 | Optimistic-lock failure | CareCapabilityErrorCode.java:17-19; CareCapabilityProblemDetailHandler.java:42-49 |
| URGENT_CABINET_DIRECTORY_ENTRY_NOT_FOUND | 404 | 4 | Discovery: doctor + practice-location entry not available | CareCapabilityErrorCode.java:34-36; UrgentCabinetDiscoveryService.java:149 |
| URGENT_CABINET_REQUEST_NOT_AUTHORIZED | 404 | 4 | Actor fails `requirePatient` (deliberately reported as 404) | CareCapabilityErrorCode.java:40-42; UrgentCabinetTargetedAccessPolicy.java:27 |
| URGENT_CABINET_REQUEST_UNAVAILABLE | 404 | 4 | Feature disabled (`requireEnabled`) | CareCapabilityErrorCode.java:37-39; UrgentCabinetOperationalService.java:363-365 |
| URGENT_CABINET_SUBJECT_NOT_AVAILABLE | 404 | 4 | Care subject unresolvable or has no operational patient | CareCapabilityErrorCode.java:43-45; UrgentCabinetTargetedService.java:401,404,588 |
| URGENT_CABINET_REQUEST_NOT_FOUND | 404 | 4 | Request not found for this patient | CareCapabilityErrorCode.java:46-48; UrgentCabinetTargetedService.java:136,415,418,580; UrgentCabinetOperationalService.java:356,359,388 |
| URGENT_CABINET_ACTIVE_JOURNEY_EXISTS | 409 | 4 | Subject already has an active urgent journey | CareCapabilityErrorCode.java:49-52; UrgentCabinetTargetedService.java:101,106 |
| URGENT_CABINET_TARGET_NOT_AVAILABLE | 409 | 4 | Selected Doctor and Cabinet no longer eligible | CareCapabilityErrorCode.java:53-56; UrgentCabinetTargetedWriter.java:151,155 |
| URGENT_CABINET_TARGET_CHANGED | 409 | 4 | Doctor or Cabinet changed; refresh the target | CareCapabilityErrorCode.java:57-60; UrgentCabinetTargetedWriter.java:160,164 |
| URGENT_CABINET_REQUOTE_REQUIRED | 409 | 4 | Authoritative fee changed; review the quote | CareCapabilityErrorCode.java:61-64; UrgentCabinetTargetedWriter.java:157 |
| URGENT_CABINET_TRIAGE_INVALID | 400 | 4 | Triage input invalid | CareCapabilityErrorCode.java:65-68; UrgentCabinetTargetedValidator.java:76 |
| URGENT_CABINET_IDEMPOTENCY_CONFLICT | 409 | 4 | Key reused for a different submission | CareCapabilityErrorCode.java:69-71; UrgentCabinetTargetedService.java:109,352,358 |
| URGENT_CABINET_COMMAND_IN_PROGRESS | 409 | 4 | Submission still in progress | CareCapabilityErrorCode.java:72-74; UrgentCabinetTargetedService.java:98,355 |
| URGENT_CABINET_CANCEL_NOT_ACTIONABLE | 409 | 4 | No longer cancellable | CareCapabilityErrorCode.java:95-98; UrgentCabinetTargetedService.java:181,203 |
| URGENT_CABINET_CANCEL_IDEMPOTENCY_CONFLICT | 409 | 4 | Key reused for a different cancellation | CareCapabilityErrorCode.java:99-102; UrgentCabinetTargetedService.java:206,379,386,393 |
| URGENT_CABINET_CANCEL_COMMAND_IN_PROGRESS | 409 | 4 | Cancellation still in progress | CareCapabilityErrorCode.java:103-106; UrgentCabinetTargetedService.java:196,382 |
| URGENT_CABINET_COMMITMENT_READ_UNAVAILABLE | 503 | 4 | Commitment cannot currently be read safely (`requireReadable`, used by patient status, recovery, active and cancel) | CareCapabilityErrorCode.java:111-114; UrgentCabinetTargetedService.java:560-564 |
| URGENT_CABINET_WITHDRAWAL_NOT_ACTIONABLE | 409 | 4 | Accepted commitment no longer withdrawable | CareCapabilityErrorCode.java:115-118; UrgentCabinetOperationalService.java:131,152,157 |
| URGENT_CABINET_ARRIVAL_HANDOFF_NOT_ACTIONABLE | 409 | 4 | Arrival handoff cannot be issued | CareCapabilityErrorCode.java:119-122; UrgentCabinetOperationalService.java:199 |
| URGENT_CABINET_OPERATION_IDEMPOTENCY_CONFLICT | 409 | 4 | Key reused for a different withdraw or handoff | CareCapabilityErrorCode.java:136-139; UrgentCabinetOperationalService.java:115,339,343 |
| URGENT_CABINET_OPERATION_IN_PROGRESS | 409 | 4 | Withdraw or handoff still in progress | CareCapabilityErrorCode.java:140-143; UrgentCabinetOperationalService.java:346 |
| UNAUTHORIZED / FORBIDDEN | 401 / 403 | **5** | No bearer token, or wrong role (`hasRole(PATIENT)`, SEC:111-116) | SERW:42-89 (problemDomain "care-capability") |
| AUTH_SESSION_INVALID | 401 | **1** | Bearer token present but invalid or expired (see D) | auth/security/OpaqueTokenAuthenticationFilter.java:58-71,107-110; RestAuthenticationEntryPoint.java:34-36 |
| VALIDATION_ERROR | 400 | **1** | Malformed UUID path variable (`MethodArgumentTypeMismatchException` is not handled by the CareCapability advice) | GEH:132-146 |
(Doctor-only codes in the same services, such as RESPONSE_*, ARRIVAL_TOKEN_* and COMMITMENT_NOT_FOUND, are excluded: they are thrown from `respond`, `verifyArrival` and `doctorCommitment`.)

### Professional access request (public form, `POST /professional-access-requests`), shape 1
| code | HTTP | shape | backend meaning | evidence |
|---|---|---|---|---|
| VALIDATION_ERROR | 400 | 1 | CreateProfessionalAccessRequest `@Valid` failure (`@Email @NotBlank @Pattern @Size`) | GEH:85-109; professionalaccess/api/dto/CreateProfessionalAccessRequest.java |
| PROFESSIONAL_ACCESS_REQUEST_ALREADY_PENDING | 409 | 1 | An active request already exists for this email or professional identifier (also on a unique-index race) | professionalaccess/application/ProfessionalAccessRequestService.java:54; EC:371-374 |

### Medical sharing (patient side)
| code | HTTP | shape | backend meaning | evidence |
|---|---|---|---|---|
| RESOURCE_NOT_FOUND | 404 | 3 (`/patient/medical-sharing`) / 1 (`/me/consultations`) | Subject unresolvable; consultation not owned, not completed, or of another subject; MRS 403/404; MRS `DIRECT_CONSENT_DENIED`/`_CONTEXT_DENIED` | medicalsharing/MedicalSharingService.java:167,169,252,307,313; DirectPatientAuthorizationService.java:120,128,130; HttpMrsMedicalSharingClient.java:160; HttpMrsMedicalShareClient.java:202 |
| CLINICAL_SUBJECT_UNAVAILABLE | 409 | 3 | Subject has no MRS patient id | MedicalSharingService.java:255 |
| SHARING_POLICY_VERSION_CONFLICT | 409 | 3 | MRS reports `SHARING_POLICY_VERSION_CONFLICT` (policy PUT) | HttpMrsMedicalSharingClient.java:156-157 |
| VALIDATION_ERROR | 400 | 3 / 1 | Invalid subject selection (service); MRS 422; also a `@Valid` body failure, which goes to GEH with `fieldErrors` (shape 1) | PatientMedicalSharingController.java:108; HttpMrsMedicalSharingClient.java:163; DirectPatientAuthorizationService.java:187; GEH:85-109 |
| TOO_MANY_REQUESTS | 429 (**Retry-After 300**) | 3 | QR generation rate limit | MedicalSharingService.java:269; MedicalSharingProblemDetailHandler.java:60-61 |
| MRS_UNAVAILABLE | 503 (Retry-After 30) | 3 / 1 | MRS down; rate-limiter infrastructure down; approve did not yield an ACTIVE grant | MedicalSharingService.java:161,262,274; HttpMrsMedicalShareClient.java:43,145,179; DirectPatientAuthorizationService.java:73 |
| CONFLICT | 409 | 1 | `/me/consultations/*/medical-sharing/approve|revoke`: MRS `DIRECT_CONSENT_IDEMPOTENCY_CONFLICT` or an MRS 409 | HttpMrsMedicalShareClient.java:203-205 |

### Generic / global (any patient endpoint)
| code | HTTP | shape | backend meaning | evidence |
|---|---|---|---|---|
| UNAUTHORIZED | 401 | 1 (5 on care-capability `/me/*` paths) | No bearer token on a protected route | RestAuthenticationEntryPoint.java:31; SERW:42-47,59 |
| AUTH_SESSION_INVALID | 401 | 1 always | Bearer present but empty, unknown or expired; user missing or not allowed; role changed | OpaqueTokenAuthenticationFilter.java:56-71,107-110 |
| FORBIDDEN | 403 | 1 (5 on care-capability `/me/*` paths) | Role rule, `@PreAuthorize`, or `anyRequest().denyAll()` | RestAccessDeniedHandler.java:32; GEH:215-218; SEC:280 |
| RESOURCE_NOT_FOUND | 404 | 1 | `NoResourceFoundException` (only for paths that pass a security rule; unknown paths elsewhere get 401/403 from `denyAll`) | GEH:185-197 |
| METHOD_NOT_ALLOWED | 405 | 1 | Wrong HTTP method; **French** message "Cette opération n’est pas disponible."; `Allow` header set | GEH:166-183 |
| FILE_TOO_LARGE | 413 | 1 | `MaxUploadSizeExceededException` | GEH:199-211 |
| UNSUPPORTED_FILE_TYPE | 415 | 1 | Only from explicit file-type checks (avatar, documents). There is **no handler for `HttpMediaTypeNotSupportedException`**: a wrong `Content-Type` falls into the catch-all → 500 (inferred from code) | GEH:220 |
| TOO_MANY_REQUESTS | 429 (Retry-After 60 in GEH) | 1 | Feature-level limiters only. There is **no global HTTP rate-limit filter** (the only filters are OpaqueTokenAuthenticationFilter, RequestIdFilter and AccessLogFilter) | GEH:57-58 |
| INTERNAL_SERVER_ERROR | 500 | 1 (+`requestId`) | Any unhandled exception (catch-all). The only place shape 1 carries `requestId` | GEH:220-244 |
| MRS_UNAVAILABLE | 503 (Retry-After 30) | 3 (MrsGatewayException, any controller) or 1/3/4 (scoped `ApiException`) | Medical record service unavailable | mrs/MrsProblemDetailHandler.java:20-53; GEH:55-56 |
| AUDIT_CIRCUIT_BROKEN | 503 | UNCLEAR | Audit breaker open, "Tier 1 operations are temporarily blocked"; which patient endpoints can raise it was not traced | EC:217-220 |

---

## Section B: field-validation shapes and field codes

**Shape 1, `ErrorResponse.fieldErrors`** is a JSON **object `{ "<fieldPath>": "<message>" }`**, typed `Map<String,String>` (ErrorResponse.java:17), **not an array of objects**. It is built in:
- `MethodArgumentNotValidException`: key = `FieldError.getField()` (nested paths such as `allergies[0].name`), value = `getDefaultMessage()`. It is a HashMap, so when one field has several violations the last one wins. Only *field* errors are kept: class-level `ObjectError`s are dropped. Method-level `@AssertTrue isSubjectSelectionValid()` shows up as field `subjectSelectionValid` (GEH:90-104; medicalsharing/api/UpdateMedicalSharingPolicyRequest.java:89, PatientMedicalShareQrRequest.java:22).
- Missing header: `{ "<Header-Name>": "Header is required." }` (GEH:116-130).
- Type mismatch: `{ "<paramName>": "Invalid value." }` (GEH:132-146).
- Unreadable body: `{ "body": "Malformed JSON or invalid field value." }` (GEH:148-160).
- Every other shape-1 error sends `fieldErrors: {}` (an empty object, never null). No patient code path builds `ApiException` with a fieldErrors map (grep found none).
- **`fieldErrorCodes`** (`{path: CODE}`, ErrorResponse.java:20) is omitted when null. In shape 1 it is only filled from `ApiException.getFieldErrorCodes()`, and no patient path sets it. The only producer is `ClinicalValidationAdvice` (doctor clinical controllers, `shared/validation/ClinicalValidationAdvice.java:58-59`), so **patients never receive it**.
- **Constraint names are not sent.** For MethodArgumentNotValid, the constraint code (`NotBlank`, `Size`, …) is only *logged* (`HandledErrorLog.logCodes`, GEH:95-97). The client receives only the message. Constraints used in patient DTOs: `@NotBlank @NotNull @Size @Pattern @Email @Past @Positive @PositiveOrZero @Min @Max @DecimalMin @DecimalMax @AssertTrue @NotEmpty @Digits`.
- Custom messages are English, for example "Must be +216 followed by 8 digits" (auth/api/dto/PhoneRequest.java:10), "OTP must contain exactly 6 digits" (PhoneChangeOtpRequest.java:8), "must be one of M, F, autre" / "must be one of fr, ar, en" (profile/DTO/UpdateProfileRequest.java:20,24), "Weight must be positive" / "Allergy name is required" (profile/DTO/OnboardingStepRequest.java:27,45). Constraints without a `message=` use Hibernate Validator defaults, which are interpolated in the request or JVM locale. The app sends no `Accept-Language` (grep found none) and the backend has no `ValidationMessages*.properties`, so these come out English only if the server's JVM default locale is English.

**Shape 2** has no field errors.

**Shape 3 (`errorCode`)**: no patient handler emits a field list (`errors`/`fieldErrors`). Validation collapses to one code:
- M05 → `REQUEST_INVALID` 400 (field lists deliberately not returned, RequestProblemDetailHandler.java:84-99)
- Booking / scheduled-care / appointment-cancel → `VALIDATION_FAILED` 422 (BookingRequestProblemDetailHandler.java:52-58)
- Availability → `VALIDATION_FAILED` 422 (AvailabilityProblemDetailHandler.java:42-54)
- Consultation → `VALIDATION_FAILED` 400 (ConsultationProblemDetailHandler.java:38-49)
- Clinic → ProblemDetail without `errorCode` (type mismatch) or `CLINIC_STAFF_REQUEST_INVALID` (body, not reachable from patient GETs) (ClinicProblemDetailHandler.java:78-119)
- Medical sharing, prescription, artifact: the advice handles only its exception type, so Bean Validation goes to GEH → shape 1 with `fieldErrors`.

**Shape 4 (`code`)**: urgent cabinet → `VALIDATION_FAILED` 400, no field list (CareCapabilityProblemDetailHandler.java:74-82). The only extra property is `blockingReasons` (List<UrgentReadinessReason>, :112-114), and no patient urgent-cabinet path sets it.

**Shape 5**: `code` is only ever `"UNAUTHORIZED"` or `"FORBIDDEN"` (SERW:59), with no field errors.

**Language of `message` / `detail`**: English, with these exceptions:
- `METHOD_NOT_ALLOWED` message is French (GEH:174).
- The `PATIENT_CHART_*`, `CONSULTATION_FINALIZED`, `MEDICAL_SUMMARY_UPDATE_NOT_ALLOWED` and `ARTIFACT_NOT_DISCARDABLE` default messages are French (EC:178,376-411). CONSULTATION_FINALIZED is only an MRS-mapped code on the prescription and artifact clients.
- Shape 1 `message` = `exception.getMessage()`: the custom text above, or the enum default (ApiException.java:15-27, GEH:47).
- Shape 3 `detail` for Prescription, Artifact, MedicalSharing and Mrs = enum `defaultMessage()` (custom text is discarded). Request, Booking, Availability, Consultation and Clinic use their enum's `detail()`.
- Shape 5 `detail` = ErrorCode default ("Authentication is required." / "You are not allowed to perform this action.").

---

## Section C: codes whose meaning is UNCLEAR

| code | why unclear |
|---|---|
| AUDIT_CIRCUIT_BROKEN (503) | Message is clear ("Tier 1 operations are temporarily blocked"), but which patient endpoints count as "Tier 1" and can surface it was not traced. UNCLEAR |
| MRS_SINGLETON_SERIES_AMBIGUOUS (409) | Defined and mapped (HttpMrsMedicalRecordClient.java:260), but whether a patient-facing write reaches `upsertSingleton` and lets this code through (rather than catching it) was not traced end to end. UNCLEAR |
| PRESCRIPTION_* / CONSULTATION_FINALIZED / IDEMPOTENCY_KEY_REUSED on patient prescription and artifact reads | The MRS client maps many MRS codes (HttpMrsPrescriptionClient.java:144-156; HttpMrsArtifactClient.java:36), but which ones MRS actually returns on *patient read* is not knowable from this repo. UNCLEAR |
| CONFLICT on `/documents/**` | Raised for any MRS 409 **or 410** (HttpMrsDocumentClient.java:553). What the upstream condition means is UNCLEAR |
| Urgent-cabinet `URGENT_CABINET_COMMITMENT_READ_UNAVAILABLE` | The trigger condition inside `requireReadable` (UrgentCabinetTargetedService.java:560-564) was not read in detail. UNCLEAR beyond "cannot currently be read safely" |

---

## Section D: surprises

1. **DirectPatientAuthorizationController (`/me/consultations/*/medical-sharing/*`) answers in shape 1, not 3.** It is missing from `MedicalSharingProblemDetailHandler`'s `assignableTypes` (MedicalSharingProblemDetailHandler.java:25-29), and `MedicalSharingException extends ApiException`, so GEH renders it. It is also not a care-capability `/me/*` path, so its 401/403 are shape 1, not shape 5 (SERW:72-91 only covers `professional-profile/education|certifications`, `practice-locations`, `care-capabilities`, `urgent-runtime`, `urgent-cabinet/`, `urgent-home/` and `equipment`).
2. **On `/me/urgent-cabinet/**`, a 401 comes in two shapes.** No token gives shape 5 `code:"UNAUTHORIZED"`. An invalid or expired token gives shape 1 `code:"AUTH_SESSION_INVALID"`, because the token filter calls `commenceInvalidSession(response)` without the request and so skips the problem-domain branch (OpaqueTokenAuthenticationFilter.java:107-110; RestAuthenticationEntryPoint.java:34-36). Shape 5 also collapses every security ErrorCode to `UNAUTHORIZED`/`FORBIDDEN` (SERW:59).
3. **The same name means different HTTP statuses:** `VALIDATION_FAILED` is 422 in Booking and Availability, 400 in Consultation and CareCapability. `VALIDATION_ERROR` (400) is the GEH/ErrorCode name, and `REQUEST_INVALID` (400) is the M05 name. `NOT_FOUND` (booking) vs `REQUEST_NOT_FOUND` (M05) vs `RESOURCE_NOT_FOUND` (global) vs `CONSULTATION_NOT_FOUND`.
4. **`MRS_UNAVAILABLE` on one endpoint can come in two shapes.** `/documents/**` and `/profile/medical-data` return it as shape 1 when the service throws `ApiException(MRS_UNAVAILABLE)` (DocumentService.java:115…), and as shape 3 when an HTTP client throws `MrsGatewayException`, which the global `MrsProblemDetailHandler` catches at HIGHEST_PRECEDENCE (mrs/MrsProblemDetailHandler.java:20-21). Both send `Retry-After: 30`.
5. **`GET /appointments/{id}` is not under the booking advice.** It is served by `appointment/controller/AppointmentController` (:100-111), which calls `ScheduledAppointmentQueryService.findOwnIfScheduled`. That service can throw `BookingRequestException(NOT_FOUND)` (ScheduledAppointmentQueryService.java:51-58), which is not an ApiException and not in scope of any advice → **500 INTERNAL_SERVER_ERROR**. The normal not-found case falls back to `AppointmentQueryService` → shape 1 `RESOURCE_NOT_FOUND`/`FORBIDDEN`.
6. **The deprecated `POST /appointments` (`doctor_directory_api.dart:111-140`) is `denyAll`** (SEC:225). It always returns 403 `FORBIDDEN` in shape 1, never a booking error.
7. **Clinic type-mismatch ProblemDetail has no `errorCode` property** (ClinicProblemDetailHandler.java:78-103). Clients keyed on `errorCode` will see null.
8. **`POST /notifications/{id}/read` returns 404 with an empty body** (NotificationCenterController.java:73). An unknown `category` query value returns 500 (`valueOf`, :42).
9. **Several framework exceptions fall into the 500 catch-all** because GEH does not extend `ResponseEntityExceptionHandler` and has `@ExceptionHandler(Exception.class)` (GEH:220). This is inferred from code and not covered by tests. The exceptions are `HttpMediaTypeNotSupportedException` (415), `MissingServletRequestParameterException` (for example the required `subjectType` on prescription and artifact reads), `ConstraintViolationException` and `HandlerMethodValidationException` on globally-handled controllers. A concrete case: a **blank or over-long `Idempotency-Key`** on the `@Validated` `PatientMedicalSharingController` / `DirectPatientAuthorizationController` raises ConstraintViolationException, which neither advice handles → 500. A *missing* header → 400 `VALIDATION_ERROR`.
10. **Urgent cabinet submit can leak a 500:** `UrgentDomainException` codes other than ACTIVE_JOURNEY_EXISTS and IDEMPOTENCY_CONFLICT are rethrown (UrgentCabinetTargetedService.java:104-111), and no advice handles `UrgentDomainException` (grep found no `UrgentDomainException.class` handler).
11. **Shape 2 (session limit) is effectively unreachable for patients by default:** `patient-max-sessions` defaults to `0`, which means unlimited (application.yaml:370; DeviceAwareSessionPolicy.java:102,201-203). The environment can override it.
12. **Defined but never thrown anywhere:** `BAD_REQUEST`, `AUTH_SESSION_EXPIRED`, `AUTH_MFA_REQUIRED`, `AUTH_INVALID_TOTP`, `AUTH_ACCOUNT_LOCKED`, `AUTH_ACCOUNT_DISABLED`, `MEDICAL_ACCESS_ALREADY_ACTIVE`, `PRESCRIPTION_NOT_FINALIZABLE`, `ARTIFACT_VERIFICATION_INVALID` (repo-wide grep, 0 uses). An expired access token gives `AUTH_SESSION_INVALID`, never `AUTH_SESSION_EXPIRED`.
13. **The patient artifact screen calls through `lib/features/doctor/artifact/artifact_api.dart`** (`listPatient`/`downloadPatient`, lines 34, 135). That file sits in the excluded `doctor/` folder but is a patient call.
14. **Medical-sharing QR rate limit sends `Retry-After: 300`** (MedicalSharingProblemDetailHandler.java:60-61). Every other 429 sends 60.
15. **`ErrorResponse.requestId` is only populated on the 500 catch-all** (GEH:233-239). Shapes 3, 4 and 5 always carry `requestId`. The `X-Request-Id` response header is set on every request by `shared/http/RequestIdFilter.java:37`.
16. **M05 schedule-proposal codes (`SCHEDULE_*`) are unreachable from the app:** `request_api.dart` never calls `/schedule-proposals/*`. Booking proposals go through `/doctor-booking-requests/*/proposals/*` (booking codes) instead.
