import 'package:flutter/foundation.dart';

import 'doctor_workspace_config.dart';
import 'doctor_workspace_repository.dart';

/// One source of truth for the local Doctor workspace configuration.
class DoctorWorkspaceController extends ChangeNotifier {
  DoctorWorkspaceController({required DoctorWorkspaceRepository repository})
    : _repository = repository;

  final DoctorWorkspaceRepository _repository;

  DoctorWorkspaceConfig? _config;
  String? _doctorId;
  bool _isLoading = false;

  DoctorWorkspaceConfig? get config => _config;
  bool get isLoading => _isLoading;
  bool get onboardingCompleted => _config?.onboardingCompleted == true;
  Set<DoctorCapability> get capabilities => _config == null
      ? const <DoctorCapability>{}
      : deriveDoctorCapabilities(_config!);

  Future<void> load(String doctorId) async {
    _doctorId = doctorId.trim();
    _isLoading = true;
    notifyListeners();
    _config = await _repository.read(_doctorId!);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> complete(DoctorWorkspaceConfig config) async {
    if (_doctorId == null || config.doctorId != _doctorId) {
      throw ArgumentError(
        'Doctor workspace config does not match this session.',
      );
    }
    _isLoading = true;
    notifyListeners();
    try {
      await _repository.save(config);
      _config = config;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Test and debug-only entry point. Production UI never exposes it.
  Future<void> resetForDemo() async {
    final doctorId = _doctorId;
    if (doctorId == null) return;
    await _repository.clear(doctorId);
    _config = null;
    notifyListeners();
  }
}
