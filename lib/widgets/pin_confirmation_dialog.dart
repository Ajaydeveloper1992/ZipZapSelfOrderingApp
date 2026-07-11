import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zipzap_pos_self_orders/pages/auth/widgets/numeric_keypad.dart';

class PinConfirmationDialog extends StatefulWidget {
  final String title;
  final String? description;

  const PinConfirmationDialog({
    super.key,
    required this.title,
    this.description,
  });

  static Future<String?> show(
    BuildContext context, {
    required String title,
    String? description,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) =>
          PinConfirmationDialog(title: title, description: description),
    );
  }

  @override
  State<PinConfirmationDialog> createState() => _PinConfirmationDialogState();
}

class _PinConfirmationDialogState extends State<PinConfirmationDialog> {
  final _pinController = TextEditingController();
  bool _isPinVisible = false;
  String? _errorText;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _onNumberPressed(String number) {
    _pinController.text += number;
    _pinController.selection = TextSelection.fromPosition(
      TextPosition(offset: _pinController.text.length),
    );
    if (_errorText != null) setState(() => _errorText = null);
  }

  void _onBackspace() {
    final text = _pinController.text;
    if (text.isNotEmpty) {
      _pinController.text = text.substring(0, text.length - 1);
      _pinController.selection = TextSelection.fromPosition(
        TextPosition(offset: _pinController.text.length),
      );
    }
  }

  void _onConfirm() {
    final pin = _pinController.text;
    if (pin.isEmpty || pin.length < 4) {
      setState(() => _errorText = 'PIN must be at least 4 digits');
      return;
    }
    Navigator.of(context).pop(pin);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                widget.title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              if (widget.description != null) ...[
                const SizedBox(height: 4),
                Text(
                  widget.description!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 12),
              CupertinoTextField(
                controller: _pinController,
                placeholder: 'Enter your PIN',
                readOnly: true,
                showCursor: false,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _errorText != null
                        ? Colors.red.shade300
                        : Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                prefix: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Icon(
                    Icons.lock,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                suffix: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      setState(() => _isPinVisible = !_isPinVisible);
                    },
                    minimumSize: const Size(0, 0),
                    child: Icon(
                      _isPinVisible ? Icons.visibility : Icons.visibility_off,
                      size: 20,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                obscureText: !_isPinVisible,
                style: const TextStyle(fontSize: 15),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 4),
                Text(
                  _errorText!,
                  style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                ),
              ],
              const SizedBox(height: 8),
              NumericKeypad(
                onNumberPressed: _onNumberPressed,
                onBackspace: _onBackspace,
                onEnter: _onConfirm,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
