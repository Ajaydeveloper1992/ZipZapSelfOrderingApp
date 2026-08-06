import 'package:flutter/material.dart';

class ReceiptFooter extends StatelessWidget {
  final String? leftText;
  final String? rightText;

  const ReceiptFooter({super.key, this.leftText, this.rightText});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        if (leftText != null)
          Text(
            leftText!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.black54),
          ),
        if (rightText != null) ...[
          const SizedBox(height: 6),
          Text(
            rightText!,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}
