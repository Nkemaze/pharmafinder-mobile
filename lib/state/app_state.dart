import 'package:flutter/foundation.dart';

import '../services/location_service.dart';
import '../services/prefs_service.dart';

/// Lightweight shared state for the customer app.
///
/// The main tabs (Home, Nearby, Map) all need the user's location, so it is
/// resolved once and broadcast through [currentLocation]. Falls back to a
/// manually entered address when GPS is unavailable or denied.
class AppState {
  AppState._();
  static final AppState instance = AppState._();

  final LocationService _location = LocationService.instance;
  final PrefsService _prefs = PrefsService.instance;

  /// The resolved user location, or null when none is available.
  final ValueNotifier<UserLocation?> currentLocation = ValueNotifier(null);

  /// True once we have attempted a GPS fix at least once.
  bool gpsAttempted = false;

  /// Whether GPS permission is currently granted.
  Future<bool> gpsEnabled() => _location.hasPermission();

  /// Tries GPS first, then falls back to the saved manual location.
  Future<UserLocation?> resolveLocation() async {
    if (await _location.hasPermission()) {
      gpsAttempted = true;
      final position = await _location.getPosition();
      if (position != null) {
        final area = await _location.reverseGeocode(position);
        final loc = UserLocation(position: position, areaName: area);
        currentLocation.value = loc;
        return loc;
      }
    }

    final manual = await _prefs.getManualLocation();
    if (manual != null) {
      final loc = UserLocation(
        position: manual.position,
        areaName: manual.areaName,
        fromManualEntry: true,
      );
      currentLocation.value = loc;
      return loc;
    }

    currentLocation.value = null;
    return null;
  }

  /// Clears any manual location so GPS is used again.
  Future<void> clearManualLocation() async {
    await _prefs.clearManualLocation();
    if (await _location.hasPermission()) {
      await resolveLocation();
    } else {
      currentLocation.value = null;
    }
  }

  /// Full reset used by "Reset local data": drops the manual location and
  /// any resolved position. GPS will be tried again on the next load.
  Future<void> resetLocation() async {
    await _prefs.clearManualLocation();
    currentLocation.value = null;
  }

  void dispose() {
    currentLocation.dispose();
  }
}
