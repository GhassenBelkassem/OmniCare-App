import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../workspace/doctor_workspace_bootstrap.dart';
import 'doctor_home_location_provider.dart';
import 'doctor_home_presence_repository.dart';
import 'doctor_urgent_runtime_controller.dart';

enum DoctorHomePresenceState {
  detached,
  inactive,
  permissionRequired,
  permissionDenied,
  serviceDisabled,
  acquiring,
  publishing,
  updated,
  expired,
  inaccurate,
  invalid,
  outOfOrder,
  paused,
  unavailable,
  unsupported,
  failure,
}

class DoctorHomePresenceController extends ChangeNotifier {
  DoctorHomePresenceController({
    required DoctorHomePresenceRepositoryContract repository,
    required DoctorHomeLocationProvider locationProvider,
    required DoctorUrgentRuntimeController runtimeController,
    this.onSessionRejected,
    this.publicationInterval = const Duration(seconds: 60),
    this.retryDelay = const Duration(seconds: 2),
    this.clientMaximumObservationAge = const Duration(seconds: 90),
    this.maximumFutureSkew = const Duration(seconds: 30),
    this.maximumAccuracyMeters = 100,
    DateTime Function()? clock,
  }) : _repository = repository,
       _locationProvider = locationProvider,
       _runtimeController = runtimeController,
       _clock = clock ?? DateTime.now;

  final DoctorHomePresenceRepositoryContract _repository;
  final DoctorHomeLocationProvider _locationProvider;
  final DoctorUrgentRuntimeController _runtimeController;
  final VoidCallback? onSessionRejected;
  final Duration publicationInterval;
  final Duration retryDelay;
  final Duration clientMaximumObservationAge;
  final Duration maximumFutureSkew;
  final double maximumAccuracyMeters;
  final DateTime Function() _clock;

  DoctorHomePresenceState _state = DoctorHomePresenceState.detached;
  String? _doctorId;
  bool _hasHomeCapability = false;
  bool _homeIntentEnabled = false;
  bool _foreground = true;
  bool _publicationRequested = false;
  bool _operationInFlight = false;
  int _generation = 0;
  bool _disposed = false;
  String? _message;
  DoctorHomeLocationPresence? _serverPresence;
  DoctorHomePresenceUpdate? _ambiguousUpdate;
  DateTime? _lastAcceptedObservedAt;
  Timer? _publicationTimer;
  Timer? _expiryTimer;
  CancelToken? _uploadToken;

  DoctorHomePresenceState get state => _state;
  String? get message => _message;
  DoctorHomeLocationPresence? get serverPresence => _serverPresence;
  bool get isPublishing => _operationInFlight;
  bool get isForegroundPublicationActive =>
      _publicationRequested && _foreground && _homeIntentEnabled;
  bool get canStart =>
      !_operationInFlight &&
      _foreground &&
      _hasHomeCapability &&
      _homeIntentEnabled &&
      _locationProvider.isSupported;

  String get statusLabel => switch (_state) {
    DoctorHomePresenceState.detached ||
    DoctorHomePresenceState.inactive => 'Position requise',
    DoctorHomePresenceState.permissionRequired ||
    DoctorHomePresenceState.permissionDenied =>
      'Autorisation de localisation nécessaire',
    DoctorHomePresenceState.serviceDisabled => 'Service GPS désactivé',
    DoctorHomePresenceState.acquiring => 'Recherche de position…',
    DoctorHomePresenceState.publishing => 'Mise à jour sécurisée…',
    DoctorHomePresenceState.updated => 'Position actualisée',
    DoctorHomePresenceState.expired => 'Position expirée',
    DoctorHomePresenceState.inaccurate => 'Précision insuffisante',
    DoctorHomePresenceState.invalid => 'Position non valide',
    DoctorHomePresenceState.outOfOrder => 'Position serveur plus récente',
    DoctorHomePresenceState.paused => 'Publication en pause',
    DoctorHomePresenceState.unavailable ||
    DoctorHomePresenceState.unsupported ||
    DoctorHomePresenceState.failure => 'Localisation indisponible',
  };

