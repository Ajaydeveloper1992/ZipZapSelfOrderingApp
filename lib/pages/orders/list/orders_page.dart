import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zipzap_pos_self_orders/widgets/header/widget.dart';
import 'package:zipzap_pos_self_orders/widgets/app_drawer.dart';
import 'package:zipzap_pos_self_orders/models/order_model.dart' as order_model;
import 'package:zipzap_pos_self_orders/pages/orders/list/widgets/orders_filters.dart';
import 'package:zipzap_pos_self_orders/pages/orders/list/widgets/orders_pagination.dart';
import 'package:zipzap_pos_self_orders/pages/takeouts/widgets/order_details_drawer.dart';
import 'package:zipzap_pos_self_orders/services/orders_service.dart';
import 'package:zipzap_pos_self_orders/core/services/auth_service.dart';
import 'package:zipzap_pos_self_orders/providers/data_provider.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final OrdersService _ordersService = OrdersService();
  final AuthService _authService = AuthService();

  List<order_model.Order> _orders = [];
  Set<String> _selectedOrderIds = {};
  bool _selectAll = false;
  order_model.Order? _selectedOrder;

  // Loading and error state
  bool _isLoading = false;
  String? _errorMessage;
  String? _loadingAction; // Track which action is loading

  // Stats from API
  Map<String, int> _statusCounts = {};

  // Filter state
  String _selectedStatus = 'all';
  String _searchQuery = '';
  DateTimeRange? _dateRange;

  // Sort state
  int? _sortColumnIndex;
  bool _sortAscending = false; // Default to descending (newest first)
  final String _sortBy = 'updatedAt';

  // Pagination state
  int _currentPage = 1;
  int _rowsPerPage = 10;
  final List<int> _rowsPerPageOptions = [10, 25, 50, 100];
  int _totalItems = 0;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get store ID from DataProvider (source of truth)
      final dataProvider = DataProvider();
      final storeId =
          dataProvider.store?.id ?? _authService.getProfile()?.storeId;

      // Map sort column index to API sortBy field
      String? sortBy;
      if (_sortColumnIndex != null) {
        switch (_sortColumnIndex) {
          case 0: // Order Number
            sortBy = 'orderNumber';
            break;
          case 1: // Amount
            sortBy = 'total';
            break;
          case 2: // Customer
            sortBy = 'customer';
            break;
          case 3: // Order Type
            sortBy = 'orderType';
            break;
          case 4: // Order Time
            sortBy = 'createdAt';
            break;
          case 5: // Updated Time
            sortBy = 'updatedAt';
            break;
          case 6: // Order Status
            sortBy = 'orderstatus';
            break;
          case 7: // Payment Status
            sortBy = 'paymentStatus';
            break;
          case 8: // Payment Method
            sortBy = 'payments.method';
            break;
          default:
            sortBy = 'createdAt';
        }
      } else {
        sortBy = _sortBy;
      }

      // Map status filter
      String? orderstatus;
      if (_selectedStatus != 'all') {
        orderstatus = _selectedStatus;
      }

      // Format date range (use Canadian timezone - America/Toronto)
      DateTime? dateFrom;
      DateTime? dateTo;
      if (_dateRange != null) {
        // Convert to Canadian Eastern Time
        final toronto = DateTime(
          _dateRange!.start.year,
          _dateRange!.start.month,
          _dateRange!.start.day,
        );
        final torontoEnd = DateTime(
          _dateRange!.end.year,
          _dateRange!.end.month,
          _dateRange!.end.day,
          23,
          59,
          59,
        );

        dateFrom = toronto;
        dateTo = torontoEnd;
      }

      final response = await _ordersService.getAllOrders(
        sortBy: sortBy,
        sortOrder: _sortAscending ? 'asc' : 'desc',
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        orderstatus: orderstatus,
        store: storeId,
        dateFrom: dateFrom,
        dateTo: dateTo,
        page: _currentPage,
        limit: _rowsPerPage,
      );

      final convertedOrders = response.orders;

      // Extract stats from response
      final stats = response.stats;
      final statusCounts = <String, int>{
        'all': stats?.all ?? 0,
        'pending': stats?.pending ?? 0,
        'complete': stats?.complete ?? 0,
        'inkitchen': stats?.inKitchen ?? 0,
        'rejected': stats?.rejected ?? 0,
        'voided': stats?.voided ?? 0,
      };

      setState(() {
        _orders = convertedOrders;
        _totalItems = response.pagination?.totalItems ?? 0;
        _totalPages = response.pagination?.totalPages ?? 1;
        _statusCounts = statusCounts;
        _isLoading = false;
        _loadingAction = null; // Clear loading action
        _errorMessage = null;
        _selectAll = false;
        _selectedOrderIds.clear();
      });
    } catch (e) {
      debugPrint('Error loading orders: $e');
      setState(() {
        _isLoading = false;
        _loadingAction = null; // Clear loading action on error
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _orders = [];
        _totalItems = 0;
        _totalPages = 1;
        _statusCounts = {};
      });
    }
  }

  void _handleStatusFilter(String status) {
    setState(() {
      _selectedStatus = status;
      _currentPage = 1; // Reset to first page
    });
    _loadOrders();
  }

  void _handleSearch(String query) {
    setState(() {
      _searchQuery = query;
      _currentPage = 1; // Reset to first page
    });
    _loadOrders();
  }

  void _handleDateRange(DateTimeRange? range) {
    setState(() {
      _dateRange = range;
      _currentPage = 1; // Reset to first page
    });
    _loadOrders();
  }

  void _handleSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _currentPage = 1; // Reset to first page
    });
    _loadOrders();
  }

  void _handlePageChange(int page) {
    String? action;
    if (page == 1) {
      action = 'first';
    } else if (page < _currentPage) {
      action = 'prev';
    } else if (page > _currentPage) {
      action = 'next';
    } else if (page == _totalPages) {
      action = 'last';
    }

    setState(() {
      _currentPage = page;
      _loadingAction = action;
    });
    _loadOrders();
  }

  void _handleRowsPerPageChange(int rows) {
    setState(() {
      _rowsPerPage = rows;
      _currentPage = 1; // Reset to first page
      _loadingAction = 'rowsPerPage';
    });
    _loadOrders();
  }

  void _handleSelectAll(bool? value) {
    setState(() {
      _selectAll = value ?? false;
      if (_selectAll) {
        _selectedOrderIds = _orders.map((o) => o.id).toSet();
      } else {
        _selectedOrderIds.clear();
      }
    });
  }

  void _handleSelectOrder(String orderId, bool? value) {
    setState(() {
      if (value ?? false) {
        _selectedOrderIds.add(orderId);
      } else {
        _selectedOrderIds.remove(orderId);
      }
      _selectAll =
          _selectedOrderIds.length == _orders.length && _orders.isNotEmpty;
    });
  }

  Map<String, int> _getStatusCounts() {
    // Return stats from API response
    return _statusCounts;
  }

  void _openOrderDetails(order_model.Order order) {
    setState(() {
      _selectedOrder = order;
    });
    _scaffoldKey.currentState?.openEndDrawer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      endDrawer: _selectedOrder != null
          ? OrderDetailsDrawer(order: _selectedOrder!)
          : const Drawer(child: SizedBox.shrink()),
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
                                        'All Orders',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '($_totalItems)',
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
                                        onPressed: _isLoading
                                            ? null
                                            : _loadOrders,
                                        icon: _isLoading
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Icon(Icons.sync, size: 16),
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
                                          Navigator.pushNamed(
                                            context,
                                            '/orders/new',
                                            arguments: {'orderType': 'prepay'},
                                          );
                                        },
                                        icon: const Icon(Icons.add, size: 16),
                                        label: const Text(
                                          'New Order',
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
                                        child: OrdersFilters(
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
                                      Expanded(
                                        child: _isLoading && _orders.isEmpty
                                            ? const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              )
                                            : _errorMessage != null &&
                                                  _orders.isEmpty
                                            ? Center(
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.error_outline,
                                                      size: 64,
                                                      color:
                                                          Colors.red.shade300,
                                                    ),
                                                    const SizedBox(height: 16),
                                                    Text(
                                                      _errorMessage!,
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        color: Colors
                                                            .grey
                                                            .shade600,
                                                      ),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                    const SizedBox(height: 16),
                                                    ElevatedButton.icon(
                                                      onPressed: _loadOrders,
                                                      icon: const Icon(
                                                        Icons.refresh,
                                                      ),
                                                      label: const Text(
                                                        'Retry',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            : _buildDataTable(),
                                      ),
                                      const SizedBox(height: 8),
                                      // Pagination
                                      OrdersPagination(
                                        currentPage: _currentPage,
                                        totalPages: _totalPages,
                                        rowsPerPage: _rowsPerPage,
                                        rowsPerPageOptions: _rowsPerPageOptions,
                                        totalItems: _totalItems,
                                        onPageChanged: _handlePageChange,
                                        onRowsPerPageChanged:
                                            _handleRowsPerPageChange,
                                        isLoading: _isLoading,
                                        loadingAction: _loadingAction,
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
                      label: const Text(
                        'Order #',
                        style: TextStyle(fontSize: 12),
                      ),
                      onSort: _handleSort,
                    ),
                    DataColumn(
                      label: const Text(
                        'Amount',
                        style: TextStyle(fontSize: 12),
                      ),
                      numeric: true,
                      onSort: _handleSort,
                    ),
                    DataColumn(
                      label: const Text(
                        'Customer',
                        style: TextStyle(fontSize: 12),
                      ),
                      onSort: _handleSort,
                    ),
                    DataColumn(
                      label: const Text(
                        'Order Type',
                        style: TextStyle(fontSize: 12),
                      ),
                      onSort: _handleSort,
                    ),
                    DataColumn(
                      label: const Text(
                        'Order Time',
                        style: TextStyle(fontSize: 12),
                      ),
                      onSort: _handleSort,
                    ),
                    DataColumn(
                      label: const Text(
                        'Updated Time',
                        style: TextStyle(fontSize: 12),
                      ),
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
                        'Payment',
                        style: TextStyle(fontSize: 12),
                      ),
                      onSort: _handleSort,
                    ),
                    DataColumn(
                      label: const Text(
                        'Method',
                        style: TextStyle(fontSize: 12),
                      ),
                      onSort: _handleSort,
                    ),
                    const DataColumn(
                      label: Text(
                        'Void/Refund',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    DataColumn(
                      headingRowAlignment: MainAxisAlignment.end,
                      label: Text('Quick View', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                  rows: _orders.map((order) {
                    final isSelected = _selectedOrderIds.contains(order.id);
                    return DataRow(
                      selected: isSelected,
                      onSelectChanged: (selected) {
                        _handleSelectOrder(order.id, selected);
                      },
                      cells: [
                        DataCell(
                          Text(
                            order.orderNumber,
                            style: const TextStyle(fontSize: 13),
                          ),
                          onTap: () {
                            Navigator.of(
                              context,
                            ).pushNamed('/orders/${order.id}/details');
                          },
                        ),
                        DataCell(
                          Text(
                            '\$${order.displayTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onTap: () {
                            Navigator.of(
                              context,
                            ).pushNamed('/orders/${order.id}/details');
                          },
                        ),
                        DataCell(
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                order.customerName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                order.customerPhone,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          onTap: () {
                            Navigator.of(
                              context,
                            ).pushNamed('/orders/${order.id}/details');
                          },
                        ),
                        DataCell(
                          _buildOrderTypeChip(order.orderType),
                          onTap: () {
                            Navigator.of(
                              context,
                            ).pushNamed('/orders/${order.id}/details');
                          },
                        ),
                        DataCell(
                          Text(
                            order.createdAt != null
                                ? DateFormat(
                                    'MMM dd, yyyy\nhh:mm a',
                                  ).format(order.createdAt!)
                                : 'N/A',
                            style: const TextStyle(fontSize: 11),
                          ),
                          onTap: () {
                            Navigator.of(
                              context,
                            ).pushNamed('/orders/${order.id}/details');
                          },
                        ),
                        DataCell(
                          Text(
                            order.updatedAt != null
                                ? DateFormat(
                                    'MMM dd, yyyy\nhh:mm a',
                                  ).format(order.updatedAt!)
                                : 'N/A',
                            style: const TextStyle(fontSize: 11),
                          ),
                          onTap: () {
                            Navigator.of(
                              context,
                            ).pushNamed('/orders/${order.id}/details');
                          },
                        ),
                        DataCell(
                          _buildStatusChip(order.orderstatus),
                          onTap: () {
                            Navigator.of(
                              context,
                            ).pushNamed('/orders/${order.id}/details');
                          },
                        ),
                        DataCell(
                          _buildPaymentStatusChip(order.displayPaymentStatus),
                          onTap: () {
                            Navigator.of(
                              context,
                            ).pushNamed('/orders/${order.id}/details');
                          },
                        ),
                        DataCell(
                          Text(
                            order.paymentMethod,
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            Navigator.of(
                              context,
                            ).pushNamed('/orders/${order.id}/details');
                          },
                        ),
                        DataCell(
                          _buildVoidRefundCell(order),
                          onTap: () {
                            Navigator.of(
                              context,
                            ).pushNamed('/orders/${order.id}/details');
                          },
                        ),
                        DataCell(
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton.outlined(
                                icon: const Icon(Icons.visibility, size: 16),
                                onPressed: () {
                                  _openOrderDetails(order);
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

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'complete':
        return Icons.check_circle;
      case 'pending':
        return Icons.schedule;
      case 'inkitchen':
        return Icons.restaurant;
      case 'rejected':
        return Icons.cancel;
      case 'refunded':
        return Icons.money_off;
      case 'voided':
        return Icons.block;
      default:
        return Icons.help_outline;
    }
  }

  Widget _buildOrderTypeChip(String orderType) {
    Color color;
    IconData icon;
    switch (orderType.toLowerCase()) {
      case 'pickup':
        color = Colors.teal.shade800;
        icon = Icons.shopping_bag_outlined;
        break;
      case 'delivery':
        color = Colors.indigo.shade800;
        icon = Icons.delivery_dining;
        break;
      case 'dine-in':
        color = Colors.purple.shade800;
        icon = Icons.restaurant_menu;
        break;
      default:
        color = Colors.grey.shade800;
        icon = Icons.receipt_long;
    }

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
            orderType,
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

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'complete':
        color = Colors.green.shade800;
        break;
      case 'pending':
        color = Colors.orange.shade800;
        break;
      case 'inkitchen':
        color = Colors.blue.shade800;
        break;
      case 'rejected':
        color = Colors.red.shade800;
        break;
      case 'refunded':
        color = Colors.red.shade800;
        break;
      case 'voided':
        color = Colors.grey.shade800;
        break;
      default:
        color = Colors.grey.shade800;
    }

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
          Icon(_getStatusIcon(status), size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            status,
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

  IconData _getPaymentStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return Icons.check_circle;
      case 'pending':
        return Icons.schedule;
      case 'unpaid':
        return Icons.money_off;
      case 'refunded':
        return Icons.money_off;
      default:
        return Icons.help_outline;
    }
  }

  Widget _buildPaymentStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'paid':
        color = Colors.green.shade800;
        break;
      case 'pending':
        color = Colors.orange.shade800;
        break;
      case 'unpaid':
        color = Colors.red.shade800;
        break;
      case 'refunded':
        color = Colors.red.shade800;
        break;
      default:
        color = Colors.grey.shade800;
    }

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
          Icon(_getPaymentStatusIcon(status), size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            status,
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

  Widget _buildVoidRefundCell(order_model.Order order) {
    final voidedCount = order.voidedItemCount;
    final refundedCount = order.refundedItemCount;

    if (voidedCount > 0) {
      final color = Colors.red.shade800;
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
            Icon(Icons.block, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              'Voided: $voidedCount',
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    } else if (refundedCount > 0) {
      final color = Colors.blue.shade800;
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
            Icon(Icons.money_off, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              'Refunded: $refundedCount',
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    } else {
      return Text(
        '-',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade400,
          fontWeight: FontWeight.w400,
        ),
      );
    }
  }
}
