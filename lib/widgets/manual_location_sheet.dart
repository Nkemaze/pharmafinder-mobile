import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../services/location_service.dart';
import '../services/prefs_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Bottom sheet for "Enter address manually": forward-geocodes a free-text
/// address via Nominatim and stores it as the user's location.
Future<void> showManualLocationSheet(BuildContext context) async {
  final controller = TextEditingController();
  var busy = false;

  Future<void> submit() async {
    final address = controller.text.trim();
    if (address.isEmpty) return;
    busy = true;
    final position =
        await LocationService.instance.forwardGeocode(address);
    if (position == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not find that address. Try another.'),
          ),
        );
      }
      busy = false;
      return;
    }
    await PrefsService.instance.setManualLocation(
      ManualLocation(position: position, areaName: address),
    );
    await AppState.instance.resolveLocation();
    if (context.mounted) Navigator.of(context).pop();
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
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
                const SizedBox(height: 24),
                Text(
                  'Enter your location',
                  style: AppTextStyles.headlineMd.copyWith(color: AppColors.onSurface),
                ),
                const SizedBox(height: 8),
                Text(
                  'Type a neighbourhood, street or town in Cameroon.',
                  style: AppTextStyles.bodySm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => submit(),
                  decoration: InputDecoration(
                    hintText: 'e.g. Molyko, Buea',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: AppSpace.touchTarget,
                  child: FilledButton(
                    onPressed: busy ? null : submit,
                    child: busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onPrimary,
                            ),
                          )
                        : const Text('Use this location'),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// Confirms the GPS coordinates as a manual location (used by the map's
/// "set here" affordance).
Future<void> saveCoordinatesAsLocation(
  BuildContext context,
  LatLng position, {
  required String areaName,
}) async {
  await PrefsService.instance.setManualLocation(
    ManualLocation(position: position, areaName: areaName),
  );
  await AppState.instance.resolveLocation();
}
