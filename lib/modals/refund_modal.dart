import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/models/order_model.dart';
import 'package:zipzap_pos_self_orders/widgets/app_toast.dart';

class RefundItem {
  final OrderItem orderItem;
  final int refundQuantity;

  RefundItem({required this.orderItem, required this.refundQuantity});
}

class RefundModal extends StatefulWidget {
  final Order order;
  final VoidCallback onCancel;
  final Function({
    required List<RefundItem> items,
    required String paymentMethod,
    required String reason,
  })?
  onRefund;

  const RefundModal({
    super.key,
    required this.order,
    required this.onCancel,
    this.onRefund,
  });

  @override
  State<RefundModal> createState() => _RefundModalState();
}

class _RefundModalState extends State<RefundModal> {
  final Map<int, bool> _selectedItems = {};
  final Map<int, int> _refundQuantities = {};
  final TextEditingController _reasonController = TextEditingController();
  String _selectedPaymentMethod = 'Cash';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Initialize with Cash as default
    _selectedPaymentMethod = 'Cash';

    // Initialize all items as unselected
    for (int i = 0; i < widget.order.items.length; i++) {
      _selectedItems[i] = false;
      _refundQuantities[i] = 0;
    }
  }

  double _calculateItemPriceWithModifiers(OrderItem item) {
    // item.price from API already includes modifier price adjustments
    // Just return the price directly
    return item.price;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  List<String> get availablePaymentMethods {
    return ['Cash', 'Card'];
  }

  // Check if the original order payment method is Cash
  bool get isOriginalPaymentCash {
    if (widget.order.payments.isEmpty) return false;
    // Check if all payments are Cash
    return widget.order.payments.every((payment) => payment.method == 'Cash');
  }

  double get totalRefundAmount {
    // Calculate the refund subtotal (sum of item prices * quantities)
    double refundSubtotal = 0.0;
    _selectedItems.forEach((index, isSelected) {
      if (isSelected && _refundQuantities[index]! > 0) {
        final item = widget.order.items[index];
        final refundQty = _refundQuantities[index]!;
        refundSubtotal += _calculateItemPriceWithModifiers(item) * refundQty;
      }
    });

    if (refundSubtotal <= 0) return 0.0;

    // Calculate proportional discount and tax based on order totals
    final orderSubtotal = widget.order.subtotal;
    if (orderSubtotal <= 0) return refundSubtotal;

    // Calculate what proportion of the order is being refunded
    final proportion = refundSubtotal / orderSubtotal;

    // Calculate proportional discount
    double proportionalDiscount = 0.0;
    if (widget.order.discount != null && widget.order.discount!.value > 0) {
      if (widget.order.discount!.type == '%') {
        // Percentage discount - apply same percentage to refund subtotal
        proportionalDiscount =
            refundSubtotal * (widget.order.discount!.value / 100);
      } else {
        // Fixed amount discount - distribute proportionally
        proportionalDiscount = widget.order.discount!.value * proportion;
      }
    }

    // Calculate proportional tax
    final proportionalTax = widget.order.tax * proportion;

    // Total refund = subtotal - discount + tax
    final total = refundSubtotal - proportionalDiscount + proportionalTax;

    return total > 0 ? total : 0.0;
  }

  // Get just the item subtotal for display (without discount/tax)
  double get refundItemSubtotal {
    double total = 0.0;
    _selectedItems.forEach((index, isSelected) {
      if (isSelected && _refundQuantities[index]! > 0) {
        final item = widget.order.items[index];
        final refundQty = _refundQuantities[index]!;
        total += _calculateItemPriceWithModifiers(item) * refundQty;
      }
    });
    return total;
  }

  // Get proportional discount amount
  double get refundDiscount {
    final subtotal = refundItemSubtotal;
    if (subtotal <= 0 || widget.order.subtotal <= 0) return 0.0;

    final proportion = subtotal / widget.order.subtotal;

    if (widget.order.discount != null && widget.order.discount!.value > 0) {
      if (widget.order.discount!.type == '%') {
        return subtotal * (widget.order.discount!.value / 100);
      } else {
        return widget.order.discount!.value * proportion;
      }
    }
    return 0.0;
  }

  // Get proportional tax amount
  double get refundTax {
    final subtotal = refundItemSubtotal;
    if (subtotal <= 0 || widget.order.subtotal <= 0) return 0.0;

    final proportion = subtotal / widget.order.subtotal;
    return widget.order.tax * proportion;
  }

  int get totalRefundItems {
    int total = 0;
    _selectedItems.forEach((index, isSelected) {
      if (isSelected && _refundQuantities[index]! > 0) {
        total += _refundQuantities[index]!;
      }
    });
    return total;
  }

  bool get hasSelectedItems {
    return _selectedItems.values.any((selected) => selected) &&
        _refundQuantities.values.any((qty) => qty > 0);
  }

  void _toggleItem(int index) {
    setState(() {
      _selectedItems[index] = !_selectedItems[index]!;
      if (_selectedItems[index]!) {
        // If selected, set default quantity to available quantity
        final item = widget.order.items[index];
        final alreadyRefunded = item.refundQuantity ?? 0;
        // If item is voided, entire quantity is voided
        final isVoided = item.itemStatus?.toLowerCase() == 'voided';
        final availableQty = isVoided ? 0 : item.quantity - alreadyRefunded;
        _refundQuantities[index] = availableQty > 0 ? 1 : 0;
      } else {
        // If unselected, reset quantity
        _refundQuantities[index] = 0;
      }
    });
  }

  void _updateQuantity(int index, int quantity) {
    setState(() {
      final item = widget.order.items[index];
      final alreadyRefunded = item.refundQuantity ?? 0;
      // If item is voided, entire quantity is voided
      final isVoided = item.itemStatus?.toLowerCase() == 'voided';
      final availableQty = isVoided ? 0 : item.quantity - alreadyRefunded;

      // Ensure quantity is within valid range
      if (quantity > 0 && quantity <= availableQty) {
        _refundQuantities[index] = quantity;
        _selectedItems[index] = true;
      } else if (quantity <= 0) {
        _refundQuantities[index] = 0;
        _selectedItems[index] = false;
      }
    });
  }

  Future<void> _handleRefund() async {
    if (!hasSelectedItems) {
      AppToast.warning(
        context: context,
        title: 'No Items Selected',
        description: 'Please select at least one item to refund',
      );
      return;
    }

    if (_reasonController.text.trim().isEmpty) {
      AppToast.warning(
        context: context,
        title: 'Reason Required',
        description: 'Please provide a reason for the refund',
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Build list of refund items
      final List<RefundItem> refundItems = [];
      _selectedItems.forEach((index, isSelected) {
        if (isSelected && _refundQuantities[index]! > 0) {
          refundItems.add(
            RefundItem(
              orderItem: widget.order.items[index],
              refundQuantity: _refundQuantities[index]!,
            ),
          );
        }
      });

      // Call the onRefund callback if provided
      await widget.onRefund?.call(
        items: refundItems,
        paymentMethod: _selectedPaymentMethod,
        reason: _reasonController.text.trim(),
      );

      if (mounted) {
        AppToast.success(
          context: context,
          title: 'Refund Processed',
          description:
              'Refund of \$${totalRefundAmount.toStringAsFixed(2)} has been processed successfully',
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context: context,
          title: 'Refund Failed',
          description: e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 768;
    final modalWidth = isSmallScreen ? screenWidth * 0.9 : 450.0;

    // Calculate max height based on screen size
    final calculatedMaxHeight = isSmallScreen
        ? screenHeight * 0.75
        : screenHeight * 0.65;

    // Ensure minHeight doesn't exceed maxHeight
    final minHeight = calculatedMaxHeight < 450 ? calculatedMaxHeight : 450.0;
    final maxHeight = calculatedMaxHeight;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: modalWidth,
        constraints: BoxConstraints(minHeight: minHeight, maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            Expanded(child: _buildContent(context)),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              Icons.undo_rounded,
              color: Theme.of(context).colorScheme.error,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Refund Order',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Order #${widget.order.orderNumber}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: widget.onCancel,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.error.withValues(alpha: 0.1),
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Items section
            Text(
              'Select Items to Refund',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.3),
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(0),
                itemCount: widget.order.items.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = widget.order.items[index];
                  final alreadyRefunded = item.refundQuantity ?? 0;
                  // If item is voided, entire quantity is voided
                  final isVoided = item.itemStatus?.toLowerCase() == 'voided';
                  final availableQty = isVoided
                      ? 0
                      : item.quantity - alreadyRefunded;
                  final isRefundable =
                      availableQty > 0 &&
                      !isVoided &&
                      item.itemStatus?.toLowerCase() != 'refunded';

                  return Opacity(
                    opacity: isRefundable ? 1.0 : 0.5,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          // Checkbox
                          Transform.scale(
                            scale: 0.85,
                            child: Checkbox(
                              value: _selectedItems[index] ?? false,
                              onChanged: isRefundable
                                  ? (value) => _toggleItem(index)
                                  : null,
                            ),
                          ),
                          // Item name
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.displayName,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                ),
                                if (!isRefundable)
                                  Text(
                                    isVoided
                                        ? 'Already voided'
                                        : item.itemStatus?.toLowerCase() ==
                                              'refunded'
                                        ? 'Already refunded'
                                        : 'Not available (refunded: $alreadyRefunded)',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                          fontSize: 10,
                                        ),
                                  )
                                else
                                  Text(
                                    'Available: $availableQty × \$${_calculateItemPriceWithModifiers(item).toStringAsFixed(2)}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Colors.grey.shade600,
                                          fontSize: 10,
                                        ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Quantity controls
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove, size: 16),
                                onPressed:
                                    (isRefundable &&
                                        (_selectedItems[index] ?? false) &&
                                        (_refundQuantities[index] ?? 0) > 1)
                                    ? () {
                                        _updateQuantity(
                                          index,
                                          (_refundQuantities[index] ?? 0) - 1,
                                        );
                                      }
                                    : null,
                                style: IconButton.styleFrom(
                                  padding: const EdgeInsets.all(4),
                                  minimumSize: const Size(24, 24),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                              SizedBox(
                                width: 32,
                                child: TextField(
                                  enabled:
                                      isRefundable &&
                                      (_selectedItems[index] ?? false),
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                  ),
                                  controller:
                                      TextEditingController(
                                          text:
                                              (_refundQuantities[index] ?? 0) >
                                                  0
                                              ? _refundQuantities[index]
                                                    .toString()
                                              : '0',
                                        )
                                        ..selection = TextSelection.collapsed(
                                          offset:
                                              (_refundQuantities[index] ?? 0) >
                                                  0
                                              ? _refundQuantities[index]
                                                    .toString()
                                                    .length
                                              : 1,
                                        ),
                                  onChanged: (value) {
                                    final qty = int.tryParse(value) ?? 0;
                                    _updateQuantity(index, qty);
                                  },
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add, size: 16),
                                onPressed:
                                    (isRefundable &&
                                        (_selectedItems[index] ?? false) &&
                                        (_refundQuantities[index] ?? 0) <
                                            availableQty)
                                    ? () {
                                        _updateQuantity(
                                          index,
                                          (_refundQuantities[index] ?? 0) + 1,
                                        );
                                      }
                                    : null,
                                style: IconButton.styleFrom(
                                  padding: const EdgeInsets.all(4),
                                  minimumSize: const Size(24, 24),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Payment method section
            Text(
              'Refund Payment Method',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: availablePaymentMethods.map((method) {
                final isSelected = _selectedPaymentMethod == method;
                final isDisabled = method == 'Card' && isOriginalPaymentCash;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: method == availablePaymentMethods.last ? 0 : 8,
                    ),
                    child: InkWell(
                      onTap: isDisabled
                          ? null
                          : () {
                              setState(() {
                                _selectedPaymentMethod = method;
                              });
                            },
                      borderRadius: BorderRadius.circular(6),
                      child: Opacity(
                        opacity: isDisabled ? 0.5 : 1.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outline
                                        .withValues(alpha: 0.3),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                method == 'Cash'
                                    ? Icons.payments_outlined
                                    : Icons.credit_card,
                                size: 18,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : isDisabled
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                method,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : isDisabled
                                      ? Colors.grey.shade400
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Reason section
            Text(
              'Reason for Refunding',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _reasonController,
              maxLines: 2,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Enter reason for refund...',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final hasDiscount = refundDiscount > 0;
    final hasTax = refundTax > 0;
    final showBreakdown = hasSelectedItems && (hasDiscount || hasTax);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Show refund breakdown if there's discount or tax
          if (showBreakdown) ...[
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _buildBreakdownRow('Item Subtotal', refundItemSubtotal),
                  if (hasDiscount)
                    _buildBreakdownRow(
                      'Discount${widget.order.discount?.type == '%' ? ' (${widget.order.discount!.value.toStringAsFixed(widget.order.discount!.value % 1 == 0 ? 0 : 2)}%)' : ''}',
                      -refundDiscount,
                      isDiscount: true,
                    ),
                  if (hasTax) _buildBreakdownRow('Tax', refundTax),
                  const Divider(height: 12),
                  _buildBreakdownRow(
                    'Total Refund',
                    totalRefundAmount,
                    isTotal: true,
                  ),
                ],
              ),
            ),
          ],
          Row(
            spacing: 8,
            children: [
              Expanded(
                flex: 3,
                child: OutlinedButton.icon(
                  onPressed: _isProcessing ? null : widget.onCancel,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Cancel', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    side: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: FilledButton.icon(
                  onPressed: (_isProcessing || !hasSelectedItems)
                      ? null
                      : _handleRefund,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: Text(
                    _isProcessing
                        ? 'Processing...'
                        : 'Refund \$${totalRefundAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(
    String label,
    double amount, {
    bool isDiscount = false,
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 13 : 12,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
              color: isTotal ? Colors.black87 : Colors.grey.shade700,
            ),
          ),
          Text(
            '${isDiscount ? '-' : ''}\$${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 13 : 12,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500,
              color: isDiscount
                  ? Colors.green.shade700
                  : isTotal
                  ? Colors.red.shade700
                  : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
