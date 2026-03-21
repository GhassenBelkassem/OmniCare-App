# Project Structure

## Tech Stack

- **Backend**
  - Spring Boot (Java)
- **Frontend**
  - Flutter (Dart)

## Critical Architecture

- **Flat DTO pattern for Consultations**
  - Consultation payloads returned by the backend are intentionally flattened into a single DTO (the “Flat DTO”) that includes consultation fields plus the key patient/vitals fields.
  - This exists to avoid frontend issues caused by nested/optional structures and inconsistent serialization.

## Database / Domain Model Relationships

- **Patient**
  - A `Patient` represents either:
    - a `USER` (links to `User`), or
    - a `FAMILY_MEMBER` (links to `FamilyMember`).
  - Patient demographic/vitals fields may come from `User` / `FamilyMember` identity fields and/or `medicalInfo`.

## Service Rules

- **Only `com.omnicare` is authoritative**
  - All backend work must happen under the `com.omnicare` package.
  - The `com.omnilinks` package is **not** used for current backend routing/logic and must be ignored for implementation work.

## Active API Endpoints ↔ Dart Models

Notes:

- Backend paths below are shown **without** the `/api` prefix duplication for brevity; the actual base paths in controllers are under `/api/...` (and a few also have `/v1/...`).
- “Model” refers to existing Dart classes under `lib/core/models`. If “(none)” then the app is currently parsing the response ad-hoc (Map) or the feature isn’t wired in Flutter yet.

### Auth (`com.omnicare.auth.controller`)

- **POST `/api/auth/login`**
  - **Model**: (none) (response wrapped in backend `ApiResponse<LoginResponseData>`)
- **POST `/api/auth/google`**
  - **Model**: (none)
- **POST `/api/auth/register`**
  - **Model**: (none)
- **POST `/api/auth/verify-email-otp`**
  - **Model**: (none)
- **POST `/api/auth/set-phone`**
  - **Model**: (none)
- **POST `/api/auth/logout`**
  - **Model**: (none)
- **POST `/api/auth/set-initial-password`**
  - **Model**: (none)

#### Phone OTP (`PhoneOtpController`)

- **POST `/api/auth/request-phone-otp`**
  - **Model**: (none)
- **POST `/api/auth/verify-phone-otp`**
  - **Model**: (none)

#### Dev auth (`DevAuthController`, `DevProfessionalSeedController`)

- **POST `/auth/dev/create-doctor`**
- **POST `/auth/dev/create-professional`**
- **POST `/auth/dev/create-patient`**
- **POST `/auth/dev/create-admin`**
- **POST `/auth/dev/request-phone-otp`**
- **POST `/auth/dev/verify-phone-otp`**
- **GET `/auth/dev/mappings`**
- **POST `/auth/dev/ensure-fake-doctor`**
- **POST `/auth/dev/ensure-fake-patient`**
- **POST `/auth/dev/consultations/{id}/auto-complete`**
- **POST `/auth/dev/mega-seed`**
  - **Model**: (none)

### Account (`com.omnicare.account.AccountController`)

- **GET `/api/account/me`**
  - **Model**: (none)
- **PATCH `/api/account/medical-passport`**
  - **Model**: `AccountUser` (subset)
- **GET `/api/account/full-profile`**
  - **Model**: `AccountFullProfile` (`AccountUser`, `AccountFamilyMember`, `AccountMedicalDocument`)
- **POST `/api/account/password`**
  - **Model**: (none)

### Users / Profile (`com.omnicare.profile.controller`)

- **PATCH `/api/users/me`**
  - **Model**: (none)

### Family (`com.omnicare.family.FamilyMemberController`)

- **POST `/api/family`**
  - **Model**: `FamilyMember` (`lib/core/models/family_models.dart`)
- **GET `/api/family`**
  - **Model**: `FamilyMember`
- **PATCH `/api/family/{id}`**
  - **Model**: `FamilyMember`
- **DELETE `/api/family/{id}`**
  - **Model**: (none)
- **PATCH `/api/family/{id}/medical-passport`**
  - **Model**: `FamilyMember`

### Patients / Passport (`com.omnicare.patient.controller.PatientController`)

