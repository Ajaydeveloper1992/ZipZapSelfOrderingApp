import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/models/floor_plan_model.dart';
import 'package:zipzap_pos_self_orders/services/floor_plans_service.dart';
import 'package:zipzap_pos_self_orders/widgets/app_toast.dart';

/// Dialog for shifting an order to a different table
class ShiftTableDialog extends StatefulWidget {
  final String orderId;
  final String? currentTableId;
  final String? currentTableName;
  final int? currentPartySize; // Preserve party size when shifting tables
  final Function(FloorItem newTable, FloorPlan floorPlan)? onTableShifted;

  const ShiftTableDialog({
    super.key,
    required this.orderId,
    this.currentTableId,
    this.currentTableName,
    this.currentPartySize,
    this.onTableShifted,
  });

  @override
  State<ShiftTableDialog> createState() => _ShiftTableDialogState();
}

class _ShiftTableDialogState extends State<ShiftTableDialog> {
  final FloorPlansService _floorPlansService = FloorPlansService();
  List<FloorPlan> _floorPlans = [];
  bool _isLoading = true;
  bool _isShifting = false;
  int _selectedFloorIndex = 0;
  FloorItem? _selectedTable;

  @override
  void initState() {
    super.initState();
    _loadFloorPlans();
  }

  Future<void> _loadFloorPlans() async {
    try {
      final response = await _floorPlansService.getFloorPlans(
        isActive: true,
        sortBy: 'createdAt',
        sortOrder: 'asc',
      );
      setState(() {
        _floorPlans = response.floorPlans;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        AppToast.error(
          context: context,
          title: 'Error',
          description: 'Failed to load floor plans',
        );
      }
    }
  }

  Future<void> _handleShiftTable() async {
    if (_selectedTable == null || _floorPlans.isEmpty) return;

    setState(() {
      _isShifting = true;
    });

    try {
      final floorPlan = _floorPlans[_selectedFloorIndex];

      await _floorPlansService.shiftOrderTable(
        orderId: widget.orderId,
        tableId: _selectedTable!.id,
        tableName: _selectedTable!.name,
        floorPlanId: floorPlan.id,
        partySize: widget.currentPartySize, // Preserve original party size
      );

      if (mounted) {
        AppToast.success(
          context: context,
          title: 'Table Changed',
          description: 'Order moved to ${_selectedTable!.name}',
        );
        widget.onTableShifted?.call(_selectedTable!, floorPlan);
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context: context,
          title: 'Error',
          description: e.toString().replaceAll('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isShifting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
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
                        const Text(
                          'Change Table',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.currentTableName != null)
                          Text(
                            'Current: ${widget.currentTableName}',
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
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _floorPlans.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.table_restaurant_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No floor plans available',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Floor plan selector
                        if (_floorPlans.length > 1)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: SizedBox(
                              width: double.infinity,
                              child: CupertinoSlidingSegmentedControl<int>(
                                groupValue: _selectedFloorIndex,
                                children: {
                                  for (int i = 0; i < _floorPlans.length; i++)
                                    i: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      child: Text(
                                        _floorPlans[i].name,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                },
                                onValueChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedFloorIndex = value;
                                      _selectedTable = null;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),

                        // Tables list
                        Expanded(child: _buildTablesList()),
                      ],
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
                      onPressed: _isShifting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _selectedTable != null && !_isShifting
                          ? _handleShiftTable
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      child: _isShifting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _selectedTable != null
                                  ? 'Move to ${_selectedTable!.name}'
                                  : 'Select a Table',
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

  Widget _buildTablesList() {
    if (_floorPlans.isEmpty) return const SizedBox.shrink();

    final floorPlan = _floorPlans[_selectedFloorIndex];
    final availableTables = floorPlan.items
        .where(
          (item) =>
              item.type.isTable &&
              item.status == TableStatus.available &&
              item.id != widget.currentTableId,
        )
        .toList();

    if (availableTables.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_busy_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'No available tables',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'All tables are currently reserved',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: availableTables.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final table = availableTables[index];
        final isSelected = _selectedTable?.id == table.id;

        return InkWell(
          onTap: () {
            setState(() {
              _selectedTable = table;
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
                // Table icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.table_restaurant_rounded,
                    color: Color(0xFF10B981),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),

                // Table info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        table.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${table.seats ?? 0} seats • ${_getTableTypeLabel(table.type)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
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

  String _getTableTypeLabel(FloorItemType type) {
    switch (type) {
      case FloorItemType.rectangular:
        return 'Rectangle';
      case FloorItemType.square:
        return 'Square';
      case FloorItemType.circular:
        return 'Round';
      case FloorItemType.barStool:
        return 'Bar Stool';
      default:
        return 'Table';
    }
  }
}
