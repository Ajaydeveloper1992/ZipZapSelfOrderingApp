import 'package:flutter/material.dart';
import 'models/receipt_models.dart';
import 'shared/receipt_widgets.dart';

class KitchenReceipt extends StatelessWidget {
  final ReceiptModel model;
  final double width;

  const KitchenReceipt({super.key, required this.model, this.width = 560});

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
              _buildOrderMeta(context),
              if (model.kitchenNote != null &&
                  model.kitchenNote!.isNotEmpty) ...[
                const SizedBox(height: 12),
                ReceiptSection(
                  heading: 'Kitchen Note',
                  child: ReceiptNoteBox(model.kitchenNote!),
                ),
              ],
              const SizedBox(height: 12),
              const ReceiptDivider(),
              const SizedBox(height: 12),
              _buildItems(context),
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
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
        if (model.orderType != null) ...[
          const SizedBox(height: 6),
          Text(
            model.orderType!.toUpperCase(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Order #${model.orderNumber}',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  Widget _buildOrderMeta(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (model.customerName != null)
          _infoRow('Customer', model.customerName!, context),
        if (model.phone != null) _infoRow('Phone', model.phone!, context),
        _infoRow('Placed at', _formatDate(model.placedAt), context),
        if (model.requiredAt != null)
          _infoRow('Due at', _formatDate(model.requiredAt!), context),
      ],
    );
  }

  Widget _buildItems(BuildContext context) {
    return ReceiptSection(
      heading: 'Items',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: model.items
            .map(
              (item) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildItem(context, item),
                  const SizedBox(height: 10),
                  const ReceiptDivider(),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildItem(BuildContext context, ReceiptItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${item.quantity} × ${item.name}',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (item.variants.isNotEmpty || item.addons.isNotEmpty) ...[
          const SizedBox(height: 8),
          ReceiptItemDetails(details: [...item.variants, ...item.addons]),
        ],
        if (item.notes != null && item.notes!.isNotEmpty) ...[
          const SizedBox(height: 8),
          ReceiptDecoratedCard(
            child: Text(
              item.notes!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Kitchen Copy',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Printed: ${_formatDate(DateTime.now())}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.black54),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              '$label :',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
