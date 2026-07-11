import 'package:flutter/material.dart';

class PayCardForm extends StatefulWidget {
  final double remainingAmount;
  final Function(double) onPay;
  final String cardType;
  final Function(String) onCardTypeChanged;

  const PayCardForm({
    super.key,
    required this.remainingAmount,
    required this.onPay,
    required this.cardType,
    required this.onCardTypeChanged,
  });

  @override
  State<PayCardForm> createState() => _PayCardFormState();
}

class _PayCardFormState extends State<PayCardForm> {
  final List<Map<String, dynamic>> _cardTypes = [
    {
      'name': 'Visa',
      'icon': Icons.credit_card,
      'color': const Color(0xFF1A1F71),
      'gradient': [Color(0xFF1A1F71), Color(0xFF1434CB)],
    },
    {
      'name': 'Mastercard',
      'icon': Icons.credit_card,
      'color': const Color(0xFFEB001B),
      'gradient': [Color(0xFFEB001B), Color(0xFFF79E1B)],
    },
    {
      'name': 'Debit',
      'icon': Icons.account_balance,
      'color': const Color(0xFF6B46C1),
      'gradient': [Color(0xFF6B46C1), Color(0xFF9333EA)],
    },
    {
      'name': 'Amex',
      'icon': Icons.credit_card,
      'color': const Color(0xFF006FCF),
      'gradient': [Color(0xFF006FCF), Color(0xFF012169)],
    },
    {
      'name': 'Discover',
      'icon': Icons.credit_card,
      'color': const Color(0xFFFF6000),
      'gradient': [Color(0xFFFF6000), Color(0xFFFF8C00)],
    },
    {
      'name': 'Diners',
      'icon': Icons.credit_card,
      'color': const Color(0xFF0079BE),
      'gradient': [Color(0xFF0079BE), Color(0xFF005A9E)],
    },
    {
      'name': 'JCB',
      'icon': Icons.credit_card,
      'color': const Color(0xFF0066CC),
      'gradient': [Color(0xFF0066CC), Color(0xFF003D7A)],
    },
    {
      'name': 'Other',
      'icon': Icons.credit_card,
      'color': const Color(0xFF000000),
      'gradient': [Color(0xFF000000), Color(0xFF000000)],
    },
  ];

  Widget _buildCardTypeCard(Map<String, dynamic> cardData) {
    final isSelected = widget.cardType == cardData['name'];
    final colors = cardData['gradient'] as List<Color>;

    return InkWell(
      onTap: () => widget.onCardTypeChanged(cardData['name']),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isSelected
                ? colors
                : [Colors.grey.shade200, Colors.grey.shade300],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colors.first : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colors.first.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                cardData['icon'] as IconData,
                size: 32,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
              const SizedBox(height: 8),
              Text(
                cardData['name'] as String,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 300),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Card type selector
            Text(
              'Select Card Type',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Card grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
              ),
              itemCount: _cardTypes.length,
              itemBuilder: (context, index) {
                return _buildCardTypeCard(_cardTypes[index]);
              },
            ),
          ],
        ),
      ),
    );
  }
}
