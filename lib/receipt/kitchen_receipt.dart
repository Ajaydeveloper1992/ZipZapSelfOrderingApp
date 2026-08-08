import 'package:flutter/material.dart';
import 'models/receipt_models.dart';
import 'shared/receipt_widgets.dart';

class KitchenReceipt extends StatelessWidget {
  final ReceiptModel model;
  final double width;

  const KitchenReceipt({super.key, required this.model, this.width = 576});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      color: Colors.white,
      child: Material(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              const SizedBox(height: 14),
              _buildOrderMeta(context),
              if (model.kitchenNote != null &&
                  model.kitchenNote!.isNotEmpty) ...[
                const SizedBox(height: 18),
                ReceiptSection(
                  heading: 'Kitchen Note',
                  padding: EdgeInsets.zero,
                  child: ReceiptNoteBox(model.kitchenNote!),
                ),
              ],
              const SizedBox(height: 24),
              const ReceiptDivider(),
              const SizedBox(height: 14),
              _buildItems(context),
              const SizedBox(height: 8),
              const ReceiptDivider(),
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
            color: Colors.black,
          ),
        ),
        if (model.orderType != null) ...[
          const SizedBox(height: 6),
          Text(
            model.orderType!.toUpperCase(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Order #${model.orderNumber}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: Colors.black,
          ),
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
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < model.items.length; i++) ...[
            _buildItem(context, model.items[i]),
            if (i != model.items.length - 1) ...[
              const SizedBox(height: 14),
              const ReceiptDivider(),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, ReceiptItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${item.quantity} \u00d7 ${item.name}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        if (item.variants.isNotEmpty || item.addons.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildItemDetails(context, [...item.variants, ...item.addons]),
        ],
        if (item.notes != null && item.notes!.isNotEmpty) ...[
          const SizedBox(height: 12),
          ReceiptDecoratedCard(
            child: Text(
              item.notes!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.black87),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildItemDetails(BuildContext context, List<String> details) {
    if (details.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: details.map((detail) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              '\u2022 $detail',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.black87),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _infoRow(String label, String value, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label :',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.black87),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.black),
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
