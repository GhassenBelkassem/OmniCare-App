import 'dart:async';

import 'package:flutter/material.dart';
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
import 'features/profile/medical_document_upload_controller.dart';
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
import 'features/clinical_safety/clinical_feature_unavailable_screen.dart';
import 'features/doctor/doctor_auth_shell_screen.dart';
import 'features/request/provider_selection_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'providers/user_onboarding_provider.dart';
import 'providers/user_provider.dart';
import 'providers/family_provider.dart';
import 'services/notification_service.dart';
import 'core/l10n/app_locale.dart';
import 'l10n/omni_localizations.dart';
import 'core/nav/app_nav.dart';
import 'core/maps/maps_configuration.dart';
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
import 'features/notifications/application/notification_navigation_resolver.dart';
import 'features/scheduled_care/presentation/scheduled_care_resource_resolver.dart';
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
import 'features/patient_passport/application/medical_data_editor_view_model.dart';
import 'features/patient_passport/application/medical_documents_view_model.dart';
import 'features/patient_passport/application/medical_record_view_model.dart';
import 'features/patient_passport/data/medical_document_api.dart';
import 'features/patient_passport/data/medical_document_repository.dart';
import 'features/patient_passport/data/medical_record_api.dart';
import 'features/patient_passport/data/medical_record_repository.dart';
import 'features/patient_passport/data/medical_record_write_api.dart';
import 'features/patient_passport/data/medical_record_write_repository.dart';
import 'features/patient_passport/sharing/medical_sharing_api.dart';
import 'features/patient_passport/sharing/medical_sharing_controller.dart';
import 'features/patient_passport/sharing/medical_share_qr_api.dart';
import 'features/patient_passport/sharing/medical_share_qr_controller.dart';
import 'features/patient_passport/sharing/direct_patient_authorization_api.dart';
import 'features/patient_passport/sharing/direct_patient_authorization_controller.dart';
import 'features/pending_answers/application/pending_answers_controller.dart';
import 'features/pending_answers/data/pending_answers_api.dart';
import 'features/pending_answers/presentation/pending_answers_entry.dart';

Future<void> main() => startOmniCare();

