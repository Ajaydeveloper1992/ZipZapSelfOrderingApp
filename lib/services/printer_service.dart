import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zipzap_pos_self_orders/models/printer_model.dart';
import 'package:zipzap_pos_self_orders/models/available_printer_model.dart';

class PrinterService {
  static const MethodChannel _channel = MethodChannel(
    'com.zipzap/starxpand_printer',
  );
  static const String _storageKey = 'saved_printers';

  // Request Bluetooth permissions
  static Future<bool> requestBluetoothPermissions() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'requestBluetoothPermissions',
      );
      return result ?? false;
    } catch (e) {
      debugPrint('Error requesting Bluetooth permissions: $e');
      return false;
    }
  }

  // Check if Bluetooth permissions are granted
  static Future<bool> checkBluetoothPermissions() async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'checkBluetoothPermissions',
      );
      return result ?? false;
    } catch (e) {
      debugPrint('Error checking Bluetooth permissions: $e');
      return false;
    }
  }

  // Discover available printers
  static Future<List<AvailablePrinter>> discoverPrinters({
    List<String> interfaceTypes = const ['Lan', 'Bluetooth', 'Usb'],
  }) async {
    try {
      final result = await _channel.invokeMethod<List>('discoverPrinters', {
        'interfaceTypes': interfaceTypes,
      });

      if (result == null) {
        debugPrint('Discovery returned null result');
        return [];
      }

      return result.map((printerData) {
        try {
          final data = Map<String, dynamic>.from(printerData);
          return AvailablePrinter(
            id: data['identifier'] as String,
            name: data['modelName'] as String? ?? data['identifier'] as String,
            type: _mapInterfaceTypeToPrinterType(
              data['interfaceType'] as String,
            ),
            ipAddress: data['interfaceType'] == 'Lan'
                ? data['identifier'] as String
                : null,
            port: data['interfaceType'] == 'Usb'
                ? data['identifier'] as String
                : null,
          );
        } catch (e) {
          debugPrint('Error parsing printer data: $e');
          rethrow;
        }
      }).toList();
    } on PlatformException catch (e) {
      debugPrint(
        'Platform error discovering printers: ${e.code} - ${e.message}',
      );
      // Re-throw PlatformException so UI can show specific error messages
      rethrow;
    } catch (e) {
      debugPrint('Error discovering printers: $e');
      // Re-throw other errors as well
      rethrow;
    }
  }

  // Print test page
  static Future<bool> printTest({
    required String interfaceType,
    required String identifier,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('printTest', {
        'interfaceType': interfaceType,
        'identifier': identifier,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('Error printing test: $e');
      return false;
    }
  }

  // Print kitchen order
  static Future<bool> printKitchenOrder({
    required String interfaceType,
    required String identifier,
    required Map<String, dynamic> orderData,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('printKitchenOrder', {
        'interfaceType': interfaceType,
        'identifier': identifier,
        'orderData': orderData,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('Error printing kitchen order: $e');
      return false;
    }
  }

  // Print customer receipt
  static Future<bool> printCustomerReceipt({
    required String interfaceType,
    required String identifier,
    required Map<String, dynamic> orderData,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('printCustomerReceipt', {
        'interfaceType': interfaceType,
        'identifier': identifier,
        'orderData': orderData,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('Error printing customer receipt: $e');
      return false;
    }
  }

  // Print quote
  static Future<bool> printQuote({
    required String interfaceType,
    required String identifier,
    required Map<String, dynamic> orderData,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('printQuote', {
        'interfaceType': interfaceType,
        'identifier': identifier,
        'orderData': orderData,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('Error printing quote: $e');
      return false;
    }
  }

  // Print financial report
  static Future<bool> printReport({
    required String interfaceType,
    required String identifier,
    required Map<String, dynamic> reportData,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('printReport', {
        'interfaceType': interfaceType,
        'identifier': identifier,
        'reportData': reportData,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('Error printing report: $e');
      return false;
    }
  }

  // Print void receipt (kitchen receipt for voided items)
  static Future<bool> printVoidReceipt({
    required String interfaceType,
    required String identifier,
    required Map<String, dynamic> orderData,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('printVoidReceipt', {
        'interfaceType': interfaceType,
        'identifier': identifier,
        'orderData': orderData,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('Error printing void receipt: $e');
      return false;
    }
  }

  // Open cash drawer
  static Future<bool> openCashDrawer({
    required String interfaceType,
    required String identifier,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('openCashDrawer', {
        'interfaceType': interfaceType,
        'identifier': identifier,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('Error opening cash drawer: $e');
      return false;
    }
  }

  // Get printer status
  static Future<Map<String, dynamic>?> getPrinterStatus({
    required String interfaceType,
    required String identifier,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getPrinterStatus',
        {'interfaceType': interfaceType, 'identifier': identifier},
      );
      if (result == null) return null;
      return result.map((key, value) => MapEntry(key.toString(), value));
    } catch (e) {
      debugPrint('Error getting printer status: $e');
      return null;
    }
  }

  // Get printer information (model name, IP address, etc.)
  static Future<Map<String, dynamic>?> getPrinterInformation({
    required String interfaceType,
    required String identifier,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getPrinterInformation',
        {'interfaceType': interfaceType, 'identifier': identifier},
      );
      if (result == null) return null;
      return result.map((key, value) => MapEntry(key.toString(), value));
    } catch (e) {
      debugPrint('Error getting printer information: $e');
      return null;
    }
  }

  // Save printer to localStorage
  static Future<void> savePrinter(Printer printer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final printers = await getSavedPrinters();

      debugPrint(
        'Saving printer: ${printer.name} (ID: ${printer.id}). Current printers count: ${printers.length}',
      );

      // Remove existing printer with same ID if exists
      final removedCount = printers.length;
      printers.removeWhere((p) => p.id == printer.id);
      if (removedCount != printers.length) {
        debugPrint('Removed existing printer with same ID');
      }

      printers.add(printer);
      debugPrint('After adding, printers count: ${printers.length}');

      final jsonList = printers.map((p) => _printerToJson(p)).toList();
      final jsonString = jsonEncode(jsonList);
      debugPrint('JSON string length: ${jsonString.length}');

      final success = await prefs.setString(_storageKey, jsonString);

      if (success) {
        debugPrint(
          'Printer saved successfully: ${printer.name} (ID: ${printer.id})',
        );
        debugPrint('Total printers saved: ${printers.length}');

        // Verify by reading back
        final verifyPrinters = await getSavedPrinters();
        debugPrint(
          'Verification: ${verifyPrinters.length} printers in storage',
        );
      } else {
        debugPrint('Failed to save printer to SharedPreferences');
        throw Exception('Failed to save printer to storage');
      }
    } catch (e) {
      debugPrint('Error saving printer: $e');
      rethrow;
    }
  }

  // Get all saved printers from localStorage
  static Future<List<Printer>> getSavedPrinters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);

      if (jsonString == null || jsonString.isEmpty) {
        debugPrint('No saved printers found in localStorage');
        return [];
      }

      debugPrint(
        'Loading printers from localStorage (${jsonString.length} chars)',
      );
      final jsonList = jsonDecode(jsonString) as List;
      final printers = jsonList.map((json) => _printerFromJson(json)).toList();
      debugPrint('Loaded ${printers.length} printers from localStorage');
      return printers;
    } catch (e) {
      debugPrint('Error loading saved printers: $e');
      return [];
    }
  }

  // Delete printer from localStorage
  static Future<void> deletePrinter(String printerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final printers = await getSavedPrinters();

      final printerToDelete = printers.firstWhere(
        (p) => p.id == printerId,
        orElse: () => throw Exception('Printer not found'),
      );

      printers.removeWhere((p) => p.id == printerId);

      final jsonList = printers.map((p) => _printerToJson(p)).toList();
      final jsonString = jsonEncode(jsonList);
      final success = await prefs.setString(_storageKey, jsonString);

      if (success) {
        debugPrint(
          'Printer deleted successfully: ${printerToDelete.name} (ID: $printerId)',
        );
        debugPrint('Remaining printers: ${printers.length}');
      } else {
        debugPrint('Failed to delete printer from SharedPreferences');
        throw Exception('Failed to delete printer from storage');
      }
    } catch (e) {
      debugPrint('Error deleting printer: $e');
      rethrow;
    }
  }

  // Update printer in localStorage
  static Future<void> updatePrinter(Printer printer) async {
    await savePrinter(printer);
  }

  // Helper: Map interface type string to PrinterType enum
  static PrinterType _mapInterfaceTypeToPrinterType(String interfaceType) {
    switch (interfaceType) {
      case 'Lan':
        return PrinterType.lan;
      case 'Bluetooth':
        return PrinterType.bluetooth;
      case 'Usb':
        return PrinterType.usb;
      default:
        return PrinterType.lan;
    }
  }

  // Helper: Convert Printer to JSON
  static Map<String, dynamic> _printerToJson(Printer printer) {
    return {
      'id': printer.id,
      'name': printer.name,
      'type': printer.type.toString().split('.').last,
      'status': printer.status.toString().split('.').last,
      'group': printer.group.toString().split('.').last,
      'identifier': printer.identifier,
      'selectedLabels': printer.selectedLabels,
      'modelName': printer.modelName,
      'ipAddress': printer.ipAddress,
    };
  }

  // Helper: Create Printer from JSON
  static Printer _printerFromJson(Map<String, dynamic> json) {
    return Printer(
      id: json['id'] as String,
      name: json['name'] as String,
      type: _stringToPrinterType(json['type'] as String),
      status: _stringToPrinterStatus(json['status'] as String),
      group: _stringToPrinterGroup(json['group'] as String),
      identifier: json['identifier'] as String? ?? json['id'] as String,
      selectedLabels:
          (json['selectedLabels'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      modelName: json['modelName'] as String?,
      ipAddress: json['ipAddress'] as String?,
    );
  }

  // Helper: String to PrinterType
  static PrinterType _stringToPrinterType(String type) {
    switch (type) {
      case 'lan':
        return PrinterType.lan;
      case 'usb':
        return PrinterType.usb;
      case 'bluetooth':
        return PrinterType.bluetooth;
      case 'wifi':
        return PrinterType.wifi;
      default:
        return PrinterType.lan;
    }
  }

  // Helper: String to PrinterStatus
  static PrinterStatus _stringToPrinterStatus(String status) {
    switch (status) {
      case 'online':
        return PrinterStatus.online;
      case 'offline':
        return PrinterStatus.offline;
      case 'error':
        return PrinterStatus.error;
      default:
        return PrinterStatus.offline;
    }
  }

  // Helper: String to PrinterGroup
  static PrinterGroup _stringToPrinterGroup(String group) {
    switch (group) {
      case 'receipt':
        return PrinterGroup.receipt;
      case 'kitchen':
        return PrinterGroup.kitchen;
      case 'order': // Legacy support
        return PrinterGroup.kitchen;
      case 'quote':
        return PrinterGroup.quote;
      default:
        return PrinterGroup.receipt;
    }
  }
}
