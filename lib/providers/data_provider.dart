import 'dart:async';
import 'package:flutter/foundation.dart' hide Category;
import 'package:zipzap_pos_self_orders/core/constants/api_constants.dart';
import 'package:zipzap_pos_self_orders/core/models/api_response.dart';
import 'package:zipzap_pos_self_orders/core/services/websocket_service.dart';
import 'package:zipzap_pos_self_orders/core/services/auth_service.dart';
import 'package:zipzap_pos_self_orders/core/services/cache_service.dart';
import 'package:zipzap_pos_self_orders/models/order_model.dart'
    hide OrderCustomer, OrderModifier;
import 'package:zipzap_pos_self_orders/models/product_model.dart';
import 'package:zipzap_pos_self_orders/models/category_model.dart';
import 'package:zipzap_pos_self_orders/models/modifier_group_model.dart';
import 'package:zipzap_pos_self_orders/models/customer_model.dart';
import 'package:zipzap_pos_self_orders/services/orders_service.dart';
import 'package:zipzap_pos_self_orders/services/products_service.dart';
import 'package:zipzap_pos_self_orders/services/categories_service.dart';
import 'package:zipzap_pos_self_orders/services/customers_service.dart';
import 'package:zipzap_pos_self_orders/services/modifier_groups_service.dart';
import 'package:zipzap_pos_self_orders/services/modifiers_service.dart';
import 'package:zipzap_pos_self_orders/services/stores_service.dart';
import 'package:zipzap_pos_self_orders/services/tax_rules_service.dart';
import 'package:zipzap_pos_self_orders/services/audio_service.dart';
import 'package:zipzap_pos_self_orders/services/notification_service.dart';
import 'package:zipzap_pos_self_orders/providers/websocket_provider.dart';
import 'package:zipzap_pos_self_orders/widgets/data_loading_progress_dialog.dart';

/// Centralized data provider that manages all GET route data
/// Refetches data on WebSocket events and makes it available app-wide
class DataProvider extends ChangeNotifier {
  static final DataProvider _instance = DataProvider._internal();
  factory DataProvider() {
    // Don't auto-initialize - initialization should only happen after authentication
    return _instance;
  }
  DataProvider._internal();

  final OrdersService _ordersService = OrdersService();
  final ProductsService _productsService = ProductsService();
  final CategoriesService _categoriesService = CategoriesService();
  final CustomersService _customersService = CustomersService();
  final ModifierGroupsService _modifierGroupsService = ModifierGroupsService();
  final ModifiersService _modifiersService = ModifiersService();
  final StoresService _storesService = StoresService();
  final TaxRulesService _taxRulesService = TaxRulesService();
  final WebSocketProvider _webSocketProvider = WebSocketProvider();
  final WebSocketService _webSocketService = WebSocketService();
  final AuthService _authService = AuthService();
  final CacheService _cacheService = CacheService();
  final AudioService _audioService = AudioService();
  final NotificationService _notificationService = NotificationService();

  StreamSubscription<WebSocketMessage>? _webSocketSubscription;
  bool _isInitialized = false;
  Future<void>? _initializationFuture;

  // Track previously seen order IDs to detect new orders
  final Set<String> _seenOrderIds = {};

  // Progress tracking
  final Map<String, DataItemProgress> _progressItems = {};
  bool _isInitialLoad = false;

  // Data storage - Orders
  OrdersResponse? _takeoutOrders;
  bool _isLoadingTakeoutOrders = false;
  bool _pendingForceRefresh = false;
  String? _takeoutOrdersError;

  // Data storage - Products
  ProductsResponse? _products;
  bool _isLoadingProducts = false;
  String? _productsError;

  // Data storage - Categories
  CategoriesResponse? _categories;
  bool _isLoadingCategories = false;
  String? _categoriesError;

  // Data storage - Customers
  CustomersResponse? _customers;
  bool _isLoadingCustomers = false;
  String? _customersError;

  // Data storage - Modifier Groups
  ModifierGroupsResponse? _modifierGroups;
  bool _isLoadingModifierGroups = false;
  String? _modifierGroupsError;

  // Data storage - Modifiers
  ModifiersResponse? _modifiers;
  bool _isLoadingModifiers = false;
  String? _modifiersError;

  // Data storage - Store
  StoreDetails? _store;
  bool _isLoadingStore = false;
  String? _storeError;

  // Data storage - Tax Rules
  TaxRulesResponse? _taxRules;
  bool _isLoadingTaxRules = false;
  String? _taxRulesError;

  // Getters - Orders
  OrdersResponse? get takeoutOrders => _takeoutOrders;
  bool get isLoadingTakeoutOrders => _isLoadingTakeoutOrders;
  String? get takeoutOrdersError => _takeoutOrdersError;
  List<Order> get takeoutOrdersList => _takeoutOrders?.orders ?? [];

  // Getters - Products
  ProductsResponse? get products => _products;
  bool get isLoadingProducts => _isLoadingProducts;
  String? get productsError => _productsError;
  List<Product> get productsList => _products?.products ?? [];

  // Getters - Categories
  CategoriesResponse? get categories => _categories;
  bool get isLoadingCategories => _isLoadingCategories;
  String? get categoriesError => _categoriesError;
  List<Category> get categoriesList => _categories?.categories ?? [];

  // Getters - Customers
  CustomersResponse? get customers => _customers;
  bool get isLoadingCustomers => _isLoadingCustomers;
  String? get customersError => _customersError;
  List<Customer> get customersList => _customers?.customers ?? [];

  // Getters - Modifier Groups
  ModifierGroupsResponse? get modifierGroups => _modifierGroups;
  bool get isLoadingModifierGroups => _isLoadingModifierGroups;
  String? get modifierGroupsError => _modifierGroupsError;
  List<ModifierGroup> get modifierGroupsList =>
      _modifierGroups?.modifierGroups ?? [];

  // Getters - Modifiers
  ModifiersResponse? get modifiers => _modifiers;
  bool get isLoadingModifiers => _isLoadingModifiers;
  String? get modifiersError => _modifiersError;
  List<Modifier> get modifiersList => _modifiers?.modifiers ?? [];

  // Getters - Store
  StoreDetails? get store => _store;
  bool get isLoadingStore => _isLoadingStore;
  String? get storeError => _storeError;

