import 'package:flutter/material.dart';

class TaxFreeBadge extends StatelessWidget {
  const TaxFreeBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 6,
      bottom: 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.green.shade700,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle,
              size: 10,
              color: Colors.white,
            ),
            const SizedBox(width: 3),
            Text(
              'TAX FREE',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

