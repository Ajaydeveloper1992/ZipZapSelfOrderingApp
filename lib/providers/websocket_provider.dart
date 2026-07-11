import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/core/services/websocket_service.dart';
import 'package:zipzap_pos_self_orders/core/services/auth_service.dart';
import 'package:zipzap_pos_self_orders/providers/data_provider.dart';

/// WebSocket Provider for managing WebSocket connections and events
class WebSocketProvider extends ChangeNotifier with WidgetsBindingObserver {
  static final WebSocketProvider _instance = WebSocketProvider._internal();
  factory WebSocketProvider() {
    _instance._ensureInitialized();
    return _instance;
  }
  WebSocketProvider._internal();

  final WebSocketService _webSocketService = WebSocketService();
  final AuthService _authService = AuthService();

  StreamSubscription<WebSocketMessage>? _messageSubscription;
  Timer? _debounceTimer;
  Timer? _statusUpdateTimer;
  bool _isRefetching = false; // Track if refetch is in progress
  static const int debounceDelay = 1000; // 1 second debounce

  // Track previous status to detect changes
  WebSocketStatus? _previousStatus;
  bool? _previousIsServerDown;

  // Status
  WebSocketStatus get status => _webSocketService.status;
  bool get isConnected => _webSocketService.isConnected;
  bool get isServerDown => _webSocketService.isServerDown;
  int get reconnectAttempts => _webSocketService.reconnectAttempts;
  int get lastPongTime => _webSocketService.lastPongTime;

  WebSocketMessage? _lastMessage;
  WebSocketMessage? get lastMessage => _lastMessage;

  bool _isInitialized = false;
  bool _isLifecycleObserverRegistered = false;

  void _ensureInitialized() {
    if (!_isInitialized) {
      _initialize();
      _isInitialized = true;
    }
  }

