import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/models/product_model.dart';
import 'package:zipzap_pos_self_orders/models/category_model.dart';

class CategoriesSidebar extends StatelessWidget {
  final List<Category> categories;
  final List<Product> products;
  final String? selectedCategoryId;
  final Function(String?) onCategorySelected;

  const CategoriesSidebar({
    super.key,
    required this.categories,
    required this.products,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  int _getProductCountForCategory(String categoryId) {
    return products.where((product) => product.category == categoryId).length;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth >= 1280;
    final sidebarWidth = isLargeScreen ? 176.0 : 112.0;
    final isInDrawer = screenWidth < 1024;

    return Container(
      width: isInDrawer ? double.infinity : sidebarWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        border: isInDrawer
            ? null
            : Border(
                right: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.1),
                ),
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(4),
              itemCount: categories.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  final isSelected = selectedCategoryId == null;
                  return _buildCategoryItem(
                    context,
                    label: 'All Products',
                    count: products.length,
                    isSelected: isSelected,
                    onTap: () => onCategorySelected(null),
                    isLast: index == categories.length,
                  );
                }
                final category = categories[index - 1];
                final count = _getProductCountForCategory(category.id);
                final isSelected = selectedCategoryId == category.id;
                return _buildCategoryItem(
                  context,
                  label: category.name.toLowerCase(),
                  count: count,
                  isSelected: isSelected,
                  onTap: () => onCategorySelected(category.id),
                  isLast: index == categories.length,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(
    BuildContext context, {
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isLast,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth >= 1280;
    final leftBorderWidth = isLargeScreen ? 6.0 : 4.0;
    final horizontalPadding = isLargeScreen ? 8.0 : 6.0;
    final height = isLargeScreen ? 40.0 : 32.0;
    final fontSize = 13.5;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          splashColor: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
              : Colors.grey.shade200,
          highlightColor: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.05)
              : Colors.grey.shade100,
          child: Container(
            height: height,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: isSelected
                  ? Border(
                      left: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: leftBorderWidth,
                      ),
                      top: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1,
                      ),
                      right: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1,
                      ),
                      bottom: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1,
                      ),
                    )
                  : Border(
                      left: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: leftBorderWidth,
                      ),
                    ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  offset: const Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
