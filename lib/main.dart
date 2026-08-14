import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'features/auth/splash_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/phone_input_screen.dart';
import 'features/auth/reset_password_screen.dart';
import 'features/profile/vital_info_screen.dart';
import 'features/profile/medications_screen.dart';
import 'features/profile/medical_documents_screen.dart';
import 'features/onboarding/conversational_onboarding_screen.dart';
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
import 'features/request/clinic_request_screen.dart';
import 'features/request/time_selection_screen.dart';
import 'providers/user_onboarding_provider.dart';
import 'providers/user_provider.dart';
import 'providers/family_provider.dart';
import 'providers/reservation_provider.dart';
import 'services/notification_service.dart';
import 'l10n/app_localizations.dart';
import 'core/nav/app_nav.dart';
import 'core/device/device_identity_service.dart';
import 'core/network/app_http_client.dart';
import 'core/storage/secure_token_store.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/auth/application/auth_flow_models.dart';
import 'features/clinic/application/clinic_context_controller.dart';
import 'features/clinic/application/clinic_operational_controller.dart';
import 'features/clinic/clinic_routes.dart';
import 'features/clinic/data/clinic_api.dart';
import 'features/clinic/data/clinic_repository.dart';
import 'features/request_core/application/request_submission_controller.dart';
import 'features/request_core/data/request_api.dart';
import 'features/request_core/data/request_repository.dart';
import 'features/patient_clinic/application/patient_clinic_directory_controller.dart';
import 'features/patient_clinic/data/patient_clinic_api.dart';
import 'features/patient_clinic/data/patient_clinic_repository.dart';
import 'features/patient_clinic/presentation/clinic_directory_screen.dart';
import 'features/request_flow/screens/request_flow_entry_screen.dart';
import 'features/request_flow/screens/who_needs_care_screen.dart';
import 'features/request_flow/screens/situation_screen.dart';
import 'features/request_flow/screens/pickup_screen.dart';
import 'features/request_flow/screens/review_screen.dart';
import 'features/request_flow/screens/request_received_screen.dart';
import 'features/request_history/application/patient_requests_controller.dart';
import 'features/request_history/presentation/my_requests_screen.dart';
import 'core/api/account_api.dart';
import 'core/api/files_api.dart';
import 'core/api/family_api.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/data/auth_repository.dart';
import 'repositories/user_repository.dart';
import 'repositories/family_repository.dart';
import 'features/security/account_security_api.dart';
import 'features/security/account_security_provider.dart';
import 'features/security/app_lock_gate.dart';
import 'features/security/app_lock_service.dart';
import 'features/security/phone_change_reversal_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await NotificationService().initialize();

  final tokenStore = SecureTokenStore();
  late AuthController authController;
  final httpClient = AppHttpClient(tokenStore: tokenStore);
  final authRepository = AuthRepository(
    api: AuthApi(httpClient),
    tokenStore: tokenStore,
    deviceIdentityService: DeviceIdentityService(tokenStore: tokenStore),
    refreshCoordinator: httpClient.refreshCoordinator,
  );
  authController = AuthController(repository: authRepository);
  httpClient.onSessionInvalidated = authController.handleSessionInvalidated;

  await authController.initialize();
  final appLockService = AppLockService();
  await appLockService.initialize();
  runApp(
    OmniCareApp(
      authController: authController,
      httpClient: httpClient,
      appLockService: appLockService,
    ),
  );
}

class OmniCareApp extends StatelessWidget {
  const OmniCareApp({
    super.key,
    required this.authController,
    this.httpClient,
    this.appLockService,
  });

  final AuthController authController;
  final AppHttpClient? httpClient;
  final AppLockService? appLockService;

