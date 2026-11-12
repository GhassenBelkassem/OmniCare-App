import 'package:flutter/widgets.dart';

/// The app's only language for V1: French (roadmap G-2 §4.1 Q10).
///
/// The profile `preferredLanguage` and the onboarding language choice are
/// still read and stored, but they do not change the app language yet.
/// Arabic and English come back by adding `app_ar.arb` / `app_en.arb`.
const Locale appLocale = Locale('fr');
