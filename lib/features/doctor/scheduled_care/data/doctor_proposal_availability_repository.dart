import 'package:dio/dio.dart';

import '../../../patient_doctor/data/doctor_directory_models.dart';
import '../../../patient_doctor/data/doctor_directory_repository.dart';

abstract interface class DoctorProposalAvailabilityRepositoryContract {
  Future<AvailabilitySlotsDto> getSlots({
    required String doctorId,
    required String practiceLocationId,
    required DateTime from,
    required DateTime to,
    CancelToken? cancelToken,
  });
}

class DoctorProposalAvailabilityRepository
    implements DoctorProposalAvailabilityRepositoryContract {
  const DoctorProposalAvailabilityRepository(this._directoryRepository);

  final DoctorDirectoryRepository _directoryRepository;

  @override
  Future<AvailabilitySlotsDto> getSlots({
    required String doctorId,
    required String practiceLocationId,
    required DateTime from,
    required DateTime to,
    CancelToken? cancelToken,
  }) => _directoryRepository.getSlots(
    doctorId: doctorId,
    practiceLocationId: practiceLocationId,
    from: from,
    to: to,
    cancelToken: cancelToken,
  );
}
