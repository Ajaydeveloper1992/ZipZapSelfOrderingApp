import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/models/printer_model.dart';
import 'package:zipzap_pos_self_orders/pages/printers/widgets/printer_group_section.dart';

class PrintersList extends StatelessWidget {
  final List<Printer> printers;
  final Function(Printer)? onPrinterTap;

  const PrintersList({super.key, required this.printers, this.onPrinterTap});

  @override
  Widget build(BuildContext context) {
    // Create a mutable copy of printers for testing
    final testPrinters = List<Printer>.from(printers);

    // ========== DUMMY PRINTERS FOR TESTING ==========
    // Uncomment the lines below to add dummy printers for UI testing
    // testPrinters.addAll([
    //   const Printer(
    //     id: 'dummy-receipt-1',
    //     name: 'Receipt Printer 1',
    //     type: PrinterType.lan,
    //     ipAddress: '192.168.1.100',
    //     modelName: 'Epson TM-T88V',
    //     status: PrinterStatus.online,
    //     group: PrinterGroup.receipt,
    //     identifier: '192.168.1.100',
    //   ),
    //   const Printer(
    //     id: 'dummy-order-1',
    //     name: 'Kitchen Printer 1',
    //     type: PrinterType.usb,
    //     modelName: 'Star TSP143',
    //     status: PrinterStatus.online,
    //     group: PrinterGroup.kitchen,
    //     identifier: 'USB001',
    //   ),
    //   const Printer(
    //     id: 'dummy-quote-1',
    //     name: 'Quote Printer 1',
    //     type: PrinterType.bluetooth,
    //     modelName: 'Brother QL-820NWB',
    //     status: PrinterStatus.offline,
    //     group: PrinterGroup.quote,
    //     identifier: 'BT:00:11:22:33:44:55',
    //   ),
    // ]);
    // ===============================================

    if (testPrinters.isEmpty) {
      return Center(
        child: Text(
          'No printers found',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    // Dynamically group printers by their group type
    return ListView(
      children: PrinterGroup.values.map((group) {
        final groupPrinters = testPrinters
            .where((p) => p.group == group)
            .toList();
        return PrinterGroupSection(
          group: group,
          printers: groupPrinters,
          onPrinterTap: onPrinterTap,
        );
      }).toList(),
    );
  }
}
