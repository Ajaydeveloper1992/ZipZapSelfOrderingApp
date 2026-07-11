import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zipzap_pos_self_orders/models/printer_model.dart';
import 'package:zipzap_pos_self_orders/models/available_printer_model.dart';
import 'package:zipzap_pos_self_orders/pages/printers/widgets/available_printers_list.dart';
import 'package:zipzap_pos_self_orders/pages/printers/printer_details_page.dart';
import 'package:zipzap_pos_self_orders/services/printer_service.dart';
import 'package:zipzap_pos_self_orders/widgets/app_toast.dart';
import 'package:zipzap_pos_self_orders/pages/printers/widgets/printer_constants.dart';

class AddPrinterPage extends StatefulWidget {
  final PrinterGroup group;

  const AddPrinterPage({super.key, required this.group});

  @override
  State<AddPrinterPage> createState() => _AddPrinterPageState();
}

class _AddPrinterPageState extends State<AddPrinterPage> {
  List<AvailablePrinter> _availablePrinters = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAvailablePrinters();
  }

  Future<void> _loadAvailablePrinters() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check if Bluetooth is in the interface types and request permissions if needed
      final interfaceTypes = ['Lan', 'Bluetooth', 'Usb'];
      final needsBluetooth = interfaceTypes.contains('Bluetooth');

      if (needsBluetooth) {
        final hasPermission = await PrinterService.checkBluetoothPermissions();
        if (!hasPermission) {
          // Request permissions
          final granted = await PrinterService.requestBluetoothPermissions();
          if (!granted) {
            setState(() {
              _isLoading = false;
            });
            if (mounted) {
              AppToast.warning(
                context: context,
                title: 'Bluetooth Permission Required',
                description:
                    'Bluetooth permissions are required to discover Bluetooth printers. Please grant permissions in settings.',
                autoCloseDuration: const Duration(seconds: 5),
              );
            }
            return;
          }
        }
      }

      final printers = await PrinterService.discoverPrinters();
      setState(() {
        _availablePrinters = printers;
        _isLoading = false;
      });

      if (mounted && printers.isEmpty) {
        AppToast.info(
          context: context,
          title: 'No Printers Found',
          description:
              'No printers found. Make sure printers are powered on and connected.',
        );
      }
    } on PlatformException catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        String errorMessage = 'Error discovering printers';
        if (e.code == 'PERMISSION_ERROR') {
          errorMessage =
              'Bluetooth permission required. Please grant permission in settings.';
        } else if (e.code == 'DISCOVERY_ERROR') {
          errorMessage = 'Discovery failed: ${e.message ?? 'Unknown error'}';
        } else {
          errorMessage = 'Error: ${e.message ?? e.code}';
        }
        AppToast.error(
          context: context,
          title: 'Discovery Error',
          description: errorMessage,
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        AppToast.error(
          context: context,
          title: 'Discovery Error',
          description: 'Error discovering printers: $e',
        );
      }
    }
  }

  void _handleRefresh() {
    _loadAvailablePrinters();
  }

  void _handlePrinterTap(AvailablePrinter printer) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => PrinterDetailsPage(
              availablePrinter: printer,
              group: widget.group,
            ),
          ),
        )
        .then((saved) {
          // Forward the result back to the previous page (PrintersPage)
          if (saved == true) {
            Navigator.of(context).pop(true);
          }
        });
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
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          'Add ${widget.group.label}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _handleRefresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : AvailablePrintersList(
              printers: _availablePrinters,
              onPrinterTap: _handlePrinterTap,
            ),
    );
  }
}
