import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A tile at slippy-map coordinates (zoom, x, y).
typedef TileCoord = ({int z, int x, int y});

/// Progress of an ongoing offline map download.
@immutable
class OfflineDownloadProgress {
  final String regionName;
  final int completed;
  final int total;
  final int failed;

  const OfflineDownloadProgress({
    required this.regionName,
    required this.completed,
    required this.total,
    required this.failed,
  });

  double get fraction => total <= 0 ? 0 : completed / total;
}

/// A saved offline map area previously downloaded by the user.
@immutable
class OfflineRegion {
  final String id;
  final String name;
  final double west;
  final double south;
  final double east;
  final double north;
  final int minZoom;
  final int maxZoom;
  final int tileCount;
  final int sizeBytes;
  final DateTime createdAt;

  const OfflineRegion({
    required this.id,
    required this.name,
    required this.west,
    required this.south,
    required this.east,
    required this.north,
    required this.minZoom,
    required this.maxZoom,
    required this.tileCount,
    required this.sizeBytes,
    required this.createdAt,
  });

  LatLngBounds get bounds =>
      LatLngBounds(LatLng(south, west), LatLng(north, east));

  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).round()} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'west': west,
    'south': south,
    'east': east,
    'north': north,
    'minZoom': minZoom,
    'maxZoom': maxZoom,
    'tileCount': tileCount,
    'sizeBytes': sizeBytes,
    'createdAt': createdAt.toIso8601String(),
  };

  factory OfflineRegion.fromJson(Map<String, dynamic> json) => OfflineRegion(
    id: json['id'] as String,
    name: json['name'] as String,
    west: (json['west'] as num).toDouble(),
    south: (json['south'] as num).toDouble(),
    east: (json['east'] as num).toDouble(),
    north: (json['north'] as num).toDouble(),
    minZoom: json['minZoom'] as int,
    maxZoom: json['maxZoom'] as int,
    tileCount: json['tileCount'] as int,
    sizeBytes: json['sizeBytes'] as int,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

/// Thrown when a download is requested while storage is unavailable.
class OfflineMapUnavailableException implements Exception {
  const OfflineMapUnavailableException();
}

/// Thrown when another download is already running.
class OfflineMapBusyException implements Exception {
  const OfflineMapBusyException();
}

/// Thrown when the requested area needs more tiles than allowed.
class OfflineMapTooLargeException implements Exception {
  final int tileCount;

  const OfflineMapTooLargeException(this.tileCount);
}

/// Thrown when the user cancels a download.
class OfflineMapCanceledException implements Exception {
  const OfflineMapCanceledException();
}

/// Thrown when too many tiles fail to download.
class OfflineMapFailedException implements Exception {
  final int failedCount;

  const OfflineMapFailedException(this.failedCount);
}

/// Persistent map tile cache and offline area downloader.
///
/// Tiles live on disk in a simple `z/x/y.png` tree under the app support
/// directory:
///
/// * `browsing/` is filled automatically as the user browses the map, so
///   previously seen tiles render instantly on later visits;
/// * `regions/<id>/` is filled by explicit offline downloads.
///
/// The whole store is exposed to flutter_map through [tileCache], a
/// [MapCachingProvider] that reports every stored tile as fresh. Cached tiles
/// are therefore always served from disk first (fast) and keep working with
/// no network connection at all (offline).
class OfflineMapService {
  OfflineMapService._();

  static final OfflineMapService instance = OfflineMapService._();

  static const String tileUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Hard cap per downloaded area. Public OSM tile servers restrict bulk
  /// downloading, so areas are kept small; zoom in or pick less detail for
  /// larger views.
  static const int maxTilesPerRegion = 1200;

  static const int _maxConcurrentRequests = 2;
  static const Duration _requestPause = Duration(milliseconds: 120);
  static const String _regionsPrefKey = 'offline_map_regions';
  static const Map<String, String> _tileHeaders = {
    'User-Agent': 'PharmaFinderMobile/1.0 (capstone demo)',
  };

  Directory? _root;
  List<OfflineRegion> _regions = [];
  bool _cancelRequested = false;

  /// Live progress of the current download, or `null` when idle. The sheet
  /// listens to this so progress survives being closed and reopened.
  final ValueNotifier<OfflineDownloadProgress?> progress = ValueNotifier(null);

  bool get isAvailable => _root != null && !kIsWeb;

  List<OfflineRegion> get regions => List.unmodifiable(_regions);

  /// The caching provider handed to every [NetworkTileProvider] in the app.
  late final MapCachingProvider tileCache = _OfflineTileCache(this);

  /// Prepares storage and loads previously saved regions. Safe to call more
  /// than once; failures disable offline features instead of crashing.
  Future<void> initialize() async {
    if (isAvailable || kIsWeb) return;
    try {
      final support = await getApplicationSupportDirectory();
      _root = Directory(
        '${support.path}${Platform.pathSeparator}offline_map_tiles',
      );
      await _root!.create(recursive: true);
      _regions = await _loadRegions();
    } catch (_) {
      _root = null;
    }
  }

  Directory? get _regionsRoot {
    final root = _root;
    if (root == null) return null;
    return Directory('${root.path}${Platform.pathSeparator}regions');
  }

  Directory? get _browsingRoot {
    final root = _root;
    if (root == null) return null;
    return Directory('${root.path}${Platform.pathSeparator}browsing');
  }

  Future<List<OfflineRegion>> _loadRegions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getStringList(_regionsPrefKey) ?? [];
      return encoded
          .map(
            (s) =>
                OfflineRegion.fromJson(jsonDecode(s) as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveRegions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_regionsPrefKey, [
        for (final r in _regions) jsonEncode(r.toJson()),
      ]);
    } catch (_) {
      // Metadata is best-effort; tiles remain usable within the session.
    }
  }

  /// Looks for a stored tile, preferring downloaded regions over the
  /// browsing cache.
  File? _findTileFile(TileCoord coord) {
    final regionsRoot = _regionsRoot;
    if (regionsRoot != null) {
      for (final region in _regions) {
        if (coord.z < region.minZoom || coord.z > region.maxZoom) continue;
        final file = _tileFile(regionsRoot, region.id, coord);
        if (file.existsSync()) return file;
      }
    }
    final browsing = _browsingRoot;
    if (browsing != null) {
      final file = _tileFile(browsing, '', coord);
      if (file.existsSync()) return file;
    }
    return null;
  }

  File _tileFile(Directory base, String regionId, TileCoord coord) {
    final prefix = regionId.isEmpty ? '' : '$regionId${Platform.pathSeparator}';
    return File(
      '${base.path}${Platform.pathSeparator}$prefix${coord.z}${Platform.pathSeparator}${coord.x}${Platform.pathSeparator}${coord.y}.png',
    );
  }

  Future<void> _writeBrowseTile(TileCoord coord, Uint8List bytes) async {
    final browsing = _browsingRoot;
    if (browsing == null) return;
    try {
      final file = _tileFile(browsing, '', coord);
      await file.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {
      // Caching is best-effort; the map still works from the network.
    }
  }

  /// Downloads every tile covering [bounds] between [minZoom] and [maxZoom]
  /// into a new offline region.
  ///
  /// Throws [OfflineMapUnavailableException] when storage is unavailable,
  /// [OfflineMapBusyException] when a download is already running,
  /// [OfflineMapTooLargeException] when the area exceeds [maxTilesPerRegion]
  /// and [OfflineMapCanceledException] when cancelled through
  /// [cancelDownload]. Partial downloads are discarded on failure.
  Future<OfflineRegion> downloadRegion({
    required String name,
    required LatLngBounds bounds,
    required int minZoom,
    required int maxZoom,
  }) async {
    if (!isAvailable) throw const OfflineMapUnavailableException();
    if (progress.value != null) throw const OfflineMapBusyException();

    final tiles = enumerateTiles(bounds, minZoom, maxZoom);
    if (tiles.length > maxTilesPerRegion) {
      throw OfflineMapTooLargeException(tiles.length);
    }

    final id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final regionDir = Directory(
      '${_regionsRoot!.path}${Platform.pathSeparator}$id',
    );
    await regionDir.create(recursive: true);

    _cancelRequested = false;
    progress.value = OfflineDownloadProgress(
      regionName: name,
      completed: 0,
      total: tiles.length,
      failed: 0,
    );

    final client = http.Client();
    var completed = 0;
    var failed = 0;
    var sizeBytes = 0;

    try {
      final queue = List.of(tiles);

      Future<void> worker() async {
        while (queue.isNotEmpty) {
          if (_cancelRequested) return;
          final coord = queue.removeAt(0);
          try {
            final url = tileUrlTemplate
                .replaceFirst('{z}', '${coord.z}')
                .replaceFirst('{x}', '${coord.x}')
                .replaceFirst('{y}', '${coord.y}');
            final response = await client.get(
              Uri.parse(url),
              headers: _tileHeaders,
            );
            if (response.statusCode == HttpStatus.ok &&
                response.bodyBytes.isNotEmpty) {
              final file = _tileFile(regionDir, '', coord);
              await file.create(recursive: true);
              await file.writeAsBytes(response.bodyBytes, flush: true);
              sizeBytes += response.bodyBytes.length;
            } else {
              failed++;
            }
          } catch (_) {
            failed++;
          }
          completed++;
          progress.value = OfflineDownloadProgress(
            regionName: name,
            completed: completed,
            total: tiles.length,
            failed: failed,
          );
          await Future<void>.delayed(_requestPause);
        }
      }

      await Future.wait([
        for (var i = 0; i < _maxConcurrentRequests; i++) worker(),
      ]);

      if (_cancelRequested) throw const OfflineMapCanceledException();
      if (failed > tiles.length ~/ 2) {
        throw OfflineMapFailedException(failed);
      }

      final region = OfflineRegion(
        id: id,
        name: name,
        west: bounds.west,
        south: bounds.south,
        east: bounds.east,
        north: bounds.north,
        minZoom: minZoom,
        maxZoom: maxZoom,
        tileCount: tiles.length - failed,
        sizeBytes: sizeBytes,
        createdAt: DateTime.now(),
      );
      _regions = [..._regions, region];
      await _saveRegions();
      return region;
    } catch (_) {
      await _deleteDirectory(regionDir);
      rethrow;
    } finally {
      client.close();
      progress.value = null;
      _cancelRequested = false;
    }
  }

  /// Requests cancellation of the running download (if any).
  void cancelDownload() => _cancelRequested = true;

  /// Deletes a saved offline area and its tiles.
  Future<void> deleteRegion(String id) async {
    _regions = _regions.where((r) => r.id != id).toList();
    await _saveRegions();
    final root = _regionsRoot;
    if (root == null) return;
    await _deleteDirectory(
      Directory('${root.path}${Platform.pathSeparator}$id'),
    );
  }

  /// Deletes every offline area and the browsing tile cache.
  Future<void> deleteAll() async {
    _regions = [];
    await _saveRegions();
    await _deleteDirectory(_root);
    if (_root != null) await _root!.create(recursive: true);
  }

  Future<void> _deleteDirectory(Directory? dir) async {
    if (dir == null) return;
    try {
      if (dir.existsSync()) await dir.delete(recursive: true);
    } catch (_) {
      // Leftover files only cost storage; ignore failures.
    }
  }

  // ---------------------------------------------------------------------------
  // Tile math (pure functions, unit tested).
  // ---------------------------------------------------------------------------

  /// Extracts `z/x/y` from a tile URL such as
  /// `https://tile.openstreetmap.org/14/9243/8212.png`.
  static TileCoord? parseTileCoordFromUrl(String url) {
    final match = RegExp(r'/(\d+)/(\d+)/(\d+)\.png(?:\?.*)?$').firstMatch(url);
    if (match == null) return null;
    final z = int.tryParse(match.group(1)!);
    final x = int.tryParse(match.group(2)!);
    final y = int.tryParse(match.group(3)!);
    if (z == null || x == null || y == null || z < 0 || z > 22) return null;
    return (z: z, x: x, y: y);
  }

  /// Number of tiles needed to cover [bounds] from [minZoom] to [maxZoom].
  static int estimateTileCount(LatLngBounds bounds, int minZoom, int maxZoom) {
    var count = 0;
    for (var z = minZoom; z <= maxZoom; z++) {
      final x1 = _lonToTileX(bounds.west, z);
      final x2 = _lonToTileX(bounds.east, z);
      final y1 = _latToTileY(bounds.north, z);
      final y2 = _latToTileY(bounds.south, z);
      final width = (x2 - x1).abs() + 1;
      final height = (y2 - y1).abs() + 1;
      count += width * height;
    }
    return count;
  }

  /// Every tile coordinate covering [bounds] between the two zoom levels.
  static List<TileCoord> enumerateTiles(
    LatLngBounds bounds,
    int minZoom,
    int maxZoom,
  ) {
    final tiles = <TileCoord>[];
    for (var z = minZoom; z <= maxZoom; z++) {
      final x1 = _lonToTileX(bounds.west, z);
      final x2 = _lonToTileX(bounds.east, z);
      final y1 = _latToTileY(bounds.north, z);
      final y2 = _latToTileY(bounds.south, z);
      for (var x = math.min(x1, x2); x <= math.max(x1, x2); x++) {
        for (var y = math.min(y1, y2); y <= math.max(y1, y2); y++) {
          tiles.add((z: z, x: x, y: y));
        }
      }
    }
    return tiles;
  }

  static int _lonToTileX(double lon, int z) {
    final n = math.pow(2, z).toDouble();
    return (((lon + 180) / 360) * n).floor().clamp(0, n.toInt() - 1);
  }

  static int _latToTileY(double lat, int z) {
    const maxLat = 85.05112878;
    final clamped = lat.clamp(-maxLat, maxLat) * math.pi / 180;
    final n = math.pow(2, z).toDouble();
    final y =
        (1 - (math.log(math.tan(clamped) + 1 / math.cos(clamped)) / math.pi)) /
        2;
    return (y * n).floor().clamp(0, n.toInt() - 1);
  }
}

/// [MapCachingProvider] backed by [OfflineMapService]'s tile store.
///
/// Every stored tile is reported as fresh, so flutter_map serves it from
/// disk without a network round-trip and keeps working offline. Tiles are
/// refreshed only by deleting the area (map tiles rarely change).
class _OfflineTileCache implements MapCachingProvider {
  static final CachedMapTileMetadata _alwaysFreshMetadata =
      CachedMapTileMetadata(
        staleAt: DateTime.utc(9999, 12, 31),
        lastModified: null,
        etag: null,
      );

  final OfflineMapService _service;

  _OfflineTileCache(this._service);

  @override
  bool get isSupported => _service.isAvailable;

  @override
  Future<CachedMapTile?> getTile(String url) async {
    if (!isSupported) return null;
    final coord = OfflineMapService.parseTileCoordFromUrl(url);
    if (coord == null) return null;
    final file = _service._findTileFile(coord);
    if (file == null) return null;
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      return (bytes: bytes, metadata: _alwaysFreshMetadata);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> putTile({
    required String url,
    required CachedMapTileMetadata metadata,
    Uint8List? bytes,
  }) async {
    if (!isSupported || bytes == null) return;
    final coord = OfflineMapService.parseTileCoordFromUrl(url);
    if (coord == null) return;
    await _service._writeBrowseTile(coord, bytes);
  }
}
