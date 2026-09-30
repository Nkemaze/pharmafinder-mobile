import 'package:customer_mobile_app/models/pharmacy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses API coordinates supplied as numeric strings', () {
    final pharmacy = Pharmacy.fromJson({
      'id': 'citycare',
      'name': 'CityCare Pharmacy',
      'latitude': '9.0784',
      'longitude': '7.4646',
    });

    expect(pharmacy.latitude, 9.0784);
    expect(pharmacy.longitude, 7.4646);
    expect(pharmacy.hasLocation, isTrue);
  });
}
