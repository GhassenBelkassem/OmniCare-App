import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'features/auth/splash_screen.dart';
import 'features/auth/phone_input_screen.dart';
import 'features/profile/vital_info_screen.dart';
import 'features/profile/medications_screen.dart';
import 'features/profile/medical_documents_screen.dart';
import 'features/onboarding/conversational_onboarding_screen.dart';
import 'features/home/home_screen.dart';
import 'providers/user_onboarding_provider.dart';
import 'l10n/app_localizations.dart';

void main() {
  runApp(const OmniCareApp());
}

class OmniCareApp extends StatelessWidget {
  const OmniCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => UserOnboardingProvider(),
      child: Consumer<UserOnboardingProvider>(
        builder: (context, provider, child) {
          Locale locale = const Locale('en');
          if (provider.language != null) {
            locale = Locale(provider.language!);
          }

          return MaterialApp(
            title: 'OmniCare',
            debugShowCheckedModeBanner: false,
            locale: locale,
            supportedLocales: const [
              Locale('en'),
              Locale('fr'),
              Locale('ar'),
            ],
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF1FBF9A),
                primary: const Color(0xFF1FBF9A),
                secondary: const Color(0xFF6BE3B2),
              ),
              scaffoldBackgroundColor: const Color(0xFFF4F5F7),
              textTheme: GoogleFonts.plusJakartaSansTextTheme(),
              useMaterial3: true,
            ),
            home: const SplashScreen(),
            routes: {
              '/phone-input': (context) => const PhoneInputScreen(),
              '/medical-profile': (context) => const VitalInfoScreen(),
              '/medications': (context) => const MedicationsScreen(),
              '/medical-documents': (context) => const MedicalDocumentsScreen(),
              '/conversational-onboarding': (context) => const ConversationalOnboardingScreen(),
              '/home': (context) => const HomeScreen(),
            },
          );
        },
      ),
    );
  }
}
