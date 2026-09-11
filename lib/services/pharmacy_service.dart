import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models/drug.dart';
import '../models/pharmacy.dart';
import '../models/popular_drug.dart';

/// A pharmacy that stocks at least one matching drug, for search results.
class PharmacySearchResult {
  final Pharmacy pharmacy;
  final List<Drug> drugs;

  PharmacySearchResult({required this.pharmacy, required this.drugs});

  bool get anyInStock => drugs.any((d) => d.inStock);

  Drug get bestDrug {
    final inStock = drugs.where((d) => d.inStock).toList();
    if (inStock.isNotEmpty) {
      inStock.sort((a, b) => a.price.compareTo(b.price));
      return inStock.first;
    }
    drugs.sort((a, b) => a.price.compareTo(b.price));
    return drugs.first;
  }
}

/// Data access layer for the customer app, backed by the hosted PharmaTrack
/// REST API (`ApiConfig.apiBase`) instead of Firestore.
///
/// Caching contract mirrors the old implementation: the pharmacy list is
/// cached in memory (10-minute TTL) and persisted to disk via
/// SharedPreferences, so the map and nearby list render instantly and still
/// work offline. Drug listings and search are always fetched fresh.
class PharmacyService {
  PharmacyService._();
  static final PharmacyService instance = PharmacyService._();

  static const double earthRadiusKm = 6371;
  static const Duration _timeout = Duration(seconds: 15);

  static const _kPharmaciesCachePref = 'pharmacies_cache_v3';
  static const _pharmaciesCacheTtl = Duration(minutes: 10);

  /// In-memory + persisted cache of the raw pharmacy maps (API shape,
  /// snake_case keys). The map and nearby list render instantly from it
  /// while the API refreshes in the background, and it is the data source
  /// when the device is offline.
  List<Map<String, dynamic>>? _pharmaciesCache;
  DateTime? _pharmaciesCacheAt;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${ApiConfig.apiBase}$path').replace(queryParameters: query);

