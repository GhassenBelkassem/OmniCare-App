import '../../../core/storage/secure_token_store.dart';
import '../../auth/application/auth_role_family.dart';
import '../../scheduled_care/data/scheduled_care_failure.dart';
import '../../scheduled_care/domain/scheduled_care_models.dart';
import 'doctor_scheduled_care_models.dart';
import 'doctor_scheduled_care_repository.dart';

typedef SessionValue = String? Function();
typedef SessionFlag = bool Function();
typedef SessionTransition = Future<void> Function();

abstract interface class DoctorSessionAccessContract {
  Future<void> requireDoctorSession();
  Future<void> handleFailure(ScheduledCareFailure failure);
}

/// Reconciles the in-memory account with the origin-wide persisted web session
/// before any Doctor-only scheduled-care call can reach Dio.
class DoctorSessionAccess implements DoctorSessionAccessContract {
  DoctorSessionAccess({
    required SecureTokenStore tokenStore,
    required SessionFlag isAuthenticated,
    required SessionValue currentUserId,
    required SessionValue currentRole,
    required SessionTransition reconcilePersistedSession,
    required SessionTransition invalidateSession,
  }) : _tokenStore = tokenStore,
       _isAuthenticated = isAuthenticated,
       _currentUserId = currentUserId,
       _currentRole = currentRole,
       _reconcilePersistedSession = reconcilePersistedSession,
       _invalidateSession = invalidateSession;

  final SecureTokenStore _tokenStore;
  final SessionFlag _isAuthenticated;
  final SessionValue _currentUserId;
  final SessionValue _currentRole;
  final SessionTransition _reconcilePersistedSession;
  final SessionTransition _invalidateSession;

  String? _suspendedIdentity;
  Future<void>? _transitionInFlight;

  @override
  Future<void> requireDoctorSession() async {
    final userId = _currentUserId()?.trim() ?? '';
    final role = _currentRole();
    if (!_isAuthenticated() ||
        userId.isEmpty ||
        AuthRoles.familyOf(role) != AuthRoleFamily.doctor) {
      throw const ScheduledCareFailure.sessionChanged();
    }

    final identity = _identity(userId, role);
    if (_suspendedIdentity == identity) {
      throw const ScheduledCareFailure.sessionChanged();
    }
    if (_suspendedIdentity != null) _suspendedIdentity = null;

    final stored = await _tokenStore.readSession();
    final ownsStoredDoctorSession =
        stored != null &&
        stored.userId == userId &&
        AuthRoles.familyOf(stored.userRole) == AuthRoleFamily.doctor;
    if (ownsStoredDoctorSession) return;

    _suspendedIdentity = identity;
    await _transition(() async {
      if (stored == null) {
        await _invalidateSession();
      } else {
        await _reconcilePersistedSession();
      }
    });
    throw const ScheduledCareFailure.sessionChanged();
  }

  @override
  Future<void> handleFailure(ScheduledCareFailure failure) async {
    if (!failure.isUnauthorized && !failure.isForbidden) return;
    if (!_isAuthenticated()) return;

    final userId = _currentUserId()?.trim() ?? '';
    final role = _currentRole();
    final identity = userId.isEmpty ? null : _identity(userId, role);
    if (identity != null && _suspendedIdentity == identity) {
      await _transitionInFlight;
      return;
    }
    if (identity != null) _suspendedIdentity = identity;

    await _transition(() async {
      final stored = await _tokenStore.readSession();
      final persistedIdentityChanged =
          stored != null &&
          (stored.userId != userId ||
              AuthRoles.familyOf(stored.userRole) != AuthRoleFamily.doctor);
      if (persistedIdentityChanged) {
        await _reconcilePersistedSession();
        return;
      }

      // A repeated 401, or a core Doctor 403 under the same stored identity,
      // is not retried as a scheduling error. End the local session safely.
      await _tokenStore.clearSession();
      await _invalidateSession();
    });
  }

  Future<void> _transition(SessionTransition action) {
    final current = _transitionInFlight;
    if (current != null) return current;
    final started = action();
    _transitionInFlight = started;
    return started.whenComplete(() {
      _transitionInFlight = null;
    });
  }

