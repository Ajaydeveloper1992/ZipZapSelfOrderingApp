import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/models/order_model.dart' as order_models;
import 'package:zipzap_pos_self_orders/services/orders_service.dart';
import 'package:intl/intl.dart';

class CustomerOrderHistory extends StatefulWidget {
  final String? customerId;
  final String? customerName;
  final Function(List<order_models.OrderItem>)? onReorder;

  const CustomerOrderHistory({
    super.key,
    required this.customerId,
    this.customerName,
    this.onReorder,
  });

  @override
  State<CustomerOrderHistory> createState() => _CustomerOrderHistoryState();
}

class _CustomerOrderHistoryState extends State<CustomerOrderHistory> {
  final OrdersService _ordersService = OrdersService();
  List<order_models.Order>? _orders;
  bool _isLoading = false;
  String? _error;
  String? _expandedOrderId;
  Set<int> _selectedItemIndices = {};

  @override
  void initState() {
    super.initState();
    if (widget.customerId != null && widget.customerId!.isNotEmpty) {
      _loadOrders();
    }
  }

  @override
  void didUpdateWidget(CustomerOrderHistory oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload if customer changed
    if (widget.customerId != oldWidget.customerId) {
      _orders = null;
      _error = null;
      _expandedOrderId = null;
      if (widget.customerId != null && widget.customerId!.isNotEmpty) {
        _loadOrders();
      }
    }
  }

  Future<void> _loadOrders() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _ordersService.getOrdersByCustomer(
        customerId: widget.customerId!,
        sortBy: 'createdAt',
        sortOrder: 'desc',
      );