Future<void> startOmniCare({
  UrgentCabinetSubmissionActivationGate? submissionActivationGate,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final appLockService = AppLockService();

  // App-lock state is local and security-sensitive, so resolve it before any
  // authenticated screen can be displayed. Load browser-safe dotenv values
  // and initialize the existing Maps platform loader at the same time so Web
  // maps cannot render before the JavaScript API has received its build key.
  await Future.wait<void>([
    dotenv.load(fileName: '.env'),
    appLockService.initialize(),
    loadMapsConfiguration().then((_) {}),
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
    final medicalRecordRepository = MedicalRecordRepository(
      MedicalRecordApi(resolvedHttpClient),
    );
    final medicalRecordWriteRepository = MedicalRecordWriteRepository(
      MedicalRecordWriteApi(resolvedHttpClient),
    );
    final scheduledCareRepository = ScheduledCareRepository(
      ScheduledCareApi(resolvedHttpClient),
      patientScheduledCareApi: PatientScheduledCareApi(resolvedHttpClient),
      appointmentCancellationApi: ScheduledAppointmentCancellationApi(
        resolvedHttpClient,
      ),
    );
    final documentsApi = DocumentsApi(httpClient: resolvedHttpClient);
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
        ChangeNotifierProvider(
          lazy: false,
          create: (_) => MedicalDocumentUploadController(
            api: documentsApi,
            receiptStore: SecureMedicalDocumentUploadReceiptStore(),
            authController: authController,
          ),
        ),
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
        // G-2 FT-3: the « Dossier médical » record; G2.1-A2: its editor, on
        // the same read repository and the A1 write repository.
        ChangeNotifierProvider(
          create: (_) =>
              MedicalRecordViewModel(repository: medicalRecordRepository),
        ),
        // G2.1-A4: the « Documents » tab (list, upload, status, delete).
        ChangeNotifierProvider(
          create: (_) => MedicalDocumentsViewModel(
            repository: MedicalDocumentRepository(
              MedicalDocumentApi(resolvedHttpClient),
            ),
          ),
        ),
        Provider<MedicalDataEditorFactory>.value(
          value: MedicalDataEditorFactory(
            reads: medicalRecordRepository,
            writes: medicalRecordWriteRepository,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              MedicalShareQrController(MedicalShareQrApi(resolvedHttpClient)),
        ),
        ChangeNotifierProvider(
          create: (_) => DirectPatientAuthorizationController(
            DirectPatientAuthorizationApi(resolvedHttpClient),
          ),
        ),
        // G-1 D2 / D4: the patient's pending access requests and follow-ups.
        ChangeNotifierProvider(
          create: (_) =>
              PendingAnswersController(PendingAnswersApi(resolvedHttpClient)),
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
      ],
      child: Consumer2<UserOnboardingProvider, UserProvider>(
        // Still rebuilds on account changes as before; the app language no
        // longer depends on them (V1 is French only, G2-1b-1).
        builder: (context, _, _, child) {
          return MaterialApp(
            title: 'OmniCare',
            debugShowCheckedModeBanner: false,
            navigatorKey: AppNav.navigatorKey,
            scaffoldMessengerKey: AppNav.scaffoldMessengerKey,
            locale: appLocale,
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
            supportedLocales: OmniLocalizations.supportedLocales,
            localizationsDelegates: OmniLocalizations.localizationsDelegates,
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
                uploadController: context
                    .read<MedicalDocumentUploadController>(),
                accountApi: AccountApi(httpClient: resolvedHttpClient),
                initialAccountId: context
                    .read<AuthController>()
                    .currentUser
                    ?.id,
                initialPatientId: context
                    .read<UserProvider>()
                    .profile
                    ?.patientId,
              ),
              '/conversational-onboarding': (context) =>
                  ConversationalOnboardingScreen(
                    accountApi: AccountApi(httpClient: resolvedHttpClient),
                    medicalRecords: medicalRecordRepository,
                    medicalRecordWrites: medicalRecordWriteRepository,
                  ),
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
              '/clinical-request-unavailable': (context) =>
                  const ClinicalFeatureUnavailableScreen(),
              '/request-care': (context) => const ProviderSelectionScreen(),
              '/provider-selection': (context) =>
                  const ProviderSelectionScreen(),
              '/clinic-request': (context) =>
                  const ClinicalFeatureUnavailableScreen(),
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
              if (const <String>{
                '/doctor-selection',
                '/review-confirm',
                '/doctor-calling',
                '/doctor-arriving',
                '/consultation-qr',
                '/consultation-complete',
                '/consultation-type',
                '/provider-list',
                '/time-selection',
                '/appointment-confirmation',
                '/booking-confirmed',
              }.contains(settings.name)) {
                return MaterialPageRoute(
                  settings: settings,
                  builder: (context) =>
                      const ClinicalFeatureUnavailableScreen(),
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
  StreamSubscription<PendingNotificationOpenIdentity>?
  _notificationOpenSubscription;
  PatientScheduledCareRealtimeTarget? _patientRealtimeTarget;
  VoidCallback? _unregisterPatientRealtimeTarget;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppNav.patientHomeInStack.addListener(_onPatientHomeInStackChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _notificationRealtimeCoordinator = context
        .read<NotificationRealtimeCoordinator?>();
    _notificationPushCoordinator = context.read<NotificationPushCoordinator?>();
    final notificationAlerts = NotificationService();
    if (!identical(notificationAlerts, _notificationAlerts)) {
      _notificationOpenSubscription?.cancel();
      _notificationAlerts = notificationAlerts;
      _notificationOpenSubscription = notificationAlerts.notificationOpens
          .listen(_openPatientNotification);
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
      unawaited(_offerAccessRequestWindow());
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
    AppNav.patientHomeInStack.removeListener(_onPatientHomeInStackChanged);
    _unregisterPatientRealtimeTarget?.call();
    _patientRealtimeTarget?.dispose();
    _notificationOpenSubscription?.cancel();
    super.dispose();
  }

  Future<void> _openPatientNotification(
    PendingNotificationOpenIdentity intent,
  ) async {
    if (!mounted) return;
    final auth = context.read<AuthController>();
    if (!auth.isAuthenticated || auth.globalRole != 'PATIENT') return;
    final accountId = auth.currentUser?.id.trim();
    if (accountId == null || accountId.isEmpty) return;
    final resolution = NotificationNavigationResolver.resolvePending(
      intent,
      auth.roleFamily,
      accountScope: accountId,
    );
    final claimed = NotificationService().claimNotificationOpen(intent);
    if (claimed == null) return;
    if (resolution.status != NotificationNavigationStatus.target) return;
    if (isPendingAnswerResource(resolution.resource)) {
      await _openPendingAnswer(resolution);
      return;
    }
    if (resolution.resource == NotificationNavigationResource.bookingRequest) {
      await ScheduledCareResourceResolver.openRequest(
        context,
        resolution.resourceId!,
      );
      return;
    }
    if (resolution.resource == NotificationNavigationResource.appointment) {
      await ScheduledCareResourceResolver.openAppointment(
        context,
        resolution.resourceId!,
      );
      return;
    }
    final navigator = Navigator.of(context);
    final recovered = await context
        .read<UrgentCabinetPatientLifecycleController>()
        .recoverFromNotification(
          accountId: accountId,
          requestId: resolution.resourceId!,
        );
    if (!context.mounted ||
        !recovered ||
        !auth.isAuthenticated ||
        auth.currentUser?.id.trim() != accountId) {
      return;
    }
    await navigator.pushNamed<void>('/urgent-cabinet/care-subject');
  }

  /// G-1 D2 / D4 pushes. Returns false for any other destination.
  Future<bool> _openPendingAnswer(
    NotificationNavigationResolution resolution,
  ) async {
    final resource = resolution.resource;
    if (!isPendingAnswerResource(resource)) return false;
    final controller = context.read<PendingAnswersController>();
    // A cold-start push waits for the patient home, so nothing it opens is
    // replaced by the splash → home navigation.
    await _patientHomeReady();
    if (!mounted) return true;
    final navigator = AppNav.navigatorKey.currentState;
    final id = resolution.resourceId!;
    switch (resource) {
      case NotificationNavigationResource.accessRequest:
        if (navigator != null) {
          await PendingAnswersEntry.openAccessRequest(
            navigator,
            controller,
            id,
          );
        }
        return true;
      case NotificationNavigationResource.followUpProposal:
        if (navigator != null) {
          await PendingAnswersEntry.openFollowUpProposal(
            navigator,
            controller,
            id,
          );
        }
        return true;
      case NotificationNavigationResource.followUpWithdrawn:
        if (navigator != null) {
          await PendingAnswersEntry.openFollowUpWithdrawn(
            navigator,
            controller,
          );
        }
        return true;
      default:
        return false;
    }
  }

  Future<void> _patientHomeReady() {
    final home = AppNav.patientHomeInStack;
    if (home.value) return Future.value();
    final ready = Completer<void>();
    void listener() {
      if (home.value && !ready.isCompleted) ready.complete();
    }

    home.addListener(listener);
    return ready.future
        .timeout(const Duration(seconds: 20), onTimeout: () {})
        .whenComplete(() => home.removeListener(listener));
  }

  void _onPatientHomeInStackChanged() {
    if (AppNav.patientHomeInStack.value) unawaited(_offerAccessRequestWindow());
  }

  /// G-1 D2 (B): on app open and resume, a pending access request opens the
  /// window once per app session. Patients only.
  Future<void> _offerAccessRequestWindow() async {
    if (!mounted) return;
    final auth = context.read<AuthController>();
    if (!auth.isAuthenticated || auth.globalRole != 'PATIENT') return;
    if (NotificationService().pendingNotificationOpen != null) return;
    if (!AppNav.patientHomeInStack.value) return;
    final navigator = AppNav.navigatorKey.currentState;
    if (navigator == null) return;
    await PendingAnswersEntry.offerAccessRequestWindow(
      navigator,
      context.read<PendingAnswersController>(),
    );
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
          if (nextRole == 'PATIENT') {
            final pending = NotificationService().pendingNotificationOpen;
            if (pending != null) {
              unawaited(_openPatientNotification(pending));
            } else {
              unawaited(_offerAccessRequestWindow());
            }
          }
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
          NotificationService().clearPendingNotificationOpen();
          unawaited(
            context
                .read<UrgentCabinetPatientLifecycleController>()
                .invalidateSession(previousUserId),
          );
          final request = context.read<RequestSubmissionController>();
          final currentAuth = context.read<AuthController>();
          unawaited(
            request.clear().then((_) {
              if (mounted && currentAuth.currentUser?.id == nextUserId) {
                request.attachAuthenticatedAccount(nextUserId);
              }
            }),
          );
          context.read<PatientBookingController>().clear();
          context.read<PatientScheduledCareController>().clear();
          context.read<MedicalSharingController>().clear();
          context.read<MedicalShareQrController>().clear();
          context.read<DirectPatientAuthorizationController>().clear();
          context.read<MedicalRecordViewModel>().clear();
          context.read<MedicalDocumentsViewModel>().clear();
          context.read<PendingAnswersController>().clear();
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
        NotificationService().clearPendingNotificationOpen();
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
        context.read<DirectPatientAuthorizationController>().clear();
        if (!context.mounted) return;
        context.read<PendingAnswersController>().clear();
        if (!context.mounted) return;
        // Medical data must not outlive the session (G-2 FT-3).
        context.read<MedicalRecordViewModel>().clear();
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
