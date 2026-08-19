import 'package:url_launcher/url_launcher.dart';

/// Handles external hand-offs: the optional "open in Google Maps" fallback
/// for directions and phone calls via the dialer. In-app directions are
/// handled by DirectionsScreen (OSRM/OpenStreetMap); Google Maps API is
/// deliberately not used (billing requirement).
class LauncherService {
  LauncherService._();

  /// Fallback only: opens the native Google Maps app with turn-by-turn
  /// directions to [latitude],[longitude].
  static Future<bool> directionsTo(double latitude, double longitude) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination='
      '$latitude,$longitude',
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Opens the dialer with [phone] prefilled.
  static Future<bool> call(String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) return false;
    return launchUrl(
      Uri.parse('tel:$digits'),
      mode: LaunchMode.externalApplication,
    );
  }

  /// Opens the default mail app with a prefilled subject/body.
  static Future<bool> email({String subject = '', String body = ''}) {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@pharmafinder.com',
      queryParameters: {
        if (subject.isNotEmpty) 'subject': subject,
        if (body.isNotEmpty) 'body': body,
      },
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
