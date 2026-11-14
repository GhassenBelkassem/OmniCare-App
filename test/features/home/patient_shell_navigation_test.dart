import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/features/home/patient_shell_navigation.dart';

const _home = PatientShellTab.home;
const _health = PatientShellTab.health;
const _care = PatientShellTab.care;
const _record = PatientShellTab.medicalRecord;
const _profile = PatientShellTab.profile;

PatientDestinationTapAction _tap(
  int selected,
  int tapped, {
  bool canPop = false,
}) => resolvePatientDestinationTap(
  selectedTab: selected,
  tappedTab: tapped,
  tappedBranchCanPop: canPop,
);

void main() {
  group('branches', () {
    test('one branch per bottom-bar button, in on-screen order', () {
      expect(PatientShellTab.ordered, [
        _home,
        _health,
        _care,
        _record,
        _profile,
      ]);
      // IndexedStack index == button index.
      for (var i = 0; i < PatientShellTab.ordered.length; i++) {
        expect(PatientShellTab.ordered[i], i);
      }
    });

    test('only Accueil and the care flow own a Navigator', () {
      expect(PatientShellTab.hasNavigator(_home), isTrue);
      expect(PatientShellTab.hasNavigator(_care), isTrue);
      expect(PatientShellTab.hasNavigator(_health), isFalse);
      expect(PatientShellTab.hasNavigator(_record), isFalse);
      expect(PatientShellTab.hasNavigator(_profile), isFalse);
    });

    test('each Navigator branch has its own first screen', () {
      expect(patientBranchRootRoute(_home), patientHomeRootRoute);
      expect(patientBranchRootRoute(_care), patientCareFlowEntryRoute);
    });
  });

  group('resolvePatientDestinationTap', () {
    test('every button opens its own branch from every other button', () {
      for (final from in PatientShellTab.ordered) {
        for (final to in PatientShellTab.ordered) {
          if (from == to) continue;
          for (final canPop in [true, false]) {
            expect(
              _tap(from, to, canPop: canPop),
              PatientDestinationTapAction.selectBranch,
              reason: '$from -> $to',
            );
          }
        }
      }
    });

    test('regression: logo from « Dossier médical » opens the care flow', () {
      expect(_tap(_record, _care), PatientDestinationTapAction.selectBranch);
    });

    test('re-tap on a Navigator branch deep in a flow resets it', () {
      expect(
        _tap(_home, _home, canPop: true),
        PatientDestinationTapAction.resetBranchToRoot,
      );
      expect(
        _tap(_care, _care, canPop: true),
        PatientDestinationTapAction.resetBranchToRoot,
      );
    });

    test('re-tap on a branch already on its first screen does nothing', () {
      for (final tab in PatientShellTab.ordered) {
        expect(_tap(tab, tab), PatientDestinationTapAction.none);
      }
    });

    test('re-tap on a branch without a Navigator does nothing', () {
      for (final tab in [_health, _record, _profile]) {
        expect(_tap(tab, tab, canPop: true), PatientDestinationTapAction.none);
      }
    });
  });

  group('resolveCareExitTab', () {
    test('returns to the button shown before the logo', () {
      for (final tab in [_home, _health, _record, _profile]) {
        expect(resolveCareExitTab(tab), tab);
      }
    });

    test('never returns into the care flow itself', () {
      expect(resolveCareExitTab(_care), _home);
    });
  });

  group('resolvePatientBack (system back)', () {
    test('a branch with screens to pop pops them first', () {
      for (final tab in PatientShellTab.ordered) {
        expect(
          resolvePatientBack(
            selectedTab: tab,
            selectedBranchCanHandlePop: true,
          ),
          PatientBackAction.popBranch,
        );
      }
    });

    test('care flow first screen returns to the previous button', () {
      expect(
        resolvePatientBack(
          selectedTab: _care,
          selectedBranchCanHandlePop: false,
        ),
        PatientBackAction.leaveCareFlow,
      );
    });

    test('other buttons return to Accueil', () {
      for (final tab in [_health, _record, _profile]) {
        expect(
          resolvePatientBack(
            selectedTab: tab,
            selectedBranchCanHandlePop: false,
          ),
          PatientBackAction.selectHomeTab,
        );
      }
    });

    test('Accueil home feed lets the app close', () {
      expect(
        resolvePatientBack(
          selectedTab: _home,
          selectedBranchCanHandlePop: false,
        ),
        PatientBackAction.allowRoutePop,
      );
    });
  });
}
