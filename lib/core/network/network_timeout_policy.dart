import 'package:dio/dio.dart';

/// Bounded timeout categories for the shared network stack.
///
/// These values bound individual Dio phases. They are not a wall-clock
/// deadline for the whole request.
abstract final class NetworkTimeoutPolicy {
  static const standardJson = NetworkTimeouts(
    connect: Duration(seconds: 30),
    send: Duration(seconds: 30),
    receive: Duration(seconds: 30),
  );

  static const authRefresh = NetworkTimeouts(
    connect: Duration(seconds: 30),
    send: Duration(seconds: 30),
    receive: Duration(seconds: 30),
  );

  static const medicalUpload = NetworkTimeouts(
    connect: Duration(seconds: 30),
    send: Duration(minutes: 2),
    receive: Duration(seconds: 30),
  );

  static const documentEvents = NetworkTimeouts(
    connect: Duration(seconds: 30),
    send: Duration(seconds: 5),
    receive: Duration(seconds: 45),
  );
}

class NetworkTimeouts {
  const NetworkTimeouts({
    required this.connect,
    required this.send,
    required this.receive,
  });

  final Duration connect;
  final Duration send;
  final Duration receive;

  BaseOptions applyToBaseOptions({required String baseUrl}) => BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: connect,
    sendTimeout: send,
    receiveTimeout: receive,
  );
}
