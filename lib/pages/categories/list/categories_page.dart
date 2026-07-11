import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zipzap_pos_self_orders/widgets/header/widget.dart';
import 'package:zipzap_pos_self_orders/widgets/app_drawer.dart';
import 'package:zipzap_pos_self_orders/models/category_model.dart';
import 'package:zipzap_pos_self_orders/pages/categories/list/widgets/categories_filters.dart';
import 'package:zipzap_pos_self_orders/pages/orders/list/widgets/orders_pagination.dart';
import 'package:zipzap_pos_self_orders/providers/data_provider.dart';
import 'package:zipzap_pos_self_orders/services/categories_service.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final DataProvider _dataProvider = DataProvider();
  final CategoriesService _categoriesService = CategoriesService();
  List<Category> _allCategories = [];
  List<Category> _filteredCategories = [];
  List<Category> _paginatedCategories = [];
  Set<String> _selectedCategoryIds = {};
  bool _selectAll = false;
  Set<String> _updatingCategoryIds = {};

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
    _loadCategories();
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
    // Update categories when DataProvider notifies
    if (mounted) {
      _updateCategoriesFromProvider();
    }
  }

  void _updateCategoriesFromProvider() {
    setState(() {
      _allCategories = _dataProvider.categoriesList.toList().toList();
      _applyFilters();
    });
  }

  Future<void> _loadCategories({bool forceRefresh = false}) async {
    try {
      // If forcing refresh, trigger DataProvider to refetch
      if (forceRefresh) {
        await _dataProvider.loadCategories(forceRefresh: true);
      }

      // Update from provider
      _updateCategoriesFromProvider();
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  void _applyFilters() {
    List<Category> filtered = List.from(_allCategories);

    // Status filter
    // Active = isActive && showOnPos && showOnWeb
    // Inactive = !isActive || !showOnPos || !showOnWeb
    if (_selectedStatus != 'all') {
      filtered = filtered.where((category) {
        final isFullyActive =
            category.isActive &&
            category.showOnPos &&
            (category.showOnWeb ?? false);
        if (_selectedStatus == 'active') {
          return isFullyActive;
        } else if (_selectedStatus == 'inactive') {
          return !isFullyActive;
        }
        return true;
      }).toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((category) {
        return category.name.toLowerCase().contains(query) ||
            (category.description?.toLowerCase().contains(query) ?? false) ||
            category.slug.toLowerCase().contains(query);
      }).toList();
    }

    // Date range filter
    if (_dateRange != null) {
      filtered = filtered.where((category) {
        if (category.createdAt == null) return false;
        final categoryDate = DateTime(
          category.createdAt!.year,
          category.createdAt!.month,
          category.createdAt!.day,
        );
        final startDate = DateTime(
          _dateRange!.start.year,
          _dateRange!.start.month,
          _dateRange!.start.day,
        );
        final endDate = DateTime(
          _dateRange!.end.year,
          _dateRange!.end.month,
          _dateRange!.end.day,
        );
        return categoryDate.isAfter(
              startDate.subtract(const Duration(days: 1)),
            ) &&
            categoryDate.isBefore(endDate.add(const Duration(days: 1)));
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
          case 1: // Slug
            comparison = a.slug.compareTo(b.slug);
            break;
          case 2: // Products
            comparison = a.productsCount.compareTo(b.productsCount);
            break;
          case 3: // Sort Order
            comparison = a.sortOrder.compareTo(b.sortOrder);
            break;
          case 4: // Status
            comparison = a.isActive.toString().compareTo(b.isActive.toString());
            break;
          case 7: // Created Date
            comparison = (a.createdAt ?? DateTime.now()).compareTo(
              b.createdAt ?? DateTime.now(),
            );
            break;
        }
        return _sortAscending ? comparison : -comparison;
      });
    }

    setState(() {
      _filteredCategories = filtered;
      _currentPage = 1;
      _updatePagination();
    });
  }

  void _updatePagination() {
    final startIndex = (_currentPage - 1) * _rowsPerPage;
    final endIndex = startIndex + _rowsPerPage;
    setState(() {
      _paginatedCategories = _filteredCategories.length > startIndex
          ? _filteredCategories.sublist(
              startIndex,
              endIndex > _filteredCategories.length
                  ? _filteredCategories.length
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
        _selectedCategoryIds = _paginatedCategories.map((c) => c.id).toSet();
      } else {
        _selectedCategoryIds.clear();
      }
    });
  }

  void _handleSelectCategory(String categoryId, bool? value) {
    setState(() {
      if (value ?? false) {
        _selectedCategoryIds.add(categoryId);
      } else {
        _selectedCategoryIds.remove(categoryId);
      }
      _selectAll = _selectedCategoryIds.length == _paginatedCategories.length;
    });
  }

  Future<void> _handlePosToggle(Category category, bool value) async {
    // Add to updating set and disable switch
    setState(() {
      _updatingCategoryIds.add(category.id);
    });

    // Optimistically update the UI first
    final previousValue = category.showOnPos;
    _updateCategoryLocally(category, showOnPos: value);

    try {
      // Make API call to update showOnPos
      await _categoriesService.updateCategory(
        categoryId: category.id,
        showOnPos: value,
      );
      // API succeeded - force refresh to sync with server
      if (mounted) {
        await _dataProvider.loadCategories(forceRefresh: true);
      }
    } catch (e) {
      debugPrint('Error updating showOnPos: $e');
      // Revert on failure
      if (mounted) {
        _updateCategoryLocally(category, showOnPos: previousValue);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Unable to connect!')));
      }
    } finally {
      // Remove from updating set and re-enable switch
      if (mounted) {
        setState(() {
          _updatingCategoryIds.remove(category.id);
        });
      }
    }
  }

  Future<void> _handleWebToggle(Category category, bool value) async {
    // Add to updating set and disable switch
    setState(() {
      _updatingCategoryIds.add(category.id);
    });

    // Optimistically update the UI first
    final previousValue = category.showOnWeb;
    _updateCategoryLocally(category, showOnWeb: value);

    try {
      // Make API call to update showOnWeb
      await _categoriesService.updateCategory(
        categoryId: category.id,
        showOnWeb: value,
      );
      // API succeeded - force refresh to sync with server
      if (mounted) {
        await _dataProvider.loadCategories(forceRefresh: true);
      }
    } catch (e) {
      debugPrint('Error updating showOnWeb: $e');
      // Revert on failure
      if (mounted) {
        _updateCategoryLocally(category, showOnWeb: previousValue);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Unable to connect!')));
      }
    } finally {
      // Remove from updating set and re-enable switch
      if (mounted) {
        setState(() {
          _updatingCategoryIds.remove(category.id);
        });
      }
    }
  }

  void _updateCategoryLocally(
    Category category, {
    bool? showOnPos,
    bool? showOnWeb,
  }) {
    setState(() {
      final index = _allCategories.indexWhere((c) => c.id == category.id);
      if (index != -1) {
        final updatedCategory = Category(
          id: category.id,
          name: category.name,
          slug: category.slug,
          description: category.description,
          isActive: category.isActive,
          showOnPos: showOnPos ?? category.showOnPos,
          showOnWeb: showOnWeb ?? category.showOnWeb,
          store: category.store,
          products: category.products,
          sortOrder: category.sortOrder,
          availability: category.availability,
          createdBy: category.createdBy,
          createdAt: category.createdAt,
          updatedAt: category.updatedAt,
          parent: category.parent,
        );
        _allCategories[index] = updatedCategory;
        _applyFilters();
      }
    });
  }

  Map<String, int> _getStatusCounts() {
    final counts = <String, int>{
      'all': _allCategories.length,
      'active': 0,
      'inactive': 0,
    };

    for (final category in _allCategories) {
      // Active = isActive && showOnPos && showOnWeb
      final isFullyActive =
          category.isActive &&
          category.showOnPos &&
          (category.showOnWeb ?? false);
      if (isFullyActive) {
        counts['active'] = (counts['active'] ?? 0) + 1;
      } else {
        counts['inactive'] = (counts['inactive'] ?? 0) + 1;
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
                                        'All Categories',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '(${_allCategories.length})',
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
                                          _loadCategories(forceRefresh: true);
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
                                          // TODO: Add new category
                                        },
                                        icon: const Icon(Icons.add, size: 16),
                                        label: const Text(
                                          'New Category',
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
                                        child: CategoriesFilters(
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
                                            (_filteredCategories.length /
                                                    _rowsPerPage)
                                                .ceil(),
                                        rowsPerPage: _rowsPerPage,
                                        rowsPerPageOptions: _rowsPerPageOptions,
                                        totalItems: _filteredCategories.length,
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
                      label: const Text('Slug', style: TextStyle(fontSize: 12)),
                      onSort: _handleSort,
                    ),
                    DataColumn(
                      label: const Text(
                        'Products',
                        style: TextStyle(fontSize: 12),
                      ),
                      onSort: _handleSort,
                    ),
                    DataColumn(
                      label: const Text(
                        'Sort Order',
                        style: TextStyle(fontSize: 12),
                      ),
                      numeric: true,
                      onSort: _handleSort,
                    ),
                    DataColumn(
                      label: const Text(
                        'Status',
                        style: TextStyle(fontSize: 12),
                      ),
                      onSort: _handleSort,
                    ),
                    DataColumn(
                      label: const Text('POS', style: TextStyle(fontSize: 12)),
                    ),
                    DataColumn(
                      label: const Text('WEB', style: TextStyle(fontSize: 12)),
                    ),
                    DataColumn(
                      label: const Text(
                        'Created',
                        style: TextStyle(fontSize: 12),
                      ),
                      onSort: _handleSort,
                    ),
                    DataColumn(
                      headingRowAlignment: MainAxisAlignment.end,
                      label: const Text(
                        'Quick View',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                  rows: _paginatedCategories.map((category) {
                    final isSelected = _selectedCategoryIds.contains(
                      category.id,
                    );
                    return DataRow(
                      selected: isSelected,
                      onSelectChanged: (selected) {
                        _handleSelectCategory(category.id, selected);
                      },
                      cells: [
                        DataCell(
                          Text(
                            category.name,
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
                            category.slug,
                            style: const TextStyle(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DataCell(_buildProductsChip(category.productsCount)),
                        DataCell(
                          Text(
                            '${category.sortOrder}',
                            style: const TextStyle(fontSize: 13),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        DataCell(_buildStatusChip(category.isActive)),
                        DataCell(
                          Switch(
                            value: category.showOnPos,
                            onChanged:
                                _updatingCategoryIds.contains(category.id)
                                ? null
                                : (value) => _handlePosToggle(category, value),
                          ),
                        ),
                        DataCell(
                          Switch(
                            value: category.showOnWeb ?? true,
                            onChanged:
                                _updatingCategoryIds.contains(category.id)
                                ? null
                                : (value) => _handleWebToggle(category, value),
                          ),
                        ),
                        DataCell(
                          Text(
                            category.createdAt != null
                                ? DateFormat(
                                    'MMM dd, yyyy',
                                  ).format(category.createdAt!)
                                : 'N/A',
                            style: const TextStyle(fontSize: 11),
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
                                    // TODO: View category details
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

  Widget _buildProductsChip(int count) {
    final color = Colors.blue.shade800;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            TextSpan(
              text: ' Products',
              style: TextStyle(fontSize: 11, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(bool isActive) {
    final color = isActive ? Colors.green.shade800 : Colors.grey.shade800;
    final icon = isActive ? Icons.check_circle : Icons.cancel;
    final text = isActive ? 'Active' : 'Inactive';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
