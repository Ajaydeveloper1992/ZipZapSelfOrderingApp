import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/models/printer_model.dart';
import 'package:zipzap_pos_self_orders/pages/printers/widgets/printer_item.dart';
import 'package:zipzap_pos_self_orders/pages/printers/widgets/printer_constants.dart';

class PrinterGroupSection extends StatelessWidget {
  final PrinterGroup group;
  final List<Printer> printers;
  final Function(Printer)? onPrinterTap;

  const PrinterGroupSection({
    super.key,
    required this.group,
    required this.printers,
    this.onPrinterTap,
  });

  @override
  Widget build(BuildContext context) {
    if (printers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '${group.title} (${printers.length})',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        ...printers.map(
          (printer) => PrinterItem(
            printer: printer,
            onTap: onPrinterTap != null ? () => onPrinterTap!(printer) : null,
          ),
        ),
      ],
    );
  }
}
