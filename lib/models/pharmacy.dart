import 'package:cloud_firestore/cloud_firestore.dart';

/// A pharmacy as stored under `pharmacies/{pharmacyId}`.
///
/// Mirrors the web app's schema: profile fields (name, address, city,
/// latitude, longitude, phone) plus operating hours. Open/closed status is
/// derived from the hours, matching the web app's behaviour.
class Pharmacy {
  final String id;
  final String name;
  final String address;
  final String city;
  final String phone;
  final double latitude;
  final double longitude;
  final String status;

  /// Raw hours map: weekdayOpen, weekdayClose, weekendOpen, weekendClose.
  final Map<String, dynamic> hours;

  /// Distance from the user, in km. -1 when unknown.
  final double distanceKm;

  Pharmacy({
    required this.id,
    required this.name,
    this.address = '',
    this.city = '',
    this.phone = '',
    required this.latitude,
    required this.longitude,
    this.status = 'active',
    this.hours = const {},
    this.distanceKm = -1,
  });

  /// Builds a pharmacy from a plain map (Firestore document data or the
  /// on-device cache written by [PharmacyService]).
  factory Pharmacy.fromMap(
    String id,
    Map<String, dynamic> data, {
    double distanceKm = -1,
  }) {
    return Pharmacy(
      id: id,
      name: data['name']?.toString() ?? id,
      address: data['address']?.toString() ?? '',
      city: data['city']?.toString() ?? '',
      phone: (data['emergencyPhone'] ?? data['phone'] ?? '').toString(),
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
      status: data['status']?.toString() ?? 'active',
      hours:
          (data['hours'] as Map<String, dynamic>?) ??
          {
            'weekdayOpen': data['weekdayOpen'],
            'weekdayClose': data['weekdayClose'],
            'weekendOpen': data['weekendOpen'],
            'weekendClose': data['weekendClose'],
          },
      distanceKm: distanceKm,
    );
  }

  factory Pharmacy.fromDocument(
    DocumentSnapshot doc, {
    double distanceKm = -1,
  }) => Pharmacy.fromMap(
    doc.id,
    doc.data() as Map<String, dynamic>? ?? {},
    distanceKm: distanceKm,
  );

  /// True for pharmacies that are active (not suspended/deleted).
  bool get isActive => status == 'active' || status.isEmpty;

  /// True if the pharmacy has usable coordinates.
  bool get hasLocation => latitude != 0 || longitude != 0;

  /// Whether the pharmacy is open right now, derived from operating hours.
  bool get isOpenNow {
    if (!isActive) return false;
    if (hasManualOpenFlag) return _manualOpen;
    final now = DateTime.now();
    final isWeekend =
        now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
    final openStr = (isWeekend ? hours['weekendOpen'] : hours['weekdayOpen'])
        ?.toString();
    final closeStr = (isWeekend ? hours['weekendClose'] : hours['weekdayClose'])
        ?.toString();
    if (openStr == null || closeStr == null || openStr.isEmpty) return false;
    final open = _parseTime(openStr);
    final close = _parseTime(closeStr);
    if (open == null || close == null) return false;

    // A pharmacy that opens and closes at the same time is 24 hours.
    if (open == close) return true;

    final current = now.hour * 60 + now.minute;
    final openMinutes = open.hour * 60 + open.minute;
    final closeMinutes = close.hour * 60 + close.minute;
    if (openMinutes < closeMinutes) {
      return current >= openMinutes && current < closeMinutes;
    }
    return current >= openMinutes || current < closeMinutes;
  }

  bool get hasManualOpenFlag => hours.containsKey('_manualOpen');

  bool get _manualOpen => hours['_manualOpen'] == true;

  String get openStatusText => isOpenNow ? 'Open' : 'Closed';

  /// "Closes at 10:00 PM", "24 Hours", "Opens tomorrow at 8:00 AM", ...
  String get scheduleSummary {
    if (!isActive) return 'Unavailable';
    final isWeekend =
        DateTime.now().weekday == DateTime.saturday ||
        DateTime.now().weekday == DateTime.sunday;
    final openStr = (isWeekend ? hours['weekendOpen'] : hours['weekdayOpen'])
        ?.toString();
    final closeStr = (isWeekend ? hours['weekendClose'] : hours['weekdayClose'])
        ?.toString();
    if (openStr == null || closeStr == null || openStr.isEmpty) {
      return '';
    }
    final open = _parseTime(openStr);
    final close = _parseTime(closeStr);
    if (open == null || close == null) return '';
    if (open == close) return '24 Hours';

    final now = DateTime.now();
    final current = now.hour * 60 + now.minute;
    final openMinutes = open.hour * 60 + open.minute;

    if (isOpenNow) {
      return 'Closes at ${_format12(close)}';
    }
    if (openMinutes > current) {
      return 'Opens today at ${_format12(open)}';
    }
    return 'Opens tomorrow at ${_format12(open)}';
  }

  String get formattedDistance {
    if (distanceKm < 0) return '';
    if (distanceKm < 1) return '${(distanceKm * 1000).round()} m';
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  static _ParsedTime? _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return _ParsedTime(hour, minute);
  }

  static String _format12(_ParsedTime t) {
    final period = t.hour < 12 ? 'AM' : 'PM';
    var h = t.hour % 12;
    if (h == 0) h = 12;
    return '${t.minute == 0 ? h : '$h:${t.minute.toString().padLeft(2, '0')}'} $period';
  }
}

class _ParsedTime {
  final int hour;
  final int minute;
  const _ParsedTime(this.hour, this.minute);

  @override
  bool operator ==(Object other) =>
      other is _ParsedTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}
