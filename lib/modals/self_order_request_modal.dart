import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/models/order_model.dart';
import 'package:zipzap_pos_self_orders/models/self_order_request_model.dart';
import 'package:zipzap_pos_self_orders/services/self_order_request_service.dart';
import 'package:zipzap_pos_self_orders/widgets/app_toast.dart';

class SelfOrderRequestModal extends StatefulWidget {
  final Order order;
  final Function(SelfOrderRequest)? onRequestCreated;
  final String? storeId;

  const SelfOrderRequestModal({
    super.key,
    required this.order,
    this.onRequestCreated,
    this.storeId,
  });

  @override
  State<SelfOrderRequestModal> createState() => _SelfOrderRequestModalState();
}

class _SelfOrderRequestModalState extends State<SelfOrderRequestModal> {
  // Predefined request options
  static const List<String> _predefinedNeeds = [
    'Cutlery',
    'Water',
    'Napkins',
    'Sauce',
    'Condiments',
    'Straws',
    'Plates',
    'Utensils',
    'Toothpicks',
    'Wet Wipes',
  ];

  late Set<String> _selectedNeeds;
  late TextEditingController _customRequestController;
  bool _hasOtherRequest = false;
  bool _isSubmitting = false;
  final SelfOrderRequestService _requestService = SelfOrderRequestService();

  @override
  void initState() {
    super.initState();
    _selectedNeeds = {};
    _customRequestController = TextEditingController();
  }

  @override
  void dispose() {
    _customRequestController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    // Validation
    if (_selectedNeeds.isEmpty && !_hasOtherRequest) {
      _showError('Please select at least one option or add a custom request');
      return;
    }

    if (_hasOtherRequest && _customRequestController.text.trim().isEmpty) {
      _showError('Please enter your custom request');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final tableInfo = widget.order.tableInfo;

      final request = SelfOrderRequest(
        orderNumber: widget.order.orderNumber,
        tableNumber: tableInfo?.tableName ?? 'Unknown',
        store: widget.storeId ?? '',
        selectedNeeds: _selectedNeeds.toList(),
        other: _hasOtherRequest,
        customRequest: _hasOtherRequest
            ? _customRequestController.text.trim()
            : '',
        customerName: widget.order.customerName,
        phone: widget.order.phone ?? '',
      );

      final createdRequest = await _requestService.createRequest(request);

      if (!mounted) return;

      setState(() => _isSubmitting = false);

      // Close modal and notify parent
      Navigator.of(context).pop();
      widget.onRequestCreated?.call(createdRequest);

      // Show success toast
      _showSuccess('Request sent to staff!');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showError('Failed to send request: ${e.toString()}');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade600,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.notifications_active,
                        color: Theme.of(context).primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Request Assistance',
                            style:
                                Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.bold) ??
                                const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            'Order #${widget.order.orderNumber}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(Icons.close, color: Colors.grey.shade400),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Instructions
                Text(
                  'What do you need?',
                  style:
                      Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ) ??
                      TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                ),
                const SizedBox(height: 12),

                // Predefined options grid
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _predefinedNeeds.map((need) {
                    final isSelected = _selectedNeeds.contains(need);
                    return FilterChip(
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedNeeds.add(need);
                          } else {
                            _selectedNeeds.remove(need);
                          }
                        });
                      },
                      label: Text(
                        need,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : Colors.grey.shade700,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                      backgroundColor: Colors.grey.shade200,
                      selectedColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      side: BorderSide.none,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Other/Custom request section
                Material(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: _hasOtherRequest,
                              onChanged: (value) {
                                setState(
                                  () => _hasOtherRequest = value ?? false,
                                );
                                if (value ?? false) {
                                  _customRequestController.clear();
                                }
                              },
                              activeColor: Theme.of(context).primaryColor,
                            ),
                            Text(
                              'Other request',
                              style:
                                  Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w500) ??
                                  const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ],
                        ),
                        if (_hasOtherRequest) ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: _customRequestController,
                            maxLines: 3,
                            maxLength: 200,
                            decoration: InputDecoration(
                              hintText:
                                  'Tell us what you need... (e.g., Extra sauce, special utensils, etc.)',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 13,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Theme.of(context).primaryColor,
                                  width: 2,
                                ),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.all(12),
                            ),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(
                            color: Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.3),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitRequest,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: Theme.of(context).primaryColor,
                          disabledBackgroundColor: Colors.grey.shade300,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isSubmitting
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                              )
                            : const Text(
                                'Send Request ',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
