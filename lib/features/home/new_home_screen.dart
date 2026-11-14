import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/omni_theme.dart';
import '../../core/platform/secure_screen.dart';
import '../../core/services/file_picker_service.dart';
import '../../core/models/blood_type.dart';
import '../../core/models/family_models.dart' as core_models;
import '../auth/application/auth_controller.dart';
import '../../providers/user_onboarding_provider.dart' hide MedicalDocument;
import '../../providers/user_provider.dart';
import '../../providers/family_provider.dart';
import 'edit_medical_data_screen.dart';
import 'patient_shell_navigation.dart';
import 'patient_shell_scope.dart';
import 'add_family_member_screen.dart';
import 'family_member_detail_screen.dart';
import 'document_viewer_screen.dart';
import 'qr_code_modal.dart';
import '../patient_passport/sharing/medical_sharing_models.dart';
import 'patient_home_feed.dart';
import '../profile/patient_profile_screen.dart';
import '../patient_appointments/presentation/patient_appointments_screen.dart';
import '../security/account_security_screen.dart';
import '../security/device_management_screen.dart';
import '../security/login_history_screen.dart';
import '../request/provider_selection_screen.dart';
import '../request_flow/screens/request_flow_entry_screen.dart';
import '../request_flow/screens/doctor_cabinet_entry_screen.dart';
import '../request_flow/screens/who_needs_care_screen.dart';
import '../request_flow/screens/situation_screen.dart';
import '../request_flow/screens/pickup_screen.dart';
import '../request_flow/screens/review_screen.dart';
import '../request_flow/screens/request_received_screen.dart';
import '../patient_clinic/presentation/clinic_directory_screen.dart';
import '../patient_doctor/presentation/doctor_directory_screen.dart';
import '../patient_doctor/presentation/doctor_detail_screen.dart';
import '../patient_passport/application/medical_data_editor_view_model.dart';
import '../patient_passport/application/medical_record_view_model.dart';
import '../patient_passport/data/medical_record_models.dart';
import '../patient_passport/presentation/patient_passport_screen.dart';
import '../request_history/presentation/my_requests_screen.dart';
import '../emergency/emergency_request_step0.dart';
import '../emergency/emergency_request_step1.dart';
import '../emergency/urgent_care_mode_selection_screen.dart';
import '../emergency/urgent_cabinet/urgent_cabinet_flow_shell.dart';
import '../emergency/emergency_request_step2.dart';
import '../emergency/emergency_request_step3.dart';
import '../emergency/emergency_review_screen.dart';
import '../clinical_safety/clinical_feature_unavailable_screen.dart';
import '../notifications/application/notification_center_controller.dart';
import '../notifications/presentation/notification_badge.dart';
import '../../core/l10n/blood_type_label.dart';
import '../../l10n/omni_localizations.dart';
import '../../core/network/api_failure.dart';
import '../../core/network/api_failure_message.dart';

class NewHomeScreen extends StatefulWidget {
  const NewHomeScreen({super.key});

  @override
  State<NewHomeScreen> createState() => _NewHomeScreenState();
}

class _NewHomeScreenState extends State<NewHomeScreen> {
  /// Shown bottom-bar button; one persistent branch per button.
  int _selectedIndex = PatientShellTab.home;

  /// Button shown before the logo was tapped, where leaving the care flow
  /// returns.
  int _tabBeforeCare = PatientShellTab.home;

  /// Branches are built on first visit, then kept alive (state, scroll and
  /// in-progress requests survive switching buttons).
  final Set<int> _builtBranches = {PatientShellTab.home};

  final Map<int, GlobalKey<NavigatorState>> _branchNavigatorKeys = {
    PatientShellTab.home: GlobalKey<NavigatorState>(
      debugLabel: 'patient-home-branch',
    ),
    PatientShellTab.care: GlobalKey<NavigatorState>(
      debugLabel: 'patient-care-branch',
    ),
  };

  /// Whether each Navigator branch has a screen to pop (or one that vetoes
  /// the pop), from its [NavigationNotification]s.
  final Map<int, bool> _branchCanHandlePop = {};

  bool _isLoggingOut = false;
  final _filePickerService = FilePickerService();

  FamilyMember _toDetailMember(core_models.FamilyMember member) {
    return FamilyMember(
      id: member.id,
      name: member.fullName,
      age: member.ageYears,
      relationship: core_models.FamilyRelationships.frenchLabel(
        member.relationship,
      ),
      avatar: member.photoUrl ?? '',
      bloodType: null,
      chronicConditions: const [],
      currentMedications: const [],
      documents: const <MedicalDocument>[],
      criticalAlert: null,
      phoneNumber: null,
    );
  }

