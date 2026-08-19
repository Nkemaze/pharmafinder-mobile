import 'package:flutter/material.dart';

import '../services/launcher_service.dart';
import '../services/offline_map_service.dart';
import '../services/prefs_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/top_bar.dart';

/// App settings (screen 10): units, contact support, about and a
/// reset-local-data action.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _unit = 'km';

  @override
  void initState() {
    super.initState();
    _loadUnit();
  }

  Future<void> _loadUnit() async {
    final prefs = await PrefsService.instance.getUnit();
    if (mounted) setState(() => _unit = prefs);
  }

  Future<void> _setUnit(String unit) async {
    setState(() => _unit = unit);
    await PrefsService.instance.setUnit(unit);
  }

  Future<void> _resetData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset local data?'),
        content: const Text(
          'This clears saved pharmacies, recent searches, your manual '
          'location and downloaded offline maps from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await PrefsService.instance.resetAll();
    await OfflineMapService.instance.deleteAll();
    await AppState.instance.resetLocation();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Local data cleared.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const TopBar(title: 'Settings'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _sectionTitle('Search'),
              _unitTile(),
              const SizedBox(height: 24),
              _sectionTitle('Support'),
              _actionTile(
                icon: Icons.call_outlined,
                title: 'Call support',
                subtitle: '+237 672 58 05 67',
                onTap: () => LauncherService.call('+237 672 58 05 67'),
              ),
              _actionTile(
                icon: Icons.mail_outline,
                title: 'Email support',
                subtitle: 'support@pharmafinder.com',
                onTap: () =>
                    LauncherService.email(subject: 'PharmaFinder support'),
              ),
              const SizedBox(height: 24),
              _sectionTitle('About'),
              _actionTile(
                icon: Icons.info_outline,
                title: 'About PharmaFinder',
                subtitle: 'Version 1.0.0',
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'PharmaFinder',
                  applicationVersion: '1.0.0',
                  applicationIcon: const Icon(
                    Icons.local_pharmacy,
                    size: 32,
                    color: AppColors.primary,
                  ),
                  children: const [
                    Text(
                      'Find nearby pharmacies, check medicine prices and '
                      'availability near you.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _sectionTitle('Data'),
              _actionTile(
                icon: Icons.delete_outline,
                title: 'Reset local data',
                subtitle: 'Clear saved pharmacies and searches',
                onTap: _resetData,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.labelMd.copyWith(
          color: AppColors.primary,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _unitTile() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.straighten_outlined,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Distance units',
              style: AppTextStyles.bodyLg.copyWith(color: AppColors.onSurface),
            ),
          ),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'km', label: Text('km')),
              ButtonSegment(value: 'mi', label: Text('mi')),
            ],
            selected: {_unit},
            onSelectionChanged: (s) => _setUnit(s.first),
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyLg.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
