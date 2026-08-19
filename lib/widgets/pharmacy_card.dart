import 'package:flutter/material.dart';

import '../models/pharmacy.dart';
import '../theme/app_theme.dart';
import 'status_chip.dart';

enum StockStatus { inStock, outOfStock, unknown }

/// The core pharmacy component: name, distance, status chip, optional price,
/// and Directions / Call actions.
class PharmacyCard extends StatelessWidget {
  final Pharmacy pharmacy;
  final String? subtitle;
  final String? priceLabel;
  final StockStatus stockStatus;
  final bool showSchedule;
  final bool enabled;
  final VoidCallback? onTap;
  final VoidCallback? onDirections;
  final VoidCallback? onCall;

  const PharmacyCard({
    super.key,
    required this.pharmacy,
    this.subtitle,
    this.priceLabel,
    this.stockStatus = StockStatus.unknown,
    this.showSchedule = false,
    this.enabled = true,
    this.onTap,
    this.onDirections,
    this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final dimmed = !enabled;
    final nameColor = dimmed ? AppColors.onSurfaceVariant : AppColors.primary;

    return Opacity(
      opacity: dimmed ? 0.75 : 1,
      child: Material(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pharmacy.name,
                            style: AppTextStyles.headlineMd.copyWith(color: nameColor),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if ((subtitle ?? '').isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 14,
                                  color: AppColors.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    subtitle!,
                                    style: AppTextStyles.bodySm
                                        .copyWith(color: AppColors.onSurfaceVariant),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusChip(isOpen: pharmacy.isOpenNow, compact: true),
                  ],
                ),
                if (showSchedule && (pharmacy.scheduleSummary.isNotEmpty)) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_outlined,
                        size: 16,
                        color: pharmacy.isOpenNow
                            ? AppColors.onSurfaceVariant
                            : AppColors.error,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        pharmacy.scheduleSummary,
                        style: AppTextStyles.bodySm.copyWith(
                          color: pharmacy.isOpenNow
                              ? AppColors.onSurfaceVariant
                              : AppColors.error,
                        ),
                      ),
                    ],
                  ),
                ],
                if (priceLabel != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PRICE',
                              style: AppTextStyles.labelMd
                                  .copyWith(color: AppColors.onSurfaceVariant),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              priceLabel!,
                              style: AppTextStyles.headlineMd.copyWith(
                                color: dimmed
                                    ? AppColors.onSurfaceVariant
                                    : AppColors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _stockBadge(),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        label: 'Call',
                        icon: Icons.call_outlined,
                        onTap: enabled ? onCall : null,
                        filled: false,
                        dimmed: dimmed,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionButton(
                        label: 'Directions',
                        icon: Icons.directions_outlined,
                        onTap: enabled ? onDirections : null,
                        filled: true,
                        dimmed: dimmed,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stockBadge() {
    switch (stockStatus) {
      case StockStatus.inStock:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline,
                size: 16, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              'In Stock',
              style: AppTextStyles.labelMd.copyWith(color: AppColors.primary),
            ),
          ],
        );
      case StockStatus.outOfStock:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.remove_circle_outline,
                size: 16, color: AppColors.error),
            const SizedBox(width: 4),
            Text(
              'Out of Stock',
              style: AppTextStyles.labelMd.copyWith(color: AppColors.error),
            ),
          ],
        );
      case StockStatus.unknown:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.help_outline,
                size: 16, color: AppColors.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              'Unknown Stock',
              style: AppTextStyles.labelMd
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
        );
    }
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;
  final bool dimmed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.filled,
    required this.dimmed,
  });

  @override
  Widget build(BuildContext context) {
    final bg = filled ? AppColors.primary : AppColors.surfaceContainer;
    final fg = dimmed
        ? AppColors.onSurfaceVariant
        : filled
            ? AppColors.onPrimary
            : AppColors.primary;

    return Material(
      color: dimmed && filled ? AppColors.surfaceVariant : bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: filled || dimmed
                ? null
                : Border.all(color: AppColors.primary, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: 6),
              Text(label, style: AppTextStyles.labelMd.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}
