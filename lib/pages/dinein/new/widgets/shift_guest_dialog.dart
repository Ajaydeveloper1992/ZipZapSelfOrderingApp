import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/models/cart_item_model.dart';

/// Dialog for shifting selected items from one guest to another
class ShiftGuestDialog extends StatefulWidget {
  final String currentGuestGroup; // e.g., 'whole_table', 'guest_1'
  final int partySize; // Number of guests
  final List<CartItem> items; // Items available to shift
  final Function(String targetGuestGroup, Set<String> selectedItemIds)?
  onGuestShifted;

  const ShiftGuestDialog({
    super.key,
    required this.currentGuestGroup,
    required this.partySize,
    required this.items,
    this.onGuestShifted,
  });

  @override
  State<ShiftGuestDialog> createState() => _ShiftGuestDialogState();
}

class _ShiftGuestDialogState extends State<ShiftGuestDialog> {
  String? _selectedGuestGroup;
  final Set<String> _selectedItemIds = {};
  int _currentStep = 0; // 0 = select items, 1 = select guest

  @override
  void initState() {
    super.initState();
    // Pre-select all items by default
    _selectedItemIds.addAll(widget.items.map((item) => item.id));
  }

  /// Get display label for a guest group
  String _getGuestLabel(String guestGroup) {
    if (guestGroup == 'whole_table') {
      return 'Whole Table';
    }
    // Extract guest number from 'guest_1', 'guest_2', etc.
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

  /// Build list of available guest groups (excluding current)
  List<String> _getAvailableGuestGroups() {
    final List<String> groups = ['whole_table'];
    for (int i = 1; i <= widget.partySize; i++) {
      groups.add('guest_$i');
    }
    // Exclude current guest group
    return groups.where((g) => g != widget.currentGuestGroup).toList();
  }

  void _handleShiftGuest() {
    if (_selectedGuestGroup == null || _selectedItemIds.isEmpty) return;
    widget.onGuestShifted?.call(_selectedGuestGroup!, _selectedItemIds);
    Navigator.of(context).pop(true);
  }

  void _toggleItemSelection(String itemId) {
    setState(() {
      if (_selectedItemIds.contains(itemId)) {
        _selectedItemIds.remove(itemId);
      } else {
        _selectedItemIds.add(itemId);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedItemIds.length == widget.items.length) {
        _selectedItemIds.clear();
      } else {
        _selectedItemIds.clear();
        _selectedItemIds.addAll(widget.items.map((item) => item.id));
      }
    });
  }

  Widget _buildItemSelectionStep() {
    final allSelected = _selectedItemIds.length == widget.items.length;

    return Column(
      children: [
        // Select all toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: InkWell(
            onTap: _toggleSelectAll,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                children: [
                  Checkbox(
                    value: allSelected,
                    tristate: true,
                    onChanged: (_) => _toggleSelectAll(),
                    activeColor: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    allSelected ? 'Deselect All' : 'Select All',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_selectedItemIds.length}/${widget.items.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        // Items list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: widget.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = widget.items[index];
              final isSelected = _selectedItemIds.contains(item.id);

              return InkWell(
                onTap: () => _toggleItemSelection(item.id),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
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
                        onChanged: (_) => _toggleItemSelection(item.id),
                        activeColor: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 8),
                      // Item details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.product.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (item.itemNote.isNotEmpty)
                              Text(
                                item.itemNote,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Quantity badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'x${item.quantity}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGuestSelectionStep() {
    final availableGroups = _getAvailableGuestGroups();

    if (availableGroups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                'No other guests available',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.all(12),
      itemCount: availableGroups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final guestGroup = availableGroups[index];
        final isSelected = _selectedGuestGroup == guestGroup;

        return InkWell(
          onTap: () {
            setState(() {
              _selectedGuestGroup = guestGroup;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // Guest icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getGuestIcon(guestGroup),
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),

                // Guest label
                Expanded(
                  child: Text(
                    _getGuestLabel(guestGroup),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                // Selection indicator
                if (isSelected)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    ),
                  )
                else
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final availableGroups = _getAvailableGuestGroups();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 450, maxHeight: 600),
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
                    Icons.swap_horiz_rounded,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentStep == 0 ? 'Select Items' : 'Select Guest',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _currentStep == 0
                              ? 'Choose items to shift'
                              : 'Move ${_selectedItemIds.length} item(s) to:',
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

            // Step indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  _buildStepIndicator(0, 'Items'),
                  Expanded(
                    child: Container(
                      height: 2,
                      color: _currentStep >= 1
                          ? Theme.of(context).primaryColor
                          : Colors.grey.shade300,
                    ),
                  ),
                  _buildStepIndicator(1, 'Guest'),
                ],
              ),
            ),

            // Content
            Flexible(
              child: _currentStep == 0
                  ? _buildItemSelectionStep()
                  : _buildGuestSelectionStep(),
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
                      onPressed: () {
                        if (_currentStep == 0) {
                          Navigator.of(context).pop();
                        } else {
                          setState(() {
                            _currentStep = 0;
                          });
                        }
                      },
                      child: Text(_currentStep == 0 ? 'Cancel' : 'Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _currentStep == 0
                          ? (_selectedItemIds.isNotEmpty &&
                                    availableGroups.isNotEmpty
                                ? () => setState(() => _currentStep = 1)
                                : null)
                          : (_selectedGuestGroup != null
                                ? _handleShiftGuest
                                : null),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        _currentStep == 0
                            ? 'Next (${_selectedItemIds.length} selected)'
                            : (_selectedGuestGroup != null
                                  ? 'Move to ${_getGuestLabel(_selectedGuestGroup!)}'
                                  : 'Select a Guest'),
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

  Widget _buildStepIndicator(int step, String label) {
    final isActive = _currentStep >= step;
    final isCurrent = _currentStep == step;

    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isActive
                ? Theme.of(context).primaryColor
                : Colors.grey.shade300,
            shape: BoxShape.circle,
            border: isCurrent
                ? Border.all(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.3),
                    width: 3,
                  )
                : null,
          ),
          child: Center(
            child: Text(
              '${step + 1}',
              style: TextStyle(
                color: isActive ? Colors.white : Colors.grey.shade600,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isActive
                ? Theme.of(context).primaryColor
                : Colors.grey.shade600,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
