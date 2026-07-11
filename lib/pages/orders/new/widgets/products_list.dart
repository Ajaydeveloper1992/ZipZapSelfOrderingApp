import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/models/product_model.dart';
import 'package:zipzap_pos_self_orders/pages/orders/new/widgets/stock_badge.dart';
import 'package:zipzap_pos_self_orders/pages/orders/new/widgets/price_badge.dart';
import 'package:zipzap_pos_self_orders/pages/orders/new/widgets/tax_free_badge.dart';

class ProductsList extends StatelessWidget {
  final List<Product> products;
  final Function(Product) onProductTap;
  final List<String> cartProductIds;

  const ProductsList({
    super.key,
    required this.products,
    required this.onProductTap,
    this.cartProductIds = const [],
  });

  @override
  Widget build(BuildContext context) {
    // Sort products by sort value
    final sortedProducts = List<Product>.from(products)
      ..sort((a, b) => a.sort.compareTo(b.sort));

    if (sortedProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No products found',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;

        // Responsive card width based on screen size
        double cardWidth;
        if (screenWidth < 600) {
          // Small screens: use most of the width
          cardWidth = screenWidth * 0.45;
        } else if (screenWidth < 1024) {
          // Medium screens: fixed width
          cardWidth = 180.0;
        } else {
          // Large screens: slightly wider cards
          cardWidth = 200.0;
        }

        const horizontalPadding = 8.0 * 2; // left + right padding
        const crossAxisSpacing = 8.0;
        final availableWidth = screenWidth - horizontalPadding;
        final crossAxisCount = (availableWidth / (cardWidth + crossAxisSpacing))
            .floor()
            .clamp(1, 10);

        // Calculate actual item width based on available space
        final actualItemWidth =
            (availableWidth - (crossAxisSpacing * (crossAxisCount - 1))) /
            crossAxisCount;

        // Target height for product cards (maintains 1.15 aspect ratio)
        final targetHeight = actualItemWidth / 1.15;
        final childAspectRatio = actualItemWidth / targetHeight;

        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: crossAxisSpacing,
            mainAxisSpacing: crossAxisSpacing,
          ),
          itemCount: sortedProducts.length,
          itemBuilder: (context, index) {
            final product = sortedProducts[index];
            final isInCart = cartProductIds.contains(product.id);
            return _ProductCard(
              product: product,
              isInCart: isInCart,
              onTap: () => onProductTap(product),
            );
          },
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final bool isInCart;
  final VoidCallback onTap;

  const _ProductCard({
    required this.product,
    required this.isInCart,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isInCart
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.1),
              width: isInCart ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Product Image/Icon with Price Badge
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: double.infinity,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child:
                            (product.imageUrl != null ||
                                product.images.isNotEmpty)
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(
                                  product.imageUrl ?? product.images.first,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _buildPlaceholderIcon(context),
                                ),
                              )
                            : _buildPlaceholderIcon(context),
                      ),
                      // Gradient overlay for better badge visibility (top area only)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(6),
                              topRight: Radius.circular(6),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                isInCart
                                    ? Theme.of(context).colorScheme.primary
                                          .withValues(alpha: 0.4)
                                    : Colors.black.withValues(alpha: 0.4),
                                isInCart
                                    ? Theme.of(context).colorScheme.primary
                                          .withValues(alpha: 0.2)
                                    : Colors.black.withValues(alpha: 0.2),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Badges should be on top of overlay
                      if (product.trackInventory)
                        StockBadge(
                          stockQuantity: product.stockQuantity,
                          lowStockThreshold: product.lowStockThreshold,
                        ),
                      PriceBadge(price: product.posEffectivePrice),
                      // Show tax-free badge if taxEnable is false
                      if (!product.taxEnable) const TaxFreeBadge(),
                    ],
                  ),
                ),
                // Product Name
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    product.name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon(BuildContext context) {
    return Center(
      child: Icon(
        Icons.fastfood_outlined,
        size: 36,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
      ),
    );
  }
}
