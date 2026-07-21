import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zipzap_pos_self_orders/core/services/auth_service.dart';
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

  // Optional initial values (per-staff defaults)
  final String? initialTableNumber;
  final String? initialGuestCount;
  final String? initialCustomerName;

  const DineInEntryModal({
    super.key,
    required this.onConfirm,
    this.initialTableNumber,
    this.initialGuestCount,
    this.initialCustomerName,
  });

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
  String? _assignedTableName;
  late int _guestCount;

  static const Color _primaryTeal = Color(0xFF006B5F);
  static const Color _lightTealBg = Color(0xFFD8F0ED);
  @override
  void dispose() {
    _tableController.dispose();
    _guestController.dispose();
    _customerController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Apply any initial values passed from caller
    if (widget.initialTableNumber != null) {
      _tableController.text = widget.initialTableNumber!;
      _assignedTableName = widget.initialTableNumber;
    }
    if (widget.initialGuestCount != null) {
      _guestController.text = widget.initialGuestCount!;
      _guestCount = int.tryParse(widget.initialGuestCount!) ?? 1;
    } else {
      _guestCount = 1;
    }
    if (widget.initialCustomerName != null) {
      _customerController.text = widget.initialCustomerName!;
    }
  }

  void _updateGuestCount(int value) {
    if (value > 0) {
      setState(() {
        _guestCount = value;
        _guestController.text = value.toString();
      });
    }
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
      // Save last-used values to preferences for the logged-in staff
      try {
        final prefs = await SharedPreferences.getInstance();
        // Try to store per-user if profile available
        try {
          final authService = AuthService();
          final username = authService.getProfile()?.username;
          if (username != null && username.isNotEmpty) {
            await prefs.setString('last_table_number_$username', tableNumber);
            await prefs.setString('last_guest_count_$username', guestCount);
            await prefs.setString('last_customer_name_$username', customerName);
          } else {
            await prefs.setString('last_table_number', tableNumber);
            await prefs.setString('last_guest_count', guestCount);
            await prefs.setString('last_customer_name', customerName);
          }
        } catch (_) {
          // fallback to generic keys
          await prefs.setString('last_table_number', tableNumber);
          await prefs.setString('last_guest_count', guestCount);
          await prefs.setString('last_customer_name', customerName);
        }
      } catch (_) {
        // ignore prefs errors
      }
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
    final authService = AuthService();
    final profile = authService.getProfile();
    final staffName = profile?.username ?? 'Staff';
    final staffEmail = profile?.email ?? 'admin@promehedi.com';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Order Now Details Ajay',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if (_assignedTableName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _assignedTableName!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.close,
                        color: Colors.red.shade700,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Guest Count - Large Container
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 28,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: _lightTealBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300, width: 1.5),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _guestCount > 1
                              ? () => _updateGuestCount(_guestCount - 1)
                              : null,
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.remove,
                              color: _guestCount > 1
                                  ? _primaryTeal
                                  : Colors.grey.shade300,
                              size: 26,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                        Text(
                          _guestCount.toString(),
                          style: const TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.bold,
                            color: _primaryTeal,
                          ),
                        ),
                        const SizedBox(width: 48),
                        GestureDetector(
                          onTap: () => _updateGuestCount(_guestCount + 1),
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.add,
                              color: _primaryTeal,
                              size: 26,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Guest',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Server
              const Text(
                'Server',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _lightTealBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          staffName.substring(0, 2).toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _primaryTeal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            staffName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            staffEmail,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Customer Name
              TextField(
                controller: _customerController,
                decoration: InputDecoration(
                  hintText: 'Customer Name',
                  prefixIcon: const Icon(Icons.person, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _primaryTeal, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
              ),

              if (_errorText != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red.shade700,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorText!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red.shade400, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(
                        Icons.close,
                        color: Colors.red.shade600,
                        size: 18,
                      ),
                      label: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.red.shade600,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isSubmitting ? null : _handleConfirm,
                      style: FilledButton.styleFrom(
                        backgroundColor: _primaryTeal,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: Text(
                        _isSubmitting ? 'Confirming...' : 'Confirm Order',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
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
    );
  }
}
