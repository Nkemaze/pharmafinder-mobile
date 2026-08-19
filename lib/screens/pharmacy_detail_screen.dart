import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/pharmacy.dart';
import '../services/launcher_service.dart';
import '../services/pharmacy_service.dart';
import '../services/prefs_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/mini_map.dart';
import '../widgets/status_chip.dart';
import 'directions_screen.dart';
import 'map_screen.dart';

/// Full pharmacy page: hero info, map preview, actions and the inventory
/// list with in-stock badges and prices.
class PharmacyDetailScreen extends StatefulWidget {
  final Pharmacy pharmacy;

  const PharmacyDetailScreen({super.key, required this.pharmacy});

  @override
  State<PharmacyDetailScreen> createState() => _PharmacyDetailScreenState();
}

class _PharmacyDetailScreenState extends State<PharmacyDetailScreen> {
  late Pharmacy _pharmacy;
  List<dynamic> _drugs = [];
  bool _loading = true;
  bool _error = false;
  bool _saved = false;
  bool _showFullInventory = false;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _pharmacy = widget.pharmacy;
    _load();
  }

  Future<void> _load() async {
    _saved = await PrefsService.instance.isPharmacySaved(_pharmacy.id);
    if (!mounted) return;

    // Refresh distances using the current user location when available.
    final location = AppState.instance.currentLocation.value;
    if (_pharmacy.distanceKm < 0 && location != null) {
      final fresh =
          await PharmacyService.instance.fetchPharmacy(_pharmacy.id);
      if (fresh != null) _pharmacy = fresh;
    }

    setState(() => _loading = true);
    try {
      final drugs =
          await PharmacyService.instance.fetchDrugs(_pharmacy.id);
      if (!mounted) return;
      setState(() {
        _drugs = drugs;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  void _toggleSaved() {
    setState(() => _saved = !_saved);
    PrefsService.instance.toggleSavedPharmacy(_pharmacy.id);
  }

  List<dynamic> get _visibleDrugs {
    final filtered = _drugs.where((d) {
      final name = (d as dynamic).name?.toString() ?? '';
      return _filter.isEmpty || name.toLowerCase().contains(_filter.toLowerCase());
    }).toList();
    return _showFullInventory ? filtered : filtered.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final p = _pharmacy;
    final dist = p.distanceKm >= 0 ? '${p.formattedDistance} away' : '';
    final walk = p.distanceKm >= 0
        ? '• ${(p.distanceKm * 12).round()} min walk'
        : '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Pharmacy Details',
          style: AppTextStyles.headlineMd.copyWith(color: AppColors.onSurface),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHero(p, dist, walk),
          _buildInventory(),
        ],
      ),
    );
  }

  Widget _buildHero(Pharmacy p, String dist, String walk) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  p.name,
                  style: AppTextStyles.headlineLg
                      .copyWith(color: AppColors.onSurface),
                ),
              ),
              const SizedBox(width: 8),
              StatusChip(isOpen: p.isOpenNow),
            ],
          ),
          const SizedBox(height: 16),
          _infoRow(
            icon: Icons.location_on,
            filled: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.address.isNotEmpty ? p.address : 'Address unavailable',
                  style: AppTextStyles.bodyLg
                      .copyWith(color: AppColors.onSurface),
                ),
                if (dist.isNotEmpty)
                  Text(
                    '$dist $walk'.trim(),
                    style: AppTextStyles.bodySm
                        .copyWith(color: AppColors.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          if (p.scheduleSummary.isNotEmpty)
            _infoRow(
              icon: Icons.schedule,
              child: Text(
                p.isOpenNow
                    ? '${p.scheduleSummary} today'
                    : p.scheduleSummary,
                style: AppTextStyles.bodySm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
            ),
          if (p.phone.isNotEmpty)
            _infoRow(
              icon: Icons.call,
              child: Text(
                p.phone,
                style: AppTextStyles.bodySm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
            ),
          if (p.hasLocation) ...[
            const SizedBox(height: 16),
            MiniMap(
              center: LatLng(p.latitude, p.longitude),
              onTap: () => _expandMap(),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: _expandMap,
                icon: const Icon(Icons.zoom_in_map, size: 18),
                label: const Text('Expand Map'),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: AppSpace.touchTarget,
                  child: FilledButton.icon(
                    onPressed: _openDirections,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.directions),
                    label: const Text('Get Directions'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _squareAction(
                icon: Icons.call,
                onTap: () => LauncherService.call(p.phone),
              ),
              const SizedBox(width: 8),
              _squareAction(
                icon: _saved ? Icons.bookmark : Icons.bookmark_border,
                onTap: _toggleSaved,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _expandMap() {
    if (!_pharmacy.hasLocation) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MapScreen(focusPharmacy: _pharmacy),
      ),
    );
  }

  void _openDirections() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DirectionsScreen(pharmacy: _pharmacy),
      ),
    );
  }

  Widget _squareAction({required IconData icon, required VoidCallback onTap}) {
    return SizedBox(
      width: AppSpace.touchTarget,
      height: AppSpace.touchTarget,
      child: Material(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Icon(icon, color: AppColors.primary, size: 24),
        ),
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required Widget child,
    bool filled = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: 20,
              color: AppColors.outline,
              fill: filled ? 1 : 0),
          const SizedBox(width: 12),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildInventory() {
    return Container(
      margin: const EdgeInsets.only(top: 0),
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Available Medicines',
                  style: AppTextStyles.headlineMd
                      .copyWith(color: AppColors.onSurface),
                ),
              ),
              Text(
                'Search',
                style: AppTextStyles.labelMd.copyWith(color: AppColors.primary),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.search, size: 16, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 16),
          _buildInventoryBody(),
        ],
      ),
    );
  }

  Widget _buildInventoryBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    if (_error) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Text(
              'Could not load the medicine list.',
              style: AppTextStyles.bodySm
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _inventorySearch(),
        const SizedBox(height: 16),
        if (_drugs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No medicines recorded yet.',
                style: AppTextStyles.bodySm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
            ),
          )
        else if (_visibleDrugs.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No medicines match "$_filter".',
                style: AppTextStyles.bodySm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
            ),
          )
        else
          for (final drug in _visibleDrugs) ...[
            _drugTile(drug),
            const SizedBox(height: 12),
          ],
        if (!_showFullInventory && _drugs.length > 4)
          TextButton.icon(
            onPressed: () => setState(() => _showFullInventory = true),
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: const Text('View Full Inventory'),
            style: TextButton.styleFrom(alignment: Alignment.center),
          ),
      ],
    );
  }

  Widget _inventorySearch() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 20, color: AppColors.outline),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _filter = v),
              style: AppTextStyles.bodyLg.copyWith(color: AppColors.onSurface),
              decoration: InputDecoration(
                hintText: 'Search inventory...',
                hintStyle: AppTextStyles.bodyLg
                    .copyWith(color: AppColors.outlineVariant),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drugTile(dynamic raw) {
    final drug = raw as dynamic;
    final name = drug.name ?? '';
    final priceLabel = drug.priceLabel ?? '';
    final inStock = drug.inStock ?? false;
    final formLabel = drug.formLabel ?? '';

    return Opacity(
      opacity: inStock ? 1 : 0.65,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: AppTextStyles.bodyLg.copyWith(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.w600,
                            decoration: inStock
                                ? TextDecoration.none
                                : TextDecoration.lineThrough,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: inStock
                              ? AppColors.tertiaryFixed
                              : AppColors.errorContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          inStock ? 'IN STOCK' : 'OUT OF STOCK',
                          style: AppTextStyles.labelMd.copyWith(
                            fontSize: 10,
                            color: inStock
                                ? AppColors.onTertiaryFixedVariant
                                : AppColors.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (formLabel.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      formLabel,
                      style: AppTextStyles.bodySm
                          .copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              priceLabel,
              style: AppTextStyles.bodyLg.copyWith(
                color: inStock ? AppColors.primary : AppColors.outline,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
