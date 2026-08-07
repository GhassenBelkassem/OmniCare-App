import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../auth/application/auth_role_family.dart';
import '../data/clinic_failure.dart';
import '../data/clinic_models.dart';
import '../data/clinic_repository.dart';
import '../storage/clinic_selection_store.dart';

/// Where the clinic shell should send an authenticated clinic professional.
enum ClinicDestination {
  loading,
  selection,
  professionalHome,
  webWorkspace,
  accessUnavailable,
  error,
}

/// Owns the whole Phase 1 clinic access context:
/// access family -> memberships -> selected clinic -> bootstrap -> destination.
///
/// It never owns, reads or copies authentication tokens; the shared
/// [AppHttpClient] pipeline keeps handling 401, refresh and session
/// invalidation.
class ClinicContextController extends ChangeNotifier {
  ClinicContextController({
    required ClinicRepository repository,
    ClinicSelectionStore? selectionStore,
    Duration resumeRefreshCooldown = const Duration(seconds: 30),
    DateTime Function()? clock,
  }) : _repository = repository,
       _selectionStore = selectionStore ?? ClinicSelectionStore(),
       _resumeRefreshCooldown = resumeRefreshCooldown,
       _clock = clock ?? DateTime.now;

  final ClinicRepository _repository;
  final ClinicSelectionStore _selectionStore;
  final Duration _resumeRefreshCooldown;
  final DateTime Function() _clock;

  ClinicAccessFamily? _accessFamily;
  List<ClinicMembershipSummary> _activeMemberships = const [];
  List<ClinicMembershipSummary> _unavailableMemberships = const [];
  String? _selectedClinicId;
  ClinicBootstrap? _bootstrap;
  ClinicFailure? _failure;
  bool _loading = false;
  bool _initialized = false;
  bool _disposed = false;
  String? _globalRole;
  DateTime? _lastCompletedRefreshAt;

  int _generation = 0;
  CancelToken? _inFlightToken;
  Future<void>? _initializationFuture;

  ClinicAccessFamily? get accessFamily => _accessFamily;
  List<ClinicMembershipSummary> get activeMemberships => _activeMemberships;
  List<ClinicMembershipSummary> get unavailableMemberships =>
      _unavailableMemberships;
  String? get selectedClinicId => _selectedClinicId;
  ClinicBootstrap? get bootstrap => _bootstrap;
  ClinicFailure? get failure => _failure;
  bool get isLoading => _loading;
  bool get isInitialized => _initialized;
  bool get canSwitchClinic => _activeMemberships.length > 1;

  ClinicMembershipSummary? get selectedMembership {
    final id = _selectedClinicId;
    if (id == null) return null;
    for (final membership in _activeMemberships) {
      if (membership.clinicId == id) return membership;
    }
    return null;
  }

  ClinicDestination get destination {
    final failure = _failure;
    if (failure != null) {
      return failure.isTerminalAccessProblem
          ? ClinicDestination.accessUnavailable
          : ClinicDestination.error;
    }

    final bootstrap = _bootstrap;
    if (bootstrap != null) {
      final role = bootstrap.membership.professionalRole;
      if (role.isMobileOperational) return ClinicDestination.professionalHome;
      if (role.isWebFirst) return ClinicDestination.webWorkspace;
      return ClinicDestination.accessUnavailable;
    }

    if (_loading || !_initialized) return ClinicDestination.loading;
    if (_accessFamily != ClinicAccessFamily.clinic) {
      return ClinicDestination.accessUnavailable;
    }
    if (_activeMemberships.isEmpty) return ClinicDestination.accessUnavailable;
    return ClinicDestination.selection;
  }

