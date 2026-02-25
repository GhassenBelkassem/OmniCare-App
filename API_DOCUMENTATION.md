# OmniCare Mobile App - Backend API Documentation

## Overview
This document outlines all the API endpoints required by the OmniCare mobile application to support the complete authentication and onboarding flow.

**Base URL**: `https://api.omnicare.tn/v1`

**Authentication**: JWT Bearer Token (after login)

---

## 📱 Authentication Flow

### 1. Language Selection
**Screen**: `LanguageSelectionScreen`
**Purpose**: User selects preferred language (English, French, Arabic)
**Client-Side Only**: No API call needed - stored locally in app state

---

### 2. User Registration (Sign Up)

#### 2.1 Register with Email/Password

**Endpoint**: `POST /auth/register`

**Request Body**:
```json
{
  "email": "user@example.com",
  "password": "securePassword123",
  "language": "en"
}
```

**Validation Rules**:
- Email: Valid email format, unique in database
- Password: Minimum 6 characters
- Language: One of `["en", "fr", "ar"]`

**Success Response** (201 Created):
```json
{
  "success": true,
  "message": "Registration successful. Please verify your email.",
  "data": {
    "userId": "usr_1234567890",
    "email": "user@example.com",
    "emailVerified": false,
    "requiresEmailVerification": true
  }
}
```

**Error Responses**:
- **400 Bad Request**: Invalid input data
  ```json
  {
    "success": false,
    "error": "VALIDATION_ERROR",
    "message": "Email is already registered",
    "field": "email"
  }
  ```

- **422 Unprocessable Entity**: Password too weak
  ```json
  {
    "success": false,
    "error": "WEAK_PASSWORD",
    "message": "Password must be at least 6 characters"
  }
  ```

---

#### 2.2 Send Email Verification OTP

**Endpoint**: `POST /auth/send-email-otp`

**Request Body**:
```json
{
  "email": "user@example.com"
}
```

**Success Response** (200 OK):
```json
{
  "success": true,
  "message": "Verification code sent to your email",
  "data": {
    "expiresIn": 300,
    "canResendIn": 60
  }
}
```

**Error Responses**:
- **404 Not Found**: Email not found
- **429 Too Many Requests**: Rate limit exceeded
  ```json
  {
    "success": false,
    "error": "RATE_LIMIT_EXCEEDED",
    "message": "Please wait 60 seconds before requesting a new code",
    "retryAfter": 45
  }
  ```

---

#### 2.3 Verify Email OTP

**Endpoint**: `POST /auth/verify-email`

**Request Body**:
```json
{
  "email": "user@example.com",
  "otp": "123456"
}
```

**Validation Rules**:
- OTP: 6-digit numeric code
- Must be verified within 5 minutes of generation

**Success Response** (200 OK):
```json
{
  "success": true,
  "message": "Email verified successfully",
  "data": {
    "userId": "usr_1234567890",
    "emailVerified": true,
    "requiresPhoneVerification": true
  }
}
```

**Error Responses**:
- **400 Bad Request**: Invalid or expired OTP
  ```json
  {
    "success": false,
    "error": "INVALID_OTP",
    "message": "Invalid or expired verification code"
  }
  ```

- **410 Gone**: OTP expired
  ```json
  {
    "success": false,
    "error": "OTP_EXPIRED",
    "message": "Verification code has expired. Please request a new one."
  }
  ```

---

#### 2.4 Add Phone Number

**Endpoint**: `POST /auth/add-phone`

**Request Headers**:
```
Authorization: Bearer {temporary_token_from_email_verification}
```

**Request Body**:
```json
{
  "phoneNumber": "+21612345678"
}
```

**Validation Rules**:
- Phone number: E.164 format (e.g., +216XXXXXXXX for Tunisia)
- Must be unique in database

**Success Response** (200 OK):
```json
{
  "success": true,
  "message": "Phone number added. Verification code sent via SMS.",
  "data": {
    "phoneNumber": "+21612345678",
    "phoneVerified": false,
    "expiresIn": 300,
    "canResendIn": 60
  }
}
```

**Error Responses**:
- **400 Bad Request**: Invalid phone format
- **409 Conflict**: Phone number already registered

---

#### 2.5 Send Phone Verification OTP

**Endpoint**: `POST /auth/send-phone-otp`

**Request Body**:
```json
{
  "phoneNumber": "+21612345678"
}
```

**Success Response** (200 OK):
```json
{
  "success": true,
  "message": "Verification code sent via SMS",
  "data": {
    "expiresIn": 300,
    "canResendIn": 60
  }
}
```

---

#### 2.6 Verify Phone OTP

**Endpoint**: `POST /auth/verify-phone`

**Request Headers**:
```
Authorization: Bearer {temporary_token}
```

