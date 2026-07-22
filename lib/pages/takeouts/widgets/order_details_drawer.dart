import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:zipzap_pos_self_orders/core/constants/api_constants.dart';
import 'package:zipzap_pos_self_orders/models/order_model.dart';
import 'package:zipzap_pos_self_orders/models/customer_model.dart';
import 'package:zipzap_pos_self_orders/providers/data_provider.dart';
import 'package:zipzap_pos_self_orders/services/customers_service.dart';
import 'package:zipzap_pos_self_orders/services/orders_service.dart';
import 'package:zipzap_pos_self_orders/utils/timezone_utils.dart';
import 'package:zipzap_pos_self_orders/widgets/app_toast.dart';
import 'package:zipzap_pos_self_orders/services/printer_service.dart';
import 'package:zipzap_pos_self_orders/models/printer_model.dart';
import 'package:zipzap_pos_self_orders/modals/contact_modal.dart';

class OrderDetailsDrawer extends StatefulWidget {
  final Order order;

  const OrderDetailsDrawer({super.key, required this.order});

  @override
  State<OrderDetailsDrawer> createState() => _OrderDetailsDrawerState();
}

class _OrderDetailsDrawerState extends State<OrderDetailsDrawer> {
  bool _isOrderItemsExpanded = true; // Keep Order Items expanded by default
  bool _isCustomerDetailsExpanded = false;
  bool _isAdditionalInfoExpanded = false;
  DateTime? _selectedPickupTime;
  bool _isRejectingOrder = false;
  bool _isAcceptingOrder = false;
  bool _isCompletingOrder = false;
  bool _isVoidingOrder = false;
  bool _isPrintingCustomer = false;
  bool _isPrintingKitchen = false;
  final bool _isSendingContact = false;
  bool _isUpdatingPickupTime = false;
  final OrdersService _ordersService = OrdersService();
  final CustomersService _customersService = CustomersService();
  final DataProvider _dataProvider = DataProvider();

  /// Fresh customer fetched right before a print, used to source an
  /// up-to-date `isReturning` and orders count for the receipt's
  /// "Returning Customer" badge. Web orders' embedded `OrderCustomer`
  /// has `totalOrders` defaulted to 0 on the server (no maintenance
  /// path), and `isReturning` can be stale, so we refetch from the API.
  Customer? _freshCustomerForPrint;

  /// Fetch the latest customer record before printing so the receipt
  /// shows accurate "Returning Customer (N Orders)" data. Falls back
  /// silently if there's no customer or the API call fails.
  Future<void> _refreshCustomerForPrint() async {
    final customerId = widget.order.customer?.id;
    if (customerId == null || customerId.isEmpty) {
      _freshCustomerForPrint = null;
      return;
    }
    try {
      _freshCustomerForPrint = await _customersService.getCustomerById(
        customerId,
      );
    } catch (e) {
      debugPrint('Failed to refresh customer for print: $e');
      // Keep whatever we last had so the receipt still prints.
    }
  }

  @override
  void initState() {
    super.initState();
    _initializePickupTime();
  }

  @override
  void didUpdateWidget(OrderDetailsDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-initialize pickup time if order changed
    if (oldWidget.order.id != widget.order.id) {
      _initializePickupTime();
    }
  }

  void _initializePickupTime() {
    // Prioritize delayTime first (updated time) - now DateTime
    final delayTime = widget.order.pickupInfo?.delayTime;
    if (delayTime != null) {
      setState(() {
        _selectedPickupTime = delayTime;
      });
      return;
    }
    // Fallback to pickupTime (user selected time) - now DateTime
    final pickupTime = widget.order.pickupInfo?.pickupTime;
    if (pickupTime != null) {
      setState(() {
        _selectedPickupTime = pickupTime;
      });
      return;
    }
    // Reset to null if no valid time found
    setState(() {
      _selectedPickupTime = null;
    });
  }

  String _getOrderTime() {
    try {
      return DateFormat('hh:mm a').format(widget.order.date);
    } catch (e) {
      return 'N/A';
    }
  }

  Future<void> _handleRejectOrder() async {
    // Show confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Order'),
        content: Text(
          'Are you sure you want to reject order #${widget.order.orderNumber}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Reject Order'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isRejectingOrder = true;
    });

