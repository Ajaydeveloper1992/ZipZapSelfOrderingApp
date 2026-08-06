import 'package:flutter/material.dart';
import '../../models/receipt_item_model.dart';

class ReceiptItemWidget extends StatelessWidget {
  final ReceiptItemModel item;
  final bool showPrice;

  const ReceiptItemWidget({
    super.key,
    required this.item,
    this.showPrice = true,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quantity
            SizedBox(
              width: 36,
              child: Text(
                '${item.quantity}×',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Name and details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // variants and addons
                  if (item.variants.isNotEmpty || item.addons.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...item.variants.map((v) => _detailRow(v, context)),
                          ...item.addons.map((a) => _detailRow(a, context)),
                        ],
                      ),
                    ),
                  if (item.notes != null && item.notes!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(item.notes!, style: textTheme.bodySmall),
                      ),
                    ),
                ],
              ),
            ),
            if (showPrice)
              SizedBox(
                width: 80,
                child: Text(
                  item.price != null
                      ? '\$${item.price!.toStringAsFixed(2)}'
                      : '',
                  textAlign: TextAlign.right,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _detailRow(String text, BuildContext context) {
    return Row(
      children: [
        const Text('• ', style: TextStyle(fontSize: 12)),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}