  Future<void> _openFamilyMemberForm([core_models.FamilyMember? member]) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AddFamilyMemberScreen(member: member)),
    );
  }

  void _openPatientAppointments() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PatientAppointmentsScreen()),
    );
  }

  /// « Modifier Mes Données » (Ma Santé): the record editor's section saves
  /// for SELF (G2.1-A3). When it closes, the profile and the record reload
  /// if anything was saved, even if another section failed.
  Future<void> _editOwnMedicalData() async {
    const self = SelfRecordSubject();
    final editor = context.read<MedicalDataEditorFactory>().create(self);
    final record = context.read<MedicalRecordViewModel>();
    final user = context.read<UserProvider>();
    await Navigator.push<MedicalDataEditResult>(
      context,
      MaterialPageRoute(
        builder: (context) => EditMedicalDataScreen(viewModel: editor),
      ),
    );
    final saved = editor.savedSomething;
    editor.dispose();
    if (!saved || !mounted) return;
    if (record.subject == self) record.refreshAfterEdit();
    await user.refresh();
  }

  Future<void> _editFamilyMember(String id) async {
    final provider = context.read<FamilyProvider>();
    final matches = provider.members.where((member) => member.id == id);
    if (matches.isEmpty) return;
    await _openFamilyMemberForm(matches.first);
  }

  Future<void> _deactivateFamilyMember(String id) async {
    final provider = context.read<FamilyProvider>();
    if (provider.isDeactivating(id)) return;
    final matches = provider.members.where((member) => member.id == id);
    if (matches.isEmpty) return;
    final member = matches.first;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Retirer ce membre ?'),
        content: Text(
          '${member.fullName} ne figurera plus dans votre famille. '
          'Cette action ne supprime pas immédiatement les données médicales.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.person_remove_outlined, size: 18),
            label: const Text('Retirer'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await provider.deactivateFamilyMember(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Membre retiré de votre famille.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiFailureMessageOr(
              provider.mutationFailure,
              OmniLocalizations.of(context),
              fallback: OmniLocalizations.of(context).familyRemoveFailed,
            ),
          ),
          backgroundColor: const Color(0xFFB42318),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // FLAG_SECURE for the whole patient shell (health data on every
    // branch). Set once here instead of per screen: toggling the window
    // flag on each « Dossier médical » visit re-laid out the Android window
    // and flashed the previous frame.
    SecureScreen.acquire();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Authentication inputs can retain focus while the route changes,
      // especially on mobile web. Clear it so stale keyboard viewInsets do
      // not collapse the dashboard on its first frame.
      FocusManager.instance.primaryFocus?.unfocus();
      final familyProvider = Provider.of<FamilyProvider>(
        context,
        listen: false,
      );
      if (familyProvider.members.isEmpty && !familyProvider.isLoading) {
        familyProvider.loadFamilyMembers();
      }
    });
  }

  Future<void> _handleLogout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    try {
      await context.read<AuthController>().logout();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            apiFailureMessage(
              ApiFailure.from(e),
              OmniLocalizations.of(context),
            ),
          ),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
    }
  }

  Future<void> _selectAndUploadAvatar(ImageSource source) async {
    XFile? selected;
    try {
      selected = await _filePickerService.pickAndCompressImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        quality: 88,
      );
    } catch (_) {
      if (!mounted) return;
      context.read<UserProvider>().reportAvatarSelectionFailure();
      rethrow;
    }
    if (selected == null || !mounted) return;
    await context.read<UserProvider>().uploadAvatar(selected);
  }

  @override
  Widget build(BuildContext context) {
    final onboarding = Provider.of<UserOnboardingProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);

    if (userProvider.profile == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F5F7),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: userProvider.isLoading
                  ? const CircularProgressIndicator(color: Color(0xFF1FBF9A))
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 44,
                          color: Color(0xFFD92D20),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          apiFailureMessageOr(
                            userProvider.loadFailure,
                            OmniLocalizations.of(context),
                            fallback: OmniLocalizations.of(
                              context,
                            ).profileLoadFailed,
                          ),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF475467),
                          ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: userProvider.refresh,
                          icon: const Icon(Icons.refresh_rounded, size: 19),
                          label: const Text('Réessayer'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF087A65),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      );
    }
    final userName = _resolveUserName(userProvider, onboarding);

    // The single source of truth for system back: the root route reports
    // this to the platform, so Android predictive back is accurate.
    return PopScope<Object?>(
      canPop: _resolveBack() == PatientBackAction.allowRoutePop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleSystemBack();
      },
      child: PatientShellScope(
        showHome: _showHomeFeed,
        child: MediaQuery.removeViewInsets(
          context: context,
          removeBottom: true,
          child: Scaffold(
            backgroundColor: const Color(0xFFF4F5F7),
            resizeToAvoidBottomInset: false,
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _buildStickyHeader(userName),
                  Expanded(child: _buildBranches()),
                ],
              ),
            ),
            bottomNavigationBar: _buildBottomNavigation(),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    SecureScreen.release();
    super.dispose();
  }

  static String _resolveUserName(
    UserProvider userProvider,
    UserOnboardingProvider onboarding,
  ) {
    final resolvedDisplayName = (userProvider.user?.displayName ?? '').trim();
    return resolvedDisplayName.isNotEmpty
        ? resolvedDisplayName
        : (onboarding.email?.split('@')[0] ?? 'User');
  }

  bool _branchCanPop(int tab) => _branchCanHandlePop[tab] ?? false;

  PatientBackAction _resolveBack() => resolvePatientBack(
    selectedTab: _selectedIndex,
    selectedBranchCanHandlePop: _branchCanPop(_selectedIndex),
  );

  /// Shows [tab]'s branch as it was left. One setState, no transition: the
  /// IndexedStack swaps the painted branch in the same frame.
  void _selectTab(int tab) {
    if (_selectedIndex == tab || !mounted) return;
    setState(() {
      if (tab == PatientShellTab.care) _tabBeforeCare = _selectedIndex;
      _builtBranches.add(tab);
      _selectedIndex = tab;
    });
  }

  void _resetBranchToRoot(int tab) {
    _branchNavigatorKeys[tab]?.currentState?.popUntil((route) => route.isFirst);
  }

  /// Every bottom-bar button, the centre logo included.
  void _onDestinationTapped(int tab) {
    switch (resolvePatientDestinationTap(
      selectedTab: _selectedIndex,
      tappedTab: tab,
      tappedBranchCanPop: _branchCanPop(tab),
    )) {
      case PatientDestinationTapAction.selectBranch:
        _selectTab(tab);
      case PatientDestinationTapAction.resetBranchToRoot:
        _resetBranchToRoot(tab);
      case PatientDestinationTapAction.none:
        break;
    }
  }

  void _onCareActionTapped() {
    // Warm the family list; every care-flow screen also loads it itself, so
    // nothing waits on the network.
    final familyProvider = context.read<FamilyProvider>();
    if (familyProvider.members.isEmpty && !familyProvider.isLoading) {
      unawaited(familyProvider.loadFamilyMembers());
    }
    _onDestinationTapped(PatientShellTab.care);
  }

  void _leaveCareFlow() => _selectTab(resolveCareExitTab(_tabBeforeCare));

  /// « Back to home » at the end of a flow: shows the home feed and puts
  /// the finished flow's branch back on its first screen.
  void _showHomeFeed() {
    final finished = _selectedIndex;
    _selectTab(PatientShellTab.home);
    if (finished != PatientShellTab.home) _resetBranchToRoot(finished);
    _resetBranchToRoot(PatientShellTab.home);
  }

  void _handleSystemBack() {
    switch (_resolveBack()) {
      case PatientBackAction.popBranch:
        // maybePop lets the branch's own screens (e.g. an urgent request
        // waiting screen) veto leaving.
        _branchNavigatorKeys[_selectedIndex]?.currentState?.maybePop();
      case PatientBackAction.leaveCareFlow:
        _leaveCareFlow();
      case PatientBackAction.selectHomeTab:
        _selectTab(PatientShellTab.home);
      case PatientBackAction.allowRoutePop:
        break;
    }
  }

  bool _onBranchNavigation(int tab, NavigationNotification notification) {
    if (_branchCanPop(tab) != notification.canHandlePop && mounted) {
      setState(() => _branchCanHandlePop[tab] = notification.canHandlePop);
    }
    // Consumed: the shell's PopScope (which includes this state) is what
    // the platform must see, not a hidden branch's own state.
    return true;
  }

  Widget _buildBranches() {
    return IndexedStack(
      index: _selectedIndex,
      sizing: StackFit.expand,
      children: [
        for (final tab in PatientShellTab.ordered)
          TickerMode(
            enabled: tab == _selectedIndex,
            child: _builtBranches.contains(tab)
                ? _buildBranch(tab)
                : const SizedBox.shrink(),
          ),
      ],
    );
  }

  Widget _buildBranch(int tab) {
    return switch (tab) {
      PatientShellTab.home ||
      PatientShellTab.care => _buildBranchNavigator(tab),
      PatientShellTab.health => _buildHealthTab(),
      PatientShellTab.medicalRecord => const PatientPassportScreen(),
      _ => _buildProfileTab(),
    };
  }

  /// Home feed root of the « Accueil » branch. Built from the providers on
  /// each change because the branch outlives button switches (a name edited
  /// in « Profil » must show up on « Accueil »).
  Widget _buildHomeFeedRoute() {
    return Builder(
      builder: (context) => _buildHomeTab(
        _resolveUserName(
          context.watch<UserProvider>(),
          context.watch<UserOnboardingProvider>(),
        ),
      ),
    );
  }

  /// Builds a [PageRoute] for all Patient nested-Navigator content routes.
  ///
  /// Every patient-content route is wrapped in a full-size opaque
  /// [ColoredBox] surface so that the outgoing route's detailed content
  /// never bleeds through during the transition.  A restrained slide-from-
  /// right animation replaces the default Material zoom to avoid the
  /// prolonged cross-fade of two detailed page trees.
  static Route<dynamic> _buildPatientPageRoute({
    required WidgetBuilder builder,
    required RouteSettings settings,
  }) {
    return PageRouteBuilder(
      settings: settings,
      fullscreenDialog: false,
      pageBuilder: (context, animation, secondaryAnimation) {
        return ColoredBox(color: OmniColors.slateSoft, child: builder(context));
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween<Offset>(
          begin: const Offset(0.06, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));
        final fadeTween = Tween<double>(begin: 0, end: 1).chain(
          CurveTween(curve: const Interval(0.3, 1.0, curve: Curves.easeIn)),
        );
        return SlideTransition(
          position: animation.drive(tween),
          child: FadeTransition(
            opacity: animation.drive(fadeTween),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 200),
    );
  }

  Widget _buildBranchNavigator(int tab) {
    final rootRoute = patientBranchRootRoute(tab);
    return NotificationListener<NavigationNotification>(
      onNotification: (notification) => _onBranchNavigation(tab, notification),
      child: Navigator(
        key: _branchNavigatorKeys[tab],
        // Exactly one root route. `initialRoute: '/patient-home'` made
        // Flutter also build '/' (which fell back to a second home feed),
        // so the « Accueil » stack started with two identical home feeds.
        onGenerateInitialRoutes: (_, _) => [
          _generatePatientRoute(
            RouteSettings(name: rootRoute),
            tab,
            isRoot: true,
          ),
        ],
        onGenerateRoute: (settings) => _generatePatientRoute(settings, tab),
      ),
    );
  }

  Route<dynamic> _generatePatientRoute(
    RouteSettings settings,
    int tab, {
    bool isRoot = false,
  }) {
    // Emergency patient flow — arguments required for step2+.
    if (settings.name == '/emergency-step2') {
      final args = settings.arguments as Map<String, dynamic>;
      return _buildPatientPageRoute(
        builder: (_) => EmergencyRequestStep2(step1Data: args),
        settings: settings,
      );
    }
    if (settings.name == '/emergency-step3') {
      final args = settings.arguments as Map<String, dynamic>;
      return _buildPatientPageRoute(
        builder: (_) => EmergencyRequestStep3(previousData: args),
        settings: settings,
      );
    }
    if (settings.name == '/emergency-review') {
      final args = settings.arguments as Map<String, dynamic>;
      return _buildPatientPageRoute(
        builder: (_) => EmergencyReviewScreen(requestData: args),
        settings: settings,
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
      return _buildPatientPageRoute(
        builder: (_) => const ClinicalFeatureUnavailableScreen(),
        settings: settings,
      );
    }
    if (settings.name == '/m05/doctor-detail') {
      final args = settings.arguments;
      final doctorId = args is String ? args.trim() : '';
      return _buildPatientPageRoute(
        builder: (_) => doctorId.isEmpty
            ? const _InvalidDoctorDetailRouteScreen()
            : DoctorDetailScreen(doctorId: doctorId),
        settings: settings,
      );
    }

    // The care branch's first screen: its back arrow leaves the care flow
    // (there is no screen under it to pop to).
    final isCareRoot = isRoot && tab == PatientShellTab.care;

    // Static routes — M05 clinic flow, emergency step0/1, and home.
    final page = switch (settings.name) {
      patientHomeRootRoute => _buildHomeFeedRoute(),
      patientCareFlowEntryRoute when isCareRoot => ProviderSelectionScreen(
        onBack: _leaveCareFlow,
      ),
      patientCareFlowEntryRoute => const ProviderSelectionScreen(),
      '/emergency-step0' => const EmergencyRequestStep0(),
      '/urgent-care-mode-selection' => const UrgentCareModeSelectionScreen(),
      '/urgent-cabinet/care-subject' => const UrgentCabinetFlowShell(),
      '/emergency-step1' => const EmergencyRequestStep1(),
      '/clinical-request-unavailable' =>
        const ClinicalFeatureUnavailableScreen(),
      '/m05/request' => const RequestFlowEntryScreen(),
      '/doctor/cabinet/who-needs-care' => const DoctorCabinetEntryScreen(),
      '/m05/who-needs-care' => const WhoNeedsCareScreen(),
      '/m05/clinic-directory' => const ClinicDirectoryScreen(),
      '/m05/doctor-directory' => const DoctorDirectoryScreen(),
      '/m05/situation' => const SituationScreen(),
      '/m05/pickup' => const PickupScreen(),
      '/m05/review' => const ReviewScreen(),
      '/m05/received' => const RequestReceivedScreen(),
      '/m05/requests' => const MyRequestsScreen(),
      // Unknown names fall back to the branch's own first screen, never to
      // another button's content.
      _ when tab == PatientShellTab.care => const ProviderSelectionScreen(),
      _ => _buildHomeFeedRoute(),
    };
    return _buildPatientPageRoute(builder: (_) => page, settings: settings);
  }

  Widget _buildHomeTab(String userName) {
    return PatientHomeFeed(
      displayName: userName,
      onOpenHealth: () => _selectTab(PatientShellTab.health),
      onOpenMedicalRecord: () => _selectTab(PatientShellTab.medicalRecord),
      onOpenProfile: () => _selectTab(PatientShellTab.profile),
    );
  }

  Widget _buildUrgentCareCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1FBF9A), Color(0xFF0F9D7E)],
          ),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1FBF9A).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.access_time,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Urgent Care',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Need a Doctor Right Now?',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.2,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'A verified doctor at your door within minutes.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Colors.white.withOpacity(0.9),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () async {
                  final familyProvider = Provider.of<FamilyProvider>(
                    context,
                    listen: false,
                  );
                  if (familyProvider.members.isEmpty &&
                      !familyProvider.isLoading) {
                    await familyProvider.loadFamilyMembers();
                  }
                  if (!mounted) return;
                  Navigator.pushNamed(context, '/emergency-step0');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1FBF9A),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Request Urgent Doctor',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsCards() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.videocam,
                      color: Color(0xFF8B5CF6),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Start Live Call',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A202C),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Psychologist',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.phone,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Call Ambulance',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SAMU - 190',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Image placeholder for doctors
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F5F7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/images/Doctors-bro.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF1FBF9A).withOpacity(0.1),
                            const Color(0xFF6BE3B2).withOpacity(0.1),
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.groups,
                        size: 48,
                        color: Color(0xFF1FBF9A),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trusted by over',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A202C),
                    ),
                  ),
                  Text(
                    '100 doctors',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A202C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Licensed & verified across Tunisia',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF667085),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorksSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            'How it works',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A202C),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 32),
          _buildStepCard(
            number: '1',
            title: 'Describe your symptoms',
            description: 'Tell us what\'s wrong and select the affected area.',
            icon: Icons.edit_note_rounded,
            color: const Color(0xFF1FBF9A),
          ),
          const SizedBox(height: 16),
          _buildStepCard(
            number: '2',
            title: 'Get matched instantly',
            description: 'We connect you with the nearest available doctor.',
            icon: Icons.person_search_rounded,
            color: const Color(0xFF8B5CF6),
          ),
          const SizedBox(height: 16),
          _buildStepCard(
            number: '3',
            title: 'Receive care at home',
            description: 'Your doctor arrives and provides quality treatment.',
            icon: Icons.home_rounded,
            color: const Color(0xFF0F6F73),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required String number,
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(child: Icon(icon, color: color, size: 28)),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          number,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1A202C),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF667085),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCTAButton({
    required IconData icon,
    required String label,
    required Color color,
    bool outlined = false,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: outlined ? Colors.white : color,
        foregroundColor: outlined ? color : Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: outlined ? BorderSide(color: color, width: 2) : BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildSearchFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Find a Doctor',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1D2939),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                hintText: 'Search doctors...',
                hintStyle: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF9CA3AF),
                ),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF667085)),
                filled: true,
                fillColor: const Color(0xFFF4F5F7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.black.withOpacity(0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.black.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFF1FBF9A),
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorsList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Doctors (0)',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1D2939),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              'No doctors available yet.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF667085),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorCard(Map<String, dynamic> doctor) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Stack(
              children: [
                Container(
                  height: 160,
                  width: double.infinity,
                  color: const Color(0xFFF4F5F7),
                  child: const Icon(
                    Icons.person,
                    size: 60,
                    color: Color(0xFF667085),
                  ),
                ),
                if (doctor['verified'] == true)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor['name'],
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1D2939),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  doctor['specialty'],
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: const Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 14,
                      color: Color(0xFF667085),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${doctor['distance']} km',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.star, size: 14, color: Color(0xFFFBBF24)),
                    const SizedBox(width: 4),
                    Text(
                      '${doctor['rating']}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1D2939),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${doctor['experience']} years experience',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: const Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1FBF9A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Request Visit',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    final userProvider = Provider.of<UserProvider>(context);
    final familyProvider = Provider.of<FamilyProvider>(context);
    final profile = userProvider.profile!;

    return PatientProfileScreen(
      identity: PatientProfileIdentity(
        firstName: profile.firstName,
        lastName: profile.lastName,
        displayName: profile.displayName,
        phoneNumber: profile.primaryPhone?.value ?? '',
        phoneVerified: profile.primaryPhone?.verified ?? false,
        email: profile.primaryEmail?.value ?? '',
        emailVerified: profile.primaryEmail?.verified ?? false,
        avatarUrl: profile.photoUrl,
        dateOfBirth: profile.dateOfBirth,
        gender: profile.gender,
      ),
      familyMembers: familyProvider.members
          .map(
            (member) => PatientProfileFamilyMember(
              id: member.id,
              name: member.fullName,
              relationship: core_models.FamilyRelationships.frenchLabel(
                member.relationship,
              ),
              avatarUrl: member.photoUrl,
              graduated: member.graduated,
            ),
          )
          .toList(growable: false),
      preferredLanguage: profile.preferredLanguage,
      notificationMedications: profile.notifications.medications,
      notificationAppointments: profile.notifications.appointments,
      notificationPassport: profile.notifications.passport,
      isSaving: userProvider.isSaving,
      isAvatarUploading: userProvider.isAvatarUploading,
      avatarUploadProgress: userProvider.avatarUploadProgress,
      avatarErrorMessage: userProvider.avatarSelectionFailed
          ? OmniLocalizations.of(context).avatarSelectionFailed
          : userProvider.avatarFailure == null
          ? null
          : apiFailureMessage(
              userProvider.avatarFailure!,
              OmniLocalizations.of(context),
              fallback: OmniLocalizations.of(context).avatarUpdateFailed,
            ),
      errorMessage: userProvider.saveFailure == null
          ? null
          : apiFailureMessage(
              userProvider.saveFailure!,
              OmniLocalizations.of(context),
              fallback: OmniLocalizations.of(context).profileSaveFailed,
            ),
      onRetry: userProvider.clearSaveError,
      onAvatarSourceSelected: _selectAndUploadAvatar,
      onAvatarRemove: () async {
        await userProvider.removeAvatar();
      },
      onAvatarRetry: userProvider.canRetryAvatar
          ? () async {
              await userProvider.retryAvatarUpload();
            }
          : null,
      onAvatarErrorDismiss: userProvider.clearAvatarError,
      familyIsLoading: familyProvider.isLoading,
      familyErrorMessage: familyProvider.loadFailure == null
          ? null
          : apiFailureMessage(
              familyProvider.loadFailure!,
              OmniLocalizations.of(context),
              fallback: OmniLocalizations.of(context).familyLoadFailed,
            ),
      onRetryFamily: familyProvider.loadFamilyMembers,
      onPersonalInformationChanged:
          ({
            required firstName,
            required lastName,
            required dateOfBirth,
            required gender,
          }) async {
            await userProvider.updatePersonalInformation(
              firstName: firstName,
              lastName: lastName,
              dateOfBirth: dateOfBirth,
              gender: gender,
            );
          },
      onLanguageChanged: (language) async {
        await userProvider.updatePreferences(preferredLanguage: language);
      },
      onNotificationPreferencesChanged:
          ({medications, appointments, passport}) async {
            await userProvider.updatePreferences(
              notificationMedications: medications,
              notificationAppointments: appointments,
              notificationPassport: passport,
            );
          },
      onOpenAccountSecurity: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const AccountSecurityScreen())),
      onOpenDevices: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const DeviceManagementScreen())),
      onOpenLoginHistory: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const LoginHistoryScreen())),
      onOpenAppointments: _openPatientAppointments,
      onOpenRequests: () => Navigator.of(context).pushNamed('/m05/requests'),
      isLoggingOut: _isLoggingOut,
      onLogout: _handleLogout,
      onAddFamilyMember: () => _openFamilyMemberForm(),
      onEditFamilyMember: _editFamilyMember,
      onDeactivateFamilyMember: _deactivateFamilyMember,
    );
  }

  Widget _buildHealthTab() {
    final onboarding = Provider.of<UserOnboardingProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final resolvedDisplayName = (userProvider.user?.displayName ?? '').trim();
    final userName = resolvedDisplayName.isNotEmpty
        ? resolvedDisplayName
        : (onboarding.email?.split('@')[0] ?? 'User');

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // Section 1: Personal Medical Passport
            _buildMedicalPassportSection(userName),

            const SizedBox(height: 32),

            // Section 2: Medical Documents
            _buildMedicalDocumentsSection(),

            const SizedBox(height: 32),

            // Section 3: Family Circle
            _buildFamilyCircleSection(),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalPassportSection(String userName) {
    final onboarding = Provider.of<UserOnboardingProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);

    final Map<String, dynamic> medicalInfo =
        userProvider.user?.medicalInfo ?? const <String, dynamic>{};
    final List<String> chronicConditions =
        (medicalInfo['chronicConditions'] is List)
        ? (medicalInfo['chronicConditions'] as List)
              .map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList()
        : const <String>[];
    final List<Map<String, dynamic>> currentMedications =
        (medicalInfo['currentMedications'] is List)
        ? (medicalInfo['currentMedications'] as List)
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList()
        : const <Map<String, dynamic>>[];
    final String bloodGroup = (userProvider.user?.bloodGroup ?? '').trim();
    final String? avatarUrl = (userProvider.user?.avatar ?? '').trim().isEmpty
        ? null
        : userProvider.user?.avatar;

    final String patientName;
    if (userProvider.isLoading && userProvider.user == null) {
      patientName = 'Loading...';
    } else if ((userProvider.user?.displayName ?? '').trim().isNotEmpty) {
      patientName = userProvider.user!.displayName;
    } else if ((onboarding.email ?? '').isNotEmpty) {
      patientName = onboarding.email!.split('@')[0];
    } else {
      patientName = 'User';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mon Carnet de Santé Digital',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1A202C),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Votre passeport médical pour un accès rapide',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _buildLogoutButton(),
          ],
        ),
        const SizedBox(height: 20),

        Align(
          alignment: Alignment.center,
          child: Stack(
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF1FBF9A).withOpacity(0.25),
                    width: 3,
                  ),
                ),
                child: ClipOval(
                  child: avatarUrl != null
                      ? CachedNetworkImage(
                          imageUrl: avatarUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, _) => const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          errorWidget: (context, _, __) => const Center(
                            child: Icon(
                              Icons.person,
                              size: 44,
                              color: Color(0xFF1FBF9A),
                            ),
                          ),
                        )
                      : const Center(
                          child: Icon(
                            Icons.person,
                            size: 44,
                            color: Color(0xFF1FBF9A),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Digital ID Card
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1FBF9A).withOpacity(0.05),
                Colors.white,
                const Color(0xFF6BE3B2).withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => QRCodeModal(
                        patientName: patientName,
                        subject: const MedicalSharingSubject.self(),
                        isFamilyMember: false,
                      ),
                    );
                  },
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF1FBF9A).withOpacity(0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1FBF9A).withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.qr_code_2,
                          size: 64,
                          color: Color(0xFF1FBF9A),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Cliquez pour afficher',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF667085),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  patientName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A202C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pour scan médecin',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Blood Type
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GROUPE SANGUIN',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF667085),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                border: Border.all(color: const Color(0xFFFECACA)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.favorite,
                    color: Color(0xFFDC2626),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    BloodType.fromWire(
                          bloodGroup,
                        )?.label(OmniLocalizations.of(context)) ??
                        '-',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Chronic Conditions
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CONDITIONS CHRONIQUES',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF667085),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            if (chronicConditions.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  'Aucune condition',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF667085),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: chronicConditions.map(_buildConditionChip).toList(),
              ),
          ],
        ),

        const SizedBox(height: 24),

        // Current Medications
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MÉDICAMENTS ACTUELS',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF667085),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            if (currentMedications.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  'Aucun médicament',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF667085),
                  ),
                ),
              )
            else
              Column(
                children: [
                  for (int i = 0; i < currentMedications.length; i++) ...[
                    _buildMedicationItem(
                      (() {
                        final m = currentMedications[i];
                        final name = (m['name'] ?? '').toString().trim();
                        final fallback = (m['medicationId'] ?? 'Medication')
                            .toString();
                        final form = (m['form'] ?? '').toString().trim();
                        final soluble = m['soluble'] == true;
                        final base = name.isNotEmpty ? name : fallback;
                        final extras = <String>[];
                        if (form.isNotEmpty) extras.add(form);
                        if (soluble) extras.add('Soluble');
                        if (extras.isEmpty) return base;
                        return '$base (${extras.join(' • ')})';
                      })(),
                      (currentMedications[i]['dosage'] ??
                              currentMedications[i]['catalogDosage'] ??
                              '-')
                          .toString(),
                      (currentMedications[i]['frequency'] ?? '-').toString(),
                    ),
                    if (i != currentMedications.length - 1)
                      const SizedBox(height: 8),
                  ],
                ],
              ),
          ],
        ),

        // Edit Button
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: const Color(0xFFE2E8F0))),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _editOwnMedicalData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1FBF9A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Modifier Mes Données',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      height: 40,
      child: OutlinedButton(
        onPressed: _isLoggingOut ? null : _handleLogout,
        style: OutlinedButton.styleFrom(
          // The theme's full-width minimum (Size(double.infinity, 50))
          // overflows inside the header Row; size to the label instead.
          minimumSize: const Size(0, 40),
          foregroundColor: const Color(0xFFDC2626),
          side: const BorderSide(color: Color(0xFFFECACA)),
          backgroundColor: const Color(0xFFFEF2F2),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: _isLoggingOut
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFDC2626),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.logout_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Déconnexion',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildConditionChip(String condition) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF6BE3B2).withOpacity(0.1),
        border: Border.all(color: const Color(0xFF6BE3B2).withOpacity(0.3)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: const Color(0xFF0F6F73),
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            condition,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F6F73),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationItem(String name, String dosage, String frequency) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF1FBF9A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.medication,
              color: const Color(0xFF1FBF9A),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A202C),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$dosage • $frequency',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalDocumentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mes Documents Médicaux',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1A202C),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Analyses et ordonnances',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildDocumentItem(
                'Analyse de Sang Complète',
                '10 Fév 2026',
                Icons.bloodtype,
                const Color(0xFFDC2626),
              ),
              const SizedBox(height: 12),
              _buildDocumentItem(
                'Radio Thorax - Contrôle',
                '28 Jan 2026',
                Icons.medical_services,
                const Color(0xFF8B5CF6),
              ),
              const SizedBox(height: 12),
              _buildDocumentItem(
                'Ordonnance Janvier 2026',
                '15 Jan 2026',
                Icons.description,
                const Color(0xFF1FBF9A),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1FBF9A).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1FBF9A).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.info_outline,
                        color: const Color(0xFF1FBF9A),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Vos documents sont stockés de manière sécurisée',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF667085),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentItem(
    String name,
    String date,
    IconData icon,
    Color color,
  ) {
    String docType = 'other';
    if (icon == Icons.bloodtype) {
      docType = 'blood-test';
    } else if (icon == Icons.medical_services) {
      docType = 'xray';
    } else if (icon == Icons.description) {
      docType = 'prescription';
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DocumentViewerScreen(
              documentName: name,
              documentDate: date,
              documentType: docType,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A202C),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF667085),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: const Color(0xFF667085), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyCircleSection() {
    final familyProvider = Provider.of<FamilyProvider>(context);
    final family = familyProvider.members;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cercle Familial',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A202C),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Gérez les carnets de santé de vos proches',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF667085),
          ),
        ),
        const SizedBox(height: 16),

        if (family.isEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aucun membre de famille pour le moment',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A202C),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ajoutez un proche pour gérer son carnet de santé.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Family Members Grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.85,
          children: [
            ...family.map((m) {
              final age = '${m.ageYears} ans';
              final alert = null;
              return _buildFamilyMemberCard(
                m.fullName,
                core_models.FamilyRelationships.frenchLabel(m.relationship),
                age,
                alert,
                memberId: m.id,
              );
            }),
            _buildAddFamilyMemberCard(),
          ],
        ),

        const SizedBox(height: 20),

        // Info Banner
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1FBF9A).withOpacity(0.1),
                const Color(0xFF6BE3B2).withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1FBF9A).withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1FBF9A).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.family_restroom,
                  color: const Color(0xFF1FBF9A),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Chef de Famille - Accès Complet',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A202C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Gérez les carnets de santé de vos proches',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF667085),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFamilyMemberCard(
    String name,
    String relationship,
    String age,
    String? alert, {
    String? memberId,
  }) {
    return GestureDetector(
      onTap: () {
        final familyProvider = Provider.of<FamilyProvider>(
          context,
          listen: false,
        );
        final core = (memberId == null)
            ? null
            : familyProvider.members
                  .cast<core_models.FamilyMember?>()
                  .firstWhere(
                    (m) => m != null && m.id == memberId,
                    orElse: () => null,
                  );
        if (core == null) {
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                FamilyMemberDetailScreen(member: _toDetailMember(core)),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF1FBF9A).withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF1FBF9A), width: 2),
              ),
              child: Icon(
                Icons.person,
                color: const Color(0xFF1FBF9A),
                size: 26,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF0F6F73),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                relationship,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A202C),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              age,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF667085),
              ),
            ),
            if (alert != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  border: Border.all(color: const Color(0xFFFECACA)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: const Color(0xFFDC2626),
                      size: 12,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        alert,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFDC2626),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              'Voir le carnet',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF667085),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddFamilyMemberCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1FBF9A).withOpacity(0.3),
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AddFamilyMemberScreen(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF1FBF9A).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add,
                  color: const Color(0xFF1FBF9A),
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Ajouter Membre',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A202C),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Ajoutez un proche',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF667085),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUrgentDoctorModal() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1FBF9A), Color(0xFF0F6F73)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1FBF9A).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.medical_services_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Demande Urgente',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A202C),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Besoin d\'un médecin en urgence ?',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: const Color(0xFF667085),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    // Handle urgent doctor request
                  },
                  icon: const Icon(Icons.phone, size: 24),
                  label: Text(
                    'Appeler un Médecin',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    // Handle video consultation request
                  },
                  icon: const Icon(Icons.videocam, size: 24),
                  label: Text(
                    'Consultation Vidéo',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1FBF9A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    // Handle chat request
                  },
                  icon: const Icon(Icons.chat_bubble, size: 24),
                  label: Text(
                    'Chat avec un Médecin',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1FBF9A),
                    side: const BorderSide(color: Color(0xFF1FBF9A), width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Annuler',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF667085),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageCard({
    required String name,
    required String message,
    required String time,
    required bool isUnread,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnread ? const Color(0xFFF0FDF9) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnread
              ? const Color(0xFF1FBF9A).withOpacity(0.3)
              : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF1FBF9A).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: Color(0xFF1FBF9A), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A202C),
                      ),
                    ),
                    Text(
                      time,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                    color: isUnread
                        ? const Color(0xFF1A202C)
                        : const Color(0xFF667085),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyHeader(String userName) {
    final unreadCount =
        context.watch<NotificationCenterController?>()?.unreadCount ?? 0;
    return ClipRect(
      key: const ValueKey('patient-top-bar'),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            border: Border(
              bottom: BorderSide(
                color: Colors.black.withValues(alpha: 0.08),
                width: 0.5,
              ),
            ),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: SizedBox(
                height: 72,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Image.asset(
                            'assets/images/logo.png',
                            height: 43,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Text(
                              'OmniCare',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF07536A),
                              ),
                            ),
                          ),
                        ),
                      ),
                      NotificationBadge(
                        count: unreadCount,
                        onTap: () =>
                            Navigator.pushNamed(context, '/notifications'),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Se déconnecter',
                        constraints: const BoxConstraints.tightFor(
                          width: 40,
                          height: 40,
                        ),
                        padding: const EdgeInsets.all(8),
                        onPressed: _isLoggingOut ? null : _handleLogout,
                        icon: _isLoggingOut
                            ? const SizedBox(
                                width: 21,
                                height: 21,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFFF3347),
                                ),
                              )
                            : const Icon(
                                Icons.logout_rounded,
                                color: Color(0xFFFF3347),
                                size: 22,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showLanguageSelector(UserOnboardingProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Select Language',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1D2939),
                ),
              ),
              const SizedBox(height: 24),
              _buildLanguageOption(provider, 'en', 'English', '🇬🇧'),
              const SizedBox(height: 12),
              _buildLanguageOption(provider, 'fr', 'Français', '🇫🇷'),
              const SizedBox(height: 12),
              _buildLanguageOption(provider, 'ar', 'العربية', '🇸🇦'),
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(
    UserOnboardingProvider provider,
    String languageCode,
    String languageName,
    String flag,
  ) {
    final isSelected = (provider.language ?? 'en') == languageCode;

    return GestureDetector(
      onTap: () {
        provider.setLanguage(languageCode);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1FBF9A).withOpacity(0.08)
              : const Color(0xFFF4F5F7),
          border: Border.all(
            color: isSelected ? const Color(0xFF1FBF9A) : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(flag, style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                languageName,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1D2939),
                ),
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFF1FBF9A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: _buildUrgentRequestCard()),
          const SizedBox(width: 16),
          Expanded(child: _buildMyRequestsCard()),
        ],
      ),
    );
  }

  Widget _buildUrgentRequestCard() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/m05/request'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1FBF9A), Color(0xFF6BE3B2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1FBF9A).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.add_alert_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Demande\nUrgente',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Médecin à domicile',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyRequestsCard() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/m05/requests'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFF1FBF9A), width: 2),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1FBF9A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                color: Color(0xFF1FBF9A),
                size: 24,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Mes\ndemandes',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1FBF9A),
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Suivre mes demandes de soins',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF667085),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingAppointment() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_today,
                color: Color(0xFF1FBF9A),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Rendez-vous à venir',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A202C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1FBF9A).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Color(0xFF1FBF9A),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Dr. Ahmed Ben Salem',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1A202C),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified,
                                color: Color(0xFF1FBF9A),
                                size: 16,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1FBF9A).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Cardiologue',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF1FBF9A),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      color: Color(0xFF667085),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Lundi, 15 Mars 2024 • 10:00 AM',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Color(0xFF667085),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Clinique Centrale, Tunis',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.phone, size: 18),
                        label: Text(
                          'Appeler',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1FBF9A),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.message, size: 18),
                        label: Text(
                          'Message',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1FBF9A),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.location_on, size: 18),
                        label: Text(
                          'Lieu',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1FBF9A),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthMetrics() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mes Indicateurs de Santé',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1A202C),
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.3,
            children: [
              _buildMetricCard(
                icon: Icons.favorite,
                label: 'Fréquence Cardiaque',
                value: '72',
                unit: 'bpm',
                color: const Color(0xFFEF4444),
              ),
              _buildMetricCard(
                icon: Icons.water_drop,
                label: 'Tension Artérielle',
                value: '120/80',
                unit: 'mmHg',
                color: const Color(0xFF1FBF9A),
              ),
              _buildMetricCard(
                icon: Icons.monitor_weight,
                label: 'Poids',
                value: '65',
                unit: 'kg',
                color: const Color(0xFF0F6F73),
              ),
              _buildMetricCard(
                icon: Icons.thermostat,
                label: 'Température',
                value: '36.8',
                unit: '°C',
                color: const Color(0xFFF59E0B),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF667085),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A202C),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      unit,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF667085),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      key: const ValueKey('home-bottom-navigation'),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE1E7E5))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    _buildNavItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home_outlined,
                      label: 'Accueil',
                      index: PatientShellTab.home,
                      hasNotification: false,
                    ),
                    _buildNavItem(
                      icon: Icons.favorite_border_rounded,
                      activeIcon: Icons.favorite_rounded,
                      label: 'Ma Santé',
                      index: PatientShellTab.health,
                      hasNotification: false,
                    ),
                    _buildCenterNavItem(),
                    _buildNavItem(
                      iconAsset: 'assets/svg/medical_pass_grey.svg',
                      activeIconAsset: 'assets/svg/medical_pass_green.svg',
                      label: 'Dossier médical',
                      index: PatientShellTab.medicalRecord,
                      hasNotification: false,
                    ),
                    _buildNavItem(
                      icon: Icons.account_circle_outlined,
                      activeIcon: Icons.account_circle_outlined,
                      label: 'Profil',
                      index: PatientShellTab.profile,
                      hasNotification: false,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterNavItem() {
    final isSelected = _selectedIndex == PatientShellTab.care;
    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Demander des soins',
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('patient-care-action'),
        behavior: HitTestBehavior.opaque,
        onTap: _onCareActionTapped,
        child: _buildCenterNavButton(isSelected: isSelected),
      ),
    );
  }

  Widget _buildCenterNavButton({required bool isSelected}) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1FC6A5), Color(0xFF087C76)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: isSelected
            ? Border.all(color: const Color(0xFFBDEFE2), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF0A8C80,
            ).withValues(alpha: isSelected ? 0.32 : 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: SvgPicture.asset(
          'assets/svg/omnicare_logo_white.svg',
          fit: BoxFit.contain,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          placeholderBuilder: (_) => _buildCenterLogoFallback(),
          errorBuilder: (_, _, _) => _buildCenterLogoFallback(),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    IconData? icon,
    IconData? activeIcon,
    String? iconAsset,
    String? activeIconAsset,
    required String label,
    required int index,
    required bool hasNotification,
  }) {
    assert(icon != null || iconAsset != null);
    assert(activeIcon != null || activeIconAsset != null);
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _onDestinationTapped(index),
          child: Center(
            // Selection state switches in the tap's frame: no cross-fade
            // where two buttons look selected at once.
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFE8F8F3)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: iconAsset != null
                        // Both SVG states stay loaded; swapping the asset on
                        // selection made the new file load asynchronously
                        // and flashed the placeholder icon.
                        ? IndexedStack(
                            index: isSelected ? 1 : 0,
                            children: [
                              _buildNavSvg(iconAsset, selected: false),
                              _buildNavSvg(
                                activeIconAsset ?? iconAsset,
                                selected: true,
                              ),
                            ],
                          )
                        : Icon(
                            isSelected ? activeIcon : icon,
                            color: isSelected
                                ? const Color(0xFF087A65)
                                : const Color(0xFFA8AAAD),
                            size: 32,
                          ),
                  ),
                  if (hasNotification)
                    Positioned(
                      right: 8,
                      top: 6,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavSvg(String asset, {required bool selected}) {
    final fallbackColor = selected
        ? const Color(0xFF087A65)
        : const Color(0xFFA8AAAD);
    return SvgPicture.asset(
      asset,
      width: 56,
      height: 56,
      fit: BoxFit.contain,
      placeholderBuilder: (_) => const SizedBox(width: 56, height: 56),
      errorBuilder: (_, _, _) =>
          Icon(Icons.menu_book_outlined, color: fallbackColor, size: 30),
    );
  }

  Widget _buildCenterLogoFallback() {
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      child: Image.asset('assets/images/app_logo.png', fit: BoxFit.contain),
    );
  }
}

class _InvalidDoctorDetailRouteScreen extends StatelessWidget {
  const _InvalidDoctorDetailRouteScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Médecin')),
    body: const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Ce médecin n’est pas disponible.',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}
