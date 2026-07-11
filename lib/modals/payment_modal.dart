import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/widgets/payment/payment_tip.dart';
import 'package:zipzap_pos_self_orders/widgets/payment/pay_cash_form.dart';
import 'package:zipzap_pos_self_orders/widgets/payment/pay_card_form.dart';

class PaymentModal extends StatefulWidget {
  final double totalAmount;
  final double currentPaid;
  final Map<String, dynamic> currentTip;
  final String? orderType;
  final Function(
    double cashAmount,
    double cardAmount,
    Map<String, dynamic> tip,
    bool sendToKitchen,
  )
  onConfirm;
  final VoidCallback onCancel;
  final VoidCallback? onPrint;
  final bool isPosTipEnable;

  const PaymentModal({
    super.key,
    required this.totalAmount,
    required this.currentPaid,
    required this.currentTip,
    this.orderType,
    required this.onConfirm,
    required this.onCancel,
    this.onPrint,
    this.isPosTipEnable = true,
  });

  @override
  State<PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends State<PaymentModal> {
  String _step = 'tip'; // 'tip', 'payment'
  String _paymentMethod = 'Cash';
  String _cardType = 'Visa';
  String _tendered = '0';
  double _cashAmount = 0.0;
  double _cardAmount = 0.0;
  Map<String, dynamic> _tip = {'amount': 0, 'type': '\$'};
  bool _sendToKitchen = false;

  @override
  void initState() {
    super.initState();
    _tip = Map<String, dynamic>.from(widget.currentTip);
    _cashAmount = widget.currentPaid;
    // Skip tip step if tip is disabled
    if (!widget.isPosTipEnable) {
      _step = 'payment';
    }
  }

  double get _splitAmount {
    final tipValue = _tip['amount']?.toDouble() ?? 0.0;
    final tipAmount = _tip['type'] == '%'
        ? (widget.totalAmount * tipValue) / 100
        : tipValue;
    return widget.totalAmount + tipAmount;
  }

  double get _remaining => _splitAmount - _cashAmount - _cardAmount;

  void _handleTipNext(double amount, String type) {
    setState(() {
      _tip = {'amount': amount, 'type': type};
      _step = 'payment';
    });
  }

  void _handleTenderedChanged(String value) {
    setState(() {
      _tendered = value;
    });
  }

  void _handleCashPay(double amount) {
    setState(() {
      _cashAmount += amount;
      _tendered = '0';
    });

    // Use half-cent tolerance to avoid floating-point precision blocking confirmation
    if (_remaining < 0.005) {
      _handleConfirm();
    }
  }

  void _handleCardPay(double amount) {
    setState(() {
      _cardAmount = amount;
    });
    _handleConfirm();
  }

  void _handleConfirm() {
    widget.onConfirm(_cashAmount, _cardAmount, _tip, _sendToKitchen);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;
    final modalWidth = isSmallScreen
        ? screenWidth * 0.95
        : (screenWidth < 1024 ? 650.0 : 700.0);

    return Dialog(
      child: Container(
        width: modalWidth,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: _step == 'tip'
            ? PaymentTip(
                currentSplitAmount: widget.totalAmount,
                existingTip: widget.currentTip,
                onNext: _handleTipNext,
                onCancel: widget.onCancel,
              )
            : Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  spacing: 8,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with tabs
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                        color: Colors.white,
                      ),
                      child: Row(
                        spacing: 8,
                        children: [
                          Expanded(
                            child: _buildTabButton(
                              'Cash',
                              _paymentMethod == 'Cash',
                            ),
                          ),
                          Expanded(
                            child: _buildTabButton(
                              'Card',
                              _paymentMethod == 'Card',
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Payment content
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: _paymentMethod == 'Cash'
                            ? PayCashForm(
                                splitAmount: _splitAmount,
                                currentPayment: _cashAmount,
                                tendered: _tendered,
                                onTenderedChanged: _handleTenderedChanged,
                                onPay: _handleCashPay,
                                sendToKitchen: _sendToKitchen,
                                onSendToKitchenChanged: (value) {
                                  setState(() {
                                    _sendToKitchen = value;
                                  });
                                },
                                onPrint: widget.onPrint,
                                hideSendToKitchen: false,
                                orderType: widget.orderType,
                              )
                            : PayCardForm(
                                remainingAmount: _remaining,
                                onPay: _handleCardPay,
                                cardType: _cardType,
                                onCardTypeChanged: (type) {
                                  setState(() {
                                    _cardType = type;
                                  });
                                },
                              ),
                      ),
                    ),
                    // Footer buttons
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
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
                              onPressed: widget.isPosTipEnable
                                  ? () {
                                      setState(() {
                                        _step = 'tip';
                                      });
                                    }
                                  : () {
                                      widget.onCancel();
                                    },
                              icon: Icon(
                                widget.isPosTipEnable
                                    ? Icons.arrow_back
                                    : Icons.close,
                              ),
                              label: Text(
                                widget.isPosTipEnable ? 'Back' : 'Cancel',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.error,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _paymentMethod == 'Cash'
                                  ? (double.tryParse(_tendered) ?? 0.0) > 0
                                        ? () => _handleCashPay(
                                            double.tryParse(_tendered) ?? 0.0,
                                          )
                                        : null
                                  : _remaining > 0.005
                                  ? () => _handleCardPay(_remaining)
                                  : null,
                              icon: const Icon(Icons.payment),
                              label: Text(
                                _paymentMethod == 'Cash'
                                    ? 'Pay \$${(double.tryParse(_tendered) ?? 0.0).toStringAsFixed(2)}'
                                    : 'Pay \$${_remaining.toStringAsFixed(2)}',
                              ),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
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
              ),
      ),
    );
  }

  Widget _buildTabButton(String label, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          _paymentMethod = label;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label == 'Card' ? 'Credit Card' : label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
