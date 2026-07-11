import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zipzap_pos_self_orders/models/order_model.dart';
import 'package:zipzap_pos_self_orders/models/modifier_group_model.dart';
import 'package:zipzap_pos_self_orders/widgets/header/widget.dart';
import 'package:zipzap_pos_self_orders/widgets/app_drawer.dart';
import 'package:zipzap_pos_self_orders/pages/orders/details/order_details_breadcrumb.dart';
import 'package:zipzap_pos_self_orders/services/orders_service.dart';
import 'package:zipzap_pos_self_orders/providers/data_provider.dart';

class OrderDetailsPage extends StatefulWidget {
  final String orderId;

  const OrderDetailsPage({super.key, required this.orderId});

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  final OrdersService _ordersService = OrdersService();

  Order? _order;
  bool _isLoading = true;
  String? _errorMessage;
  List<Modifier> _modifiers = [];

  @override
  void initState() {
    super.initState();
    _loadModifiers();
    _loadOrder();
  }

  void _loadModifiers() {
    try {
      final dataProvider = DataProvider();
      setState(() {
        // Get modifiers from DataProvider
        _modifiers = dataProvider.modifiersList
            .where((m) => m.isActive && m.posEnabled)
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading modifiers: $e');
    }
  }

  String _getPickupTime() {
    if (_order == null) return 'N/A';

    // Prioritize delayTime first (updated time) - now DateTime
    if (_order!.pickupInfo?.delayTime != null) {
      return DateFormat('h:mm a').format(_order!.pickupInfo!.delayTime!);
    }
    // Fallback to pickupTime (user selected time) - now DateTime
    if (_order!.pickupInfo?.pickupTime != null) {
      return DateFormat('h:mm a').format(_order!.pickupInfo!.pickupTime!);
    }
    // null pickupTime = ASAP
    return 'ASAP';
  }

  Future<void> _loadOrder({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final order = await _ordersService.getOrderById(
        widget.orderId,
        forceRefresh: forceRefresh,
      );

      // Log order data to console
      debugPrint('========== ORDER DETAILS ==========');
      debugPrint('Order ID: ${order.id}');
      debugPrint('Order Number: ${order.orderNumber}');
      debugPrint('Order Type: ${order.orderType}');
      debugPrint('Order Status: ${order.orderstatus}');
      debugPrint('Origin: ${order.origin}');
      debugPrint('Payment Status: ${order.paymentStatus}');
      debugPrint('Pre-Paid: ${order.prePaid}');
      debugPrint('Date: ${order.date}');
      debugPrint('------- Financial -------');
      debugPrint('Subtotal: \$${order.subtotal.toStringAsFixed(2)}');
      debugPrint('Tax: \$${order.tax.toStringAsFixed(2)}');
      debugPrint('Tip: \$${order.tip.toStringAsFixed(2)}');
      debugPrint('Total: \$${order.total.toStringAsFixed(2)}');
      debugPrint('Total Refund: \$${order.totalRefund.toStringAsFixed(2)}');
      if (order.discount != null) {
        debugPrint('Discount: ${order.discount!.value}${order.discount!.type}');
      }
      debugPrint('------- Customer -------');
      debugPrint('Customer Name: ${order.customerName}');
      debugPrint('Customer Phone: ${order.customerPhone}');
      debugPrint('Customer Email: ${order.customerEmail}');
      debugPrint('------- Store -------');
      debugPrint('Store ID: ${order.store?.id ?? "N/A"}');
      debugPrint('Store Name: ${order.store?.name ?? "N/A"}');
      debugPrint('------- Items (${order.items.length}) -------');
      for (var i = 0; i < order.items.length; i++) {
        final item = order.items[i];
        debugPrint(
          'Item ${i + 1}: ${item.displayName} x${item.quantity} - \$${item.price.toStringAsFixed(2)}',
        );
        if (item.modifiers.isNotEmpty) {
          debugPrint(
            '  Modifiers: ${item.modifiers.map((m) => m.name).join(", ")}',
          );
        }
        if (item.itemNote != null && item.itemNote!.isNotEmpty) {
          debugPrint('  Note: ${item.itemNote}');
        }
        if (item.itemStatus != null) {
          debugPrint('  Status: ${item.itemStatus}');
        }
      }
      debugPrint('------- Payments (${order.payments.length}) -------');
      for (var i = 0; i < order.payments.length; i++) {
        final payment = order.payments[i];
        debugPrint(
          'Payment ${i + 1}: ${payment.method} - \$${payment.amount.toStringAsFixed(2)}',
        );
        if (payment.cardType != null) {
          debugPrint('  Card Type: ${payment.cardType}');
        }
        if (payment.change != null && payment.change! > 0) {
          debugPrint('  Change: \$${payment.change!.toStringAsFixed(2)}');
        }
      }
      if (order.comment != null && order.comment!.isNotEmpty) {
        debugPrint('------- Comment -------');
        debugPrint(order.comment);
      }
      if (order.note != null && order.note!.isNotEmpty) {
        debugPrint('------- Note -------');
        debugPrint(order.note);
      }
      debugPrint('===================================');

      setState(() {
        _order = order;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading order: $e');
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 1024;

    return Scaffold(
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Builder(
              builder: (context) => HeaderWidget(
                logoUrl: 'https://zipzappos.com',
                onDrawerPressed: () {
                  Scaffold.of(context).openDrawer();
                },
                onSearchChanged: (query) {
                  // Handle search
                },
                serverStatus: true,
              ),
            ),
            // Main content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadOrder,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(isSmallScreen ? 8 : 16),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1400),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Breadcrumb with Action Buttons
                            OrderDetailsBreadcrumb(
                              order: _order!,
                              onRefresh: () => _loadOrder(forceRefresh: true),
                              isRefreshing: _isLoading,
                            ),
                            const SizedBox(height: 12),
                            // Header Section
                            _buildHeaderSection(context),
                            const SizedBox(height: 12),
                            // Two Column Layout
                            isSmallScreen
                                ? _buildMobileLayout(context)
                                : _buildDesktopLayout(context),
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

  Widget _buildHeaderSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < 600;
          return isSmallScreen
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOverviewItem(
                      context,
                      'Order Time',
                      DateFormat('MMM dd, yyyy | hh:mm a').format(_order!.date),
                    ),
                    const SizedBox(height: 12),
                    _buildOverviewItem(
                      context,
                      'Order Status',
                      null,
                      status: _order!.orderstatus,
                    ),
                    const SizedBox(height: 12),
                    _buildOverviewItem(
                      context,
                      'Pickup Time',
                      _getPickupTime(),
                      isDestructive: _getPickupTime() == 'N/A',
                    ),
                    const SizedBox(height: 12),
                    _buildOverviewItem(
                      context,
                      'Total',
                      '\$${_order!.total.toStringAsFixed(2)}',
                      isTotal: true,
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOverviewItem(
                      context,
                      'Order Time',
                      DateFormat('MMM dd, yyyy | hh:mm a').format(_order!.date),
                    ),
                    _buildOverviewItem(
                      context,
                      'Order Status',
                      null,
                      status: _order!.orderstatus,
                    ),
                    _buildOverviewItem(
                      context,
                      'Pickup Time',
                      _getPickupTime(),
                      isDestructive: _getPickupTime() == 'N/A',
                    ),
                    _buildOverviewItem(
                      context,
                      'Total',
                      '\$${_order!.total.toStringAsFixed(2)}',
                      isTotal: true,
                      alignRight: true,
                    ),
                  ],
                );
        },
      ),
    );
  }

  Widget _buildOverviewItem(
    BuildContext context,
    String label,
    String? value, {
    String? status,
    bool isDestructive = false,
    bool isTotal = false,
    bool alignRight = false,
  }) {
    return Column(
      crossAxisAlignment: alignRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        if (status != null)
          _buildStatusChip(status)
        else
          Text(
            value ?? '',
            style: TextStyle(
              fontSize: 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: isDestructive
                  ? Theme.of(context).colorScheme.error
                  : isTotal
                  ? Theme.of(context).colorScheme.primary
                  : Colors.black87,
            ),
          ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildOrderInfoCard(context),
        const SizedBox(height: 8),
        _buildCustomerInfoCard(context),
        const SizedBox(height: 8),
        _buildItemsCard(context),
        const SizedBox(height: 8),
        _buildPaymentCard(context),
        const SizedBox(height: 8),
        _buildSummaryCard(context),
      ],
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column
        Expanded(
          flex: 7,
          child: Column(
            children: [
              _buildItemsCard(context),
              const SizedBox(height: 8),
              _buildSummaryCard(context),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Right Column
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _buildOrderInfoCard(context),
              const SizedBox(height: 8),
              _buildCustomerInfoCard(context),
              const SizedBox(height: 8),
              _buildPaymentCard(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderInfoCard(BuildContext context) {
    return _buildCard(
      title: 'Order Information',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Order ID', _order!.id),
          _buildInfoRow('Order Number', _order!.orderNumber),
          _buildInfoRow('Order Type', _order!.orderType),
          _buildInfoRow('Origin', _order!.origin),
          _buildInfoRow('Payment Status', _order!.displayPaymentStatus),
          _buildInfoRow('Pre-Paid', _order!.prePaid ? 'Yes' : 'No'),
          if (_order!.store?.name.isNotEmpty ?? false)
            _buildInfoRow('Store', _order!.store!.name),
          if (_order!.origin == 'WEB' || _order!.displayCreator != null)
            _buildInfoRow(
              'Created By',
              _order!.origin == 'WEB'
                  ? 'Customer'
                  : '${_order!.displayCreator!.firstName} ${_order!.displayCreator!.lastName}',
            ),
          if (_order!.createdAt != null)
            _buildInfoRow(
              'Created At',
              DateFormat('MMM dd, yyyy | hh:mm a').format(_order!.createdAt!),
            ),
          if (_order!.updatedAt != null)
            _buildInfoRow(
              'Updated At',
              DateFormat('MMM dd, yyyy | hh:mm a').format(_order!.updatedAt!),
            ),
          _buildInfoRow('Comment', _order!.comment ?? 'N/A'),
          _buildInfoRow('Note', _order!.note ?? 'N/A'),
          _buildInfoRow(
            'Discount',
            '${_order!.discount?.value ?? 0.0}${_order!.discount?.type ?? ''}',
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfoCard(BuildContext context) {
    return _buildCard(
      title: 'Customer Information',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Name', _order!.customerName),
          _buildInfoRow('Phone', _order!.customerPhone),
          if (_order!.customerEmail != 'N/A')
            _buildInfoRow('Email', _order!.customerEmail),
        ],
      ),
    );
  }

  Widget _buildItemsCard(BuildContext context) {
    return _buildCard(
      title: 'Order Items (${_order!.items.length})',
      child: Column(
        children: _order!.items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == _order!.items.length - 1;

          return Column(
            children: [
              _buildOrderItemRow(item),
              if (!isLast)
                Divider(height: 12, thickness: 1, color: Colors.grey.shade200),
            ],
          );
        }).toList(),
      ),
    );
  }

  double _calculateItemTotal(OrderItem item) {
    // item.price from API already includes modifier price adjustments
    // Just multiply by quantity
    return item.price * item.quantity;
  }

  Widget _buildOrderItemRow(OrderItem item) {
    final itemName = item.item?.name ?? item.customItem;
    final hasModifiers = item.modifiers.isNotEmpty;
    final hasNote = item.itemNote?.isNotEmpty ?? false;
    final isRefunded =
        item.itemStatus?.toLowerCase() == 'refunded' ||
        (item.refundQuantity ?? 0) > 0;
    final isVoided = item.itemStatus?.toLowerCase() == 'voided';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quantity
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isRefunded
                ? Colors.blue.shade50
                : isVoided
                ? Colors.red.shade50
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isRefunded
                  ? Colors.blue.shade200
                  : isVoided
                  ? Colors.red.shade200
                  : Colors.grey.shade300,
            ),
          ),
          child: Center(
            child: Text(
              '${item.quantity}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isRefunded
                    ? Colors.blue.shade700
                    : isVoided
                    ? Colors.red.shade700
                    : Colors.grey.shade700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Item Details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      itemName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        decoration: isVoided
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        color: isVoided ? Colors.grey.shade400 : Colors.black87,
                      ),
                    ),
                  ),
                  Text(
                    '\$${_calculateItemTotal(item).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      decoration: isVoided
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      color: isVoided ? Colors.grey.shade400 : Colors.black87,
                    ),
                  ),
                ],
              ),
              if (hasModifiers) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: item.modifiers.map((modifier) {
                    final fullModifier = _modifiers.firstWhere(
                      (m) => m.id == modifier.id,
                      orElse: () => Modifier(
                        id: modifier.id,
                        name: modifier.name,
                        priceAdjustment: 0,
                        isActive: true,
                      ),
                    );
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${modifier.name}${fullModifier.priceAdjustment > 0 ? ' (+${fullModifier.priceAdjustment.toStringAsFixed(2)})' : ''}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              if (hasNote) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.note, size: 12, color: Colors.amber.shade700),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.itemNote ?? '',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (isRefunded) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Refunded: ${item.refundQuantity ?? item.quantity}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              if (isVoided) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Voided',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentCard(BuildContext context) {
    if (_order!.payments.isEmpty) {
      return _buildCard(
        title: 'Payment Information',
        child: Text(
          'No payment information available',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
      );
    }

    return _buildCard(
      title: 'Payment Information',
      child: Column(
        children: _order!.payments.asMap().entries.map((entry) {
          final index = entry.key;
          final payment = entry.value;
          final isLast = index == _order!.payments.length - 1;

          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payment.method,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (payment.cardType?.isNotEmpty ?? false)
                        Text(
                          payment.cardType ?? '',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${payment.amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (payment.change != null && payment.change! > 0)
                        Text(
                          'Change: \$${payment.change!.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if (!isLast)
                Divider(height: 8, thickness: 1, color: Colors.grey.shade200),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    final discountAmount =
        _order!.discount != null && _order!.discount!.value > 0
        ? (_order!.discount!.type == '%'
              ? _order!.subtotal * (_order!.discount!.value / 100)
              : _order!.discount!.value)
        : 0.0;

    final discountLabel =
        _order!.discount != null && _order!.discount!.value > 0
        ? _order!.discount!.type == '%'
              ? 'Discount (${_order!.discount!.value % 1 == 0 ? _order!.discount!.value.toInt() : _order!.discount!.value}%)'
              : 'Discount'
        : 'Discount';

    return _buildCard(
      title: 'Order Summary',
      child: Column(
        children: [
          _buildSummaryRow(context, 'Subtotal', _order!.subtotal),
          _buildSummaryRow(
            context,
            discountLabel,
            -discountAmount,
            isDiscount: true,
          ),
          _buildSummaryRow(context, 'Tax', _order!.tax),
          _buildSummaryRow(context, 'Tip', _order!.tip),
          Divider(height: 12, thickness: 1, color: Colors.grey.shade300),
          _buildSummaryRow(context, 'Total', _order!.total, isTotal: true),
          if (_order!.totalRefund > 0)
            _buildSummaryRow(
              context,
              'Total Refund',
              -_order!.totalRefund,
              isRefund: true,
            ),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    BuildContext context,
    String label,
    double amount, {
    bool isTotal = false,
    bool isDiscount = false,
    bool isRefund = false,
  }) {
    final color = isRefund
        ? Colors.red
        : isDiscount
        ? Theme.of(context).colorScheme.error
        : isTotal
        ? Theme.of(context).colorScheme.primary
        : Colors.black87;

    return Padding(
      padding: EdgeInsets.only(bottom: isTotal ? 0 : 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 14 : 12,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
          Text(
            '${isDiscount || isRefund ? '-' : ''}\$${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 16 : 12,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'complete':
      case 'completed':
        backgroundColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        break;
      case 'pending':
        backgroundColor = Colors.orange.shade50;
        textColor = Colors.orange.shade700;
        break;
      case 'inkitchen':
        backgroundColor = Colors.blue.shade50;
        textColor = Colors.blue.shade700;
        break;
      case 'rejected':
        backgroundColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        break;
      case 'voided':
        backgroundColor = Colors.grey.shade200;
        textColor = Colors.grey.shade700;
        break;
      default:
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
