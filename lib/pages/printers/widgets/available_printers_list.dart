import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/models/available_printer_model.dart';
import 'package:zipzap_pos_self_orders/pages/printers/widgets/available_printer_item.dart';

class AvailablePrintersList extends StatelessWidget {
  final List<AvailablePrinter> printers;
  final Function(AvailablePrinter)? onPrinterTap;

  const AvailablePrintersList({
    super.key,
    required this.printers,
    this.onPrinterTap,
  });

  @override
  Widget build(BuildContext context) {
    if (printers.isEmpty) {
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

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: printers.length,
      itemBuilder: (context, index) {
        final printer = printers[index];
        return AvailablePrinterItem(
          printer: printer,
          onTap: onPrinterTap != null ? () => onPrinterTap!(printer) : null,
        );
      },
    );
  }
}