  // Getters - Tax Rules
  TaxRulesResponse? get taxRules => _taxRules;
  bool get isLoadingTaxRules => _isLoadingTaxRules;
  String? get taxRulesError => _taxRulesError;
  List<TaxRule> get taxRulesList => _taxRules?.taxRules ?? [];

  // General loading state - returns true if ANY data is being loaded
  bool get isRefetching =>
      _isLoadingTakeoutOrders ||
      _isLoadingProducts ||
      _isLoadingCategories ||
      _isLoadingCustomers ||
      _isLoadingModifierGroups ||
      _isLoadingModifiers ||
      _isLoadingStore ||
      _isLoadingTaxRules;

  // Getters - Progress
  Map<String, DataItemProgress> get progressItems =>
      Map.unmodifiable(_progressItems);
  bool get isInitialLoad => _isInitialLoad;

  // Get takeout orders count (for dashboard)
  int get takeoutOrdersCount {
    if (_takeoutOrders == null) return 0;
    return _takeoutOrders!.orders
        .where(
          (order) =>
              order.orderstatus == ApiConstants.orderStatusPending ||
              order.orderstatus == ApiConstants.orderStatusInKitchen,
        )
        .length;
  }

  void addOptimisticTakeoutOrder(Order newOrder) {
    final existingOrders = _takeoutOrders?.orders ?? [];
    final filteredOrders = existingOrders
        .where((order) => order.id != newOrder.id)
        .toList();
    final updatedOrders = [newOrder, ...filteredOrders];

    _takeoutOrders = OrdersResponse(
      orders: updatedOrders,
      pagination: _takeoutOrders?.pagination,
    );

    notifyListeners();
  }

  /// Add a new customer to the in-memory list (for immediate UI updates after creation)
  void addOptimisticCustomer(Customer newCustomer) {
    final existingCustomers = _customers?.customers ?? [];
    final filteredCustomers = existingCustomers
        .where((customer) => customer.id != newCustomer.id)
        .toList();
    final updatedCustomers = [newCustomer, ...filteredCustomers];

    _customers = CustomersResponse(
      customers: updatedCustomers,
      pagination: _customers?.pagination,
    );

    notifyListeners();
  }

  /// Update an existing customer in the in-memory list (for immediate UI updates)
  void updateCustomerInMemory(Customer updatedCustomer) {
    final existingCustomers = _customers?.customers ?? [];
    final updatedCustomers = existingCustomers.map((customer) {
      if (customer.id == updatedCustomer.id) {
        return updatedCustomer;
      }
      return customer;
    }).toList();

    _customers = CustomersResponse(
      customers: updatedCustomers,
      pagination: _customers?.pagination,
    );

    notifyListeners();
  }

  /// Update an existing order in the in-memory list (for immediate UI updates)
  void updateTakeoutOrderInMemory(Order updatedOrder) {
    if (_takeoutOrders == null) {
      return;
    }

    final orderIndex = _takeoutOrders!.orders.indexWhere(
      (order) => order.id == updatedOrder.id,
    );

    if (orderIndex != -1) {
      // Update the order in the list
      final updatedOrders = List<Order>.from(_takeoutOrders!.orders);
      updatedOrders[orderIndex] = updatedOrder;

      _takeoutOrders = OrdersResponse(
        orders: updatedOrders,
        pagination: _takeoutOrders!.pagination,
      );

      notifyListeners();
    }
  }

  /// Add new order to cache from WebSocket message (OPTIMISTIC UPDATE)
  /// This avoids refetching all orders when a new order is created
  void addOrderToCache(Map<String, dynamic> orderData) {
    try {
      // Parse the new order
      final newOrder = Order.fromJson(orderData);
      final orderId = newOrder.id;

      debugPrint(
        '📦 Adding order to cache: ${newOrder.orderNumber} ($orderId) [type=${newOrder.orderType}]',
      );

      // Only add Pickup orders to the takeout cache (matches API filter)
      if (newOrder.orderType != ApiConstants.orderTypePickup) {
        debugPrint(
          '⏭️ Skipping non-Pickup order ${newOrder.orderNumber} (type=${newOrder.orderType})',
        );
        _seenOrderIds.add(orderId);
        return;
      }

      // Check if order already exists (shouldn't happen, but just in case)
      if (_takeoutOrders != null) {
        final exists = _takeoutOrders!.orders.any(
          (order) => order.id == orderId,
        );

        if (exists) {
          debugPrint('Order already exists, updating instead');
          updateOrderInCache(orderData);
          return;
        }
      }

      // Add new order to the beginning of the list
      final existingOrders = _takeoutOrders?.orders ?? [];
      final updatedOrders = [newOrder, ...existingOrders];

      _takeoutOrders = OrdersResponse(
        orders: updatedOrders,
        pagination: _takeoutOrders?.pagination,
      );

      // Track as seen order
      _seenOrderIds.add(orderId);

      // Check for new web orders and trigger notification
      _checkForNewWebOrders([newOrder]);

      debugPrint(
        '✅ Order added to cache: ${newOrder.orderNumber} (total: ${updatedOrders.length})',
      );

      // Sync to disk cache so stale reads don't overwrite in-memory state
      _ordersService.addOrderToCache(newOrder, existingOrders: updatedOrders);

      // Always update notification loop when orders change
      _updateNotificationLoop();

      // Notify listeners
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error adding order to cache: $e');
      // Fallback: trigger a refetch
      loadTakeoutOrders(forceRefresh: true);
    }
  }

