import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/models/printer_label_model.dart';

class PrinterLabelsList extends StatelessWidget {
  final List<PrinterLabel> labels;
  final Function(PrinterLabel, bool)? onLabelChanged;

  const PrinterLabelsList({
    super.key,
    required this.labels,
    this.onLabelChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No labels available',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.label_outline_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Labels / Print Areas',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: labels.map((label) {
            return _buildLabelChip(context, label);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLabelChip(BuildContext context, PrinterLabel label) {
    return InkWell(
      onTap: () {
        if (onLabelChanged != null) {
          onLabelChanged!(label, !label.isSelected);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: label.isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: label.isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: label.isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: Checkbox(
                value: label.isSelected,
                onChanged: (value) {
                  if (onLabelChanged != null && value != null) {
                    onLabelChanged!(label, value);
                  }
                },
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label.name,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: label.isSelected
                    ? FontWeight.w600
                    : FontWeight.w400,
                color: label.isSelected
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
