import 'package:flutter/material.dart';

class KeypadButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool disabled;
  final Color? backgroundColor;
  final Color? textColor;

  const KeypadButton({
    super.key,
    required this.child,
    this.onPressed,
    this.disabled = false,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: disabled ? null : onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: backgroundColor ?? Colors.transparent,
        foregroundColor: textColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minimumSize: const Size(0, 50),
        maximumSize: const Size(double.infinity, double.infinity),
        fixedSize: null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: child,
    );
  }
}