  /// Update order in cache from WebSocket message (OPTIMISTIC UPDATE)
  /// This avoids refetching all orders when an order is updated
  void updateOrderInCache(Map<String, dynamic> orderData) {
    try {
      final updatedOrder = Order.fromJson(orderData);
      final orderId = updatedOrder.id;

      const validTakeoutStatuses = {
        ApiConstants.orderStatusPending,
        ApiConstants.orderStatusInKitchen,
      };
      final isPickup = updatedOrder.orderType == ApiConstants.orderTypePickup;
      final belongsInList =
          isPickup && validTakeoutStatuses.contains(updatedOrder.orderstatus);

      if (_takeoutOrders == null) {
        if (belongsInList) addOrderToCache(orderData);
        return;
      }

      final orderIndex = _takeoutOrders!.orders.indexWhere(
        (order) => order.id == orderId,
      );

      if (orderIndex != -1) {
        final updatedOrders = List<Order>.from(_takeoutOrders!.orders);

        if (belongsInList) {
          updatedOrders[orderIndex] = updatedOrder;
        } else {
          updatedOrders.removeAt(orderIndex);
        }

        _takeoutOrders = OrdersResponse(
          orders: updatedOrders,
          pagination: _takeoutOrders!.pagination,
        );

        // Sync to disk cache so stale reads don't overwrite in-memory state
        _ordersService.updateOrderInCache(updatedOrder);

        _updateNotificationLoop();
        notifyListeners();
      } else if (belongsInList) {
        addOrderToCache(orderData);
      }
    } catch (e) {
      debugPrint('❌ Error updating order in cache: $e');
      loadTakeoutOrders(forceRefresh: true);
    }
  }

  /// Ensure data provider is initialized (must be called after authentication)
  Future<void> ensureInitialized() async {
    // If already initialized, return immediately
    if (_isInitialized) {
      return;
    }

    // If initialization is in progress, wait for it to complete
    if (_initializationFuture != null) {
      debugPrint(
        'DataProvider: Waiting for ongoing initialization to complete',
      );
      await _initializationFuture;
      return;
    }

    // Start new initialization
    debugPrint('DataProvider: Starting initialization');
    _initializationFuture = _initialize();

    try {
      await _initializationFuture;
      _isInitialized = true;
      debugPrint('DataProvider: Initialization completed successfully');
    } catch (e) {
      debugPrint('DataProvider: Initialization failed: $e');
      rethrow;
    } finally {
      _initializationFuture = null;
    }
  }

  Future<void> _initialize() async {
    // Cancel existing WebSocket subscription to prevent duplicates
    await _webSocketSubscription?.cancel();
    _webSocketSubscription = null;

    // Check if we have any cached data
    final hasCache = await _hasAnyCache();
    _isInitialLoad = !hasCache;

    // Initialize progress tracking if this is initial load
    if (_isInitialLoad) {
      _initializeProgressTracking();
    }

    // Load initial data sequentially to track progress
    if (_isInitialLoad) {
      await _loadDataWithProgress();
    } else {
      // Load tax rules first so OrderItem.fromJson can resolve string taxRule IDs,
      // then load everything else in parallel
      await loadTaxRules();
      await Future.wait([
        loadTakeoutOrders(),
        loadProducts(),
        loadCategories(),
        loadCustomers(),
        loadModifierGroups(),
        loadModifiers(),
        loadStore(),
      ]);
    }

    // Listen to WebSocket service messages directly for automatic refetching
    // This handles messages that are NOT handled by WebSocketProvider with optimistic updates
    // IMPORTANT: Only create ONE subscription per DataProvider instance
    _webSocketSubscription = _webSocketService.messages.listen((message) {
      // Skip messages handled by WebSocketProvider with optimistic updates
      // to prevent duplicate processing
      if (message.type != 'order_created' &&
          message.type != 'order_updated' &&
          message.type != 'order_status_changed' &&
          message.type != 'customer_created' &&
          message.type != 'customer_updated' &&
          message.type != 'product_updated' &&
          message.type != 'category_updated' &&
          message.type != 'floor_plan_updated' &&
          message.type != 'table_status_updated' &&
          message.type != 'modifier_updated' &&
          message.type != 'modifier_group_updated' &&
          message.type != 'profile_updated' &&
          message.type != 'user_updated' &&
          message.type != 'role_updated' &&
          message.type != 'store_updated') {
        _handleWebSocketMessage(message);
      }
    });

    // Note: We don't need to listen to WebSocketProvider for order events
    // as they're already handled by the direct WebSocket listener above.
    // The provider listener is kept for potential future use with other message types.
  }

