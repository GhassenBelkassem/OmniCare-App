# OmniCare End-to-End Testing Checklist

## 0) Prerequisites

- Backend running on:
  - `http://localhost:8080`
- Flutter `.env` contains:
  - `API_BASE_URL=http://localhost:8080/api`
- You have a valid Google Maps Web API key ready (for Flutter Web).
- You have Google OAuth client configured and `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` set for the backend.

### Database tooling (Postgres maintenance)

- **Primary pgAdmin tool path (Windows)**
  - `D:\pgAdmin 4\runtime`
  - Use this as the canonical path when running pgAdmin-related maintenance to avoid future **Path Not Found** issues.

---

## 1) Backend sanity checks

1. Start backend (from `c:\Users\Jay\OneDrive\Documents\Omnicare`).
2. Confirm backend is reachable in a browser:
   - Open:
     - `http://localhost:8080/api/medications/search?q=para`
   - Expected:
     - JSON response (list)

### Error shape check
If you intentionally hit a protected endpoint without a token, errors should be:

```json
{"error":"CODE","message":"Human readable message"}
```

---

## 2) Web setup (Maps)

In `web/index.html` you must set a real key:

- Find:
  - `https://maps.googleapis.com/maps/api/js?key=%GOOGLE_MAPS_API_KEY%`
- Replace `%GOOGLE_MAPS_API_KEY%` with your actual key.

If Maps isn’t configured, you may see Chrome errors like:
- `TypeError: Cannot read properties of undefined (reading 'maps')`

---

## 3) Run Flutter

From `c:\Users\Jay\OneDrive\Documents\OmnicareFrontend`:

```powershell
flutter pub get
flutter run -d chrome
```

Keep the terminal open to see the logs.

---

## 4) Auth test (Email/Password)

1. App opens to Language Selection.
2. Choose a language.
3. Click `Sign up`.
4. Click `Sign up with Email` (this reveals the form).
5. Enter:
   - Email
   - Password
   - Name (optional)
6. Click `Create account`.

Expected in console logs:
- A request log:
  - `🚀 API POST http://localhost:8080/api/auth/register`
  - `🚀 API 📦 {email: ..., password: ..., name: ...}`
- A response log:
  - `🚀 API ✅ 200 POST http://localhost:8080/api/auth/register` (or `201`)

If it fails, expected:
- SnackBar shows backend message from `{error,message}`.

### Login
1. After signup you should be on Login.
2. Click `Sign in with Email` (reveals form).
3. Enter email + password.
4. Click `Sign In`.

Expected logs:
- `🚀 API POST http://localhost:8080/api/auth/login`
- Response contains `{token: "..."}`

---

## 5) Auth test (Google)

1. On Login, click `Continue with Google`.

Expected:
- Google popup
- Backend call:
  - `🚀 API POST http://localhost:8080/api/auth/google`
- Response:
  - `{token: "..."}`

If it fails:
- SnackBar shows backend error message (from `{error,message}`)

---

## 6) Emergency Wizard (Create Consultation)

From Home:
1. Start Emergency flow.
2. Step 1: select patient.
3. Step 2:
   - select at least one body part
   - set pain level
   - enter description
4. Step 3:
   - allow location
   - ensure GPS lat/lng exists
5. Proceed to Review/Confirm and press `CONFIRMER LA DEMANDE`.

Expected logs (order):
1. List doctors:
   - `🚀 API GET http://localhost:8080/api/doctors`
2. Create consultation:
   - `🚀 API POST http://localhost:8080/api/consultations`
   - `🚀 API 📦 {doctorId: ..., symptoms: ..., painLevel: ..., affectedAreas: ..., latitude: ..., longitude: ...}`
3. Success:
   - `🚀 API ✅ 200 POST http://localhost:8080/api/consultations`

If it fails:
- SnackBar shows backend message via `apiErrorMessage(e)`.

---

## 7) What “success” looks like

- You see `✅` response logs for auth + consultation.
- No CORS errors in the Chrome console.
- After confirm, you navigate to the next screen and the request arguments contain `consultationId`.
