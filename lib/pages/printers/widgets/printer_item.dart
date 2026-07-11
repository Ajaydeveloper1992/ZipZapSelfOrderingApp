import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/models/printer_model.dart';

class PrinterItem extends StatefulWidget {
  final Printer printer;
  final VoidCallback? onTap;

  const PrinterItem({super.key, required this.printer, this.onTap});

  @override
  State<PrinterItem> createState() => _PrinterItemState();
}

class _PrinterItemState extends State<PrinterItem> {
  bool _isExpanded = false;

  String _getTypeLabel(PrinterType type) {
    switch (type) {
      case PrinterType.lan:
        return 'LAN';
      case PrinterType.usb:
        return 'USB';
      case PrinterType.bluetooth:
        return 'Bluetooth';
      case PrinterType.wifi:
        return 'WiFi';
    }
  }

  Color _getStatusColor(PrinterStatus status) {
    switch (status) {
      case PrinterStatus.online:
        return Colors.green;
      case PrinterStatus.offline:
        return Colors.grey;
      case PrinterStatus.error:
        return Colors.red;
    }
  }

  String _getStatusLabel(PrinterStatus status) {
    switch (status) {
      case PrinterStatus.online:
        return 'Online';
      case PrinterStatus.offline:
        return 'Offline';
      case PrinterStatus.error:
        return 'Error';
    }
  }

  String _getLabelName(String labelId) {
    // Map label IDs to names (matching printer_details_page.dart)
    switch (labelId) {
      case '1':
        return 'Receipt 80mm';
      case '2':
        return 'Receipt 58mm';
      case '3':
        return 'Label 4x6';
      case '4':
        return 'Label 3x2';
      case '5':
        return 'A4 Paper';
      default:
        return labelId;
    }
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          color: Colors.black.withValues(alpha: 0.02),
          elevation: 0,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: Icon(
                Icons.print,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                widget.printer.name,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Row(
                children: [
                  Text(
                    _getTypeLabel(widget.printer.type),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(width: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getStatusColor(widget.printer.status),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getStatusLabel(widget.printer.status),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _getStatusColor(widget.printer.status),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.onTap != null)
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: widget.onTap,
                      tooltip: 'Edit Printer',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              onExpansionChanged: (expanded) {
                setState(() {
                  _isExpanded = expanded;
                });
              },
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      _buildInfoRow(context, 'ID', widget.printer.id),
                      _buildInfoRow(
                        context,
                        'Type',
                        _getTypeLabel(widget.printer.type),
                      ),
                      if (widget.printer.type == PrinterType.lan &&
                          widget.printer.ipAddress != null)
                        _buildInfoRow(
                          context,
                          'IP Address',
                          widget.printer.ipAddress!,
                        ),
                      if (widget.printer.modelName != null)
                        _buildInfoRow(
                          context,
                          'Model',
                          widget.printer.modelName!,
                        ),
                      _buildInfoRow(
                        context,
                        'Identifier',
                        widget.printer.identifier,
                      ),
                      _buildInfoRow(
                        context,
                        'Status',
                        _getStatusLabel(widget.printer.status),
                      ),
                      if (widget.printer.selectedLabels.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Selected Labels',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        ...widget.printer.selectedLabels.map(
                          (labelId) => Padding(
                            padding: const EdgeInsets.only(left: 8, top: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.label,
                                  size: 14,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _getLabelName(labelId),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 8),
                        Text(
                          'Selected Labels',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            'No labels selected',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontStyle: FontStyle.italic,
                                  color: Colors.grey.shade600,
                                ),
                          ),
                        ),
                      ],
                    ],
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
