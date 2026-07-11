import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zipzap_pos_self_orders/models/order_model.dart';
import 'package:zipzap_pos_self_orders/models/customer_model.dart';
import 'package:zipzap_pos_self_orders/widgets/app_toast.dart';
import 'package:zipzap_pos_self_orders/services/printer_service.dart';
import 'package:zipzap_pos_self_orders/models/printer_model.dart';
import 'package:zipzap_pos_self_orders/modals/contact_modal.dart';
import 'package:zipzap_pos_self_orders/modals/refund_modal.dart';
import 'package:zipzap_pos_self_orders/modals/email_receipt_modal.dart';
import 'package:zipzap_pos_self_orders/services/orders_service.dart';
import 'package:zipzap_pos_self_orders/providers/data_provider.dart';

class OrderDetailsBreadcrumb extends StatefulWidget {
  final Order order;
  final VoidCallback? onRefresh;
  final bool isRefreshing;

  const OrderDetailsBreadcrumb({
    super.key,
    required this.order,
    this.onRefresh,
    this.isRefreshing = false,
  });

  @override
  State<OrderDetailsBreadcrumb> createState() => _OrderDetailsBreadcrumbState();
}

class _OrderDetailsBreadcrumbState extends State<OrderDetailsBreadcrumb> {
  bool _isPrintingReceipt = false;
  DateTime? _selectedPickupTime;
  final OrdersService _ordersService = OrdersService();

  @override
  void initState() {
    super.initState();
    _initializePickupTime();
  }

