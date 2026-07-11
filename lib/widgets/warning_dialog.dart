import 'package:flutter/material.dart';

enum WarningDialogType {
  error,
  warning,
  info,
}

class WarningDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? infoMessage;
  final String confirmText;
  final String cancelText;
  final IconData? icon;
  final WarningDialogType type;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;

  const WarningDialog({
    super.key,
    required this.title,
    required this.message,
    this.infoMessage,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    this.icon,
    this.type = WarningDialogType.warning,
    this.onConfirm,
    this.onCancel,
  });

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    String? infoMessage,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    IconData? icon,
    WarningDialogType type = WarningDialogType.warning,
    bool barrierDismissible = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => WarningDialog(
        title: title,
        message: message,
        infoMessage: infoMessage,
        confirmText: confirmText,
        cancelText: cancelText,
        icon: icon,
        type: type,
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
  }

  Color _getContainerColor(BuildContext context) {
    switch (type) {
      case WarningDialogType.error:
        return Theme.of(context).colorScheme.errorContainer;
      case WarningDialogType.warning:
        return Theme.of(context).colorScheme.errorContainer;
      case WarningDialogType.info:
        return Theme.of(context).colorScheme.primaryContainer;
    }
  }

  Color _getIconColor(BuildContext context) {
    switch (type) {
      case WarningDialogType.error:
        return Theme.of(context).colorScheme.error;
      case WarningDialogType.warning:
        return Theme.of(context).colorScheme.error;
      case WarningDialogType.info:
        return Theme.of(context).colorScheme.primary;
    }
  }

  Color _getOnContainerColor(BuildContext context) {
    switch (type) {
      case WarningDialogType.error:
        return Theme.of(context).colorScheme.onErrorContainer;
      case WarningDialogType.warning:
        return Theme.of(context).colorScheme.onErrorContainer;
      case WarningDialogType.info:
        return Theme.of(context).colorScheme.onPrimaryContainer;
    }
  }

  Color _getButtonColor(BuildContext context) {
    switch (type) {
      case WarningDialogType.error:
        return Theme.of(context).colorScheme.error;
      case WarningDialogType.warning:
        return Theme.of(context).colorScheme.error;
      case WarningDialogType.info:
        return Theme.of(context).colorScheme.primary;
    }
  }

  Color _getOnButtonColor(BuildContext context) {
    switch (type) {
      case WarningDialogType.error:
        return Theme.of(context).colorScheme.onError;
      case WarningDialogType.warning:
        return Theme.of(context).colorScheme.onError;
      case WarningDialogType.info:
        return Theme.of(context).colorScheme.onPrimary;
    }
  }

  IconData _getDefaultIcon() {
    switch (type) {
      case WarningDialogType.error:
        return Icons.error_rounded;
      case WarningDialogType.warning:
        return Icons.warning_rounded;
      case WarningDialogType.info:
        return Icons.info_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;
    final modalWidth = isSmallScreen ? screenWidth * 0.9 : 420.0;

    final containerColor = _getContainerColor(context);
    final iconColor = _getIconColor(context);
    final onContainerColor = _getOnContainerColor(context);
    final buttonColor = _getButtonColor(context);
    final onButtonColor = _getOnButtonColor(context);
    final defaultIcon = icon ?? _getDefaultIcon();

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: modalWidth,
        constraints: const BoxConstraints(maxHeight: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with icon
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: containerColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iconColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      defaultIcon,
                      color: onButtonColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: onContainerColor,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.5,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  if (infoMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: containerColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 20,
                            color: iconColor,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              infoMessage!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    height: 1.4,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Footer with buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancel ?? () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(cancelText),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: onConfirm ?? () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: buttonColor,
                        foregroundColor: onButtonColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(confirmText),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

