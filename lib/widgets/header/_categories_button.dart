import 'package:flutter/material.dart';

class HeaderCategoriesButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const HeaderCategoriesButton({
    super.key,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      icon: const Icon(Icons.category),
      onPressed: onPressed,
      tooltip: 'Categories',
      constraints: const BoxConstraints(),
      style: ButtonStyle(
        shape: WidgetStateProperty.all<RoundedRectangleBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

