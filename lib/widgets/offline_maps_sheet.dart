import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../services/connectivity_service.dart';
import '../services/offline_map_service.dart';
import '../theme/app_theme.dart';

/// Detail presets offered when saving an area. Lower zoom levels are cheap
/// (a handful of tiles) and keep zooming out working offline.
const _detailPresets = <String, ({int minZoom, int maxZoom})>{
  'standard': (minZoom: 3, maxZoom: 13),
  'detailed': (minZoom: 3, maxZoom: 14),
  'high': (minZoom: 3, maxZoom: 15),
};

/// Average compressed OSM tile size used for the download size estimate.
const _avgTileBytes = 18 * 1024;

/// Bottom sheet for downloading the visible map area for offline use and
/// managing previously saved areas. Opened from the map screen.
Future<void> showOfflineMapsSheet(
  BuildContext context, {
  required LatLngBounds visibleBounds,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _OfflineMapsSheet(visibleBounds: visibleBounds),
  );
}

class _OfflineMapsSheet extends StatefulWidget {
  final LatLngBounds visibleBounds;

  const _OfflineMapsSheet({required this.visibleBounds});

  @override
  State<_OfflineMapsSheet> createState() => _OfflineMapsSheetState();
}

class _OfflineMapsSheetState extends State<_OfflineMapsSheet> {
  final _service = OfflineMapService.instance;
  late final TextEditingController _nameController;

  String _preset = 'standard';
  bool _busy = false;
  String? _errorText;
  late List<OfflineRegion> _regions;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: 'Offline area ${_service.regions.length + 1}',
    );
    _regions = _service.regions;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _download() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final detail = _detailPresets[_preset]!;
    setState(() {
      _busy = true;
      _errorText = null;
    });
    try {
      final region = await _service.downloadRegion(
        name: name,
        bounds: widget.visibleBounds,
        minZoom: detail.minZoom,
        maxZoom: detail.maxZoom,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved "${region.name}" for offline use.')),
        );
      }
    } on OfflineMapCanceledException {
      // Silent: the user asked for it.
    } on OfflineMapTooLargeException {
      _errorText =
          'This view is too large to save. Zoom in or choose less detail.';
    } catch (_) {
      _errorText =
          "Couldn't download this area. Check your connection and try again.";
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _regions = _service.regions;
        });
      }
    }
  }

  Future<void> _delete(OfflineRegion region) async {
    await _service.deleteRegion(region.id);
    if (mounted) {
      setState(() => _regions = _service.regions);
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = ConnectivityService.instance.isOnline.value;
    final detail = _detailPresets[_preset]!;
    final tileCount = OfflineMapService.estimateTileCount(
      widget.visibleBounds,
      detail.minZoom,
      detail.maxZoom,
    );
    final tooLarge = tileCount > OfflineMapService.maxTilesPerRegion;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Offline maps',
              style: AppTextStyles.headlineMd.copyWith(
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Save the map area currently on screen so it loads instantly '
              'and works without internet.',
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            if (!_service.isAvailable)
              Text(
                'Offline maps are not available on this device.',
                style: AppTextStyles.bodySm.copyWith(
                  color: AppColors.onErrorContainer,
                ),
              )
            else ...[
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.map_outlined),
                  hintText: 'Name this area',
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'standard', label: Text('Standard')),
                  ButtonSegment(value: 'detailed', label: Text('Detailed')),
                  ButtonSegment(value: 'high', label: Text('High')),
                ],
                selected: {_preset},
                onSelectionChanged: (s) => setState(() => _preset = s.first),
              ),
              const SizedBox(height: 8),
              Text(
                tooLarge
                    ? '~$tileCount tiles — too large to save. Zoom in or pick less detail.'
                    : '~$tileCount tiles '
                          '(about ${_formatBytes(tileCount * _avgTileBytes)}). '
                          'High detail captures street-level zoom.',
                style: AppTextStyles.bodySm.copyWith(
                  color: tooLarge
                      ? AppColors.onErrorContainer
                      : AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<OfflineDownloadProgress?>(
                valueListenable: _service.progress,
                builder: (context, progress, _) {
                  final downloading = progress != null;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (downloading) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Downloading "${progress.regionName}" — '
                                '${progress.completed}/${progress.total} tiles',
                                style: AppTextStyles.bodySm.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _service.cancelDownload,
                              child: const Text('Cancel'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: progress.fraction,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(999),
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 12),
                      ],
                      SizedBox(
                        height: AppSpace.touchTarget,
                        child: FilledButton(
                          onPressed: downloading || _busy || tooLarge || !online
                              ? null
                              : _download,
                          child: Text(
                            downloading ? 'Downloading…' : 'Download this area',
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (!online)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    "You're offline — reconnect to download map areas.",
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              if (_errorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _errorText!,
                    style: AppTextStyles.bodySm.copyWith(
                      color: AppColors.onErrorContainer,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                'SAVED AREAS',
                style: AppTextStyles.labelMd.copyWith(
                  color: AppColors.primary,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 8),
              if (_regions.isEmpty)
                Text(
                  'No offline areas saved yet.',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                )
              else
                for (final region in _regions)
                  _OfflineRegionTile(
                    region: region,
                    onDelete: () => _delete(region),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OfflineRegionTile extends StatelessWidget {
  final OfflineRegion region;
  final Future<void> Function() onDelete;

  const _OfflineRegionTile({required this.region, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final created = region.createdAt;
    final date = '${created.day}/${created.month}/${created.year}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.offline_pin_outlined,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  region.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyLg.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${region.tileCount} tiles • ${region.sizeLabel} • $date',
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              size: 20,
              color: AppColors.outline,
            ),
            tooltip: 'Delete',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
