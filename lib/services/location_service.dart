import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// A resolved user location: coordinates plus a short human-readable area
/// name (e.g. "Molyko, Buea") from Nominatim reverse geocoding.
class UserLocation {
  final LatLng position;
  final String areaName;
  final bool fromManualEntry;

  const UserLocation({
    required this.position,
    required this.areaName,
    this.fromManualEntry = false,
  });
}

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  static const String _nominatimEndpoint =
      'https://nominatim.openstreetmap.org';
  static const String _userAgent = 'PharmaFinderMobile/1.0 (capstone demo)';

  /// Checks the current location permission.
  Future<bool> hasPermission() async {
    return await Geolocator.checkPermission() == LocationPermission.always ||
        await Geolocator.checkPermission() == LocationPermission.whileInUse;
  }

  /// Requests location permission; returns true when granted.
  Future<bool> requestPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Gets the device position (permission must already be granted).
  Future<LatLng?> getPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Resolves the user's current location and a short area name for it.
  Future<UserLocation?> getCurrentLocation() async {
    if (!await hasPermission()) return null;
    final position = await getPosition();
    if (position == null) return null;
    final area = await reverseGeocode(position);
    return UserLocation(position: position, areaName: area);
  }

  /// Reverse geocodes coordinates to a short area name like "Molyko, Buea".
  ///
  /// Fails gracefully to an empty string when offline so the app still works.
  Future<String> reverseGeocode(LatLng pos) async {
    try {
      final uri = Uri.parse('$_nominatimEndpoint/reverse').replace(
        queryParameters: {
          'lat': pos.latitude.toString(),
          'lon': pos.longitude.toString(),
          'format': 'jsonv2',
          'zoom': '16',
        },
      );
      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return '';
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final address = json['address'] as Map<String, dynamic>?;
      if (address == null) return '';

      String? first =
          (address['suburb'] ??
                  address['neighbourhood'] ??
                  address['city_district'] ??
                  address['quarter'])
              ?.toString();
      final city = (address['city'] ??
              address['town'] ??
              address['village'] ??
              address['municipality'])
          ?.toString();

      final parts = <String>[];
      if (first != null && first.isNotEmpty && !_allDigits(first)) {
        parts.add(first);
      }
      if (city != null && city.isNotEmpty) parts.add(city);
      if (parts.isEmpty) {
        first = (json['display_name'] as String?) ?? '';
        if (first.isNotEmpty) parts.add(first.split(',').first);
      }
      return parts.join(', ');
    } catch (_) {
      return '';
    }
  }

  static bool _allDigits(String s) => s.trim().isNotEmpty && s.trim().split('').every((c) => RegExp(r'[0-9]').hasMatch(c));

  /// Forward geocodes a free-text address to coordinates (Nominatim search).
  Future<LatLng?> forwardGeocode(String address) async {
    try {
      final uri = Uri.parse('$_nominatimEndpoint/search').replace(
        queryParameters: {
          'q': address,
          'format': 'jsonv2',
          'limit': '1',
          'countrycodes': 'cm',
        },
      );
      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final list = jsonDecode(response.body) as List<dynamic>;
      if (list.isEmpty) return null;
      final first = list.first as Map<String, dynamic>;
      return LatLng(
        double.parse(first['lat'].toString()),
        double.parse(first['lon'].toString()),
      );
    } catch (_) {
      return null;
    }
  }
}
