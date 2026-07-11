import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/widgets/header/widget.dart';
import 'package:zipzap_pos_self_orders/widgets/app_drawer.dart';
import 'package:zipzap_pos_self_orders/models/dashboard_item_model.dart';
import 'package:zipzap_pos_self_orders/pages/home/widgets/dashboard_grid.dart';
import 'package:zipzap_pos_self_orders/modals/dashboard_editor_modal.dart';
import 'package:zipzap_pos_self_orders/providers/websocket_provider.dart';
import 'package:zipzap_pos_self_orders/providers/data_provider.dart';
import 'package:zipzap_pos_self_orders/widgets/data_loading_progress_dialog.dart';
import 'package:zipzap_pos_self_orders/core/constants/api_constants.dart';
import 'package:zipzap_pos_self_orders/core/services/auth_service.dart';
import 'package:zipzap_pos_self_orders/widgets/app_version_text.dart';
import 'package:zipzap_pos_self_orders/widgets/app_toast.dart';
import 'package:zipzap_pos_self_orders/services/printer_service.dart';
import 'package:zipzap_pos_self_orders/models/printer_model.dart';
import 'package:zipzap_pos_self_orders/widgets/time_clock_status_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final WebSocketProvider _webSocketProvider = WebSocketProvider();
  final DataProvider _dataProvider = DataProvider();
  final AuthService _authService = AuthService();
  String _storeStatus = 'open';
  late List<DashboardItem> _dashboardItems;
  bool _isTakeoutEnabled = true;
  bool _isDineInEnabled = true;
  bool _hasFloorPlanPermission = false;
  bool _hasCashDrawerPermission = false;
  bool _isUpdatingStoreStatus = false;

  @override
  void initState() {
    super.initState();
    // Initialize _dashboardItems BEFORE setting up listener
    _dashboardItems = _getInitialDashboardItems();
    _setupDataProviderListener();
    _checkAndShowProgressDialog();
    _loadStoreData();
    _updateTakeoutCount();
    _updateProductsCount();
    _updateCategoriesCount();
    _updateCustomersCount();
    _updateFloorPlanPermission();
    _updateCashDrawerPermission();
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

  Future<void> _toggleStoreStatus() async {
    if (_isUpdatingStoreStatus) return;

    final newStatus = _storeStatus == 'open' ? 'closed' : 'open';

    setState(() {
      _isUpdatingStoreStatus = true;
    });

    try {
      final success = await _dataProvider.updateStoreStatus(newStatus);

      if (mounted) {
        if (success) {
          setState(() {
            _storeStatus = newStatus;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to connect!'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to connect!'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStoreStatus = false;
        });
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

  Widget _buildStoreStatusFAB(BuildContext context, bool isOpen) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Positioned(
      bottom: 20 + bottomPadding,
      right: 16,
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isOpen
                      ? [
                          Colors.green.withValues(alpha: 0.2),
                          Colors.teal.withValues(alpha: 0.1),
                          Colors.green.withValues(alpha: 0.2),
                        ]
                      : [
                          Colors.grey.withValues(alpha: 0.2),
                          Colors.grey.shade700.withValues(alpha: 0.1),
                          Colors.grey.withValues(alpha: 0.2),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isOpen
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.grey.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Store Status',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: isOpen
                              ? Colors.green.shade700
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOpen ? Icons.access_time : Icons.nightlight_round,
                            size: 16,
                            color: isOpen
                                ? Colors.green.shade700
                                : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isOpen ? 'Open' : 'Closed',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isOpen
                                      ? Colors.green.shade700
                                      : Colors.grey.shade600,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  _isUpdatingStoreStatus
                      ? SizedBox(
                          width: 40,
                          height: 24,
                          child: Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isOpen
                                      ? Colors.green.shade700
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: isOpen,
                            onChanged: (value) {
                              _toggleStoreStatus();
                            },
                            activeThumbColor: Colors.green,
                            activeTrackColor: Colors.green.withValues(
                              alpha: 0.5,
                            ),
                            inactiveThumbColor: Colors.grey.shade400,
                            inactiveTrackColor: Colors.grey.shade300,
                          ),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<DashboardItem> _getInitialDashboardItems() => [
    DashboardItem(
      title: 'Order Now',
      description: 'You Can Place Orders',
      icon: Icons.table_restaurant,
      backgroundColor: Colors.teal.shade100,
      borderColor: Colors.teal.shade300,
      route: '/dinein',
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

  void _openDashboardEditor() {
    // Filter out the "New Tile" item and items based on servicesOffered and permissions
    final editableItems = _dashboardItems.where((item) {
      if (item.route == '#') return false;
      // Filter Takeout based on pickUp or delivery service
      if (item.route == '/takeout' && !_isTakeoutEnabled) return false;
      // Filter Dine-In based on dineIn service AND floor_plans permission
      if (item.route == '/dinein' &&
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
      if (item.route == '/dinein' &&
          (!_isDineInEnabled || !_hasFloorPlanPermission))
        return false;
      // Filter Cash Drawer based on cash_drawer permission
      if (item.route == '#open_cash_drawer' && !_hasCashDrawerPermission)
        return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = _storeStatus == 'open';

    return Scaffold(
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          SafeArea(
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
                          // Handle search
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
                const TimeClockStatusBar(),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1400),
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
                  ),
                ),
                // Version at bottom
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
