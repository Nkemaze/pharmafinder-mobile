import 'dart:io';
import 'dart:math' as math;

import 'package:googleapis/firestore/v1.dart' as fs;
import 'package:googleapis_auth/auth_io.dart';

/// Seeds demo pharmacies and inventories into Firestore.
///
/// The Firestore security rules keep writes owner/admin-only, so this runs as
/// an admin (service account) which bypasses the rules.
///
/// Usage:
///   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
///   dart run tools/seed_data.dart
///
/// Re-running the script replaces the demo data (existing demo docs are
/// removed first, so the result is identical every time).
const projectId = 'pharma-finder-6d99d';
const _parent = 'projects/$projectId/databases/(default)/documents';

Future<void> main() async {
  final credPath = Platform.environment['GOOGLE_APPLICATION_CREDENTIALS'];
  if (credPath == null) {
    stderr.writeln(
      'Set GOOGLE_APPLICATION_CREDENTIALS to your service account JSON.',
    );
    exit(1);
  }

  final cred = ServiceAccountCredentials.fromJson(
    File(credPath).readAsStringSync(),
  );
  final client = await clientViaServiceAccount(
    cred,
    [fs.FirestoreApi.cloudPlatformScope],
  );
  final api = fs.FirestoreApi(client);

  // 1. Remove any existing demo pharmacy docs so the seed is idempotent.
  //    (Drug subcollections are re-written below with the same fixed ids.)
  for (final seed in seedPharmacies) {
    try {
      await api.projects.databases.documents
          .delete('$_parent/pharmacies/${seed.id}');
    } catch (_) {
      // Missing doc (404) is fine — nothing to clean.
    }
  }

  // 2. Write all seed pharmacies + drugs.
  var drugCount = 0;
  for (final seed in seedPharmacies) {
    await api.projects.databases.documents.patch(
      fs.Document(
        name: '$_parent/pharmacies/${seed.id}',
        fields: _toFields(seed.data),
      ),
      '$_parent/pharmacies/${seed.id}',
    );
    for (final drug in seed.drugs) {
      await api.projects.databases.documents.patch(
        fs.Document(
          name: '$_parent/pharmacies/${seed.id}/drugs/${drug.id}',
          fields: _toFields(drug.data),
        ),
        '$_parent/pharmacies/${seed.id}/drugs/${drug.id}',
      );
      drugCount++;
    }
  }

  client.close();
  print('Seeded ${seedPharmacies.length} pharmacies and $drugCount drugs.');
}

fs.Value _value(dynamic v) {
  if (v == null) return fs.Value(nullValue: 'NULL_VALUE');
  if (v is String) return fs.Value(stringValue: v);
  if (v is bool) return fs.Value(booleanValue: v);
  if (v is int) return fs.Value(integerValue: v.toString());
  if (v is double) return fs.Value(doubleValue: v);
  if (v is Map) {
    return fs.Value(
      mapValue: fs.MapValue(fields: _toFields(v.cast<String, dynamic>())),
    );
  }
  if (v is List) {
    return fs.Value(
      arrayValue: fs.ArrayValue(values: [for (final e in v) _value(e)]),
    );
  }
  if (v is DateTime) return fs.Value(timestampValue: v.toUtc().toIso8601String());
  throw ArgumentError('Unsupported value type: ${v.runtimeType}');
}

Map<String, fs.Value> _toFields(Map<String, dynamic> map) {
  return {
    for (final entry in map.entries) entry.key: _value(entry.value),
  };
}

class SeedPharmacy {
  final String id;
  final Map<String, dynamic> data;
  final List<SeedDrug> drugs;

  const SeedPharmacy({
    required this.id,
    required this.data,
    required this.drugs,
  });
}

class SeedDrug {
  final String id;
  final Map<String, dynamic> data;

  const SeedDrug({required this.id, required this.data});
}

class DrugSeed {
  final String id;
  final String name;
  final String category;
  final int pricePerUnit;
  final int pricePerPacket;
  final int packetSize;
  final int quantity;
  const DrugSeed(this.id, this.name, this.category, this.pricePerUnit,
      this.pricePerPacket, this.packetSize, this.quantity);
}

// Abuja, Nigeria demo data (matches the app's default map centre).
List<SeedPharmacy> get seedPharmacies {
  final out = <SeedPharmacy>[];
  for (final p in _pharmacySeeds) {
    out.add(SeedPharmacy(id: p.id, data: p.data, drugs: _drugsFor(p)));
  }
  return out;
}

class _PharmacySeed {
  final String id;
  final String name;
  final String address;
  final String city;
  final double lat;
  final double lng;
  final Map<String, dynamic> hours;
  const _PharmacySeed({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.lat,
    required this.lng,
    required this.hours,
  });

  Map<String, dynamic> get data => {
        'name': name,
        'address': address,
        'city': city,
        'license':
            'PH${id.hashCode.abs().toString().padLeft(6, '0').substring(0, 6)}',
        'email': '${id.replaceAll('-', '')}@gmail.com',
        'emergencyPhone': '0803 000 0000',
        'latitude': lat,
        'longitude': lng,
        'status': 'active',
        'hours': hours,
        'demo': true,
      };
}