  void attachWorkspace(DoctorWorkspaceBootstrap workspace) {
    final changed = _doctorId != workspace.doctorId;
    if (changed) {
      _reset(clearIdentity: false);
      _doctorId = workspace.doctorId;
    }
    _hasHomeCapability = workspace.hasUrgentHome;
    synchronizeRuntime(
      runtimeState: workspace.runtime == null
          ? DoctorUrgentRuntimeState.loading
          : DoctorUrgentRuntimeState.ready,
      snapshot: workspace.runtime,
    );
  }

  void synchronizeRuntime({
    required DoctorUrgentRuntimeState runtimeState,
    required DoctorUrgentRuntimeSnapshot? snapshot,
  }) {
    if (_doctorId == null) return;
    if (runtimeState == DoctorUrgentRuntimeState.unavailable) {
      _stopPublisher();
      _homeIntentEnabled = false;
      _state = DoctorHomePresenceState.unavailable;
      _message = 'La présence HOME n’est pas disponible sur cet environnement.';
      _notify();
      return;
    }
    if (snapshot == null) return;
    _homeIntentEnabled = snapshot.homeEnabled;
    _serverPresence = snapshot.homeLocationPresence;
    if (!_hasHomeCapability || !_homeIntentEnabled) {
      _stopPublisher();
      _state = DoctorHomePresenceState.inactive;
      _message = !_hasHomeCapability
          ? 'Le service Urgence à domicile n’est pas configuré.'
          : 'Activez d’abord votre intention HOME. Le GPS ne démarre jamais automatiquement.';
      _notify();
      return;
    }
    if (!_locationProvider.isSupported) {
      _stopPublisher();
      _state = DoctorHomePresenceState.unsupported;
      _message =
          'La présence HOME est certifiée uniquement sur Android et iOS.';
      _notify();
      return;
    }
    final presence = snapshot.homeLocationPresence;
    if (!_publicationRequested && presence != null) {
      _applyServerPresence(presence);
    }
    _notify();
  }

  Future<void> startOrRefresh() async {
    if (!canStart) return;
    _publicationRequested = true;
    await _acquireAndPublish(requestPermission: true);
  }

  void stopForRuntimeOff() {
    _stopPublisher();
    _homeIntentEnabled = false;
    _state = DoctorHomePresenceState.inactive;
    _message =
        'Intention HOME désactivée. Aucune nouvelle position ne sera collectée.';
    _notify();
  }

  void pauseForBackground() {
    if (!_foreground) return;
    _foreground = false;
    final wasPublishing = _publicationRequested;
    _stopPublisher();
    if (wasPublishing || _homeIntentEnabled) {
      _state = DoctorHomePresenceState.paused;
      _message =
          'Publication interrompue hors premier plan. Relancez-la explicitement à votre retour.';
    }
    _notify();
  }

  void resumeForeground() {
    _foreground = true;
    _publicationRequested = false;
    if (_homeIntentEnabled) {
      _state = DoctorHomePresenceState.paused;
      _message =
          'État serveur actualisé. Touchez le bouton pour reprendre la position.';
    }
    _notify();
  }

