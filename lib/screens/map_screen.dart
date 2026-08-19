import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/pharmacy.dart';
import '../services/pharmacy_service.dart';
import '../services/prefs_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_tile_layer.dart';
import '../widgets/manual_location_sheet.dart';
import '../widgets/offline_maps_sheet.dart';
import '../widgets/status_chip.dart';
import '../widgets/top_bar.dart';
import 'directions_screen.dart';
import 'pharmacy_detail_screen.dart';

/// Full-screen OpenStreetMap with pharmacy markers. Used as the Map tab
/// inside the shell (showAppBar false) or pushed as a standalone page with
/// a focus pharmacy (showAppBar true).
class MapScreen extends StatefulWidget {
  final bool showAppBar;
  final Pharmacy? focusPharmacy;

  const MapScreen({super.key, this.showAppBar = true, this.focusPharmacy});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  Pharmacy? _selected;
  List<Pharmacy> _pharmacies = [];
  bool _loading = true;
  bool _error = false;
  LatLng? _userLocation;
  bool _mapReady = false;
  String? _lastCenteredKey;

  /// Initial camera, resolved before the map first builds so it never jumps:
  /// focused pharmacy -> last used position -> Buea (the app's home region).
  static const _defaultCenter = LatLng(4.1527, 9.2410);
  static const _defaultZoom = 14.0;
  LatLng _initialCenter = _defaultCenter;
  double _initialZoom = _defaultZoom;
  bool _cameraLoaded = false;
  bool _autoRecentreAllowed = true;
  Timer? _cameraSaveDebounce;

  @override
  void initState() {
    super.initState();
    _selected = widget.focusPharmacy;
    final focus = widget.focusPharmacy;
    if (focus != null && focus.hasLocation) {
      _initialCenter = LatLng(focus.latitude, focus.longitude);
      _cameraLoaded = true;
    } else {
      _loadInitialCamera();
    }
    AppState.instance.currentLocation.addListener(_onLocationChanged);
    _load();
  }

  @override
  void dispose() {
    AppState.instance.currentLocation.removeListener(_onLocationChanged);
    _cameraSaveDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialCamera() async {
    final saved = await PrefsService.instance.getLastMapCamera();
    if (!mounted) return;
    setState(() {
      if (saved != null) {
        _initialCenter = saved.center;
        _initialZoom = saved.zoom;
        // Restoring the previous position: don't yank the camera away from
        // it on the first data load. Tapping the locate button or changing
        // the manual location still recentres.
        _autoRecentreAllowed = false;
      }
      _cameraLoaded = true;
    });
  }

  void _onLocationChanged() {
    // An explicit location change (e.g. manual address) should recentre.
    _autoRecentreAllowed = true;
    if (mounted) _load();
  }

  Future<void> _load() async {
    final location = AppState.instance.currentLocation.value;
    _userLocation = location?.position;
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final pharmacies = await PharmacyService.instance.fetchPharmacies(
        near: location?.position,
      );
      if (!mounted) return;
      setState(() {
        _pharmacies = pharmacies;
        if (_selected == null && pharmacies.isNotEmpty) {
          _selected = pharmacies.first;
        }
        _loading = false;
      });
      _recentreIfNeeded();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  LatLng? get _focus {
    if (_selected != null) {
      return LatLng(_selected!.latitude, _selected!.longitude);
    }
    if (_userLocation != null) return _userLocation;
    if (_pharmacies.isNotEmpty) {
      final p = _pharmacies.first;
      return LatLng(p.latitude, p.longitude);
    }
    return null;
  }

  /// Identifies what the camera was last centred on so we only move it when
  /// there is something new (never fights the user's own panning).
  String? get _centreKey {
    if (widget.focusPharmacy != null) {
      return 'focus:${widget.focusPharmacy!.id}';
    }
    if (_userLocation != null) return 'user:$_userLocation';
    if (_pharmacies.isNotEmpty) return 'first:${_pharmacies.first.id}';
    return null;
  }

  void _recentreIfNeeded() {
    if (!_mapReady || !_autoRecentreAllowed) return;
    final key = _centreKey;
    final focus = _focus;
    if (key == null || focus == null || key == _lastCenteredKey) return;
    _lastCenteredKey = key;
    _animateTo(focus);
  }

  /// Persists where the user left the map so the next session opens on the
  /// same view (instant, usually already-cached tiles) instead of jumping.
  void _onMapPositionChanged(MapCamera camera, bool hasGesture) {
    if (!hasGesture) return;
    _cameraSaveDebounce?.cancel();
    _cameraSaveDebounce = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      PrefsService.instance.setLastMapCamera(
        center: camera.center,
        zoom: camera.zoom,
      );
    });
  }

  void _animateTo(LatLng point, {double zoom = 14.5}) {
    if (!_mapReady) return;
    _mapController.move(point, zoom);
  }

