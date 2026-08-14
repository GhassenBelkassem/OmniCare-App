import 'package:dio/dio.dart';

import 'clinic_api.dart';
import 'clinic_failure.dart';
import 'clinic_models.dart';

/// Repository boundary for the clinic access flow.
///
/// It converts every transport or contract problem into a safe [ClinicFailure]
/// so no controller or screen ever sees backend detail, request IDs or internal
/// error codes.
class ClinicRepository {
  const ClinicRepository(this._api);

  final ClinicApi _api;

  Future<ClinicAccessFamily> resolveAccessFamily({
    CancelToken? cancelToken,
  }) async {
    try {
      final result = await _api.fetchAccess(cancelToken: cancelToken);
      return result.accessFamily;
    } catch (error) {
      throw ClinicFailure.from(error);
    }
  }

  Future<ClinicMembershipDirectory> loadMemberships({
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.fetchMemberships(cancelToken: cancelToken);
    } catch (error) {
      throw ClinicFailure.from(error);
    }
  }

  Future<ClinicBootstrap> loadBootstrap(
    String clinicId, {
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.fetchBootstrap(clinicId, cancelToken: cancelToken);
    } catch (error) {
      throw ClinicFailure.from(error);
    }
  }

  Future<ClinicSlice<ClinicTaskSummary>> loadPositionQueue(
    String clinicId, {
    int page = 0,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.fetchPositionQueue(
        clinicId,
        page: page,
        pageSize: pageSize,
        cancelToken: cancelToken,
      );
    } catch (error) {
      throw ClinicFailure.from(error);
    }
  }

  Future<ClinicSlice<ClinicTaskSummary>> loadMyTasks(
    String clinicId, {
    int page = 0,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.fetchMyTasks(
        clinicId,
        page: page,
        pageSize: pageSize,
        cancelToken: cancelToken,
      );
    } catch (error) {
      throw ClinicFailure.from(error);
    }
  }

  Future<ClinicTaskDetail> loadTaskDetail(
    String clinicId,
    String taskId, {
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.fetchTaskDetail(
        clinicId,
        taskId,
        cancelToken: cancelToken,
      );
    } catch (error) {
      throw ClinicFailure.from(error);
    }
  }

  Future<ClinicTaskDetail> acknowledgeTask(
    String clinicId,
    String taskId, {
    required int expectedVersion,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.acknowledgeTask(
        clinicId,
        taskId,
        expectedVersion: expectedVersion,
        cancelToken: cancelToken,
      );
    } catch (error) {
      throw ClinicFailure.from(error);
    }
  }

  Future<ClinicTaskDetail> startTask(
    String clinicId,
    String taskId, {
    required int expectedVersion,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.startTask(
        clinicId,
        taskId,
        expectedVersion: expectedVersion,
        cancelToken: cancelToken,
      );
    } catch (error) {
      throw ClinicFailure.from(error);
    }
  }

  Future<ClinicTaskDetail> blockTask(
    String clinicId,
    String taskId, {
    required ClinicTaskBlockedReason reason,
    required int expectedVersion,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.blockTask(
        clinicId,
        taskId,
        reason: reason,
        expectedVersion: expectedVersion,
        cancelToken: cancelToken,
      );
    } catch (error) {
      throw ClinicFailure.from(error);
    }
  }

  Future<ClinicTaskDetail> unblockTask(
    String clinicId,
    String taskId, {
    required int expectedVersion,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.unblockTask(
        clinicId,
        taskId,
        expectedVersion: expectedVersion,
        cancelToken: cancelToken,
      );
    } catch (error) {
      throw ClinicFailure.from(error);
    }
  }

  Future<ClinicTaskDetail> completeTask(
    String clinicId,
    String taskId, {
    required int expectedVersion,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.completeTask(
        clinicId,
        taskId,
        expectedVersion: expectedVersion,
        cancelToken: cancelToken,
      );
    } catch (error) {
      throw ClinicFailure.from(error);
    }
  }

