import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'features/auth/splash_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/reset_password_screen.dart';
import 'features/auth/professional_access_request_screen.dart';
import 'features/auth/data/professional_access_request_api.dart';
import 'features/profile/vital_info_screen.dart';
import 'features/profile/medications_screen.dart';
import 'features/profile/medical_documents_screen.dart';
import 'features/onboarding/conversational_onboarding_screen.dart';
import 'features/home/new_home_screen.dart';
import 'features/emergency/emergency_request_step0.dart';
import 'features/emergency/emergency_request_step1.dart';
import 'features/emergency/urgent_care_mode_selection_screen.dart';
import 'features/emergency/urgent_cabinet/urgent_cabinet_flow_shell.dart';
import 'features/emergency/urgent_cabinet/urgent_cabinet_patient_lifecycle_controller.dart';
import 'features/emergency/urgent_cabinet/urgent_cabinet_submission_activation_gate.dart';
import 'features/emergency/urgent_cabinet/urgent_cabinet_submission_coordinator.dart';
import 'features/emergency/urgent_cabinet/urgent_cabinet_targeted_request_repository.dart';
import 'features/emergency/emergency_request_step2.dart';
import 'features/emergency/emergency_request_step3.dart';
import 'features/emergency/emergency_review_screen.dart';
import 'features/emergency/doctor_selection_screen.dart';
import 'features/emergency/review_confirm_screen.dart';
import 'features/emergency/doctor_calling_screen.dart';
import 'features/emergency/doctor_arriving_screen.dart';
import 'features/emergency/consultation_qr_screen.dart';
import 'features/emergency/consultation_complete_screen.dart';
import 'features/doctor/doctor_auth_shell_screen.dart';
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
import 'core/theme/omni_theme.dart';
import 'core/device/device_identity_service.dart';
import 'core/network/app_http_client.dart';
import 'core/realtime/authenticated_realtime_transport.dart';
import 'core/storage/secure_token_store.dart';
import 'features/auth/application/auth_controller.dart';
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
import 'features/patient_doctor/presentation/doctor_directory_screen.dart';
import 'features/patient_doctor/application/doctor_directory_controller.dart';
import 'features/patient_doctor/data/doctor_directory_api.dart';
import 'features/patient_doctor/data/doctor_directory_repository.dart';
import 'features/scheduled_care/application/patient_booking_controller.dart';
import 'features/scheduled_care/application/patient_scheduled_care_controller.dart';
import 'features/scheduled_care/data/scheduled_care_api.dart';
import 'features/scheduled_care/data/scheduled_care_repository.dart';
import 'features/scheduled_care/realtime/scheduled_care_realtime_coordinator.dart';
import 'features/notifications/application/notification_center_controller.dart';
import 'features/notifications/data/notification_api.dart';
import 'features/notifications/data/notification_repository.dart';
import 'features/notifications/realtime/notification_realtime_coordinator.dart';
import 'features/notifications/push/notification_push_coordinator.dart';
import 'features/request_flow/screens/request_flow_entry_screen.dart';
import 'features/request_flow/screens/doctor_cabinet_entry_screen.dart';
import 'features/request_flow/screens/who_needs_care_screen.dart';
import 'features/request_flow/screens/situation_screen.dart';
import 'features/request_flow/screens/pickup_screen.dart';
import 'features/request_flow/screens/review_screen.dart';
import 'features/request_flow/screens/request_received_screen.dart';
import 'features/request_history/application/patient_requests_controller.dart';
import 'features/request_history/presentation/my_requests_screen.dart';
import 'core/api/account_api.dart';
import 'core/api/documents_api.dart';
import 'core/api/files_api.dart';
import 'core/api/family_api.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/application/google_sign_in_session.dart';
import 'repositories/user_repository.dart';
import 'repositories/family_repository.dart';
import 'features/security/account_security_api.dart';
import 'features/security/account_security_provider.dart';
import 'features/security/app_lock_gate.dart';
import 'features/security/app_lock_service.dart';
import 'features/security/phone_change_reversal_screen.dart';
import 'features/patient_passport/sharing/medical_sharing_api.dart';
import 'features/patient_passport/sharing/medical_sharing_controller.dart';
import 'features/patient_passport/sharing/medical_share_qr_api.dart';
import 'features/patient_passport/sharing/medical_share_qr_controller.dart';

