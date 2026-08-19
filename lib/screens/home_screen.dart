import 'package:flutter/material.dart';

import '../models/popular_drug.dart';
import '../services/location_service.dart';
import '../services/pharmacy_service.dart';
import '../services/prefs_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/manual_location_sheet.dart';
import '../widgets/search_bar.dart';
import '../widgets/top_bar.dart';
import 'search_results_screen.dart';

/// Main landing tab: greeting, drug search, recent/popular searches and a
/// "Popular Medicines" list aggregated across every pharmacy. This app is
/// drug-first — people find a medicine, then see which pharmacies carry it —
/// so pharmacies themselves live in the Nearby and Map tabs.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _popularNow = ['Coartem', 'Ibuprofen', 'Vitamin C'];

  List<String> _recentSearches = [];
  List<PopularDrug>? _popularDrugs;
  bool _locationResolving = true;
  bool _loadingDrugs = false;
  bool _locationDenied = false;
  String? _drugError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    AppState.instance.currentLocation.removeListener(_onLocationChanged);
    super.dispose();
  }

  Future<void> _load() async {
    AppState.instance.currentLocation.addListener(_onLocationChanged);
    _recentSearches = await PrefsService.instance.getRecentSearches();
    await _loadDrugs();
    if (!mounted) return;

    setState(() => _locationResolving = true);
    final location = await AppState.instance.resolveLocation();
    if (!mounted) return;

    setState(() {
      _locationResolving = false;
      _locationDenied = location == null && !(AppState.instance.gpsAttempted);
    });

    if (location == null && !AppState.instance.gpsAttempted) {
      // GPS never attempted — request it.
      await _enableLocation();
    } else if (location == null) {
      setState(() => _locationDenied = true);
    }
  }

  void _onLocationChanged() {
    if (!mounted) return;
    setState(() => _locationDenied = false);
  }

  Future<void> _enableLocation() async {
    setState(() => _locationResolving = true);
    final granted = await LocationService.instance.requestPermission();
    if (!mounted) return;
    if (granted) {
      await AppState.instance.resolveLocation();
      if (!mounted) return;
      setState(() {
        _locationResolving = false;
        _locationDenied = false;
      });
    } else {
      setState(() {
        _locationResolving = false;
        _locationDenied = true;
      });
    }
  }

  Future<void> _loadDrugs() async {
    setState(() {
      _loadingDrugs = true;
      _drugError = null;
    });
    try {
      final drugs = await PharmacyService.instance.fetchPopularDrugs();
      if (!mounted) return;
      setState(() {
        _popularDrugs = drugs;
        _loadingDrugs = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _drugError = 'Could not load medicines. Check your connection.';
        _loadingDrugs = false;
      });
    }
  }

  void _submitSearch(String query) {
    PrefsService.instance.addRecentSearch(query);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SearchResultsScreen(query: query),
      ),
    );
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const TopBar(title: 'Home'),
        Expanded(
          child: _locationResolving
              ? const _CenteredLoading()
              : _locationDenied
                  ? _buildLocationDisabled()
                  : _buildMainContent(),
        ),
      ],
    );
  }

  // ---- Main (location enabled) ----

  Widget _buildMainContent() {
    final location = AppState.instance.currentLocation.value;
    final areaName = (location?.areaName.isNotEmpty ?? false)
        ? location!.areaName
        : 'Set your location';

    return RefreshIndicator(
      onRefresh: _loadDrugs,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: AppSpace.horizontalMargin,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => showManualLocationSheet(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 16, color: AppColors.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            areaName,
                            style: AppTextStyles.bodySm
                                .copyWith(color: AppColors.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.expand_more,
                            size: 16, color: AppColors.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(_greeting,
                    style: AppTextStyles.headlineLg
                        .copyWith(color: AppColors.onBackground)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SearchBarWidget(
            onSubmitted: _submitSearch,
          ),
          const SizedBox(height: 24),
          _buildChipSection(),
          _buildDrugsSection(),
        ],
      ),
    );
  }

  Widget _buildChipSection() {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_recentSearches.isNotEmpty) ...[
            _chipHeader('Recent Searches'),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: 16),
                itemCount: _recentSearches.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) => _chip(
                  label: _recentSearches[i],
                  icon: Icons.history,
                  onTap: () => _submitSearch(_recentSearches[i]),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          _chipHeader('Popular Now'),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              itemCount: _popularNow.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => _chip(
                label: _popularNow[i],
                icon: Icons.trending_up,
                highlight: true,
                onTap: () => _submitSearch(_popularNow[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 16),
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.labelMd.copyWith(color: AppColors.onSurfaceVariant),
      ),
    );
  }

  Widget _chip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool highlight = false,
  }) {
    final bg = highlight
        ? AppColors.secondaryContainer.withValues(alpha: 0.3)
        : AppColors.surfaceContainer;
    final fg = highlight ? AppColors.onSecondaryContainer : AppColors.onSurface;
    final iconColor = highlight ? AppColors.secondary : AppColors.outline;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(label,
                  style: AppTextStyles.bodySm.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Popular Medicines ----

  Widget _buildDrugsSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: AppSpace.horizontalMargin,
            child: Text('Popular Medicines',
                style: AppTextStyles.headlineMd
                    .copyWith(color: AppColors.onBackground)),
          ),
          const SizedBox(height: 16),
          _buildDrugsBody(),
        ],
      ),
    );
  }

  Widget _buildDrugsBody() {
    if (_loadingDrugs) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    if (_drugError != null) {
      return Padding(
        padding: AppSpace.pageMargin,
        child: Column(
          children: [
            Text(_drugError!,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySm
                    .copyWith(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _loadDrugs,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    final drugs = _popularDrugs ?? [];
    if (drugs.isEmpty) {
      return Padding(
        padding: AppSpace.pageMargin,
        child: Text(
          'No medicines available yet. Check back soon.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySm
              .copyWith(color: AppColors.onSurfaceVariant),
        ),
      );
    }

    return Padding(
      padding: AppSpace.horizontalMargin,
      child: Column(
        children: [
          for (final d in drugs) ...[
            _drugCard(d),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _drugCard(PopularDrug d) {
    final pharmacies = d.pharmacyCount == 1
        ? '1 pharmacy'
        : '${d.pharmacyCount} pharmacies';
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _submitSearch(d.name),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.medication_outlined,
                        size: 24, color: AppColors.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.name,
                            style: AppTextStyles.headlineMd
                                .copyWith(color: AppColors.onBackground)),
                        const SizedBox(height: 2),
                        Text(d.formLabel,
                            style: AppTextStyles.bodySm.copyWith(
                                color: AppColors.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  _stockPill(d.anyInStock),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right,
                      size: 20, color: AppColors.outline),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'From ${d.cheapestPriceLabel}',
                            style: AppTextStyles.labelMd.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(
                            text: '  •  $pharmacies',
                            style: AppTextStyles.bodySm
                                .copyWith(color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Compare prices',
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stockPill(bool inStock) {
    final color = inStock ? AppColors.openGreen : AppColors.outline;
    final bg = inStock ? AppColors.openGreenBg : AppColors.surfaceContainer;
    final label = inStock ? 'In Stock' : 'Out of stock';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label,
              style: AppTextStyles.bodySm.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }

  // ---- Location disabled ----

  Widget _buildLocationDisabled() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 16),
        SearchBarWidget(
          onSubmitted: _submitSearch,
        ),
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  color: Color(0x80FFDAD6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_off,
                  size: 48,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 24),
              Text('Turn on location',
                  style: AppTextStyles.headlineMd
                      .copyWith(color: AppColors.onSurface)),
              const SizedBox(height: 8),
              Text(
                'Allow PharmaFinder to find pharmacies closest to you for '
                'faster care and better recommendations. You can still search '
                'for medicines above.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyLg
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: AppSpace.touchTarget,
                child: FilledButton.icon(
                  onPressed: _enableLocation,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Enable Location'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => showManualLocationSheet(context),
                icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                label: const Text('Enter address manually'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CenteredLoading extends StatelessWidget {
  const _CenteredLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }
}
