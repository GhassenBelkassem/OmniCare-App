# Changelog

## Format Rule (applies going forward)

- Each major entry must include a **Files changed** section listing the relevant backend/frontend files.

## Consultation Sync Fix (Backend <-> Frontend)

- **Backend**
  - Aligned consultation responses to the Flat DTO shape.
  - Enforced **snake_case** JSON keys for the consultation response DTO.
- **Frontend**
  - Updated the Flutter `Consultation` model to parse the Flat DTO reliably.
  - Added robust parsing to accept both **snake_case** and **camelCase** keys (defensive compatibility).

### Files changed

- **Backend**
  - `OmnicareBackend/src/main/java/com/omnicare/doctor/controller/ConsultationController.java`
  - `OmnicareBackend/src/main/java/com/omnicare/provider/controller/ProviderMeController.java`
- **Frontend**
  - `lib/core/models/consultation.dart`
  - `lib/core/api/provider_me_api.dart`
  - `lib/features/doctor/request_accepted_screen.dart`
  - `lib/features/doctor/doctor_dashboard_screen.dart`
  - `lib/features/doctor/consultation_detail_screen.dart`
  - `lib/features/home/history_tab.dart`
  - `lib/core/models/patient_models.dart`
  - `lib/core/api/patients_api.dart`
  - `lib/features/doctor/navigation_screen.dart`
  - `lib/features/doctor/patient_medical_passport_screen.dart`

## Current State

- **Connectivity test verified**
  - PowerShell test successfully:
    - created/ensured a dev doctor user,
    - logged in to obtain a fresh JWT,
    - called `GET /api/consultations/{id}` and received a valid JSON payload.
  - This confirms the authentication + data pipeline is functioning end-to-end.

- **Flutter runtime payload verified**
  - Flutter logs show `✅ API 200 GET /api/providers/me/consultations` and repeated `DEBUG: Consultation JSON: {...}` entries containing the expected Flat DTO fields (e.g. `patient_id`, `patient_name`, `patient_age`, `patient_gender`, `net_amount`, `omnicare_fee`).
  - This confirms the mobile app is receiving and parsing the same snake_case response shape.

## Pending Tasks

- **Null vitals handling in UI**
  - Height/weight may be `null` in the consultation payload; Flutter UI still needs to present a clean fallback display (no broken formatting / placeholders).
