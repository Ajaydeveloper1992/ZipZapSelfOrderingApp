import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zipzap_pos_self_orders/widgets/header/widget.dart';
import 'package:zipzap_pos_self_orders/widgets/app_drawer.dart';
import 'package:zipzap_pos_self_orders/models/customer_model.dart';
import 'package:zipzap_pos_self_orders/pages/customers/list/widgets/customers_filters.dart';
import 'package:zipzap_pos_self_orders/pages/customers/list/widgets/customer_details_drawer.dart';
import 'package:zipzap_pos_self_orders/pages/orders/list/widgets/orders_pagination.dart';
import 'package:zipzap_pos_self_orders/providers/data_provider.dart';

class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final DataProvider _dataProvider = DataProvider();
  List<Customer> _allCustomers = [];
  List<Customer> _filteredCustomers = [];
  List<Customer> _paginatedCustomers = [];
  Set<String> _selectedCustomerIds = {};
  bool _selectAll = false;

  // Filter state
  String _selectedType = 'all';
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
    _loadCustomers();
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
    // Update customers when DataProvider notifies
    if (mounted) {
      _updateCustomersFromProvider();
    }
  }

  void _updateCustomersFromProvider() {
    setState(() {
      _allCustomers = _dataProvider.customersList
          .toList()
          .reversed
          .toList(); // Most recent first
      _applyFilters();
    });
  }

  Future<void> _loadCustomers({bool forceRefresh = false}) async {
    try {
      if (forceRefresh) {
        await _dataProvider.loadCustomers(forceRefresh: true);
      }

      // Update from provider
      _updateCustomersFromProvider();
    } catch (e) {
      debugPrint('Error loading customers: $e');
    }
  }

  void _applyFilters() {
    List<Customer> filtered = List.from(_allCustomers);

    // Type filter
    if (_selectedType != 'all') {
      filtered = filtered.where((customer) {
        if (_selectedType == 'returning') {
          return customer.isReturning;
        } else if (_selectedType == 'new') {
          return !customer.isReturning;
        }
        return true;
      }).toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((customer) {
        return customer.fullName.toLowerCase().contains(query) ||
            (customer.phone?.toLowerCase().contains(query) ?? false) ||
            (customer.email?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // Date range filter
    if (_dateRange != null) {
      filtered = filtered.where((customer) {
        if (customer.createdAt == null) return false;
        final customerDate = DateTime(
          customer.createdAt!.year,
          customer.createdAt!.month,
          customer.createdAt!.day,
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
        return customerDate.isAfter(
              startDate.subtract(const Duration(days: 1)),
            ) &&
            customerDate.isBefore(endDate.add(const Duration(days: 1)));
      }).toList();
    }

    // Apply sorting
    if (_sortColumnIndex != null) {
      filtered.sort((a, b) {
        int comparison = 0;
        switch (_sortColumnIndex) {
          case 0: // Name
            comparison = a.fullName.compareTo(b.fullName);
            break;
          case 1: // Phone
            comparison = (a.phone ?? '').compareTo(b.phone ?? '');
            break;
          case 2: // Email
            comparison = (a.email ?? '').compareTo(b.email ?? '');
            break;
          case 3: // Orders
            comparison = a.ordersCount.compareTo(b.ordersCount);
            break;
          case 4: // Total Spent
            comparison = a.totalSpent.compareTo(b.totalSpent);
            break;
          case 5: // Status
            comparison = a.isReturning.toString().compareTo(
              b.isReturning.toString(),
            );
            break;
          case 6: // Created Date
            comparison = (a.createdAt ?? DateTime.now()).compareTo(
              b.createdAt ?? DateTime.now(),
            );
            break;
        }
        return _sortAscending ? comparison : -comparison;
      });
    }

    setState(() {
      _filteredCustomers = filtered;
      _currentPage = 1;
      _updatePagination();
    });
  }

  void _updatePagination() {
    final startIndex = (_currentPage - 1) * _rowsPerPage;
    final endIndex = startIndex + _rowsPerPage;
    setState(() {
      _paginatedCustomers = _filteredCustomers.length > startIndex
          ? _filteredCustomers.sublist(
              startIndex,
              endIndex > _filteredCustomers.length
                  ? _filteredCustomers.length
                  : endIndex,
            )
          : [];
    });
  }

  void _handleTypeFilter(String type) {
    setState(() {
      _selectedType = type;
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
        _selectedCustomerIds = _paginatedCustomers.map((c) => c.id).toSet();
      } else {
        _selectedCustomerIds.clear();
      }
    });
  }

  void _handleSelectCustomer(String customerId, bool? value) {
    setState(() {
      if (value ?? false) {
        _selectedCustomerIds.add(customerId);
      } else {
        _selectedCustomerIds.remove(customerId);
      }
      _selectAll = _selectedCustomerIds.length == _paginatedCustomers.length;
    });
  }

  Map<String, int> _getTypeCounts() {
    final counts = <String, int>{
      'all': _allCustomers.length,
      'returning': 0,
      'new': 0,
    };

    for (final customer in _allCustomers) {
      if (customer.isReturning) {
        counts['returning'] = (counts['returning'] ?? 0) + 1;
      } else {
        counts['new'] = (counts['new'] ?? 0) + 1;
      }
    }

    return counts;
  }

  void _showCustomerDetails(Customer customer) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Customer Details',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: CustomerDetailsDrawer(
            customer: customer,
            onEdit: () {
              // TODO: Handle edit customer
            },
            onDelete: () {
              // TODO: Handle delete customer
            },
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        );
      },
    );
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
                                        'All Customers',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '(${_allCustomers.length})',
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
                                          _loadCustomers(forceRefresh: true);
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
                                          // TODO: Add new customer
                                        },
                                        icon: const Icon(Icons.add, size: 16),
                                        label: const Text(
                                          'New Customer',
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
                                        child: CustomersFilters(
                                          selectedType: _selectedType,
                                          typeCounts: _getTypeCounts(),
                                          searchQuery: _searchQuery,
                                          dateRange: _dateRange,
                                          onTypeChanged: _handleTypeFilter,
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
                                            (_filteredCustomers.length /
                                                    _rowsPerPage)
                                                .ceil(),
                                        rowsPerPage: _rowsPerPage,
                                        rowsPerPageOptions: _rowsPerPageOptions,
                                        totalItems: _filteredCustomers.length,
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
                        'Phone',
                        style: TextStyle(fontSize: 12),
                      ),
                      onSort: _handleSort,
                    ),
                    DataColumn(
                      label: const Text(
                        'Email',
                        style: TextStyle(fontSize: 12),
                      ),
                      onSort: _handleSort,
                    ),
                    DataColumn(
                      label: const Text(
                        'Orders',
                        style: TextStyle(fontSize: 12),
                      ),
                      numeric: true,
                      onSort: _handleSort,
                    ),
                    DataColumn(
                      label: const Text(
                        'Total Spent',
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
                  rows: _paginatedCustomers.map((customer) {
                    final isSelected = _selectedCustomerIds.contains(
                      customer.id,
                    );
                    return DataRow(
                      selected: isSelected,
                      onSelectChanged: (selected) {
                        _handleSelectCustomer(customer.id, selected);
                      },
                      cells: [
                        DataCell(
                          Text(
                            customer.fullName,
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
                            customer.phone ?? 'N/A',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        DataCell(
                          Text(
                            (customer.email?.isEmpty ?? true)
                                ? 'N/A'
                                : customer.email!,
                            style: TextStyle(
                              fontSize: 13,
                              color: (customer.email?.isEmpty ?? true)
                                  ? Colors.grey.shade600
                                  : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DataCell(
                          Text(
                            '${customer.ordersCount}',
                            style: const TextStyle(fontSize: 13),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        DataCell(
                          Text(
                            '\$${customer.totalSpent.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        DataCell(_buildStatusChip(customer.isReturning)),
                        DataCell(
                          Text(
                            customer.createdAt != null
                                ? DateFormat(
                                    'MMM dd, yyyy',
                                  ).format(customer.createdAt!)
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
                                    _showCustomerDetails(customer);
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

  Widget _buildStatusChip(bool isReturning) {
    final color = isReturning ? Colors.green.shade800 : Colors.orange.shade800;
    final icon = isReturning ? Icons.repeat : Icons.person_add;
    final text = isReturning ? 'Returning' : 'New';

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
