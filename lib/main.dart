import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'features/auth/splash_screen.dart';
import 'features/auth/phone_input_screen.dart';
import 'features/profile/vital_info_screen.dart';
import 'features/profile/medications_screen.dart';
import 'features/profile/medical_documents_screen.dart';
import 'features/onboarding/conversational_onboarding_screen.dart';
import 'features/home/home_screen.dart';
import 'features/home/new_home_screen.dart';
import 'features/emergency/emergency_request_step0.dart';
import 'features/emergency/emergency_request_step1.dart';
import 'features/emergency/emergency_request_step2.dart';
import 'features/emergency/emergency_request_step3.dart';
import 'features/emergency/emergency_review_screen.dart';
import 'features/emergency/doctor_selection_screen.dart';
import 'features/emergency/review_confirm_screen.dart';
import 'features/emergency/doctor_calling_screen.dart';
import 'features/emergency/doctor_arriving_screen.dart';
import 'features/emergency/consultation_qr_screen.dart';
import 'features/emergency/consultation_complete_screen.dart';
import 'features/doctor/doctor_dashboard_screen.dart';
import 'features/request/provider_selection_screen.dart';
import 'features/request/consultation_type_screen.dart';
import 'features/request/provider_list_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/notifications/appointment_confirmation_screen.dart';
import 'features/notifications/booking_confirmed_screen.dart';
import 'providers/user_onboarding_provider.dart';
import 'providers/user_provider.dart';
import 'services/notification_service.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await NotificationService().initialize();
  runApp(const OmniCareApp());
}

class OmniCareApp extends StatelessWidget {
  const OmniCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserOnboardingProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()..loadIfLoggedIn()),
      ],
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
              '/home': (context) => const NewHomeScreen(),
              '/doctor-dashboard': (context) => const DoctorDashboardScreen(),
              '/emergency-step0': (context) => const EmergencyRequestStep0(),
              '/emergency-step1': (context) => const EmergencyRequestStep1(),
              '/request-care': (context) => const ProviderSelectionScreen(),
              '/notifications': (context) => const NotificationsScreen(),
            },
            onGenerateRoute: (settings) {
              if (settings.name == '/emergency-step2') {
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (context) => EmergencyRequestStep2(step1Data: args),
                );
              }
              if (settings.name == '/emergency-step3') {
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (context) => EmergencyRequestStep3(previousData: args),
                );
              }
              if (settings.name == '/emergency-review') {
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (context) => EmergencyReviewScreen(requestData: args),
                );
              }
              if (settings.name == '/doctor-selection') {
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (context) => DoctorSelectionScreen(emergencyData: args),
                );
              }
              if (settings.name == '/review-confirm') {
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (context) => ReviewConfirmScreen(requestData: args),
                );
              }
              if (settings.name == '/doctor-calling') {
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (context) => DoctorCallingScreen(requestData: args),
                );
              }
              if (settings.name == '/doctor-arriving') {
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (context) => DoctorArrivingScreen(requestData: args),
                );
              }
              if (settings.name == '/consultation-type') {
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (context) => ConsultationTypeScreen(
                    providerType: args['providerType'],
                  ),
                );
              }
              if (settings.name == '/provider-list') {
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (context) => ProviderListScreen(
                    providerType: args['providerType'],
                  ),
                );
              }
              if (settings.name == '/consultation-qr') {
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (context) => ConsultationQRScreen(requestData: args),
                );
              }
              if (settings.name == '/consultation-complete') {
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (context) => ConsultationCompleteScreen(requestData: args),
                );
              }
              if (settings.name == '/appointment-confirmation') {
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (context) => AppointmentConfirmationScreen(doctorData: args),
                );
              }
              if (settings.name == '/booking-confirmed') {
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (context) => BookingConfirmedScreen(bookingData: args),
                );
              }
              return null;
            },
          );
        },
      ),
    );
  }
}
