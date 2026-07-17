import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zipzap_pos_self_orders/widgets/header/widget.dart';
import 'package:zipzap_pos_self_orders/widgets/app_drawer.dart';
import 'package:zipzap_pos_self_orders/models/dashboard_item_model.dart';
import 'package:zipzap_pos_self_orders/pages/home/widgets/dashboard_grid.dart';
import 'package:zipzap_pos_self_orders/modals/dashboard_editor_modal.dart';
import 'package:zipzap_pos_self_orders/modals/dinein_entry_modal.dart';
import 'package:zipzap_pos_self_orders/providers/websocket_provider.dart';
import 'package:zipzap_pos_self_orders/services/floor_plans_service.dart';
import 'package:zipzap_pos_self_orders/services/orders_service.dart';
import 'package:zipzap_pos_self_orders/providers/data_provider.dart';
import 'package:zipzap_pos_self_orders/widgets/data_loading_progress_dialog.dart';
import 'package:zipzap_pos_self_orders/core/services/auth_service.dart';
import 'package:zipzap_pos_self_orders/core/services/websocket_service.dart';
import 'package:zipzap_pos_self_orders/widgets/app_toast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zipzap_pos_self_orders/widgets/app_version_text.dart';
import 'package:zipzap_pos_self_orders/widgets/auth_wrapper.dart';
import 'package:zipzap_pos_self_orders/services/printer_service.dart';
import 'package:zipzap_pos_self_orders/models/customer_model.dart';
import 'package:zipzap_pos_self_orders/models/printer_model.dart';
import 'package:zipzap_pos_self_orders/widgets/pin_confirmation_dialog.dart';
import 'dart:convert';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final WebSocketProvider _webSocketProvider = WebSocketProvider();
  final DataProvider _dataProvider = DataProvider();
  final AuthService _authService = AuthService();
  final FloorPlansService _floorPlansService = FloorPlansService();
  String _storeStatus = 'open';
  late List<DashboardItem> _dashboardItems;
  bool _isTakeoutEnabled = true;
  bool _isDineInEnabled = true;
  bool _hasFloorPlanPermission = false;
  bool _hasAssignedTable = false;
  bool _hasAssignedTableActiveOrder = false;
  bool _hasCashDrawerPermission = false;
  bool _isUpdatingStoreStatus = false;
  Timer? _hiddenSettingsTimer;
  bool _hiddenSettingsActive = false;

  @override
  void initState() {
    super.initState();
    // Initialize _dashboardItems BEFORE setting up listener
    _dashboardItems = _getInitialDashboardItems();
    _refreshDashboardItems();
    _setupDataProviderListener();
    _checkAndShowProgressDialog();
    _loadStoreData();
    _updateTakeoutCount();
    _updateProductsCount();
    _updateCategoriesCount();
    _updateCustomersCount();
    _updateFloorPlanPermission();
    _updateCashDrawerPermission();
    _updateAssignedTableActiveOrderStatus();
  }

  void _checkAndShowProgressDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _dataProvider.isInitialLoad) {
        _showProgressDialog();
      }
    });
  }

  void _showProgressDialog() {
    late final Route<void> dialogRoute;
    dialogRoute = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _ProgressDialogWrapper(
        dataProvider: _dataProvider,
        onComplete: () {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && dialogRoute.isActive) {
              Navigator.of(context).removeRoute(dialogRoute);
            }
          });
        },
      ),
    );
    Navigator.of(context).push(dialogRoute);
  }

  @override
  void dispose() {
    _hiddenSettingsTimer?.cancel();
    _dataProvider.removeListener(_onDataUpdate);
    super.dispose();
  }

  void _setupDataProviderListener() {
    _dataProvider.addListener(_onDataUpdate);
  }

  void _onDataUpdate() {
    // Update counts and store when DataProvider notifies
    if (mounted) {
      _updateTakeoutCount();
      _updateProductsCount();
      _updateCategoriesCount();
      _updateCustomersCount();
      _updateStoreFromProvider();
      _updateFloorPlanPermission();
      _updateCashDrawerPermission();
      _updateAssignedTableActiveOrderStatus();
    }
  }

  void _updateTakeoutCount() {
    if (!mounted) return;

    setState(() {
      // Update the Takeout dashboard item with the count from DataProvider
      final takeoutIndex = _dashboardItems.indexWhere(
        (item) => item.route == '/takeout',
      );
      if (takeoutIndex != -1) {
        _dashboardItems[takeoutIndex] = _dashboardItems[takeoutIndex].copyWith(
          count: _dataProvider.takeoutOrdersCount,
        );
      }
    });
  }

  void _updateProductsCount() {
    if (!mounted) return;

    setState(() {
      // Update the Products dashboard item with the count from DataProvider
      final productsIndex = _dashboardItems.indexWhere(
        (item) => item.route == '/products/list',
      );
      if (productsIndex != -1) {
        _dashboardItems[productsIndex] = _dashboardItems[productsIndex]
            .copyWith(count: _dataProvider.productsList.length);
      }
    });
  }

  void _updateCategoriesCount() {
    if (!mounted) return;

    setState(() {
      // Update the Categories dashboard item with the count from DataProvider
      final categoriesIndex = _dashboardItems.indexWhere(
        (item) => item.route == '/categories/list',
      );
      if (categoriesIndex != -1) {
        _dashboardItems[categoriesIndex] = _dashboardItems[categoriesIndex]
            .copyWith(count: _dataProvider.categoriesList.length);
      }
    });
  }

  void _updateCustomersCount() {
    if (!mounted) return;

    setState(() {
      // Update the Customers dashboard item with the count from DataProvider
      final customersIndex = _dashboardItems.indexWhere(
        (item) => item.route == '/customers',
      );
      if (customersIndex != -1) {
        _dashboardItems[customersIndex] = _dashboardItems[customersIndex]
            .copyWith(count: _dataProvider.customersList.length);
      }
    });
  }

  void _updateStoreFromProvider() {
    setState(() {
      final store = _dataProvider.store;
      if (store != null) {
        _storeStatus = store.status;
        final servicesOffered = store.servicesOffered;
        if (servicesOffered != null) {
          _isTakeoutEnabled =
              servicesOffered['pickUp'] == true ||
              servicesOffered['delivery'] == true;
          _isDineInEnabled = servicesOffered['dineIn'] == true;
        }
      }
    });
  }

  void _updateFloorPlanPermission() {
    final profile = _authService.getProfile();
    setState(() {
      _hasFloorPlanPermission = profile?.canReadFloorPlans ?? false;
    });
  }

  void _updateCashDrawerPermission() {
    final profile = _authService.getProfile();
    setState(() {
      _hasCashDrawerPermission = profile?.canOpenCashDrawer ?? false;
    });
  }

  Future<void> _updateAssignedTableActiveOrderStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = _authService.getProfile()?.username;
      final assignedKey = username != null && username.isNotEmpty
          ? 'assigned_table_$username'
          : 'assigned_table';
      final assignedJson = prefs.getString(assignedKey);
      if (assignedJson == null || assignedJson.isEmpty) {
        if (mounted) {
          setState(() {
            _hasAssignedTable = false;
            _hasAssignedTableActiveOrder = false;
          });
          _refreshDashboardItems();
        }
        return;
      }

      final tableInfo = jsonDecode(assignedJson) as Map<String, dynamic>;
      final tableId = tableInfo['tableId'] as String?;
      if (tableId == null || tableId.isEmpty) {
        if (mounted) {
          setState(() {
            _hasAssignedTable = false;
            _hasAssignedTableActiveOrder = false;
          });
          _refreshDashboardItems();
        }
        return;
      }

      final existingOrder = await _ordersService.getActiveOrderForTable(
        tableId,
      );
      if (mounted) {
        setState(() {
          _hasAssignedTable = true;
          _hasAssignedTableActiveOrder = existingOrder != null;
        });
        _refreshDashboardItems();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasAssignedTable = false;
          _hasAssignedTableActiveOrder = false;
        });
        _refreshDashboardItems();
      }
    }
  }

  void _refreshDashboardItems() {
    if (!mounted) return;

    setState(() {
      _dashboardItems = _dashboardItems.map((item) {
        if (item.route == '#dinein_entry') {
          return item.copyWith(
            enabled: _hasAssignedTable ? !_hasAssignedTableActiveOrder : false,
          );
        }
        if (item.route == '#update_orders') {
          return item.copyWith(
            enabled: _hasAssignedTable ? _hasAssignedTableActiveOrder : false,
          );
        }
        return item;
      }).toList();
    });
  }

  void _startHiddenSettingsTimer() {
    _hiddenSettingsTimer?.cancel();
    _hiddenSettingsTimer = Timer(const Duration(seconds: 5), () {
      _hiddenSettingsTimer = null;
      _openHiddenSettingsIfAuthorized();
    });
  }

  void _cancelHiddenSettingsTimer() {
    _hiddenSettingsTimer?.cancel();
    _hiddenSettingsTimer = null;
  }

  Future<void> _openHiddenSettingsIfAuthorized() async {
    if (!mounted || _hiddenSettingsActive) return;
    _hiddenSettingsActive = true;

    try {
      final confirmed = await _confirmCurrentPin();
      if (!confirmed || !mounted) return;
      await _showHiddenSettingsModal();
    } finally {
      _hiddenSettingsActive = false;
    }
  }

  Future<bool> _confirmCurrentPin() async {
    final pin = await PinConfirmationDialog.show(
      context,
      title: 'Confirm PIN',
      description: 'Enter your PIN to access hidden settings.',
    );

    if (pin == null || pin.isEmpty) {
      return false;
    }

    final profile = _authService.getProfile();
    final username = profile?.username;
    final storeSlug = profile?.storeSlug ?? _authService.getLastStoreSlug();

    if (username == null || storeSlug == null || storeSlug.isEmpty) {
      AppToast.error(
        context: context,
        title: 'PIN Error',
        description:
            'Unable to verify PIN. Please try logging out and in again.',
      );
      return false;
    }

    try {
      await _authService.pinLogin(
        user: username,
        pin: pin,
        storeSlug: storeSlug,
      );
      if (!mounted) return false;
      return true;
    } catch (e) {
      if (!mounted) return false;
      AppToast.error(
        context: context,
        title: 'Invalid PIN',
        description: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  Future<void> _performLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    try {
      final dataProvider = DataProvider();
      dataProvider.clearAllData();

      final webSocketService = WebSocketService();
      webSocketService.disconnect();

      await _authService.logout();

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
        (route) => false,
      );
    } catch (e) {
      AppToast.error(
        context: context,
        title: 'Logout Error',
        description: e.toString(),
      );
    }
  }

  Future<void> _showHiddenSettingsModal() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Advanced Settings'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Choose an advanced action. This menu is protected by PIN.',
                  style: TextStyle(color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.print),
                  label: const Text('Printer Settings'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).pushNamed('/printers');
                  },
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.table_restaurant_outlined),
                  label: const Text('Assign Table for Customers'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _assignTableForSelfOrdering();
                  },
                ),
                // const SizedBox(height: 12),
                // ElevatedButton.icon(
                //   icon: const Icon(Icons.table_restaurant),
                //   label: const Text('Enter Table Number'),
                //   style: ElevatedButton.styleFrom(
                //     minimumSize: const Size.fromHeight(48),
                //   ),
                //   onPressed: () {
                //     Navigator.of(dialogContext).pop();
                //     _promptForUpdateOrderTableNumber();
                //   },
                // ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(),
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _performLogout();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadStoreData() async {
    try {
      // Trigger DataProvider to load store if not already loaded
      if (_dataProvider.store == null && !_dataProvider.isLoadingStore) {
        await _dataProvider.loadStore();
      }

      // Update from provider
      _updateStoreFromProvider();
    } catch (e) {
      debugPrint('Error loading store data: $e');
      // Error loading store data, keep default status
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
        return 'Lan';
    }
  }

  Future<void> _openCashDrawer() async {
    try {
      final printers = await PrinterService.getSavedPrinters();
      final receiptPrinters = printers
          .where((p) => p.group == PrinterGroup.receipt)
          .where((p) => p.status != PrinterStatus.error)
          .toList();

      if (receiptPrinters.isEmpty) {
        if (mounted) {
          AppToast.warning(
            context: context,
            title: 'No Receipt Printers',
            description: 'Please add a receipt printer first.',
          );
        }
        return;
      }

      bool anySuccess = false;
      for (final printer in receiptPrinters) {
        try {
          final interfaceType = _printerTypeToString(printer.type);
          final success = await PrinterService.openCashDrawer(
            interfaceType: interfaceType,
            identifier: printer.identifier,
          );
          if (success) anySuccess = true;
        } catch (e) {
          debugPrint('Error opening cash drawer on ${printer.name}: $e');
        }
      }

      if (mounted) {
        if (anySuccess) {
          AppToast.success(
            context: context,
            title: 'Cash Drawer Opened',
            description: 'Cash drawer opened successfully',
          );
        } else {
          AppToast.error(
            context: context,
            title: 'Cash Drawer Failed',
            description: 'Failed to open cash drawer. Check printer status.',
          );
        }
      }
    } catch (e) {
      debugPrint('Error opening cash drawer: $e');
      if (mounted) {
        AppToast.error(
          context: context,
          title: 'Cash Drawer Error',
          description: 'Error: $e',
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _getAssignedTableInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = _authService.getProfile()?.username;
      final assignedKey = username != null && username.isNotEmpty
          ? 'assigned_table_$username'
          : 'assigned_table';
      final assignedJson = prefs.getString(assignedKey);
      if (assignedJson == null || assignedJson.isEmpty) return null;
      return jsonDecode(assignedJson) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> _promptForUpdateOrderTableNumber() async {
    final assignedTable = await _getAssignedTableInfo();
    if (assignedTable != null) {
      final tableId = assignedTable['tableId'] as String?;
      if (tableId != null && tableId.isNotEmpty) {
        if (!mounted) return;
        Navigator.pushNamed(
          context,
          '/dinein',
          arguments: {'tableInfo': assignedTable},
        );
        return;
      }
    }

    final tableController = TextEditingController();
    String? dialogError;
    bool isLoading = false;

    Future<void> submitTableNumber(
      String tableNumber,
      void Function(VoidCallback fn) localSetState,
    ) async {
      if (tableNumber.isEmpty) {
        localSetState(() {
          dialogError = 'Please enter a table number';
        });
        return;
      }

      localSetState(() {
        isLoading = true;
        dialogError = null;
      });

      try {
        final response = await _floorPlansService.getFloorPlans(
          isActive: true,
          sortBy: 'createdAt',
          sortOrder: 'asc',
        );

        final matchingTable = response.floorPlans.fold<Map<String, dynamic>?>(
          null,
          (currentMatch, floorPlan) {
            if (currentMatch != null) return currentMatch;

            for (final item in floorPlan.items.where(
              (entry) => entry.type.isTable,
            )) {
              final itemName = item.name.trim().toLowerCase();
              final lookupName = tableNumber.toLowerCase();

              if (itemName == lookupName ||
                  itemName.contains(lookupName) ||
                  lookupName.contains(itemName)) {
                return {
                  'floorPlanId': floorPlan.id,
                  'floorPlanName': floorPlan.name,
                  'tableId': item.id,
                  'tableName': item.name,
                };
              }
            }

            return null;
          },
        );

        if (matchingTable == null) {
          localSetState(() {
            dialogError = 'Table number is not found';
          });
          return;
        }

        if (!mounted) return;
        Navigator.of(context).pop();
        Navigator.pushNamed(
          context,
          '/dinein',
          arguments: {
            'tableInfo': {
              'tableId': matchingTable['tableId'],
              'tableName': matchingTable['tableName'],
              'floorPlanId': matchingTable['floorPlanId'],
              'floorPlanName': matchingTable['floorPlanName'],
            },
          },
        );
      } catch (e) {
        localSetState(() {
          dialogError = e.toString().replaceFirst('Exception: ', '');
        });
      } finally {
        localSetState(() {
          isLoading = false;
        });
      }
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Enter Table Number'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter the table number to show that table on the dine-in page.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: tableController,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Table Number',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.table_restaurant),
                      ),
                      onSubmitted: (_) async {
                        if (!isLoading) {
                          await submitTableNumber(
                            tableController.text.trim(),
                            setState,
                          );
                        }
                      },
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        dialogError ?? '',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          await submitTableNumber(
                            tableController.text.trim(),
                            setState,
                          );
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Show Table'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<DashboardItem> _getInitialDashboardItems() => [
    DashboardItem(
      title: 'Order Now',
      description: 'You Can Place Orders',
      icon: Icons.table_restaurant,
      backgroundColor: Colors.teal.shade100,
      borderColor: Colors.teal.shade300,
      route: '#dinein_entry',
    ),
    DashboardItem(
      title: 'Update Orders',
      description: 'View tables and update orders',
      icon: Icons.table_bar,
      backgroundColor: Colors.blue.shade100,
      borderColor: Colors.blue.shade300,
      route: '#update_orders',
    ),
    // DashboardItem(
    //   title: 'Takeout',
    //   description: 'View and manage takeout orders',
    //   icon: Icons.shopping_bag,
    //   backgroundColor: Colors.yellow.shade100,
    //   borderColor: Colors.yellow.shade300,
    //   count: 0,
    //   route: '/takeout',
    // ),
    // DashboardItem(
    //   title: 'Dine-In',
    //   description: 'Manage tables and dine-in orders',
    //   icon: Icons.table_restaurant,
    //   backgroundColor: Colors.teal.shade100,
    //   borderColor: Colors.teal.shade300,
    //   route: '/dinein',
    // ),
    // DashboardItem(
    //   title: 'All Orders',
    //   description: 'View all customer orders',
    //   icon: Icons.shopping_cart,
    //   backgroundColor: Colors.orange.shade100,
    //   borderColor: Colors.orange.shade300,
    //   route: '/orders',
    // ),
    // DashboardItem(
    //   title: 'Pre-Pay Order',
    //   description: 'Create a new pre-pay order',
    //   icon: Icons.inventory_2,
    //   backgroundColor: Colors.pink.shade100,
    //   borderColor: Colors.pink.shade300,
    //   route: '/orders/new',
    //   arguments: {'orderType': ApiConstants.uiOrderTypePrepay},
    // ),
    // DashboardItem(
    //   title: 'Products',
    //   description: 'Manage your product catalog',
    //   icon: Icons.checklist,
    //   backgroundColor: Colors.blue.shade100,
    //   borderColor: Colors.blue.shade300,
    //   count: 0,
    //   route: '/products/list',
    // ),
    // DashboardItem(
    //   title: 'Categories',
    //   description: 'Organize products by categories',
    //   icon: Icons.list,
    //   backgroundColor: Colors.green.shade100,
    //   borderColor: Colors.green.shade300,
    //   count: 0,
    //   route: '/categories/list',
    // ),
    // DashboardItem(
    //   title: 'Customers',
    //   description: 'View and manage customer information',
    //   icon: Icons.people,
    //   backgroundColor: Colors.purple.shade100,
    //   borderColor: Colors.purple.shade300,
    //   count: 0,
    //   route: '/customers',
    // ),
    // DashboardItem(
    //   title: 'Report',
    //   description: 'View sales and business reports',
    //   icon: Icons.description,
    //   backgroundColor: Colors.indigo.shade100,
    //   borderColor: Colors.indigo.shade300,
    //   route: '/report',
    // ),
    // DashboardItem(
    //   title: 'Settings',
    //   description: 'Configure application settings',
    //   icon: Icons.settings,
    //   backgroundColor: Colors.grey.shade100,
    //   borderColor: Colors.grey.shade300,
    //   route: '/settings',
    // ),
    // DashboardItem(
    //   title: 'My Account',
    //   description: 'View and edit your account details',
    //   icon: Icons.person,
    //   backgroundColor: Colors.pink.shade100,
    //   borderColor: Colors.pink.shade300,
    //   route: '/profile',
    // ),
    // DashboardItem(
    //   title: 'Printer Settings',
    //   description: 'Configure printer settings',
    //   icon: Icons.print,
    //   backgroundColor: Colors.amber.shade100,
    //   borderColor: Colors.amber.shade300,
    //   route: '/printers',
    // ),
    // DashboardItem(
    //   title: 'Cash Drawer',
    //   description: 'Open the receipt printer cash drawer',
    //   icon: Icons.point_of_sale,
    //   backgroundColor: Colors.cyan.shade100,
    //   borderColor: Colors.cyan.shade300,
    //   route: '#open_cash_drawer',
    // ),
    // DashboardItem(
    //   title: 'New Tile',
    //   description: 'Edit dashboard cards',
    //   icon: Icons.add,
    //   backgroundColor: Colors.grey.shade300,
    //   borderColor: Colors.grey.shade500,
    //   route: '#',
    // ),
  ];

  final OrdersService _ordersService = OrdersService();

  Future<void> _openDineInEntryFlow() async {
    final navigationContext = context;

    // If staff has an assigned table for customers, use that directly
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = _authService.getProfile()?.username;
      final assignedKey = username != null && username.isNotEmpty
          ? 'assigned_table_$username'
          : 'assigned_table';
      final assignedJson = prefs.getString(assignedKey);
      if (assignedJson != null && assignedJson.isNotEmpty) {
        final tableInfo = jsonDecode(assignedJson) as Map<String, dynamic>;
        final tableId = tableInfo['tableId'] as String?;
        if (tableId != null && tableId.isNotEmpty) {
          // If there's an existing order for this table, open edit; else new
          final existingOrder = await _ordersService.getActiveOrderForTable(
            tableId,
          );
          if (existingOrder != null) {
            if (!mounted) return;
            Navigator.pushNamed(
              navigationContext,
              '/dinein/new',
              arguments: {
                'orderType': 'dineIn',
                'isEditMode': true,
                'order': existingOrder,
                'tableInfo': tableInfo,
              },
            );
            return;
          }

          final orderData = await _promptForGuestAndCustomerForAssignedTable(
            tableInfo,
          );
          if (orderData == null) return;
          if (!mounted) return;

          Navigator.pushNamed(
            navigationContext,
            '/dinein/new',
            arguments: {
              'orderType': 'dineIn',
              'tableInfo': tableInfo,
              'partySize': orderData['partySize'],
              'customer': orderData['customer'],
            },
          );
          return;
        }
      }
    } catch (_) {
      // ignore prefs errors and fall back to modal
    }

    // Load last-used dine-in defaults (per-user if available)
    String? initialTable;
    String? initialGuests;
    String? initialCustomer;
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = _authService.getProfile()?.username;
      if (username != null && username.isNotEmpty) {
        initialTable = prefs.getString('last_table_number_$username');
        initialGuests = prefs.getString('last_guest_count_$username');
        initialCustomer = prefs.getString('last_customer_name_$username');
      }
      initialTable ??= prefs.getString('last_table_number');
      initialGuests ??= prefs.getString('last_guest_count');
      initialCustomer ??= prefs.getString('last_customer_name');
    } catch (_) {
      // ignore prefs errors
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DineInEntryModal(
        onConfirm: (tableInfo, partySize, customer) async {
          if (!mounted) return;

          Navigator.of(navigationContext).pop();

          final tableId = tableInfo['tableId'] as String?;
          if (tableId != null && tableId.isNotEmpty) {
            final existingOrder = await _ordersService.getActiveOrderForTable(
              tableId,
            );
            if (existingOrder != null) {
              Navigator.pushNamed(
                navigationContext,
                '/dinein/new',
                arguments: {
                  'orderType': 'dineIn',
                  'isEditMode': true,
                  'order': existingOrder,
                  'tableInfo': tableInfo,
                },
              );
              return;
            }
          }

          Navigator.pushNamed(
            navigationContext,
            '/dinein/new',
            arguments: {
              'orderType': 'dineIn',
              'tableInfo': tableInfo,
              'partySize': partySize,
              'customer': customer,
            },
          );
        },
        initialTableNumber: initialTable,
        initialGuestCount: initialGuests,
        initialCustomerName: initialCustomer,
      ),
    );
  }

  Future<Map<String, dynamic>?> _promptForGuestAndCustomerForAssignedTable(
    Map<String, dynamic> tableInfo,
  ) async {
    int guestCount =
        int.tryParse(tableInfo['partySize']?.toString() ?? '1') ?? 1;
    final customerController = TextEditingController();
    String? errorText;
    bool isSubmitting = false;
    const Color primaryTeal = Color(0xFF006B5F);
    const Color lightTealBg = Color(0xFFD8F0ED);

    return await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            void updateGuestCount(int value) {
              setState(() {
                guestCount = value;
              });
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: SingleChildScrollView(
                child: Container(
                  width: 480,
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Order Now Details',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                tableInfo['tableName'] ?? 'Table',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(dialogContext),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.close,
                                color: Colors.red.shade700,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Guest Count - Large Container
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 28,
                          horizontal: 20,
                        ),
                        decoration: BoxDecoration(
                          color: lightTealBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: guestCount > 1
                                      ? () => updateGuestCount(guestCount - 1)
                                      : null,
                                  child: Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.08,
                                          ),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.remove,
                                      color: guestCount > 1
                                          ? primaryTeal
                                          : Colors.grey.shade300,
                                      size: 26,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 48),
                                Text(
                                  guestCount.toString(),
                                  style: const TextStyle(
                                    fontSize: 56,
                                    fontWeight: FontWeight.bold,
                                    color: primaryTeal,
                                  ),
                                ),
                                const SizedBox(width: 48),
                                GestureDetector(
                                  onTap: () => updateGuestCount(guestCount + 1),
                                  child: Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.08,
                                          ),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      color: primaryTeal,
                                      size: 26,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Guest',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Quick Select
                      const Text(
                        'Quick Select',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [1, 2, 3, 4, 5, 8, 10, 20]
                            .map(
                              (count) => GestureDetector(
                                onTap: () => updateGuestCount(count),
                                child: Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: guestCount == count
                                        ? primaryTeal
                                        : Colors.white,
                                    border: Border.all(
                                      color: guestCount == count
                                          ? primaryTeal
                                          : Colors.grey.shade300,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      count.toString(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: guestCount == count
                                            ? Colors.white
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 24),

                      // Customer Name
                      TextField(
                        controller: customerController,
                        decoration: InputDecoration(
                          hintText: 'Customer Name',
                          prefixIcon: const Icon(Icons.person, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: primaryTeal,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                        ),
                      ),

                      if (errorText != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            border: Border.all(color: Colors.red.shade200),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red.shade700,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errorText!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),

                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: isSubmitting
                                  ? null
                                  : () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: Colors.red.shade400,
                                  width: 2,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: Icon(
                                Icons.close,
                                color: Colors.red.shade600,
                                size: 18,
                              ),
                              label: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.red.shade600,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: isSubmitting
                                  ? null
                                  : () {
                                      final customerName = customerController
                                          .text
                                          .trim();

                                      if (customerName.isEmpty) {
                                        setState(() {
                                          errorText =
                                              'Please enter customer name.';
                                        });
                                        return;
                                      }

                                      Navigator.of(dialogContext).pop({
                                        'partySize': guestCount,
                                        'customer': Customer(
                                          id: '',
                                          firstName: customerName,
                                        ),
                                      });
                                    },
                              style: FilledButton.styleFrom(
                                backgroundColor: primaryTeal,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Icon(Icons.check, size: 18),
                              label: Text(
                                isSubmitting
                                    ? 'Confirming...'
                                    : 'Confirm Order',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadAssignableTables() async {
    final response = await _floorPlansService.getFloorPlans(
      isActive: true,
      sortBy: 'createdAt',
      sortOrder: 'asc',
    );

    final tables = <Map<String, dynamic>>[];
    for (final floorPlan in response.floorPlans) {
      for (final item in floorPlan.items.where((entry) => entry.type.isTable)) {
        tables.add({
          'floorPlanId': floorPlan.id,
          'floorPlanName': floorPlan.name,
          'tableId': item.id,
          'tableName': item.name,
          'tableStatus': item.status.value,
          'tableSection': item.section,
          'tableSeats': item.seats,
        });
      }
    }

    return tables;
  }

  Future<void> _assignTableForSelfOrdering() async {
    String? dialogError;
    bool isLoading = false;
    Map<String, dynamic>? selectedTable;
    final tableListFuture = _loadAssignableTables();

    Future<void> submitAssign(
      Map<String, dynamic> table,
      void Function(VoidCallback fn) localSetState,
    ) async {
      localSetState(() {
        isLoading = true;
        dialogError = null;
      });

      try {
        final prefs = await SharedPreferences.getInstance();
        final username = _authService.getProfile()?.username;
        final assignedKey = username != null && username.isNotEmpty
            ? 'assigned_table_$username'
            : 'assigned_table';
        final toSave = jsonEncode(table);
        await prefs.setString(assignedKey, toSave);

        if (!mounted) return;
        Navigator.of(context).pop();
        AppToast.success(
          context: context,
          title: 'Assigned',
          description: 'Table ${table['tableName']} assigned for customers',
        );
      } catch (e) {
        localSetState(() {
          dialogError = 'Failed to save assignment. Please try again.';
        });
      } finally {
        localSetState(() {
          isLoading = false;
        });
      }
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Assign Table for Customers'),
              content: SizedBox(
                width: 420,
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: tableListFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const SizedBox(
                        height: 220,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (snapshot.hasError) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Failed to load table list.'),
                          const SizedBox(height: 12),
                          Text(
                            snapshot.error.toString(),
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ],
                      );
                    }

                    final tables = snapshot.data ?? [];
                    if (tables.isEmpty) {
                      return const Text(
                        'No tables available. Please add floor plan tables first.',
                      );
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select a table created by the admin to assign to incoming self-orders.',
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 310,
                          child: ListView.separated(
                            itemCount: tables.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final table = tables[index];
                              final isSelected =
                                  selectedTable != null &&
                                  selectedTable!['tableId'] == table['tableId'];
                              final statusText =
                                  (table['tableStatus'] as String?)
                                      ?.toUpperCase() ??
                                  'UNKNOWN';
                              final section = table['tableSection'] != null
                                  ? ' · ${table['tableSection']}'
                                  : '';
                              final seats = table['tableSeats'] != null
                                  ? ' · ${table['tableSeats']} seats'
                                  : '';

                              return ListTile(
                                dense: true,
                                title: Text(table['tableName'] as String),
                                subtitle: Text(
                                  '${table['floorPlanName']}$section$seats • $statusText',
                                ),
                                trailing: isSelected
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: Colors.teal,
                                      )
                                    : null,
                                selected: isSelected,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                selectedTileColor: Colors.teal.shade50,
                                onTap: () {
                                  setState(() {
                                    selectedTable = table;
                                    dialogError = null;
                                  });
                                },
                              );
                            },
                          ),
                        ),
                        if (dialogError != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            dialogError!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isLoading || selectedTable == null
                      ? null
                      : () async {
                          await submitAssign(selectedTable!, setState);
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Assign'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openDashboardEditor() {
    // Filter out the "New Tile" item and items based on servicesOffered and permissions
    final editableItems = _dashboardItems.where((item) {
      if (item.route == '#') return false;
      // Filter Takeout based on pickUp or delivery service
      if (item.route == '/takeout' && !_isTakeoutEnabled) return false;
      // Filter Dine-In based on dineIn service AND floor_plans permission
      if ((item.route == '/dinein' ||
              item.route == '#dinein_entry' ||
              item.route == '#update_orders') &&
          (!_isDineInEnabled || !_hasFloorPlanPermission))
        return false;
      // Filter Cash Drawer based on cash_drawer permission
      if (item.route == '#open_cash_drawer' && !_hasCashDrawerPermission)
        return false;
      return true;
    }).toList();

    showDialog(
      context: context,
      builder: (context) => DashboardEditorModal(
        items: editableItems,
        onSave: (updatedItems) {
          setState(() {
            // Find the "New Tile" item to preserve it
            final newTileItem = _dashboardItems.firstWhere(
              (item) => item.route == '#',
              orElse: () => _dashboardItems.last,
            );
            // Combine updated items with the preserved "New Tile" item
            _dashboardItems = [...updatedItems, newTileItem];
          });
        },
      ),
    );
  }

  List<DashboardItem> get _enabledDashboardItems {
    return _dashboardItems.where((item) {
      if (!item.enabled) return false;
      // Filter Takeout based on pickUp or delivery service
      if (item.route == '/takeout' && !_isTakeoutEnabled) return false;
      // Filter Dine-In based on dineIn service AND floor_plans permission
      if ((item.route == '/dinein' ||
              item.route == '#dinein_entry' ||
              item.route == '#update_orders') &&
          (!_isDineInEnabled || !_hasFloorPlanPermission))
        return false;
      // Filter Cash Drawer based on cash_drawer permission
      if (item.route == '#open_cash_drawer' && !_hasCashDrawerPermission)
        return false;
      return true;
    }).toList();
  }

  Widget _buildAssignmentNotice() {
    if (_hasAssignedTable) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Assign a table from Advanced Settings first to use Order Now or Update Orders.',
              style: TextStyle(color: Colors.orange.shade900),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          SafeArea(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => _startHiddenSettingsTimer(),
              onPointerUp: (_) => _cancelHiddenSettingsTimer(),
              onPointerCancel: (_) => _cancelHiddenSettingsTimer(),
              child: Column(
                children: [
                  Builder(
                    builder: (context) => ListenableBuilder(
                      listenable: _webSocketProvider,
                      builder: (context, _) => ListenableBuilder(
                        listenable: _dataProvider,
                        builder: (context, _) => HeaderWidget(
                          logoUrl: 'https://zipzappos.com',
                          onDrawerPressed: () {
                            Scaffold.of(context).openDrawer();
                          },
                          onSearchChanged: (query) {
                            debugPrint('Search query: $query');
                          },
                          serverStatus: true,
                          websocketStatus: _webSocketProvider.status,
                          isServerDown: _webSocketProvider.isServerDown,
                          isRefetching: _dataProvider.isRefetching,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1400),
                        child: Column(
                          children: [
                            _buildAssignmentNotice(),
                            Expanded(
                              child: DashboardGrid(
                                items: _enabledDashboardItems,
                                onItemTap: (route, arguments) {
                                  if (route == '#') {
                                    _openDashboardEditor();
                                    return;
                                  }
                                  if (route == '#open_cash_drawer') {
                                    _openCashDrawer();
                                    return;
                                  }
                                  if (route == '#dinein_entry') {
                                    _openDineInEntryFlow();
                                    return;
                                  }
                                  if (route == '#update_orders') {
                                    _promptForUpdateOrderTableNumber();
                                    return;
                                  }
                                  if (route == '/dinein') {
                                    Navigator.pushNamed(
                                      context,
                                      route,
                                      arguments: arguments,
                                    );
                                    return;
                                  }
                                  if (arguments != null) {
                                    Navigator.pushNamed(
                                      context,
                                      route,
                                      arguments: arguments,
                                    );
                                  } else {
                                    Navigator.pushNamed(context, route);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppVersionText(
                      color: Colors.grey.shade400,
                      fontSize: 11,
                      showIcon: true,
                      checkForUpdates: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          //_buildStoreStatusFAB(context, isOpen),
        ],
      ),
    );
  }
}

// Wrapper widget to listen to DataProvider changes and update dialog
class _ProgressDialogWrapper extends StatefulWidget {
  final DataProvider dataProvider;
  final VoidCallback onComplete;

  const _ProgressDialogWrapper({
    required this.dataProvider,
    required this.onComplete,
  });

  @override
  State<_ProgressDialogWrapper> createState() => _ProgressDialogWrapperState();
}

class _ProgressDialogWrapperState extends State<_ProgressDialogWrapper> {
  @override
  void initState() {
    super.initState();
    widget.dataProvider.addListener(_onDataUpdate);
  }

  @override
  void dispose() {
    widget.dataProvider.removeListener(_onDataUpdate);
    super.dispose();
  }

  void _onDataUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return DataLoadingProgressDialog(
      items: widget.dataProvider.progressItems,
      onComplete: widget.onComplete,
    );
  }
}
