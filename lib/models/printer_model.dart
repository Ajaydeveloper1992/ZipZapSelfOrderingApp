enum PrinterType { lan, usb, bluetooth, wifi }

enum PrinterStatus { online, offline, error }

enum PrinterGroup { receipt, kitchen, quote }

class Printer {
  final String id;
  final String name;
  final PrinterType type;
  final PrinterStatus status;
  final PrinterGroup group;
  final String
  identifier; // Connection identifier (IP for LAN, MAC for Bluetooth, etc.)
  final List<String> selectedLabels; // Selected label IDs
  final String? modelName; // Printer model name
  final String? ipAddress; // IP address (for LAN printers)

  const Printer({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.group,
    required this.identifier,
    this.selectedLabels = const [],
    this.modelName,
    this.ipAddress,
  });

  Printer copyWith({
    String? id,
    String? name,
    PrinterType? type,
    PrinterStatus? status,
    PrinterGroup? group,
    String? identifier,
    List<String>? selectedLabels,
    String? modelName,
    String? ipAddress,
  }) {
    return Printer(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
      group: group ?? this.group,
      identifier: identifier ?? this.identifier,
      selectedLabels: selectedLabels ?? this.selectedLabels,
      modelName: modelName ?? this.modelName,
      ipAddress: ipAddress ?? this.ipAddress,
    );
  }
}
