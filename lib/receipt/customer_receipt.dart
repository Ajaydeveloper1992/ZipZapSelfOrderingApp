import 'package:flutter/material.dart';
import 'models/receipt_models.dart';
import 'shared/receipt_widgets.dart';

class CustomerReceipt extends StatelessWidget {
  final ReceiptModel model;
  final double width;
  static const String _receiptFont = 'sans-serif-condensed';

  const CustomerReceipt({super.key, required this.model, this.width = 560});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      color: Colors.white,
      child: Material(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              const SizedBox(height: 10),
              _buildOrderInfo(context),
              const SizedBox(height: 12),
              const ReceiptDivider(),
              const SizedBox(height: 12),
              _buildItems(context),
              if (model.summary != null) ...[
                const SizedBox(height: 12),
                const ReceiptDivider(),
                const SizedBox(height: 12),
                _buildSummary(context),
              ],
              if (model.orderNote != null && model.orderNote!.isNotEmpty) ...[
                const SizedBox(height: 12),
                ReceiptSection(
                  heading: 'Order Note',
                  child: ReceiptNoteBox(model.orderNote!),
                ),
              ],
              const SizedBox(height: 12),
              const ReceiptDivider(),
              const SizedBox(height: 12),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          model.restaurantName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: _receiptFont,
            fontSize: 46,
            fontWeight: FontWeight.w900,
            color: Colors.black,
            height: 0.98,
          ),
        ),
        const SizedBox(height: 10),
        if (model.address != null) ReceiptSubtext(model.address!),
        if (model.phone != null) ...[
          const SizedBox(height: 2),
          ReceiptSubtext(model.phone!),
        ],
        if (model.website != null) ...[
          const SizedBox(height: 2),
          ReceiptSubtext(model.website!),
        ],
      ],
    );
  }

  Widget _buildOrderInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _infoRow('Order', model.orderNumber, context, boldValue: true),
        if (model.customerName != null)
          _infoRow('Customer', model.customerName!, context),
        _infoRow('Date', _formatDate(model.placedAt), context),
        if (model.orderType != null)
          _infoRow('Order Type', model.orderType!, context),
        if (model.cashier != null) _infoRow('Cashier', model.cashier!, context),
        if (model.tableNumber != null)
          _infoRow('Table', model.tableNumber!, context),
        if (model.orderNote != null && model.orderNote!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Order Note: ${model.orderNote!}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildItems(BuildContext context) {
    return ReceiptSection(
      heading: 'Items',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  'Item',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'Qty',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Price',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...model.items.map(
            (item) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildItemRow(context, item),
                const SizedBox(height: 8),
                const ReceiptDivider(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(BuildContext context, ReceiptItem item) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: Text(
                item.name,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                '${item.quantity}',
                textAlign: TextAlign.right,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                item.price != null
                    ? '\$${item.price!.toStringAsFixed(2)}'
                    : '-',
                textAlign: TextAlign.right,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        if (item.variants.isNotEmpty || item.addons.isNotEmpty) ...[
          const SizedBox(height: 6),
          ReceiptItemDetails(details: [...item.variants, ...item.addons]),
        ],
        if (item.notes != null && item.notes!.isNotEmpty) ...[
          const SizedBox(height: 8),
          ReceiptNoteBox(_itemNoteText(item.notes!)),
        ],
      ],
    );
  }

  String _itemNoteText(String note) {
    final trimmed = note.trim();
    if (trimmed.toLowerCase().startsWith('order note:')) {
      return 'Item Note: ${trimmed.substring('order note:'.length).trim()}';
    }
    if (trimmed.toLowerCase().startsWith('item note:')) {
      return 'Item Note: ${trimmed.substring('item note:'.length).trim()}';
    }
    return 'Item Note: $trimmed';
  }

  Widget _buildSummary(BuildContext context) {
    final summary = model.summary!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReceiptValueRow(
          label: 'Subtotal',
          value: '\$${summary.subtotal.toStringAsFixed(2)}',
        ),
        if (summary.discount != null)
          ReceiptValueRow(
            label: 'Discount',
            value: '-\$${summary.discount!.toStringAsFixed(2)}',
          ),
        if (summary.tax != null)
          ReceiptValueRow(
            label: 'Tax',
            value: '\$${summary.tax!.toStringAsFixed(2)}',
          ),
        if (summary.serviceCharge != null)
          ReceiptValueRow(
            label: 'Service Charge',
            value: '\$${summary.serviceCharge!.toStringAsFixed(2)}',
          ),
        const SizedBox(height: 8),
        ReceiptValueRow(
          label: 'TOTAL',
          value: '\$${summary.total.toStringAsFixed(2)}',
          isTotal: true,
        ),
      ],
    );
  }

  Widget _infoRow(
    String label,
    String value,
    BuildContext context, {
    bool boldValue = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              '$label :',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(
                color: Colors.black,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: boldValue ? FontWeight.w900 : FontWeight.w800,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Thank You',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Visit Again',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 14),
        ReceiptQrPlaceholder(size: 84),
        if (model.website != null) ...[
          const SizedBox(height: 10),
          Text(
            model.website!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(
              color: Colors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  String _formatDate(DateTime date) {
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = date.hour == 0 || date.hour == 12 ? 12 : date.hour % 12;
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day.toString().padLeft(2, '0')} ${monthNames[date.month - 1]} ${date.year} $hour:$minute $period';
  }
}