  void _onMapReady() {
    _mapReady = true;
    _recentreIfNeeded();
  }

  void _changeZoom(double delta) {
    if (!_mapReady) return;
    final camera = _mapController.camera;
    final target = (camera.zoom + delta).clamp(3.0, 19.0);
    if (target == camera.zoom) return;
    _mapController.move(camera.center, target);
  }

  Future<void> _goToMyLocation() async {
    var location = AppState.instance.currentLocation.value;
    location ??= await AppState.instance.resolveLocation();
    if (!mounted) return;
    if (location == null) {
      await showManualLocationSheet(context);
      return;
    }
    _autoRecentreAllowed = true;
    _animateTo(location.position, zoom: 15);
  }

  Future<void> _openOfflineMaps() async {
    if (!_mapReady) return;
    await showOfflineMapsSheet(
      context,
      visibleBounds: _mapController.camera.visibleBounds,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.showAppBar
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                'Map',
                style: AppTextStyles.headlineMd.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
            )
          : null,
      body: widget.showAppBar
          ? _buildBody()
          : Column(
              children: [
                const TopBar(title: 'Map'),
                Expanded(child: _buildBody()),
              ],
            ),
    );
  }

  Widget _buildBody() {
    return Stack(
      children: [
        _buildMap(),
        if (_error && !_loading)
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: _ErrorBanner(onRetry: _load),
          ),
        if (_selected != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _PharmacyCard(
              pharmacy: _selected!,
              onDirections: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DirectionsScreen(pharmacy: _selected!),
                ),
              ),
              onView: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PharmacyDetailScreen(pharmacy: _selected!),
                ),
              ),
              onClose: () => setState(() => _selected = null),
            ),
          ),
        Positioned(
          right: 12,
          bottom: _selected != null ? 178 : 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MapButton(
                icon: Icons.download_for_offline_outlined,
                onTap: _openOfflineMaps,
              ),
              const SizedBox(height: 12),
              _MapButton(icon: Icons.add, onTap: () => _changeZoom(1)),
              const SizedBox(height: 4),
              _MapButton(icon: Icons.remove, onTap: () => _changeZoom(-1)),
              const SizedBox(height: 12),
              _MapButton(
                icon: Icons.my_location,
                onTap: _goToMyLocation,
                highlighted: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMap() {
    if (!_cameraLoaded) {
      return const ColoredBox(color: AppColors.background);
    }
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _initialCenter,
        initialZoom: _initialZoom,
        minZoom: 3,
        maxZoom: 19,
        onMapReady: _onMapReady,
        onPositionChanged: _onMapPositionChanged,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        const AppTileLayer(),
        if (_userLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: _userLocation!,
                width: 18,
                height: 18,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            for (final p in _pharmacies)
              if (p.hasLocation)
                Marker(
                  point: LatLng(p.latitude, p.longitude),
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selected = p);
                      _animateTo(LatLng(p.latitude, p.longitude));
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _selected?.id == p.id
                            ? AppColors.primary
                            : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _selected?.id == p.id
                              ? Colors.white
                              : AppColors.primary,
                          width: 2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.local_pharmacy,
                        size: 20,
                        color: _selected?.id == p.id
                            ? AppColors.onPrimary
                            : AppColors.primary,
                      ),
                    ),
                  ),
                ),
          ],
        ),
        RichAttributionWidget(
          attributions: [TextSourceAttribution('OpenStreetMap contributors')],
        ),
      ],
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool highlighted;

  const _MapButton({
    required this.icon,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: Material(
        elevation: 3,
        borderRadius: BorderRadius.circular(12),
        color: highlighted ? AppColors.primary : Colors.white,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Icon(
            icon,
            size: 20,
            color: highlighted ? AppColors.onPrimary : AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      color: AppColors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            const Icon(
              Icons.wifi_off,
              size: 18,
              color: AppColors.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Could not load pharmacies.',
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.onErrorContainer,
                ),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _PharmacyCard extends StatelessWidget {
  final Pharmacy pharmacy;
  final VoidCallback onDirections;
  final VoidCallback onView;
  final VoidCallback onClose;

  const _PharmacyCard({
    required this.pharmacy,
    required this.onDirections,
    required this.onView,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final p = pharmacy;
    final subtitle = [
      if (p.address.isNotEmpty || p.city.isNotEmpty)
        p.address.isNotEmpty ? p.address : p.city,
      if (p.distanceKm >= 0) p.formattedDistance,
    ].join(' • ');
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyLg.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                StatusChip(isOpen: p.isOpenNow, compact: true),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: AppColors.outline,
                  onPressed: onClose,
                ),
              ],
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: onDirections,
                      child: const Text('Directions'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: FilledButton(
                      onPressed: onView,
                      child: const Text('View Details'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
