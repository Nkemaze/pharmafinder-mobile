import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Fixed app header used by the main tabs: title + avatar chip on the right.
class TopBar extends StatelessWidget {
  final String title;
  final bool titleUppercase;

  const TopBar({super.key, required this.title, this.titleUppercase = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: AppSpace.horizontalMargin,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: Color(0x0A000000), width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              titleUppercase ? title.toUpperCase() : title,
              style: AppTextStyles.headlineMd.copyWith(color: AppColors.primary),
            ),
          ),
          const _Avatar(),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.person_outline,
        size: 18,
        color: AppColors.onPrimary,
      ),
    );
  }
}
