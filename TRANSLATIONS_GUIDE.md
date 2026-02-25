# OmniCare Translations Guide

## Overview
The app supports 3 languages:
- 🇬🇧 English (en)
- 🇫🇷 French (fr)
- 🇸🇦 Arabic (ar)

## How to Use Translations in Your Screens

### 1. Import AppLocalizations
```dart
import '../../l10n/app_localizations.dart';
```

### 2. Get the Localization Instance
```dart
final l10n = AppLocalizations.of(context);
```

### 3. Use Translated Strings

#### Method 1: Using Convenience Getters (Recommended)
```dart
Text(l10n!.welcomeBack)
Text(l10n!.email)
Text(l10n!.password)
```

#### Method 2: Using translate() Method
```dart
Text(l10n!.translate('welcome_back'))
```

## Example: Updating a Screen

### Before (Hardcoded English):
```dart
Text(
  'Welcome Back',
  style: GoogleFonts.plusJakartaSans(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: const Color(0xFF0F6F73),
  ),
)
```

### After (Multi-language):
```dart
final l10n = AppLocalizations.of(context);

Text(
  l10n!.welcomeBack,
  style: GoogleFonts.plusJakartaSans(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: const Color(0xFF0F6F73),
  ),
)
```

## Available Translation Keys

### Login/Signup Screen
- `welcomeBack` - "Welcome Back" / "Bon Retour" / "مرحباً بعودتك"
- `signInContinue` - "Sign in to continue to OmniCare"
- `createAccount` - "Create Account" / "Créer un Compte" / "إنشاء حساب"
- `email` - "Email" / "Email" / "البريد الإلكتروني"
- `password` - "Password" / "Mot de passe" / "كلمة المرور"
- `signIn` - "Sign In" / "Se connecter" / "تسجيل الدخول"
- `signUp` - "Sign Up" / "S'inscrire" / "التسجيل"
- `continueWithGoogle` - "Sign in with Google"
- `or` - "OR" / "OU" / "أو"

### Validation Messages
- `emailRequired` - "Email is required"
- `validEmail` - "Please enter a valid email"
- `passwordRequired` - "Password is required"
- `passwordMinLength` - "Password must be at least 6 characters"
- `passwordsNotMatch` - "Passwords do not match"

### OTP Verification
- `verifyEmail` - "Verify Email"
- `verifyPhone` - "Verify Phone"
- `codeSentTo` - "We sent a code to"
- `verify` - "Verify"
- `resendCode` - "Resend code"

### Conversational Onboarding
- `bloodTypeQuestion` - "What is your blood type?"
- `chronicConditionsQuestion` - "Any chronic conditions?"
- `currentMedications` - "Current Medications"
- `medicineName` - "Medicine Name"
- `dosage` - "Dosage"
- `complete` - "Complete"
- `skip` - "Skip"

## Adding New Translations

1. Open `/lib/l10n/app_localizations.dart`
2. Add the key-value pair to all 3 language maps (en, fr, ar)
3. Add a convenience getter if desired

Example:
```dart
static final Map<String, Map<String, String>> _localizedValues = {
  'en': {
    'new_key': 'English Text',
    // ... other keys
  },
  'fr': {
    'new_key': 'Texte Français',
    // ... other keys
  },
  'ar': {
    'new_key': 'النص العربي',
    // ... other keys
  },
};

// Add getter
String get newKey => translate('new_key');
```

## How Language Selection Works

1. User selects language on Language Selection Screen
2. Language code (en/fr/ar) is saved to `UserOnboardingProvider`
3. `main.dart` listens to provider and updates app locale
4. All screens automatically rebuild with new translations

## Testing Different Languages

To test a specific language without going through the language selection:
```dart
// In main.dart, temporarily set:
locale: const Locale('fr'), // or 'ar' for Arabic
```

## RTL Support for Arabic

Arabic text direction (RTL) is automatically handled by Flutter's localization system.
