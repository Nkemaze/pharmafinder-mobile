import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Small pill badge showing a pharmacy's open/closed status.
class StatusChip extends StatelessWidget {
  final bool isOpen;
  final bool compact;

  const StatusChip({super.key, required this.isOpen, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final bg = isOpen ? AppColors.openGreenBg : AppColors.errorContainer;
    final fg = isOpen ? AppColors.openGreen : AppColors.onErrorContainer;
    final dot = isOpen ? AppColors.openGreen : AppColors.error;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            isOpen ? 'Open' : 'Closed',
            style: AppTextStyles.labelMd.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}
