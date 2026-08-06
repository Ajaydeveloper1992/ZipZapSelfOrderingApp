import 'package:flutter/material.dart';

class ReceiptDivider extends StatelessWidget {
  final double thickness;
  final double indent;

  const ReceiptDivider({super.key, this.thickness = 1.0, this.indent = 0});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8).copyWith(left: indent),
      child: Divider(
        height: 12,
        thickness: thickness,
        color: Colors.grey.shade300,
      ),
    );
  }
}
