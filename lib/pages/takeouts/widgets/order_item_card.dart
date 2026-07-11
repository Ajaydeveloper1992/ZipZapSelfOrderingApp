import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zipzap_pos_self_orders/models/order_model.dart';

class OrderItemCard extends StatelessWidget {
  final Order order;
  final VoidCallback? onTap;

  const OrderItemCard({super.key, required this.order, this.onTap});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'InKitchen':
        return Colors.green;
      case 'Paid':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _getOriginColor(String origin) {
    switch (origin) {
      case 'AI':
        return Colors.purple;
      case 'POS':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  String _getPickupTime() {
    // Prioritize delayTime first (updated time) - now DateTime
    if (order.pickupInfo?.delayTime != null) {
      return DateFormat('h:mm a').format(order.pickupInfo!.delayTime!);
    }
    // Fallback to pickupTime (user selected time) - now DateTime
    if (order.pickupInfo?.pickupTime != null) {
      return DateFormat('h:mm a').format(order.pickupInfo!.pickupTime!);
    }
    // null pickupTime = ASAP
    return 'ASAP';
  }

  String _getOrderNote() {
    // Get order-level note first
    if (order.note != null && order.note!.isNotEmpty) {
      return order.note!;
    }
    // Fallback to comment if note is not available
    if (order.comment != null && order.comment!.isNotEmpty) {
      return order.comment!;
    }
    return '_________________';
  }

  int _getTotalItems() {
    return order.activeItemCount;
  }

  IconData _getOrderTypeIcon() {
    switch (order.orderType) {
      case 'Pickup':
        return Icons.shopping_bag_outlined;
      case 'Delivery':
        return Icons.delivery_dining_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  IconData _getStatusIcon() {
    switch (order.orderstatus) {
      case 'Pending':
        return Icons.schedule;
      case 'InKitchen':
        return Icons.done_all;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      color: order.orderstatus == 'Pending'
          ? Colors.yellow.shade100
          : order.orderstatus == 'InKitchen'
          ? Colors.green.shade50
          : Colors.white,
      shape: RoundedRectangleBorder(),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header Row: Order Number + Icons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left: Order Number
                      Expanded(
                        child: Text(
                          '#${order.orderNumber}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Right: Icons Row
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Paid Badge
                          if (order.paymentStatus == 'Paid')
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'PAID',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (order.paymentStatus == 'Paid')
                            const SizedBox(width: 6),
                          // Order Type Icon
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: _getOriginColor(
                                order.origin,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              _getOrderTypeIcon(),
                              size: 20,
                              color: _getOriginColor(order.origin),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Status Icon
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(
                                order.orderstatus,
                              ).withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              _getStatusIcon(),
                              size: 20,
                              color: _getStatusColor(order.orderstatus),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Customer Name
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 14,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          order.customer != null &&
                                  order.customer!.fullName.isNotEmpty
                              ? order.customer!.fullName
                              : 'Guest',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Phone
                  Row(
                    children: [
                      Icon(
                        Icons.phone_outlined,
                        size: 14,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          order.customer != null &&
                                  order.customer!.phone.isNotEmpty
                              ? order.customer!.phone
                              : 'N/A',
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Pickup Time
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _getPickupTime(),
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Note
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.note_outlined,
                        size: 14,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _getOrderNote(),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.grey.shade700,
                                fontStyle: _getOrderNote() == 'No notes'
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Footer: Total Items + Total Price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Total Items
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 16,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_getTotalItems()} ${_getTotalItems() == 1 ? 'item' : 'items'}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                      // Total Price
                      Text(
                        '\$${order.total.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ],
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
