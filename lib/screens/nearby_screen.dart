import 'package:flutter/material.dart';

import '../models/pharmacy.dart';
import '../services/launcher_service.dart';
import '../services/pharmacy_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/pharmacy_card.dart';
import '../widgets/search_bar.dart';
import 'directions_screen.dart';
import 'pharmacy_detail_screen.dart';
/// Pharmacy list sorted by distance from the user (screen 08).
class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  List<Pharmacy> _pharmacies = [];
  bool _loading = true;
  bool _error = false;
  String _filter = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() {
      setState(() => _filter = _searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final location = AppState.instance.currentLocation.value;
      final pharmacies = await PharmacyService.instance
          .fetchPharmacies(near: location?.position);
      if (!mounted) return;
      setState(() {
        _pharmacies = pharmacies;
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

  List<Pharmacy> get _visible {
    final q = _filter.trim().toLowerCase();
    if (q.isEmpty) return _pharmacies;
    return _pharmacies.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.address.toLowerCase().contains(q) ||
          p.city.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nearby Pharmacies',
                style: AppTextStyles.headlineXl
                    .copyWith(color: AppColors.onSurface),
              ),
              const SizedBox(height: 4),
              Text(
                _loading
                    ? 'Finding pharmacies near you...'
                    : '${_visible.length} pharmacies found',
                style: AppTextStyles.bodySm
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SearchBarWidget(
            controller: _searchController,
            hint: 'Search by name, address or city',
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off,
                size: 40, color: AppColors.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              'Could not load pharmacies.',
              style: AppTextStyles.bodySm
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    final visible = _visible;
    if (visible.isEmpty) {
      return Center(
        child: Text(
          _filter.isEmpty
              ? 'No pharmacies found.'
              : 'No results for "$_filter".',
          style: AppTextStyles.bodySm
              .copyWith(color: AppColors.onSurfaceVariant),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: visible.length,
      itemBuilder: (context, i) {
        final p = visible[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PharmacyCard(
            pharmacy: p,
            subtitle: p.distanceKm >= 0
                ? '${p.formattedDistance} • ${p.address.isNotEmpty ? p.address : p.city}'
                : (p.address.isNotEmpty ? p.address : p.city),
            showSchedule: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PharmacyDetailScreen(pharmacy: p),
              ),
            ),
            onCall: () => LauncherService.call(p.phone),
            onDirections: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DirectionsScreen(pharmacy: p),
              ),
            ),
          ),
        );
      },
    );
  }
}