Future<void> main() => startOmniCare();

Future<void> startOmniCare({
  UrgentCabinetSubmissionActivationGate? submissionActivationGate,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final appLockService = AppLockService();

  // App-lock state is local and security-sensitive, so resolve it before any
  // authenticated screen can be displayed. Load dotenv at the same time to
  // avoid making these independent startup operations wait on each other.
  await Future.wait<void>([
    dotenv.load(fileName: '.env'),
    appLockService.initialize(),
  ]);
  final resolvedUrgentCabinetGate =
      submissionActivationGate ??
      UrgentCabinetSubmissionActivationGate.p4Production;

  final tokenStore = SecureTokenStore();
  late AuthController authController;
  final httpClient = AppHttpClient(tokenStore: tokenStore);
  final authRepository = AuthRepository(
    api: AuthApi(httpClient),
    tokenStore: tokenStore,
    deviceIdentityService: DeviceIdentityService(tokenStore: tokenStore),
    refreshCoordinator: httpClient.refreshCoordinator,
  );
  authController = AuthController(
    repository: authRepository,
    googleSignInSession: createGoogleSignInSession(),
  );
  httpClient.onSessionInvalidated = authController.handleSessionInvalidated;
  final realtimeTransport = AuthenticatedRealtimeTransport(
    tokenStore: tokenStore,
  );
  final realtimeCoordinator = ScheduledCareRealtimeCoordinator(
    transport: realtimeTransport,
  );
  final notificationController = NotificationCenterController(
    repository: NotificationRepository(NotificationApi(httpClient)),
  );
  final notificationRealtimeCoordinator = NotificationRealtimeCoordinator(
    transport: realtimeTransport,
    controller: notificationController,
    onForegroundNotification: NotificationService().showInboxNotification,
  );
  final notificationPushCoordinator = NotificationPushCoordinator(
    httpClient: httpClient,
    alerts: NotificationService(),
  );
  httpClient.refreshCoordinator.onSessionRefreshed = (_) =>
      realtimeCoordinator.credentialsChanged();

  runApp(
    OmniCareApp(
      authController: authController,
      httpClient: httpClient,
      appLockService: appLockService,
      realtimeCoordinator: realtimeCoordinator,
      notificationController: notificationController,
      notificationRealtimeCoordinator: notificationRealtimeCoordinator,
      notificationPushCoordinator: notificationPushCoordinator,
      urgentCabinetSubmissionActivationGate: resolvedUrgentCabinetGate,
    ),
  );

  // Authentication can involve token refresh plus backend reads. Start it
  // after runApp so the Flutter splash screen appears immediately instead of
  // leaving the native launch screen frozen while the network is slow.
  unawaited(authController.initialize());

  // Notification setup is not required for the first frame.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_initializeNotifications());
  });
}

Future<void> _initializeNotifications() async {
  try {
    await NotificationService().initialize();
  } catch (error) {
    debugPrint('Notification initialization failed: ${error.runtimeType}');
  }
}

class OmniCareApp extends StatelessWidget {
  const OmniCareApp({
    super.key,
    required this.authController,
    this.httpClient,
    this.appLockService,
    this.realtimeCoordinator,
    this.notificationController,
    this.notificationRealtimeCoordinator,
    this.notificationPushCoordinator,
    this.urgentCabinetSubmissionActivationGate =
        UrgentCabinetSubmissionActivationGate.p4Production,
  });

  final AuthController authController;
  final AppHttpClient? httpClient;
  final AppLockService? appLockService;
  final ScheduledCareRealtimeCoordinator? realtimeCoordinator;
  final NotificationCenterController? notificationController;
  final NotificationRealtimeCoordinator? notificationRealtimeCoordinator;
  final NotificationPushCoordinator? notificationPushCoordinator;
  final UrgentCabinetSubmissionActivationGate
  urgentCabinetSubmissionActivationGate;

