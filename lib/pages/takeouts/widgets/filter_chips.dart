import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class FilterChips extends StatelessWidget {
  final String? title;
  final List<String> options;
  final String selectedOption;
  final Function(String) onOptionSelected;

  const FilterChips({
    super.key,
    this.title,
    required this.options,
    required this.selectedOption,
    required this.onOptionSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Convert List<String> to Map<String, Widget> for CupertinoSlidingSegmentedControl
    final Map<String, Widget> children = {
      for (var option in options)
        option: Padding(
          padding: const EdgeInsets.all(6),
          child: Text(
            option,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: option == selectedOption
                  ? Colors.white
                  : Colors.grey.shade700,
            ),
          ),
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null)
          Text(
            title!,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        if (title != null) const SizedBox(height: 8),
        CupertinoSlidingSegmentedControl<String>(
          children: children,
          groupValue: selectedOption,
          onValueChanged: (value) {
            if (value != null) {
              onOptionSelected(value);
            }
          },
          thumbColor: Theme.of(context).colorScheme.primary,
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.1),
        ),
      ],
    );
  }
}