  /// Fire an HTTP GET, retrying once on timeout / transient error.
  Future<http.Response> _getWithRetry(Uri url) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final res = await http
            .get(url, headers: const {'Accept': 'application/json'})
            .timeout(_timeout);
        return res;
      } on TimeoutException {
        if (attempt == 1) rethrow;
      }
    }
    throw StateError('unreachable');
  }

  Future<Map<String, dynamic>> _getJson(String path,
      [Map<String, String>? query]) async {
    final res = await _getWithRetry(_uri(path, query));
    if (res.statusCode == 404) {
      throw _NotFound();
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw http.ClientException(
          'API ${res.statusCode} for $path', res.request?.url);
    }
    final body = utf8.decode(res.bodyBytes);
    return jsonDecode(body) as Map<String, dynamic>;
  }

  /// All active pharmacies, optionally distance-sorted from [near].
  ///
  /// Serves from the cache when fresh; otherwise fetches `/pharmacies` and
  /// updates the cache. If the network fails, falls back to the persisted
  /// cache so the map still shows markers offline.
  Future<List<Pharmacy>> fetchPharmacies({LatLng? near}) async {
    if (_pharmaciesCache != null &&
        _pharmaciesCacheAt != null &&
        DateTime.now().difference(_pharmaciesCacheAt!) < _pharmaciesCacheTtl) {
      return _materializePharmacies(_pharmaciesCache!, near);
    }

    try {
      final data = await _getJson('/pharmacies');
      final docs = [
        for (final raw in (data['pharmacies'] as List? ?? []))
          if (raw is Map<String, dynamic>) Map<String, dynamic>.from(raw),
      ];
      _pharmaciesCache = docs;
      _pharmaciesCacheAt = DateTime.now();
      unawaited(_persistPharmaciesCache(docs));
      return _materializePharmacies(docs, near);
    } catch (_) {
      final persisted = await _loadPersistedPharmacies();
      if (persisted != null && persisted.isNotEmpty) {
        _pharmaciesCache = persisted;
        _pharmaciesCacheAt = DateTime.now();
        return _materializePharmacies(persisted, near);
      }
      rethrow;
    }
  }

  List<Pharmacy> _materializePharmacies(
    List<Map<String, dynamic>> docs,
    LatLng? near,
  ) {
    final pharmacies = <Pharmacy>[];
    for (final data in docs) {
      final lat = (data['latitude'] as num?)?.toDouble() ?? 0;
      final lng = (data['longitude'] as num?)?.toDouble() ?? 0;
      final p = Pharmacy.fromJson(
        data,
        distanceKm: near == null
            ? -1
            : distanceKmBetween(near, LatLng(lat, lng)),
      );
      if (p.isActive) pharmacies.add(p);
    }
    if (near != null) {
      pharmacies.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    }
    return pharmacies;
  }

  Future<void> _persistPharmaciesCache(List<Map<String, dynamic>> docs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPharmaciesCachePref, jsonEncode(docs));
    } catch (_) {
      // Caching is best-effort; the network path still works.
    }
  }

  Future<List<Map<String, dynamic>>?> _loadPersistedPharmacies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPharmaciesCachePref);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return [
        for (final entry in decoded)
          if (entry is Map<String, dynamic>) Map<String, dynamic>.from(entry),
      ];
    } catch (_) {
      return null;
    }
  }

  Future<Pharmacy?> fetchPharmacy(String id, {LatLng? near}) async {
    try {
      final data = await _getJson('/pharmacies/$id');
      final raw = data['pharmacy'];
      if (raw is! Map<String, dynamic>) return null;
      final lat = (raw['latitude'] as num?)?.toDouble() ?? 0;
      final lng = (raw['longitude'] as num?)?.toDouble() ?? 0;
      final p = Pharmacy.fromJson(
        raw,
        distanceKm: near == null ? -1 : distanceKmBetween(near, LatLng(lat, lng)),
      );
      return p.isActive ? p : null;
    } on _NotFound {
      return null;
    }
  }

  /// All drugs in a single pharmacy's inventory (`/pharmacies/<id>/products`).
  Future<List<Drug>> fetchDrugs(String pharmacyId) async {
    final data = await _getJson('/pharmacies/$pharmacyId/products');
    return [
      for (final raw in (data['products'] as List? ?? []))
        if (raw is Map<String, dynamic>) Drug.fromJson(raw),
    ];
  }

  /// Search every pharmacy's inventory for [query].
  ///
  /// The API matches case-insensitively and partially server-side, so
  /// "paracetamol", "PARACETAMOL 500MG" and "amox" all work.
  Future<List<PharmacySearchResult>> searchDrugs(
    String query, {
    LatLng? near,
  }) async {
    final term = query.trim().toLowerCase();
    if (term.isEmpty) return [];

    final data = await _getJson('/products/search', {'q': term});
    final drugs = <Drug>[
      for (final raw in (data['products'] as List? ?? []))
        if (raw is Map<String, dynamic>) Drug.fromJson(raw),
    ];
    if (drugs.isEmpty) return [];

    final pharmacies = await _fetchActiveById(near: near);
    if (pharmacies.isEmpty) return [];

    final results = <PharmacySearchResult>[];
    final byPharmacy = <String, PharmacySearchResult>{};
    for (final drug in drugs) {
      final pharmacy = pharmacies[drug.pharmacyId];
      if (pharmacy == null) continue;
      final result = byPharmacy.putIfAbsent(
        drug.pharmacyId,
        () => PharmacySearchResult(pharmacy: pharmacy, drugs: []),
      );
      result.drugs.add(drug);
    }
    results.addAll(byPharmacy.values);

    if (near != null) {
      results.sort(
        (a, b) => a.pharmacy.distanceKm.compareTo(b.pharmacy.distanceKm),
      );
    }
    return results;
  }

  /// Map of active pharmacy id -> Pharmacy, reused by search and detail.
  Future<Map<String, Pharmacy>> _fetchActiveById({LatLng? near}) async {
    final pharmacies = await fetchPharmacies(near: near);
    return {for (final p in pharmacies) p.id: p};
  }

  /// Every distinct drug aggregated across all pharmacies: cheapest price,
  /// stock count and how many pharmacies carry it. Sorted so in-stock
  /// medicines with the widest availability lead. Backed by
  /// `/products/popular`.
  Future<List<PopularDrug>> fetchPopularDrugs() async {
    final data = await _getJson('/products/popular');
    final drugs = <PopularDrug>[
      for (final raw in (data['products'] as List? ?? []))
        if (raw is Map<String, dynamic>) PopularDrug.fromJson(raw),
    ];
    drugs.sort((a, b) {
      if (a.anyInStock != b.anyInStock) return a.anyInStock ? -1 : 1;
      return b.pharmacyCount.compareTo(a.pharmacyCount);
    });
    return drugs;
  }

  /// Haversine distance in kilometres.
  static double distanceKmBetween(LatLng a, LatLng b) {
    return const Distance().as(LengthUnit.Kilometer, a, b);
  }
}

class _NotFound implements Exception {
  const _NotFound();
}