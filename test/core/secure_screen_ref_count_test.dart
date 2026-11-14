import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/platform/secure_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('omnicare/secure_screen');
  late List<String> calls;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SecureScreen.debugReset();
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    SecureScreen.debugReset();
    debugDefaultTargetPlatformOverride = null;
  });

  test('first acquire enables, last release disables', () async {
    SecureScreen.acquire();
    SecureScreen.release();
    await pumpEventQueue();
    expect(calls, ['enable', 'disable']);
  });

  test('nested holders never toggle the window flag', () async {
    // Patient shell holds the flag; « Dossier médical » mounts and unmounts.
    SecureScreen.acquire();
    SecureScreen.acquire();
    SecureScreen.release();
    SecureScreen.acquire();
    SecureScreen.release();
    await pumpEventQueue();
    expect(calls, ['enable']);
    expect(SecureScreen.debugHolderCount, 1);

    SecureScreen.release(); // logout: shell disposed
    await pumpEventQueue();
    expect(calls, ['enable', 'disable']);
  });

  test('extra release is ignored', () async {
    SecureScreen.release();
    await pumpEventQueue();
    expect(calls, isEmpty);
    expect(SecureScreen.debugHolderCount, 0);
  });
}
