import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zipzap_pos_self_orders/models/order_model.dart';
import 'package:zipzap_pos_self_orders/widgets/app_toast.dart';
import 'package:zipzap_pos_self_orders/services/printer_service.dart';
import 'package:zipzap_pos_self_orders/services/orders_service.dart';
import 'package:zipzap_pos_self_orders/models/printer_model.dart';
import 'package:zipzap_pos_self_orders/modals/email_receipt_modal.dart';
import 'package:zipzap_pos_self_orders/providers/data_provider.dart';

class OrderDetailsActions extends StatefulWidget {
  final Order order;

  const OrderDetailsActions({super.key, required this.order});

  @override
  State<OrderDetailsActions> createState() => _OrderDetailsActionsState();
}

class _OrderDetailsActionsState extends State<OrderDetailsActions> {
  bool _isPrintingReceipt = false;
  final OrdersService _ordersService = OrdersService();

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
        return {
          'name': modifier.name,
          'priceAdjustment':
              0.0, // Price adjustment not available in order model
        };
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
      // pickupTime is now DateTime, format it
      dueAt = DateFormat(
        'MMMM dd, h:mm a',
      ).format(order.pickupInfo!.pickupTime!);
    } else {
      // pickupTime is null means ASAP - show estimated time
      dueAt = 'ASAP';
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(0),
      child: Column(
        children: [
          Column(
            spacing: 8,
            children: [
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // TODO: Contact customer
                        if (widget.order.customerPhone != 'N/A') {
                          // Could open phone dialer or SMS
                        }
                      },
                      icon: const Icon(Icons.phone, size: 16),
                      label: const Text('Contact Customer'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        minimumSize: const Size(0, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // TODO: Refund order
                      },
                      icon: const Icon(Icons.undo, size: 16),
                      label: const Text('Refund Order'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        foregroundColor: Theme.of(context).colorScheme.error,
                        minimumSize: const Size(0, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isPrintingReceipt
                          ? null
                          : _handlePrintReceipt,
                      icon: _isPrintingReceipt
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.print, size: 16),
                      label: Text(
                        _isPrintingReceipt ? 'Printing...' : 'Print Receipt',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        minimumSize: const Size(0, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showEmailReceiptModal,
                      icon: const Icon(Icons.email, size: 16),
                      label: const Text('Email Receipt'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        minimumSize: const Size(0, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