  // Start periodic status updates (only notify when status actually changes)
  void _startStatusUpdates() {
    _statusUpdateTimer?.cancel();
    _previousStatus = status;
    _previousIsServerDown = isServerDown;

    _statusUpdateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      // Only notify if status actually changed
      final currentStatus = status;
      final currentIsServerDown = isServerDown;

      if (currentStatus != _previousStatus ||
          currentIsServerDown != _previousIsServerDown) {
        _previousStatus = currentStatus;
        _previousIsServerDown = currentIsServerDown;
        notifyListeners(); // Only notify on actual status changes
      }
    });
  }

  Future<void> _initialize() async {
    if (!_isLifecycleObserverRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _isLifecycleObserverRegistered = true;
    }

    // Start periodic status updates
    _startStatusUpdates();

    // Listen to WebSocket messages BEFORE connecting
    // This ensures we don't miss any messages
    _messageSubscription = _webSocketService.messages.listen(
      (message) {
        debugPrint('WebSocketProvider received message: type=${message.type}');
        _lastMessage = message;
        _handleMessage(message);
        // Skip notifyListeners() for messages handled with optimistic updates
        // These handlers update the cache directly and call notifyListeners() themselves
        final skipNotify = [
          'order_created',
          'order_updated',
          'order_status_changed',
          'customer_created',
          'customer_updated',
          'product_updated',
          'category_updated',
          'modifier_updated',
          'modifier_group_updated',
          'floor_plan_updated',
          'table_status_updated',
          'profile_updated',
          'user_updated',
          'role_updated',
          'store_updated',
        ];
        if (!skipNotify.contains(message.type)) {
          notifyListeners();
        }
      },
      onError: (error) {
        debugPrint('WebSocketProvider message stream error: $error');
      },
      onDone: () {
        debugPrint('WebSocketProvider message stream closed');
      },
      cancelOnError: false,
    );

    // Initialize profile from storage
    await _authService.initializeProfile();

    // Auto-connect when authenticated
    final isAuth = await _authService.isAuthenticated();
    if (isAuth) {
      // Get userId from profile and storeId from DataProvider (source of truth)
      final profile = _authService.getProfile();
      final userId = profile?.id ?? _authService.getUserIdFromToken();

      // Get storeId from DataProvider's cached store
      final dataProvider = DataProvider();
      final storeId =
          dataProvider.store?.id ??
          profile?.storeId ??
          _authService.getStoreId();

      debugPrint(
        'Auto-connecting WebSocket: userId=$userId, storeId=$storeId (from store: ${dataProvider.store?.name})',
      );
      await connect(userId: userId, storeId: storeId);
    }
  }

  // Connect to WebSocket
  Future<void> connect({String? userId, String? storeId}) async {
    debugPrint(
      'WebSocketProvider connecting with userId: $userId, storeId: $storeId',
    );
    await _webSocketService.connect(userId: userId, storeId: storeId);
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    debugPrint('📱 App resumed – WebSocket connected: $isConnected');

    if (!isConnected) {
      _webSocketService.reconnect().then((_) => notifyListeners());
      DataProvider().loadTakeoutOrders(forceRefresh: true);
    }
  }

  // Disconnect from WebSocket
  void disconnect() {
    _webSocketService.disconnect();
    notifyListeners();
  }

  // Debounced refetch function (similar to Next.js debouncedRefetch)
  void _debouncedRefetch(VoidCallback refetchCallback) {
    // If already refetching, skip to prevent duplicate calls
    if (_isRefetching) {
      debugPrint('Refetch already in progress, skipping...');
      return;
    }

    // Cancel any existing timer
    _debounceTimer?.cancel();

    // Schedule new refetch
    _debounceTimer = Timer(Duration(milliseconds: debounceDelay), () {
      if (_isRefetching) return; // Double check

      _isRefetching = true;

      try {
        refetchCallback();
      } finally {
        // Reset flag after a short delay to allow API calls to complete
        Future.delayed(const Duration(milliseconds: 500), () {
          _isRefetching = false;
        });
      }
    });
  }

  // Handle incoming WebSocket messages
  void _handleMessage(WebSocketMessage message) {
    switch (message.type) {
      case 'order_created':
        _handleOrderCreated(message);
        break;

      case 'order_updated':
      case 'order_status_changed':
        _handleOrderUpdated(message);
        break;

      case 'customer_created':
        _handleCustomerCreated(message);
        break;

      case 'profile_updated':
        _handleProfileUpdated(message);
        break;

      case 'customer_updated':
        _handleCustomerUpdated(message);
        break;

      case 'product_updated':
        _handleProductUpdated(message);
        break;

      case 'category_updated':
        _handleCategoryUpdated(message);
        break;

      case 'modifier_updated':
        _handleModifierUpdated(message);
        break;

      case 'modifier_group_updated':
        _handleModifierGroupUpdated(message);
        break;

      case 'store_updated':
        _handleStoreUpdated(message);
        break;

      case 'floor_plan_updated':
        _handleFloorPlanUpdated(message);
        break;

      case 'table_status_updated':
        _handleTableStatusUpdated(message);
        break;

      case 'user_updated':
        _handleUserUpdated(message);
        break;

      default:
        debugPrint('Unhandled WebSocket message type: ${message.type}');
    }
  }

  // Handle new order created - OPTIMISTIC UPDATE (no refetch!)
  void _handleOrderCreated(WebSocketMessage message) {
    final data = message.data;
    if (data == null) return;

    final orderData = data['order'];
    final orderNumber = data['orderNumber'] ?? orderData?['orderNumber'];

    debugPrint('🆕 New order received: $orderNumber');

    // If we have full order data, update cache directly (optimistic update)
    if (orderData != null) {
      final dataProvider = DataProvider();
      dataProvider.addOrderToCache(orderData);
      debugPrint('✅ Order added to cache directly (no refetch needed)');
    } else {
      // Fallback: trigger actual API refetch if no order data provided
      debugPrint('⚠️ No order data in WebSocket, triggering refetch');
      _debouncedRefetch(() {
        DataProvider().loadTakeoutOrders(forceRefresh: true);
      });
    }

    // Notify listeners immediately for UI update
    notifyListeners();
  }

  // Handle order updated - OPTIMISTIC UPDATE (no refetch!)
  void _handleOrderUpdated(WebSocketMessage message) {
    final data = message.data;
    if (data == null) return;

    final orderData = data['order'];

    // If we have full order data, update cache directly (optimistic update)
    if (orderData != null) {
      final dataProvider = DataProvider();
      dataProvider.updateOrderInCache(orderData as Map<String, dynamic>);
    } else {
      // Fallback: trigger actual API refetch if no order data provided
      _debouncedRefetch(() {
        DataProvider().loadTakeoutOrders(forceRefresh: true);
      });
    }

    // Notify listeners immediately for UI update
    notifyListeners();
  }

  // Handle profile updated - OPTIMISTIC UPDATE
  void _handleProfileUpdated(WebSocketMessage message) {
    final data = message.data;
    if (data == null) return;

    final action = data['action'] as String?;
    final authService = AuthService();

    // Handle role_changed action specifically
    if (action == 'role_changed') {
      final roleData = data['role'];
      final roleMessage = data['message'] as String?;

      debugPrint('🔐 Role changed notification: $roleMessage');

      // If role is null, it was deleted - user needs to refresh or re-login
      if (roleData == null) {
        debugPrint('⚠️ User role was deleted - permissions may be affected');
        // Force profile refresh to get updated state
        authService
            .fetchProfile()
            .then((_) {
              debugPrint('Profile refreshed after role deletion');
            })
            .catchError((e) {
              debugPrint('Error refreshing profile after role deletion: $e');
              return null; // Return null to satisfy the type checker
            });
      } else {
        // Update the role in the current profile
        authService.updateRoleFromWebSocket(roleData as Map<String, dynamic>);
      }
      return;
    }

    // Handle normal profile update
    final profileData = data['profile'];
    if (profileData == null) return;

    // Update profile in AuthService (optimistic update)
    authService.updateProfileFromWebSocket(profileData as Map<String, dynamic>);
  }

  // Handle user updated - OPTIMISTIC UPDATE (for staff list and profile)
  void _handleUserUpdated(WebSocketMessage message) {
    final data = message.data;
    if (data == null) return;

    final userData = data['user'];
    if (userData == null) return;

    // Update profile in AuthService if this is the current user
    final authService = AuthService();
    authService.updateProfileFromWebSocket(userData as Map<String, dynamic>);

    // Note: Staff list updates could be handled here in the future
    // if the app maintains a staff list in DataProvider
  }

  // Handle customer created
  void _handleCustomerCreated(WebSocketMessage message) {
    final data = message.data;
    if (data == null) return;

    final customerData = data['customer'];
    if (customerData == null) return;

    // Add customer to cache directly (optimistic update)
    final dataProvider = DataProvider();
    dataProvider.addCustomerToCache(customerData);
  }

  // Handle customer updated
  void _handleCustomerUpdated(WebSocketMessage message) {
    final data = message.data;
    if (data == null) return;

    final customerData = data['customer'];
    if (customerData == null) return;

    // Update customer in cache directly (optimistic update)
    final dataProvider = DataProvider();
    dataProvider.updateCustomerInCache(customerData);
  }

  // Handle product updated - OPTIMISTIC UPDATE (no refetch!)
  void _handleProductUpdated(WebSocketMessage message) {
    final data = message.data;
    if (data == null) return;

    final productData = data['product'];
    final action = data['action'] ?? 'updated';

    // If we have full product data, update cache directly (optimistic update)
    if (productData != null && productData is Map<String, dynamic>) {
      final dataProvider = DataProvider();
      dataProvider.updateProductInCache(productData, action: action);
      return;
    }

    // Fallback: trigger actual API refetch if no product data provided
    _debouncedRefetch(() {
      DataProvider().loadProducts(forceRefresh: true);
    });
  }

  // Handle category updated
  // Handle category updated - OPTIMISTIC UPDATE (no refetch!)
  void _handleCategoryUpdated(WebSocketMessage message) {
    final data = message.data;
    if (data == null) return;

    final categoryData = data['category'];
    final action = data['action'] ?? 'updated';

    // If we have full category data, update cache directly
    if (categoryData != null && categoryData is Map<String, dynamic>) {
      final dataProvider = DataProvider();
      dataProvider.updateCategoryInCache(categoryData, action: action);
      return;
    }

    // Fallback: trigger actual API refetch if no category data provided
    _debouncedRefetch(() {
      DataProvider().loadCategories(forceRefresh: true);
    });
  }

  // Handle modifier updated - OPTIMISTIC UPDATE
  void _handleModifierUpdated(WebSocketMessage message) {
    final data = message.data;
    if (data == null) return;

    final modifierData = data['modifier'];
    final action = data['action'] ?? 'updated';

    if (modifierData != null) {
      final dataProvider = DataProvider();
      dataProvider.updateModifierInCache(modifierData, action: action);
    } else {
      // Fallback: trigger actual API refetch if no modifier data provided
      _debouncedRefetch(() {
        DataProvider().loadModifiers(forceRefresh: true);
      });
    }
  }

  // Handle modifier group updated - OPTIMISTIC UPDATE
  void _handleModifierGroupUpdated(WebSocketMessage message) {
    final data = message.data;
    if (data == null) return;

    final modifierGroupData = data['modifierGroup'];
    final action = data['action'] ?? 'updated';

    if (modifierGroupData != null) {
      final dataProvider = DataProvider();
      dataProvider.updateModifierGroupInCache(
        modifierGroupData,
        action: action,
      );
    } else {
      // Fallback: trigger actual API refetch if no modifier group data provided
      _debouncedRefetch(() {
        DataProvider().loadModifierGroups(forceRefresh: true);
      });
    }
  }

  // Handle store updated
  // Handle store updated - OPTIMISTIC UPDATE
  void _handleStoreUpdated(WebSocketMessage message) {
    final data = message.data;
    if (data == null) return;

    final storeData = data['store'];
    final action = data['action'] ?? 'updated';
    final storeId = data['storeId'];

    debugPrint('🏪 Store $action: ${storeData?['name'] ?? storeId}');

    if (storeData != null) {
      // Update the store in AuthService if it's the current user's store
      final authService = AuthService();
      final profile = authService.getProfile();

      if (profile != null && profile.storeId == storeId) {
        // The store in the user's profile needs to be updated
        authService.updateStoreFromWebSocket(storeData as Map<String, dynamic>);
        debugPrint('✅ Store updated in profile (optimistic update)');
      }

      // Also update DataProvider's store cache if it maintains one
      final dataProvider = DataProvider();
      dataProvider.updateStoreInCache(storeData, action);
    } else {
      // Fallback: trigger actual API refetch if no store data provided
      debugPrint('⚠️ No store data in WebSocket, triggering refetch');
      _debouncedRefetch(() {
        DataProvider().loadStore(forceRefresh: true);
      });
    }
  }

  // Handle floor plan updated
  // Handle floor plan updated - passes full floor plan data for optimistic updates
  void _handleFloorPlanUpdated(WebSocketMessage message) {
    final data = message.data;
    if (data == null) return;

    // Store the latest floor plan update data for listeners
    _lastFloorPlanUpdate = data;

    // Notify listeners - pages can access lastFloorPlanUpdate for optimistic updates
    notifyListeners();
  }

  // Handle table status updated - passes full floor plan data for optimistic updates
  void _handleTableStatusUpdated(WebSocketMessage message) {
    final data = message.data;
    if (data == null) return;

    // Store the latest table status update data for listeners
    _lastTableStatusUpdate = data;

    // Notify listeners - pages can access lastTableStatusUpdate for optimistic updates
    notifyListeners();
  }

  // Store latest updates for pages to access
  Map<String, dynamic>? _lastFloorPlanUpdate;
  Map<String, dynamic>? _lastTableStatusUpdate;

  /// Get the latest floor plan update data (for optimistic updates)
  Map<String, dynamic>? get lastFloorPlanUpdate => _lastFloorPlanUpdate;

  /// Get the latest table status update data (for optimistic updates)
  Map<String, dynamic>? get lastTableStatusUpdate => _lastTableStatusUpdate;

  /// Clear the latest updates after consuming
  void clearFloorPlanUpdate() => _lastFloorPlanUpdate = null;
  void clearTableStatusUpdate() => _lastTableStatusUpdate = null;

  @override
  void dispose() {
    if (_isLifecycleObserverRegistered) {
      WidgetsBinding.instance.removeObserver(this);
      _isLifecycleObserverRegistered = false;
    }
    _messageSubscription?.cancel();
    _debounceTimer?.cancel();
    _statusUpdateTimer?.cancel();
    // Don't dispose WebSocketService here as it's a singleton
    // _webSocketService.dispose();
    super.dispose();
  }
}