  @override
  Widget build(BuildContext context) {
    final resolvedHttpClient =
        httpClient ?? AppHttpClient(tokenStore: SecureTokenStore());
    final clinicRepository = ClinicRepository(ClinicApi(resolvedHttpClient));
    final scheduledCareRepository = ScheduledCareRepository(
      ScheduledCareApi(resolvedHttpClient),
      patientScheduledCareApi: PatientScheduledCareApi(resolvedHttpClient),
      appointmentCancellationApi: ScheduledAppointmentCancellationApi(
        resolvedHttpClient,
      ),
    );
    return MultiProvider(
      providers: [
        Provider<UrgentCabinetSubmissionActivationGate>.value(
          value: urgentCabinetSubmissionActivationGate,
        ),
        if (realtimeCoordinator != null)
          Provider<ScheduledCareRealtimeCoordinator>.value(
            value: realtimeCoordinator!,
          ),
        if (notificationRealtimeCoordinator != null)
          Provider<NotificationRealtimeCoordinator>.value(
            value: notificationRealtimeCoordinator!,
          ),
        if (notificationPushCoordinator != null)
          Provider<NotificationPushCoordinator>.value(
            value: notificationPushCoordinator!,
          ),
        Provider<AppHttpClient>.value(value: resolvedHttpClient),
        ChangeNotifierProvider(
          create: (_) {
            final repository = AppUrgentCabinetTargetedRequestRepository(
              resolvedHttpClient,
            );
            return UrgentCabinetPatientLifecycleController(
              repository: repository,
              submissionCoordinator: UrgentCabinetSubmissionCoordinator(
                repository: repository,
                receiptStore: SecureUrgentCabinetRecoveryReceiptStore(),
              ),
            );
          },
        ),
        ChangeNotifierProvider<AuthController>.value(value: authController),
        if (notificationController != null)
          ChangeNotifierProvider<NotificationCenterController>.value(
            value: notificationController!,
          )
        else
          ChangeNotifierProvider(
            create: (_) => NotificationCenterController(
              repository: NotificationRepository(
                NotificationApi(resolvedHttpClient),
              ),
            ),
          ),
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
          create: (_) =>
              MedicalSharingController(MedicalSharingApi(resolvedHttpClient)),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              MedicalShareQrController(MedicalShareQrApi(resolvedHttpClient)),
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
        // Real patient doctor directory. Same shared client; the controller
        // owns debounced, cancel-safe search over the plain /doctors array.
        ChangeNotifierProvider(
          create: (_) => DoctorDirectoryController(
            repository: DoctorDirectoryRepository(
              DoctorDirectoryApi(resolvedHttpClient),
            ),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              PatientBookingController(repository: scheduledCareRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => PatientScheduledCareController(
            repository: scheduledCareRepository,
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
            scaffoldMessengerKey: AppNav.scaffoldMessengerKey,
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
            theme: buildOmniTheme(),
            home: const SplashScreen(),
            navigatorObservers: [AppNav.routeObserver],
            routes: {
              // Compatibility route for existing links. It deliberately reuses the
              // one role-neutral sign-in screen.
              '/auth-entry': (context) => const LoginScreen(),
              '/login': (context) => const LoginScreen(),
              '/professional-login': (context) => const LoginScreen(),
              '/professional-access-request': (context) =>
                  ProfessionalAccessRequestScreen(
                    api: ProfessionalAccessRequestApi(resolvedHttpClient),
                  ),
              '/medical-profile': (context) => const VitalInfoScreen(),
              '/medications': (context) => const MedicationsScreen(),
              '/medical-documents': (context) => MedicalDocumentsScreen(
                documentsApi: DocumentsApi(httpClient: resolvedHttpClient),
                accountApi: AccountApi(httpClient: resolvedHttpClient),
                initialPatientId: context
                    .read<UserProvider>()
                    .profile
                    ?.patientId,
              ),
              '/conversational-onboarding': (context) =>
                  const ConversationalOnboardingScreen(),
              '/change-password-required': (context) =>
                  const ResetPasswordScreen(),
              '/home': (context) => const NewHomeScreen(),
              '/doctor-dashboard': (context) => const DoctorAuthShellScreen(),
              '/emergency-step0': (context) => const EmergencyRequestStep0(),
              '/urgent-care-mode-selection': (context) =>
                  const UrgentCareModeSelectionScreen(),
              '/urgent-cabinet/care-subject': (context) =>
                  const UrgentCabinetFlowShell(),
              '/emergency-step1': (context) => const EmergencyRequestStep1(),
              '/request-care': (context) => const ProviderSelectionScreen(),
              '/provider-selection': (context) =>
                  const ProviderSelectionScreen(),
              '/clinic-request': (context) => const ClinicRequestScreen(),
              '/notifications': (context) => const NotificationsScreen(),
              '/m05/request': (context) => const RequestFlowEntryScreen(),
              '/doctor/cabinet/who-needs-care': (context) =>
                  const DoctorCabinetEntryScreen(),
              '/m05/who-needs-care': (context) => const WhoNeedsCareScreen(),
              '/m05/clinic-directory': (context) =>
                  const ClinicDirectoryScreen(),
              '/m05/doctor-directory': (context) =>
                  const DoctorDirectoryScreen(),
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

class _AuthStateListenerState extends State<_AuthStateListener>
    with WidgetsBindingObserver {
  bool _wasAuthenticated = false;
  bool _handledUnauthenticatedTransition = false;
  String? _scheduledCareOwnerUserId;
  String? _realtimeOwnerKey;
  ScheduledCareRealtimeCoordinator? _realtimeCoordinator;
  NotificationRealtimeCoordinator? _notificationRealtimeCoordinator;
  NotificationPushCoordinator? _notificationPushCoordinator;
  NotificationService? _notificationAlerts;
  StreamSubscription<UrgentCabinetNotificationOpenIntent>?
  _urgentCabinetOpenSubscription;
  PatientScheduledCareRealtimeTarget? _patientRealtimeTarget;
  VoidCallback? _unregisterPatientRealtimeTarget;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _notificationRealtimeCoordinator = context
        .read<NotificationRealtimeCoordinator?>();
    _notificationPushCoordinator = context.read<NotificationPushCoordinator?>();
    final notificationAlerts = NotificationService();
    if (!identical(notificationAlerts, _notificationAlerts)) {
      _urgentCabinetOpenSubscription?.cancel();
      _notificationAlerts = notificationAlerts;
      _urgentCabinetOpenSubscription = notificationAlerts.urgentCabinetOpens
          .listen(_openPatientUrgentCabinetNotification);
    }
    final coordinator = context.read<ScheduledCareRealtimeCoordinator?>();
    if (identical(coordinator, _realtimeCoordinator)) return;
    _unregisterPatientRealtimeTarget?.call();
    _patientRealtimeTarget?.dispose();
    _realtimeCoordinator = coordinator;
    if (coordinator != null) {
      final target = PatientScheduledCareRealtimeTarget(
        bookingController: context.read<PatientBookingController>(),
        listController: context.read<PatientScheduledCareController>(),
      );
      _patientRealtimeTarget = target;
      _unregisterPatientRealtimeTarget = coordinator.registerTarget(target);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context
          .read<UrgentCabinetPatientLifecycleController>()
          .applicationResumed();
      unawaited(_realtimeCoordinator?.foregroundResync());
      unawaited(_notificationRealtimeCoordinator?.foregroundResync());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      context
          .read<UrgentCabinetPatientLifecycleController>()
          .applicationBackgrounded();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unregisterPatientRealtimeTarget?.call();
    _patientRealtimeTarget?.dispose();
    _urgentCabinetOpenSubscription?.cancel();
    super.dispose();
  }

  Future<void> _openPatientUrgentCabinetNotification(
    UrgentCabinetNotificationOpenIntent intent,
  ) async {
    if (!mounted) return;
    final auth = context.read<AuthController>();
    if (!auth.isAuthenticated || auth.globalRole != 'PATIENT') return;
    final accountId = auth.currentUser?.id.trim();
    if (accountId == null || accountId.isEmpty) return;
    final claimed = NotificationService().claimUrgentCabinetOpen(intent);
    if (claimed == null) return;
    final navigator = Navigator.of(context);
    final recovered = await context
        .read<UrgentCabinetPatientLifecycleController>()
        .recoverFromNotification(
          accountId: accountId,
          requestId: claimed.requestId,
        );
    if (!context.mounted ||
        !recovered ||
        !auth.isAuthenticated ||
        auth.currentUser?.id.trim() != accountId) {
      return;
    }
    await navigator.pushNamed<void>('/urgent-cabinet/care-subject');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (auth.isAuthenticated) {
      final nextUserId = auth.currentUser?.id;
      final nextRole = auth.globalRole;
      final previousUserId = _scheduledCareOwnerUserId;
      _scheduledCareOwnerUserId = nextUserId;
      final nextRealtimeOwnerKey = nextUserId != null && nextRole != null
          ? '$nextUserId::$nextRole'
          : null;
      if (nextRealtimeOwnerKey != null &&
          nextRealtimeOwnerKey != _realtimeOwnerKey &&
          (nextRole == 'PATIENT' || nextRole == 'DOCTOR')) {
        final realtimeUserId = nextUserId!;
        final realtimeRole = nextRole!;
        _realtimeOwnerKey = nextRealtimeOwnerKey;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _realtimeOwnerKey != nextRealtimeOwnerKey) return;
          unawaited(
            context.read<NotificationCenterController>().startSession(
              nextRealtimeOwnerKey,
            ),
          );
          _notificationRealtimeCoordinator?.startSession();
          unawaited(
            _notificationPushCoordinator?.startSession(nextRealtimeOwnerKey),
          );
          unawaited(
            _realtimeCoordinator?.startSession(
              RealtimeSessionOwner(userId: realtimeUserId, role: realtimeRole),
            ),
          );
        });
      } else if ((nextRole != 'PATIENT' && nextRole != 'DOCTOR') &&
          _realtimeOwnerKey != null) {
        _realtimeOwnerKey = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _notificationRealtimeCoordinator?.stopSession();
          unawaited(_notificationPushCoordinator?.stopSession());
          context.read<NotificationCenterController>().clearForSession();
          unawaited(_realtimeCoordinator?.stopSession());
        });
      }
      if (previousUserId != null &&
          nextUserId != null &&
          previousUserId != nextUserId) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(
            context
                .read<UrgentCabinetPatientLifecycleController>()
                .invalidateSession(previousUserId),
          );
          context.read<PatientBookingController>().clear();
          context.read<PatientScheduledCareController>().clear();
          context.read<MedicalSharingController>().clear();
          context.read<MedicalShareQrController>().clear();
        });
      }
      _wasAuthenticated = true;
      _handledUnauthenticatedTransition = false;
    } else if (auth.status == AuthStatus.unauthenticated &&
        !_handledUnauthenticatedTransition &&
        (_wasAuthenticated || auth.errorCode == 'AUTH_SESSION_INVALID')) {
      _handledUnauthenticatedTransition = true;
      _wasAuthenticated = false;
      final urgentCabinetOwnerUserId = _scheduledCareOwnerUserId;
      _scheduledCareOwnerUserId = null;
      _realtimeOwnerKey = null;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        if (urgentCabinetOwnerUserId != null) {
          await context
              .read<UrgentCabinetPatientLifecycleController>()
              .invalidateSession(urgentCabinetOwnerUserId);
          if (!context.mounted) return;
        }
        _notificationRealtimeCoordinator?.stopSession();
        await _notificationPushCoordinator?.stopSession();
        if (!context.mounted) return;
        context.read<NotificationCenterController>().clearForSession();
        await _realtimeCoordinator?.stopSession();
        if (!context.mounted) return;
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
        context.read<PatientBookingController>().clear();
        if (!context.mounted) return;
        context.read<PatientScheduledCareController>().clear();
        if (!context.mounted) return;
        context.read<MedicalSharingController>().clear();
        if (!context.mounted) return;
        context.read<MedicalShareQrController>().clear();
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
