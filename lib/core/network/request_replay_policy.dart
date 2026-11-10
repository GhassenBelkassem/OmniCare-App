import 'package:dio/dio.dart';

enum RequestReplayPolicy { automaticSafeRead, declaredIdempotentWrite, never }

const String requestReplayPolicyExtraKey = 'omnicare_request_replay_policy';

Map<String, dynamic> requestReplayExtra(RequestReplayPolicy policy) =>
    <String, dynamic>{requestReplayPolicyExtraKey: policy.name};

RequestReplayPolicy? declaredReplayPolicy(RequestOptions request) {
  final value = request.extra[requestReplayPolicyExtraKey];
  if (value is RequestReplayPolicy) return value;
  if (value is String) {
    for (final policy in RequestReplayPolicy.values) {
      if (policy.name == value) return policy;
    }
  }
  return null;
}

bool isSafeReadMethod(String method) {
  final normalized = method.toUpperCase();
  return normalized == 'GET' || normalized == 'HEAD' || normalized == 'OPTIONS';
}

bool isRequestReplayable(RequestOptions request) {
  final data = request.data;
  if (data is FormData || data is Stream || data is MultipartFile) {
    return false;
  }

  final declared = declaredReplayPolicy(request);
  if (declared == RequestReplayPolicy.never) return false;

  if (isSafeReadMethod(request.method)) {
    return (declared == null ||
            declared == RequestReplayPolicy.automaticSafeRead) &&
        isReconstructableJsonValue(data);
  }

  if (declared != RequestReplayPolicy.declaredIdempotentWrite) return false;
  if (_headerValue(request.headers, 'Idempotency-Key')?.isNotEmpty != true) {
    return false;
  }
  return isReconstructableJsonValue(data);
}

/// True only for values Dio can encode as a fresh JSON body without consuming
/// a stream or depending on mutable custom state.
bool isReconstructableJsonValue(Object? value, [int depth = 0]) {
  if (depth > 64) return false;
  if (value == null || value is String || value is num || value is bool) {
    return true;
  }
  if (value is List) {
    return value.every((item) => isReconstructableJsonValue(item, depth + 1));
  }
  if (value is Map) {
    return value.entries.every(
      (entry) =>
          entry.key is String &&
          isReconstructableJsonValue(entry.value, depth + 1),
    );
  }
  return false;
}

String? _headerValue(Map<String, dynamic> headers, String name) {
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == name.toLowerCase()) {
      return entry.value?.toString().trim();
    }
  }
  return null;
}
