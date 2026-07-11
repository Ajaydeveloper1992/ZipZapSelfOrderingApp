import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/models/order_model.dart';
import 'package:zipzap_pos_self_orders/widgets/app_toast.dart';

class VoidItem {
  final OrderItem orderItem;

  VoidItem({required this.orderItem});
}

class VoidModal extends StatefulWidget {
  final Order order;
  final VoidCallback onCancel;
  final Function({required List<VoidItem> items, required String reason})?
  onVoid;

  const VoidModal({
    super.key,
    required this.order,
    required this.onCancel,
    this.onVoid,
  });

  @override
  State<VoidModal> createState() => _VoidModalState();
}

class _VoidModalState extends State<VoidModal> {
  final Map<int, bool> _selectedItems = {};
  final TextEditingController _reasonController = TextEditingController();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();

    // Initialize all items as unselected
    for (int i = 0; i < widget.order.items.length; i++) {
      _selectedItems[i] = false;
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  int get totalVoidItems {
    int count = 0;
    _selectedItems.forEach((index, isSelected) {
      if (isSelected) {
        count++;
      }
    });
    return count;
  }

  // Total quantity of items being voided (for display purposes)
  int get totalVoidQuantity {
    int total = 0;
    _selectedItems.forEach((index, isSelected) {
      if (isSelected) {
        total += widget.order.items[index].quantity;
      }
    });
    return total;
  }

  bool get hasSelectedItems {
    return _selectedItems.values.any((selected) => selected);
  }

  // Check if any selected item has quantity > 1
  bool get hasMultipleQuantityItems {
    for (final entry in _selectedItems.entries) {
      if (entry.value && widget.order.items[entry.key].quantity > 1) {
        return true;
      }
    }
    return false;
  }

  void _toggleItem(int index) {
    final item = widget.order.items[index];
    final isVoided = item.itemStatus?.toLowerCase() == 'voided';
    final isRefunded = item.itemStatus?.toLowerCase() == 'refunded';

    if (isVoided || isRefunded) return;

    setState(() {
      _selectedItems[index] = !_selectedItems[index]!;
    });
  }

  Future<void> _handleVoid() async {
    if (!hasSelectedItems) {
      AppToast.warning(
        context: context,
        title: 'No Items Selected',
        description: 'Please select at least one item to void',
      );
      return;
    }

    if (_reasonController.text.trim().isEmpty) {
      AppToast.warning(
        context: context,
        title: 'Reason Required',
        description: 'Please provide a reason for voiding',
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Build list of void items
      final List<VoidItem> voidItems = [];
      _selectedItems.forEach((index, isSelected) {
        if (isSelected) {
          voidItems.add(VoidItem(orderItem: widget.order.items[index]));
        }
      });

      // Call the onVoid callback if provided
      await widget.onVoid?.call(
        items: voidItems,
        reason: _reasonController.text.trim(),
      );

      if (mounted) {
        AppToast.success(
          context: context,
          title: 'Items Voided',
          description:
              '$totalVoidItems ${totalVoidItems == 1 ? 'item' : 'items'} voided successfully',
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context: context,
          title: 'Void Failed',
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
              Icons.delete_outline,
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
                  'Void Items',
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
              'Select Items to Void',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 250),
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
                padding: const EdgeInsets.all(6),
                itemCount: widget.order.items.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = widget.order.items[index];

                  // Check if item is already voided or refunded
                  final isVoided = item.itemStatus?.toLowerCase() == 'voided';
                  final isRefunded =
                      item.itemStatus?.toLowerCase() == 'refunded' ||
                      item.itemStatus?.toLowerCase() == 'partially refunded';
                  final isSelectable = !isVoided && !isRefunded;
                  final isSelected = _selectedItems[index] ?? false;

                  return InkWell(
                    onTap: isSelectable ? () => _toggleItem(index) : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          // Checkbox or Status indicator
                          if (isVoided || isRefunded)
                            // Show status badge instead of checkbox
                            Container(
                              width: 40,
                              alignment: Alignment.center,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isVoided
                                      ? Colors.red.shade100
                                      : Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isVoided ? 'VOID' : 'REFUNDED',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: isVoided
                                        ? Colors.red.shade700
                                        : Colors.orange.shade700,
                                  ),
                                ),
                              ),
                            )
                          else
                            Transform.scale(
                              scale: 0.85,
                              child: Checkbox(
                                value: isSelected,
                                onChanged: (value) => _toggleItem(index),
                              ),
                            ),
                          // Item details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.displayName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 13,
                                              decoration: isVoided
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                              color: isVoided || isRefunded
                                                  ? Colors.grey
                                                  : null,
                                            ),
                                      ),
                                    ),
                                    // Show quantity badge if > 1
                                    if (item.quantity > 1)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.orange.shade100
                                              : Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          '×${item.quantity}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected
                                                ? Colors.orange.shade800
                                                : Colors.grey.shade700,
                                          ),
                                        ),
                                      )
                                    else
                                      Text(
                                        '×${item.quantity}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                  ],
                                ),
                                // Status text
                                if (isVoided)
                                  Text(
                                    'Voided${item.voidReason != null ? ' - ${item.voidReason}' : ''}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.red.shade600,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  )
                                else if (isRefunded)
                                  Text(
                                    'Refunded',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.orange.shade600,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  )
                                else
                                  Text(
                                    '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Colors.grey.shade600,
                                          fontSize: 11,
                                        ),
                                  ),
                              ],
                            ),
                          ),
                          // Price for voided/refunded items
                          if (isVoided || isRefunded)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Warning for multiple quantity items
            if (hasSelectedItems && hasMultipleQuantityItems) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Selected items with multiple quantities will be voided entirely (all $totalVoidQuantity units)',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Reason section
            Text(
              'Reason for Voiding',
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
                hintText: 'Enter reason for voiding...',
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        spacing: 8,
        children: [
          Expanded(
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
            flex: 2,
            child: FilledButton.icon(
              onPressed: (_isProcessing || !hasSelectedItems)
                  ? null
                  : _handleVoid,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.delete, size: 18),
              label: Text(
                _isProcessing
                    ? 'Processing...'
                    : 'Void $totalVoidItems ${totalVoidItems == 1 ? 'item' : 'items'}',
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
    );
  }
}
