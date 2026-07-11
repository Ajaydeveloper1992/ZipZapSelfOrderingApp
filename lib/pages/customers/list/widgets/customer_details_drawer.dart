import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:zipzap_pos_self_orders/models/customer_model.dart';
import 'package:zipzap_pos_self_orders/widgets/app_toast.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerDetailsDrawer extends StatefulWidget {
  final Customer customer;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const CustomerDetailsDrawer({
    super.key,
    required this.customer,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<CustomerDetailsDrawer> createState() => _CustomerDetailsDrawerState();
}

class _CustomerDetailsDrawerState extends State<CustomerDetailsDrawer> {
  bool _isCustomerInfoExpanded = true;
  bool _isOrderHistoryExpanded = true;
  bool _isNotesExpanded = false;

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('MMM dd, yyyy').format(date);
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('MMM dd, yyyy, h:mm a').format(date);
  }

  Future<void> _handleCall() async {
    if (widget.customer.phone == null || widget.customer.phone!.isEmpty) {
      if (mounted) {
        AppToast.warning(
          context: context,
          title: 'No Phone Number',
          description: 'This customer has no phone number on file.',
        );
      }
      return;
    }

    final uri = Uri.parse('tel:${widget.customer.phone}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          AppToast.error(
            context: context,
            title: 'Cannot Call',
            description: 'Unable to open phone dialer.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context: context,
          title: 'Error',
          description: 'Failed to initiate call: $e',
        );
      }
    }
  }

  Future<void> _handleSMS() async {
    if (widget.customer.phone == null || widget.customer.phone!.isEmpty) {
      if (mounted) {
        AppToast.warning(
          context: context,
          title: 'No Phone Number',
          description: 'This customer has no phone number on file.',
        );
      }
      return;
    }

    final uri = Uri.parse('sms:${widget.customer.phone}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          AppToast.error(
            context: context,
            title: 'Cannot Send SMS',
            description: 'Unable to open messaging app.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context: context,
          title: 'Error',
          description: 'Failed to open SMS: $e',
        );
      }
    }
  }

  Future<void> _handleEmail() async {
    if (widget.customer.email == null || widget.customer.email!.isEmpty) {
      if (mounted) {
        AppToast.warning(
          context: context,
          title: 'No Email',
          description: 'This customer has no email on file.',
        );
      }
      return;
    }

    final uri = Uri.parse('mailto:${widget.customer.email}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          AppToast.error(
            context: context,
            title: 'Cannot Send Email',
            description: 'Unable to open email app.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context: context,
          title: 'Error',
          description: 'Failed to open email: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    double drawerWidth;
    if (screenWidth < 600) {
      drawerWidth = screenWidth * 0.9;
    } else if (screenWidth < 1024) {
      drawerWidth = screenWidth * 0.6;
    } else {
      drawerWidth = screenWidth * 0.35;
    }

    return Drawer(
      width: drawerWidth,
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context),
            // Content
            Expanded(
              child: Container(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats Row
                      _buildStatsRow(context),
                      const SizedBox(height: 8),
                      // Customer Info
                      _buildCustomExpansionTile(
                        context,
                        title: Text(
                          'Customer Information',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        isExpanded: _isCustomerInfoExpanded,
                        onExpansionChanged: (value) {
                          setState(() {
                            _isCustomerInfoExpanded = value;
                          });
                        },
                        child: _buildCustomerInfoContent(context),
                      ),
                      Divider(
                        height: 1,
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.2),
                      ),
                      // Order History
                      _buildCustomExpansionTile(
                        context,
                        title: Text(
                          'Order History (${widget.customer.ordersCount})',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        isExpanded: _isOrderHistoryExpanded,
                        onExpansionChanged: (value) {
                          setState(() {
                            _isOrderHistoryExpanded = value;
                          });
                        },
                        child: _buildOrderHistoryContent(context),
                      ),
                      Divider(
                        height: 1,
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.2),
                      ),
                      // Notes
                      if (widget.customer.note != null &&
                          widget.customer.note!.isNotEmpty)
                        _buildCustomExpansionTile(
                          context,
                          title: Text(
                            'Notes',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          isExpanded: _isNotesExpanded,
                          onExpansionChanged: (value) {
                            setState(() {
                              _isNotesExpanded = value;
                            });
                          },
                          child: _buildNotesContent(context),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // Footer Actions
            _buildFooterActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.1),
            child: Text(
              widget.customer.fullName.isNotEmpty
                  ? widget.customer.fullName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name and status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.customer.fullName.isNotEmpty
                      ? widget.customer.fullName
                      : 'Unknown Customer',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                _buildStatusBadge(context),
              ],
            ),
          ),
          // Close button
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    final isReturning = widget.customer.isReturning;
    final color = isReturning ? Colors.green : Colors.orange;
    final icon = isReturning ? Icons.repeat : Icons.person_add;
    final text = isReturning ? 'Returning Customer' : 'New Customer';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, top: 6),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              context,
              'Total Orders',
              '${widget.customer.ordersCount}',
              Icons.shopping_bag_outlined,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              context,
              'Total Spent',
              '\$${widget.customer.totalSpent.toStringAsFixed(2)}',
              Icons.attach_money,
              isHighlight: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              context,
              'Avg Order',
              widget.customer.ordersCount > 0
                  ? '\$${(widget.customer.totalSpent / widget.customer.ordersCount).toStringAsFixed(2)}'
                  : '\$0.00',
              Icons.analytics_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    bool isHighlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isHighlight
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: isHighlight
            ? Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.3),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: isHighlight
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isHighlight
                  ? Theme.of(context).colorScheme.primary
                  : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfoContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      child: Column(
        children: [
          // Phone and Email row
          Row(
            children: [
              Expanded(
                child: _buildInfoRow(
                  context,
                  Icons.phone_outlined,
                  'Phone',
                  widget.customer.phone ?? 'N/A',
                  onTap: widget.customer.phone != null ? _handleCall : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoRow(
                  context,
                  Icons.email_outlined,
                  'Email',
                  widget.customer.email ?? 'N/A',
                  onTap: widget.customer.email != null ? _handleEmail : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Address
          _buildInfoRow(
            context,
            Icons.location_on_outlined,
            'Address',
            widget.customer.address?.fullAddress ?? 'N/A',
          ),
          const SizedBox(height: 12),
          // Created and Updated dates
          Row(
            children: [
              Expanded(
                child: _buildInfoRow(
                  context,
                  Icons.calendar_today_outlined,
                  'Customer Since',
                  _formatDate(widget.customer.createdAt),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoRow(
                  context,
                  Icons.update_outlined,
                  'Last Updated',
                  _formatDate(widget.customer.updatedAt),
                ),
              ),
            ],
          ),
          if (widget.customer.createdBy != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              context,
              Icons.person_outline,
              'Created By',
              '${widget.customer.createdBy!.firstName} ${widget.customer.createdBy!.lastName}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: onTap != null
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    decoration: onTap != null ? TextDecoration.underline : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderHistoryContent(BuildContext context) {
    final orders = widget.customer.orders;

    if (orders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.shopping_bag_outlined,
                size: 32,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 8),
              Text(
                'No orders yet',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      child: Column(
        children: orders.take(10).map((order) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                // Status indicator
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _getOrderStatusColor(order.orderstatus),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                // Order details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.orderstatus,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getOrderStatusColor(order.orderstatus),
                        ),
                      ),
                      Text(
                        _formatDateTime(order.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Total
                Text(
                  '\$${order.total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getOrderStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'complete':
      case 'completed':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'inkitchen':
        return Colors.blue;
      case 'cancelled':
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildNotesContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.yellow.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.yellow.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.note_outlined, size: 16, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.customer.note ?? '',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomExpansionTile(
    BuildContext context, {
    required Widget title,
    required bool isExpanded,
    required ValueChanged<bool> onExpansionChanged,
    required Widget child,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: () => onExpansionChanged(!isExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(child: title),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    CupertinoIcons.chevron_down,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: ClipRect(child: isExpanded ? child : const SizedBox.shrink()),
        ),
      ],
    );
  }

  Widget _buildFooterActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quick Actions Row
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _handleCall,
                  icon: const Icon(Icons.phone, size: 16),
                  label: const Text('Call'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _handleSMS,
                  icon: const Icon(Icons.sms, size: 16),
                  label: const Text('SMS'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _handleEmail,
                  icon: const Icon(Icons.email, size: 16),
                  label: const Text('Email'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Edit and Delete Row
          Row(
            children: [
              if (widget.onDelete != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onDelete?.call();
                    },
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              if (widget.onDelete != null && widget.onEdit != null)
                const SizedBox(width: 8),
              if (widget.onEdit != null)
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onEdit?.call();
                    },
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit Customer'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