  @override
  void didUpdateWidget(OrderDetailsBreadcrumb oldWidget) {
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
    // Fallback to pickupTime (user selected time) - pickupTime is already a DateTime
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

  String _printerTypeToString(PrinterType type) {
    switch (type) {
      case PrinterType.lan:
        return 'Lan';
      case PrinterType.usb:
        return 'Usb';
      case PrinterType.bluetooth:
        return 'Bluetooth';
      case PrinterType.wifi:
        return 'Lan';
    }
  }

  Map<String, dynamic> _formatOrderDataForReceipt() {
    final order = widget.order;

    // Get store details from DataProvider
    final dataProvider = DataProvider();
    final store = dataProvider.store;

    // Format items with modifiers
    final items = order.items.map((item) {
      final itemName = item.item?.name ?? item.customItem;

      // Build modifiers list
      final modifierList = item.modifiers.map((modifier) {
        return {'name': modifier.name, 'priceAdjustment': 0.0};
      }).toList();

      return {
        'quantity': item.quantity,
        'name': itemName,
        'price': item.price * item.quantity,
        'modifiers': modifierList,
        'itemNote': item.itemNote ?? '',
      };
    }).toList();

    final dateFormat = DateFormat('MMM dd, yyyy, HH:mm');
    final orderDate = dateFormat.format(order.date);

    // Calculate dueAt from pickupInfo if available - delayTime is now DateTime
    String dueAt;
    if (order.pickupInfo?.delayTime != null) {
      dueAt = DateFormat(
        'MMMM dd, h:mm a',
      ).format(order.pickupInfo!.delayTime!);
    } else if (order.pickupInfo?.pickupTime != null) {
      dueAt = DateFormat(
        'MMMM dd, h:mm a',
      ).format(order.pickupInfo!.pickupTime!);
    } else {
      dueAt = DateFormat(
        'MMMM dd, h:mm a',
      ).format(order.date.add(const Duration(minutes: 25)));
    }

    // Use createdAt if available, otherwise use date
    final placedAtDate = order.createdAt ?? order.date;

    return {
      'storeName': store?.name ?? order.store?.name ?? 'Store',
      'storeAddress': store?.address?.fullAddress ?? '',
      'storePhone': store?.phone ?? '',
      'storeEmail': store?.email ?? '',
      'orderNumber': order.orderNumber,
      'orderDate': orderDate,
      'orderType': order.orderType.toUpperCase(),
      'placedAt': DateFormat('MMMM dd, h:mm a').format(placedAtDate),
      'dueAt': dueAt,
      'customerName': order.customerName,
      'customerPhone': order.customerPhone,
      'items': items,
      'subtotal': order.subtotal,
      'tax': order.tax,
      'tip': order.tip,
      'discount': order.discount != null && order.discount!.value > 0
          ? (order.discount!.type == '%'
                ? order.subtotal * (order.discount!.value / 100)
                : order.discount!.value)
          : 0.0,
      'total': order.total,
      'note': order.comment ?? '',
      'splitInfo': null,
    };
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
    );

    // Get store name
    final dataProvider = DataProvider();
    final storeName =
        dataProvider.store?.name ?? widget.order.store?.name ?? '';

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

  void _showEmailReceiptModal() {
    showDialog(
      context: context,
      builder: (context) => EmailReceiptModal(
        customerEmail: widget.order.customer?.email,
        customerName: widget.order.customerName,
        orderNumber: widget.order.orderNumber,
        onCancel: () => Navigator.of(context).pop(),
        onSend: ({required email}) async {
          await _ordersService.sendEmailReceipt(
            orderId: widget.order.id,
            email: email,
          );
        },
      ),
    );
  }

  void _showRefundModal() {
    showDialog(
      context: context,
      builder: (context) => RefundModal(
        order: widget.order,
        onCancel: () {
          Navigator.of(context).pop();
        },
        onRefund:
            ({required items, required paymentMethod, required reason}) async {
              // Prepare refund data - map to API format
              final itemsToRefund = items.map((refundItem) {
                final orderItem = refundItem.orderItem;
                final productId = orderItem.item?.id;
                final orderItemId = orderItem.id;
                final isCustomItem =
                    orderItem.item == null && orderItem.customItem.isNotEmpty;

                // For regular items: use the product ID (items[].item._id)
                // For custom items: use the order item's _id since they don't
                // have a product reference
                final itemId = isCustomItem
                    ? orderItemId
                    : productId ?? orderItemId;

                debugPrint(
                  '🔄 Refund item: isCustom=$isCustomItem, productId=$productId, orderItemId=$orderItemId, using=$itemId, name=${orderItem.displayName}, qty=${refundItem.refundQuantity}',
                );

                return {
                  'itemId': itemId,
                  'refundQuantity': refundItem.refundQuantity,
                };
              }).toList();

              debugPrint('📤 Refund request: $itemsToRefund');

              // Call the API to process refund
              await _ordersService.refundOrder(
                orderId: widget.order.id,
                itemsToRefund: itemsToRefund,
                paymentMethod: paymentMethod,
                refundReason: reason,
              );

              // Refresh order details
              widget.onRefresh?.call();
            },
      ),
    );
  }

  Future<void> _handlePrintReceipt() async {
    try {
      setState(() {
        _isPrintingReceipt = true;
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

      // Format order data
      final orderData = _formatOrderDataForReceipt();

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
      debugPrint('Error printing receipt: $e');
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
          _isPrintingReceipt = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Back button and breadcrumb
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
          Text(
            'Orders',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.chevron_right,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ),
          Text(
            widget.order.orderNumber,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          // All action buttons inline
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => _showContactModal(context),
                icon: const Icon(Icons.phone, size: 16),
                label: const Text('Contact'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _isPrintingReceipt ? null : _handlePrintReceipt,
                icon: _isPrintingReceipt
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.print, size: 16),
                label: Text(_isPrintingReceipt ? 'Printing...' : 'Print'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _showEmailReceiptModal,
                icon: const Icon(Icons.email, size: 16),
                label: const Text('Receipt'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              // Refund button - only show if payment is not pending
              if (widget.order.paymentStatus.toLowerCase() != 'pending')
                OutlinedButton.icon(
                  onPressed: () {
                    _showRefundModal();
                  },
                  icon: const Icon(Icons.undo, size: 16),
                  label: const Text('Refund'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    foregroundColor: Theme.of(context).colorScheme.error,
                    minimumSize: const Size(0, 36),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              // Refresh button
              if (widget.onRefresh != null)
                OutlinedButton.icon(
                  onPressed: widget.isRefreshing ? null : widget.onRefresh,
                  icon: widget.isRefreshing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 16),
                  label: Text(
                    widget.isRefreshing ? 'Refreshing...' : 'Refresh',
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 36),
                    side: BorderSide(color: Colors.blue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
