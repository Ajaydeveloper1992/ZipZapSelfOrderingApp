import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/models/order_model.dart';
import 'package:zipzap_pos_self_orders/pages/takeouts/widgets/order_item_card.dart';

class OrderList extends StatelessWidget {
  final List<Order> orders;
  final Function(Order)? onOrderTap;

  const OrderList({super.key, required this.orders, this.onOrderTap});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No orders found',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Responsive card width based on screen size
    double cardWidth;
    if (screenWidth < 600) {
      // Small screens: use most of the width
      cardWidth = screenWidth * 0.45;
    } else if (screenWidth < 1024) {
      // Medium screens: fixed width
      cardWidth = 280.0;
    } else {
      // Large screens: slightly wider cards
      cardWidth = 300.0;
    }

    const horizontalPadding = 12.0 * 2; // left + right padding
    const crossAxisSpacing = 6.0;
    final availableWidth = screenWidth - horizontalPadding;
    final crossAxisCount = (availableWidth / (cardWidth + crossAxisSpacing))
        .floor()
        .clamp(1, 10);

    // Calculate actual item width based on available space
    final actualItemWidth =
        (availableWidth - (crossAxisSpacing * (crossAxisCount - 1))) /
        crossAxisCount;

    // Responsive aspect ratio based on screen height
    // Target height for cards based on screen size
    // Minimum height needed: ~180px (padding + header + 5 rows + footer)
    double targetHeight;
    if (screenHeight < 600) {
      // Very small screens: compact cards
      targetHeight = 160.0;
    } else if (screenHeight < 800) {
      // Small screens: medium height
      targetHeight = 180.0;
    } else if (screenHeight < 1200) {
      // Medium screens: standard height (1280px width typically has ~800-1000px height)
      targetHeight = 190.0;
    } else {
      // Large screens: slightly taller cards
      targetHeight = 200.0;
    }

    final childAspectRatio = actualItemWidth / targetHeight;

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: crossAxisSpacing,
      ),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return OrderItemCard(
          order: order,
          onTap: onOrderTap != null ? () => onOrderTap!(order) : null,
        );
      },
    );
  }
}
