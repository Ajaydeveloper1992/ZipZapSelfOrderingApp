import 'package:flutter/material.dart';

class PriceBadge extends StatelessWidget {
  final double price;

  const PriceBadge({super.key, required this.price});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 3,
      right: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(2),
          // border: Border.all(color: Colors.white, width: 1),
        ),
        child: Text(
          '\$${price.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
