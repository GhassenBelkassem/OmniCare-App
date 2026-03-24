import 'package:flutter/material.dart';
import 'language_selection_screen.dart';
import '../../core/auth/token_storage.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToLogin();
  }

  Future<void> _navigateToLogin() async {
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      final jwt = await TokenStorage.readJwt();
      if (jwt != null && jwt.trim().isNotEmpty) {
        final complete = await TokenStorage.readOnboardingComplete();
        if (!mounted) return;
        if (complete == true) {
          Navigator.of(context).pushReplacementNamed('/home');
          return;
        }
        if (complete == false) {
          Navigator.of(
            context,
          ).pushReplacementNamed('/conversational-onboarding');
          return;
        }

        // Unknown onboarding status (e.g. first launch after update or profile fetch failed).
        // Do not route to onboarding by default.
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const LanguageSelectionScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
        return;
      }

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LanguageSelectionScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1FBF9A)),
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () async {
                await TokenStorage.clearJwt();
                if (!context.mounted) return;
                Navigator.of(context).pushReplacement(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        const LanguageSelectionScreen(),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                          return FadeTransition(
                            opacity: animation,
                            child: child,
                          );
                        },
                    transitionDuration: const Duration(milliseconds: 300),
                  ),
                );
              },
              child: const Text('Clear Storage'),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
