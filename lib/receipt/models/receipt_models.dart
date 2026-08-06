import 'package:flutter/foundation.dart';

enum ReceiptType { customer, kitchen }

@immutable
class ReceiptItem {
  final String id;
  final String name;
  final int quantity;
  final double? price;
  final List<String> variants;
  final List<String> addons;
  final String? notes;

  const ReceiptItem({
    required this.id,
    required this.name,
    this.quantity = 1,
    this.price,
    this.variants = const [],
    this.addons = const [],
    this.notes,
  });
}

@immutable
class ReceiptSummary {
  final double subtotal;
  final double? discount;
  final double? tax;
  final double? serviceCharge;
  final double total;

  const ReceiptSummary({
    required this.subtotal,
    this.discount,
    this.tax,
    this.serviceCharge,
    required this.total,
  });
}

@immutable
class ReceiptPayment {
  final String method;
  final double paidAmount;
  final double change;

  const ReceiptPayment({
    required this.method,
    required this.paidAmount,
    required this.change,
  });
}

@immutable
class ReceiptModel {
  final ReceiptType type;
  final String restaurantName;
  final String? restaurantLogoUrl;
  final String? address;
  final String? phone;
  final String? website;
  final String orderNumber;
  final String? customerName;
  final String? cashier;
  final String? tableNumber;
  final String? orderType;
  final DateTime placedAt;
  final DateTime? requiredAt;
  final String? orderNote;
  final String? kitchenNote;
  final List<ReceiptItem> items;
  final ReceiptSummary? summary;
  final ReceiptPayment? payment;

  const ReceiptModel({
    required this.type,
    required this.restaurantName,
    this.restaurantLogoUrl,
    this.address,
    this.phone,
    this.website,
    required this.orderNumber,
    this.customerName,
    this.cashier,
    this.tableNumber,
    this.orderType,
    required this.placedAt,
    this.requiredAt,
    this.orderNote,
    this.kitchenNote,
    this.items = const [],
    this.summary,
    this.payment,
  });
}
