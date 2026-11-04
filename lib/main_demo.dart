import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/network/app_http_client.dart';
import 'core/storage/secure_token_store.dart';
import 'core/theme/omni_theme.dart';
import 'demo/demo_auth_repository.dart';
import 'demo/demo_http_adapter.dart';
import 'demo/demo_token_storage.dart';
import 'demo/demo_toolbar.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/notifications/application/notification_center_controller.dart';
import 'features/notifications/data/notification_api.dart';
import 'features/notifications/data/notification_repository.dart';
import 'main.dart' show OmniCareApp;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    runApp(const _ChromeOnlyMessage());
    return;
  }

  final tokenStore = SecureTokenStore(backend: DemoTokenStorage());
  final httpClient = AppHttpClient(
    tokenStore: tokenStore,
    baseUrl: 'https://static-demo.invalid',
    dio: _demoDio(),
    refreshDio: _demoDio(),
  );
  final authRepository = DemoAuthRepository();
  final authController = AuthController(repository: authRepository);
  final notificationController = NotificationCenterController(
    repository: NotificationRepository(NotificationApi(httpClient)),
  );

  runApp(
    _DemoRoot(
      authController: authController,
      authRepository: authRepository,
      httpClient: httpClient,
      notificationController: notificationController,
    ),
  );

  unawaited(authController.initialize());
}

Dio _demoDio() {
  final dio = Dio();
  dio.httpClientAdapter = DemoHttpAdapter();
  return dio;
}

class _DemoRoot extends StatelessWidget {
  const _DemoRoot({
    required this.authController,
    required this.authRepository,
    required this.httpClient,
    required this.notificationController,
  });

  final AuthController authController;
  final DemoAuthRepository authRepository;
  final AppHttpClient httpClient;
  final NotificationCenterController notificationController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OmniCare Static Demo',
      debugShowCheckedModeBanner: false,
      theme: buildOmniTheme(),
      home: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            OmniCareApp(
              authController: authController,
              httpClient: httpClient,
              notificationController: notificationController,
            ),
            DemoToolbar(
              authController: authController,
              authRepository: authRepository,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChromeOnlyMessage extends StatelessWidget {
  const _ChromeOnlyMessage();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildOmniTheme(),
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'La démo statique OmniCare est disponible uniquement dans Chrome.\n\n'
              'flutter run -d chrome -t lib/main_demo.dart',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
