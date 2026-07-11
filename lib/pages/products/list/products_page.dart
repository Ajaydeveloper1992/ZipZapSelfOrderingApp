import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/widgets/header/widget.dart';
import 'package:zipzap_pos_self_orders/widgets/app_drawer.dart';
import 'package:zipzap_pos_self_orders/models/product_model.dart';
import 'package:zipzap_pos_self_orders/pages/products/list/widgets/products_filters.dart';
import 'package:zipzap_pos_self_orders/pages/orders/list/widgets/orders_pagination.dart';
import 'package:zipzap_pos_self_orders/providers/data_provider.dart';
import 'package:zipzap_pos_self_orders/services/products_service.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final DataProvider _dataProvider = DataProvider();
  final ProductsService _productsService = ProductsService();
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  List<Product> _paginatedProducts = [];
  Set<String> _selectedProductIds = {};
  bool _selectAll = false;
  Set<String> _updatingProductIds = {};

  // Filter state
  String _selectedStatus = 'all';
  String _searchQuery = '';
  DateTimeRange? _dateRange;

  // Sort state
  int? _sortColumnIndex;
  bool _sortAscending = true;

  // Pagination state
  int _currentPage = 1;
  int _rowsPerPage = 25;
  final List<int> _rowsPerPageOptions = [10, 25, 50, 100];

  @override
  void initState() {
    super.initState();
    _setupDataProviderListener();
    _loadProducts();
  }

  @override
  void dispose() {
    _dataProvider.removeListener(_onDataUpdate);
    super.dispose();
  }

  void _setupDataProviderListener() {
    _dataProvider.addListener(_onDataUpdate);
  }

  void _onDataUpdate() {
    // Update products when DataProvider notifies
    if (mounted) {
      _updateProductsFromProvider();
    }
  }

  void _updateProductsFromProvider() {
    setState(() {
      // Get products from DataProvider
      _allProducts = _dataProvider.productsList
          .toList()
          .reversed
          .toList(); // Most recent first
      _applyFilters();
    });
  }

  Future<void> _loadProducts({bool forceRefresh = false}) async {
    try {
      // If forcing refresh, trigger DataProvider to refetch
      if (forceRefresh) {
        await _dataProvider.loadProducts(forceRefresh: true);
      }

      // Update from provider
      _updateProductsFromProvider();
    } catch (e) {
      debugPrint('Error loading products: $e');
    }
  }

  void _applyFilters() {
    List<Product> filtered = List.from(_allProducts);

    // Status filter
    // Active = status == 'active' && isAvailable && showOnPos && showOnWeb
    // Inactive = status != 'active' || !isAvailable || !showOnPos || !showOnWeb
    if (_selectedStatus != 'all') {
      filtered = filtered.where((product) {
        final isFullyActive =
            product.status == 'active' &&
            product.isAvailable &&
            product.showOnPos &&
            product.showOnWeb;
        if (_selectedStatus == 'active') {
          return isFullyActive;
        } else if (_selectedStatus == 'inactive') {
          return !isFullyActive;
        } else if (_selectedStatus == 'lowstock') {
          return product.trackInventory &&
              product.stockQuantity <= product.lowStockThreshold;
        }
        return true;
      }).toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((product) {
        return product.name.toLowerCase().contains(query) ||
            product.description.toLowerCase().contains(query);
      }).toList();
    }

    // Apply sorting
    if (_sortColumnIndex != null) {
      filtered.sort((a, b) {
        int comparison = 0;
        switch (_sortColumnIndex) {
          case 0: // Name
            comparison = a.name.compareTo(b.name);
            break;
          case 1: // Category
            comparison = a.categoriesDisplay.compareTo(b.categoriesDisplay);
            break;
          case 2: // Price
            comparison = a.posEffectivePrice.compareTo(b.posEffectivePrice);
            break;
          case 3: // Stock
            comparison = a.stockQuantity.compareTo(b.stockQuantity);
            break;
        }
        return _sortAscending ? comparison : -comparison;
      });
    }

    setState(() {
      _filteredProducts = filtered;
      _currentPage = 1;
      _updatePagination();
    });
  }

  void _updatePagination() {
    final startIndex = (_currentPage - 1) * _rowsPerPage;
    final endIndex = startIndex + _rowsPerPage;
    setState(() {
      _paginatedProducts = _filteredProducts.length > startIndex
          ? _filteredProducts.sublist(
              startIndex,
              endIndex > _filteredProducts.length
                  ? _filteredProducts.length
                  : endIndex,
            )
          : [];
    });
  }

  void _handleStatusFilter(String status) {
    setState(() {
      _selectedStatus = status;
      _applyFilters();
    });
  }

  void _handleSearch(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _handleDateRange(DateTimeRange? range) {
    setState(() {
      _dateRange = range;
      _applyFilters();
    });
  }

  void _handleSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _applyFilters();
    });
  }

  void _handlePageChange(int page) {
    setState(() {
      _currentPage = page;
      _updatePagination();
    });
  }

  void _handleRowsPerPageChange(int rows) {
    setState(() {
      _rowsPerPage = rows;
      _currentPage = 1;
      _updatePagination();
    });
  }

  void _handleSelectAll(bool? value) {
    setState(() {
      _selectAll = value ?? false;
      if (_selectAll) {
        _selectedProductIds = _paginatedProducts.map((p) => p.id).toSet();
      } else {
        _selectedProductIds.clear();
      }
    });
  }

  void _handleSelectProduct(String productId, bool? value) {
    setState(() {
      if (value ?? false) {
        _selectedProductIds.add(productId);
      } else {
        _selectedProductIds.remove(productId);
      }
      _selectAll = _selectedProductIds.length == _paginatedProducts.length;
    });
  }

  Future<void> _handlePosToggle(Product product, bool value) async {
    // Add to updating set and disable switch
    setState(() {
      _updatingProductIds.add(product.id);
    });

    // Optimistically update the UI first
    final previousValue = product.showOnPos;
    _updateProductLocally(product, showOnPos: value);

    try {
      // Make API call to update showOnPos
      await _productsService.updateProduct(
        productId: product.id,
        showOnPos: value,
      );
      // API succeeded - force refresh to sync with server
      if (mounted) {
        await _dataProvider.loadProducts(forceRefresh: true);
      }
    } catch (e) {
      debugPrint('Error updating showOnPos: $e');
      // Revert on failure
      if (mounted) {
        _updateProductLocally(product, showOnPos: previousValue);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Unable to connect!')));
      }
    } finally {
      // Remove from updating set and re-enable switch
      if (mounted) {
        setState(() {
          _updatingProductIds.remove(product.id);
        });
      }
    }
  }

  Future<void> _handleWebToggle(Product product, bool value) async {
    // Add to updating set and disable switch
    setState(() {
      _updatingProductIds.add(product.id);
    });

    // Optimistically update the UI first
    final previousValue = product.showOnWeb;
    _updateProductLocally(product, showOnWeb: value);

    try {
      // Make API call to update showOnWeb
      await _productsService.updateProduct(
        productId: product.id,
        showOnWeb: value,
      );
      // API succeeded - force refresh to sync with server
      if (mounted) {
        await _dataProvider.loadProducts(forceRefresh: true);
      }
    } catch (e) {
      debugPrint('Error updating showOnWeb: $e');
      // Revert on failure
      if (mounted) {
        _updateProductLocally(product, showOnWeb: previousValue);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Unable to connect!')));
      }
    } finally {
      // Remove from updating set and re-enable switch
      if (mounted) {
        setState(() {
          _updatingProductIds.remove(product.id);
        });
      }
    }
  }

  void _updateProductLocally(
    Product product, {
    bool? showOnPos,
    bool? showOnWeb,
  }) {
    setState(() {
      final index = _allProducts.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        final updatedProduct = product.copyWith(
          showOnPos: showOnPos ?? product.showOnPos,
          showOnWeb: showOnWeb ?? product.showOnWeb,
        );
        _allProducts[index] = updatedProduct;
        _applyFilters();
      }
    });
  }

  Map<String, int> _getStatusCounts() {
    final counts = <String, int>{
      'all': _allProducts.length,
      'active': 0,
      'inactive': 0,
      'lowstock': 0,
    };

    for (final product in _allProducts) {
      // Active = status == 'active' && isAvailable && showOnPos && showOnWeb
      final isFullyActive =
          product.status == 'active' &&
          product.isAvailable &&
          product.showOnPos &&
          product.showOnWeb;
      if (isFullyActive) {
        counts['active'] = (counts['active'] ?? 0) + 1;
      } else {
        counts['inactive'] = (counts['inactive'] ?? 0) + 1;
      }
      if (product.trackInventory &&
          product.stockQuantity <= product.lowStockThreshold) {
        counts['lowstock'] = (counts['lowstock'] ?? 0) + 1;
      }
    }

    return counts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            const HeaderWidget(),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            spacing: 8,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                spacing: 4,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'All Products',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '(${_allProducts.length})',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    spacing: 8,
                                    children: [
                                      // Reload Button
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          _loadProducts(forceRefresh: true);
                                        },
                                        icon: const Icon(Icons.sync, size: 16),
                                        label: const Text(
                                          'Reload',
                                          style: TextStyle(fontSize: 14),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(0, 46),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                        ),
                                      ),
                                      FilledButton.icon(
                                        onPressed: () {
                                          // TODO: Add new product
                                        },
                                        icon: const Icon(Icons.add, size: 16),
                                        label: const Text(
                                          'New Product',
                                          style: TextStyle(fontSize: 14),
                                        ),
                                        style: FilledButton.styleFrom(
                                          minimumSize: const Size(0, 46),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      // Filters
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 8,
                                          right: 8,
                                          top: 8,
                                        ),
                                        child: ProductsFilters(
                                          selectedStatus: _selectedStatus,
                                          statusCounts: _getStatusCounts(),
                                          searchQuery: _searchQuery,
                                          dateRange: _dateRange,
                                          onStatusChanged: _handleStatusFilter,
                                          onSearchChanged: _handleSearch,
                                          onDateRangeChanged: _handleDateRange,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      // DataTable
                                      Expanded(child: _buildDataTable()),
                                      const SizedBox(height: 8),
                                      // Pagination
                                      OrdersPagination(
                                        currentPage: _currentPage,
                                        totalPages:
                                            (_filteredProducts.length /
                                                    _rowsPerPage)
                                                .ceil(),
                                        rowsPerPage: _rowsPerPage,
                                        rowsPerPageOptions: _rowsPerPageOptions,
                                        totalItems: _filteredProducts.length,
                                        onPageChanged: _handlePageChange,
                                        onRowsPerPageChanged:
                                            _handleRowsPerPageChange,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                  headingRowHeight: 40,
                  dataRowMinHeight: 44,
                  dataRowMaxHeight: 48,
                  horizontalMargin: 12,
                  columnSpacing: 16,
                  sortColumnIndex: _sortColumnIndex,
                  sortAscending: _sortAscending,
                  headingTextStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  dataTextStyle: const TextStyle(fontSize: 13),
                  onSelectAll: (value) {
                    _handleSelectAll(value);
                  },
                  columns: [
                    DataColumn(
                      label: const Text('Name', style: TextStyle(fontSize: 12)),
                      onSort: _handleSort,
                    ),
                    DataColumn(
                      label: const Text(
                        'Category',
                        style: TextStyle(fontSize: 12),
                      ),
                      onSort: _handleSort,
                    ),
                    DataColumn(
                      label: const Text(
                        'Price',
                        style: TextStyle(fontSize: 12),
                      ),
                      numeric: true,
                      onSort: _handleSort,
                    ),
                    DataColumn(
                      label: const Text(
                        'Stock',
                        style: TextStyle(fontSize: 12),
                      ),
                      numeric: true,
                      onSort: _handleSort,
                    ),
                    DataColumn(
                      label: const Text('POS', style: TextStyle(fontSize: 12)),
                    ),
                    DataColumn(
                      label: const Text('WEB', style: TextStyle(fontSize: 12)),
                    ),
                    DataColumn(
                      headingRowAlignment: MainAxisAlignment.end,
                      label: const Text(
                        'Quick View',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                  rows: _paginatedProducts.map((product) {
                    final isSelected = _selectedProductIds.contains(product.id);
                    return DataRow(
                      selected: isSelected,
                      onSelectChanged: (selected) {
                        _handleSelectProduct(product.id, selected);
                      },
                      cells: [
                        DataCell(
                          Text(
                            product.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DataCell(
                          Text(
                            product.categoriesDisplay,
                            style: const TextStyle(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DataCell(
                          Text(
                            '\$${product.posEffectivePrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        DataCell(_buildStockCell(product)),
                        DataCell(
                          Switch(
                            value: product.showOnPos,
                            onChanged: _updatingProductIds.contains(product.id)
                                ? null
                                : (value) => _handlePosToggle(product, value),
                          ),
                        ),
                        DataCell(
                          Switch(
                            value: product.showOnWeb,
                            onChanged: _updatingProductIds.contains(product.id)
                                ? null
                                : (value) => _handleWebToggle(product, value),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: double.infinity,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton.outlined(
                                  icon: const Icon(Icons.visibility, size: 16),
                                  onPressed: () {
                                    // TODO: View product details
                                  },
                                  tooltip: 'Quick View',
                                  style: IconButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(40, 40),
                                    maximumSize: const Size(40, 40),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStockCell(Product product) {
    if (!product.trackInventory) {
      return Text(
        'N/A',
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade400,
          fontWeight: FontWeight.w400,
        ),
        textAlign: TextAlign.right,
      );
    }

    final isLowStock = product.stockQuantity <= product.lowStockThreshold;
    final isOutOfStock = product.stockQuantity == 0;

    if (isOutOfStock) {
      final color = Colors.red.shade800;
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inventory_2, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  'Out of Stock',
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else if (isLowStock) {
      final color = Colors.orange.shade800;
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  '${product.stockQuantity}',
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Text(
      '${product.stockQuantity}',
      style: TextStyle(
        fontSize: 13,
        color: Colors.black87,
        fontWeight: FontWeight.w500,
      ),
      textAlign: TextAlign.right,
    );
  }
}
