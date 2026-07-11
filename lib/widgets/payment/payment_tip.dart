import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/widgets/payment/keypad_button.dart';
import 'package:zipzap_pos_self_orders/widgets/payment/numeric_keypad.dart';

class PaymentTip extends StatefulWidget {
  final double currentSplitAmount;
  final Map<String, dynamic>? existingTip;
  final Function(double amount, String type) onNext;
  final VoidCallback onCancel;

  const PaymentTip({
    super.key,
    required this.currentSplitAmount,
    this.existingTip,
    required this.onNext,
    required this.onCancel,
  });

  @override
  State<PaymentTip> createState() => _PaymentTipState();
}

class _PaymentTipState extends State<PaymentTip> {
  String _tipAmount = '0';
  String _tipType = '\$';

  @override
  void initState() {
    super.initState();
    if (widget.existingTip != null) {
      _tipAmount = widget.existingTip!['amount']?.toString() ?? '0';
      _tipType = widget.existingTip!['type'] ?? '\$';
    }
  }

  double get _totalAfterTip {
    final tipValue = double.tryParse(_tipAmount) ?? 0.0;
    if (_tipType == '%') {
      return widget.currentSplitAmount +
          (widget.currentSplitAmount * tipValue / 100);
    }
    return widget.currentSplitAmount + tipValue;
  }

  void _handleNumberClick(String num) {
    setState(() {
      if (_tipAmount == '0') {
        _tipAmount = num;
      } else {
        _tipAmount = _tipAmount + num;
      }
    });
  }

  void _handleClear() {
    setState(() {
      _tipAmount = '0';
    });
  }

  void _handleBackspace() {
    setState(() {
      if (_tipAmount.length > 1) {
        _tipAmount = _tipAmount.substring(0, _tipAmount.length - 1);
      } else {
        _tipAmount = '0';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        spacing: 8,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              color: Colors.white,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add a TIP',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  spacing: 4,
                  children: [
                    Text(
                      'Total After TIP: ',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '\$${_totalAfterTip.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Tip amount input row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              spacing: 4,
              children: [
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Center(
                      child: const Text(
                        'TIP AMOUNT',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 58,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        _tipAmount,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Row(
                    spacing: 4,
                    children: [
                      Expanded(
                        child: Container(
                          height: 58,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: KeypadButton(
                            onPressed: () {
                              setState(() {
                                _tipType = '\$';
                              });
                            },
                            backgroundColor: _tipType == '\$'
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade100,
                            textColor: _tipType == '\$' ? Colors.white : null,
                            child: const Text('\$'),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 58,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: KeypadButton(
                            onPressed: () {
                              setState(() {
                                _tipType = '%';
                              });
                            },
                            backgroundColor: _tipType == '%'
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade100,
                            textColor: _tipType == '%' ? Colors.white : null,
                            child: const Text('%'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Keypad and quick suggestions
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              spacing: 4,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: NumericKeypad(
                    onNumberClick: _handleNumberClick,
                    onClear: _handleClear,
                    onBackspace: _handleBackspace,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    spacing: 4,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: KeypadButton(
                          onPressed: () {
                            setState(() {
                              _tipAmount = '5';
                              _tipType = '\$';
                            });
                          },
                          child: const Text(
                            '\$5',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: KeypadButton(
                          onPressed: () {
                            setState(() {
                              _tipAmount = '10';
                              _tipType = '\$';
                            });
                          },
                          child: const Text(
                            '\$10',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: KeypadButton(
                          onPressed: () {
                            setState(() {
                              _tipAmount = '5';
                              _tipType = '%';
                            });
                          },
                          child: const Text(
                            '5%',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: KeypadButton(
                          onPressed: () {
                            setState(() {
                              _tipAmount = '10';
                              _tipType = '%';
                            });
                          },
                          child: const Text(
                            '10%',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Footer buttons
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              color: Colors.white,
            ),
            child: Row(
              spacing: 8,
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      final amount = double.tryParse(_tipAmount) ?? 0.0;
                      widget.onNext(amount, _tipType);
                    },
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Next'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
