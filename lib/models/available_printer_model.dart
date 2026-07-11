import 'package:zipzap_pos_self_orders/models/printer_model.dart';

class AvailablePrinter {
  final String id; // This is the identifier from SDK
  final String name;
  final PrinterType type;
  final String? ipAddress; // For LAN printers
  final String? port; // For USB/other connections

  const AvailablePrinter({
    required this.id,
    required this.name,
    required this.type,
    this.ipAddress,
    this.port,
  });

  // Get the connection identifier
  String get identifier => id;
}
