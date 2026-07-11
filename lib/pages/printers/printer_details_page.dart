import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/models/available_printer_model.dart';
import 'package:zipzap_pos_self_orders/models/printer_model.dart';
import 'package:zipzap_pos_self_orders/models/printer_label_model.dart';
import 'package:zipzap_pos_self_orders/pages/printers/widgets/printer_labels_list.dart';
import 'package:zipzap_pos_self_orders/services/printer_service.dart';
import 'package:zipzap_pos_self_orders/services/labels_service.dart';
import 'package:zipzap_pos_self_orders/widgets/warning_dialog.dart';
import 'package:uuid/uuid.dart';
import 'package:zipzap_pos_self_orders/widgets/app_toast.dart';

class PrinterDetailsPage extends StatefulWidget {
  final AvailablePrinter? availablePrinter;
  final Printer? existingPrinter;
  final PrinterGroup group;

  const PrinterDetailsPage({
    super.key,
    this.availablePrinter,
    this.existingPrinter,
    required this.group,
  });

  @override
  State<PrinterDetailsPage> createState() => _PrinterDetailsPageState();
}

class _PrinterDetailsPageState extends State<PrinterDetailsPage> {
  late TextEditingController _nameController;
  late String _connectionInfo;
  late List<PrinterLabel> _labels;
  bool _isLoadingLabels = true;
  String? _labelsError;

  final LabelsService _labelsService = LabelsService();

  bool get _isEditing => widget.existingPrinter != null;

  @override
  void initState() {
    super.initState();
    String initialName = '';
    if (widget.existingPrinter != null) {
      initialName = widget.existingPrinter!.name;
      _connectionInfo = _getConnectionInfo(widget.existingPrinter!);
    } else if (widget.availablePrinter != null) {
      initialName = widget.availablePrinter!.name;
      _connectionInfo = _getAvailableConnectionInfo(widget.availablePrinter!);
    } else {
      _connectionInfo = '';
    }
    _nameController = TextEditingController(text: initialName);
    _loadLabels();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadLabels() async {
    setState(() {
      _isLoadingLabels = true;
      _labelsError = null;
    });

    try {
      final response = await _labelsService.getLabels();
      final savedLabelIds = widget.existingPrinter?.selectedLabels ?? [];

      setState(() {
        _labels = response.labels.map((label) {
          return label.copyWith(isSelected: savedLabelIds.contains(label.id));
        }).toList();
        _isLoadingLabels = false;
      });
    } catch (e) {
      debugPrint('Error loading labels: $e');
      setState(() {
        _labels = [];
        _labelsError = 'Failed to load labels: $e';
        _isLoadingLabels = false;
      });

      if (mounted) {
        AppToast.error(
          context: context,
          title: 'Error Loading Labels',
          description: 'Unable to fetch labels from server',
        );
      }
    }
  }

  String _getConnectionInfo(Printer printer) {
    switch (printer.type) {
      case PrinterType.lan:
        return 'LAN - ${printer.identifier}';
      case PrinterType.usb:
        return 'USB - ${printer.identifier}';
      case PrinterType.bluetooth:
        return 'Bluetooth - ${printer.identifier}';
      case PrinterType.wifi:
        return 'WiFi - ${printer.identifier}';
    }
  }

  String _getAvailableConnectionInfo(AvailablePrinter printer) {
    if (printer.type == PrinterType.lan && printer.ipAddress != null) {
      return 'LAN - ${printer.ipAddress}';
    }
    switch (printer.type) {
      case PrinterType.lan:
        return 'LAN';
      case PrinterType.usb:
        return printer.port != null ? 'USB - ${printer.port}' : 'USB';
      case PrinterType.bluetooth:
        return 'Bluetooth';
      case PrinterType.wifi:
        return 'WiFi';
    }
  }

  void _handleLabelChanged(PrinterLabel label, bool value) {
    setState(() {
      _labels = _labels.map((l) {
        if (l.id == label.id) {
          return l.copyWith(isSelected: value);
        }
        return l;
      }).toList();
    });
  }

  Future<void> _handlePrintTest() async {
    String? identifier;
    String? interfaceType;

    if (widget.existingPrinter != null) {
      identifier = widget.existingPrinter!.identifier;
      interfaceType = _printerTypeToString(widget.existingPrinter!.type);
    } else if (widget.availablePrinter != null) {
      identifier = widget.availablePrinter!.id;
      interfaceType = _printerTypeToString(widget.availablePrinter!.type);
    }

    if (identifier == null || interfaceType == null) {
      AppToast.error(
        context: context,
        title: 'Connection Error',
        description: 'Unable to get printer connection info',
      );
      return;
    }

    try {
      final success = await PrinterService.printTest(
        interfaceType: interfaceType,
        identifier: identifier,
      );

      if (mounted) {
        if (success) {
          AppToast.success(
            context: context,
            title: 'Print Test Successful',
            description: 'Print test sent successfully',
          );
        } else {
          AppToast.error(
            context: context,
            title: 'Print Test Failed',
            description: 'Print test failed',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context: context,
          title: 'Print Error',
          description: 'Error: $e',
        );
      }
    }
  }

  Future<void> _handleSave() async {
    if (_nameController.text.trim().isEmpty) {
      AppToast.warning(
        context: context,
        title: 'Name Required',
        description: 'Please enter a printer name',
      );
      return;
    }

    final selectedLabelIds = _labels
        .where((l) => l.isSelected)
        .map((l) => l.id)
        .toList();

    try {
      if (_isEditing && widget.existingPrinter != null) {
        // Update existing printer
        final updatedPrinter = widget.existingPrinter!.copyWith(
          name: _nameController.text.trim(),
          selectedLabels: selectedLabelIds,
        );
        await PrinterService.updatePrinter(updatedPrinter);
      } else if (widget.availablePrinter != null) {
        // Save new printer - try to get additional information for LAN printers
        String? modelName;
        String? ipAddress;

        if (widget.availablePrinter!.type == PrinterType.lan) {
          try {
            final interfaceType = _printerTypeToString(
              widget.availablePrinter!.type,
            );
            final info = await PrinterService.getPrinterInformation(
              interfaceType: interfaceType,
              identifier: widget.availablePrinter!.id,
            );
            if (info != null) {
              modelName = info['modelName'] as String?;
              ipAddress =
                  info['ipAddress'] as String? ?? widget.availablePrinter!.id;
            } else {
              ipAddress = widget.availablePrinter!.id; // Use identifier as IP
            }
          } catch (e) {
            debugPrint('Error getting printer information: $e');
            ipAddress = widget.availablePrinter!.id; // Fallback to identifier
          }
        } else if (widget.availablePrinter!.ipAddress != null) {
          ipAddress = widget.availablePrinter!.ipAddress;
        }

        final newPrinter = Printer(
          id: const Uuid().v4(),
          name: _nameController.text.trim(),
          type: widget.availablePrinter!.type,
          status: PrinterStatus.online,
          group: widget.group,
          identifier: widget.availablePrinter!.id,
          selectedLabels: selectedLabelIds,
          modelName: modelName,
          ipAddress: ipAddress,
        );
        await PrinterService.savePrinter(newPrinter);
      }

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context: context,
          title: 'Save Error',
          description: 'Error saving printer: $e',
        );
      }
    }
  }

