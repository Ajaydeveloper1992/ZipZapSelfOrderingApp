import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/widgets/header/widget.dart';
import 'package:zipzap_pos_self_orders/widgets/app_drawer.dart';
import 'package:zipzap_pos_self_orders/models/order_model.dart';
import 'package:zipzap_pos_self_orders/pages/takeouts/widgets/order_list.dart';
import 'package:zipzap_pos_self_orders/pages/takeouts/widgets/filter_chips.dart';
import 'package:zipzap_pos_self_orders/pages/takeouts/widgets/order_details_drawer.dart';
import 'package:zipzap_pos_self_orders/modals/order_type_modal.dart';
import 'package:zipzap_pos_self_orders/providers/websocket_provider.dart';
import 'package:zipzap_pos_self_orders/providers/data_provider.dart';
import 'package:zipzap_pos_self_orders/services/audio_service.dart';

class TakeoutPage extends StatefulWidget {
  const TakeoutPage({super.key});

  @override
  State<TakeoutPage> createState() => _TakeoutPageState();
}

class _TakeoutPageState extends State<TakeoutPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final WebSocketProvider _webSocketProvider = WebSocketProvider();
  final DataProvider _dataProvider = DataProvider();
  final AudioService _audioService = AudioService();

  List<Order> _allOrders = [];
  List<Order> _filteredOrders = [];
  String _originFilter = 'All';
  String _statusFilter = 'All';
  String _searchQuery = '';
  Order? _selectedOrder;
  ServicesOffered? _servicesOffered;

  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isBackgroundRefreshing = false;
  String? _errorMessage;

  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    _loadStoreData();
    _setupDataProviderListener();
    _updateOrdersFromProvider(); // Initial load from DataProvider

    // Ensure notification loop is checked when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dataProvider.checkNotificationLoop();
    });
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _dataProvider.removeListener(_onDataUpdate);
    super.dispose();
  }

  void _setupDataProviderListener() {
    _dataProvider.addListener(_onDataUpdate);
  }

  void _onDataUpdate() {
    // Update orders and store when DataProvider notifies (after WebSocket refetch)
    if (mounted) {
      _updateOrdersFromProvider(isBackground: true);
      _updateStoreFromProvider();
    }
  }

  void _updateOrdersFromProvider({bool isBackground = false}) {
    if (isBackground) {
      setState(() {
        _isBackgroundRefreshing = true;
      });
    }

    // Get orders from DataProvider (notification logic is now handled there)
    final orders = _dataProvider.takeoutOrdersList;

    setState(() {
      _allOrders = orders;
      _isLoading = false;
      _isRefreshing = false;
      _isBackgroundRefreshing = false;
      _errorMessage = _dataProvider.takeoutOrdersError;
      _applyFilters();
    });
  }

  Future<void> _loadOrders({
    bool forceRefresh = false,
    bool isBackground = false,
  }) async {
    // If DataProvider is loading, wait for it or use cached data
    if (_dataProvider.isLoadingTakeoutOrders && !forceRefresh) {
      // Wait a bit and try again
      await Future.delayed(const Duration(milliseconds: 100));
      _updateOrdersFromProvider(isBackground: isBackground);
      return;
    }

    // If forcing refresh, trigger DataProvider to refetch
    if (forceRefresh) {
      await _dataProvider.loadTakeoutOrders(forceRefresh: true);
    }

    // Update from provider
    _updateOrdersFromProvider(isBackground: isBackground);
  }

  void _updateStoreFromProvider() {
    setState(() {
      final store = _dataProvider.store;
      if (store != null && store.servicesOffered != null) {
        _servicesOffered = ServicesOffered.fromJson(store.servicesOffered!);
      }
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
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredOrders = _allOrders.where((order) {
        // Origin filter
        bool originMatch = true;
        if (_originFilter == 'Online Order') {
          originMatch = order.origin == 'AI' || order.origin == 'WEB';
        } else if (_originFilter == 'Pickup') {
          originMatch = order.origin == 'POS';
        }

        // Status filter
        bool statusMatch = true;
        if (_statusFilter == 'Pending') {
          statusMatch = order.orderstatus == 'Pending';
        } else if (_statusFilter == 'In Kitchen') {
          statusMatch = order.orderstatus == 'InKitchen';
        }

        // Search filter
        bool searchMatch = true;
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          searchMatch =
              order.orderNumber.toLowerCase().contains(query) ||
              order.customer?.fullName.toLowerCase().contains(query) == true ||
              order.customer?.phone.contains(query) == true ||
              order.items.any(
                (item) => item.displayName.toLowerCase().contains(query),
              );
        }

        return originMatch && statusMatch && searchMatch;
      }).toList();

      // Sort: Pending orders first, then by updatedAt (latest first)
      _filteredOrders.sort((a, b) {
        // First priority: Pending orders come first
        if (a.orderstatus == 'Pending' && b.orderstatus != 'Pending') {
          return -1;
        }
        if (b.orderstatus == 'Pending' && a.orderstatus != 'Pending') {
          return 1;
        }

        // Second priority: Sort by updatedAt (latest first)
        // If both have updatedAt, compare them
        if (a.updatedAt != null && b.updatedAt != null) {
          return b.updatedAt!.compareTo(
            a.updatedAt!,
          ); // Descending order (latest first)
        }

        // Fallback: Sort by date field (creation date)
        return b.date.compareTo(a.date); // Descending order (latest first)
      });
    });
  }

  void _handleOriginFilterChanged(String filter) {
    setState(() {
      _originFilter = filter;
    });
    _applyFilters();
  }

  void _handleStatusFilterChanged(String filter) {
    setState(() {
      _statusFilter = filter;
    });
    // Apply filters client-side only, no API call
    _applyFilters();
  }

  void _handleSearchChanged(String query) {
    // Cancel any pending timer
    _searchDebounceTimer?.cancel();

    // Update search query immediately for UI responsiveness
    setState(() {
      _searchQuery = query;
    });

    // Short debounce for local filtering (feels instant but reduces rebuilds)
    _searchDebounceTimer = Timer(const Duration(milliseconds: 150), () {
      _applyFilters();
    });
  }

  void _handleAddNewOrder() {
    final hasPickUp = _servicesOffered?.pickUp == true;
    final hasDelivery = _servicesOffered?.delivery == true;

    // If only pickUp is enabled, go directly to takeout
    if (hasPickUp && !hasDelivery) {
      Navigator.of(
        context,
      ).pushNamed('/orders/new', arguments: {'orderType': 'takeout'});
      return;
    }

    // If only delivery is enabled, go directly to delivery
    if (hasDelivery && !hasPickUp) {
      Navigator.of(
        context,
      ).pushNamed('/orders/new', arguments: {'orderType': 'delivery'});
      return;
    }

    // If both are enabled (or services is null), show modal
    showDialog(
      context: context,
      builder: (context) => OrderTypeModal(
        services: _servicesOffered,
        onOrderTypeSelected: (orderType) {
          Navigator.of(context).pop(); // Close modal
          Navigator.of(
            context,
          ).pushNamed('/orders/new', arguments: {'orderType': orderType});
        },
        onCancel: () {
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _handleOrderTap(Order order) {
    // Only open drawer if orderstatus is 'Pending' AND paymentStatus is 'Paid'
    if (order.orderstatus == 'Pending' ||
        (order.orderstatus == 'InKitchen' && order.paymentStatus == 'Paid')) {
      setState(() {
        _selectedOrder = order;
      });
      _scaffoldKey.currentState?.openEndDrawer();
    } else if (order.orderstatus == 'InKitchen') {
      // Navigate to new order page with order data for editing
      Navigator.of(context).pushNamed(
        '/orders/new',
        arguments: {
          'orderType': order.orderType.toLowerCase(),
          'order': order,
          'isEditMode': true,
        },
      );
    }
  }

  /// Mark user interaction for audio playback (needed on web)
  void _onUserInteraction() {
    if (!_audioService.hasUserInteracted) {
      _audioService.markUserInteracted();
      // After user interaction, check if notification loop should start
      _dataProvider.checkNotificationLoop();
      // Rebuild to hide the banner
      if (mounted) setState(() {});
    }
  }

  /// Build a banner to prompt user to enable sound notifications (web only)
  Widget _buildSoundNotificationBanner() {
    // Only show on web and when user hasn't interacted yet
    final pendingCount = _dataProvider.pendingWebOrdersCount;

    // Don't show if no pending orders or user has already interacted
    if (pendingCount == 0 || _audioService.hasUserInteracted) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.orange.shade50,
      child: InkWell(
        onTap: _onUserInteraction,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.notifications_active,
                color: Colors.orange.shade700,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '🔔 $pendingCount pending web order${pendingCount > 1 ? 's' : ''}! '
                  'Tap anywhere to enable sound notifications.',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade600,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Enable Sound',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Capture any tap/interaction to enable audio on web
      onTap: _onUserInteraction,
      onPanDown: (_) => _onUserInteraction(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: const AppDrawer(),
        endDrawer: _selectedOrder != null
            ? OrderDetailsDrawer(order: _selectedOrder!)
            : const Drawer(child: SizedBox.shrink()),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            _onUserInteraction();
            _handleAddNewOrder();
          },
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
          child: const Icon(Icons.add, size: 32),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Builder(
                builder: (context) => ListenableBuilder(
                  listenable: _webSocketProvider,
                  builder: (context, _) => ListenableBuilder(
                    listenable: _dataProvider,
                    builder: (context, _) => HeaderWidget(
                      logoUrl: 'https://zipzappos.com',
                      onHomePressed: () {
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      },
                      onDrawerPressed: () {
                        Scaffold.of(context).openDrawer();
                      },
                      onSearchChanged: _handleSearchChanged,
                      serverStatus: true,
                      websocketStatus: _webSocketProvider.status,
                      isServerDown: _webSocketProvider.isServerDown,
                      isRefetching: _dataProvider.isRefetching,
                      onRefresh: () => _loadOrders(forceRefresh: true),
                    ),
                  ),
                ),
              ),
              // Sound notification banner (web only - needs user interaction)
              _buildSoundNotificationBanner(),
              // Filters and Actions Section
              Container(
                padding: const EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 0,
                  bottom: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade300,
                      blurRadius: 2,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: Origin Filter
                    Expanded(
                      child: FilterChips(
                        options: const ['All', 'Online Order', 'Pickup'],
                        selectedOption: _originFilter,
                        onOptionSelected: _handleOriginFilterChanged,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Right: Status Filter + New Order Button (same row)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FilterChips(
                          options: const ['All', 'Pending', 'In Kitchen'],
                          selectedOption: _statusFilter,
                          onOptionSelected: _handleStatusFilterChanged,
                        ),
                        // const SizedBox(width: 12),
                        // SizedBox(
                        //   child: FilledButton.icon(
                        //     onPressed: _handleAddNewOrder,
                        //     icon: const Icon(Icons.add, size: 20),
                        //     label: const Text('Add New Order'),
                        //     style: FilledButton.styleFrom(
                        //       shape: RoundedRectangleBorder(
                        //         borderRadius: BorderRadius.circular(8),
                        //       ),
                        //     ),
                        //   ),
                        // ),
                      ],
                    ),
                  ],
                ),
              ),
              // Orders List
              Expanded(
                child: Stack(
                  children: [
                    _isLoading && _allOrders.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : _errorMessage != null && _allOrders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: Colors.red.shade300,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      _loadOrders(forceRefresh: true),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => _loadOrders(forceRefresh: true),
                            child: _filteredOrders.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.inbox_outlined,
                                          size: 64,
                                          color: Colors.grey.shade400,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No orders found',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : OrderList(
                                    orders: _filteredOrders,
                                    onOrderTap: _handleOrderTap,
                                  ),
                          ),
                    // Show refresh indicator only for manual refresh, not background refresh
                    if (_isRefreshing && !_isBackgroundRefreshing)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(
                          minHeight: 2,
                          backgroundColor: Colors.transparent,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
