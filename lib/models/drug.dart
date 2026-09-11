/// A drug from a pharmacy's inventory, as returned by the PharmaTrack
/// public API (`GET /api/v1/pharmacies/<id>/products` and
/// `GET /api/v1/products/search?q=`).
///
/// The API always hides exact stock: it sends `in_stock` as a boolean, plus
/// `price_per_unit`, `price_per_packet`, `packet_size`, `unit_label`,
/// `category`, `image_url` and the owning pharmacy's id/name.
class Drug {
  final String id;

  /// Id of the owning pharmacy.
  final String pharmacyId;
  final String pharmacyName;
  final String name;
  final double pricePerUnit;
  final double? pricePerPacket;
  final int? packetSize;
  final String unitLabel;

  /// 1 when the pharmacy reports stock for this product, 0 otherwise.
  /// Exact quantities are never exposed publicly.
  final int quantity;
  final String category;
  final String? imageUrl;

  bool get inStock => quantity > 0;

  /// Display price; falls back to legacy `price` field.
  double get price => pricePerUnit;

  Drug({
    required this.id,
    required this.pharmacyId,
    this.pharmacyName = '',
    required this.name,
    this.pricePerUnit = 0,
    this.pricePerPacket,
    this.packetSize,
    this.unitLabel = 'unit',
    this.quantity = 0,
    this.category = '',
    this.imageUrl,
  });

  factory Drug.fromJson(Map<String, dynamic> data) {
    return Drug(
      id: data['id']?.toString() ?? '',
      pharmacyId: (data['pharmacy_id'] ?? '').toString(),
      pharmacyName: (data['pharmacy_name'] ?? '').toString(),
      name: data['name']?.toString() ?? '',
      pricePerUnit:
          (data['price_per_unit'] ?? data['pricePerUnit'] ?? 0).toDouble(),
      pricePerPacket:
          (data['price_per_packet'] ?? data['pricePerPacket'] as num?)
              ?.toDouble(),
      packetSize: (data['packet_size'] ?? data['packetSize'] as num?)?.toInt(),
      unitLabel: data['unit_label']?.toString() ?? 'unit',
      quantity: data['in_stock'] == true ? 1 : (data['quantity'] ?? 0).toInt(),
      category: data['category']?.toString() ?? '',
      imageUrl: data['image_url']?.toString(),
    );
  }

  /// Secondary descriptor, e.g. "Tablet • Blister of 10".
  String get formLabel {
    final parts = <String>[];
    if (category.isNotEmpty && category != '—') parts.add(category);
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