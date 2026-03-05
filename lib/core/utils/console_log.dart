import 'console_log_stub.dart'
    if (dart.library.html) 'console_log_web.dart';

void consoleLog(Object? message) {
  consoleLogImpl(message);
}
