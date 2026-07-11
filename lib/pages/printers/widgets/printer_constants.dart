import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/models/printer_model.dart';

/// Constants for printer group display names
class PrinterConstants {
  static const String receiptPrintersLabel = 'Receipt Printers';
  static const String kitchenPrintersLabel = 'Kitchen Printers';
  static const String quotePrintersLabel = 'Quote Printers';

  static const String receiptPrintersTitle = 'RECEIPT PRINTERS';
  static const String kitchenPrintersTitle = 'KITCHEN PRINTERS';
  static const String quotePrintersTitle = 'QUOTE PRINTERS';
}

/// Extension to provide printer group properties
extension PrinterGroupExtension on PrinterGroup {
  /// Display label for the printer group
  String get label {
    switch (this) {
      case PrinterGroup.receipt:
        return PrinterConstants.receiptPrintersLabel;
      case PrinterGroup.kitchen:
        return PrinterConstants.kitchenPrintersLabel;
      case PrinterGroup.quote:
        return PrinterConstants.quotePrintersLabel;
    }
  }

  /// Uppercase title for the printer group
  String get title {
    switch (this) {
      case PrinterGroup.receipt:
        return PrinterConstants.receiptPrintersTitle;
      case PrinterGroup.kitchen:
        return PrinterConstants.kitchenPrintersTitle;
      case PrinterGroup.quote:
        return PrinterConstants.quotePrintersTitle;
    }
  }

  /// Icon for the printer group
  IconData get icon {
    switch (this) {
      case PrinterGroup.receipt:
        return Icons.receipt_long;
      case PrinterGroup.kitchen:
        return Icons.shopping_bag;
      case PrinterGroup.quote:
        return Icons.request_quote;
    }
  }

  /// Background color for the printer group
  Color getColor(BuildContext context) {
    switch (this) {
      case PrinterGroup.receipt:
        return Colors.blue.shade50;
      case PrinterGroup.kitchen:
        return Colors.green.shade50;
      case PrinterGroup.quote:
        return Colors.purple.shade50;
    }
  }
}