      if (mounted) {
        setState(() {
          _orders = response.orders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'complete':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'inkitchen':
        return Colors.blue;
      case 'voided':
      case 'rejected':
        return Colors.red;
      case 'refunded':
      case 'partially refunded':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'complete':
        return Icons.check_circle;
      case 'pending':
        return Icons.schedule;
      case 'inkitchen':
        return Icons.restaurant;
      case 'voided':
      case 'rejected':
        return Icons.cancel;
      case 'refunded':
      case 'partially refunded':
        return Icons.money_off;
      default:
        return Icons.info;
    }
  }

  void _handleReorder(order_models.Order order) {
    // Get visible (non-voided) items
    final visibleItems = order.items
        .where((item) => item.itemStatus?.toLowerCase() != 'voided')
        .toList();

    final selectedItems = _selectedItemIndices
        .where((index) => index < visibleItems.length)
        .map((index) => visibleItems[index])
        .toList();

    if (selectedItems.isNotEmpty) {
      widget.onReorder?.call(selectedItems);
      // Collapse the order after re-ordering
      setState(() {
        _expandedOrderId = null;
        _selectedItemIndices.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // No customer selected
    if (widget.customerId == null || widget.customerId!.isEmpty) {
      return _buildEmptyState(
        icon: Icons.person_search,
        title: 'Select a customer',
        subtitle: 'Choose a customer to view their order history',
      );
    }

    // Loading state
    if (_isLoading && _orders == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Error state
    if (_error != null) {
      return _buildErrorState();
    }

    // Empty orders
    if (_orders == null || _orders!.isEmpty) {
      return _buildEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No orders yet',
        subtitle: 'This customer hasn\'t placed any orders',
      );
    }

    // Orders list
    return Column(
      children: [
        // Header with count
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.1),
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.history,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '${_orders!.length} Order${_orders!.length == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Refresh',
                onPressed: _loadOrders,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
        // Orders list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: _orders!.length,
            itemBuilder: (context, index) {
              final order = _orders![index];
              final isExpanded = _expandedOrderId == order.id;
              return _buildOrderCard(order, isExpanded);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(order_models.Order order, bool isExpanded) {
    final statusColor = _getStatusColor(order.orderstatus);
    final statusIcon = _getStatusIcon(order.orderstatus);
    final orderDate = order.date;
    final formattedDate = DateFormat('MMM dd, yyyy').format(orderDate);
    final formattedTime = DateFormat('hh:mm a').format(orderDate);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(
          color: isExpanded
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: isExpanded ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        color: isExpanded
            ? Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.05)
            : Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        children: [
          // Header (always visible)
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedOrderId = null;
                  _selectedItemIndices.clear();
                } else {
                  _expandedOrderId = order.id;
                  // Select all non-voided items by default
                  final visibleItems = order.items
                      .where(
                        (item) => item.itemStatus?.toLowerCase() != 'voided',
                      )
                      .toList();
                  _selectedItemIndices = Set.from(
                    List.generate(visibleItems.length, (i) => i),
                  );
                }
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Order number
                      Expanded(
                        child: Text(
                          order.orderNumber,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                        ),
                      ),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 12, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              order.orderstatus,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Expand icon
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 20,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Date, Items, Total
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 13,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formattedDate,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '•',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formattedTime,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.shopping_bag_outlined,
                        size: 13,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${order.items.where((item) => item.itemStatus?.toLowerCase() != 'voided').length}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '\$${order.total.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Expanded content
          if (isExpanded) _buildExpandedContent(order),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(order_models.Order order) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          // Order items
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Order Items',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    Builder(
                      builder: (context) {
                        final visibleItems = order.items
                            .where(
                              (item) =>
                                  item.itemStatus?.toLowerCase() != 'voided',
                            )
                            .toList();
                        return TextButton(
                          onPressed: () {
                            setState(() {
                              if (_selectedItemIndices.length ==
                                  visibleItems.length) {
                                _selectedItemIndices.clear();
                              } else {
                                _selectedItemIndices = Set.from(
                                  List.generate(visibleItems.length, (i) => i),
                                );
                              }
                            });
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            _selectedItemIndices.length == visibleItems.length
                                ? 'Deselect All'
                                : 'Select All',
                            style: const TextStyle(fontSize: 11),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Filter out voided items
                ...order.items
                    .where((item) => item.itemStatus?.toLowerCase() != 'voided')
                    .toList()
                    .asMap()
                    .entries
                    .map((entry) => _buildOrderItem(entry.value, entry.key)),
                const SizedBox(height: 12),
                // Order summary
                _buildOrderSummary(order),
              ],
            ),
          ),
          // Re-order button
          if (widget.onReorder != null &&
              order.orderstatus.toLowerCase() != 'voided' &&
              order.orderstatus.toLowerCase() != 'rejected' &&
              order.orderstatus.toLowerCase() != 'refunded')
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _selectedItemIndices.isEmpty
                      ? null
                      : () => _handleReorder(order),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(
                    _selectedItemIndices.isEmpty
                        ? 'Re-order'
                        : 'Re-order (${_selectedItemIndices.length})',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(order_models.OrderItem item, int index) {
    final itemName = item.customItem.isNotEmpty
        ? item.customItem
        : (item.item?.name ?? 'Unknown');
    final hasNote = item.itemNote?.isNotEmpty ?? false;
    final isSelected = _selectedItemIndices.contains(index);

    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedItemIndices.remove(index);
          } else {
            _selectedItemIndices.add(index);
          }
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox
            Checkbox(
              value: isSelected,
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    _selectedItemIndices.add(index);
                  } else {
                    _selectedItemIndices.remove(index);
                  }
                });
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
            // Quantity badge
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Center(
                child: Text(
                  '${item.quantity}×',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Item details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    itemName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.modifiers.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.modifiers.map((m) => m.name).join(', '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                  if (hasNote) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.note,
                          size: 11,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.itemNote ?? '',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Item price
            Text(
              '\$${(item.price * item.quantity).toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary(order_models.Order order) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          _buildSummaryRow('Subtotal', order.subtotal),
          if (order.tax > 0) ...[
            const SizedBox(height: 6),
            _buildSummaryRow('Tax', order.tax),
          ],
          if (order.tip > 0) ...[
            const SizedBox(height: 6),
            _buildSummaryRow('Tip', order.tip),
          ],
          const SizedBox(height: 8),
          Container(
            height: 1,
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Total',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '\$${order.total.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount) {
    return Row(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
        const Spacer(),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _loadOrders,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }
}