    try {
      await _ordersService.updateOrderStatus(
        orderId: widget.order.id,
        orderstatus: ApiConstants.orderStatusRejected,
      );

      // Force refresh from API to ensure cache is updated with latest data
      await _dataProvider.loadTakeoutOrders(forceRefresh: true);

      if (mounted) {
        AppToast.success(
          context: context,
          title: 'Order Rejected',
          description:
              'Order #${widget.order.orderNumber} has been rejected successfully',
        );
        Navigator.of(
          context,
        ).pop(true); // Return true to indicate order was updated
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context: context,
          title: 'Rejection Failed',
          description: e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRejectingOrder = false;
        });
      }
    }
  }

  Future<void> _handleAcceptOrder() async {
    // Show confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Order'),
        content: Text(
          'Accept order #${widget.order.orderNumber} and send to kitchen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Accept Order'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isAcceptingOrder = true;
    });

    try {
      // Send delay time as UTC ISO timestamp if selected
      final delayTime = TimezoneUtils.toUtcIsoString(_selectedPickupTime);

      final updatedOrder = await _ordersService.updateOrderStatus(
        orderId: widget.order.id,
        orderstatus: ApiConstants.orderStatusInKitchen,
        delayTime: delayTime,
      );

      // Update in-memory list immediately for instant UI update
      _dataProvider.updateTakeoutOrderInMemory(updatedOrder);

      // Force refresh from API to ensure cache is updated with latest data
      await _dataProvider.loadTakeoutOrders(forceRefresh: true);

      // Print kitchen receipt automatically (don't wait for it to complete)
      _handlePrintKitchenReceipt();

      // SMS + email notifications are now handled server-side via ORDER_STATUS_CHANGED event

      if (mounted) {
        AppToast.success(
          context: context,
          title: 'Order Accepted',
          description:
              'Order #${widget.order.orderNumber} has been sent to kitchen',
        );
        Navigator.of(
          context,
        ).pop(true); // Return true to indicate order was updated
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context: context,
          title: 'Accept Failed',
          description: e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAcceptingOrder = false;
        });
      }
    }
  }

  Future<void> _handleCompleteOrder() async {
    // Show confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Order'),
        content: Text('Mark order #${widget.order.orderNumber} as completed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Complete Order'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isCompletingOrder = true;
    });

    try {
      await _ordersService.updateOrderStatus(
        orderId: widget.order.id,
        orderstatus: ApiConstants.orderStatusComplete,
      );

      // Force refresh from API to ensure cache is updated with latest data
      await _dataProvider.loadTakeoutOrders(forceRefresh: true);

      if (mounted) {
        AppToast.success(
          context: context,
          title: 'Order Completed',
          description:
              'Order #${widget.order.orderNumber} has been marked as completed',
        );
        Navigator.of(
          context,
        ).pop(true); // Return true to indicate order was updated
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context: context,
          title: 'Complete Failed',
          description: e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCompletingOrder = false;
        });
      }
    }
  }

  Future<void> _handleVoidOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Void Order'),
        content: Text(
          'Are you sure you want to void order #${widget.order.orderNumber}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Void Order'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isVoidingOrder = true;
    });

    try {
      await _ordersService.updateOrderStatus(
        orderId: widget.order.id,
        orderstatus: ApiConstants.orderStatusVoided,
      );

      await _dataProvider.loadTakeoutOrders(forceRefresh: true);

      if (mounted) {
        AppToast.success(
          context: context,
          title: 'Order Voided',
          description:
              'Order #${widget.order.orderNumber} has been voided successfully',
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context: context,
          title: 'Void Failed',
          description: e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVoidingOrder = false;
        });
      }
    }
  }

  Future<void> _handlePrintKitchenReceipt() async {
    try {
      setState(() {
        _isPrintingKitchen = true;
      });

      // Refresh customer so the kitchen receipt's "Returning Customer
      // (N Orders)" badge reflects the latest server state. The order's
      // embedded customer has `totalOrders` defaulted to 0 server-side
      // and `isReturning` can be stale -- particularly for web orders.
      await _refreshCustomerForPrint();

      // Refresh products to ensure labels are up-to-date
      await _dataProvider.loadProducts(forceRefresh: true);

      // Get kitchen printers (kitchen group) only
      final printers = await PrinterService.getSavedPrinters();
      final kitchenPrinters = printers
          .where((p) => p.group == PrinterGroup.kitchen)
          .where((p) => p.status != PrinterStatus.error)
          .toList();

      if (kitchenPrinters.isEmpty) {
        if (mounted) {
          AppToast.warning(
            context: context,
            title: 'No Kitchen Printers Found',
            description: 'Please add a kitchen printer (Kitchen group) first.',
          );
        }
        return;
      }

      // Print to each kitchen printer with label-based filtering
      bool allSuccess = true;
      for (final printer in kitchenPrinters) {
        final filteredItems = _filterOrderItemsForPrinter(
          widget.order.items,
          printer,
        );
        if (filteredItems.isEmpty) continue;

        final orderData = _formatOrderDataForPrinting(
          orderItems: filteredItems,
        );
        try {
          final interfaceType = _printerTypeToString(printer.type);
          final success = await PrinterService.printKitchenOrder(
            interfaceType: interfaceType,
            identifier: printer.identifier,
            orderData: orderData,
          );
          if (!success) {
            allSuccess = false;
          }
        } catch (e) {
          debugPrint('Error printing to ${printer.name}: $e');
          allSuccess = false;
        }
      }

      if (mounted) {
        if (allSuccess) {
          AppToast.success(
            context: context,
            title: 'Kitchen Receipt Printed',
            description: 'Kitchen order printed successfully',
          );
        } else {
          AppToast.error(
            context: context,
            title: 'Printing Failed',
            description: 'Some printers failed. Please check printer status.',
          );
        }
      }
    } catch (e) {
      debugPrint('Error printing kitchen receipt: $e');
      if (mounted) {
        AppToast.error(
          context: context,
          title: 'Printing Error',
          description: 'Error printing: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPrintingKitchen = false;
        });
      }
    }
  }

  Map<String, dynamic> _formatOrderDataForPrinting({
    List<OrderItem>? orderItems,
  }) {
    // Get store information from DataProvider or order
    final store = _dataProvider.store;
    final orderStore = widget.order.store;
    final storeName = store?.name ?? orderStore?.name ?? '';
    // StoreDetails doesn't have address field, use empty string or get from order if available
    final storeAddress = ''; // Address not available in StoreDetails
    final storePhone = store?.phone ?? '';
    final storeEmail = store?.email ?? '';

    // Format order date
    String orderDate = '';
    try {
      orderDate = DateFormat('MMM dd, yyyy, HH:mm').format(widget.order.date);
    } catch (e) {
      orderDate = DateFormat('MMM dd, yyyy, HH:mm').format(DateTime.now());
    }

    // Resolve modifier names from store cache when empty (e.g. order from WebSocket with IDs only)
    final storeModifiers = _dataProvider.modifiersList;

    // Format items with modifiers
    final itemsSource = orderItems ?? widget.order.items;
    final items = itemsSource.map((orderItem) {
      // Format modifiers
      final modifierList = orderItem.modifiers.map((mod) {
        String name = mod.name;
        if (name.trim().isEmpty &&
            mod.id.isNotEmpty &&
            storeModifiers.isNotEmpty) {
          final resolved = storeModifiers.where((m) => m.id == mod.id);
          if (resolved.isNotEmpty) name = resolved.first.name;
        }
        return {
          'name': name,
          'priceAdjustment':
              0.0, // Modifiers in OrderItem don't have priceAdjustment
          'group': '', // Modifiers in OrderItem don't have group info
        };
      }).toList();

      // Calculate item price (price is per item, multiply by quantity)
      final itemPrice = orderItem.price * orderItem.quantity;

      return {
        'quantity': orderItem.quantity,
        'name': orderItem.displayName,
        'price': itemPrice,
        'modifiers': modifierList,
        'itemNote': orderItem.itemNote,
      };
    }).toList();

    // Determine order type for display
    String orderTypeDisplay = 'PICKUP';
    if (widget.order.orderType.toLowerCase().contains('delivery')) {
      orderTypeDisplay = 'DELIVERY';
    } else if (widget.order.orderType.toLowerCase().contains('dine')) {
      orderTypeDisplay = 'DINE-IN';
    }

    // Format pickup time if available
    // Use createdAt if available, otherwise use date
    final placedAtDate = widget.order.createdAt ?? widget.order.date;
    String placedAt = DateFormat('MMMM dd, h:mm a').format(placedAtDate);
    String dueAt = '';
    // delayTime is now DateTime?, check if it's set
    if (widget.order.pickupInfo?.delayTime != null) {
      dueAt = DateFormat(
        'MMMM dd, h:mm a',
      ).format(widget.order.pickupInfo!.delayTime!);
    } else if (widget.order.pickupInfo?.pickupTime != null) {
      // Use pickupTime if delayTime is not set
      dueAt = DateFormat(
        'MMMM dd, h:mm a',
      ).format(widget.order.pickupInfo!.pickupTime!);
    } else {
      // No pickup time (ASAP): add 25 minutes to order date
      final dueDateTime = widget.order.date.add(const Duration(minutes: 25));
      dueAt = DateFormat('MMMM dd, h:mm a').format(dueDateTime);
    }

    return {
      'storeName': storeName,
      'storeAddress': storeAddress,
      'storePhone': storePhone,
      'storeEmail': storeEmail,
      'orderNumber': widget.order.orderNumber,
      'orderDate': orderDate,
      'orderType': orderTypeDisplay,
      'placedAt': placedAt,
      'dueAt': dueAt,
      'customerName': widget.order.customer?.fullName ?? '',
      'customerPhone': widget.order.customer?.phone ?? '',
      // Prefer the freshly-fetched Customer (populated with the live
      // `isReturning` flag and the actual `orders.length`). Fall back to
      // the order's embedded snapshot when no fresh fetch happened.
      'isReturningCustomer':
          _freshCustomerForPrint?.isReturning ??
          widget.order.customer?.isReturning ??
          false,
      'customerOrderCount':
          _freshCustomerForPrint?.ordersCount ??
          widget.order.customer?.totalOrders ??
          0,
      'items': items,
      'subtotal': widget.order.subtotal,
      'tax': widget.order.tax,
      'tip': widget.order.tip,
      'discount':
          widget.order.discount != null && widget.order.discount!.value > 0
          ? (widget.order.discount!.type == '%'
                ? widget.order.subtotal * (widget.order.discount!.value / 100)
                : widget.order.discount!.value)
          : 0.0,
      'total': widget.order.total,
      'note': widget.order.note ?? widget.order.comment ?? '',
      'splitInfo': null,
    };
  }

  List<OrderItem> _filterOrderItemsForPrinter(
    List<OrderItem> items,
    Printer printer,
  ) {
    if (printer.selectedLabels.isEmpty) return items;
    final products = _dataProvider.productsList;
    return items.where((orderItem) {
      final productId = orderItem.item?.id;
      if (productId == null || productId.isEmpty) return true;
      final matching = products.where((p) => p.id == productId);
      if (matching.isEmpty) return true;
      final labels = matching.first.labels;
      if (labels.isEmpty) return true;
      return labels.any((labelId) => printer.selectedLabels.contains(labelId));
    }).toList();
  }

  String _printerTypeToString(PrinterType type) {
    switch (type) {
      case PrinterType.lan:
        return 'Lan';
      case PrinterType.usb:
        return 'Usb';
      case PrinterType.bluetooth:
        return 'Bluetooth';
      case PrinterType.wifi:
        return 'Lan'; // WiFi uses LAN interface
    }
  }

  String _getPickupTime() {
    // Prioritize delayTime first (updated time) - now DateTime
    if (widget.order.pickupInfo?.delayTime != null) {
      return DateFormat('h:mm a').format(widget.order.pickupInfo!.delayTime!);
    }
    // Fallback to pickupTime (user selected time) - now DateTime
    if (widget.order.pickupInfo?.pickupTime != null) {
      return DateFormat('h:mm a').format(widget.order.pickupInfo!.pickupTime!);
    }
    // null pickupTime = ASAP
    return 'ASAP';
  }

  String _formatPickupTime(DateTime time) {
    // Format as "8:20 AM" (with colon)
    final hour = time.hour == 0
        ? 12
        : time.hour > 12
        ? time.hour - 12
        : time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _getCreatedByDisplay() {
    if (widget.order.origin == 'WEB') {
      return 'Customer';
    }
    final creator = widget.order.displayCreator;
    if (creator != null) {
      return '${creator.firstName} ${creator.lastName}'.trim();
    }
    return 'N/A';
  }

  Future<void> _handleUpdatePickupTime(DateTime newTime) async {
    setState(() {
      _isUpdatingPickupTime = true;
    });

    try {
      // Send as UTC ISO timestamp
      final delayTimeIso = TimezoneUtils.toUtcIsoString(newTime);
      final delayTimeDisplay = _formatPickupTime(newTime);

      await _ordersService.updateOrderStatus(
        orderId: widget.order.id,
        orderstatus: widget.order.orderstatus, // Keep current status
        delayTime: delayTimeIso,
      );

      // Force refresh from API to ensure cache is updated
      await _dataProvider.loadTakeoutOrders(forceRefresh: true);

      if (mounted) {
        AppToast.success(
          context: context,
          title: 'Pickup Time Updated',
          description: 'Pickup time changed to $delayTimeDisplay',
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context: context,
          title: 'Update Failed',
          description: e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingPickupTime = false;
        });
      }
    }
  }

  Future<void> _showTimePicker() async {
    final now = DateTime.now();
    final initialTime = _selectedPickupTime ?? now;
    DateTime tempSelectedTime = initialTime;

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => Container(
        height: 280,
        padding: const EdgeInsets.only(top: 6.0),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              // Header with Done button
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: CupertinoColors.separator,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const Text(
                      'Select Pickup Time',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        Navigator.of(context).pop();
                        // Update state and call API
                        setState(() {
                          _selectedPickupTime = tempSelectedTime;
                        });
                        _handleUpdatePickupTime(tempSelectedTime);
                      },
                      child: const Text(
                        'Done',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              // Time picker with colon separator
              Expanded(
                child: Stack(
                  children: [
                    CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.time,
                      initialDateTime: initialTime,
                      use24hFormat: false,
                      onDateTimeChanged: (DateTime newTime) {
                        tempSelectedTime = newTime;
                      },
                    ),
                    // Overlay colon separator between hour and minute
                    // Positioned at center with slight left offset to sit between hour and minute columns
                    Center(
                      child: Transform.translate(
                        offset: const Offset(-30, -2),
                        child: const Text(
                          ':',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w300,
                            color: CupertinoColors.label,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'InKitchen':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getOriginColor(String origin) {
    switch (origin) {
      case 'AI':
        return Colors.purple;
      case 'WEB':
        return Colors.blue;
      case 'POS':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Future<void> _handlePrintCustomerReceipt() async {
    try {
      setState(() {
        _isPrintingCustomer = true;
      });

      // Get receipt printers (receipt group) only
      final printers = await PrinterService.getSavedPrinters();
      final receiptPrinters = printers
          .where((p) => p.group == PrinterGroup.receipt)
          .where((p) => p.status != PrinterStatus.error)
          .toList();

      if (receiptPrinters.isEmpty) {
        if (mounted) {
          AppToast.warning(
            context: context,
            title: 'No Receipt Printers Found',
            description: 'Please add a receipt printer (Receipt group) first.',
          );
        }
        return;
      }

      // Format order data using existing method
      final orderData = _formatOrderDataForPrinting();

      // Print to all receipt printers
      bool allSuccess = true;
      for (final printer in receiptPrinters) {
        try {
          final interfaceType = _printerTypeToString(printer.type);
          final success = await PrinterService.printCustomerReceipt(
            interfaceType: interfaceType,
            identifier: printer.identifier,
            orderData: orderData,
          );
          if (!success) {
            allSuccess = false;
          }
        } catch (e) {
          debugPrint('Error printing to ${printer.name}: $e');
          allSuccess = false;
        }
      }

      if (mounted) {
        if (allSuccess) {
          AppToast.success(
            context: context,
            title: 'Receipt Printed',
            description: 'Customer receipt printed successfully',
          );
        } else {
          AppToast.error(
            context: context,
            title: 'Printing Failed',
            description: 'Some printers failed. Please check printer status.',
          );
        }
      }
    } catch (e) {
      debugPrint('Error printing customer receipt: $e');
      if (mounted) {
        AppToast.error(
          context: context,
          title: 'Printing Error',
          description: 'Error printing: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPrintingCustomer = false;
        });
      }
    }
  }

  void _showContactModal(BuildContext context) {
    // Check if customer is available
    if (widget.order.customer == null) {
      AppToast.warning(
        context: context,
        title: 'No Customer',
        description: 'This order has no customer information',
      );
      return;
    }

    // Convert OrderCustomer to Customer
    final orderCustomer = widget.order.customer!;
    final customer = Customer(
      id: orderCustomer.id,
      firstName: orderCustomer.firstName,
      lastName: orderCustomer.lastName,
      phone: orderCustomer.phone,
      email: orderCustomer.email,
    );

    // Get store name
    final store = _dataProvider.store;
    final orderStore = widget.order.store;
    final storeName = store?.name ?? orderStore?.name ?? '';

    showDialog(
      context: context,
      builder: (context) => ContactModal(
        customer: customer,
        orderNumber: widget.order.orderNumber,
        storeName: storeName,
        currentPickupTime: _selectedPickupTime,
        onCancel: () {
          Navigator.of(context).pop();
        },
        // The ContactModal handles the API call directly, onSend is optional for additional handling
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Responsive width: smaller screens get more width, larger screens get less
    double drawerWidth;
    if (screenWidth < 600) {
      // Small screens: use 90% width
      drawerWidth = screenWidth * 0.9;
    } else if (screenWidth < 1024) {
      // Medium screens: use 50% width
      drawerWidth = screenWidth * 0.7;
    } else {
      // Large screens: use 40% width
      drawerWidth = screenWidth * 0.4;
    }

    return Drawer(
      width: drawerWidth,
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            // Header: Quick View, Order ID, Status, Origin
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Order #${widget.order.orderNumber}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.end,
                            alignment: WrapAlignment.end,
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              // Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    widget.order.orderstatus,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _getStatusColor(
                                      widget.order.orderstatus,
                                    ),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      widget.order.orderstatus == 'Pending'
                                          ? Icons.schedule
                                          : Icons.done_all,
                                      size: 14,
                                      color: _getStatusColor(
                                        widget.order.orderstatus,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.order.orderstatus,
                                      style: TextStyle(
                                        color: _getStatusColor(
                                          widget.order.orderstatus,
                                        ),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Origin Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getOriginColor(
                                    widget.order.origin,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _getOriginColor(widget.order.origin),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      widget.order.origin == 'POS'
                                          ? Icons.store
                                          : Icons.language,
                                      size: 14,
                                      color: _getOriginColor(
                                        widget.order.origin,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.order.origin,
                                      style: TextStyle(
                                        color: _getOriginColor(
                                          widget.order.origin,
                                        ),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Payment Status
                              if (widget.order.paymentStatus == 'Paid')
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'PAID',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: Container(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Order Time - Pickup Time - Total
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 8,
                          right: 8,
                          top: 6,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildTimeInfo(
                                context,
                                'Order Time',
                                _getOrderTime(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildTimeInfo(
                                context,
                                'Pickup Time',
                                _getPickupTime(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildTimeInfo(
                                context,
                                'Total',
                                '\$${widget.order.total.toStringAsFixed(2)}',
                                isTotal: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Customer Details (ExpansionTile)
                      _buildCustomExpansionTile(
                        context,
                        title: Text(
                          'Customer Details',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        isExpanded: _isCustomerDetailsExpanded,
                        onExpansionChanged: (value) {
                          setState(() {
                            _isCustomerDetailsExpanded = value;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 16,
                            right: 16,
                            bottom: 8,
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildInfoRow(
                                      Icons.person_outline,
                                      'Name',
                                      widget.order.customer?.fullName ??
                                          'Guest',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildInfoRow(
                                      Icons.phone_outlined,
                                      'Phone',
                                      widget.order.customer?.phone ?? 'N/A',
                                    ),
                                  ),
                                ],
                              ),
                              if (widget.order.customer?.email != null &&
                                  widget.order.customer!.email!.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _buildInfoRow(
                                  Icons.email_outlined,
                                  'Email',
                                  widget.order.customer!.email!,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.2),
                      ),
                      // Order Items (ExpansionTile)
                      _buildCustomExpansionTile(
                        context,
                        title: Text(
                          'Order Items (${widget.order.items.length})',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        isExpanded: _isOrderItemsExpanded,
                        onExpansionChanged: (value) {
                          setState(() {
                            _isOrderItemsExpanded = value;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 16,
                            right: 16,
                            bottom: 8,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Order Items List
                              ...widget.order.items.map(
                                (item) => _buildOrderItem(context, item),
                              ),
                              const SizedBox(height: 8),
                              Divider(
                                height: 1,
                                color: Theme.of(
                                  context,
                                ).colorScheme.outline.withValues(alpha: 0.2),
                              ),
                              const SizedBox(height: 8),
                              _buildPaymentRow(
                                context,
                                'Subtotal',
                                widget.order.subtotal,
                              ),
                              if (widget.order.discount != null &&
                                  widget.order.discount!.value > 0) ...[
                                _buildPaymentRow(
                                  context,
                                  'Discount${widget.order.discount?.type == '%' ? ' (${widget.order.discount!.value % 1 == 0 ? widget.order.discount!.value.toInt() : widget.order.discount!.value}%)' : ''}',
                                  widget.order.discount!.type == '%'
                                      ? widget.order.subtotal *
                                            (widget.order.discount!.value / 100)
                                      : widget.order.discount!.value,
                                  isDiscount: true,
                                ),
                              ],
                              if (widget.order.tax > 0)
                                _buildPaymentRow(
                                  context,
                                  'Tax',
                                  widget.order.tax,
                                ),
                              if (widget.order.tip > 0)
                                _buildPaymentRow(
                                  context,
                                  'Tip',
                                  widget.order.tip,
                                ),
                              Divider(
                                height: 8,
                                color: Theme.of(
                                  context,
                                ).colorScheme.outline.withValues(alpha: 0.2),
                              ),
                              _buildPaymentRow(
                                context,
                                'Total',
                                widget.order.total,
                                isTotal: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Divider(
                        height: 1,
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.2),
                      ),
                      // Additional Info (ExpansionTile)
                      _buildCustomExpansionTile(
                        context,
                        title: Text(
                          'Additional Info',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        isExpanded: _isAdditionalInfoExpanded,
                        onExpansionChanged: (value) {
                          setState(() {
                            _isAdditionalInfoExpanded = value;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 16,
                            right: 16,
                            bottom: 8,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Info Grid (2 columns)
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildInfoRow(
                                      Icons.shopping_bag_outlined,
                                      'Order Type',
                                      widget.order.orderType,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildInfoRow(
                                      Icons.payment,
                                      'Payment Status',
                                      widget.order.displayPaymentStatus,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildInfoRow(
                                      widget.order.orderstatus == 'Pending'
                                          ? Icons.schedule
                                          : Icons.done_all,
                                      'Order Status',
                                      widget.order.orderstatus,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildInfoRow(
                                      Icons.store,
                                      'Created By',
                                      _getCreatedByDisplay(),
                                    ),
                                  ),
                                ],
                              ),
                              // Notes
                              if (widget.order.items.any(
                                (item) => item.itemNote?.isNotEmpty ?? false,
                              )) ...[
                                const SizedBox(height: 16),
                                _buildSectionTitle(context, 'Notes'),
                                const SizedBox(height: 8),
                                ...widget.order.items
                                    .where(
                                      (item) =>
                                          item.itemNote?.isNotEmpty ?? false,
                                    )
                                    .map(
                                      (item) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 6,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              Icons.note_outlined,
                                              size: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                '${item.displayName}: ${item.itemNote}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(fontSize: 12),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom Action Buttons
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // First Row: Receipt buttons (left) and Pickup Times (right)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left side: Receipt and Contact buttons (for InKitchen & Paid)
                      if (widget.order.orderstatus == 'InKitchen' &&
                          widget.order.paymentStatus == 'Paid')
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _isPrintingCustomer
                                  ? null
                                  : _handlePrintCustomerReceipt,
                              icon: _isPrintingCustomer
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.print, size: 16),
                              label: Text(
                                _isPrintingCustomer
                                    ? 'Printing...'
                                    : 'Customer Receipt',
                              ),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                iconSize: 15,
                                textStyle: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _isPrintingKitchen
                                  ? null
                                  : _handlePrintKitchenReceipt,
                              icon: _isPrintingKitchen
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.print, size: 16),
                              label: Text(
                                _isPrintingKitchen
                                    ? 'Printing...'
                                    : 'Kitchen Receipt',
                              ),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                iconSize: 15,
                                textStyle: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (widget.order.customer != null) ...[
                              OutlinedButton.icon(
                                onPressed: _isSendingContact
                                    ? null
                                    : () => _showContactModal(context),
                                icon: _isSendingContact
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.perm_phone_msg,
                                        size: 16,
                                      ),
                                label: Text(
                                  _isSendingContact ? 'Sending...' : 'Contact',
                                ),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  iconSize: 15,
                                  textStyle: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ],
                        ),
                      // Right side: Recommended Pickup Times & Contact (for Pending)
                      if (widget.order.orderstatus == 'Pending')
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Recommended Pickup Times',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _isUpdatingPickupTime
                                      ? null
                                      : _showTimePicker,
                                  icon: _isUpdatingPickupTime
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.access_time, size: 16),
                                  label: Text(
                                    _isUpdatingPickupTime
                                        ? 'Updating...'
                                        : _selectedPickupTime != null
                                        ? _formatPickupTime(
                                            _selectedPickupTime!,
                                          )
                                        : 'Select Time',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    iconSize: 15,
                                    textStyle: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _isSendingContact
                                      ? null
                                      : () => _showContactModal(context),
                                  icon: _isSendingContact
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.send, size: 16),
                                  label: Text(
                                    _isSendingContact
                                        ? 'Sending...'
                                        : 'Contact Customer',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    iconSize: 15,
                                    textStyle: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                    ],
                  ),
                  // Second Row: Buttons based on order status
                  if (widget.order.orderstatus == 'Pending' ||
                      (widget.order.orderstatus == 'InKitchen' &&
                          widget.order.paymentStatus == 'Paid') ||
                      (widget.order.orderstatus == 'InKitchen' &&
                          widget.order.paymentStatus == 'Pending')) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // For Pending: Reject and Accept buttons
                        if (widget.order.orderstatus == 'Pending') ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isRejectingOrder
                                  ? null
                                  : _handleRejectOrder,
                              icon: _isRejectingOrder
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.close, size: 18),
                              label: Text(
                                _isRejectingOrder ? 'Rejecting...' : 'Reject',
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.error.withValues(alpha: 0.1),
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.error,
                                minimumSize: const Size(0, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _isAcceptingOrder
                                  ? null
                                  : _handleAcceptOrder,
                              icon: _isAcceptingOrder
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Icon(Icons.check_circle, size: 18),
                              label: Text(
                                _isAcceptingOrder ? 'Accepting...' : 'Accept',
                              ),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                        // For InKitchen & Paid: Refund and Complete Order buttons
                        if (widget.order.orderstatus == 'InKitchen' &&
                            widget.order.paymentStatus == 'Paid') ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                // TODO: Handle refund
                                Navigator.of(context).pop();
                              },
                              icon: const Icon(Icons.undo, size: 18),
                              label: const Text('Refund'),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.error.withValues(alpha: 0.1),
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.error,
                                minimumSize: const Size(0, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _isCompletingOrder
                                  ? null
                                  : _handleCompleteOrder,
                              icon: _isCompletingOrder
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Icon(Icons.check_circle, size: 18),
                              label: Text(
                                _isCompletingOrder
                                    ? 'Completing...'
                                    : 'Complete Order',
                              ),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                        // For InKitchen & Pending payment: Void and Complete buttons
                        if (widget.order.orderstatus == 'InKitchen' &&
                            widget.order.paymentStatus == 'Pending') ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isVoidingOrder
                                  ? null
                                  : _handleVoidOrder,
                              icon: _isVoidingOrder
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.block, size: 18),
                              label: Text(
                                _isVoidingOrder ? 'Voiding...' : 'Void Order',
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.error.withValues(alpha: 0.1),
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.error,
                                minimumSize: const Size(0, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _isCompletingOrder
                                  ? null
                                  : _handleCompleteOrder,
                              icon: _isCompletingOrder
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Icon(Icons.check_circle, size: 18),
                              label: Text(
                                _isCompletingOrder
                                    ? 'Completing...'
                                    : 'Complete Order',
                              ),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomExpansionTile(
    BuildContext context, {
    required Widget title,
    required bool isExpanded,
    required ValueChanged<bool> onExpansionChanged,
    required Widget child,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: () => onExpansionChanged(!isExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(child: title),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    CupertinoIcons.chevron_down,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: ClipRect(child: isExpanded ? child : const SizedBox.shrink()),
        ),
      ],
    );
  }

  Widget _buildTimeInfo(
    BuildContext context,
    String label,
    String value, {
    bool isTotal = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isTotal ? Colors.red.shade700 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.secondary,
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderItem(BuildContext context, OrderItem item) {
    final isVoided = item.itemStatus?.toLowerCase() == 'voided';
    final isRefunded =
        item.itemStatus?.toLowerCase() == 'refunded' ||
        item.itemStatus?.toLowerCase() == 'partially refunded';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quantity x Item Name - Price (right aligned)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    // Status badge
                    if (isVoided)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'VOID',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                      )
                    else if (isRefunded)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'REFUNDED',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        '${item.quantity}x ${item.displayName}',
                        maxLines: 1,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isVoided || isRefunded
                              ? Colors.grey
                              : Theme.of(context).colorScheme.secondary,
                          decoration: isVoided
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isVoided || isRefunded
                      ? Colors.grey
                      : Theme.of(context).colorScheme.error,
                  decoration: isVoided ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
          // Void reason (if available)
          if (isVoided && item.voidReason != null) ...[
            const SizedBox(height: 2),
            Text(
              'Void reason: ${item.voidReason}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.red.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          // Note (if available)
          if (item.itemNote?.isNotEmpty ?? false) ...[
            const SizedBox(height: 4),
            Text(
              'Note: ${item.itemNote}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentRow(
    BuildContext context,
    String label,
    double amount, {
    bool isTotal = false,
    bool isDiscount = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 14 : 12,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
          Text(
            '${isDiscount ? '- ' : ''}\$${amount.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isTotal
                  ? Theme.of(context).colorScheme.error
                  : isDiscount
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.secondary,
            ),
          ),
        ],
      ),
    );
  }
}