  String _printerTypeToString(PrinterType type) {
    switch (type) {
      case PrinterType.lan:
        return 'Lan';
      case PrinterType.usb:
        return 'Usb';
      case PrinterType.bluetooth:
        return 'Bluetooth';
      case PrinterType.wifi:
        return 'Lan'; // WiFi uses LAN interface
    }
  }

  void _handleCancel() {
    Navigator.of(context).pop();
  }

  Future<void> _handleDelete() async {
    if (!_isEditing || widget.existingPrinter == null) {
      return;
    }

    // Show confirmation dialog
    final confirmed = await WarningDialog.show(
      context: context,
      title: 'Delete Printer',
      message:
          'Are you sure you want to delete "${widget.existingPrinter!.name}"?',
      infoMessage: 'This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      type: WarningDialogType.error,
      barrierDismissible: false,
    );

    if (confirmed != true) {
      return;
    }

    try {
      await PrinterService.deletePrinter(widget.existingPrinter!.id);

      if (mounted) {
        AppToast.success(
          context: context,
          title: 'Printer Deleted',
          description:
              'Printer "${widget.existingPrinter!.name}" deleted successfully',
        );
        Navigator.of(context).pop(true); // Return true to indicate deletion
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context: context,
          title: 'Delete Error',
          description: 'Error deleting printer: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        shadowColor: Colors.grey.shade300,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.close_sharp),
          onPressed: _handleCancel,
        ),
        title: Text(
          _isEditing ? 'Edit Printer' : 'Add Printer',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        actions: [
          Row(
            children: [
              // Delete button (only show when editing)
              if (_isEditing)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _handleDelete,
                  tooltip: 'Delete Printer',
                  color: Theme.of(context).colorScheme.error,
                ),
              const Text('SYNCING'),
              IconButton(
                icon: const Icon(Icons.sync),
                onPressed: () {},
                tooltip: 'Refresh',
              ),
            ],
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Printer Image and Name Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Printer Image
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                                  Theme.of(context).colorScheme.primaryContainer
                                      .withValues(alpha: 0.7),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.print_rounded,
                              size: 48,
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 20),
                          // Printer Name and Connection Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  autofocus: true,
                                  controller: _nameController,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    border: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline
                                            .withValues(alpha: 0.7),
                                      ),
                                    ),
                                    enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline
                                            .withValues(alpha: 0.7),
                                      ),
                                    ),
                                    focusedBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Connection Info
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .secondaryContainer
                                        .withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.link_rounded,
                                        size: 16,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _connectionInfo,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Print Test Button Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _handlePrintTest,
                          icon: const Icon(Icons.print_rounded, size: 20),
                          label: const Text(
                            'Print Test',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Labels List Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: _isLoadingLabels
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : _labelsError != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: 48,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Failed to load labels',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.error,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextButton.icon(
                                      onPressed: _loadLabels,
                                      icon: const Icon(Icons.refresh, size: 18),
                                      label: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : PrinterLabelsList(
                              labels: _labels,
                              onLabelChanged: _handleLabelChanged,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Divider
          Container(
            width: 1,
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          ),
          // Right Column - Actions
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _handleSave,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        _isEditing ? 'Update' : 'Save',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _handleCancel,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
