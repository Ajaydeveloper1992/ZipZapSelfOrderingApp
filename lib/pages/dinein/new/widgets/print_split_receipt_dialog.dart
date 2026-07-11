import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/models/cart_item_model.dart';

/// Result returned from the dialog containing selected print targets
class PrintSplitReceiptResult {
  final Set<String> selectedGuestGroups; // e.g., {'whole_table', 'guest_1'}

  PrintSplitReceiptResult({required this.selectedGuestGroups});
}

/// Dialog for selecting guests to print separate receipts
class PrintSplitReceiptDialog extends StatefulWidget {
  final int partySize; // Number of guests
  final List<CartItem> items; // All cart items
  final String? currentTableName; // Current table name
  final Function(PrintSplitReceiptResult result)? onPrintSelected;

  const PrintSplitReceiptDialog({
    super.key,
    required this.partySize,
    required this.items,
    this.currentTableName,
    this.onPrintSelected,
  });

  @override
  State<PrintSplitReceiptDialog> createState() =>
      _PrintSplitReceiptDialogState();
}

class _PrintSplitReceiptDialogState extends State<PrintSplitReceiptDialog> {
  // Guest group selection (multi-select)
  final Set<String> _selectedGuestGroups = {};

  // Track which guest groups have items
  late Map<String, int> _guestGroupItemCounts;

  @override
  void initState() {
    super.initState();
    _calculateGuestGroupItemCounts();
  }

  void _calculateGuestGroupItemCounts() {
    _guestGroupItemCounts = {};
    for (final item in widget.items) {
      if (item.itemStatus == 'Voided') continue;
      final group = item.guestGroup;
      _guestGroupItemCounts[group] =
          (_guestGroupItemCounts[group] ?? 0) + item.quantity;
    }
  }

  /// Get display label for a guest group
  String _getGuestLabel(String guestGroup) {
    if (guestGroup == 'whole_table') {
      return 'Whole Table';
    }
    final parts = guestGroup.split('_');
    if (parts.length == 2) {
      return 'Guest ${parts[1]}';
    }
    return guestGroup;
  }

  /// Get icon for a guest group
  IconData _getGuestIcon(String guestGroup) {
    if (guestGroup == 'whole_table') {
      return Icons.table_restaurant;
    }
    return Icons.person;
  }

  /// Build list of all guest groups
  List<String> _getAllGuestGroups() {
    final List<String> groups = ['whole_table'];
    for (int i = 1; i <= widget.partySize; i++) {
      groups.add('guest_$i');
    }
    return groups;
  }

  void _toggleGuestGroupSelection(String guestGroup) {
    setState(() {
      if (_selectedGuestGroups.contains(guestGroup)) {
        _selectedGuestGroups.remove(guestGroup);
      } else {
        _selectedGuestGroups.add(guestGroup);
      }
    });
  }

  void _handlePrint() {
    if (_selectedGuestGroups.isEmpty) return;

    final result = PrintSplitReceiptResult(
      selectedGuestGroups: _selectedGuestGroups,
    );

    widget.onPrintSelected?.call(result);
    Navigator.of(context).pop(true);
  }

  Widget _buildGuestGroupsSection() {
    final groups = _getAllGuestGroups();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.people,
                size: 18,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Print by Guest',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              if (widget.currentTableName != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.currentTableName!,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ],
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: groups.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (context, index) {
            final guestGroup = groups[index];
            final itemCount = _guestGroupItemCounts[guestGroup] ?? 0;
            final hasItems = itemCount > 0;
            final isSelected = _selectedGuestGroups.contains(guestGroup);

            return InkWell(
              onTap: hasItems
                  ? () => _toggleGuestGroupSelection(guestGroup)
                  : null,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                      : hasItems
                      ? Colors.white
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade200,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Checkbox
                    Checkbox(
                      value: isSelected,
                      onChanged: hasItems
                          ? (_) => _toggleGuestGroupSelection(guestGroup)
                          : null,
                      activeColor: Theme.of(context).primaryColor,
                    ),
                    // Guest icon
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: hasItems
                            ? Theme.of(
                                context,
                              ).primaryColor.withValues(alpha: 0.1)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getGuestIcon(guestGroup),
                        color: hasItems
                            ? Theme.of(context).primaryColor
                            : Colors.grey.shade400,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Guest label
                    Expanded(
                      child: Text(
                        _getGuestLabel(guestGroup),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: hasItems ? null : Colors.grey.shade400,
                        ),
                      ),
                    ),
                    // Item count badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: hasItems
                            ? Theme.of(
                                context,
                              ).primaryColor.withValues(alpha: 0.1)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$itemCount items',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: hasItems
                              ? Theme.of(context).primaryColor
                              : Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = _selectedGuestGroups.isNotEmpty;
    final totalSelections = _selectedGuestGroups.length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 450, maxHeight: 550),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.receipt_long,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Print Split Receipts',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Select guests to print separately',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _buildGuestGroupsSection(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Footer with action buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: hasSelection ? _handlePrint : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.print, size: 18),
                      label: Text(
                        hasSelection
                            ? 'Print $totalSelections Receipt${totalSelections > 1 ? 's' : ''}'
                            : 'Select to Print',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
