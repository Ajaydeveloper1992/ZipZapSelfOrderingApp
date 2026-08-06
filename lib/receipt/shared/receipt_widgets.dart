import 'package:flutter/material.dart';

class ReceiptSection extends StatelessWidget {
  final Widget child;
  final String? heading;
  final EdgeInsetsGeometry padding;

  const ReceiptSection({
    super.key,
    required this.child,
    this.heading,
    this.padding = const EdgeInsets.symmetric(vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (heading != null) ...[
            Text(
              heading!,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}

class ReceiptDivider extends StatelessWidget {
  final double thickness;

  const ReceiptDivider({super.key, this.thickness = 1});

  @override
  Widget build(BuildContext context) {
    return Divider(
      thickness: thickness,
      color: Colors.grey.shade300,
      height: 24,
    );
  }
}

class ReceiptLabelValueRow extends StatelessWidget {
  final String label;
  final String value;
  final bool valueBold;

  const ReceiptLabelValueRow({
    super.key,
    required this.label,
    required this.value,
    this.valueBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: Colors.black54);
    final valueStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: valueBold ? FontWeight.w700 : FontWeight.w500,
      color: Colors.black87,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: labelStyle)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value, style: valueStyle, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class ReceiptNoteBox extends StatelessWidget {
  final String note;

  const ReceiptNoteBox(this.note, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(12),
      child: Text(
        note,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: Colors.black87),
      ),
    );
  }
}

class ReceiptSubtitle extends StatelessWidget {
  final String text;

  const ReceiptSubtitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: Colors.black54),
    );
  }
}

class ReceiptSectionHeading extends StatelessWidget {
  final String title;

  const ReceiptSectionHeading(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),
    );
  }
}

class ReceiptSubtext extends StatelessWidget {
  final String text;

  const ReceiptSubtext(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: Colors.black54, height: 1.4),
    );
  }
}

class ReceiptDecoratedCard extends StatelessWidget {
  final Widget child;

  const ReceiptDecoratedCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class ReceiptLogoPlaceholder extends StatelessWidget {
  final double size;

  const ReceiptLogoPlaceholder({super.key, this.size = 60});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: Icon(
        Icons.restaurant,
        color: Colors.grey.shade600,
        size: size * 0.55,
      ),
    );
  }
}

class ReceiptQrPlaceholder extends StatelessWidget {
  final double size;

  const ReceiptQrPlaceholder({super.key, this.size = 90});

  @override
  Widget build(BuildContext context) {
    return Container(
      /* width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          'QR ',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: Colors.grey.shade600),
        ),
      ),
      */
    );
  }
}

class ReceiptValueRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const ReceiptValueRow({
    super.key,
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = isTotal
        ? Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.black54),
            ),
          ),
          const SizedBox(width: 12),
          Text(value, style: textStyle),
        ],
      ),
    );
  }
}

class ReceiptItemDetails extends StatelessWidget {
  final List<String> details;

  const ReceiptItemDetails({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    if (details.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: details.map((detail) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: Theme.of(context).textTheme.bodySmall),
                Expanded(
                  child: Text(
                    detail,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class ReceiptSectionTitle extends StatelessWidget {
  final String title;

  const ReceiptSectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class ReceiptFooterText extends StatelessWidget {
  final String primary;
  final String? secondary;

  const ReceiptFooterText(this.primary, {super.key, this.secondary});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          primary,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (secondary != null) ...[
          const SizedBox(height: 4),
          Text(
            secondary!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.black54),
          ),
        ],
      ],
    );
  }
}
