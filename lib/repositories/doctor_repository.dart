import '../core/api/doctors_api.dart';
import '../mock_data/mock_doctors.dart';

class DoctorRepository {
  DoctorsApi? _api;

  DoctorRepository({DoctorsApi? api}) : _api = api;

  void useMock() {
    _api = null;
  }

  void useApi(DoctorsApi api) {
    _api = api;
  }

  bool get isMock => _api == null;

  Future<Map<String, dynamic>> getMyProfile() async {
    if (_api == null) return createMockDoctorProfile();
    return _api!.getMyProfile();
  }

  Future<List<Map<String, dynamic>>> listDoctors() async {
    if (_api == null) return createMockDoctors();
    return _api!.listDoctors();
  }

  Future<List<Map<String, dynamic>>> getDoctors() async {
    if (_api == null) return createMockDoctors();
    return _api!.getDoctors();
  }

  List<Map<String, dynamic>> getKines() {
    return createMockDoctors().where((d) => d['specialty'] == 'Kinésithérapeute').toList();
  }
}
