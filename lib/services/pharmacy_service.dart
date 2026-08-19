import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class PharmacyService {
  PharmacyService._();
  static final PharmacyService instance = PharmacyService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const double earthRadiusKm = 6371;

  CollectionReference get _pharmacies => _db.collection('pharmacies');

  /// In-memory + persisted cache of the raw pharmacy documents. The map and
  /// nearby list render instantly from it while Firestore refreshes in the
  /// background, and it is the data source when the device is offline.
  static const _kPharmaciesCachePref = 'pharmacies_cache_v2';
  static const _pharmaciesCacheTtl = Duration(minutes: 10);
  static const _pharmaciesCacheFields = [
    'id',
    'name',
    'address',
    'city',
    'phone',
    'emergencyPhone',
    'latitude',
    'longitude',
    'status',
    'hours',
    'weekdayOpen',
    'weekdayClose',
    'weekendOpen',
    'weekendClose',
  ];
  List<Map<String, dynamic>>? _pharmaciesCache;
  DateTime? _pharmaciesCacheAt;

  /// All active pharmacies, optionally distance-sorted from [near].
  ///
  /// Serves from the cache when fresh; otherwise fetches Firestore and
  /// updates the cache. If the network fails, falls back to the persisted
  /// cache so the map still shows markers offline.
  Future<List<Pharmacy>> fetchPharmacies({LatLng? near}) async {
    if (_pharmaciesCache != null &&
        _pharmaciesCacheAt != null &&
        DateTime.now().difference(_pharmaciesCacheAt!) < _pharmaciesCacheTtl) {
      return _materializePharmacies(_pharmaciesCache!, near);
    }

    try {
      final snap = await _pharmacies.get();
      final docs = [
        for (final doc in snap.docs)
          _sanitizePharmacyDoc(
            doc.id,
            doc.data() as Map<String, dynamic>? ?? {},
          ),
      ];
      _pharmaciesCache = docs;
      _pharmaciesCacheAt = DateTime.now();
      unawaited(_persistPharmaciesCache(docs));
      return _materializePharmacies(docs, near);
    } catch (_) {
      final persisted = await _loadPersistedPharmacies();
      if (persisted != null) {
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
      final p = Pharmacy.fromMap(
        data['id']?.toString() ?? '',
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

  /// Keeps only the fields the model reads, so the cache is JSON-encodable
  /// regardless of what else documents contain.
  Map<String, dynamic> _sanitizePharmacyDoc(
    String id,
    Map<String, dynamic> data,
  ) {
    final sanitized = <String, dynamic>{'id': id};
    for (final key in _pharmaciesCacheFields) {
      if (key == 'id' || !data.containsKey(key)) continue;
      final value = data[key];
      if (value == null) continue;
      if (value is Map<String, dynamic>) {
        sanitized[key] = {
          for (final e in value.entries)
            if (e.value == null ||
                e.value is String ||
                e.value is bool ||
                e.value is num)
              e.key: e.value,
        };
      } else if (value is String || value is bool || value is num) {
        sanitized[key] = value;
      }
    }
    return sanitized;
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
          if (entry is Map<String, dynamic>) entry,
      ];
    } catch (_) {
      return null;
    }
  }

  Future<Pharmacy?> fetchPharmacy(String id, {LatLng? near}) async {
    final doc = await _pharmacies.doc(id).get();
    if (!doc.exists) return null;
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final lat = (data['latitude'] as num?)?.toDouble() ?? 0;
    final lng = (data['longitude'] as num?)?.toDouble() ?? 0;
    final p = Pharmacy.fromDocument(
      doc,
      distanceKm: near == null ? -1 : distanceKmBetween(near, LatLng(lat, lng)),
    );
    return p.isActive ? p : null;
  }

  /// All drugs in a single pharmacy's inventory.
  Future<List<Drug>> fetchDrugs(String pharmacyId) async {
    final snap = await _pharmacies.doc(pharmacyId).collection('drugs').get();
    return snap.docs
        .map((d) => Drug.fromDocument(d, pharmacyId: pharmacyId))
        .toList();
  }

  /// Search every pharmacy's inventory for [query].
  ///
  /// Uses a case-insensitive, partial (substring) match so "paracetamol",
  /// "PARACETAMOL 500MG" and "amox" all work on the demo dataset.
  Future<List<PharmacySearchResult>> searchDrugs(
    String query, {
    LatLng? near,
  }) async {
    final term = query.trim().toLowerCase();
    if (term.isEmpty) return [];

    final drugsSnap = await _db.collectionGroup('drugs').get();
    final pharmacies = <String, Pharmacy>{};
    final matches = <Drug>[];

    for (final doc in drugsSnap.docs) {
      final drug = Drug.fromDocument(
        doc,
        pharmacyId: doc.reference.parent.parent!.id,
      );
      if (drug.name.toLowerCase().contains(term)) {
        matches.add(drug);
      }
    }

    if (matches.isEmpty) return [];

    final pharmSnap = await _pharmacies.where('name', isNotEqualTo: '').get();
    for (final doc in pharmSnap.docs) {
      final p = Pharmacy.fromDocument(
        doc,
        distanceKm: near == null
            ? -1
            : distanceKmBetween(near, _docLatLng(doc)),
      );
      if (p.isActive) pharmacies[doc.id] = p;
    }

    final results = <PharmacySearchResult>[];
    final byPharmacy = <String, PharmacySearchResult>{};
    for (final drug in matches) {
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

  /// Every distinct drug aggregated across all pharmacies: cheapest price,
  /// stock count and how many pharmacies carry it. Sorted so in-stock
  /// medicines with the widest availability lead.
  ///
  /// Only drugs owned by search-eligible pharmacies (existing, named, active)
  /// are counted, mirroring [searchDrugs]. Orphaned drug subcollections left
  /// behind by deleted pharmacies are ignored so the home list never shows an
  /// "In Stock" medicine that resolves to zero pharmacies.
  Future<List<PopularDrug>> fetchPopularDrugs() async {
    final pharmSnap = await _pharmacies.where('name', isNotEqualTo: '').get();
    final activePharmacies = <String>{
      for (final doc in pharmSnap.docs)
        if (Pharmacy.fromDocument(doc).isActive) doc.id,
    };

    final snap = await _db.collectionGroup('drugs').get();
    final byName = <String, _DrugAggregate>{};
    for (final doc in snap.docs) {
      final pharmacyId = doc.reference.parent.parent!.id;
      if (!activePharmacies.contains(pharmacyId)) continue;
      final drug = Drug.fromDocument(doc, pharmacyId: pharmacyId);
      final agg = byName.putIfAbsent(
        drug.name.toLowerCase(),
        () => _DrugAggregate(name: drug.name, formLabel: drug.formLabel),
      );
      agg.pharmacyIds.add(pharmacyId);
      if (drug.inStock) agg.inStockCount++;
      if (drug.price < agg.cheapest) agg.cheapest = drug.price;
    }

    final drugs = byName.values
        .map(
          (a) => PopularDrug(
            name: a.name,
            formLabel: a.formLabel,
            cheapestPrice: a.cheapest,
            pharmacyCount: a.pharmacyIds.length,
            anyInStock: a.inStockCount > 0,
          ),
        )
        .toList();
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

  static LatLng _docLatLng(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final lat = (data['latitude'] as num?)?.toDouble() ?? 0;
    final lng = (data['longitude'] as num?)?.toDouble() ?? 0;
    return LatLng(lat, lng);
  }
}

class _DrugAggregate {
  final String name;
  final String formLabel;
  double cheapest;
  final Set<String> pharmacyIds;
  int inStockCount;

  _DrugAggregate({required this.name, required this.formLabel})
    : cheapest = double.infinity,
      pharmacyIds = <String>{},
      inStockCount = 0;
}
