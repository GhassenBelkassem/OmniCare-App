import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_care_subject.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_doctor_fixture.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_flow_controller.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_review.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_source.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_state.dart';

class _ControlledRequestSource extends UrgentCabinetRequestSource {
  _ControlledRequestSource();

  @override
  bool get isDevelopmentFixture => true;

  final completer = Completer<UrgentCabinetSubmissionOutcome>();
  int calls = 0;

  @override
  Future<UrgentCabinetSubmissionOutcome> submit(
    UrgentCabinetRequestReview review,
  ) {
    calls++;
    return completer.future;
  }
}

UrgentCabinetRequestReview _review({UrgentCabinetFeeQuote? fee}) {
  final doctor =
      UrgentCabinetDoctorFixtureSource.developmentDoctorDetails.first;
  final cabinet = doctor.cabinetById('p4-demo-cabinet-lac-1')!;
  final validation = validateUrgentCabinetRequestReview(
    careSubject: const UrgentCabinetCareSubject.self(),
    patientDisplayName: 'Sarah Martin',
    selectedDoctorId: doctor.doctorId,
    selectedCabinetId: cabinet.cabinetId,
    doctor: doctor,
    cabinet: cabinet,
    feeQuote:
        fee ?? UrgentCabinetDoctorFixtureSource.developmentFeeQuotes.first,
    developmentFixturesEnabled: true,
    now: DateTime.utc(2026, 10, 12),
  );
  return validation.review!;
}

UrgentCabinetFlowController _controller() {
  return UrgentCabinetFlowController(accountId: 'patient-user-1')
    ..selectSelf()
    ..selectDoctor(
      doctorId: 'p4-demo-doctor-amine-ben-salah',
      cabinetId: 'p4-demo-cabinet-lac-1',
    );
}

void main() {
  test(
    'submission enters submitting synchronously and rejects a double tap',
    () async {
      final controller = _controller();
      final review = _review();
      final source = _ControlledRequestSource();

      final first = controller.submitReview(review: review, source: source);
      expect(controller.requestState, isA<UrgentCabinetRequestSubmitting>());
      expect(controller.frozenReview, same(review));
      expect(source.calls, 1);

      final second = await controller.submitReview(
        review: review,
        source: source,
      );
      expect(second, UrgentCabinetSubmitTransition.rejected);
      expect(source.calls, 1);

      source.completer.complete(const UrgentCabinetSubmissionAcknowledged());
      expect(await first, UrgentCabinetSubmitTransition.pending);
      expect(
        controller.requestState,
        isA<UrgentCabinetRequestPendingDoctorResponse>(),
      );
      expect(controller.frozenReview, same(review));
    },
  );

  test(
    'selection mismatch and expired frozen fees never call the source',
    () async {
      final mismatchedController = _controller()
        ..selectDoctor(
          doctorId: 'different-doctor',
          cabinetId: 'different-cabinet',
        );
      final source = _ControlledRequestSource();

      expect(
        await mismatchedController.submitReview(
          review: _review(),
          source: source,
        ),
        UrgentCabinetSubmitTransition.rejected,
      );
      expect(source.calls, 0);

      final expiry = DateTime.utc(2026, 10, 13);
      final expiringFee = UrgentCabinetFeeQuote(
        doctorId: 'p4-demo-doctor-amine-ben-salah',
        cabinetId: 'p4-demo-cabinet-lac-1',
        amountMilliTnd: 75000,
        currencyCode: 'TND',
        provenance: UrgentCabinetFeeProvenance.developmentFixture,
        expiresAt: expiry,
        configurationRevision: 11,
        runtimeRevision: 21,
        practiceLocationVersion: 31,
      );
      final expiredSource = _ControlledRequestSource();
      expect(
        await _controller().submitReview(
          review: _review(fee: expiringFee),
          source: expiredSource,
          now: expiry,
        ),
        UrgentCabinetSubmitTransition.rejected,
      );
      expect(expiredSource.calls, 0);
    },
  );

  test(
    'account reset invalidates a stale asynchronous acknowledgement',
    () async {
      final controller = _controller();
      final source = _ControlledRequestSource();
      final attempt = controller.submitReview(
        review: _review(),
        source: source,
      );

      controller.ensureAccount('patient-user-2');
      source.completer.complete(const UrgentCabinetSubmissionAcknowledged());

      expect(await attempt, UrgentCabinetSubmitTransition.obsolete);
      expect(controller.requestState, isA<UrgentCabinetRequestDraft>());
      expect(controller.frozenReview, isNull);
      expect(controller.selectedSubject, isNull);
    },
  );

  test(
    'explicit failures remain typed and never create fictional pending',
    () async {
      final definite = _controller();
      await definite.submitReview(
        review: _review(),
        source: const UrgentCabinetDevelopmentRequestSource(
          scenario:
              UrgentCabinetDevelopmentSubmissionScenario.definitelyNotSubmitted,
        ),
      );
      expect(
        definite.requestState,
        isA<UrgentCabinetRequestSubmissionFailed>().having(
          (state) => state.kind,
          'kind',
          UrgentCabinetSubmissionFailureKind.definitelyNotSubmitted,
        ),
      );

      final productionSource = UrgentCabinetRequestSources.forBuild(
        enableDevelopmentFixtures: false,
      );
      expect(productionSource.isDevelopmentFixture, isFalse);
      final productionOutcome = await productionSource.submit(_review());
      expect(
        productionOutcome,
        isA<UrgentCabinetSubmissionRejected>().having(
          (outcome) => outcome.kind,
          'kind',
          UrgentCabinetSubmissionFailureKind.definitelyNotSubmitted,
        ),
      );

      final unavailable = _controller();
      expect(
        await unavailable.submitReview(
          review: _review(),
          source: productionSource,
        ),
        UrgentCabinetSubmitTransition.rejected,
      );
      expect(unavailable.requestState, isA<UrgentCabinetRequestDraft>());
      expect(
        unavailable.requestState,
        isNot(isA<UrgentCabinetRequestPendingDoctorResponse>()),
      );
    },
  );

  test(
    'pending stays pending until the local simulation is explicitly ended',
    () async {
      final controller = _controller();
      final review = _review();
      await controller.submitReview(
        review: review,
        source: const UrgentCabinetDevelopmentRequestSource(),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        controller.requestState,
        isA<UrgentCabinetRequestPendingDoctorResponse>(),
      );
      expect(controller.frozenReview, same(review));

      controller.endDevelopmentSimulation();
      expect(controller.requestState, isA<UrgentCabinetRequestDraft>());
      expect(controller.frozenReview, isNull);
      expect(controller.selectedDoctorId, isNull);
    },
  );
}
