import 'package:flutter/material.dart';

class StockBadge extends StatelessWidget {
  final int stockQuantity;
  final int lowStockThreshold;

  const StockBadge({
    super.key,
    required this.stockQuantity,
    this.lowStockThreshold = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = stockQuantity == 0;
    final isLowStock =
        stockQuantity > 0 &&
        lowStockThreshold > 0 &&
        stockQuantity <= lowStockThreshold;

    Color backgroundColor;
    Color borderColor;
    Color textColor;
    IconData? icon;
    String label;

    if (isOutOfStock) {
      backgroundColor = Colors.red.shade100;
      borderColor = Colors.red.shade200;
      textColor = Colors.red.shade400;
      icon = Icons.warning_amber_rounded;
      label = 'OUT';
    } else if (isLowStock) {
      backgroundColor = Colors.orange.shade100;
      borderColor = Colors.orange.shade300;
      textColor = Colors.orange.shade800;
      label = 'LOW: $stockQuantity';
    } else {
      backgroundColor = Colors.blue.shade200;
      borderColor = Colors.blue.shade400;
      textColor = Colors.blue.shade800;
      icon = null;
      label = 'STOCK: $stockQuantity';
    }

    return Positioned(
      top: 4,
      left: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) Icon(icon, size: 12, color: textColor),
            if (icon != null) const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
