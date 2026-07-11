import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/widgets/payment/keypad_button.dart';
import 'package:zipzap_pos_self_orders/widgets/payment/numeric_keypad.dart';

class PayCashForm extends StatefulWidget {
  final double splitAmount;
  final double currentPayment;
  final String tendered;
  final Function(String) onTenderedChanged;
  final Function(double) onPay;
  final bool sendToKitchen;
  final Function(bool) onSendToKitchenChanged;
  final VoidCallback? onPrint;
  final bool hideSendToKitchen;
  final String? orderType;

  const PayCashForm({
    super.key,
    required this.splitAmount,
    required this.currentPayment,
    required this.tendered,
    required this.onTenderedChanged,
    required this.onPay,
    required this.sendToKitchen,
    required this.onSendToKitchenChanged,
    this.onPrint,
    this.hideSendToKitchen = false,
    this.orderType,
  });

  @override
  State<PayCashForm> createState() => _PayCashFormState();
}

class _PayCashFormState extends State<PayCashForm> {
  List<double> _generateQuickAmounts(double remaining) {
    if (remaining < 0.005) return [];

    final amounts = <double>[];

    // First: Always include exact amount
    amounts.add(remaining);

    // Second: Round up to nearest dollar
    final roundedUp = remaining.ceilToDouble();
    if (roundedUp != remaining) {
      amounts.add(roundedUp);
    }

    // Third: Round to nearest 0.50 above the rounded dollar
    // If rounded dollar is 29, then 29.50
    if (roundedUp != remaining) {
      final roundedTo50 = roundedUp + 0.5;
      if (roundedTo50 > remaining && !amounts.contains(roundedTo50)) {
        amounts.add(roundedTo50);
      }
    }

    // Fourth: Round to nearest 5 or next convenient number
    final roundedTo5 = ((remaining / 5).ceil() * 5).toDouble();
    if (roundedTo5 != remaining &&
        roundedTo5 > remaining &&
        !amounts.contains(roundedTo5)) {
      amounts.add(roundedTo5);
    }

    // Limit to 4 values (exact + up to 3 rounded values)
    return amounts.length > 4 ? amounts.sublist(0, 4) : amounts;
  }

  void _handleNumberClick(String num) {
    final current = widget.tendered == '0' ? '' : widget.tendered;
    widget.onTenderedChanged(current + num);
  }

  void _handleClear() {
    widget.onTenderedChanged('0');
  }

  void _handleBackspace() {
    if (widget.tendered.length > 1) {
      widget.onTenderedChanged(
        widget.tendered.substring(0, widget.tendered.length - 1),
      );
    } else {
      widget.onTenderedChanged('0');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenderedValue = double.tryParse(widget.tendered) ?? 0.0;
    final totalTendered = widget.currentPayment + tenderedValue;
    final change = (totalTendered - widget.splitAmount).clamp(
      0.0,
      double.infinity,
    );
    final remaining = (widget.splitAmount - widget.currentPayment).clamp(
      0.0,
      double.infinity,
    );
    final quickAmounts = _generateQuickAmounts(remaining);

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
          // Header with print button
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              color: Colors.white,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pay with Cash',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (widget.onPrint != null)
                  IconButton(
                    icon: const Icon(Icons.print, size: 18),
                    onPressed: widget.onPrint,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
          // Current payment / Total display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.currentPayment.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                  Text(
                    ' / ',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    widget.splitAmount.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Tendered / Change row
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
                        'TENDERED / CHANGE',
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
                        widget.tendered,
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
                  child: Container(
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Center(
                      child: Text(
                        change.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.red.shade800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Keypad and quick amounts
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
                    onConfirm: tenderedValue > 0
                        ? () => widget.onPay(tenderedValue)
                        : null,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    spacing: 4,
                    children: quickAmounts.map((amount) {
                      return SizedBox(
                        width: double.infinity,
                        child: KeypadButton(
                          onPressed: () {
                            widget.onTenderedChanged(amount.toStringAsFixed(2));
                          },
                          child: Text(
                            amount.toStringAsFixed(2),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          // Footer with Send to Kitchen switch
          if (!widget.hideSendToKitchen && widget.orderType == 'prepay')
            Row(
              children: [
                Switch(
                  value: widget.sendToKitchen,
                  onChanged: widget.onSendToKitchenChanged,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Send to Kitchen',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
