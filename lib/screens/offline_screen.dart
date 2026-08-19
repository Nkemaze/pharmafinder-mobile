import 'package:flutter/material.dart';

import '../services/connectivity_service.dart';
import '../services/prefs_service.dart';
import '../theme/app_theme.dart';
import 'onboarding_screen.dart';
import 'shell_screen.dart';

/// Shown when there is no internet connection (screen 09). Offers a retry
/// button that re-runs the bootstrap decision once connectivity returns.
class OfflineScreen extends StatefulWidget {
  const OfflineScreen({super.key});

  @override
  State<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends State<OfflineScreen> {
  bool _checking = false;

  Future<void> _retry() async {
    setState(() => _checking = true);
    final online = await ConnectivityService.instance.checkNow();
    if (!mounted) return;
    if (!online) {
      setState(() => _checking = false);
      return;
    }
    final onboardingDone = await PrefsService.instance.isOnboardingDone();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            onboardingDone ? const ShellScreen() : const OnboardingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.wifi_off,
                    size: 44,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'You\'re offline',
                  style: AppTextStyles.headlineXl
                      .copyWith(color: AppColors.onSurface),
                ),
                const SizedBox(height: 12),
                Text(
                  'Check your internet connection and try again.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyLg
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _checking ? null : _retry,
                    child: _checking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onPrimary,
                            ),
                          )
                        : const Text('Retry'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