- **GET `/api/patients`**
  - **Model**: `PatientSummary` (NOTE: there are *two* `PatientSummary` classes: `lib/core/models/patient.dart` and `lib/core/models/patient_models.dart`)
- **GET `/api/patients/doctor`**
  - **Model**: `PatientSummary`
- **GET `/api/patients/{patientId}/passport`**
  - **Model**: `PatientPassport` (`lib/core/models/patient_models.dart`)
- **GET `/api/patients/{patientId}/medical-passport`**
  - **Model**: `PatientPassport` (partial)
- **POST `/api/patients/{patientId}/medical-passport`**
  - **Model**: `PatientPassport` (partial)

#### Patient allergies

- **GET `/api/patients/{patientId}/allergies`**
  - **Model**: (none)
- **POST `/api/patients/{patientId}/allergies`**
  - **Model**: (none)
- **DELETE `/api/patients/{patientId}/allergies/{allergyId}`**
  - **Model**: (none)

#### Patient medications (current medicines)

- **GET `/api/patients/{patientId}/medications`**
  - **Model**: `PatientMedicationSummary` (close match; API returns more fields than the summary)
- **POST `/api/patients/{patientId}/medications`**
  - **Model**: (none)
- **DELETE `/api/patients/{patientId}/medications/{patientMedicationId}`**
  - **Model**: (none)

#### Patient chronic conditions

- **GET `/api/patients/{patientId}/conditions`**
  - **Model**: (none)
- **POST `/api/patients/{patientId}/conditions`**
  - **Model**: (none)
- **DELETE `/api/patients/{patientId}/conditions/{conditionId}`**
  - **Model**: (none)

### Access (patient-provider sharing) (`com.omnicare.access.controller.PatientAccessController`)

- **POST `/api/access/share-token`**
  - **Model**: (none)
- **POST `/api/access/redeem`**
  - **Model**: (none)
- **POST `/api/access/grants/{accessId}/revoke`**
  - **Model**: (none)
- **POST `/api/access/grants/{accessId}/report`**
  - **Model**: (none)

### Consultations (flat DTO) (`com.omnicare.doctor.controller.ConsultationController`)

- **GET `/api/consultations?status=...`**
  - **Model**: `Consultation` (`lib/core/models/consultation.dart`) *(Flat DTO, supports snake_case + camelCase)*
- **POST `/api/consultations`**
  - **Model**: `Consultation` (create response)
- **PATCH `/api/consultations/{id}`**
  - **Model**: `Consultation` (patch response)
- **POST `/api/consultations/{id}/complete`**
  - **Model**: `Consultation` (complete response)
- **GET `/api/consultations/{id}/prescription`**
  - **Model**: (none) (currently parsed as `Map<String,dynamic>` in Flutter)
- **PUT `/api/consultations/{id}/prescription`**
  - **Model**: (none) (request payload built in Flutter and sent as a Map)

### Prescriptions (`com.omnicare.prescription.controller.PrescriptionController`)

- **POST `/api/prescriptions`**
  - **Model**: (none)
- **PUT `/api/prescriptions/{id}`**
  - **Model**: (none)
- **GET `/api/prescriptions?patientId=...`**
  - **Model**: (none)

### Medications catalog (`com.omnicare.medication.MedicationController`)

- **GET `/api/medications/search?q=...`**
  - **Model**: `MedicationSearchResult` (`lib/core/api/medications_api.dart`)
- **GET `/api/medications/dci?q=...`**
  - **Model**: (none)
- **GET `/api/medications/{id}`**
  - **Model**: `MedicationSearchResult` (same)

### Provider Me (`com.omnicare.provider.controller.ProviderMeController`)

- **GET `/api/providers/me`**
  - **Model**: (none)
- **GET `/api/providers/me/consultations?status=...`**
  - **Model**: `Consultation` (same Flat DTO)
- **GET `/api/providers/me/patients`**
  - **Model**: `PatientSummary`

### Doctors (search + doctor dashboard endpoints)

#### Doctor search (`DoctorSearchController`)

- **GET `/api/doctors?specialty=...`**
  - **Model**: (none)

#### Doctor self endpoints (`DoctorController`)

- **PATCH `/api/doctor/status`**
  - **Model**: (none)
