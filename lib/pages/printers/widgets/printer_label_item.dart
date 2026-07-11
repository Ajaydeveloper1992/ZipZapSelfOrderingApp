import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/models/printer_label_model.dart';

class PrinterLabelItem extends StatelessWidget {
  final PrinterLabel label;
  final ValueChanged<bool>? onChanged;

  const PrinterLabelItem({super.key, required this.label, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: label.isSelected,
      onChanged: (value) {
        if (onChanged != null && value != null) {
          onChanged!(value);
        }
      },
      title: Text(label.name, style: Theme.of(context).textTheme.bodyMedium),
      subtitle: label.description != null && label.description!.isNotEmpty
          ? Text(
              label.description!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            )
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      dense: true,
    );
  }
}
