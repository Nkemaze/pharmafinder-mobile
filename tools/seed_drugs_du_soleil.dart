import 'dart:io';

import 'package:googleapis/firestore/v1.dart' as fs;
import 'package:googleapis_auth/auth_io.dart';

/// Adds a starter inventory of 10 drugs to Pharmacie Du Soleil.
///
/// Runs as an admin (service account) so it bypasses the Firestore security
/// rules, which keep drug writes owner/admin-only.
///
/// Usage:
///   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
///   dart run tools/seed_drugs_du_soleil.dart
///
/// Re-running is safe: documents are patched with fixed ids.
const projectId = 'pharma-finder-6d99d';
const _parent = 'projects/$projectId/databases/(default)/documents';

const _pharmacyId = '2Nb5y62nthbDXd33UZbl2LztWut1'; // Pharmacie Du Soleil

class DrugSeed {
  final String id;
  final String name;
  final String category;
  final int pricePerUnit;
  final int pricePerPacket;
  final int packetSize;
  final String unitLabel;
  final int quantity;
  const DrugSeed(
    this.id,
    this.name,
    this.category,
    this.pricePerUnit,
    this.pricePerPacket,
    this.packetSize,
    this.unitLabel,
    this.quantity,
  );
}

const _drugs = [
  DrugSeed('paracetamol-500', 'Paracetamol 500mg', 'Tablet', 50, 500, 10, 'tablet', 200),
  DrugSeed('ibuprofen-400', 'Ibuprofen 400mg', 'Tablet', 75, 750, 10, 'tablet', 150),
  DrugSeed('amoxicillin-500', 'Amoxicillin 500mg', 'Capsule', 100, 1000, 10, 'capsule', 120),
  DrugSeed('artemether-lumefantrine', 'Artemether-Lumefantrine', 'Tablet', 200, 1200, 6, 'tablet', 80),
  DrugSeed('metronidazole-400', 'Metronidazole 400mg', 'Tablet', 60, 600, 10, 'tablet', 100),
  DrugSeed('omeprazole-20', 'Omeprazole 20mg', 'Capsule', 100, 1400, 14, 'capsule', 90),
  DrugSeed('cetirizine-10', 'Cetirizine 10mg', 'Tablet', 50, 500, 10, 'tablet', 110),
  DrugSeed('vitamin-c-500', 'Vitamin C 500mg', 'Tablet', 45, 450, 10, 'tablet', 180),
  DrugSeed('cough-syrup', 'Cough Syrup', 'Syrup', 1500, 1500, 1, 'bottle', 40),
  DrugSeed('ors-sachet', 'Oral Rehydration Salts', 'Sachet', 150, 600, 4, 'sachet', 130),
];

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

  final pharmacyDoc =
      await api.projects.databases.documents.get('$_parent/pharmacies/$_pharmacyId');
  final name = pharmacyDoc.fields?['name']?.stringValue;
  if (name == null) {
    stderr.writeln('Pharmacy document $_pharmacyId not found.');
    client.close();
    exit(1);
  }
  stderr.writeln('Adding ${_drugs.length} drugs to "$name" ($_pharmacyId) …');

  final expiry = DateTime.now().add(const Duration(days: 365));
  var count = 0;
  for (final d in _drugs) {
    await api.projects.databases.documents.patch(
      fs.Document(
        name: '$_parent/pharmacies/$_pharmacyId/drugs/${d.id}',
        fields: _toFields({
          'name': d.name,
          'category': d.category,
          'pricePerUnit': d.pricePerUnit,
          'pricePerPacket': d.pricePerPacket,
          'packetSize': d.packetSize,
          'unitLabel': d.unitLabel,
          'quantity': d.quantity,
          'expiryDate': expiry,
          'createdAt': DateTime.now().toUtc(),
          'updatedAt': DateTime.now().toUtc(),
        }),
      ),
      '$_parent/pharmacies/$_pharmacyId/drugs/${d.id}',
    );
    stderr.writeln('  ✓ ${d.name} (${d.pricePerUnit} FCFA/unit)');
    count++;
  }

  client.close();
  print('Added $count drugs to $name ($_pharmacyId).');
}

fs.Value _value(dynamic v) {
  if (v == null) return fs.Value(nullValue: 'NULL_VALUE');
  if (v is String) return fs.Value(stringValue: v);
  if (v is bool) return fs.Value(booleanValue: v);
  if (v is int) return fs.Value(integerValue: v.toString());
  if (v is double) return fs.Value(doubleValue: v);
  if (v is DateTime) {
    return fs.Value(timestampValue: v.toUtc().toIso8601String());
  }
  throw ArgumentError('Unsupported value type: ${v.runtimeType}');
}

Map<String, fs.Value> _toFields(Map<String, dynamic> map) {
  return {
    for (final entry in map.entries) entry.key: _value(entry.value),
  };
}
