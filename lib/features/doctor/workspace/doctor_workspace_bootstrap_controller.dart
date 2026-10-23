import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'doctor_workspace_bootstrap.dart';
import 'doctor_workspace_bootstrap_repository.dart';

enum DoctorWorkspaceBootstrapState { initial, loading, ready, failure }

class DoctorWorkspaceBootstrapController extends ChangeNotifier {
  DoctorWorkspaceBootstrapController({
    required DoctorWorkspaceBootstrapRepositoryContract repository,
  }) : _repository = repository;

  final DoctorWorkspaceBootstrapRepositoryContract _repository;

  DoctorWorkspaceBootstrapState _state = DoctorWorkspaceBootstrapState.initial;
  DoctorWorkspaceBootstrap? _workspace;
  String? _doctorId;
  String? _errorMessage;
  CancelToken? _token;
  int _generation = 0;
  bool _disposed = false;

  DoctorWorkspaceBootstrapState get state => _state;
  DoctorWorkspaceBootstrap? get workspace => _workspace;
  String? get doctorId => _doctorId;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == DoctorWorkspaceBootstrapState.loading;

  Future<void> load(String doctorId) =>
      _load(doctorId, preserveCurrentWorkspace: false);

  Future<void> _load(
    String doctorId, {
    required bool preserveCurrentWorkspace,
  }) async {
    final id = doctorId.trim();
    if (id.isEmpty) throw ArgumentError.value(doctorId, 'doctorId');
    final canPreserve =
        preserveCurrentWorkspace &&
        _doctorId == id &&
        _workspace?.doctorId == id;
    final generation = ++_generation;
    _token?.cancel('Doctor workspace request replaced.');
    final token = _token = CancelToken();

    // A new account must never render the previous Doctor state. A same-account
    // refresh keeps the last authoritative snapshot mounted so presentation
    // state owned by DoctorAppShell survives foreground synchronization.
    _doctorId = id;
    if (!canPreserve) _workspace = null;
    _errorMessage = null;
    _state = DoctorWorkspaceBootstrapState.loading;
    _notify();

    try {
      final result = await _repository.load(id, cancelToken: token);
      if (!_isCurrent(generation, token, id)) return;
      if (result.doctorId != id) {
        throw const DoctorWorkspaceBootstrapException(
          'La configuration reçue ne correspond pas à cette session.',
        );
      }
      _workspace = result;
      _state = DoctorWorkspaceBootstrapState.ready;
    } on DioException catch (error) {
      if (!_isCurrent(generation, token, id) || CancelToken.isCancel(error)) {
        return;
      }
      if (error.response?.statusCode == 401 ||
          error.response?.statusCode == 403) {
        _workspace = null;
      }
      _errorMessage =
          'Impossible de charger la configuration professionnelle. Vérifiez votre connexion puis réessayez.';
      _state = DoctorWorkspaceBootstrapState.failure;
    } on DoctorWorkspaceBootstrapException catch (error) {
      if (!_isCurrent(generation, token, id)) return;
      _workspace = null;
      _errorMessage = error.message;
      _state = DoctorWorkspaceBootstrapState.failure;
    } on FormatException {
      if (!_isCurrent(generation, token, id)) return;
      _workspace = null;
      _errorMessage =
          'La configuration professionnelle reçue est incompatible avec cette version.';
      _state = DoctorWorkspaceBootstrapState.failure;
    } catch (_) {
      if (!_isCurrent(generation, token, id)) return;
      _workspace = null;
      _errorMessage =
          'La configuration professionnelle est momentanément indisponible.';
      _state = DoctorWorkspaceBootstrapState.failure;
    } finally {
      if (_isCurrent(generation, token, id)) {
        _token = null;
        _notify();
      }
    }
  }

  Future<void> refresh() async {
    final id = _doctorId;
    if (id == null) return;
    await _load(id, preserveCurrentWorkspace: true);
  }

  void clear() {
    _generation++;
    _token?.cancel('Doctor session cleared.');
    _token = null;
    _doctorId = null;
    _workspace = null;
    _errorMessage = null;
    _state = DoctorWorkspaceBootstrapState.initial;
    _notify();
  }

  bool _isCurrent(int generation, CancelToken token, String doctorId) =>
      !_disposed &&
      generation == _generation &&
      identical(_token, token) &&
      !token.isCancelled &&
      _doctorId == doctorId;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _token?.cancel('Doctor workspace controller disposed.');
    _token = null;
    _workspace = null;
    super.dispose();
  }
}
