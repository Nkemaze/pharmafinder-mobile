import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:customer_mobile_app/services/offline_map_service.dart';

void main() {
  group('OfflineMapService.parseTileCoordFromUrl', () {
    test('parses z/x/y from a tile URL', () {
      final coord = OfflineMapService.parseTileCoordFromUrl(
        'https://tile.openstreetmap.org/14/9243/8212.png',
      );
      expect(coord, isNotNull);
      expect(coord!.z, 14);
      expect(coord.x, 9243);
      expect(coord.y, 8212);
    });

    test('parses URLs with query strings', () {
      final coord = OfflineMapService.parseTileCoordFromUrl(
        'https://tiles.example.com/8/137/96.png?token=abc',
      );
      expect(coord, isNotNull);
      expect(coord!.z, 8);
      expect(coord.x, 137);
      expect(coord.y, 96);
    });

    test('returns null for non-tile URLs', () {
      expect(
        OfflineMapService.parseTileCoordFromUrl('https://example.com/a/b'),
        isNull,
      );
      expect(
        OfflineMapService.parseTileCoordFromUrl(
          'https://tile.openstreetmap.org/30/1/1.png',
        ),
        isNull,
      );
    });
  });

  group('OfflineMapService tile enumeration', () {
    // A small area around Buea, Cameroon.
    final buea = LatLngBounds(
      const LatLng(4.13, 9.22),
      const LatLng(4.17, 9.26),
    );

    test('estimate matches enumerated tile count', () {
      final estimate = OfflineMapService.estimateTileCount(buea, 3, 14);
      final tiles = OfflineMapService.enumerateTiles(buea, 3, 14);
      expect(estimate, tiles.length);
    });

    test('single zoom level 0 covers the world in one tile', () {
      final world = LatLngBounds(
        const LatLng(-85, -179),
        const LatLng(85, 179),
      );
      expect(OfflineMapService.estimateTileCount(world, 0, 0), 1);
    });

    test('tile count grows with the zoom range', () {
      final low = OfflineMapService.estimateTileCount(buea, 3, 12);
      final mid = OfflineMapService.estimateTileCount(buea, 3, 13);
      final high = OfflineMapService.estimateTileCount(buea, 3, 14);
      expect(low, lessThan(mid));
      expect(mid, lessThan(high));
    });

    test('a phone-sized view stays within the download cap', () {
      final tiles = OfflineMapService.enumerateTiles(buea, 3, 15);
      expect(
        tiles.length,
        lessThanOrEqualTo(OfflineMapService.maxTilesPerRegion),
      );
    });

    test('every enumerated tile lies within the bounds at its zoom', () {
      final tiles = OfflineMapService.enumerateTiles(buea, 12, 14);
      expect(tiles, isNotEmpty);
      for (final tile in tiles) {
        // Reconvert the tile coordinate back to its center and confirm it is
        // within the (padded) area covered by the bounds.
        final n = 1 << tile.z;
        final lon = (tile.x + 0.5) / n * 360 - 180;
        final latRad = _tileYToLat(tile.y, tile.z);
        final lat = latRad * 180 / 3.141592653589793;
        expect(lon, greaterThanOrEqualTo(buea.west - 1));
        expect(lon, lessThanOrEqualTo(buea.east + 1));
        expect(lat, greaterThanOrEqualTo(buea.south - 1));
        expect(lat, lessThanOrEqualTo(buea.north + 1));
      }
    });
  });

  group('OfflineRegion', () {
    test('serializes to JSON and back', () {
      final region = OfflineRegion(
        id: 'abc123',
        name: 'Buea town',
        west: 9.22,
        south: 4.13,
        east: 9.26,
        north: 4.17,
        minZoom: 3,
        maxZoom: 14,
        tileCount: 240,
        sizeBytes: 4_300_000,
        createdAt: DateTime(2026, 8, 18),
      );

      final decoded = OfflineRegion.fromJson(region.toJson());

      expect(decoded.id, region.id);
      expect(decoded.name, region.name);
      expect(decoded.west, region.west);
      expect(decoded.south, region.south);
      expect(decoded.east, region.east);
      expect(decoded.north, region.north);
      expect(decoded.minZoom, region.minZoom);
      expect(decoded.maxZoom, region.maxZoom);
      expect(decoded.tileCount, region.tileCount);
      expect(decoded.sizeBytes, region.sizeBytes);
      expect(decoded.createdAt, region.createdAt);
    });

    test('formats sizes for display', () {
      expect(_regionWithSize(500).sizeLabel, '500 B');
      expect(_regionWithSize(18 * 1024).sizeLabel, '18 KB');
      expect(_regionWithSize(4_300_000).sizeLabel, '4.1 MB');
    });
  });
}

OfflineRegion _regionWithSize(int sizeBytes) => OfflineRegion(
  id: 'x',
  name: 'x',
  west: 9,
  south: 4,
  east: 9.1,
  north: 4.1,
  minZoom: 3,
  maxZoom: 14,
  tileCount: 1,
  sizeBytes: sizeBytes,
  createdAt: DateTime(2026, 1, 1),
);

double _tileYToLat(int y, int z) {
  final n = 1 << z;
  return 3.141592653589793 * (1 - 2 * y / n);
}
