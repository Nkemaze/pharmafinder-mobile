import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/pharmacy.dart';
import '../services/launcher_service.dart';
import '../services/routing_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_tile_layer.dart';
import '../widgets/manual_location_sheet.dart';
import '../widgets/status_chip.dart';

/// In-app directions: draws the road route from the user's location to the
/// pharmacy on an OpenStreetMap, with distance, ETA and turn-by-turn steps.
/// Opening the external Google Maps app remains available as a fallback.
class DirectionsScreen extends StatefulWidget {
  final Pharmacy pharmacy;

  const DirectionsScreen({super.key, required this.pharmacy});

  @override
  State<DirectionsScreen> createState() => _DirectionsScreenState();
}

class _DirectionsScreenState extends State<DirectionsScreen> {
  final _mapController = MapController();
  RouteResult? _route;
  LatLng? _origin;
  bool _loading = true;
  bool _noLocation = false;
  bool _mapReady = false;

  Pharmacy get _pharmacy => widget.pharmacy;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    setState(() => _loading = true);
    var location = AppState.instance.currentLocation.value;
    location ??= await AppState.instance.resolveLocation();
    if (!mounted) return;
    if (location == null) {
      setState(() {
        _noLocation = true;
        _loading = false;
      });
      return;
    }
    final position = location.position;
    setState(() {
      _origin = position;
      _noLocation = false;
    });
    final route = await RoutingService.instance.getRoute(
      origin: position,
      destination: LatLng(_pharmacy.latitude, _pharmacy.longitude),
    );
    if (!mounted) return;
    setState(() {
      _route = route;
      _loading = false;
    });
    _fitRoute();
  }

  void _fitRoute() {
    final route = _route;
    if (!_mapReady || route == null) return;
    final bounds = LatLngBounds.fromPoints(route.points);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mapReady) return;
      final camera = CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(56),
      ).fit(_mapController.camera);
      _mapController.move(camera.center, camera.zoom);
    });
  }

  Future<void> _setManualLocation() async {
    await showManualLocationSheet(context);
    if (mounted) _resolve();
  }

  @override
  Widget build(BuildContext context) {
    final destination = LatLng(_pharmacy.latitude, _pharmacy.longitude);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Directions',
              style: AppTextStyles.headlineMd.copyWith(
                color: AppColors.onSurface,
              ),
            ),
            Text(
              _pharmacy.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: !_pharmacy.hasLocation
          ? _buildNoPharmacyLocation()
          : LayoutBuilder(
              builder: (context, constraints) {
                final mapHeight = (constraints.maxHeight * 0.45).clamp(
                  220.0,
                  400.0,
                );
                return Column(
                  children: [
                    SizedBox(
                      height: mapHeight,
                      width: double.infinity,
                      child: _buildMap(destination),
                    ),
                    Expanded(child: _buildPanel()),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildNoPharmacyLocation() {
    return Center(
      child: Padding(
        padding: AppSpace.pageMargin,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_off,
              size: 48,
              color: AppColors.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No map location',
              style: AppTextStyles.headlineMd.copyWith(
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_pharmacy.name} has no coordinates set, so directions are '
              'not available yet.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(LatLng destination) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: destination,
        initialZoom: 14,
        minZoom: 3,
        maxZoom: 19,
        onMapReady: () {
          _mapReady = true;
          _fitRoute();
        },
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      ),
      children: [
        const AppTileLayer(),
        if (_route != null && !_route!.isFallback)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _route!.points,
                strokeWidth: 6,
                color: AppColors.primary,
                borderColor: Colors.white,
                borderStrokeWidth: 3,
              ),
            ],
          ),
        if (_route != null && _route!.isFallback)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _route!.points,
                strokeWidth: 4,
                color: AppColors.outline,
                pattern: StrokePattern.dashed(segments: const [12, 10]),
              ),
            ],
          ),
        if (_loading)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x66FFFFFF),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
          ),
        MarkerLayer(
          markers: [
            if (_origin != null)
              Marker(
                point: _origin!,
                width: 18,
                height: 18,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
              ),
            Marker(
              point: destination,
              width: 44,
              height: 44,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.local_pharmacy,
                  size: 20,
                  color: AppColors.onPrimary,
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

  Widget _buildPanel() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: _panelContent(),
      ),
    );
  }

  List<Widget> _panelContent() {
    if (_loading) {
      return [
        const SizedBox(height: 32),
        const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Finding the best route...',
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ];
    }
    if (_noLocation) {
      return [
        const SizedBox(height: 16),
        const Icon(
          Icons.location_off,
          size: 40,
          color: AppColors.onSurfaceVariant,
        ),
        const SizedBox(height: 16),
        Text(
          'We need your location',
          textAlign: TextAlign.center,
          style: AppTextStyles.headlineMd.copyWith(color: AppColors.onSurface),
        ),
        const SizedBox(height: 8),
        Text(
          'Set your location to get directions to ${_pharmacy.name}.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _setManualLocation,
            icon: const Icon(Icons.edit_location_alt, size: 18),
            label: const Text('Set my location'),
          ),
        ),
      ];
    }

    final route = _route;
    if (route == null) return const [SizedBox.shrink()];

    final address = _pharmacy.address.isNotEmpty
        ? _pharmacy.address
        : _pharmacy.city;
    return [
      Row(
        children: [
          Expanded(
            child: Text(
              _pharmacy.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.headlineMd.copyWith(
                color: AppColors.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 8),
          StatusChip(isOpen: _pharmacy.isOpenNow, compact: true),
        ],
      ),
      if (address.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(
          address,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodySm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.directions_car,
              label: 'ETA',
              value: route.formattedDuration,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              icon: Icons.straighten,
              label: 'Distance',
              value: route.formattedDistance,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              icon: Icons.turn_slight_right,
              label: 'Steps',
              value: '${route.steps.length}',
            ),
          ),
        ],
      ),
      if (route.isFallback) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 16,
                color: AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Routing service unreachable — showing a direct path.',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(
            child: Text(
              'Turn-by-turn',
              style: AppTextStyles.headlineMd.copyWith(
                color: AppColors.onSurface,
              ),
            ),
          ),
          Text(
            '${route.steps.length} steps',
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      for (var i = 0; i < route.steps.length; i++)
        _StepTile(step: route.steps[i], index: i),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => LauncherService.directionsTo(
            _pharmacy.latitude,
            _pharmacy.longitude,
          ),
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('Open in Google Maps'),
        ),
      ),
      const SizedBox(height: 8),
      Center(
        child: Text(
          'Distances and times are estimates for driving.',
          style: AppTextStyles.bodySm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
    ];
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyLg.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.labelMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final RouteStep step;
  final int index;

  const _StepTile({required this.step, required this.index});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppColors.primaryFixed,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _maneuverIcon(step),
                size: 20,
                color: AppColors.onPrimaryFixedVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                step.instruction,
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              step.formattedDistance,
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _maneuverIcon(RouteStep step) {
  switch (step.maneuverType) {
    case 'depart':
      return Icons.trip_origin;
    case 'arrive':
      return Icons.place;
    case 'roundabout':
    case 'rotary':
    case 'roundabout turn':
      return Icons.roundabout_right;
    case 'merge':
      return Icons.call_merge;
    case 'fork':
      return Icons.call_split;
    case 'on ramp':
    case 'off ramp':
      return Icons.alt_route;
  }
  switch (step.maneuverModifier) {
    case 'uturn':
      return Icons.u_turn_left;
    case 'sharp left':
      return Icons.turn_sharp_left;
    case 'left':
      return Icons.turn_left;
    case 'slight left':
      return Icons.turn_slight_left;
    case 'slight right':
      return Icons.turn_slight_right;
    case 'right':
      return Icons.turn_right;
    case 'sharp right':
      return Icons.turn_sharp_right;
  }
  return Icons.straight;
}