  @override
  Widget build(BuildContext context) {
    final resolvedHttpClient =
        httpClient ?? AppHttpClient(tokenStore: SecureTokenStore());
    final clinicRepository = ClinicRepository(ClinicApi(resolvedHttpClient));
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: authController),
        ChangeNotifierProvider(create: (_) => UserOnboardingProvider()),
        ChangeNotifierProvider(
          create: (_) => UserProvider(
            repository: UserRepository(
              api: AccountApi(httpClient: resolvedHttpClient),
              filesApi: FilesApi(httpClient: resolvedHttpClient),
            ),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => FamilyProvider(
            repository: FamilyRepository(
              api: FamilyApi(httpClient: resolvedHttpClient),
            ),
            onFamilyChanged: context.read<UserProvider>().refresh,
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => AccountSecurityProvider(
            api: AccountSecurityApi(resolvedHttpClient),
            forceLocalLogout: authController.logout,
            onProfileChanged: context.read<UserProvider>().refresh,
          ),
        ),
        ChangeNotifierProvider<AppLockService>.value(
          value: appLockService ?? AppLockService(),
        ),
        ChangeNotifierProvider(
          create: (_) => ClinicContextController(repository: clinicRepository),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              ClinicOperationalController(repository: clinicRepository),
        ),
        // Module 05 request core. It receives the same shared AppHttpClient as
        // every other provider here, so it joins the one auth interceptor and
        // the one refresh coordinator instead of starting a second pipeline.
        ChangeNotifierProvider(
          create: (_) => RequestSubmissionController(
            repository: RequestRepository(RequestApi(resolvedHttpClient)),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => PatientRequestsController(
            repository: RequestRepository(RequestApi(resolvedHttpClient)),
          ),
        ),
        // Real patient clinic directory. Same shared client; the controller
        // owns debounced, cancel-safe search and backend Slice pagination.
        ChangeNotifierProvider(
          create: (_) => PatientClinicDirectoryController(
            repository: PatientClinicRepository(
              PatientClinicApi(resolvedHttpClient),
            ),
          ),
        ),
        ChangeNotifierProvider(create: (_) => ReservationProvider()),
      ],
      child: Consumer2<UserOnboardingProvider, UserProvider>(
        builder: (context, onboarding, userProvider, child) {
          Locale locale = const Locale('en');
          final profileLanguage = userProvider.profile?.preferredLanguage;
          if (profileLanguage != null) {
            locale = Locale(profileLanguage);
          } else if (onboarding.language != null) {
            locale = Locale(onboarding.language!);
          }

          return MaterialApp(
            title: 'OmniCare',
            debugShowCheckedModeBanner: false,
            navigatorKey: AppNav.navigatorKey,
            locale: locale,
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              final clampedInsets = EdgeInsets.fromLTRB(
                mq.viewInsets.left < 0 ? 0 : mq.viewInsets.left,
                mq.viewInsets.top < 0 ? 0 : mq.viewInsets.top,
                mq.viewInsets.right < 0 ? 0 : mq.viewInsets.right,
                mq.viewInsets.bottom < 0 ? 0 : mq.viewInsets.bottom,
              );
              return MediaQuery(
                data: mq.copyWith(viewInsets: clampedInsets),
                child: AppLockGate(
                  child: _AuthStateListener(
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              );
            },
            supportedLocales: const [Locale('en'), Locale('fr'), Locale('ar')],
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
            navigatorObservers: [AppNav.routeObserver],
            routes: {
              '/login': (context) => const LoginScreen(),
              '/phone-input': (context) =>
                  const PhoneInputScreen(mode: AuthFlowMode.login),
              '/medical-profile': (context) => const VitalInfoScreen(),
              '/medications': (context) => const MedicationsScreen(),
              '/medical-documents': (context) => const MedicalDocumentsScreen(),
              '/conversational-onboarding': (context) =>
                  const ConversationalOnboardingScreen(),
              '/change-password-required': (context) =>
                  const ResetPasswordScreen(),
              '/home': (context) => const NewHomeScreen(),
              '/doctor-dashboard': (context) => const DoctorDashboardScreen(),
              '/emergency-step0': (context) => const EmergencyRequestStep0(),
              '/emergency-step1': (context) => const EmergencyRequestStep1(),
              '/request-care': (context) => const ProviderSelectionScreen(),
              '/provider-selection': (context) =>
                  const ProviderSelectionScreen(),
              '/clinic-request': (context) => const ClinicRequestScreen(),
              '/notifications': (context) => const NotificationsScreen(),
              '/m05/request': (context) => const RequestFlowEntryScreen(),
              '/m05/who-needs-care': (context) => const WhoNeedsCareScreen(),
              '/m05/clinic-directory': (context) =>
                  const ClinicDirectoryScreen(),
              '/m05/situation': (context) => const SituationScreen(),
              '/m05/pickup': (context) => const PickupScreen(),
              '/m05/review': (context) => const ReviewScreen(),
              '/m05/received': (context) => const RequestReceivedScreen(),
              '/m05/requests': (context) => const MyRequestsScreen(),
              ...ClinicRoutes.builders(),
            },
            onGenerateRoute: (settings) {
              final routeUri = Uri.tryParse(settings.name ?? '');
              if (routeUri?.path == AppNav.phoneChangeReversalRoute) {
                return MaterialPageRoute(
                  settings: const RouteSettings(
                    name: AppNav.phoneChangeReversalRoute,
                  ),
                  builder: (context) => PhoneChangeReversalScreen(
                    token: routeUri?.queryParameters['token'] ?? '',
                  ),
                );
              }
              if (settings.name == '/emergency-step2') {
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (context) => EmergencyRequestStep2(step1Data: args),
                );
              }
              if (settings.name == '/emergency-step3') {
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (context) =>
                      EmergencyRequestStep3(previousData: args),
                );
              }
              if (settings.name == '/emergency-review') {
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (context) =>
                      EmergencyReviewScreen(requestData: args),
                );
              }
              if (settings.name == '/doctor-selection') {
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (context) =>
                      DoctorSelectionScreen(emergencyData: args),
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
                    initialVisitType: args['visitType']?.toString(),
                    initialIsEmergency: args['isEmergency'] == true,
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
                  builder: (context) =>
                      ConsultationCompleteScreen(requestData: args),
                );
              }
              if (settings.name == '/appointment-confirmation') {
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (context) =>
                      AppointmentConfirmationScreen(doctorData: args),
                );
              }
              if (settings.name == '/booking-confirmed') {
                final args = settings.arguments as Map<String, dynamic>;
                return MaterialPageRoute(
                  builder: (context) =>
                      BookingConfirmedScreen(bookingData: args),
                );
              }
              if (settings.name == '/time-selection') {
                final args = settings.arguments is Map<String, dynamic>
                    ? (settings.arguments as Map<String, dynamic>)
                    : <String, dynamic>{};
                return MaterialPageRoute(
                  builder: (context) => TimeSelectionScreen(
                    providerId: args['providerId']?.toString() ?? '',
                    visitType: args['visitType']?.toString(),
                    isEmergency: args['isEmergency'] == true,
                  ),
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

class _AuthStateListener extends StatefulWidget {
  const _AuthStateListener({required this.child});

  final Widget child;

  @override
  State<_AuthStateListener> createState() => _AuthStateListenerState();
}

class _AuthStateListenerState extends State<_AuthStateListener> {
  bool _wasAuthenticated = false;
  bool _handledUnauthenticatedTransition = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (auth.isAuthenticated) {
      _wasAuthenticated = true;
      _handledUnauthenticatedTransition = false;
    } else if (auth.status == AuthStatus.unauthenticated &&
        !_handledUnauthenticatedTransition &&
        (_wasAuthenticated || auth.errorCode == 'AUTH_SESSION_INVALID')) {
      _handledUnauthenticatedTransition = true;
      _wasAuthenticated = false;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final stayOnPublicSecurityRoute = AppNav.isOnPublicSecurityRoute;
        await context.read<UserProvider>().logout();
        if (!context.mounted) return;
        context.read<FamilyProvider>().clear();
        // Clinic context is scoped to the authenticated session.
        await context.read<ClinicContextController>().clear();
        if (!context.mounted) return;
        context.read<ClinicOperationalController>().clear();
        if (!context.mounted) return;
        // A patient's in-flight care request, its operation id and its
        // persisted retry record must not survive into the next session.
        await context.read<RequestSubmissionController>().clear();
        if (!context.mounted) return;
        if (stayOnPublicSecurityRoute) return;
        AppNav.navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      });
    }

    return widget.child;
  }
}
