import 'package:flutter/material.dart';
import '../../models/receipt_model.dart';

class ReceiptSummaryWidget extends StatelessWidget {
  final ReceiptSummary? summary;

  const ReceiptSummaryWidget({super.key, this.summary});

  @override
  Widget build(BuildContext context) {
    if (summary == null) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;

    Widget row(String label, String value, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: t.bodyMedium),
          Text(
            value,
            style: bold
                ? t.titleMedium?.copyWith(fontWeight: FontWeight.w800)
                : t.bodyMedium,
          ),
        ],
      ),
    );

    return Column(
      children: [
        if (summary!.subtotal != null)
          row('Subtotal', '\$${summary!.subtotal!.toStringAsFixed(2)}'),
        if (summary!.discount != null)
          row('Discount', '\$${summary!.discount!.toStringAsFixed(2)}'),
        if (summary!.tax != null)
          row('Tax', '\$${summary!.tax!.toStringAsFixed(2)}'),
        if (summary!.serviceCharge != null)
          row('Service', '\$${summary!.serviceCharge!.toStringAsFixed(2)}'),
        if (summary!.total != null) ...[
          const SizedBox(height: 8),
          row('TOTAL', '\$${summary!.total!.toStringAsFixed(2)}', bold: true),
        ],
      ],
    );
  }
}
