import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_theme.dart';
import 'app_tile_layer.dart';

/// Lightweight static OpenStreetMap preview with a pharmacy marker.
class MiniMap extends StatelessWidget {
  final LatLng center;
  final double zoom;
  final double height;
  final VoidCallback? onTap;

  const MiniMap({
    super.key,
    required this.center,
    this.zoom = 15,
    this.height = 128,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GestureDetector(
          onTap: onTap,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: zoom,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.none,
              ),
            ),
            children: [
              const AppTileLayer(),
              MarkerLayer(
                markers: [
                  Marker(
                    point: center,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
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
            ],
          ),
        ),
      ),
    );
  }
}
