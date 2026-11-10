import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import 'application/auth_controller.dart';
import 'application/post_auth_navigation.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _navigationScheduled = false;

  @override
  void initState() {
    super.initState();
  }

  void _routeFor(AuthController auth) {
    if (_navigationScheduled || !auth.initializationCompleted) return;

    if (auth.status == AuthStatus.failure ||
        auth.status == AuthStatus.initializing) {
      return;
    }

    _navigationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      if (auth.isAuthenticated) {
        await navigateAfterAuthentication(
          context,
          auth,
          dismissKeyboard: false,
        );
        return;
      }

      Navigator.of(context).pushReplacementNamed('/login');
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    _routeFor(auth);

    final initializationFailed =
        auth.initializationCompleted && auth.status == AuthStatus.failure;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            Image.asset(
              'assets/images/logo.png',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.local_hospital,
                  size: 100,
                  color: Color(0xFF1FBF9A),
                );
              },
            ),
            const Spacer(flex: 2),
            if (initializationFailed) ...[
              const Icon(
                Icons.cloud_off_outlined,
                size: 44,
                color: Color(0xFF667085),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'We could not verify your saved session. Check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF475467)),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('splash-retry-session'),
                onPressed: () async {
                  _navigationScheduled = false;
                  await context.read<AuthController>().initialize();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1FBF9A),
                ),
                child: const Text('Try again'),
              ),
            ] else ...[
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1FBF9A)),
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
            ],
            if (kDebugMode)
              TextButton(
                onPressed: () async {
                  await context.read<AuthController>().logout();
                  if (!context.mounted) return;
                  await context.read<UserProvider>().logout();
                  if (!context.mounted) return;
                  Navigator.of(context).pushReplacementNamed('/login');
                },
                child: const Text('Clear Local Session'),
              ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
