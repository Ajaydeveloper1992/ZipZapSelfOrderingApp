import 'receipt_item_model.dart';

enum ReceiptType { kitchen, customer }

class ReceiptSummary {
  final double? subtotal;
  final double? discount;
  final double? tax;
  final double? serviceCharge;
  final double? total;

  const ReceiptSummary({
    this.subtotal,
    this.discount,
    this.tax,
    this.serviceCharge,
    this.total,
  });
}

class ReceiptModel {
  final ReceiptType type;
  final String restaurantName;
  final String? logoBase64; // placeholder
  final String? address;
  final String? phone;
  final String? email;
  final String? website;

  final String orderNumber;
  final String? customerName;
  final String? cashier;
  final String? orderType; // PICKUP / DELIVERY / DINE IN
  final DateTime placedAt;
  final DateTime? dueAt;
  final String? tableNumber;

  final List<ReceiptItemModel> items;
  final String? orderNote;
  final ReceiptSummary? summary;

  ReceiptModel({
    required this.type,
    required this.restaurantName,
    this.logoBase64,
    this.address,
    this.phone,
    this.email,
    this.website,
    required this.orderNumber,
    this.customerName,
    this.cashier,
    this.orderType,
    required this.placedAt,
    this.dueAt,
    this.tableNumber,
    this.items = const [],
    this.orderNote,
    this.summary,
  });
}