const _pharmacySeeds = [
  _PharmacySeed(
    id: 'demo-pharm-01',
    name: 'CityCare Pharmacy',
    address: '12 Aminu Kano Crescent, Wuse II',
    city: 'Abuja',
    lat: 9.0784,
    lng: 7.4646,
    hours: {
      'weekdayOpen': '08:00',
      'weekdayClose': '22:00',
      'weekendOpen': '09:00',
      'weekendClose': '21:00',
    },
  ),
  _PharmacySeed(
    id: 'demo-pharm-02',
    name: 'MedPlus Health Store',
    address: 'Plot 54, Adetokunbo Ademola Crescent, Wuse II',
    city: 'Abuja',
    lat: 9.0725,
    lng: 7.4879,
    hours: {
      'weekdayOpen': '07:00',
      'weekdayClose': '23:00',
      'weekendOpen': '08:00',
      'weekendClose': '22:00',
    },
  ),
  _PharmacySeed(
    id: 'demo-pharm-03',
    name: 'Sunshine Pharmacy',
    address: '3 Gimbiya Street, Area 11, Garki',
    city: 'Abuja',
    lat: 9.0358,
    lng: 7.4888,
    hours: {
      'weekdayOpen': '08:30',
      'weekdayClose': '20:30',
      'weekendOpen': '10:00',
      'weekendClose': '18:00',
    },
  ),
  _PharmacySeed(
    id: 'demo-pharm-04',
    name: 'Greenleaf Chemists',
    address: '21 Ahmadu Bello Way, Garki II',
    city: 'Abuja',
    lat: 9.0419,
    lng: 7.4934,
    hours: {
      'weekdayOpen': '09:00',
      'weekdayClose': '21:00',
      'weekendOpen': '10:00',
      'weekendClose': '20:00',
    },
  ),
  _PharmacySeed(
    id: 'demo-pharm-05',
    name: 'Evercare Pharmacy',
    address: '9 Gana Street, Maitama',
    city: 'Abuja',
    lat: 9.0860,
    lng: 7.4968,
    hours: {
      'weekdayOpen': '08:00',
      'weekdayClose': '20:00',
      'weekendOpen': '09:00',
      'weekendClose': '17:00',
    },
  ),
  _PharmacySeed(
    id: 'demo-pharm-06',
    name: 'Trustwell Pharmacy',
    address: '15 Abuja City Centre, Asokoro',
    city: 'Abuja',
    lat: 9.0513,
    lng: 7.5066,
    hours: {
      'weekdayOpen': '07:30',
      'weekdayClose': '21:30',
      'weekendOpen': '08:00',
      'weekendClose': '20:00',
    },
  ),
  _PharmacySeed(
    id: 'demo-pharm-07',
    name: 'PharmaMart Express',
    address: 'Plot 1161, Adetokunbo Ademola Crescent, Wuse II',
    city: 'Abuja',
    lat: 9.0766,
    lng: 7.4777,
    hours: {
      'weekdayOpen': '00:00',
      'weekdayClose': '00:00',
      'weekendOpen': '00:00',
      'weekendClose': '00:00',
    },
  ),
  _PharmacySeed(
    id: 'demo-pharm-08',
    name: 'Hope Clinic Pharmacy',
    address: '8 Abidjan Street, Wuse Zone 3',
    city: 'Abuja',
    lat: 9.0733,
    lng: 7.4585,
    hours: {
      'weekdayOpen': '08:00',
      'weekdayClose': '18:00',
      'weekendOpen': '09:00',
      'weekendClose': '14:00',
    },
  ),
];

const _drugSeeds = [
  DrugSeed('d-paracetamol', 'Paracetamol', 'Tablet', 100, 500, 10, 120),
  DrugSeed('d-ibuprofen', 'Ibuprofen', 'Tablet', 150, 700, 8, 80),
  DrugSeed('d-amoxicillin', 'Amoxicillin 500mg', 'Capsule', 200, 1000, 10, 60),
  DrugSeed('d-metformin', 'Metformin 500mg', 'Tablet', 120, 600, 12, 100),
  DrugSeed('d-artemether', 'Artemether-Lumefantrine', 'Tablet', 250, 1200, 6, 40),
  DrugSeed('d-cough-syrup', 'Cough Syrup', 'Syrup', 800, 800, 1, 30),
  DrugSeed('d-vit-c', 'Vitamin C', 'Tablet', 180, 900, 10, 150),
  DrugSeed('d-ors', 'Oral Rehydration Salts', 'Sachet', 200, 800, 4, 90),
  DrugSeed('d-chloroquine', 'Chloroquine', 'Tablet', 100, 500, 6, 70),
  DrugSeed('d-prednisolone', 'Prednisolone', 'Tablet', 150, 750, 5, 45),
  DrugSeed('d-glucose', 'Dextrose (Glucose)', 'Drip', 1500, 1500, 1, 20),
  DrugSeed('d-zinc', 'Zinc Sulphate', 'Tablet', 90, 450, 10, 110),
];

List<SeedDrug> _drugsFor(_PharmacySeed p) {
  final seed = math.Random(p.id.hashCode);
  final core = _drugSeeds.take(4).toList();
  final extra = List.of(_drugSeeds.skip(4));
  extra.shuffle(seed);
  final count = 8 + seed.nextInt(3);
  final drugs = [...core, ...extra.take(count - core.length)];

  return [
    for (final d in drugs)
      SeedDrug(
        id: d.id,
        data: {
          'name': d.name,
          'pricePerUnit': d.pricePerUnit,
          'pricePerPacket': d.pricePerPacket,
          'packetSize': d.packetSize,
          'unitLabel':
              d.category == 'Syrup' || d.category == 'Drip' ? 'bottle' : 'unit',
          'quantity': d.quantity,
          'category': d.category,
          'expiryDate': DateTime.now().add(const Duration(days: 300)),
          'demo': true,
        },
      ),
  ];
}
