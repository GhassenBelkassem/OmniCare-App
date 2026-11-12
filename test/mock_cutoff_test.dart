// G-2 1b-3: every former mock path now fails with the typed
// "feature unavailable" failure instead of serving invented data.
// Logic only (CTO testing rule).
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:omnicare_mobile/core/api/medications_api.dart';
import 'package:omnicare_mobile/core/models/patient_profile.dart';
import 'package:omnicare_mobile/core/network/api_failure.dart';
import 'package:omnicare_mobile/core/network/api_failure_message.dart';
import 'package:omnicare_mobile/core/result/result.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_doctor_source.dart';
import 'package:omnicare_mobile/features/patient_appointments/application/patient_appointments_controller.dart';
import 'package:omnicare_mobile/l10n/omni_localizations.dart';
import 'package:omnicare_mobile/providers/reservation_provider.dart';
import 'package:omnicare_mobile/providers/user_provider.dart';
import 'package:omnicare_mobile/repositories/reservation_repository.dart';
import 'package:omnicare_mobile/repositories/user_repository.dart';

final _isUnavailable = isA<ApiFailure>().having(
  (failure) => failure.isFeatureUnavailable,
  'isFeatureUnavailable',
  isTrue,
);

void main() {
  test('the failure is typed and has French text', () {
    const failure = ApiFailure.featureUnavailable;
    expect(failure.kind, ApiFailureKind.featureUnavailable);
    expect(failure.code, 'FEATURE_UNAVAILABLE');
    expect(
      apiFailureMessage(failure, lookupOmniLocalizations(const Locale('fr'))),
      'Cette fonctionnalité est indisponible pour le moment.',
    );
    // It survives the single parser and the Result wrapper unchanged.
    expect(ApiFailure.from(failure), same(failure));
  });

  group('medication search (onboarding, medical data editor)', () {
    final api = MedicationsApi();

    test('no mock suggestions: any search is unavailable', () async {
      await expectLater(api.searchTop10('dol'), throwsA(_isUnavailable));
      await expectLater(
        api.searchDistinctDciTop20('para'),
        throwsA(_isUnavailable),
      );
    });

    test('an empty query still returns nothing without failing', () async {
      expect(await api.searchTop10('  '), isEmpty);
      expect(await api.searchDistinctDciTop20(''), isEmpty);
    });
  });

  group('user profile without its APIs (no mock user)', () {
    final repository = UserRepository();

    test('every call fails as unavailable', () async {
      await expectLater(repository.getProfile(), throwsA(_isUnavailable));
      await expectLater(
        repository.updateProfile(const PatientProfileUpdate(firstName: 'A')),
        throwsA(_isUnavailable),
      );
      await expectLater(
        repository.uploadAvatar(XFile('/tmp/avatar.jpg')),
        throwsA(_isUnavailable),
      );
      await expectLater(repository.removeAvatar(), throwsA(_isUnavailable));
      await expectLater(
        repository.saveOnboardingStep(1, const {}),
        throwsA(_isUnavailable),
      );
    });

    test('as a Result it is an Err, never an invented profile', () async {
      final result = await guardApiCall(repository.getProfile);
      expect(result, isA<Err<PatientProfile>>());
      expect(
        (result as Err<PatientProfile>).failure.isFeatureUnavailable,
        isTrue,
      );
    });

    test('a default UserProvider exposes the failure, no profile', () async {
      final users = UserProvider();
      await expectLater(users.refresh(), throwsA(_isUnavailable));
      expect(users.profile, isNull);
      expect(users.loadFailure?.isFeatureUnavailable, isTrue);
    });
  });

  group('reservations (legacy, unreachable; useMock removed)', () {
    test('the repository without API is unavailable, not mock data', () async {
      final repository = ReservationRepository();
      await expectLater(
        repository.listReservationRequests(),
        throwsA(_isUnavailable),
      );
    });

    test('the provider no longer forces a mock repository', () async {
      final provider = ReservationProvider();
      await expectLater(provider.refresh(), throwsA(_isUnavailable));
      expect(provider.requests, isEmpty);
    });
  });

  test('appointments list shows only what it is given (no mock default)', () {
    final controller = PatientAppointmentsController(appointments: const []);
    expect(controller.appointments, isEmpty);
  });

  test('the urgent CABINET source without data fails, from the non-fixture '
      'file production imports', () async {
    const source = UrgentCabinetDoctorUnavailableSource();
    expect(source.isDevelopmentFixture, isFalse);
    expect(
      source.loadDoctors,
      throwsA(isA<UrgentCabinetDoctorSourceUnavailable>()),
    );
    expect(
      () => source.loadUrgentCabinetFeeQuote(doctorId: 'd', cabinetId: 'c'),
      throwsA(isA<UrgentCabinetDoctorSourceUnavailable>()),
    );
  });
}
