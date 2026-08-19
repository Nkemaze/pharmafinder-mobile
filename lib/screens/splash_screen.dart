import 'package:flutter/material.dart';

import '../services/connectivity_service.dart';
import '../services/prefs_service.dart';
import '../theme/app_theme.dart';
import 'offline_screen.dart';
import 'onboarding_screen.dart';
import 'shell_screen.dart';

/// Branded splash screen. Decides where the app goes next based on
/// connectivity and whether onboarding has been seen before.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      Future.delayed(const Duration(milliseconds: 1800)),
      ConnectivityService.instance.checkNow(),
    ]);

    if (!mounted) return;

    final online = ConnectivityService.instance.isOnline.value;
    final onboardingDone = await PrefsService.instance.isOnboardingDone();

    if (!mounted) return;

    if (!online) {
      _go(const OfflineScreen());
      return;
    }
    if (!onboardingDone) {
      _go(const OnboardingScreen());
      return;
    }
    _go(const ShellScreen());
  }

  void _go(Widget screen) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo.png',
                width: 260,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 32),
              Text(
                'Find medicine. Find pharmacies. Faster.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyLg
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 64),
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'LOADING...',
                style: AppTextStyles.labelMd.copyWith(
                  color: AppColors.secondary,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