  /// Entry point used by the clinic shell after authentication.
  ///
  /// Only `CLINIC_*` global roles ever reach the network. Concurrent calls
  /// share the same in-flight initialization.
  Future<void> initializeForAuthenticatedUser({
    required String? globalRole,
    bool force = false,
  }) {
    final normalizedRole = AuthRoles.normalize(globalRole);

    if (!AuthRoles.isClinic(normalizedRole)) {
      // Patient, doctor and unsupported accounts must never call clinic APIs.
      _resetState();
      _globalRole = normalizedRole;
      _failure = ClinicFailure.notAClinicAccount;
      _initialized = true;
      _notify();
      return Future<void>.value();
    }

    final pending = _initializationFuture;
    if (pending != null && !force) return pending;

    _globalRole = normalizedRole;
    final started = _runInitialization();
    _initializationFuture = started;
    return started.whenComplete(() {
      if (identical(_initializationFuture, started)) {
        _initializationFuture = null;
      }
    });
  }

  /// Selects an active clinic and loads its bootstrap.
  Future<void> selectClinic(String clinicId) async {
    final id = clinicId.trim();
    if (id.isEmpty) return;

    final membership = _findActiveMembership(id);
    if (membership == null) {
      // The stored or tapped clinic is not an active membership anymore.
      await _selectionStore.clear();
      _fail(ClinicFailure.noActiveMembership, generation: _generation);
      return;
    }

    final generation = _beginRequest();
    _selectedClinicId = id;
    _bootstrap = null;
    _failure = null;
    _loading = true;
    _notify();

    await _loadBootstrap(id, generation);
    if (generation != _generation) return;
    _loading = false;
    _initialized = true;
    _lastCompletedRefreshAt = _clock();
    _notify();
  }

  /// Switches to another clinic, clearing the previous scoped context first.
  Future<void> switchClinic(String clinicId) => selectClinic(clinicId);

  /// Returns to the clinic selector, dropping the currently scoped context.
  /// Only meaningful when more than one active membership exists.
  void requestClinicSelection() {
    if (!canSwitchClinic) return;
    _beginRequest();
    _selectedClinicId = null;
    _bootstrap = null;
    _failure = null;
    _loading = false;
    _notify();
  }

  /// Reloads only the bootstrap of the currently selected clinic.
  Future<void> refreshBootstrap() async {
    final id = _selectedClinicId;
    if (id == null) return;
    await selectClinic(id);
  }

  /// Retries the full resolution chain after a failure.
  Future<void> retry() {
    return initializeForAuthenticatedUser(globalRole: _globalRole, force: true);
  }

  /// App-resume revalidation, throttled to avoid refresh storms.
  Future<void> refreshOnResume() {
    if (!AuthRoles.isClinic(_globalRole)) return Future<void>.value();
    if (_loading || _initializationFuture != null) return Future<void>.value();

    final last = _lastCompletedRefreshAt;
    if (last != null && _clock().difference(last) < _resumeRefreshCooldown) {
      return Future<void>.value();
    }
    return initializeForAuthenticatedUser(globalRole: _globalRole, force: true);
  }

  /// Clears every clinic context value and the secure clinic hint. Called on
  /// logout and whenever the authentication session becomes invalid.
  Future<void> clear() async {
    _beginRequest();
    _resetState();
    _globalRole = null;
    _initializationFuture = null;
    _notify();
    await _selectionStore.clear();
  }

  Future<void> _runInitialization() async {
    final generation = _beginRequest();
    _accessFamily = null;
    _activeMemberships = const [];
    _unavailableMemberships = const [];
    _bootstrap = null;
    _failure = null;
    _loading = true;
    _notify();

    try {
      final family = await _repository.resolveAccessFamily(
        cancelToken: _inFlightToken,
      );
      if (generation != _generation) return;
      _accessFamily = family;

      if (family != ClinicAccessFamily.clinic) {
        _fail(ClinicFailure.notAClinicAccount, generation: generation);
        return;
      }

      final directory = await _repository.loadMemberships(
        cancelToken: _inFlightToken,
      );
      if (generation != _generation) return;
      _activeMemberships = directory.activeMemberships;
      _unavailableMemberships = directory.unavailableMemberships;

      if (!directory.hasActiveMemberships) {
        _selectedClinicId = null;
        await _selectionStore.clear();
        if (generation != _generation) return;
        _fail(ClinicFailure.noActiveMembership, generation: generation);
        return;
      }

      // A stored hint is only a shortcut. It is revalidated every time and
      // deleted as soon as it stops matching an active membership.
      final hint = await _selectionStore.readSelectedClinicId();
      if (generation != _generation) return;
      String? validatedHint;
      if (hint != null) {
        if (directory.findActive(hint) != null) {
          validatedHint = hint;
        } else {
          await _selectionStore.clear();
          if (generation != _generation) return;
        }
      }

      final target = directory.activeMemberships.length == 1
          ? directory.activeMemberships.single.clinicId
          : validatedHint;

      if (target == null) {
        _selectedClinicId = null;
        _bootstrap = null;
      } else {
        _selectedClinicId = target;
        await _loadBootstrap(target, generation);
        if (generation != _generation) return;
      }
    } catch (error) {
      if (generation != _generation) return;
      _failure = ClinicFailure.from(error);
    } finally {
      if (generation == _generation) {
        _loading = false;
        _initialized = true;
        _lastCompletedRefreshAt = _clock();
        _notify();
      }
    }
  }

