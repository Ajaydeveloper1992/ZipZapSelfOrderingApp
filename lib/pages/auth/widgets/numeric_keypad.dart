import 'package:flutter/material.dart';

class NumericKeypad extends StatelessWidget {
  final Function(String) onNumberPressed;
  final VoidCallback? onBackspace;
  final VoidCallback? onEnter;
  final bool isLoading;

  const NumericKeypad({
    super.key,
    required this.onNumberPressed,
    this.onBackspace,
    this.onEnter,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        // borderRadius: BorderRadius.circular(16),
        // border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Keypad grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2,
              ),
              itemCount: 12,
              itemBuilder: (context, index) {
                if (index == 9) {
                  // Backspace button
                  return _KeypadButton(
                    label: '',
                    icon: Icons.backspace_outlined,
                    onPressed: isLoading ? null : onBackspace,
                    backgroundColor: Colors.grey.shade200,
                  );
                } else if (index == 10) {
                  // Zero button
                  return _KeypadButton(
                    label: '0',
                    onPressed: isLoading ? null : () => onNumberPressed('0'),
                  );
                } else if (index == 11) {
                  // Enter button
                  return _KeypadButton(
                    label: '',
                    icon: Icons.keyboard_return,
                    onPressed: isLoading ? null : onEnter,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    iconColor: Colors.white,
                    isLoading: isLoading,
                  );
                } else {
                  // Number buttons 1-9
                  final number = (index + 1).toString();
                  return _KeypadButton(
                    label: number,
                    onPressed: isLoading ? null : () => onNumberPressed(number),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final bool isLoading;

  const _KeypadButton({
    required this.label,
    this.icon,
    this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || isLoading;
    
    return Material(
      color: isDisabled
          ? (backgroundColor ?? Colors.white).withValues(alpha: 0.6)
          : backgroundColor ?? Colors.white,
      borderRadius: BorderRadius.circular(6),
      elevation: 0.5,
      child: InkWell(
        onTap: isDisabled ? null : onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade200, width: 0.5),
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        iconColor ?? Colors.white,
                      ),
                    ),
                  )
                : icon != null
                    ? Icon(
                        icon,
                        size: 16,
                        color: isDisabled
                            ? (iconColor ?? Colors.grey.shade700)
                                .withValues(alpha: 0.6)
                            : iconColor ?? Colors.grey.shade700,
                      )
                    : Text(
                        label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDisabled
                              ? Colors.grey.shade800.withValues(alpha: 0.6)
                              : Colors.grey.shade800,
                        ),
                      ),
          ),
        ),
      ),
    );
  }
}
