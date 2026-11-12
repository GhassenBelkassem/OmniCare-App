import '../network/api_failure.dart';

/// Outcome of a repository call: a value or an [ApiFailure], never a thrown
/// exception (roadmap G-2 §5; Flutter architecture guide, "Result" design
/// pattern). Named `Err` instead of the guide's `Error` so it cannot shadow
/// `dart:core` `Error`.
sealed class Result<T> {
  const Result();
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;

  @override
  String toString() => 'Ok<$T>';
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final ApiFailure failure;

  @override
  String toString() => 'Err<$T>(${failure.logSummary})';
}

/// Runs [call] and wraps its value, or any error parsed by
/// [ApiFailure.from]. Never throws.
Future<Result<T>> guardApiCall<T>(Future<T> Function() call) async {
  try {
    return Ok(await call());
  } catch (error) {
    return Err(ApiFailure.from(error));
  }
}
