import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/core/services/time_clock_service.dart';

class TransferOrdersDialog extends StatefulWidget {
  final int orderCount;
  final List<StoreStaffMember> staff;

  const TransferOrdersDialog({
    super.key,
    required this.orderCount,
    required this.staff,
  });

  /// Shows the dialog and returns the selected staff member ID, or null if cancelled.
  static Future<String?> show(
    BuildContext context, {
    required int orderCount,
    required List<StoreStaffMember> staff,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) =>
          TransferOrdersDialog(orderCount: orderCount, staff: staff),
    );
  }

  @override
  State<TransferOrdersDialog> createState() => _TransferOrdersDialogState();
}

class _TransferOrdersDialogState extends State<TransferOrdersDialog> {
  String? _selectedStaffId;

  void _handleConfirm() {
    if (_selectedStaffId == null) return;
    Navigator.of(context).pop(_selectedStaffId);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 450, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            Flexible(
              child: widget.staff.isEmpty
                  ? _buildEmptyState()
                  : _buildStaffList(context),
            ),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.swap_horiz_rounded, color: Colors.orange.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Transfer Orders',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Move ${widget.orderCount} active order(s) to another staff',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
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
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No other staff available',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffList(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.all(12),
      itemCount: widget.staff.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final member = widget.staff[index];
        final isSelected = _selectedStaffId == member.id;

        return InkWell(
          onTap: () => setState(() => _selectedStaffId = member.id),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
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
                _buildAvatar(member, context),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.fullName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (member.username != null)
                        Text(
                          '@${member.username}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                ),
                _buildClockBadge(member),
                const SizedBox(width: 8),
                _buildSelectionIndicator(isSelected, context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatar(StoreStaffMember member, BuildContext context) {
    final initials = member.firstName.isNotEmpty
        ? member.firstName[0].toUpperCase() +
              (member.lastName != null && member.lastName!.isNotEmpty
                  ? member.lastName![0].toUpperCase()
                  : '')
        : '?';

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildClockBadge(StoreStaffMember member) {
    if (member.clockStatus == null) return const SizedBox.shrink();

    final isOnBreak = member.clockStatus == 'on_break';
    final color = isOnBreak ? Colors.amber : Colors.green;
    final label = isOnBreak ? 'Break' : 'Active';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color.shade600,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionIndicator(bool isSelected, BuildContext context) {
    if (isSelected) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 16, color: Colors.white),
      );
    }

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, width: 2),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final selectedMember = _selectedStaffId != null
        ? widget.staff.where((s) => s.id == _selectedStaffId).firstOrNull
        : null;

    return Container(
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
            child: ElevatedButton(
              onPressed: _selectedStaffId != null ? _handleConfirm : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              child: Text(
                selectedMember != null
                    ? 'Transfer to ${selectedMember.fullName}'
                    : 'Select a Staff',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
