/// Pure navigation decisions for the patient shell's bottom navigation bar.
///
/// The shell follows Flutter's stateful-shell model (the `NavigationBar`
/// nested-Navigator sample, go_router's `StatefulShellRoute.indexedStack`):
/// every bottom-bar button owns one persistent branch, built on its first
/// visit and then kept alive, and a tap only changes which branch is shown.
/// [NewHomeScreen] executes the actions decided here.
library;

/// Bottom-bar buttons, in on-screen order. Each one owns a branch.
abstract final class PatientShellTab {
  static const int home = 0;
  static const int health = 1;

  /// Centre OmniCare logo: the care-request flow.
  static const int care = 2;
  static const int medicalRecord = 3;
  static const int profile = 4;

  static const List<int> ordered = [home, health, care, medicalRecord, profile];

  /// Branches that own a nested Navigator (screens are pushed inside them).
  static bool hasNavigator(int tab) => tab == home || tab == care;
}

/// Root route of the « Accueil » branch.
const String patientHomeRootRoute = '/patient-home';

/// Root route of the care branch opened by the centre logo button.
const String patientCareFlowEntryRoute = '/provider-selection';

String patientBranchRootRoute(int tab) => switch (tab) {
  PatientShellTab.care => patientCareFlowEntryRoute,
  _ => patientHomeRootRoute,
};

enum PatientDestinationTapAction {
  /// Show the tapped branch exactly as it was left.
  selectBranch,

  /// The tapped branch is already shown: go back to its first screen.
  resetBranchToRoot,

  /// The tapped branch is already shown on its first screen.
  none,
}

/// A tap on any bottom-bar button, the centre logo included.
PatientDestinationTapAction resolvePatientDestinationTap({
  required int selectedTab,
  required int tappedTab,
  required bool tappedBranchCanPop,
}) {
  assert(PatientShellTab.ordered.contains(tappedTab));
  if (tappedTab != selectedTab) return PatientDestinationTapAction.selectBranch;
  return PatientShellTab.hasNavigator(tappedTab) && tappedBranchCanPop
      ? PatientDestinationTapAction.resetBranchToRoot
      : PatientDestinationTapAction.none;
}

/// Where leaving the care flow from its first screen goes: back to the
/// button the patient was on before tapping the logo.
int resolveCareExitTab(int tabBeforeCare) =>
    tabBeforeCare == PatientShellTab.care
    ? PatientShellTab.home
    : tabBeforeCare;

enum PatientBackAction {
  /// Pop the shown branch (its own screens may still veto the pop).
  popBranch,

  /// Care flow on its first screen: return to the previous button.
  leaveCareFlow,

  /// Another button's first screen: return to « Accueil ».
  selectHomeTab,

  /// « Accueil » home feed: let the app route pop (leaves the app).
  allowRoutePop,
}

/// System back (Android button / predictive back gesture).
PatientBackAction resolvePatientBack({
  required int selectedTab,
  required bool selectedBranchCanHandlePop,
}) {
  if (selectedBranchCanHandlePop) return PatientBackAction.popBranch;
  return switch (selectedTab) {
    PatientShellTab.home => PatientBackAction.allowRoutePop,
    PatientShellTab.care => PatientBackAction.leaveCareFlow,
    _ => PatientBackAction.selectHomeTab,
  };
}
