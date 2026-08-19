import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../services/offline_map_service.dart';

/// Shared OpenStreetMap tile layer used by every map in the app.
///
/// Tiles are served through [OfflineMapService]'s persistent cache, so
/// previously viewed or downloaded tiles render instantly and keep working
/// without a network connection.
class AppTileLayer extends StatelessWidget {
  const AppTileLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      urlTemplate: OfflineMapService.tileUrlTemplate,
      userAgentPackageName: 'com.example.customer_mobile_app',
      tileProvider: NetworkTileProvider(
        cachingProvider: OfflineMapService.instance.tileCache,
      ),
    );
  }
}
