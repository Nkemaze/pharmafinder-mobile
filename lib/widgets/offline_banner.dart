import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Thin error banner shown beneath the header when the device is offline.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.error,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 18, color: AppColors.onError),
          const SizedBox(width: 8),
          Text(
            'No internet connection',
            style: AppTextStyles.labelMd.copyWith(color: AppColors.onError),
          ),
        ],
      ),
    );
  }
}
