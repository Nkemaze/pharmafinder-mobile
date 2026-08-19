/// An aggregate view of a medicine across all pharmacies: cheapest price,
/// how many pharmacies stock it, and whether any currently have it in stock.
///
/// Used for the Home screen's "Popular Medicines" list.
class PopularDrug {
  final String name;
  final String formLabel;
  final double cheapestPrice;
  final int pharmacyCount;
  final bool anyInStock;

  const PopularDrug({
    required this.name,
    required this.formLabel,
    required this.cheapestPrice,
    required this.pharmacyCount,
    required this.anyInStock,
  });

  /// "500 FCFA" using grouping for thousands (e.g. 2500 -> 2,500 FCFA).
  String get cheapestPriceLabel => '${_group(cheapestPrice.round())} FCFA';

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
