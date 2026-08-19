import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:googleapis/firestore/v1.dart' as fs;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

/// Seeds pharmacies from the CSV into Firebase Auth + Firestore.
///
/// Creates a Firebase Auth account via the Identity Toolkit REST API and a
/// Firestore `pharmacies/{uid}` document for each valid entry.
///
/// Usage:
///   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
///   dart run tools/seed_csv_pharmacies.dart
const projectId = 'pharma-finder-6d99d';
const _apiKey = 'AIzaSyBHMSG8wxlbrGORU-X_Id9wzI6J4CI9ws8';
const _parent = 'projects/$projectId/databases/(default)/documents';

// ── Existing demo pharmacies in Abuja that must be removed ─────────────────────
const _abujaDemoIds = [
  'demo-pharm-01',
  'demo-pharm-02',
  'demo-pharm-03',
  'demo-pharm-04',
  'demo-pharm-05',
  'demo-pharm-06',
  'demo-pharm-07',
  'demo-pharm-08',
];

Future<void> main() async {
  // ── 1. Load service account credentials ───────────────────────────────────────
  final credPath = Platform.environment['GOOGLE_APPLICATION_CREDENTIALS'];
  if (credPath == null) {
    stderr.writeln(
      'Set GOOGLE_APPLICATION_CREDENTIALS to your service-account JSON.',
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

  // ── 2. Remove existing Abuja demo pharmacies from Firestore ───────────────────
  stderr.writeln('Removing ${_abujaDemoIds.length} Abuja demo pharmacies …');
  for (final id in _abujaDemoIds) {
    try {
      await api.projects.databases.documents
          .delete('$_parent/pharmacies/$id');
      stderr.writeln('  Deleted $id');
    } catch (e) {
      // 404 is fine – document may already be gone.
      stderr.writeln('  Skipped $id ($e)');
    }
  }

  // ── 3. Parse CSV ──────────────────────────────────────────────────────────────
  final csvFile = File('pharmacies-yaounde.csv');
  if (!csvFile.existsSync()) {
    stderr.writeln('CSV file not found: pharmacies-yaounde.csv');
    exit(1);
  }
  final lines = csvFile.readAsLinesSync();
  if (lines.length < 2) {
    stderr.writeln('CSV is empty or has no data rows.');
    exit(1);
  }

  final headers = lines.first.split(',');
  final rows = lines.skip(1).map((line) {
    final values = line.split(',');
    return {
      for (var i = 0; i < headers.length; i++)
        headers[i]: i < values.length ? values[i].trim() : '',
    };
  }).toList();

  // ── 4. Create Auth accounts + Firestore documents ─────────────────────────────
  final random = math.Random.secure();
  final credentials = <Map<String, String>>[];
  final http.Client authClient = http.Client();

  final validRows = rows.where((row) {
    final lat = double.tryParse(row['latitude'] ?? '');
    final lon = double.tryParse(row['longitude'] ?? '');
    return lat != null && lon != null && lat != 0 && lon != 0;
  }).toList();

  stderr.writeln(
    '\nProcessing ${validRows.length} pharmacies with coordinates …\n',
  );

  for (final row in validRows) {
    final name = row['name'] ?? 'Unnamed';
    final email = _generateEmail(name);
    final password = _generatePassword(random);
    final lat = double.parse(row['latitude']!);
    final lon = double.parse(row['longitude']!);

    try {
      // Create Firebase Auth account via Identity Toolkit REST API.
      final signUpUri = Uri.parse(
        'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$_apiKey',
      );
      final signUpRes = await authClient.post(
        signUpUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'returnSecureToken': true,
        }),
      );
      final signUpBody =
          jsonDecode(signUpRes.body) as Map<String, dynamic>;
      if (signUpRes.statusCode != 200) {
        final raw = (signUpBody['error']?['message'] as String?) ?? 'Unknown';
        stderr.writeln('  ✗ $name — Auth error: $raw');
        continue;
      }
      final uid = signUpBody['localId'] as String;

      // Write Firestore document.
      await api.projects.databases.documents.patch(
        fs.Document(
          name: '$_parent/pharmacies/$uid',
          fields: _toFields({
            'name': name,
            'email': email,
            'phone': row['phone'] ?? '',
            'address': row['location'] ?? '',
            'latitude': lat,
            'longitude': lon,
            'status': 'active',
            'mustUpdateProfile': false,
            'createdAt': DateTime.now().toUtc().toIso8601String(),
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          }),
        ),
        '$_parent/pharmacies/$uid',
      );

      credentials.add({
        'name': name,
        'email': email,
        'password': password,
        'uid': uid,
      });

      stderr.writeln('  ✓ $name ($email)');
    } catch (e) {
      stderr.writeln('  ✗ $name — $e');
    }
  }

  authClient.close();

  // ── 5. Write credentials file ───────────────────────────────────────────────
  final credentialsFile = File('tools/pharmacy_credentials.csv');
  final csvBuffer = StringBuffer('name,email,password,uid\n');
  for (final c in credentials) {
    csvBuffer.writeln('${c['name']},${c['email']},${c['password']},${c['uid']}');
  }
  credentialsFile.writeAsStringSync(csvBuffer.toString());
  stderr.writeln(
    '\n✓ Credentials written to tools/pharmacy_credentials.csv '
    '(${credentials.length} pharmacies)',
  );

  // ── 6. Write removed pharmacies file ─────────────────────────────────────────
  final removedFile = File('tools/removed_pharmacies.txt');
  final removedBuffer = StringBuffer();
  removedBuffer.writeln('=== Pharmacies Removed from Firestore ===');
  removedBuffer.writeln('All pharmacies in this list were in Abuja, Nigeria');
  removedBuffer.writeln('(outside Cameroon) and have been deleted.\n');
  for (final id in _abujaDemoIds) {
    removedBuffer.writeln('  $id');
  }
  removedBuffer.writeln('\nTotal removed: ${_abujaDemoIds.length}');
  removedFile.writeAsStringSync(removedBuffer.toString());
  stderr.writeln(
    '✓ Removed pharmacies list written to tools/removed_pharmacies.txt',
  );

  client.close();
  stderr.writeln('\nDone.');
}

/// Generates a stable email from a pharmacy name.
String _generateEmail(String name) {
  final slug = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '')
      .replaceAll('--', '-');
  return '$slug@pharmafinder.com';
}

/// Generates a random 10-character password.
String _generatePassword(math.Random random) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
  return List.generate(10, (_) => chars[random.nextInt(chars.length)]).join();
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
