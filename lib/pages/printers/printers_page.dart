import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/models/printer_model.dart';
import 'package:zipzap_pos_self_orders/pages/printers/widgets/printers_list.dart';
import 'package:zipzap_pos_self_orders/pages/printers/widgets/add_printer_dialog.dart';
import 'package:zipzap_pos_self_orders/pages/printers/add_printer_page.dart';
import 'package:zipzap_pos_self_orders/pages/printers/printer_details_page.dart';
import 'package:zipzap_pos_self_orders/services/printer_service.dart';

class PrintersPage extends StatefulWidget {
  const PrintersPage({super.key});

  @override
  State<PrintersPage> createState() => _PrintersPageState();
}

class _PrintersPageState extends State<PrintersPage> {
  List<Printer> _printers = [];

  @override
  void initState() {
    super.initState();
    _loadPrinters();
  }

  Future<void> _loadPrinters({bool checkStatus = false}) async {
    try {
      final printers = await PrinterService.getSavedPrinters();
      debugPrint('Loaded ${printers.length} printers from storage');

      // Always set the printers list first
      setState(() {
        _printers = printers;
      });

      // Only check status if explicitly requested (e.g., on manual refresh)
      // Don't check status automatically to avoid marking printers offline incorrectly
      if (checkStatus && printers.isNotEmpty) {
        // Update status for each printer in the background (non-blocking)
        // Use timeout to prevent hanging if printer is unreachable
        final updatedPrinters = await Future.wait(
          printers.map(
            (printer) => _updatePrinterStatus(printer).timeout(
              const Duration(seconds: 3),
              onTimeout: () {
                debugPrint(
                  'Status check timeout for printer: ${printer.name} - keeping existing status',
                );
                // Don't change status on timeout - keep existing status
                return printer;
              },
            ),
          ),
          eagerError: false, // Don't fail all if one fails
        );

        // Update the list with status information if we got it
        if (mounted) {
          setState(() {
            _printers = updatedPrinters;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading printers: $e');
      // Even on error, try to show what we have
      try {
        final printers = await PrinterService.getSavedPrinters();
        if (mounted) {
          setState(() {
            _printers = printers;
          });
        }
      } catch (e2) {
        debugPrint('Error loading printers fallback: $e2');
      }
    }
  }

  Future<Printer> _updatePrinterStatus(Printer printer) async {
    try {
      final interfaceType = _printerTypeToString(printer.type);
      final status = await PrinterService.getPrinterStatus(
        interfaceType: interfaceType,
        identifier: printer.identifier,
      );

      if (status != null) {
        final hasError = status['hasError'] == true;
        final paperEmpty = status['paperEmpty'] == true;
        final coverOpen = status['coverOpen'] == true;

        final newStatus = hasError || paperEmpty || coverOpen
            ? PrinterStatus.error
            : PrinterStatus.online;
        debugPrint(
          'Printer ${printer.name} status: $newStatus (hasError: $hasError, paperEmpty: $paperEmpty, coverOpen: $coverOpen)',
        );
        return printer.copyWith(status: newStatus);
      } else {
        debugPrint(
          'No status returned for printer: ${printer.name} - keeping existing status',
        );
        // Don't change status if we can't get it - keep existing status
        return printer;
      }
    } catch (e) {
      debugPrint(
        'Error checking printer status for ${printer.name}: $e - keeping existing status',
      );
      // Don't change status on error - keep existing status to avoid false offline
      return printer;
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

  Future<void> _handleRefresh() async {
    // Only check status on manual refresh
    await _loadPrinters(checkStatus: true);
  }

  void _handleNewPrinter() {
    showDialog(
      context: context,
      builder: (context) => AddPrinterDialog(
        onGroupSelected: (group) {
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (context) => AddPrinterPage(group: group),
                ),
              )
              .then((saved) {
                if (saved == true) {
                  _loadPrinters();
                }
              });
        },
      ),
    );
  }

  void _handlePrinterTap(Printer printer) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => PrinterDetailsPage(
              existingPrinter: printer,
              group: printer.group,
            ),
          ),
        )
        .then((updated) {
          if (updated == true) {
            _loadPrinters();
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _handleNewPrinter,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(100)),
        ),
        tooltip: 'Add Printer',
        child: const Icon(Icons.add, size: 24),
      ),
      appBar: AppBar(
        backgroundColor: Colors.white,
        shadowColor: Colors.grey.shade300,
        elevation: 1,
        title: const Text(
          'Printer Settings',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _handleRefresh,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _handleNewPrinter,
            tooltip: 'Add Printer',
          ),
        ],
      ),
      body: PrintersList(printers: _printers, onPrinterTap: _handlePrinterTap),
    );
  }
}
