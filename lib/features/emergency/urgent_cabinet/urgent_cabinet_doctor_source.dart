import 'urgent_cabinet_doctor_detail.dart';
import 'urgent_cabinet_doctor_list_item.dart';
import 'urgent_cabinet_request_review.dart';

/// Where the urgent CABINET screens read doctors from when a source is
/// injected (tests and the development preview entry points). Production
/// injects none and uses the real repositories. Kept apart from the
/// development fixture so production code never imports it (G-2 1b-3).
abstract class UrgentCabinetDoctorSource {
  const UrgentCabinetDoctorSource();

  bool get isDevelopmentFixture;

  Future<List<UrgentCabinetDoctorListItem>> loadDoctors();

  Future<UrgentCabinetDoctorDetail?> loadDoctorDetail(String doctorId);

  Future<UrgentCabinetFeeQuote?> loadUrgentCabinetFeeQuote({
    required String doctorId,
    required String cabinetId,
  }) {
    throw const UrgentCabinetDoctorSourceUnavailable();
  }
}

/// A source with no data: every read fails with
/// [UrgentCabinetDoctorSourceUnavailable].
class UrgentCabinetDoctorUnavailableSource extends UrgentCabinetDoctorSource {
  const UrgentCabinetDoctorUnavailableSource();

  @override
  bool get isDevelopmentFixture => false;

  @override
  Future<List<UrgentCabinetDoctorListItem>> loadDoctors() {
    throw const UrgentCabinetDoctorSourceUnavailable();
  }

  @override
  Future<UrgentCabinetDoctorDetail?> loadDoctorDetail(String doctorId) {
    throw const UrgentCabinetDoctorSourceUnavailable();
  }
}

class UrgentCabinetDoctorSourceUnavailable implements Exception {
  const UrgentCabinetDoctorSourceUnavailable();
}