  Future<void> _loadBootstrap(String clinicId, int generation) async {
    try {
      final bootstrap = await _repository.loadBootstrap(
        clinicId,
        cancelToken: _inFlightToken,
      );

      // Stale-response protection: a newer generation or a newer clinic
      // selection always wins over an older in-flight bootstrap.
      if (generation != _generation) return;
      if (_selectedClinicId != clinicId) return;

      if (bootstrap.clinic.clinicId != clinicId) {
        _failure = ClinicFailure.invalidResponse;
        _bootstrap = null;
        return;
      }

      if (!_isRoleConsistentWithGlobalRole(
        bootstrap.membership.professionalRole,
      )) {
        _bootstrap = null;
        _failure = ClinicFailure.roleMismatch;
        return;
      }

      if (!bootstrap.clinic.clinicStatus.isActive) {
        _bootstrap = null;
        _failure = const ClinicFailure(
          kind: ClinicFailureKind.clinicUnavailable,
          message: 'This clinic is not active.',
          retryable: false,
          diagnosticCode: 'CLINIC_NOT_ACTIVE',
        );
        return;
      }

      if (!bootstrap.membership.membershipStatus.isActive) {
        _bootstrap = null;
        _failure = const ClinicFailure(
          kind: ClinicFailureKind.membershipUnavailable,
          message: 'Access to this clinic is currently unavailable.',
          retryable: false,
          diagnosticCode: 'CLINIC_MEMBERSHIP_REQUIRED',
        );
        return;
      }

      _bootstrap = bootstrap;
      _failure = null;
      await _selectionStore.saveSelectedClinicId(clinicId);
    } catch (error) {
      if (generation != _generation) return;
      if (_selectedClinicId != clinicId) return;
      _bootstrap = null;
      _failure = ClinicFailure.from(error);
    }
  }

  bool _isRoleConsistentWithGlobalRole(ClinicProfessionalRole role) {
    final globalRole = _globalRole;
    if (globalRole == null) return false;
    return role.wireValue == globalRole;
  }

  ClinicMembershipSummary? _findActiveMembership(String clinicId) {
    for (final membership in _activeMemberships) {
      if (membership.clinicId == clinicId) return membership;
    }
    return null;
  }

  int _beginRequest() {
    _generation++;
    final previous = _inFlightToken;
    if (previous != null && !previous.isCancelled) {
      previous.cancel('clinic-context-superseded');
    }
    _inFlightToken = CancelToken();
    return _generation;
  }

  void _fail(ClinicFailure failure, {required int generation}) {
    if (generation != _generation) return;
    _bootstrap = null;
    _failure = failure;
    _loading = false;
    _initialized = true;
    _notify();
  }

  void _resetState() {
    _accessFamily = null;
    _activeMemberships = const [];
    _unavailableMemberships = const [];
    _selectedClinicId = null;
    _bootstrap = null;
    _failure = null;
    _loading = false;
    _initialized = false;
    _lastCompletedRefreshAt = null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    final token = _inFlightToken;
    if (token != null && !token.isCancelled) {
      token.cancel('clinic-context-disposed');
    }
    super.dispose();
  }
}
