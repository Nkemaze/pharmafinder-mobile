import 'package:cloud_firestore/cloud_firestore.dart';

/// A drug from a pharmacy's inventory
/// (`pharmacies/{pharmacyId}/drugs/{drugId}`).
///
/// Mirrors the web app's drug schema: name, pricePerUnit, pricePerPacket,
/// packetSize, unitLabel, quantity, category, expiryDate, imageUrl.
class Drug {
  final String id;

  /// Id of the owning `pharmacies/{pharmacyId}` document.
  final String pharmacyId;
  final String name;
  final double pricePerUnit;
  final double? pricePerPacket;
  final int? packetSize;
  final String unitLabel;
  final int quantity;
  final String category;
  final DateTime? expiryDate;
  final String? imageUrl;

  bool get inStock => quantity > 0;

  /// Display price; falls back to legacy `price` field.
  double get price => pricePerUnit;

  Drug({
    required this.id,
    required this.pharmacyId,
    required this.name,
    this.pricePerUnit = 0,
    this.pricePerPacket,
    this.packetSize,
    this.unitLabel = 'unit',
    this.quantity = 0,
    this.category = '',
    this.expiryDate,
    this.imageUrl,
  });

  factory Drug.fromDocument(
    DocumentSnapshot doc, {
    required String pharmacyId,
  }) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    DateTime? exp;
    if (data['expiryDate'] != null) {
      final raw = data['expiryDate'];
      exp = raw is Timestamp ? raw.toDate() : DateTime.tryParse(raw.toString());
    }

    return Drug(
      id: doc.id,
      pharmacyId: pharmacyId,
      name: data['name']?.toString() ?? '',
      pricePerUnit:
          (data['pricePerUnit'] ?? data['price'] ?? 0).toDouble(),
      pricePerPacket: (data['pricePerPacket'] as num?)?.toDouble(),
      packetSize: (data['packetSize'] as num?)?.toInt(),
      unitLabel: data['unitLabel']?.toString() ?? 'unit',
      quantity: (data['quantity'] ?? 0).toInt(),
      category: data['category']?.toString() ?? '',
      expiryDate: exp,
      imageUrl: data['imageUrl']?.toString(),
    );
  }

  /// Secondary descriptor, e.g. "Tablet • Blister of 10".
  String get formLabel {
    final parts = <String>[];
    if (category.isNotEmpty) parts.add(category);
    if (packetSize != null && packetSize! > 0) {
      parts.add('Pack of $packetSize');
    } else if (unitLabel.isNotEmpty && unitLabel != 'unit') {
      parts.add(unitLabel);
    }
    return parts.join(' • ');
  }

  /// "500 FCFA" using grouping for thousands (e.g. 2500 -> 2,500 FCFA).
  String get priceLabel {
    return '${_group(pricePerUnit.round())} FCFA';
  }

  static String _group(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}
