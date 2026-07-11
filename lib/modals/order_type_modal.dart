import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/core/constants/api_constants.dart';

class ServicesOffered {
  final bool pickUp;
  final bool delivery;
  final bool dineIn;

  ServicesOffered({
    required this.pickUp,
    required this.delivery,
    required this.dineIn,
  });

  factory ServicesOffered.fromJson(Map<String, dynamic> json) {
    return ServicesOffered(
      pickUp: json['pickUp'] as bool? ?? false,
      delivery: json['delivery'] as bool? ?? false,
      dineIn: json['dineIn'] as bool? ?? false,
    );
  }
}

class OrderTypeModal extends StatelessWidget {
  final ServicesOffered? services;
  final Function(String orderType) onOrderTypeSelected;
  final VoidCallback onCancel;

  const OrderTypeModal({
    super.key,
    this.services,
    required this.onOrderTypeSelected,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;
    final modalWidth = isSmallScreen ? screenWidth * 0.9 : 450.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: modalWidth,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildContent(context),
              ),
            ),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.receipt_long,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Select Order Type',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 24),
            onPressed: onCancel,
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.error.withValues(alpha: 0.1),
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final showPickUp = services?.pickUp ?? true;
    final showDelivery = services?.delivery ?? true;

    final List<Widget> children = [];

    if (showPickUp) {
      children.add(
        _OrderTypeButton(
          title: 'Takeout',
          description: 'Customer picks up the order',
          icon: Icons.shopping_bag,
          iconColor: Colors.blue,
          backgroundColor: Colors.blue.shade50,
          hoverColor: Colors.blue.shade100,
          onTap: () => onOrderTypeSelected(ApiConstants.uiOrderTypeTakeout),
        ),
      );
    }

    if (showDelivery) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: 12));
      }
      children.add(
        _OrderTypeButton(
          title: 'Delivery',
          description: 'Order will be delivered to customer',
          icon: Icons.local_shipping,
          iconColor: Colors.green,
          backgroundColor: Colors.green.shade50,
          hoverColor: Colors.green.shade100,
          onTap: () => onOrderTypeSelected(ApiConstants.uiOrderTypeDelivery),
        ),
      );
    }

    if (children.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No order types available',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Column(mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onCancel,
          icon: const Icon(Icons.close, size: 20),
          label: const Text('Cancel'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            side: BorderSide(
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderTypeButton extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color hoverColor;
  final VoidCallback onTap;

  const _OrderTypeButton({
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.hoverColor,
    required this.onTap,
  });

  @override
  State<_OrderTypeButton> createState() => _OrderTypeButtonState();
}

class _OrderTypeButtonState extends State<_OrderTypeButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isHovered
                  ? widget.backgroundColor.withValues(alpha: 0.5)
                  : Colors.white,
              border: Border.all(
                color: _isHovered
                    ? widget.iconColor.withValues(alpha: 0.5)
                    : Colors.grey.shade200,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _isHovered
                        ? widget.hoverColor
                        : widget.backgroundColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(widget.icon, size: 24, color: widget.iconColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: _isHovered
                                  ? widget.iconColor
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 13,
                          color: _isHovered
                              ? widget.iconColor.withValues(alpha: 0.8)
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  transform: Matrix4.translationValues(
                    _isHovered ? 4 : 0,
                    0,
                    0,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 18,
                    color: _isHovered ? widget.iconColor : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
