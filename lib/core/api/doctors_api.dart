import '../../mock_data/mock_doctors.dart';

class DoctorsApi {
  DoctorsApi({Object? dio});

  Future<Map<String, dynamic>> getMyProfile() async {
    return createMockDoctorProfile();
  }

  Future<List<Map<String, dynamic>>> listDoctors() async {
    return createMockDoctors();
  }

  Future<List<Map<String, dynamic>>> getDoctors() async {
    return createMockDoctors();
  }
}
