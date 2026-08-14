import 'package:flutter/material.dart';
import 'models/receipt_models.dart';

class KitchenReceipt extends StatelessWidget {
  final ReceiptModel model;
  final double width;
  static const String _receiptFont = 'sans-serif-condensed';

  const KitchenReceipt({super.key, required this.model, this.width = 576});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      color: Colors.white,
      child: Material(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              const SizedBox(height: 22),
              const _KitchenRule(thickness: 3),
              const SizedBox(height: 22),
              _buildItems(context),
              const SizedBox(height: 20),
              const _KitchenRule(thickness: 3),
              const SizedBox(height: 14),
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
        if (model.orderType != null) ...[
          const SizedBox(height: 10),
          Text(
            model.orderType!.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: _receiptFont,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              height: 1.05,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          _customerOrderLine,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: _receiptFont,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: Colors.black,
            height: 1.05,
          ),
        ),
        if (_tablePartyLines.isNotEmpty) ...[
          const SizedBox(height: 10),
          ..._tablePartyLines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _InvertedKitchenLine(
                text: line.text,
                fontSize: 24,
                fontWeight: line.bold ? FontWeight.w900 : FontWeight.w800,
              ),
            ),
          ),
        ],
        if (_returningCustomerLine.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            _returningCustomerLine,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: _receiptFont,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              height: 1.15,
            ),
          ),
        ],
        if (model.phone != null && model.phone!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'Phone: ${model.phone!}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: _receiptFont,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              height: 1.15,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOrderNote(BuildContext context, String note) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(
        'Order Note: $note',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: _receiptFont,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Colors.black,
          height: 1.2,
        ),
      ),
    );
  }

  Widget _buildItems(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < model.items.length; i++) ...[
          _buildItem(context, model.items[i]),
          if (i != model.items.length - 1) ...[
            const SizedBox(height: 18),
            const _DottedRule(),
            const SizedBox(height: 18),
          ],
        ],
      ],
    );
  }

  Widget _buildItem(BuildContext context, ReceiptItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${item.quantity} * ${item.name}',
          style: const TextStyle(
            fontFamily: _receiptFont,
            fontSize: 38,
            fontWeight: FontWeight.w900,
            color: Colors.black,
            height: 1.08,
          ),
        ),
        if (item.variants.isNotEmpty || item.addons.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildItemDetails(context, [...item.variants, ...item.addons]),
        ],
        if (item.notes != null && item.notes!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _InvertedKitchenLine(
            text: _noteText(item.notes!),
            fontSize: 28,
            fontWeight: FontWeight.w900,
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
          final parts = _splitModifier(detail);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '\u2022 ',
                  style: TextStyle(
                    fontFamily: _receiptFont,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                    height: 1.2,
                  ),
                ),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontFamily: _receiptFont,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                        height: 1.2,
                      ),
                      children: [
                        TextSpan(
                          text: parts.$1,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        if (parts.$2.isNotEmpty) TextSpan(text: parts.$2),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (_orderNote.isNotEmpty) ...[
          _buildOrderNote(context, _orderNote),
          const SizedBox(height: 14),
        ],
        _footerLine('Placed at:', _formatDate(model.placedAt)),
        if (model.requiredAt != null) ...[
          const SizedBox(height: 6),
          _footerLine('Due at:', _formatDate(model.requiredAt!)),
        ],
      ],
    );
  }

  Widget _footerLine(String label, String value) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          fontFamily: _receiptFont,
          fontSize: 24,
          color: Colors.black,
          height: 1.2,
        ),
        children: [
          TextSpan(text: '$label '),
          TextSpan(text: value),
        ],
      ),
    );
  }

  String get _orderNote => (model.kitchenNote ?? model.orderNote ?? '').trim();

  String get _customerOrderLine {
    final customerName = model.customerName?.trim() ?? '';
    if (customerName.isEmpty) return 'Order #${model.orderNumber}';
    return '$customerName - ${model.orderNumber}';
  }

  List<({bool bold, String text})> get _tablePartyLines {
    final lines = <({bool bold, String text})>[];
    final tableNumber = model.tableNumber?.trim() ?? '';
    if (tableNumber.isNotEmpty) {
      lines.add((bold: true, text: tableNumber));
    }
    final partySize = model.partySize;
    if (partySize != null && partySize > 0) {
      lines.add((bold: false, text: 'Party of $partySize'));
    }
    return lines;
  }

  String get _returningCustomerLine {
    final cashier = model.cashier?.trim() ?? '';
    if (cashier.startsWith('Returning Customer')) return cashier;
    return '';
  }

  String _noteText(String note) {
    final trimmed = note.trim();
    if (trimmed.toLowerCase().startsWith('order note:')) {
      return 'Item Note: ${trimmed.substring('order note:'.length).trim()}';
    }
    if (trimmed.toLowerCase().startsWith('item note:')) {
      return 'Item Note: ${trimmed.substring('item note:'.length).trim()}';
    }
    return 'Item Note: $trimmed';
  }

  (String, String) _splitModifier(String detail) {
    final index = detail.indexOf(':');
    if (index == -1) return (detail, '');
    return (detail.substring(0, index + 1), detail.substring(index + 1));
  }

  String _formatDate(DateTime date) {
    const months = [
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
    final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${months[date.month - 1]} ${date.day}, ${hour12.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} $period';
  }
}

class _KitchenRule extends StatelessWidget {
  final double thickness;

  const _KitchenRule({required this.thickness});

  @override
  Widget build(BuildContext context) {
    return Container(height: thickness, color: Colors.black38);
  }
}

class _InvertedKitchenLine extends StatelessWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;

  const _InvertedKitchenLine({
    required this.text,
    required this.fontSize,
    required this.fontWeight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: KitchenReceipt._receiptFont,
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: Colors.white,
          height: 1.05,
        ),
      ),
    );
  }
}

class _DottedRule extends StatelessWidget {
  const _DottedRule();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 5.0;
        const gapWidth = 5.0;
        final dashCount = (constraints.maxWidth / (dashWidth + gapWidth))
            .floor();
        return Row(
          children: List.generate(
            dashCount,
            (_) => Container(
              width: dashWidth,
              height: 2,
              margin: const EdgeInsets.only(right: gapWidth),
              color: Colors.black38,
            ),
          ),
        );
      },
    );
  }
}
