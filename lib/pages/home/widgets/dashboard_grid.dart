import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/models/dashboard_item_model.dart';
import 'package:zipzap_pos_self_orders/pages/home/widgets/navigation_card.dart';

class DashboardGrid extends StatelessWidget {
  final List<DashboardItem> items;
  final Function(String route, Map<String, dynamic>? arguments)? onItemTap;

  const DashboardGrid({super.key, required this.items, this.onItemTap});

  void _handleTap(BuildContext context, DashboardItem item) {
    if (onItemTap != null) {
      onItemTap!(item.route, item.arguments);
    } else {
      // Default navigation handling
      if (item.arguments != null) {
        Navigator.pushNamed(context, item.route, arguments: item.arguments);
      } else {
        Navigator.pushNamed(context, item.route);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use the actual available width from constraints instead of screen width
        final availableWidth = constraints.maxWidth;

        // Responsive card width based on available width
        double cardWidth;
        if (availableWidth < 600) {
          // Small screens: use most of the width
          cardWidth = availableWidth * 0.45;
        } else if (availableWidth < 1024) {
          // Medium screens: fixed width
          cardWidth = 280.0;
        } else {
          // Large screens: slightly wider cards
          cardWidth = 300.0;
        }

        const horizontalPadding = 12.0 * 2; // left + right padding
        const crossAxisSpacing = 12.0;
        final widthForCalculation = availableWidth - horizontalPadding;
        final crossAxisCount =
            (widthForCalculation / (cardWidth + crossAxisSpacing))
                .floor()
                .clamp(1, 10);

        // Calculate actual item width based on available space
        final actualItemWidth =
            (widthForCalculation - (crossAxisSpacing * (crossAxisCount - 1))) /
            crossAxisCount;

        // Responsive aspect ratio based on screen height
        // Target height for cards based on screen size
        double targetHeight;
        if (screenHeight < 600) {
          // Very small screens: compact cards
          targetHeight = 100.0;
        } else if (screenHeight < 800) {
          // Small screens: medium height
          targetHeight = 110.0;
        } else if (screenHeight < 1200) {
          // Medium screens: standard height
          targetHeight = 120.0;
        } else {
          // Large screens: slightly taller cards
          targetHeight = 130.0;
        }

        var childAspectRatio = actualItemWidth / targetHeight;

        // Safety check: ensure childAspectRatio is always positive and reasonable
        if (childAspectRatio <= 0 || !childAspectRatio.isFinite) {
          childAspectRatio = 1.2; // Default fallback value
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: crossAxisSpacing,
            mainAxisSpacing: crossAxisSpacing,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return NavigationCard(
              title: item.title,
              icon: item.icon,
              backgroundColor: item.backgroundColor,
              borderColor: item.borderColor,
              count: item.count,
              onTap: () => _handleTap(context, item),
            );
          },
        );
      },
    );
  }
}