**Request Body**:
```json
{
  "phoneNumber": "+21612345678",
  "otp": "123456"
}
```

**Success Response** (200 OK):
```json
{
  "success": true,
  "message": "Phone verified successfully",
  "data": {
    "userId": "usr_1234567890",
    "phoneVerified": true,
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expiresIn": 3600,
    "user": {
      "id": "usr_1234567890",
      "email": "user@example.com",
      "phoneNumber": "+21612345678",
      "emailVerified": true,
      "phoneVerified": true,
      "language": "en",
      "onboardingComplete": false
    }
  }
}
```

---

### 3. User Login

#### 3.1 Login with Email/Password

**Endpoint**: `POST /auth/login`

**Request Body**:
```json
{
  "email": "user@example.com",
  "password": "securePassword123"
}
```

**Success Response** (200 OK):
```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expiresIn": 3600,
    "user": {
      "id": "usr_1234567890",
      "email": "user@example.com",
      "phoneNumber": "+21612345678",
      "emailVerified": true,
      "phoneVerified": true,
      "language": "en",
      "onboardingComplete": true,
      "profile": {
        "firstName": "Ahmed",
        "lastName": "Ben Salem",
        "avatar": "https://cdn.omnicare.tn/avatars/usr_1234567890.jpg"
      }
    }
  }
}
```

**Error Responses**:
- **401 Unauthorized**: Invalid credentials
  ```json
  {
    "success": false,
    "error": "INVALID_CREDENTIALS",
    "message": "Invalid email or password"
  }
  ```

- **403 Forbidden**: Account not verified
  ```json
  {
    "success": false,
    "error": "EMAIL_NOT_VERIFIED",
    "message": "Please verify your email before logging in",
    "requiresVerification": true,
    "email": "user@example.com"
  }
  ```

- **423 Locked**: Account suspended
  ```json
  {
    "success": false,
    "error": "ACCOUNT_SUSPENDED",
    "message": "Your account has been suspended. Please contact support."
  }
  ```

---

#### 3.2 Google Sign-In (OAuth)

**Endpoint**: `POST /auth/google`

**Request Body**:
```json
{
  "idToken": "google_id_token_from_firebase_or_google_sdk",
  "language": "en"
}
```

**Success Response** (200 OK):
```json
{
  "success": true,
  "message": "Google sign-in successful",
  "data": {
    "isNewUser": false,
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expiresIn": 3600,
    "user": {
      "id": "usr_1234567890",
      "email": "user@gmail.com",
      "emailVerified": true,
      "phoneNumber": null,
      "phoneVerified": false,
      "language": "en",
      "onboardingComplete": false,
      "profile": {
        "firstName": "Ahmed",
        "lastName": "Ben Salem",
        "avatar": "https://lh3.googleusercontent.com/..."
      }
    }
  }
}
```

**Note**: If `isNewUser: true`, the app should prompt for phone number verification.

---

### 4. Password Reset Flow

#### 4.1 Request Password Reset

**Endpoint**: `POST /auth/forgot-password`

**Request Body**:
```json
{
  "emailOrPhone": "user@example.com"
}
```

**Note**: Accepts either email or phone number

**Success Response** (200 OK):
```json
{
  "success": true,
  "message": "Password reset code sent",
  "data": {
    "sentTo": "user@example.com",
    "method": "email",
    "expiresIn": 300,
    "canResendIn": 60
  }
}
```

**Error Responses**:
- **404 Not Found**: User not found
  ```json
  {
    "success": false,
    "error": "USER_NOT_FOUND",
    "message": "No account found with this email or phone number"
  }
  ```

---

#### 4.2 Verify Reset OTP

**Endpoint**: `POST /auth/verify-reset-otp`

**Request Body**:
```json
{
  "emailOrPhone": "user@example.com",
  "otp": "123456"
}
```

**Success Response** (200 OK):
```json
{
  "success": true,
  "message": "OTP verified successfully",
  "data": {
    "resetToken": "temp_reset_token_xyz123",
    "expiresIn": 600
  }
}
```

---

#### 4.3 Reset Password

**Endpoint**: `POST /auth/reset-password`

**Request Body**:
```json
{
  "resetToken": "temp_reset_token_xyz123",
  "newPassword": "newSecurePassword123"
}
```

**Validation Rules**:
- Password: Minimum 6 characters
- Reset token must be valid and not expired

**Success Response** (200 OK):
```json
{
  "success": true,
  "message": "Password reset successfully",
  "data": {
    "userId": "usr_1234567890"
  }
}
```

**Error Responses**:
- **400 Bad Request**: Invalid or expired reset token
- **422 Unprocessable Entity**: Password validation failed

---

### 5. Token Management

#### 5.1 Refresh Access Token

**Endpoint**: `POST /auth/refresh`

