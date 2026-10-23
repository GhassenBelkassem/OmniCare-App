import 'dart:async';

import 'package:flutter/foundation.dart';

enum UrgentCabinetDoctorDecisionType { accepted, declined, unavailable }

enum UrgentCabinetDecisionProvenance { developmentFixture, service }

/// Identity-bearing post-submission decision for one P4 urgent CABINET attempt.
///
/// [serverRequestReference] is deliberately optional. Development fixtures must
/// never invent a value for it.
@immutable
class UrgentCabinetDoctorDecisionEvent {
  const UrgentCabinetDoctorDecisionEvent({
    required this.accountId,
    required this.localAttemptGeneration,
    required this.doctorId,
    required this.cabinetId,
    required this.type,
    required this.provenance,
    this.serverRequestReference,
  });

  final String accountId;
  final int localAttemptGeneration;
  final String doctorId;
  final String cabinetId;
  final UrgentCabinetDoctorDecisionType type;
  final UrgentCabinetDecisionProvenance provenance;
  final String? serverRequestReference;

  bool get isDevelopmentFixture =>
      provenance == UrgentCabinetDecisionProvenance.developmentFixture;
}

/// Injectable P4-only boundary for decisions received after submission.
///
/// This source owns no request state. The route-scoped flow controller remains
/// the authority that validates account, attempt, doctor and cabinet identity.
abstract class UrgentCabinetRequestDecisionSource {
  const UrgentCabinetRequestDecisionSource();

  bool get isDevelopmentFixture;

  Stream<UrgentCabinetDoctorDecisionEvent> get decisions;

  void dispose();
}

/// Explicit debug/test adapter used by a dedicated preview harness or tests.
///
/// Inject one instance into the urgent-cabinet flow shell, wait until the request is
/// pending, then deliberately call [emitAccepted], [emitDeclined] or
/// [emitUnavailable] with the identity held by that pending state. Nothing is
/// emitted automatically.
class UrgentCabinetDevelopmentDecisionSource
    extends UrgentCabinetRequestDecisionSource {
  UrgentCabinetDevelopmentDecisionSource();

  final StreamController<UrgentCabinetDoctorDecisionEvent> _controller =
      StreamController<UrgentCabinetDoctorDecisionEvent>.broadcast(sync: true);
  bool _disposed = false;

  @override
  bool get isDevelopmentFixture => true;

  @override
  Stream<UrgentCabinetDoctorDecisionEvent> get decisions => _controller.stream;

  void emitAccepted({
    required String accountId,
    required int localAttemptGeneration,
    required String doctorId,
    required String cabinetId,
  }) {
    _emit(
      UrgentCabinetDoctorDecisionEvent(
        accountId: accountId,
        localAttemptGeneration: localAttemptGeneration,
        doctorId: doctorId,
        cabinetId: cabinetId,
        type: UrgentCabinetDoctorDecisionType.accepted,
        provenance: UrgentCabinetDecisionProvenance.developmentFixture,
      ),
    );
  }

  void emitDeclined({
    required String accountId,
    required int localAttemptGeneration,
    required String doctorId,
    required String cabinetId,
  }) {
    _emit(
      UrgentCabinetDoctorDecisionEvent(
        accountId: accountId,
        localAttemptGeneration: localAttemptGeneration,
        doctorId: doctorId,
        cabinetId: cabinetId,
        type: UrgentCabinetDoctorDecisionType.declined,
        provenance: UrgentCabinetDecisionProvenance.developmentFixture,
      ),
    );
  }

  void emitUnavailable({
    required String accountId,
    required int localAttemptGeneration,
    required String doctorId,
    required String cabinetId,
  }) {
    _emit(
      UrgentCabinetDoctorDecisionEvent(
        accountId: accountId,
        localAttemptGeneration: localAttemptGeneration,
        doctorId: doctorId,
        cabinetId: cabinetId,
        type: UrgentCabinetDoctorDecisionType.unavailable,
        provenance: UrgentCabinetDecisionProvenance.developmentFixture,
      ),
    );
  }

  @visibleForTesting
  void emit(UrgentCabinetDoctorDecisionEvent event) => _emit(event);

  void _emit(UrgentCabinetDoctorDecisionEvent event) {
    if (!kDebugMode || _disposed) return;
    if (!event.isDevelopmentFixture || event.serverRequestReference != null) {
      throw ArgumentError(
        'Development decisions require fixture provenance and no server ID.',
      );
    }
    _controller.add(event);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_controller.close());
  }
}

class UrgentCabinetUnavailableDecisionSource
    extends UrgentCabinetRequestDecisionSource {
  const UrgentCabinetUnavailableDecisionSource();

  @override
  bool get isDevelopmentFixture => false;

  @override
  Stream<UrgentCabinetDoctorDecisionEvent> get decisions =>
      const Stream.empty();

  @override
  void dispose() {}
}

abstract final class UrgentCabinetRequestDecisionSources {
  static UrgentCabinetRequestDecisionSource forCurrentBuild() {
    return forBuild(enableDevelopmentFixtures: kDebugMode);
  }

  @visibleForTesting
  static UrgentCabinetRequestDecisionSource forBuild({
    required bool enableDevelopmentFixtures,
  }) {
    return enableDevelopmentFixtures
        ? UrgentCabinetDevelopmentDecisionSource()
        : const UrgentCabinetUnavailableDecisionSource();
  }
}