  // Check if any cache exists
  Future<bool> _hasAnyCache() async {
    try {
      final cacheKeys = [
        ApiConstants.cacheKeyTakeoutOrdersTimestamp,
        ApiConstants.cacheKeyProductsTimestamp,
        ApiConstants.cacheKeyCategoriesTimestamp,
        ApiConstants.cacheKeyCustomersTimestamp,
        ApiConstants.cacheKeyModifierGroupsTimestamp,
        ApiConstants.cacheKeyModifiersTimestamp,
        'store_details_timestamp',
      ];

      for (final key in cacheKeys) {
        final timestamp = await _cacheService.getTimestamp(key);
        if (timestamp != null) {
          final isValid = await _cacheService.isCacheValid(
            key,
            ApiConstants.cacheDuration,
          );
          if (isValid) {
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error checking cache: $e');
      return false;
    }
  }

  // Initialize progress tracking
  void _initializeProgressTracking() {
    _progressItems.clear();
    _progressItems['Profile'] = DataItemProgress(name: 'Profile');
    _progressItems['Categories'] = DataItemProgress(name: 'Categories');
    _progressItems['Products'] = DataItemProgress(name: 'Products');
    _progressItems['Modifiers'] = DataItemProgress(name: 'Modifiers');
    _progressItems['Modifier Groups'] = DataItemProgress(
      name: 'Modifier Groups',
    );
    _progressItems['Customers'] = DataItemProgress(name: 'Customers');
    _progressItems['Takeout Orders'] = DataItemProgress(name: 'Takeout Orders');
    _progressItems['Store'] = DataItemProgress(name: 'Store');
    _progressItems['Tax Rules'] = DataItemProgress(name: 'Tax Rules');
    notifyListeners();
  }

  // Load data with progress tracking
  Future<void> _loadDataWithProgress() async {
    // Load profile first (required for other data)
    await _updateProgressAndLoad('Profile', () => _loadProfile());

    await _updateProgressAndLoad(
      'Categories',
      () => loadCategories(forceRefresh: true),
    );
    await _updateProgressAndLoad(
      'Products',
      () => loadProducts(forceRefresh: true),
    );
    await _updateProgressAndLoad(
      'Modifiers',
      () => loadModifiers(forceRefresh: true),
    );
    await _updateProgressAndLoad(
      'Modifier Groups',
      () => loadModifierGroups(forceRefresh: true),
    );
    await _updateProgressAndLoad(
      'Customers',
      () => loadCustomers(forceRefresh: true),
    );
    await _updateProgressAndLoad('Store', () => loadStore(forceRefresh: true));
    await _updateProgressAndLoad(
      'Tax Rules',
      () => loadTaxRules(forceRefresh: true),
    );
    await _updateProgressAndLoad(
      'Takeout Orders',
      () => loadTakeoutOrders(forceRefresh: true),
    );

    // Reset initial load flag after all data is loaded
    _isInitialLoad = false;
  }

  // Load profile from API
  Future<void> _loadProfile() async {
    try {
      await _authService.fetchProfile();
    } catch (e) {
      debugPrint('Error loading profile: $e');
      rethrow;
    }
  }

  // Update progress and load data
  Future<void> _updateProgressAndLoad(
    String itemName,
    Future<void> Function() loadFunction,
  ) async {
    if (_progressItems.containsKey(itemName)) {
      _progressItems[itemName]!.status = DataItemStatus.loading;
      _progressItems[itemName]!.progress = 0.0;
      notifyListeners();
    }

    try {
      await loadFunction();
      if (_progressItems.containsKey(itemName)) {
        _progressItems[itemName]!.status = DataItemStatus.completed;
        _progressItems[itemName]!.progress = 1.0;
        notifyListeners();
      }
    } catch (e) {
      if (_progressItems.containsKey(itemName)) {
        _progressItems[itemName]!.status = DataItemStatus.error;
        _progressItems[itemName]!.progress = 0.0;
        notifyListeners();
      }
    }
  }

  void _onWebSocketProviderUpdate() {
    // This is called when WebSocketProvider notifies after updates
    // Skip messages that are handled by WebSocketProvider with direct cache updates
    final lastMessage = _webSocketProvider.lastMessage;
    if (lastMessage != null) {
      // Skip messages handled by WebSocketProvider with optimistic updates
      // to prevent duplicate refetches
      if (lastMessage.type != 'order_created' &&
          lastMessage.type != 'order_updated' &&
          lastMessage.type != 'order_status_changed' &&
          lastMessage.type != 'customer_created' &&
          lastMessage.type != 'customer_updated' &&
          lastMessage.type != 'product_updated' &&
          lastMessage.type != 'category_updated' &&
          lastMessage.type != 'floor_plan_updated' &&
          lastMessage.type != 'table_status_updated' &&
          lastMessage.type != 'modifier_updated' &&
          lastMessage.type != 'modifier_group_updated' &&
          lastMessage.type != 'profile_updated' &&
          lastMessage.type != 'user_updated' &&
          lastMessage.type != 'role_updated' &&
          lastMessage.type != 'store_updated') {
        _handleWebSocketMessage(lastMessage);
      }
    }
  }

  void _handleWebSocketMessage(WebSocketMessage message) {
    switch (message.type) {
      case 'order_created':
      case 'order_updated':
      case 'order_status_changed':
        // ✅ OPTIMISTIC UPDATE: These events are now handled by WebSocketProvider
        // which updates the cache directly without refetching all orders.
        // WebSocketProvider calls addOrderToCache() or updateOrderInCache()
        // so we don't need to do anything here.
        debugPrint(
          '📦 Order event (${message.type}) - handled by WebSocketProvider with optimistic update',
        );
        break;

      case 'customer_created':
      case 'customer_updated':
        // ✅ Customer events are handled in WebSocketProvider
        // which updates the cache directly without refetching
        break;

      case 'product_updated':
        // Handled by WebSocketProvider with optimistic cache update
        break;

      case 'category_updated':
        // Handled by WebSocketProvider with optimistic cache update
        break;

      case 'modifier_group_updated':
        // Handled by WebSocketProvider with optimistic cache update
        break;

      case 'modifier_updated':
        // Handled by WebSocketProvider with optimistic cache update
        break;

      case 'store_updated':
        // Refetch store when store events occur
        loadStore(forceRefresh: true);
        break;
    }
  }

  /// Load takeout orders (called automatically on WebSocket events)
  Future<void> loadTakeoutOrders({
    bool forceRefresh = false,
    List<String>? orderStatuses,
  }) async {
    // If already loading, queue a forced refresh instead of dropping it
    if (_isLoadingTakeoutOrders) {
      if (forceRefresh) {
        _pendingForceRefresh = true;
        debugPrint('Takeout orders already loading, queued force refresh');
      }
      return;
    }

    _isLoadingTakeoutOrders = true;
    _takeoutOrdersError = null;
    notifyListeners();

    try {
      final response = await _ordersService.getTakeoutOrders(
        forceRefresh: forceRefresh,
        orderstatuses: orderStatuses,
      );

      _takeoutOrders = response;
      _takeoutOrdersError = null;

      // Check for new web orders and update notification loop
      _checkForNewWebOrders(response.orders);
      _updateNotificationLoop();
    } catch (e) {
      _takeoutOrdersError = e.toString();
      debugPrint('Error loading takeout orders in DataProvider: $e');
    } finally {
      _isLoadingTakeoutOrders = false;
      notifyListeners();

      // If a force refresh was queued while we were loading, execute it now
      if (_pendingForceRefresh) {
        _pendingForceRefresh = false;
        loadTakeoutOrders(forceRefresh: true);
      }
    }
  }

  /// Get takeout orders with specific statuses (for dashboard count)
  Future<void> loadTakeoutOrdersCount({List<String>? orderStatuses}) async {
    // Use the same method but with specific statuses
    await loadTakeoutOrders(
      orderStatuses:
          orderStatuses ??
          [ApiConstants.orderStatusPending, ApiConstants.orderStatusInKitchen],
    );
  }

  /// Check for new web orders and trigger notifications
  void _checkForNewWebOrders(List<Order> newOrders) {
    bool hasNewWebOrder = false;

    for (final order in newOrders) {
      // Check if this is a new order (not seen before)
      if (!_seenOrderIds.contains(order.id)) {
        // Check if it's a Pending web order (AI or WEB origin)
        final isPending = order.orderstatus == 'Pending';
        final isWebOrder = order.origin == 'AI' || order.origin == 'WEB';

        if (isPending && isWebOrder) {
          debugPrint('🔕 Order notifications are disabled for #${order.orderNumber}');
        }

        // Add to seen orders
        _seenOrderIds.add(order.id);
      }
    }

    // If we found at least one new web order, update the notification loop
    if (hasNewWebOrder) {
      _updateNotificationLoop();
    }
  }

  /// Update notification loop based on pending web orders
  void _updateNotificationLoop() {
    // Count pending web orders
    final pendingWebOrdersCount = takeoutOrdersList.where((order) {
      final isPending = order.orderstatus == 'Pending';
      final isWebOrder = order.origin == 'AI' || order.origin == 'WEB';
      return isPending && isWebOrder;
    }).length;

    if (pendingWebOrdersCount > 0) {
      // Start loop if not already playing
      if (!_audioService.isNotificationLoopPlaying) {
        _audioService.playNotificationLoop();
      }
    } else {
      // Stop loop if no pending web orders
      if (_audioService.isNotificationLoopPlaying) {
        _audioService.stopNotificationLoop();
      }
    }
  }

  /// Public method to check and update notification loop state
  /// Call this when the takeout page is displayed or app comes to foreground
  void checkNotificationLoop() {
    _updateNotificationLoop();
  }

  /// Get count of pending web orders
  int get pendingWebOrdersCount {
    return takeoutOrdersList.where((order) {
      final isPending = order.orderstatus == 'Pending';
      final isWebOrder = order.origin == 'AI' || order.origin == 'WEB';
      return isPending && isWebOrder;
    }).length;
  }

  /// Invalidate cache for takeout orders
  void invalidateTakeoutOrders() {
    _ordersService.invalidateCache();
    _takeoutOrders = null;
    notifyListeners();
  }

  /// Load products (called automatically on WebSocket events)
  Future<void> loadProducts({
    bool forceRefresh = false,
    String? storeId,
  }) async {
    // Prevent duplicate calls
    if (_isLoadingProducts && !forceRefresh) return;

    _isLoadingProducts = true;
    _productsError = null;
    notifyListeners();

    try {
      // Get storeId from internal store (source of truth) if not provided
      final finalStoreId =
          storeId ?? _store?.id ?? _authService.getProfile()?.storeId;

      final response = await _productsService.getProducts(
        forceRefresh: forceRefresh,
        storeId: finalStoreId,
      );

      _products = response;
      _productsError = null;
      debugPrint(
        'Products loaded successfully: ${_products?.products.length ?? 0} items',
      );
    } catch (e) {
      _productsError = e.toString();
      debugPrint('Error loading products in DataProvider: $e');
    } finally {
      _isLoadingProducts = false;
      notifyListeners();
    }
  }

  /// Invalidate cache for products
  void invalidateProducts() {
    _productsService.invalidateCache();
    _products = null;
    notifyListeners();
  }

  /// Update product in cache from WebSocket message (OPTIMISTIC UPDATE)
  /// This avoids refetching all products when a product is updated
  void updateProductInCache(
    Map<String, dynamic> productData, {
    String action = 'updated',
  }) {
    try {
      final updatedProduct = Product.fromJson(productData);
      final productId = updatedProduct.id;

      if (_products == null) return;

      if (action == 'deleted') {
        final updatedList = _products!.products
            .where((product) => product.id != productId)
            .toList();

        _products = ProductsResponse(
          products: updatedList,
          pagination: _products!.pagination,
        );
      } else if (action == 'created') {
        final exists = _products!.products.any(
          (product) => product.id == productId,
        );

        if (!exists) {
          final updatedList = [updatedProduct, ..._products!.products];
          _products = ProductsResponse(
            products: updatedList,
            pagination: _products!.pagination,
          );
        }
      } else {
        final productIndex = _products!.products.indexWhere(
          (product) => product.id == productId,
        );

        if (productIndex != -1) {
          final updatedList = List<Product>.from(_products!.products);
          updatedList[productIndex] = updatedProduct;

          _products = ProductsResponse(
            products: updatedList,
            pagination: _products!.pagination,
          );
        } else {
          // Product not found, add it
          final updatedList = [updatedProduct, ..._products!.products];
          _products = ProductsResponse(
            products: updatedList,
            pagination: _products!.pagination,
          );
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error updating product in cache: $e');
      loadProducts(forceRefresh: true);
    }
  }

  /// Load categories (called automatically on WebSocket events)
  Future<void> loadCategories({
    bool forceRefresh = false,
    String? storeId,
  }) async {
    // Prevent duplicate calls
    if (_isLoadingCategories && !forceRefresh) return;

    _isLoadingCategories = true;
    _categoriesError = null;
    notifyListeners();

    try {
      // Get storeId from internal store (source of truth) if not provided
      final finalStoreId =
          storeId ?? _store?.id ?? _authService.getProfile()?.storeId;

      final response = await _categoriesService.getCategories(
        forceRefresh: forceRefresh,
        storeId: finalStoreId,
      );

      _categories = response;
      _categoriesError = null;
    } catch (e) {
      _categoriesError = e.toString();
      debugPrint('Error loading categories in DataProvider: $e');
    } finally {
      _isLoadingCategories = false;
      notifyListeners();
    }
  }

  /// Invalidate cache for categories
  void invalidateCategories() {
    _categoriesService.invalidateCache();
    _categories = null;
    notifyListeners();
  }

  /// Update category in cache from WebSocket message (OPTIMISTIC UPDATE)
  void updateCategoryInCache(
    Map<String, dynamic> categoryData, {
    String action = 'updated',
  }) {
    if (_categories == null) return;

    try {
      final updatedCategory = Category.fromJson(categoryData);
      final categoryId = updatedCategory.id;

      if (action == 'deleted') {
        // Remove category from cache (or mark as inactive)
        final updatedList = _categories!.categories
            .where((cat) => cat.id != categoryId)
            .toList();

        _categories = CategoriesResponse(
          categories: updatedList,
          pagination: _categories!.pagination,
        );
      } else if (action == 'created') {
        // Add new category to cache
        final exists = _categories!.categories.any(
          (cat) => cat.id == categoryId,
        );

        if (!exists) {
          final updatedList = [updatedCategory, ..._categories!.categories];
          _categories = CategoriesResponse(
            categories: updatedList,
            pagination: _categories!.pagination,
          );
        }
      } else {
        // Update existing category
        final categoryIndex = _categories!.categories.indexWhere(
          (cat) => cat.id == categoryId,
        );

        if (categoryIndex != -1) {
          final updatedList = List<Category>.from(_categories!.categories);
          updatedList[categoryIndex] = updatedCategory;

          _categories = CategoriesResponse(
            categories: updatedList,
            pagination: _categories!.pagination,
          );
        } else {
          // Category not found, add it
          final updatedList = [updatedCategory, ..._categories!.categories];
          _categories = CategoriesResponse(
            categories: updatedList,
            pagination: _categories!.pagination,
          );
        }
      }

      _categoriesService.cacheCategoriesData(_categories!);
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating category in cache: $e');
      loadCategories(forceRefresh: true);
    }
  }

  /// Load customers (called automatically on WebSocket events)
  Future<void> loadCustomers({
    bool forceRefresh = false,
    int? limit,
    int? page,
  }) async {
    // Prevent duplicate calls
    if (_isLoadingCustomers && !forceRefresh) return;

    _isLoadingCustomers = true;
    _customersError = null;
    notifyListeners();

    try {
      final response = await _customersService.getCustomers(
        forceRefresh: forceRefresh,
        limit: limit,
        page: page,
      );

      // If this is a paginated request and we already have customers, merge them
      if (page != null && page > 1 && _customers != null) {
        // Merge new customers with existing ones
        final existingCustomers = _customers!.customers;
        final newCustomers = response.customers;
        final allCustomers = [...existingCustomers, ...newCustomers];

        _customers = CustomersResponse(
          customers: allCustomers,
          pagination: response.pagination,
        );
        debugPrint(
          'Merged customers: ${_customers!.customers.length} total (added ${newCustomers.length} from page $page)',
        );
      } else {
        _customers = response;
      }

      _customersError = null;

      // If this is the initial load with pagination and there are more pages,
      // fetch remaining pages in background
      if (limit != null &&
          page == 1 &&
          response.pagination?.hasNextPage == true) {
        debugPrint(
          'Starting background fetch for remaining ${response.pagination!.totalPages - 1} pages',
        );
        _fetchRemainingCustomers(
          totalPages: response.pagination!.totalPages,
          limit: limit,
        );
      }
    } catch (e) {
      _customersError = e.toString();
      debugPrint('Error loading customers in DataProvider: $e');
    } finally {
      _isLoadingCustomers = false;
      notifyListeners();
    }
  }

  /// Fetch remaining customer pages in background
  Future<void> _fetchRemainingCustomers({
    required int totalPages,
    required int limit,
  }) async {
    // Start from page 2 (page 1 already loaded)
    for (int page = 2; page <= totalPages; page++) {
      try {
        debugPrint('Fetching customers page $page of $totalPages');
        final response = await _customersService.getCustomers(
          limit: limit,
          page: page,
        );

        // Merge with existing customers
        if (_customers != null) {
          final existingCustomers = _customers!.customers;
          final newCustomers = response.customers;
          final allCustomers = [...existingCustomers, ...newCustomers];

          _customers = CustomersResponse(
            customers: allCustomers,
            pagination: response.pagination,
          );

          debugPrint(
            'Background fetch: ${_customers!.customers.length} total customers (page $page/$totalPages)',
          );
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Error fetching customers page $page: $e');
        // Continue with next page even if one fails
      }
    }

    debugPrint(
      'Background fetch complete: ${_customers?.customers.length ?? 0} total customers',
    );

    // Cache all customers after background fetch completes
    if (_customers != null) {
      try {
        await _customersService.cacheCustomersData(_customers!);
        debugPrint('Cached all ${_customers!.customers.length} customers');
      } catch (e) {
        debugPrint('Error caching customers after background fetch: $e');
      }
    }
  }

  /// Invalidate cache for customers
  void invalidateCustomers() {
    _customersService.invalidateCache();
    _customers = null;
    notifyListeners();
  }

  /// Add new customer to cache from WebSocket message (OPTIMISTIC UPDATE)
  void addCustomerToCache(Map<String, dynamic> customerData) {
    if (_customers == null) return;

    try {
      final newCustomer = Customer.fromJson(customerData);

      // Check if customer already exists
      final exists = _customers!.customers.any(
        (customer) => customer.id == newCustomer.id,
      );

      if (exists) {
        updateCustomerInCache(customerData);
        return;
      }

      // Add new customer to the beginning of the list
      final updatedList = [newCustomer, ..._customers!.customers];
      _customers = CustomersResponse(
        customers: updatedList,
        pagination: _customers!.pagination,
      );

      _customersService.cacheCustomersData(_customers!);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding customer to cache: $e');
    }
  }

  /// Update customer in cache from WebSocket message
  /// Update customer in cache from WebSocket message (OPTIMISTIC UPDATE)
  void updateCustomerInCache(Map<String, dynamic> customerData) {
    if (_customers == null) return;

    try {
      final updatedCustomer = Customer.fromJson(customerData);

      final customerIndex = _customers!.customers.indexWhere(
        (customer) => customer.id == updatedCustomer.id,
      );

      if (customerIndex != -1) {
        final updatedList = List<Customer>.from(_customers!.customers);
        updatedList[customerIndex] = updatedCustomer;

        _customers = CustomersResponse(
          customers: updatedList,
          pagination: _customers!.pagination,
        );
      } else {
        // Customer not found, add it
        final updatedList = [updatedCustomer, ..._customers!.customers];
        _customers = CustomersResponse(
          customers: updatedList,
          pagination: _customers!.pagination,
        );
      }

      _customersService.cacheCustomersData(_customers!);
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating customer in cache: $e');
    }
  }

  /// Load modifier groups (called automatically on WebSocket events)
  Future<void> loadModifierGroups({
    bool forceRefresh = false,
    String? storeId,
  }) async {
    // Prevent duplicate calls
    if (_isLoadingModifierGroups && !forceRefresh) return;

    _isLoadingModifierGroups = true;
    _modifierGroupsError = null;
    notifyListeners();

    try {
      // Get storeId from internal store (source of truth) if not provided
      final finalStoreId =
          storeId ?? _store?.id ?? _authService.getProfile()?.storeId;

      final response = await _modifierGroupsService.getModifierGroups(
        forceRefresh: forceRefresh,
        storeId: finalStoreId,
      );

      _modifierGroups = response;
      _modifierGroupsError = null;
    } catch (e) {
      _modifierGroupsError = e.toString();
      debugPrint('Error loading modifier groups in DataProvider: $e');
    } finally {
      _isLoadingModifierGroups = false;
      notifyListeners();
    }
  }

  /// Invalidate cache for modifier groups
  void invalidateModifierGroups() {
    _modifierGroupsService.invalidateCache();
    _modifierGroups = null;
    notifyListeners();
  }

  /// Load modifiers (called automatically on WebSocket events)
  Future<void> loadModifiers({
    bool forceRefresh = false,
    String? storeId,
  }) async {
    // Prevent duplicate calls
    if (_isLoadingModifiers && !forceRefresh) return;

    _isLoadingModifiers = true;
    _modifiersError = null;
    notifyListeners();

    try {
      // Get storeId from internal store (source of truth) if not provided
      final finalStoreId =
          storeId ?? _store?.id ?? _authService.getProfile()?.storeId;

      final response = await _modifiersService.getModifiers(
        forceRefresh: forceRefresh,
        storeId: finalStoreId,
      );

      _modifiers = response;
      _modifiersError = null;
    } catch (e) {
      _modifiersError = e.toString();
      debugPrint('Error loading modifiers in DataProvider: $e');
    } finally {
      _isLoadingModifiers = false;
      notifyListeners();
    }
  }

  /// Invalidate cache for modifiers
  void invalidateModifiers() {
    _modifiersService.invalidateCache();
    _modifiers = null;
    notifyListeners();
  }

  /// Update modifier in cache from WebSocket message (OPTIMISTIC UPDATE)
  void updateModifierInCache(
    Map<String, dynamic> modifierData, {
    String action = 'updated',
  }) {
    if (_modifiers == null) return;

    try {
      final updatedModifier = Modifier.fromJson(modifierData);
      final modifierId = updatedModifier.id;

      if (action == 'deleted') {
        final updatedList = _modifiers!.modifiers
            .where((modifier) => modifier.id != modifierId)
            .toList();
        _modifiers = ModifiersResponse(
          modifiers: updatedList,
          pagination: _modifiers!.pagination,
        );
      } else if (action == 'created') {
        final exists = _modifiers!.modifiers.any(
          (modifier) => modifier.id == modifierId,
        );
        if (!exists) {
          final updatedList = [updatedModifier, ..._modifiers!.modifiers];
          _modifiers = ModifiersResponse(
            modifiers: updatedList,
            pagination: _modifiers!.pagination,
          );
        }
      } else {
        final modifierIndex = _modifiers!.modifiers.indexWhere(
          (modifier) => modifier.id == modifierId,
        );
        if (modifierIndex != -1) {
          final updatedList = List<Modifier>.from(_modifiers!.modifiers);
          updatedList[modifierIndex] = updatedModifier;
          _modifiers = ModifiersResponse(
            modifiers: updatedList,
            pagination: _modifiers!.pagination,
          );
        } else {
          final updatedList = [updatedModifier, ..._modifiers!.modifiers];
          _modifiers = ModifiersResponse(
            modifiers: updatedList,
            pagination: _modifiers!.pagination,
          );
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error updating modifier in cache: $e');
      loadModifiers(forceRefresh: true);
    }
  }

  /// Update modifier group in cache from WebSocket message (OPTIMISTIC UPDATE)
  void updateModifierGroupInCache(
    Map<String, dynamic> modifierGroupData, {
    String action = 'updated',
  }) {
    if (_modifierGroups == null) return;

    try {
      final updatedModifierGroup = ModifierGroup.fromJson(modifierGroupData);
      final modifierGroupId = updatedModifierGroup.id;

      if (action == 'deleted') {
        final updatedList = _modifierGroups!.modifierGroups
            .where((group) => group.id != modifierGroupId)
            .toList();
        _modifierGroups = ModifierGroupsResponse(
          modifierGroups: updatedList,
          pagination: _modifierGroups!.pagination,
        );
      } else if (action == 'created') {
        final exists = _modifierGroups!.modifierGroups.any(
          (group) => group.id == modifierGroupId,
        );
        if (!exists) {
          final updatedList = [
            updatedModifierGroup,
            ..._modifierGroups!.modifierGroups,
          ];
          _modifierGroups = ModifierGroupsResponse(
            modifierGroups: updatedList,
            pagination: _modifierGroups!.pagination,
          );
        }
      } else {
        final groupIndex = _modifierGroups!.modifierGroups.indexWhere(
          (group) => group.id == modifierGroupId,
        );
        if (groupIndex != -1) {
          final updatedList = List<ModifierGroup>.from(
            _modifierGroups!.modifierGroups,
          );
          updatedList[groupIndex] = updatedModifierGroup;
          _modifierGroups = ModifierGroupsResponse(
            modifierGroups: updatedList,
            pagination: _modifierGroups!.pagination,
          );
        } else {
          final updatedList = [
            updatedModifierGroup,
            ..._modifierGroups!.modifierGroups,
          ];
          _modifierGroups = ModifierGroupsResponse(
            modifierGroups: updatedList,
            pagination: _modifierGroups!.pagination,
          );
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error updating modifier group in cache: $e');
      loadModifierGroups(forceRefresh: true);
    }
  }

  /// Load store (called automatically on WebSocket events)
  Future<void> loadStore({bool forceRefresh = false, String? slugOrId}) async {
    // Prevent duplicate calls
    if (_isLoadingStore && !forceRefresh) return;

    _isLoadingStore = true;
    _storeError = null;
    notifyListeners();

    try {
      final response = await _storesService.getStoreBySlugOrId(
        slugOrId: slugOrId,
        forceRefresh: forceRefresh,
      );

      _store = response;
      _storeError = null;
    } catch (e) {
      _storeError = e.toString();
      debugPrint('Error loading store in DataProvider: $e');
    } finally {
      _isLoadingStore = false;
      notifyListeners();
    }
  }

  /// Invalidate cache for store
  void invalidateStore() {
    _storesService.invalidateCache();
    _store = null;
    notifyListeners();
  }

  /// Update store in cache from WebSocket (optimistic update)
  void updateStoreInCache(dynamic storeData, String action) {
    try {
      if (storeData == null) return;

      final storeMap = storeData is Map<String, dynamic>
          ? storeData
          : <String, dynamic>{};

      final storeId = storeMap['_id']?.toString() ?? storeMap['id']?.toString();

      if (action == 'deleted') {
        // If store is deleted, clear the cache
        if (_store?.id == storeId) {
          _store = null;
          _storesService.invalidateCache();
          notifyListeners();
        }
        return;
      }

      // Only update if this is the current store
      if (_store != null && _store!.id == storeId) {
        // Parse the updated store
        final updatedStore = StoreDetails.fromJson(storeMap);
        _store = updatedStore;
        _storesService.invalidateCache(); // Invalidate service cache too
        notifyListeners();
        debugPrint(
          '✅ Store updated in DataProvider cache: ${updatedStore.name}',
        );
      }
    } catch (e) {
      debugPrint('Error updating store in cache: $e');
      // Fallback: invalidate cache to force refetch
      invalidateStore();
    }
  }

  /// Update store status via API
  /// Returns true on success, false on failure
  Future<bool> updateStoreStatus(String status) async {
    final storeId = _store?.id;
    if (storeId == null || storeId.isEmpty) {
      debugPrint('Cannot update store status: store ID is null');
      return false;
    }

    try {
      final updatedStore = await _storesService.updateStoreStatus(
        storeId: storeId,
        status: status,
      );

      _store = updatedStore;
      notifyListeners();
      debugPrint('✅ Store status updated to: $status');
      return true;
    } catch (e) {
      debugPrint('Error updating store status: $e');
      return false;
    }
  }

  // Load tax rules from API
  Future<void> loadTaxRules({bool forceRefresh = false}) async {
    // Prevent duplicate calls
    if (_isLoadingTaxRules && !forceRefresh) return;

    _isLoadingTaxRules = true;
    _taxRulesError = null;
    notifyListeners();

    try {
      final response = await _taxRulesService.getTaxRules(
        forceRefresh: forceRefresh,
      );

      _taxRules = response;
      _taxRulesError = null;
    } catch (e) {
      _taxRulesError = e.toString();
      debugPrint('Error loading tax rules in DataProvider: $e');
    } finally {
      _isLoadingTaxRules = false;
      notifyListeners();
    }
  }

  /// Invalidate cache for tax rules
  void invalidateTaxRules() {
    _taxRulesService.invalidateCache();
    _taxRules = null;
    notifyListeners();
  }

  /// Clear all cached data (for logout)
  void clearAllData() {
    // Invalidate all caches
    _ordersService.invalidateCache();
    _productsService.invalidateCache();
    _categoriesService.invalidateCache();
    _customersService.invalidateCache();
    _modifierGroupsService.invalidateCache();
    _modifiersService.invalidateCache();
    _storesService.invalidateCache();

    // Clear all data
    _takeoutOrders = null;
    _products = null;
    _categories = null;
    _customers = null;
    _modifierGroups = null;
    _modifiers = null;
    _store = null;

    // Clear errors
    _takeoutOrdersError = null;
    _productsError = null;
    _categoriesError = null;
    _customersError = null;
    _modifierGroupsError = null;
    _modifiersError = null;
    _storeError = null;

    // Reset loading states
    _isLoadingTakeoutOrders = false;
    _isLoadingProducts = false;
    _isLoadingCategories = false;
    _isLoadingCustomers = false;
    _isLoadingModifierGroups = false;
    _isLoadingModifiers = false;
    _isLoadingStore = false;

    // Reset initialization state so data can be fetched again after login
    _isInitialized = false;
    _isInitialLoad = false;
    _initializationFuture = null;
    _progressItems.clear();

    // Clear seen order IDs and stop notification loop
    _seenOrderIds.clear();
    _audioService.stopNotificationLoop();

    notifyListeners();
  }

  /// Re-initialize data (for after login)
  Future<void> reinitialize({bool forceRefresh = false}) async {
    // Wait for any ongoing initialization to complete first
    if (_initializationFuture != null) {
      debugPrint(
        'DataProvider: Waiting for ongoing initialization before reinitializing',
      );
      await _initializationFuture;
    }

    // Set isInitialLoad immediately if force refresh
    // This allows UI to detect it before async operations complete
    if (forceRefresh) {
      _isInitialLoad = true;
      _initializeProgressTracking();
      notifyListeners();

      // Clear all cache to force fresh data fetch
      await _clearAllCache();
    }

    // Start new initialization atomically (set future before resetting flag)
    debugPrint('DataProvider: Starting reinitialization');

    // Atomically reset state and start initialization
    // This prevents race conditions where ensureInitialized() could be called
    // between resetting _isInitialized and setting _initializationFuture
    _isInitialized = false;
    _initializationFuture = _initialize();

    try {
      await _initializationFuture;
      _isInitialized = true;
      debugPrint('DataProvider: Reinitialization completed successfully');
    } catch (e) {
      debugPrint('DataProvider: Reinitialization failed: $e');
      rethrow;
    } finally {
      _initializationFuture = null;
    }
  }

  // Clear all cached data
  Future<void> _clearAllCache() async {
    try {
      await _cacheService.remove(ApiConstants.cacheKeyTakeoutOrders);
      await _cacheService.remove(ApiConstants.cacheKeyTakeoutOrdersTimestamp);
      await _cacheService.remove(ApiConstants.cacheKeyProducts);
      await _cacheService.remove(ApiConstants.cacheKeyProductsTimestamp);
      await _cacheService.remove(ApiConstants.cacheKeyCategories);
      await _cacheService.remove(ApiConstants.cacheKeyCategoriesTimestamp);
      await _cacheService.remove(ApiConstants.cacheKeyCustomers);
      await _cacheService.remove(ApiConstants.cacheKeyCustomersTimestamp);
      await _cacheService.remove(ApiConstants.cacheKeyModifierGroups);
      await _cacheService.remove(ApiConstants.cacheKeyModifierGroupsTimestamp);
      await _cacheService.remove(ApiConstants.cacheKeyModifiers);
      await _cacheService.remove(ApiConstants.cacheKeyModifiersTimestamp);
      await _cacheService.remove('store_details');
      await _cacheService.remove('store_details_timestamp');
      debugPrint('All cache cleared');
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  @override
  void dispose() {
    _webSocketSubscription?.cancel();
    _webSocketProvider.removeListener(_onWebSocketProviderUpdate);
    _audioService.stopNotificationLoop();
    super.dispose();
  }
}