  Future<ClinicSlice<ClinicHandoverTarget>> loadHandoverTargets(
    String clinicId,
    String taskId, {
    int page = 0,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.fetchHandoverTargets(
        clinicId,
        taskId,
        page: page,
        pageSize: pageSize,
        cancelToken: cancelToken,
      );
    } catch (error) {
      throw ClinicFailure.from(error);
    }
  }

  Future<ClinicHandoverSummary> initiateHandover(
    String clinicId,
    String taskId, {
    required String toMembershipId,
    required ClinicHandoverReason reason,
    required int expectedTaskVersion,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.initiateHandover(
        clinicId,
        taskId,
        toMembershipId: toMembershipId,
        reason: reason,
        expectedTaskVersion: expectedTaskVersion,
        cancelToken: cancelToken,
      );
    } catch (error) {
      throw ClinicFailure.from(error);
    }
  }

  Future<ClinicHandoverSummary> loadHandoverDetail(
    String clinicId,
    String handoverId, {
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.fetchHandoverDetail(
        clinicId,
        handoverId,
        cancelToken: cancelToken,
      );
    } catch (error) {
      throw ClinicFailure.from(error);
    }
  }

  Future<ClinicHandoverSummary> acceptHandover(
    String clinicId,
    String handoverId, {
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.acceptHandover(
        clinicId,
        handoverId,
        cancelToken: cancelToken,
      );
    } catch (error) {
      throw ClinicFailure.from(error);
    }
  }

  Future<ClinicHandoverSummary> declineHandover(
    String clinicId,
    String handoverId, {
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.declineHandover(
        clinicId,
        handoverId,
        cancelToken: cancelToken,
      );
    } catch (error) {
      throw ClinicFailure.from(error);
    }
  }

  Future<ClinicHandoverSummary> cancelHandover(
    String clinicId,
    String handoverId, {
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.cancelHandover(
        clinicId,
        handoverId,
        cancelToken: cancelToken,
      );
    } catch (error) {
      throw ClinicFailure.from(error);
    }
  }

  Future<ClinicCaseDetail> loadCaseDetail(
    String clinicId,
    String caseId, {
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.fetchCaseDetail(
        clinicId,
        caseId,
        cancelToken: cancelToken,
      );
    } catch (error) {
      throw ClinicFailure.from(error);
    }
  }

  Future<ClinicCaseDetail> startReview(
    String clinicId,
    String caseId, {
    required int expectedVersion,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.startReview(
        clinicId,
        caseId,
        expectedVersion: expectedVersion,
        cancelToken: cancelToken,
      );
    } catch (error) {
      throw ClinicFailure.from(error);
    }
  }

  Future<ClinicCaseDetail> requestInformation(
    String clinicId,
    String caseId, {
    required int expectedVersion,
    required ClinicInformationRequestReason reason,
    String? patientInstruction,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.requestInformation(
        clinicId,
        caseId,
        expectedVersion: expectedVersion,
        reason: reason,
        patientInstruction: patientInstruction,
        cancelToken: cancelToken,
      );
    } catch (error) {
      throw ClinicFailure.from(error);
    }
  }

  Future<ClinicCaseDetail> readyForPlanning(
    String clinicId,
    String caseId, {
    required int expectedVersion,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.readyForPlanning(
        clinicId,
        caseId,
        expectedVersion: expectedVersion,
        cancelToken: cancelToken,
      );
    } catch (error) {
      throw ClinicFailure.from(error);
    }
  }

  Future<ClinicCaseDetail> declineCase(
    String clinicId,
    String caseId, {
    required int expectedVersion,
    required ClinicCaseDeclineReason reason,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.declineCase(
        clinicId,
        caseId,
        expectedVersion: expectedVersion,
        reason: reason,
        cancelToken: cancelToken,
      );
    } catch (error) {
      throw ClinicFailure.from(error);
    }
  }

  Future<ClinicSlice<ClinicHandoverSummary>> loadHandovers(
    String clinicId, {
    required bool incoming,
    int page = 0,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.fetchHandovers(
        clinicId,
        incoming: incoming,
        page: page,
        pageSize: pageSize,
        cancelToken: cancelToken,
      );
    } catch (error) {
      throw ClinicFailure.from(error);
    }
  }
}
