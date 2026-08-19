import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// One turn-by-turn instruction along a route.
class RouteStep {
  final String instruction;
  final String maneuverType;
  final String maneuverModifier;
  final double distanceMeters;

  const RouteStep({
    required this.instruction,
    required this.maneuverType,
    required this.maneuverModifier,
    required this.distanceMeters,
  });

  String get formattedDistance {
    if (distanceMeters < 1000) return '${distanceMeters.round()} m';
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }
}

/// A route between two points: geometry, distance, duration and steps.
class RouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final List<RouteStep> steps;

  /// True when OSRM was unreachable and a straight-line estimate is shown.
  final bool isFallback;

  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.steps,
    this.isFallback = false,
  });

  String get formattedDistance {
    if (distanceMeters < 1000) return '${distanceMeters.round()} m';
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  String get formattedDuration {
    final minutes = (durationSeconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rem = minutes % 60;
    return '${hours}h ${rem}min';
  }
}

/// Fetches road routes from the public OSRM server (OpenStreetMap data — no
/// API key, no billing, matching the app's decision to avoid Google Maps
/// pricing). Falls back to a straight-line estimate when the service is
/// unreachable so the UI can still show a route.
class RoutingService {
  RoutingService._();
  static final RoutingService instance = RoutingService._();

  static const String _osrmEndpoint = 'https://router.project-osrm.org';
  static const String _userAgent = 'PharmaFinderMobile/1.0 (capstone demo)';

  Future<RouteResult> getRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      final uri = Uri.parse(
        '$_osrmEndpoint/route/v1/driving/'
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}',
      ).replace(queryParameters: {
        'overview': 'full',
        'geometries': 'geojson',
        'steps': 'true',
      });
      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        return _fallbackRoute(origin, destination);
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = json['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        return _fallbackRoute(origin, destination);
      }

      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>;
      final coords = geometry['coordinates'] as List<dynamic>;
      final points = coords
          .map((c) => LatLng(
                (c as List<dynamic>)[1] as double,
                c[0] as double,
              ))
          .toList();

      final steps = <RouteStep>[];
      final legs = route['legs'] as List<dynamic>? ?? const [];
      for (final leg in legs) {
        final legSteps =
            (leg as Map<String, dynamic>)['steps'] as List<dynamic>? ??
                const [];
        for (final raw in legSteps) {
          final step = raw as Map<String, dynamic>;
          final maneuver = step['maneuver'] as Map<String, dynamic>?;
          if (maneuver == null) continue;
          steps.add(RouteStep(
            instruction: _instruction(
              type: maneuver['type']?.toString() ?? '',
              modifier: maneuver['modifier']?.toString() ?? '',
              name: step['name']?.toString() ?? '',
            ),
            maneuverType: maneuver['type']?.toString() ?? '',
            maneuverModifier: maneuver['modifier']?.toString() ?? '',
            distanceMeters: (step['distance'] as num?)?.toDouble() ?? 0,
          ));
        }
      }

      return RouteResult(
        points: points,
        distanceMeters: (route['distance'] as num?)?.toDouble() ?? 0,
        durationSeconds: (route['duration'] as num?)?.toDouble() ?? 0,
        steps: steps,
      );
    } catch (_) {
      return _fallbackRoute(origin, destination);
    }
  }

  RouteResult _fallbackRoute(LatLng origin, LatLng destination) {
    const distance = Distance();
    final meters = distance.as(LengthUnit.Meter, origin, destination);
    return RouteResult(
      points: [origin, destination],
      distanceMeters: meters,
      durationSeconds: meters / (30 * 1000 / 3600),
      steps: [
        RouteStep(
          instruction:
              'Follow a direct path to ${destination.latitude.toStringAsFixed(4)}, '
              '${destination.longitude.toStringAsFixed(4)}',
          maneuverType: 'depart',
          maneuverModifier: 'straight',
          distanceMeters: meters,
        ),
      ],
      isFallback: true,
    );
  }

  String _instruction({
    required String type,
    required String modifier,
    required String name,
  }) {
    final onto = name.isEmpty ? '' : ' onto $name';
    switch (type) {
      case 'depart':
        return name.isEmpty ? 'Start your journey' : 'Head out on $name';
      case 'arrive':
        return 'Arrive at your destination';
      case 'turn':
      case 'end of road':
        if (modifier == 'uturn') return 'Make a U-turn$onto';
        if (modifier == 'straight') return 'Go straight$onto';
        return 'Turn $modifier$onto';
      case 'continue':
        if (modifier == 'uturn') return 'Make a U-turn$onto';
        return 'Continue$onto';
      case 'roundabout':
      case 'rotary':
      case 'roundabout turn':
        return 'At the roundabout, take the exit$onto';
      case 'merge':
        return 'Merge$onto';
      case 'on ramp':
        return 'Take the ramp$onto';
      case 'off ramp':
        return 'Take the exit$onto';
      case 'fork':
        return 'Keep $modifier at the fork$onto';
      case 'new name':
        return 'Continue$onto';
      default:
        return 'Continue$onto';
    }
  }
}
