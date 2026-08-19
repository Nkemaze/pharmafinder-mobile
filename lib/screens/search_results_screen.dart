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

/// Shows pharmacies that stock the searched drug, sortable by nearest, price
/// and open-now.
class SearchResultsScreen extends StatefulWidget {
  final String query;

  const SearchResultsScreen({super.key, required this.query});

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

enum _SortMode { nearest, price, openNow }

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<PharmacySearchResult>? _results;
  bool _loading = true;
  bool _error = false;
  _SortMode _sort = _SortMode.nearest;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _query = widget.query;
    _searchController.text = widget.query;
    _runSearch(widget.query);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String query) async {
    setState(() {
      _query = query;
      _loading = true;
      _error = false;
    });
    try {
      final location = AppState.instance.currentLocation.value;
      final results = await PharmacyService.instance
          .searchDrugs(query, near: location?.position);
      if (!mounted) return;
      setState(() {
        _results = results;
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

  List<PharmacySearchResult> get _sorted {
    final results = List<PharmacySearchResult>.from(_results ?? []);
    switch (_sort) {
      case _SortMode.nearest:
        results.sort((a, b) => a.pharmacy.distanceKm
            .compareTo(b.pharmacy.distanceKm));
      case _SortMode.price:
        results.sort((a, b) => a.bestDrug.price.compareTo(b.bestDrug.price));
      case _SortMode.openNow:
        results.sort((a, b) {
          if (a.pharmacy.isOpenNow == b.pharmacy.isOpenNow) {
            return a.pharmacy.distanceKm.compareTo(b.pharmacy.distanceKm);
          }
          return a.pharmacy.isOpenNow ? -1 : 1;
        });
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Search Results',
          style: AppTextStyles.headlineMd.copyWith(color: AppColors.onSurface),
        ),
      ),
      body: Column(
        children: [
          _buildSearchHeader(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      color: AppColors.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          SearchBarWidget(
            controller: _searchController,
            hint: 'Search for a drug...',
            padding: const EdgeInsets.symmetric(horizontal: 16),
            onSubmitted: _runSearch,
            onClear: () => _runSearch(''),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Text(
                  '${_results?.length ?? 0} pharmacies found',
                  style: AppTextStyles.bodySm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _sortChip('Nearest', _SortMode.nearest),
                const SizedBox(width: 8),
                _sortChip('Price', _SortMode.price),
                const SizedBox(width: 8),
                _sortChip('Open now', _SortMode.openNow),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _sortChip(String label, _SortMode mode) {
    final selected = _sort == mode;
    return GestureDetector(
      onTap: () => setState(() => _sort = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryContainer : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelMd.copyWith(
            color: selected
                ? AppColors.onPrimaryContainer
                : AppColors.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_error) {
      return _message(
        icon: Icons.cloud_off,
        title: 'Something went wrong',
        body: 'Could not reach PharmaFinder. Check your connection.',
        action: OutlinedButton(
          onPressed: () => _runSearch(_query),
          child: const Text('Retry'),
        ),
      );
    }
    final results = _sorted;
    if (results.isEmpty) {
      return _message(
        icon: Icons.search_off,
        title: 'No pharmacies found',
        body: 'No pharmacy has "$_query" in stock right now.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, i) => _buildResultCard(results[i]),
    );
  }

  Widget _buildResultCard(PharmacySearchResult result) {
    final p = result.pharmacy;
    final dist = p.distanceKm >= 0 ? p.formattedDistance : '';
    final subtitle = [if (p.city.isNotEmpty) p.city, if (dist.isNotEmpty) dist]
        .join(' • ');
    return PharmacyCard(
      pharmacy: p,
      subtitle: subtitle,
      priceLabel: result.bestDrug.priceLabel,
      stockStatus:
          result.anyInStock ? StockStatus.inStock : StockStatus.outOfStock,
      enabled: p.isOpenNow,
      onTap: () => _openDetail(p),
      onDirections: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DirectionsScreen(pharmacy: p),
        ),
      ),
      onCall: () => LauncherService.call(p.phone),
    );
  }

  void _openDetail(Pharmacy p) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PharmacyDetailScreen(pharmacy: p)),
    );
  }

  Widget _message({
    required IconData icon,
    required String title,
    required String body,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: AppSpace.pageMargin,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: AppTextStyles.headlineMd
                    .copyWith(color: AppColors.onSurface)),
            const SizedBox(height: 8),
            Text(body,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySm
                    .copyWith(color: AppColors.onSurfaceVariant)),
            if (action != null) ...[const SizedBox(height: 16), action],
          ],
        ),
      ),
    );
  }
}