**Request Body**:
```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Success Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expiresIn": 3600
  }
}
```

**Error Responses**:
- **401 Unauthorized**: Invalid or expired refresh token

---

#### 5.2 Logout

**Endpoint**: `POST /auth/logout`

**Request Headers**:
```
Authorization: Bearer {access_token}
```

**Request Body**:
```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Success Response** (200 OK):
```json
{
  "success": true,
  "message": "Logged out successfully"
}
```

---

## 📋 Data Models

### User Model
```typescript
{
  id: string;                    // Unique user ID
  email: string;                 // User email
  phoneNumber: string | null;    // Phone number in E.164 format
  emailVerified: boolean;        // Email verification status
  phoneVerified: boolean;        // Phone verification status
  language: "en" | "fr" | "ar";  // Preferred language
  onboardingComplete: boolean;   // Medical onboarding status
  profile: {
    firstName: string | null;
    lastName: string | null;
    avatar: string | null;      // Avatar URL
    dateOfBirth: string | null; // ISO 8601 date
    gender: "male" | "female" | "other" | null;
  };
  medicalPassport: {
    bloodGroup: string | null;
    chronicConditions: string[];
    medications: Medication[];
    allergies: string[];
  };
  createdAt: string;             // ISO 8601 timestamp
  updatedAt: string;             // ISO 8601 timestamp
}
```

### Medication Model
```typescript
{
  id: string;
  name: string;
  dosage: string;
  frequency: string;
  startDate: string;  // ISO 8601 date
  endDate: string | null;
  prescribedBy: string | null;
}
```

---

## 🔒 Security Requirements

### Password Requirements
- Minimum 6 characters
- Should contain mix of letters and numbers (recommended)
- Hashed using bcrypt with salt rounds >= 10

### OTP Requirements
- 6-digit numeric code
- Valid for 5 minutes
- Rate limit: 1 request per 60 seconds
- Maximum 3 failed attempts before lockout

### JWT Tokens
- **Access Token**: Expires in 1 hour
- **Refresh Token**: Expires in 30 days
- Algorithm: HS256 or RS256
- Include user ID and role in payload

### Rate Limiting
- Login attempts: 5 per 15 minutes per IP
- OTP requests: 1 per 60 seconds per user
- Password reset: 3 per hour per user

---

## 📱 Client-Side Flow Summary

### Sign Up Flow:
1. User selects language → Stored locally
2. User enters email + password → `POST /auth/register`
3. User receives email OTP → `POST /auth/send-email-otp`
4. User verifies email → `POST /auth/verify-email`
5. User enters phone number → `POST /auth/add-phone`
6. User receives SMS OTP → Auto-sent from step 5
7. User verifies phone → `POST /auth/verify-phone`
8. User receives JWT tokens → Navigate to onboarding/home

### Login Flow:
1. User enters email + password → `POST /auth/login`
2. Receive JWT tokens → Navigate to home
3. Store tokens securely (Flutter Secure Storage)

### Google Sign-In Flow:
1. User taps "Sign in with Google"
2. Google OAuth flow → Get ID token
3. Send ID token → `POST /auth/google`
4. Receive JWT tokens → Navigate to home or phone verification

### Forgot Password Flow:
1. User enters email/phone → `POST /auth/forgot-password`
2. User receives OTP → Via email or SMS
3. User verifies OTP → `POST /auth/verify-reset-otp`
4. User enters new password → `POST /auth/reset-password`
5. Navigate to login screen

---

## 🧪 Testing Endpoints

For development/testing, the backend should provide:

### Test OTP Endpoint (Development Only)
**Endpoint**: `GET /auth/test/otp/:emailOrPhone`

Returns the current valid OTP for testing without sending SMS/email.

**Response**:
```json
{
  "otp": "123456",
  "expiresAt": "2026-02-24T14:30:00Z"
}
```

---

## 📝 Notes for Backend Team

1. **Email Service**: Integrate with SendGrid, AWS SES, or similar for email OTPs
2. **SMS Service**: Integrate with Twilio, AWS SNS, or similar for SMS OTPs
3. **Database**: Store users, OTPs (with expiry), and sessions
4. **Caching**: Use Redis for OTP storage and rate limiting
5. **Logging**: Log all authentication attempts for security auditing
6. **CORS**: Configure CORS to allow mobile app requests
7. **HTTPS**: All endpoints must use HTTPS in production
8. **Error Handling**: Return consistent error format across all endpoints
9. **Validation**: Validate all inputs server-side
10. **Localization**: Support error messages in EN, FR, AR based on user language preference

---

## 🔄 API Versioning

Current version: `v1`

All endpoints are prefixed with `/v1/` to support future API versions.

---

**Last Updated**: February 24, 2026
**Maintained By**: OmniCare Mobile Development Team
