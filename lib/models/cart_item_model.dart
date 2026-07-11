import 'package:zipzap_pos_self_orders/models/product_model.dart';

class ItemDiscount {
  final String type; // '$' or '%'
  final double value;

  ItemDiscount({required this.type, required this.value});
}

class CartItem {
  final String id;
  final Product product;
  final int quantity;
  final Map<String, List<String>>
  modifiers; // Modifier group -> list of modifier IDs
  final String itemNote;
  final ItemDiscount? itemDiscount;
  final DateTime timestamp;
  final bool inKitchen;
  final String? itemStatus; // 'Voided', etc.
  final double? subTotal;
  final String
  guestGroup; // Guest group assignment (e.g., 'whole_table', 'guest_1')

  CartItem({
    required this.id,
    required this.product,
    required this.quantity,
    this.modifiers = const {},
    this.itemNote = '',
    this.itemDiscount,
    DateTime? timestamp,
    this.inKitchen = false,
    this.itemStatus,
    this.subTotal,
    this.guestGroup = 'whole_table', // Default to whole table
  }) : timestamp = timestamp ?? DateTime.now();

  CartItem copyWith({
    String? id,
    Product? product,
    int? quantity,
    Map<String, List<String>>? modifiers,
    String? itemNote,
    ItemDiscount? itemDiscount,
    DateTime? timestamp,
    bool? inKitchen,
    String? itemStatus,
    double? subTotal,
    String? guestGroup,
  }) {
    return CartItem(
      id: id ?? this.id,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      modifiers: modifiers ?? this.modifiers,
      itemNote: itemNote ?? this.itemNote,
      itemDiscount: itemDiscount ?? this.itemDiscount,
      timestamp: timestamp ?? this.timestamp,
      inKitchen: inKitchen ?? this.inKitchen,
      itemStatus: itemStatus ?? this.itemStatus,
      subTotal: subTotal ?? this.subTotal,
      guestGroup: guestGroup ?? this.guestGroup,
    );
  }

  double get itemPrice => product.posEffectivePrice;

  double get totalPrice {
    final baseTotal = itemPrice * quantity;
    if (itemDiscount != null) {
      if (itemDiscount!.type == '%') {
        return baseTotal * (1 - itemDiscount!.value / 100);
      } else {
        return baseTotal - itemDiscount!.value;
      }
    }
    return baseTotal;
  }
}