- **PATCH `/api/doctor/profile`**
  - **Model**: (none)
- **GET `/api/doctor/profile`**
  - **Model**: (none)
- **GET `/api/doctor/history`**
  - **Model**: `Consultation` is a close match, but backend returns a different DTO (doctor-centric)
- **GET `/api/doctor/revenue?limit=...`**
  - **Model**: (none)

### Reservations (`com.omnicare.reservation.controller.ReservationController`)

- **POST `/api/reservations/requests`**
  - **Model**: (none)
- **GET `/api/reservations/requests?status=...`**
  - **Model**: (none)
- **POST `/api/reservations/requests/{requestId}/propose`**
  - **Model**: (none)
- **POST `/api/reservations/requests/{requestId}/accept`**
  - **Model**: (none)
- **POST `/api/reservations/requests/{requestId}/cancel`**
  - **Model**: (none)

### Medical Acts (`com.omnicare.medicalact.controller.MedicalActController`)

- **POST `/api/medical-acts`**
  - **Model**: (none)

### Documents (`com.omnicare.document.MedicalDocumentController`)

- **POST `/api/documents`**
  - **Model**: `AccountMedicalDocument` is a close match (document fields align)

### Reminders (`com.omnicare.reminder.controller.PatientReminderController`)

- **GET `/api/patients/{patientId}/reminders`**
  - **Model**: (none)
- **POST `/api/patients/{patientId}/reminders`**
  - **Model**: (none)
- **PUT `/api/patients/{patientId}/reminders/{reminderId}`**
  - **Model**: (none)
- **DELETE `/api/patients/{patientId}/reminders/{reminderId}`**
  - **Model**: (none)

### Home (`com.omnicare.home.HomeController`)

- **GET `/`**
  - **Model**: (none)

## Provider-Agnostic Architecture Guidance

Goal: keep both backend and Flutter extensible so new `ProviderType`s can be introduced without refactoring core flows.

### Backend: provider-centric access patterns

- **Rule: authorize via PatientAccess scopes, not via provider type checks**
  - Prefer enforcing permissions through `PatientAccessService.requireProviderAccess(..., Scope.X)`.
  - Provider type (`ProviderType`) should only be used for business rules that are truly type-specific (ex: who can prescribe, who can create medical acts), not for basic read/write access control.

- **Expose “my provider context” as the stable entrypoint**
  - `GET /api/providers/me` should be treated as the canonical way for any professional actor (doctor/nurse/kine/...) to discover:
    - `providerId`
    - `providerType`
    - online status
  - Any frontend feature that needs provider context should depend on this call rather than hardcoding role/type.

- **Prefer provider-scoped listings over type-specific endpoints**
  - For shared professional workflows, prefer endpoints like:
    - `GET /api/providers/me/consultations`
    - `GET /api/providers/me/patients`
  - Keep specialized endpoints (like `/api/doctor/revenue`) as optional “capability modules”, not required for the base experience.

### Flutter: capability-driven navigation & UI composition

- **Use a “provider context” object as a first-class concept**
  - After login, load provider context once (ex: via `/api/providers/me`) and store it in a single place (app state).
  - UI and routing should consult this context rather than branching on scattered `if (providerType == ...)` checks.

- **Prefer capabilities over `ProviderType` branching**
  - Define capabilities your UI cares about (examples):
    - `canPrescribe`
    - `canPerformMedicalActs`
    - `hasRevenueDashboard`
    - `supportsTreatmentPlans`
  - Map provider types to capabilities in one place.
  - Screens/tabs become “feature modules” that are enabled/disabled based on capabilities.

- **Navigation: route to the same flow, swap feature modules**
  - Keep the core consultation flow provider-agnostic:
    - list consultations
    - open consultation details
    - write notes/diagnosis/treatment (if permitted)
  - Add optional modules:
    - Doctor: e-prescription
    - Nurse/Kine: medical acts
    - Kine: treatment plan linkage

- **Data models: prefer shared “base DTOs” + feature payloads**
  - Keep using the `Consultation` Flat DTO for shared UI.
  - Add dedicated Dart models when a response becomes non-trivial (ex: prescription response/items) instead of passing around `Map<String, dynamic>`.