  Future<void> _acquireAndPublish({required bool requestPermission}) async {
    final doctorId = _doctorId;
    if (doctorId == null || _operationInFlight || !canStart) return;
    final generation = ++_generation;
    _operationInFlight = true;
    _publicationTimer?.cancel();
    _publicationTimer = null;
    try {
      if (!_locationProvider.isSupported) {
        _stopWith(
          DoctorHomePresenceState.unsupported,
          'La présence HOME est certifiée uniquement sur Android et iOS.',
        );
        return;
      }
      if (!await _locationProvider.isServiceEnabled()) {
        if (!_isCurrent(generation, doctorId)) return;
        _stopWith(
          DoctorHomePresenceState.serviceDisabled,
          'Activez le service de localisation de l’appareil.',
        );
        return;
      }
      var permission = await _locationProvider.checkPermission();
      if (!_isCurrent(generation, doctorId)) return;
      if (permission == DoctorForegroundLocationPermission.denied &&
          requestPermission) {
        permission = await _locationProvider.requestForegroundPermission();
      }
      if (!_isCurrent(generation, doctorId)) return;
      if (permission != DoctorForegroundLocationPermission.granted) {
        _stopWith(
          permission == DoctorForegroundLocationPermission.denied
              ? DoctorHomePresenceState.permissionRequired
              : DoctorHomePresenceState.permissionDenied,
          permission == DoctorForegroundLocationPermission.deniedForever
              ? 'Autorisez la localisation pendant l’utilisation dans les réglages de l’appareil.'
              : 'Une autorisation de localisation au premier plan est nécessaire.',
        );
        return;
      }

      final retry = _ambiguousUpdate;
      if (retry != null && _isFresh(retry.observedAt, _clock().toUtc())) {
        _state = DoctorHomePresenceState.publishing;
        _message = 'Vérification de la dernière mesure…';
        _notify();
        await _publish(retry, generation, doctorId);
        return;
      }
      _ambiguousUpdate = null;
      _state = DoctorHomePresenceState.acquiring;
      _message = null;
      _notify();
      final observation = await _locationProvider.currentObservation();
      if (!_isCurrent(generation, doctorId)) return;
      final validation = _validate(observation);
      if (validation != null) {
        _stopWith(validation.$1, validation.$2);
        return;
      }
      final update = DoctorHomePresenceUpdate(
        updateId: _uuidV4(),
        observedAt: observation.observedAt.toUtc(),
        latitude: observation.latitude,
        longitude: observation.longitude,
        horizontalAccuracyMeters: observation.horizontalAccuracyMeters,
      );
      _state = DoctorHomePresenceState.publishing;
      _notify();
      await _publish(update, generation, doctorId);
    } catch (error) {
      if (!_isCurrent(generation, doctorId)) return;
      _stopWith(
        DoctorHomePresenceState.failure,
        error is TimeoutException
            ? 'La recherche de position a expiré. Réessayez au premier plan.'
            : 'La position n’a pas pu être obtenue.',
      );
    } finally {
      if (!_disposed) {
        _operationInFlight = false;
        if (_isCurrent(generation, doctorId)) {
          _scheduleNextPublication();
        }
        _notify();
      }
    }
  }

