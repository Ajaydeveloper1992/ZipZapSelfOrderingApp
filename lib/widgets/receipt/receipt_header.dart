import 'package:flutter/material.dart';

class ReceiptHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final double titleSize;

  const ReceiptHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.titleSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontSize: titleSize,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.black54),
          ),
        ],
      ],
    );
  }
}
