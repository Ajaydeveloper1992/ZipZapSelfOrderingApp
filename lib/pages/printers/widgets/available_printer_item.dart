import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/models/available_printer_model.dart';
import 'package:zipzap_pos_self_orders/models/printer_model.dart';

class AvailablePrinterItem extends StatelessWidget {
  final AvailablePrinter printer;
  final VoidCallback? onTap;

  const AvailablePrinterItem({super.key, required this.printer, this.onTap});

  String _getTypeLabel(AvailablePrinter printer) {
    switch (printer.type) {
      case PrinterType.lan:
        return 'LAN';
      case PrinterType.usb:
        return 'USB';
      case PrinterType.bluetooth:
        return 'Bluetooth';
      case PrinterType.wifi:
        return 'WiFi';
    }
  }

  String _getTypeOrIp(AvailablePrinter printer) {
    if (printer.type == PrinterType.lan && printer.ipAddress != null) {
      return printer.ipAddress!;
    }
    return _getTypeLabel(printer);
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          color: Colors.black.withValues(alpha: 0.02),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.print,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 200,
                    child: Text(
                      printer.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 100),
                  SizedBox(
                    width: 100,
                    child: Text(
                      _getTypeOrIp(printer),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