  Future<void> _publish(
    DoctorHomePresenceUpdate update,
    int generation,
    String doctorId,
  ) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final token = _uploadToken = CancelToken();
      try {
        final accepted = await _repository.publish(update, cancelToken: token);
        if (!_isCurrent(generation, doctorId) || token.isCancelled) return;
        _accept(accepted, update.observedAt);
        await _runtimeController.refresh();
        return;
      } catch (error) {
        if (!_isCurrent(generation, doctorId) ||
            (error is DioException && CancelToken.isCancel(error))) {
          return;
        }
        final failure = DoctorHomePresenceFailure.from(error);
        if (failure.kind == DoctorHomePresenceFailureKind.sessionRejected) {
          _stopWith(DoctorHomePresenceState.failure, failure.message);
          onSessionRejected?.call();
          return;
        }
        if (failure.kind == DoctorHomePresenceFailureKind.runtimeUnavailable) {
          _stopWith(DoctorHomePresenceState.unavailable, failure.message);
          return;
        }
        if (failure.kind == DoctorHomePresenceFailureKind.outOfOrder) {
          await _runtimeController.refresh();
          if (!_isCurrent(generation, doctorId)) return;
          _ambiguousUpdate = null;
          _publicationRequested = false;
          _state = DoctorHomePresenceState.outOfOrder;
          _message = failure.message;
          return;
        }
        final retryable =
            failure.kind == DoctorHomePresenceFailureKind.network ||
            failure.kind == DoctorHomePresenceFailureKind.dependencyUnavailable;
        if (retryable) {
          _ambiguousUpdate = update;
          await _runtimeController.refresh();
          if (!_isCurrent(generation, doctorId)) return;
          final reconciled = _runtimeController.snapshot?.homeLocationPresence;
          if (reconciled?.updateId == update.updateId) {
            _accept(reconciled!, update.observedAt);
            return;
          }
          if (attempt == 0 &&
              _isFresh(update.observedAt, _clock().toUtc()) &&
              _publicationRequested &&
              _foreground &&
              _homeIntentEnabled) {
            await Future<void>.delayed(retryDelay);
            if (!_isCurrent(generation, doctorId)) return;
            continue;
          }
        }
        _publicationRequested = false;
        _state = switch (failure.kind) {
          DoctorHomePresenceFailureKind.staleObservation =>
            DoctorHomePresenceState.expired,
          DoctorHomePresenceFailureKind.inaccurateObservation =>
            DoctorHomePresenceState.inaccurate,
          DoctorHomePresenceFailureKind.invalidObservation =>
            DoctorHomePresenceState.invalid,
          DoctorHomePresenceFailureKind.dependencyUnavailable ||
          DoctorHomePresenceFailureKind.runtimeUnavailable =>
            DoctorHomePresenceState.unavailable,
          _ => DoctorHomePresenceState.failure,
        };
        _message = failure.message;
        return;
      } finally {
        if (identical(_uploadToken, token)) _uploadToken = null;
      }
    }
  }

  (DoctorHomePresenceState, String)? _validate(
    DoctorDeviceLocationObservation value,
  ) {
    final now = _clock().toUtc();
    if (value.isSimulated) {
      return (
        DoctorHomePresenceState.invalid,
        'Une position simulée ne peut pas servir de présence opérationnelle.',
      );
    }
    if (!value.latitude.isFinite ||
        value.latitude < -90 ||
        value.latitude > 90 ||
        !value.longitude.isFinite ||
        value.longitude < -180 ||
        value.longitude > 180) {
      return (
        DoctorHomePresenceState.invalid,
        'La mesure de position n’est pas valide.',
      );
    }
    if (!value.horizontalAccuracyMeters.isFinite ||
        value.horizontalAccuracyMeters <= 0 ||
        value.horizontalAccuracyMeters > maximumAccuracyMeters) {
      return (
        DoctorHomePresenceState.inaccurate,
        'La précision de cette mesure est insuffisante.',
      );
    }
    final observedAt = value.observedAt.toUtc();
    if (!_isFresh(observedAt, now)) {
      return (
        DoctorHomePresenceState.expired,
        'La mesure de position est trop ancienne.',
      );
    }
    if (observedAt.isAfter(now.add(maximumFutureSkew))) {
      return (
        DoctorHomePresenceState.invalid,
        'L’horodatage de la position n’est pas plausible.',
      );
    }
    final previous = _lastAcceptedObservedAt;
    if (previous != null && !observedAt.isAfter(previous)) {
      return (
        DoctorHomePresenceState.outOfOrder,
        'Une mesure plus récente a déjà été acceptée.',
      );
    }
    return null;
  }

  bool _isFresh(DateTime observedAt, DateTime now) =>
      !observedAt.isBefore(now.subtract(clientMaximumObservationAge));

  void _accept(DoctorHomeLocationPresence presence, DateTime observedAt) {
    _serverPresence = presence;
    _lastAcceptedObservedAt = observedAt;
    _ambiguousUpdate = null;
    _state = presence.status == DoctorLocationPresenceStatus.available
        ? DoctorHomePresenceState.updated
        : DoctorHomePresenceState.failure;
    _message = presence.status == DoctorLocationPresenceStatus.available
        ? 'Position reçue par le serveur. L’admissibilité reste vérifiée demande par demande.'
        : 'Le serveur n’a pas confirmé une présence opérationnelle fraîche.';
    _scheduleExpiry(presence);
  }

  void _applyServerPresence(DoctorHomeLocationPresence presence) {
    _serverPresence = presence;
    _state = switch (presence.status) {
      DoctorLocationPresenceStatus.available => DoctorHomePresenceState.updated,
      DoctorLocationPresenceStatus.missing => DoctorHomePresenceState.inactive,
      DoctorLocationPresenceStatus.stale => DoctorHomePresenceState.expired,
      DoctorLocationPresenceStatus.qualityInsufficient =>
        DoctorHomePresenceState.inaccurate,
      DoctorLocationPresenceStatus.unavailable =>
        DoctorHomePresenceState.unavailable,
    };
    _message = switch (presence.status) {
      DoctorLocationPresenceStatus.available =>
        'Une position fraîche est enregistrée côté serveur.',
      DoctorLocationPresenceStatus.missing =>
        'Touchez le bouton pour autoriser et transmettre une position.',
      DoctorLocationPresenceStatus.stale =>
        'La dernière position serveur a expiré.',
      DoctorLocationPresenceStatus.qualityInsufficient =>
        'La dernière mesure serveur manque de précision.',
      DoctorLocationPresenceStatus.unavailable =>
        'Le service de présence serveur est indisponible.',
    };
    _scheduleExpiry(presence);
  }

  void _scheduleNextPublication() {
    _publicationTimer?.cancel();
    if (!_publicationRequested ||
        !_foreground ||
        !_homeIntentEnabled ||
        _disposed) {
      return;
    }
    _publicationTimer = Timer(
      publicationInterval,
      () => unawaited(_acquireAndPublish(requestPermission: false)),
    );
  }

  void _scheduleExpiry(DoctorHomeLocationPresence presence) {
    _expiryTimer?.cancel();
    final expiresAt = presence.expiresAt;
    if (expiresAt == null) return;
    final delay = expiresAt.difference(_clock().toUtc());
    if (delay <= Duration.zero) {
      _state = DoctorHomePresenceState.expired;
      return;
    }
    final updateId = presence.updateId;
    _expiryTimer = Timer(delay, () {
      if (_disposed || _serverPresence?.updateId != updateId) return;
      _state = DoctorHomePresenceState.expired;
      _message = 'La dernière position serveur a expiré.';
      _notify();
    });
  }

  void _stopWith(DoctorHomePresenceState state, String message) {
    _stopPublisher();
    _state = state;
    _message = message;
    _notify();
  }

  void _stopPublisher() {
    _generation++;
    _publicationRequested = false;
    _publicationTimer?.cancel();
    _publicationTimer = null;
    _uploadToken?.cancel('HOME presence publication stopped.');
    _uploadToken = null;
  }

  void clear() {
    _reset(clearIdentity: true);
    _notify();
  }

  void _reset({required bool clearIdentity}) {
    _stopPublisher();
    _expiryTimer?.cancel();
    _expiryTimer = null;
    if (clearIdentity) _doctorId = null;
    _hasHomeCapability = false;
    _homeIntentEnabled = false;
    _message = null;
    _serverPresence = null;
    _ambiguousUpdate = null;
    _lastAcceptedObservedAt = null;
    _state = DoctorHomePresenceState.detached;
  }

  bool _isCurrent(int generation, String doctorId) =>
      !_disposed &&
      generation == _generation &&
      _doctorId == doctorId &&
      _foreground &&
      _homeIntentEnabled;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  static String _uuidV4() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0'));
    final value = hex.join();
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }

  @override
  void dispose() {
    _disposed = true;
    _reset(clearIdentity: true);
    super.dispose();
  }
}
