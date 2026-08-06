import 'package:flutter/material.dart';
import '../../models/receipt_model.dart';
import 'receipt_header.dart';
import 'receipt_item.dart';
import 'receipt_divider.dart';
import 'receipt_note.dart';
import 'receipt_summary.dart';
import 'receipt_footer.dart';

class ReceiptWidget extends StatelessWidget {
  final ReceiptModel model;
  final double width; // logical pixels matching target paper width

  const ReceiptWidget({super.key, required this.model, this.width = 576});

  @override
  Widget build(BuildContext context) {
    // Wrap in a constrained box so RepaintBoundary can capture correct size
    return Container(
      color: Colors.white,
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (model.type) {
      case ReceiptType.kitchen:
        return _buildKitchen(context);
      case ReceiptType.customer:
        return _buildCustomer(context);
    }
  }

  Widget _buildKitchen(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: ReceiptHeader(
            title: model.restaurantName,
            titleSize: 22,
            subtitle: model.orderType,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Order #${model.orderNumber}',
            style: t.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 36,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (model.customerName != null)
          Text('Customer: ${model.customerName}', style: t.bodyMedium),
        if (model.phone != null)
          Text('Phone: ${model.phone}', style: t.bodyMedium),
        const SizedBox(height: 6),
        Text('Placed: ${_formatDate(model.placedAt)}', style: t.bodySmall),
        if (model.dueAt != null)
          Text('Due: ${_formatDate(model.dueAt!)}', style: t.bodySmall),
        const SizedBox(height: 8),
        const ReceiptDivider(),
        if (model.orderNote != null && model.orderNote!.isNotEmpty) ...[
          const SizedBox(height: 6),
          ReceiptNote(model.orderNote!),
          const SizedBox(height: 8),
          const ReceiptDivider(),
        ],
        const SizedBox(height: 6),
        // Items
        ...model.items.map(
          (it) => Column(
            children: [
              ReceiptItemWidget(item: it, showPrice: false),
              const ReceiptDivider(),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const ReceiptDivider(),
        const SizedBox(height: 8),
        Text('Printed: ${_formatDate(DateTime.now())}', style: t.bodySmall),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Thank you — Kitchen',
            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomer(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo placeholder + header
        Center(
          child: ReceiptHeader(
            title: model.restaurantName,
            subtitle: model.address,
          ),
        ),
        const SizedBox(height: 8),
        const ReceiptDivider(),
        const SizedBox(height: 8),
        // Order info
        _infoRow('Order', model.orderNumber, context),
        if (model.customerName != null)
          _infoRow('Customer', model.customerName!, context),
        if (model.orderType != null)
          _infoRow('Order Type', model.orderType!, context),
        if (model.cashier != null) _infoRow('Cashier', model.cashier!, context),
        if (model.tableNumber != null)
          _infoRow('Table', model.tableNumber!, context),
        _infoRow('Placed', _formatDate(model.placedAt), context),
        const SizedBox(height: 8),
        const ReceiptDivider(),
        const SizedBox(height: 8),
        // Items header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Item', style: t.bodyMedium),
            Text('Qty', style: t.bodyMedium),
            Text('Price', style: t.bodyMedium),
          ],
        ),
        const SizedBox(height: 6),
        ...model.items.map(
          (it) => Column(
            children: [
              ReceiptItemWidget(item: it, showPrice: true),
              const ReceiptDivider(),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ReceiptSummaryWidget(summary: model.summary),
        const SizedBox(height: 12),
        if (model.orderNote != null && model.orderNote!.isNotEmpty) ...[
          Text('Order Note', style: t.titleMedium),
          const SizedBox(height: 6),
          ReceiptNote(model.orderNote!),
        ],
        const SizedBox(height: 12),
        const ReceiptDivider(),
        const SizedBox(height: 8),
        Center(
          child: ReceiptFooter(leftText: 'Thank You', rightText: model.website),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.black54),
          ),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
