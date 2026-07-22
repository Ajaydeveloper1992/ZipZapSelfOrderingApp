import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/models/order_model.dart';
import 'package:zipzap_pos_self_orders/modals/self_order_request_modal.dart';
import 'package:zipzap_pos_self_orders/providers/data_provider.dart';

class RequestBellButton extends StatefulWidget {
  final Order order;
  final Function(String)? onRequestSent;
  final String? storeId;
  final bool showLabel;
  final EdgeInsets padding;
  final double size;

  const RequestBellButton({
    super.key,
    required this.order,
    this.onRequestSent,
    this.storeId,
    this.showLabel = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 8.0),
    this.size = 20.0,
  });

  @override
  State<RequestBellButton> createState() => _RequestBellButtonState();
}

class _RequestBellButtonState extends State<RequestBellButton> {
  bool _hasUnreadNotifications = false;

  void _showRequestModal() {
    showDialog(
      context: context,
      builder: (context) => SelfOrderRequestModal(
        order: widget.order,
        storeId: widget.storeId ?? DataProvider().store?.id ?? '',
        onRequestCreated: (request) {
          widget.onRequestSent?.call(request.id ?? '');
          if (mounted) {
            setState(() {
              _hasUnreadNotifications = true;
            });
            // Auto-hide notification after 5 seconds
            Future.delayed(const Duration(seconds: 5), () {
              if (mounted) {
                setState(() => _hasUnreadNotifications = false);
              }
            });
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: _showRequestModal,
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.amber.shade300,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.notifications_active,
                    size: widget.size,
                    color: Colors.amber.shade700,
                  ),
                ),
                // Notification badge
                if (_hasUnreadNotifications)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (widget.showLabel) ...[
            const SizedBox(height: 4),
            const Text(
              'Request',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.amber,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