  String _identity(String userId, String? role) =>
      '$userId|${AuthRoles.normalize(role) ?? ''}';
}

/// Applies the session gate to every Doctor repository operation and treats a
/// 403 from core Doctor endpoints as a workspace/session boundary failure.
class SessionGuardedDoctorScheduledCareRepository
    implements DoctorScheduledCareRepository {
  const SessionGuardedDoctorScheduledCareRepository({
    required DoctorScheduledCareRepository delegate,
    required DoctorSessionAccessContract sessionAccess,
  }) : _delegate = delegate,
       _sessionAccess = sessionAccess;

  final DoctorScheduledCareRepository _delegate;
  final DoctorSessionAccessContract _sessionAccess;

  Future<T> _run<T>(
    Future<T> Function() operation, {
    bool coreDoctorEndpoint = false,
  }) async {
    try {
      await _sessionAccess.requireDoctorSession();
      return await operation();
    } catch (error) {
      final failure = ScheduledCareFailure.from(error);
      if (failure.isUnauthorized ||
          failure.isSessionChanged ||
          (coreDoctorEndpoint && failure.isForbidden)) {
        await _sessionAccess.handleFailure(failure);
      }
      throw failure;
    }
  }

  @override
  Future<DoctorHomeSummary> getHomeSummary() =>
      _run(_delegate.getHomeSummary, coreDoctorEndpoint: true);

  @override
  Future<DoctorScheduledCareAgenda> getAgenda({
    required DateTime from,
    required DateTime to,
  }) => _run(
    () => _delegate.getAgenda(from: from, to: to),
    coreDoctorEndpoint: true,
  );

  @override
  Future<DoctorBookingRequest> getRequest(String requestId) =>
      _run(() => _delegate.getRequest(requestId), coreDoctorEndpoint: true);

  @override
  Future<DoctorBookingAcceptance> acceptRequest({
    required String requestId,
    required int expectedVersion,
    required String idempotencyKey,
  }) => _run(
    () => _delegate.acceptRequest(
      requestId: requestId,
      expectedVersion: expectedVersion,
      idempotencyKey: idempotencyKey,
    ),
    coreDoctorEndpoint: true,
  );

  @override
  Future<AvailabilityWindow> getProposalAvailability({
    required String doctorId,
    required String practiceLocationId,
    required DateTime from,
    required DateTime to,
  }) => _run(
    () => _delegate.getProposalAvailability(
      doctorId: doctorId,
      practiceLocationId: practiceLocationId,
      from: from,
      to: to,
    ),
  );

  @override
  Future<DoctorBookingRequest> proposeNewTime({
    required String requestId,
    required int expectedVersion,
    required String practiceLocationId,
    required ScheduledCareSlot proposedSlot,
    required String idempotencyKey,
  }) => _run(
    () => _delegate.proposeNewTime(
      requestId: requestId,
      expectedVersion: expectedVersion,
      practiceLocationId: practiceLocationId,
      proposedSlot: proposedSlot,
      idempotencyKey: idempotencyKey,
    ),
    coreDoctorEndpoint: true,
  );

  @override
  Future<DoctorBookingRequest> declineRequest({
    required String requestId,
    required int expectedVersion,
    required String reasonCode,
    required String idempotencyKey,
  }) => _run(
    () => _delegate.declineRequest(
      requestId: requestId,
      expectedVersion: expectedVersion,
      reasonCode: reasonCode,
      idempotencyKey: idempotencyKey,
    ),
    coreDoctorEndpoint: true,
  );

  @override
  Future<ConfirmedScheduledAppointment> getAppointment(String appointmentId) =>
      _run(() => _delegate.getAppointment(appointmentId));

  @override
  Future<ConfirmedScheduledAppointment> cancelAppointment({
    required String appointmentId,
    required int expectedVersion,
    required String reasonCode,
    required String idempotencyKey,
  }) => _run(
    () => _delegate.cancelAppointment(
      appointmentId: appointmentId,
      expectedVersion: expectedVersion,
      reasonCode: reasonCode,
      idempotencyKey: idempotencyKey,
    ),
  );
}
