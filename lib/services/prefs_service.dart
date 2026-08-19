import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A manually-entered location (used by "Enter address manually").
class ManualLocation {
  final LatLng position;
  final String areaName;

  const ManualLocation({required this.position, required this.areaName});
}

/// Where the user last left the map, so reopening starts on the same view.
class SavedMapCamera {
  final LatLng center;
  final double zoom;

  const SavedMapCamera({required this.center, required this.zoom});
}

/// Small persisted-state wrapper around shared_preferences.
///
/// Stores: onboarding-seen flag, recent searches, saved pharmacy ids and an
/// optional manually entered location. The customer app has no accounts, so
/// everything lives on-device.
class PrefsService {
  PrefsService._();
  static final PrefsService instance = PrefsService._();

  static const _kOnboardingDone = 'onboarding_done';
  static const _kRecentSearches = 'recent_searches';
  static const _kSavedPharmacies = 'saved_pharmacies';
  static const _kManualLat = 'manual_lat';
  static const _kManualLng = 'manual_lng';
  static const _kManualArea = 'manual_area';
  static const _kUnit = 'unit';
  static const _kMapLat = 'map_camera_lat';
  static const _kMapLng = 'map_camera_lng';
  static const _kMapZoom = 'map_camera_zoom';

  Future<String> getUnit() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUnit) ?? 'km';
  }

  Future<void> setUnit(String unit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUnit, unit);
  }

  Future<bool> isOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kOnboardingDone) ?? false;
  }

  Future<void> setOnboardingDone(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingDone, value);
  }

  Future<List<String>> getRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kRecentSearches) ?? [];
  }

  Future<void> addRecentSearch(String term) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kRecentSearches) ?? [];
    list.removeWhere((s) => s.toLowerCase() == term.toLowerCase());
    list.insert(0, term);
    if (list.length > 6) list.removeRange(6, list.length);
    await prefs.setStringList(_kRecentSearches, list);
  }

  Future<void> clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRecentSearches);
  }

  Future<Set<String>> getSavedPharmacyIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_kSavedPharmacies) ?? <String>[]).toSet();
  }

  Future<void> toggleSavedPharmacy(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kSavedPharmacies) ?? [];
    if (list.contains(id)) {
      list.remove(id);
    } else {
      list.add(id);
    }
    await prefs.setStringList(_kSavedPharmacies, list);
  }

  Future<bool> isPharmacySaved(String id) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_kSavedPharmacies) ?? []).contains(id);
  }

  Future<ManualLocation?> getManualLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_kManualLat);
    final lng = prefs.getDouble(_kManualLng);
    if (lat == null || lng == null) return null;
    return ManualLocation(
      position: LatLng(lat, lng),
      areaName: prefs.getString(_kManualArea) ?? '',
    );
  }

  Future<void> setManualLocation(ManualLocation location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kManualLat, location.position.latitude);
    await prefs.setDouble(_kManualLng, location.position.longitude);
    await prefs.setString(_kManualArea, location.areaName);
  }

  Future<void> clearManualLocation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kManualLat);
    await prefs.remove(_kManualLng);
    await prefs.remove(_kManualArea);
  }

  Future<SavedMapCamera?> getLastMapCamera() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_kMapLat);
    final lng = prefs.getDouble(_kMapLng);
    final zoom = prefs.getDouble(_kMapZoom);
    if (lat == null || lng == null || zoom == null) return null;
    return SavedMapCamera(center: LatLng(lat, lng), zoom: zoom);
  }

  Future<void> setLastMapCamera({
    required LatLng center,
    required double zoom,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kMapLat, center.latitude);
    await prefs.setDouble(_kMapLng, center.longitude);
    await prefs.setDouble(_kMapZoom, zoom);
  }

  /// Used by the "Sign Out" affordance to reset on-device state.
  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
