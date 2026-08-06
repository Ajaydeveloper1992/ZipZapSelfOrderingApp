class ReceiptItemModel {
  final String id;
  final String name;
  final int quantity;
  final double? price; // null for kitchen receipts
  final List<String> variants; // size, spice, etc.
  final List<String> addons;
  final String? notes;

  ReceiptItemModel({
    required this.id,
    required this.name,
    this.quantity = 1,
    this.price,
    this.variants = const [],
    this.addons = const [],
    this.notes,
  });
}
