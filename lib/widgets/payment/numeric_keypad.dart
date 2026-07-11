import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/widgets/payment/keypad_button.dart';

class NumericKeypad extends StatelessWidget {
  final Function(String) onNumberClick;
  final VoidCallback onClear;
  final VoidCallback onBackspace;
  final List<String> customPads;
  final VoidCallback? onConfirm;
  final bool isLoading;
  final bool disabled;

  final double spacing;

  const NumericKeypad({
    super.key,
    required this.onNumberClick,
    required this.onClear,
    required this.onBackspace,
    this.customPads = const ['0', '.', '00', '000'],
    this.onConfirm,
    this.isLoading = false,
    this.disabled = false,
    this.spacing = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 4,
      children: [
        // Row 1: 1, 2, 3, Clear
        Row(
          spacing: spacing,
          children: [
            Expanded(
              child: KeypadButton(
                onPressed: disabled ? null : () => onNumberClick('1'),
                backgroundColor: Colors.grey.shade100,
                child: const Text('1'),
              ),
            ),
            Expanded(
              child: KeypadButton(
                onPressed: disabled ? null : () => onNumberClick('2'),
                backgroundColor: Colors.grey.shade100,
                child: const Text('2'),
              ),
            ),
            Expanded(
              child: KeypadButton(
                onPressed: disabled ? null : () => onNumberClick('3'),
                backgroundColor: Colors.grey.shade100,
                child: const Text('3'),
              ),
            ),
            Expanded(
              child: KeypadButton(
                onPressed: disabled ? null : onClear,
                backgroundColor: Colors.red.shade50,
                child: const Text(
                  'CLEAR',
                  style: TextStyle(fontSize: 12, color: Colors.red),
                ),
              ),
            ),
          ],
        ),
        // Row 2: 4, 5, 6, Backspace
        Row(
          spacing: spacing,
          children: [
            Expanded(
              child: KeypadButton(
                onPressed: disabled ? null : () => onNumberClick('4'),
                backgroundColor: Colors.grey.shade100,
                child: const Text('4'),
              ),
            ),
            Expanded(
              child: KeypadButton(
                onPressed: disabled ? null : () => onNumberClick('5'),
                backgroundColor: Colors.grey.shade100,
                child: const Text('5'),
              ),
            ),
            Expanded(
              child: KeypadButton(
                onPressed: disabled ? null : () => onNumberClick('6'),
                backgroundColor: Colors.grey.shade100,
                child: const Text('6'),
              ),
            ),
            Expanded(
              child: KeypadButton(
                onPressed: disabled ? null : onBackspace,
                backgroundColor: Colors.grey.shade100,
                child: const Icon(Icons.arrow_back, size: 20),
              ),
            ),
          ],
        ),
        // Row 3: 7, 8, 9, Confirm
        Row(
          spacing: spacing,
          children: [
            Expanded(
              child: KeypadButton(
                onPressed: disabled ? null : () => onNumberClick('7'),
                backgroundColor: Colors.grey.shade100,
                child: const Text('7'),
              ),
            ),
            Expanded(
              child: KeypadButton(
                onPressed: disabled ? null : () => onNumberClick('8'),
                backgroundColor: Colors.grey.shade100,
                child: const Text('8'),
              ),
            ),
            Expanded(
              child: KeypadButton(
                onPressed: disabled ? null : () => onNumberClick('9'),
                backgroundColor: Colors.grey.shade100,
                child: const Text('9'),
              ),
            ),
            Expanded(
              child: KeypadButton(
                onPressed: isLoading || disabled ? null : onConfirm,
                backgroundColor: Colors.grey.shade100,
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.done_all, size: 20),
              ),
            ),
          ],
        ),
        // Row 4: 0, ., 00
        Row(
          spacing: spacing,
          children: [
            Expanded(
              child: KeypadButton(
                onPressed: disabled ? null : () => onNumberClick(customPads[0]),
                backgroundColor: Colors.grey.shade100,
                child: Text(customPads[0]),
              ),
            ),
            Expanded(
              child: KeypadButton(
                onPressed: disabled ? null : () => onNumberClick(customPads[1]),
                backgroundColor: Colors.grey.shade100,
                child: Text(customPads[1]),
              ),
            ),
            Expanded(
              child: KeypadButton(
                onPressed: disabled ? null : () => onNumberClick(customPads[2]),
                backgroundColor: Colors.grey.shade100,
                child: Text(customPads[2]),
              ),
            ),
            Expanded(
              child: KeypadButton(
                onPressed: disabled ? null : () => onNumberClick(customPads[3]),
                backgroundColor: Colors.grey.shade100,
                child: Text(customPads[3]),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
