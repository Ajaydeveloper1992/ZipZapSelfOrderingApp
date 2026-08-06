import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/models/printer_model.dart';
import 'package:zipzap_pos_self_orders/services/printer_service.dart';
import 'package:zipzap_pos_self_orders/widgets/app_toast.dart';
import 'package:zipzap_pos_self_orders/receipt/customer_receipt.dart';
import 'package:zipzap_pos_self_orders/receipt/kitchen_receipt.dart';
import 'package:zipzap_pos_self_orders/receipt/receipt_capture_helper.dart';
import 'package:zipzap_pos_self_orders/receipt/models/receipt_models.dart';

class ReceiptPreviewPage extends StatefulWidget {
  const ReceiptPreviewPage({super.key});

  @override
  State<ReceiptPreviewPage> createState() => _ReceiptPreviewPageState();
}

class _ReceiptPreviewPageState extends State<ReceiptPreviewPage>
    with SingleTickerProviderStateMixin {
  final GlobalKey _customerReceiptKey = GlobalKey();
  final GlobalKey _kitchenReceiptKey = GlobalKey();
  late final TabController _tabController;
  bool _isPrinting = false;

  GlobalKey get _activeReceiptKey =>
      _tabController.index == 0 ? _customerReceiptKey : _kitchenReceiptKey;

  ReceiptType get _activeReceiptType =>
      _tabController.index == 0 ? ReceiptType.customer : ReceiptType.kitchen;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Preview'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Customer Receipt'),
            Tab(text: 'Kitchen Receipt'),
          ],
        ),
      ),
      body: Container(
        color: Colors.grey.shade100,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildReceiptTab(
              repaintKey: _customerReceiptKey,
              receipt: CustomerReceipt(
                model: _customerReceiptModel,
                width: ReceiptCaptureHelper.width4Inch,
              ),
            ),
            _buildReceiptTab(
              repaintKey: _kitchenReceiptKey,
              receipt: KitchenReceipt(
                model: _kitchenReceiptModel,
                width: ReceiptCaptureHelper.width4Inch,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _isPrinting
                      ? null
                      : () => _printReceipt(
                          receiptType: _activeReceiptType,
                          repaintKey: _activeReceiptKey,
                        ),
                  icon: _isPrinting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.print),
                  label: const Text('Print'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isPrinting
                      ? null
                      : () => _captureReceipt(repaintKey: _activeReceiptKey),
                  icon: const Icon(Icons.image),
                  label: const Text('Capture PNG'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptTab({
    required GlobalKey repaintKey,
    required Widget receipt,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: ReceiptCaptureHelper.width4Inch,
              constraints: BoxConstraints(maxWidth: constraints.maxWidth - 32),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(18),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: RepaintBoundary(key: repaintKey, child: receipt),
            ),
          ),
        );
      },
    );
  }

  Future<void> _captureReceipt({required GlobalKey repaintKey}) async {
    try {
      await ReceiptCaptureHelper.captureAsPng(
        repaintKey,
        pixelRatio: ReceiptCaptureHelper.capturePixelRatio4Inch,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt captured successfully.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Capture failed: $error')));
      }
    }
  }

  Future<void> _printReceipt({
    required ReceiptType receiptType,
    required GlobalKey repaintKey,
  }) async {
    try {
      setState(() => _isPrinting = true);
      final printers = await PrinterService.getSavedPrinters();
      final printersToUse = printers.where((printer) {
        final isCorrectGroup = receiptType == ReceiptType.customer
            ? printer.group == PrinterGroup.receipt
            : printer.group == PrinterGroup.kitchen;
        return isCorrectGroup && printer.status != PrinterStatus.error;
      }).toList();

      if (printersToUse.isEmpty) {
        if (mounted) {
          AppToast.warning(
            context: context,
            title: 'No Printers Found',
            description:
                'Please configure a ${receiptType == ReceiptType.customer ? 'receipt' : 'kitchen'} printer first.',
          );
        }
        return;
      }

      final receiptBase64 = await ReceiptCaptureHelper.captureAsBase64(
        repaintKey,
        pixelRatio: ReceiptCaptureHelper.capturePixelRatio4Inch,
      );
      final orderData = {
        'receiptImage': receiptBase64,
        'paperWidthMm': ReceiptCaptureHelper.width4InchMm,
      };
      var allSuccess = true;

      for (final printer in printersToUse) {
        final interfaceType = _printerTypeToString(printer.type);
        final success = receiptType == ReceiptType.customer
            ? await PrinterService.printCustomerReceipt(
                interfaceType: interfaceType,
                identifier: printer.identifier,
                orderData: orderData,
              )
            : await PrinterService.printKitchenOrder(
                interfaceType: interfaceType,
                identifier: printer.identifier,
                orderData: orderData,
              );
        if (!success) {
          allSuccess = false;
        }
      }

      if (!mounted) return;
      if (allSuccess) {
        AppToast.success(
          context: context,
          title: 'Print sent',
          description: 'Receipt image sent to printer successfully.',
        );
      } else {
        AppToast.error(
          context: context,
          title: 'Printing Failed',
          description: 'One or more printers failed to print the image.',
        );
      }
    } catch (error) {
      debugPrint('Receipt print error: $error');
      if (mounted) {
        AppToast.error(
          context: context,
          title: 'Printing Error',
          description: error.toString(),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  String _printerTypeToString(PrinterType type) {
    switch (type) {
      case PrinterType.bluetooth:
        return 'Bluetooth';
      case PrinterType.usb:
        return 'Usb';
      case PrinterType.wifi:
      case PrinterType.lan:
        return 'Lan';
    }
  }

  ReceiptModel get _customerReceiptModel => ReceiptModel(
    type: ReceiptType.customer,
    restaurantName: 'Hakka Heritage',
    address: 'Creditview, Hamilton, ON',
    phone: '+1 905 286 9099',
    website: 'hakkaheritage@gmail.com',
    orderNumber: '#1001',
    customerName: 'Gautam',
    cashier: 'WEB-4488',
    tableNumber: 'Table 5',
    orderType: 'Pickup',
    placedAt: DateTime.now(),
    items: const [
      ReceiptItem(
        id: '1',
        name: 'Shrimp Hot and Sour Soup',
        quantity: 1,
        price: 180.0,
        variants: ['Size: Large', 'Spice Level: Spicy'],
        notes: 'Item Note: Please add extra napkins',
      ),
      ReceiptItem(
        id: '2',
        name: ' Steam Momos - BOGO',
        quantity: 1,
        price: 120.0,
      ),
    ],
    orderNote: 'Please add extra napkins',
    summary: const ReceiptSummary(subtotal: 300.0, tax: 15.0, total: 315.0),
    payment: const ReceiptPayment(
      method: 'Cash',
      paidAmount: 315.0,
      change: 0.0,
    ),
  );

  ReceiptModel get _kitchenReceiptModel => ReceiptModel(
    type: ReceiptType.kitchen,
    restaurantName: 'Hakka Heritage',
    orderNumber: '#1001',
    orderType: 'Pickup',
    customerName: 'Gautam',
    phone: '8410862546',
    placedAt: DateTime.now(),
    requiredAt: DateTime.now().add(const Duration(minutes: 45)),
    kitchenNote: 'Please add extra napkins',
    items: const [
      ReceiptItem(
        id: '1',
        name: 'Shrimp Hot and Sour Soup',
        quantity: 1,
        variants: ['Size: Large', 'Spice Level: Spicy'],
        notes: 'Item Note: Please add extra napkins',
      ),
      ReceiptItem(id: '2', name: 'Steam Momos - BOGO', quantity: 1),
    ],
  );
}
