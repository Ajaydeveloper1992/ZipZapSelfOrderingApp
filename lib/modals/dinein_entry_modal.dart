import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zipzap_pos_self_orders/models/customer_model.dart';
import 'package:zipzap_pos_self_orders/models/floor_plan_model.dart';
import 'package:zipzap_pos_self_orders/services/floor_plans_service.dart';

String? validateDineInEntry({
  required String tableNumber,
  required String guestCount,
  required String customerName,
}) {
  if (tableNumber.trim().isEmpty) {
    return 'Please enter a table number';
  }

  if (guestCount.trim().isEmpty) {
    return 'Please enter guest count';
  }

  final parsedGuests = int.tryParse(guestCount.trim());
  if (parsedGuests == null || parsedGuests <= 0) {
    return 'Guest count must be a valid number';
  }

  if (customerName.trim().isEmpty) {
    return 'Please enter customer name';
  }

  return null;
}

class DineInEntryModal extends StatefulWidget {
  final Future<void> Function(
    Map<String, dynamic> tableInfo,
    int partySize,
    Customer customer,
  )
  onConfirm;

  const DineInEntryModal({super.key, required this.onConfirm});

  @override
  State<DineInEntryModal> createState() => _DineInEntryModalState();
}

class _DineInEntryModalState extends State<DineInEntryModal> {
  final TextEditingController _tableController = TextEditingController();
  final TextEditingController _guestController = TextEditingController();
  final TextEditingController _customerController = TextEditingController();
  final FloorPlansService _floorPlansService = FloorPlansService();

  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _tableController.dispose();
    _guestController.dispose();
    _customerController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    final tableNumber = _tableController.text.trim();
    final guestCount = _guestController.text.trim();
    final customerName = _customerController.text.trim();

    final validationError = validateDineInEntry(
      tableNumber: tableNumber,
      guestCount: guestCount,
      customerName: customerName,
    );

    if (validationError != null) {
      setState(() {
        _errorText = validationError;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final response = await _floorPlansService.getFloorPlans(
        isActive: true,
        sortBy: 'createdAt',
        sortOrder: 'asc',
      );

      final matchingTable = response.floorPlans.fold<Map<String, dynamic>?>(
        null,
        (currentMatch, floorPlan) {
          if (currentMatch != null) return currentMatch;

          for (final item in floorPlan.items.where(
            (entry) => entry.type.isTable,
          )) {
            final itemName = item.name.trim().toLowerCase();
            final lookupName = tableNumber.toLowerCase();

            if (itemName == lookupName ||
                itemName.contains(lookupName) ||
                lookupName.contains(itemName)) {
              if (item.status == TableStatus.occupied) {
                throw Exception('Table ${item.name} is already occupied.');
              }
              if (item.status == TableStatus.reserved) {
                throw Exception(
                  'Table ${item.name} is reserved and unavailable.',
                );
              }
              return {
                'floorPlanId': floorPlan.id,
                'floorPlanName': floorPlan.name,
                'tableId': item.id,
                'tableName': item.name,
              };
            }
          }

          return null;
        },
      );

      if (matchingTable == null) {
        throw Exception('Table number not found in floor plan data');
      }

      final partySize = int.parse(guestCount);
      final customer = Customer(id: '', firstName: customerName);

      await widget.onConfirm(
        {
          'tableId': matchingTable['tableId'],
          'tableName': matchingTable['tableName'],
          'floorPlanId': matchingTable['floorPlanId'],
          'floorPlanName': matchingTable['floorPlanName'],
          'partySize': partySize,
        },
        partySize,
        customer,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      title: const Text('Start Dine-In Order'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the table details below to start a new dine-in order.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tableController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Table Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.table_restaurant),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _guestController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Guest Count',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.people),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _customerController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Customer Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              onSubmitted: (_) => _handleConfirm(),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorText!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final useVertical = constraints.maxWidth < 380;
                final cancelButton = TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                );
                final continueButton = FilledButton.icon(
                  onPressed: _isSubmitting ? null : _handleConfirm,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.arrow_forward),
                  label: Text(_isSubmitting ? 'Checking...' : 'Continue'),
                );

                if (useVertical) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      cancelButton,
                      const SizedBox(height: 12),
                      continueButton,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: cancelButton),
                    const SizedBox(width: 12),
                    Expanded(child: continueButton),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      actions: [],
    );
  }
}
