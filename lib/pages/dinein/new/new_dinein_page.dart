import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:zipzap_pos_self_orders/widgets/header/widget.dart';
import 'package:zipzap_pos_self_orders/widgets/app_drawer.dart';
import 'package:zipzap_pos_self_orders/widgets/app_toast.dart';
import 'package:zipzap_pos_self_orders/models/product_model.dart';
import 'package:zipzap_pos_self_orders/models/category_model.dart';
import 'package:zipzap_pos_self_orders/models/cart_item_model.dart';
import 'package:zipzap_pos_self_orders/pages/orders/new/widgets/categories_sidebar.dart';
import 'package:zipzap_pos_self_orders/pages/orders/new/widgets/products_list.dart';
import 'package:zipzap_pos_self_orders/pages/dinein/new/widgets/cart_drawer.dart';
import 'package:zipzap_pos_self_orders/modals/cart_modal.dart';
import 'package:zipzap_pos_self_orders/modals/cart_discount_modal.dart';
import 'package:zipzap_pos_self_orders/modals/cart_note_modal.dart';
import 'package:zipzap_pos_self_orders/modals/customer_modal.dart';
import 'package:zipzap_pos_self_orders/modals/custom_item_modal.dart';
import 'package:zipzap_pos_self_orders/models/customer_model.dart';
import 'package:zipzap_pos_self_orders/widgets/warning_dialog.dart';
import 'package:zipzap_pos_self_orders/services/printer_service.dart';
import 'package:zipzap_pos_self_orders/services/audio_service.dart';
import 'package:zipzap_pos_self_orders/models/printer_model.dart';
import 'package:zipzap_pos_self_orders/models/modifier_group_model.dart';
import 'package:zipzap_pos_self_orders/models/order_model.dart' as order_model;
import 'package:zipzap_pos_self_orders/providers/data_provider.dart';
import 'package:zipzap_pos_self_orders/core/services/auth_service.dart';
import 'package:zipzap_pos_self_orders/services/orders_service.dart';
import 'package:zipzap_pos_self_orders/services/customers_service.dart';
import 'package:zipzap_pos_self_orders/core/constants/api_constants.dart';
import 'package:zipzap_pos_self_orders/pages/dinein/new/widgets/shift_table_dialog.dart';
import 'package:zipzap_pos_self_orders/pages/dinein/new/widgets/shift_guest_dialog.dart';
import 'package:zipzap_pos_self_orders/pages/dinein/new/widgets/print_split_receipt_dialog.dart';
import 'package:intl/intl.dart';

class NewDineInPage extends StatefulWidget {
  const NewDineInPage({super.key});

  @override
  State<NewDineInPage> createState() => _NewDineInPageState();
}

class _NewDineInPageState extends State<NewDineInPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<ScaffoldState> _categoriesScaffoldKey =
      GlobalKey<ScaffoldState>();
  final DataProvider _dataProvider = DataProvider();
  final AuthService _authService = AuthService();
  final OrdersService _ordersService = OrdersService();
  final CustomersService _customersService = CustomersService();
  final AudioService _audioService = AudioService();
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  List<Category> _categories = [];
  List<CartItem> _cartItems = []; // Remove 'final' so we can reassign
  CartData? _cartData;
  Customer? _selectedCustomer;
  String? _selectedCategoryId;
  String _searchQuery = '';
  bool _isPrintingKitchen = false;
  bool _isPrintingCustomer = false;
  bool _isPrintingQuote = false;
  bool _isCreatingOrder = false;
  List<Modifier> _modifiers = [];
  String _orderType = ApiConstants.uiOrderTypeDineIn; // Default to dine-in
  bool _hasShownCustomerModal = false;
  bool _isEditMode = false;
  String? _editingOrderId;
  String? _editingOrderNumber;
  bool _isDrawerOpen = false;
  DateTime? _selectedPickupTime;
  Map<String, dynamic>? _tableInfo; // For dine-in orders
  Map<String, dynamic>?
  _selectedStaff; // Selected server for dine-in (from party-size dialog)
  String _selectedGuestGroup = 'whole_table'; // For dine-in guest assignment
  DateTime? _orderCreatedAt; // Track order creation time for occupied duration

  @override
  void initState() {
    super.initState();
    _setupDataProviderListener();
    _loadData();
    _loadModifiers();
  }

  /// Resolve the current store ID from DataProvider, profile, or auth.
  /// If `orderId` is provided and storeId cannot be resolved locally,
  /// try fetching the order to obtain its store.
  Future<String?> _resolveStoreId([String? orderId]) async {
    final dataProvider = _dataProvider;
    final profile = _authService.getProfile();
    String? storeId =
        dataProvider.store?.id ?? profile?.storeId ?? _authService.getStoreId();

    if (storeId == null && orderId != null) {
      try {
        final order = await _ordersService.getOrderById(
          orderId,
          forceRefresh: true,
        );
        storeId = order.store?.id;
      } catch (e) {
        debugPrint('Failed to resolve store from order: $e');
      }
    }

    return storeId;
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
    // Update products and categories when DataProvider notifies
    if (mounted) {
      _updateProductsFromProvider();
      _updateCategoriesFromProvider();
    }
  }

  void _updateProductsFromProvider() {
    setState(() {
      // Get products from DataProvider
      _allProducts = _dataProvider.productsList
          .where((product) => product.isAvailable && product.status == 'active')
          .toList();
      _applyFilters();
    });
  }

  void _updateCategoriesFromProvider() {
    setState(() {
      // Get categories from DataProvider
      _categories =
          _dataProvider.categoriesList
              .where((category) => category.isActive && category.showOnPos)
              .toList()
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Get order type and order data from route arguments (can only access context here)
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      if (args.containsKey('orderType')) {
        final orderType = args['orderType'] as String;
        if (_orderType != orderType) {
          setState(() {
            _orderType = orderType;
          });
        }
      }

      // Handle tableInfo for dine-in orders
      if (args.containsKey('tableInfo') && _tableInfo == null) {
        final tableInfo = args['tableInfo'] as Map<String, dynamic>;
        // Merge partySize into tableInfo if provided separately
        if (args.containsKey('partySize')) {
          tableInfo['partySize'] = args['partySize'] as int;
        }
        setState(() {
          _tableInfo = tableInfo;
        });
      }

      // Handle selected staff (server) for dine-in orders
      if (args.containsKey('staff') && _selectedStaff == null) {
        final staffArg = args['staff'];
        if (staffArg is Map<String, dynamic>) {
          setState(() {
            _selectedStaff = staffArg;
          });
        }
      }

      // Handle a customer passed from the home-screen dine-in entry modal
      if (args.containsKey('customer') && _selectedCustomer == null) {
        final customerArg = args['customer'];
        if (customerArg is Customer) {
          setState(() {
            _selectedCustomer = customerArg;
          });
        }
      }

      // Handle edit mode
      if (args.containsKey('isEditMode') && args['isEditMode'] == true) {
        final order = args['order'] as order_model.Order?;
        if (order != null && !_isEditMode) {
          _isEditMode = true;
          _editingOrderId = order.id;
          _populateFromOrder(order);
        }
      }
    }

    // Open customer modal initially for takeout and delivery (only once, and not in edit mode)
    if (!_hasShownCustomerModal &&
        !_isEditMode &&
        (_orderType == ApiConstants.uiOrderTypeTakeout ||
            _orderType == ApiConstants.uiOrderTypeDelivery)) {
      _hasShownCustomerModal = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showCustomerModal();
        }
      });
    }
  }

  void _populateFromOrder(order_model.Order order) {
    // Store order number for display
    _editingOrderNumber = order.orderNumber;

    // Store order creation time for occupied duration calculation
    _orderCreatedAt = order.createdAt;

    // Restore the assigned server so reprints / kitchen receipts continue
    // to show the right name when an existing order is reopened. Prefer the
    // explicit staff field; fall back to createdBy for older orders.
    final restoredStaff = order.staff ?? order.createdBy;
    if (_selectedStaff == null && restoredStaff != null) {
      _selectedStaff = {
        '_id': restoredStaff.id,
        'firstName': restoredStaff.firstName,
        'lastName': restoredStaff.lastName,
        'email': restoredStaff.email,
      };
    }

    // Convert customer - try to find full customer data from DataProvider
    if (order.customer != null) {
      // First try to find the full customer from DataProvider for complete data
      final fullCustomer = _dataProvider.customersList.firstWhere(
        (c) => c.id == order.customer!.id,
        orElse: () => Customer(
          id: order.customer!.id,
          firstName: order.customer!.firstName,
          lastName: order.customer!.lastName,
          phone: order.customer!.phone,
          email: order.customer!.email,
        ),
      );
      setState(() {
        _selectedCustomer = fullCustomer;
      });
    }

    // Convert note/comment and discount from order if present
    setState(() {
      _cartData = CartData(
        note:
            order.note ?? order.comment, // Use note first, fallback to comment
        discount: order.discount != null
            ? CartDiscount(
                type: order.discount!.type,
                value: order.discount!.value,
              )
            : null,
        coupon: _cartData?.coupon,
        fees: _cartData?.fees ?? [],
      );
    });

    // Load pickup time from order if present - delayTime is now DateTime
    if (order.pickupInfo?.delayTime != null) {
      setState(() {
        _selectedPickupTime = order.pickupInfo!.delayTime;
      });
      debugPrint(
        'Loaded pickup time from order: ${order.pickupInfo!.delayTime}',
      );
    } else if (order.pickupInfo?.pickupTime != null) {
      setState(() {
        _selectedPickupTime = order.pickupInfo!.pickupTime;
      });
    }

    // Convert order items to cart items (need to wait for products to load)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _allProducts.isNotEmpty) {
        _convertOrderItemsToCartItems(order.items);
      }
    });
  }

  List<CartItem> _createCartItemsFromOrderItems(
    List<order_model.OrderItem> orderItems, {
    bool inKitchen = false,
  }) {
    final cartItems = <CartItem>[];

    for (final orderItem in orderItems) {
      Product? product;
      if (orderItem.item != null) {
        try {
          product = _allProducts.firstWhere((p) => p.id == orderItem.item!.id);
          // Overlay order-specific taxRule onto catalog product (falls back to
          // catalog's rule when null). taxEnable stays from the catalog since it
          // is the authoritative source for regular products.
          product = product.copyWith(taxRule: orderItem.taxRule);
        } catch (e) {
          product = _createProductFromOrderItem(orderItem);
        }
      } else {
        product = _createProductFromOrderItem(orderItem);
      }

      // Convert modifiers
      final modifiers = <String, List<String>>{};
      for (final modifier in orderItem.modifiers) {
        // Group modifiers by their group (we'll need to find the group)
        // For now, use a default group or find the actual group
        final groupName = _findModifierGroupName(modifier.id) ?? 'Modifiers';
        if (!modifiers.containsKey(groupName)) {
          modifiers[groupName] = [];
        }
        modifiers[groupName]!.add(modifier.id);
      }

      // Create cart item - use order item ID for void print matching
      final cartItem = CartItem(
        id: orderItem.id.isNotEmpty ? orderItem.id : const Uuid().v4(),
        product: product,
        quantity: orderItem.quantity,
        modifiers: modifiers,
        itemNote: orderItem.itemNote ?? '',
        inKitchen:
            inKitchen, // Items from InKitchen orders are already in kitchen
        itemStatus: orderItem.itemStatus, // Preserve void/refund status
        guestGroup: 'whole_table',
      );

      cartItems.add(cartItem);
    }
    return cartItems;
  }

  void _convertOrderItemsToCartItems(List<order_model.OrderItem> orderItems) {
    final cartItems = _createCartItemsFromOrderItems(
      orderItems,
      inKitchen: true,
    );

    // Update state to trigger rebuild and highlight products
    if (mounted) {
      setState(() {
        _cartItems.clear();
        _cartItems.addAll(cartItems);
      });
    }
  }

  void _handleReorder(List<order_model.OrderItem> items) {
    final cartItems = _createCartItemsFromOrderItems(items, inKitchen: false);

    setState(() {
      _cartItems.addAll(cartItems);
    });

    _audioService.playAddToCart();

    AppToast.success(
      context: context,
      title: 'Items Added',
      description: '${items.length} items added to cart',
    );
  }

  Product _createProductFromOrderItem(order_model.OrderItem orderItem) {
    final isCustomItem = orderItem.item == null;
    final perUnitPrice = orderItem.price;

    var taxRule = orderItem.taxRule;
    if (isCustomItem && orderItem.taxEnable && taxRule == null) {
      final taxRules = DataProvider().taxRulesList;
      if (taxRules.isNotEmpty) {
        try {
          taxRule = taxRules.firstWhere((rule) => rule.taxClass == 'HST');
        } catch (_) {
          taxRule = taxRules.first;
        }
      }
    }

    return Product(
      id: isCustomItem ? '' : (orderItem.item?.id ?? ''),
      name: orderItem.displayName,
      description: '',
      category: '',
      price: perUnitPrice,
      posPrice: perUnitPrice,
      isAvailable: true,
      status: 'active',
      type: isCustomItem ? 'custom' : 'product',
      images: [],
      taxEnable: orderItem.taxEnable,
      taxRule: taxRule,
      modifiers: [],
      modifiersGroup: [],
    );
  }

  String? _findModifierGroupName(String modifierId) {
    // Find which group this modifier belongs to
    for (final modifier in _modifiers) {
      if (modifier.id == modifierId) {
        // Get the group ID and look up the actual group name
        final groupId = modifier.modifierGroupId;
        if (groupId != null) {
          // Find the modifier group by ID and return its name
          try {
            final group = _dataProvider.modifierGroupsList.firstWhere(
              (g) => g.id == groupId,
            );
            return group.name;
          } catch (e) {
            // Group not found, fallback to 'Modifiers'
            return 'Modifiers';
          }
        }
        return 'Modifiers';
      }
    }
    // If modifier not found, use default group name
    return 'Modifiers';
  }

  void _showCustomerModal() {
    final isRequired = _orderType == ApiConstants.uiOrderTypeDelivery;
    showDialog(
      context: context,
      barrierDismissible: !isRequired,
      builder: (context) => CustomerModal(
        selectedCustomer: _selectedCustomer,
        isRequired: isRequired,
        orderType: _orderType,
        onConfirm: (customer) {
          _handleCustomerUpdate(customer);
        },
        onCancel: () {
          Navigator.of(context).pop(); // Close customer modal
          if (isRequired) {
            // Navigate back to takeouts page
            Navigator.of(context).pop();
          }
        },
        onReorder: (items) {
          _handleReorder(items);
          Navigator.of(context).pop(); // Close CustomerModal
        },
      ),
    );
  }

  Future<void> _handleCustomerUpdate(Customer? customer) async {
    setState(() {
      _selectedCustomer = customer;
    });

    // If in edit mode, immediately update the order with new customer
    if (_isEditMode && _editingOrderId != null) {
      try {
        // Resolve store and update order via API with just the customer
        final storeId = await _resolveStoreId(_editingOrderId);
        final updatedOrder = await _ordersService.updateOrder(
          orderId: _editingOrderId!,
          store: storeId,
          customer: customer?.id,
          phone: customer?.phone,
        );

        debugPrint('Order customer updated: ${updatedOrder.orderNumber}');

        // Update DataProvider's in-memory list for immediate UI update
        _dataProvider.updateTakeoutOrderInMemory(updatedOrder);

        // Force refresh from API to ensure cache is updated with latest data
        await _dataProvider.loadTakeoutOrders(forceRefresh: true);

        // Show success message
        if (mounted) {
          AppToast.success(
            context: context,
            title: 'Customer Updated',
            description: customer != null
                ? 'Customer ${customer.fullName} assigned'
                : 'Customer removed from order',
          );
        }
      } catch (e) {
        debugPrint('Error updating customer: $e');
        if (mounted) {
          AppToast.error(
            context: context,
            title: 'Failed to Update Customer',
            description: e.toString(),
          );
        }
      }
    }
  }

  Future<void> _loadModifiers() async {
    try {
      setState(() {
        // Get modifiers from DataProvider
        _modifiers = _dataProvider.modifiersList
            .where((m) => m.isActive && m.posEnabled)
            .toList();
        // Invalidate cache when modifiers change
        _modifierCache = null;
      });
    } catch (e) {
      debugPrint('Error loading modifiers: $e');
    }
  }

  Future<void> _loadData() async {
    try {
      // Get products and categories from DataProvider instead of JSON
      _updateProductsFromProvider();
      _updateCategoriesFromProvider();

      setState(() {
        _applyFilters();
      });

      // If in edit mode and we have an order to populate, try converting now
      if (_isEditMode && _editingOrderId != null) {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is Map<String, dynamic> && args.containsKey('order')) {
          final order = args['order'] as order_model.Order?;
          if (order != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _convertOrderItemsToCartItems(order.items);
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
  }

  void _applyFilters() {
    setState(() {
      var filtered = _allProducts;

      // Apply category filter
      if (_selectedCategoryId != null) {
        filtered = filtered
            .where((product) => product.category == _selectedCategoryId)
            .toList();
      }

      // Apply search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase().trim();
        filtered = filtered
            .where(
              (product) =>
                  product.name.toLowerCase().contains(query) ||
                  product.description.toLowerCase().contains(query),
            )
            .toList();
      }

      _filteredProducts = filtered;
    });
  }

  void _handleCategorySelected(String? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
    });
    _applyFilters();
  }

  void _handleSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _applyFilters();
  }

  /// Check if two cart items are identical (same product, modifiers, notes, and discount)
  /// Items already sent to kitchen are never considered identical (always add as new)
  bool _areCartItemsIdentical(CartItem item1, CartItem item2) {
    // Items already in kitchen should never be merged
    if (item1.inKitchen || item2.inKitchen) return false;

    // Check product ID
    if (item1.product.id != item2.product.id) return false;

    // Check item note
    if (item1.itemNote != item2.itemNote) return false;

    // Check item discount
    if (item1.itemDiscount?.type != item2.itemDiscount?.type) return false;
    if (item1.itemDiscount?.value != item2.itemDiscount?.value) return false;

    // Check modifiers - must have same groups and same modifiers in each group
    if (item1.modifiers.length != item2.modifiers.length) return false;

    for (final entry in item1.modifiers.entries) {
      final groupName = entry.key;
      final modifiers1 = entry.value;
      final modifiers2 = item2.modifiers[groupName];

      // Check if group exists in both items
      if (modifiers2 == null) return false;

      // Check if same number of modifiers in group
      if (modifiers1.length != modifiers2.length) return false;

      // Check if all modifiers match (order doesn't matter)
      final sortedModifiers1 = List<String>.from(modifiers1)..sort();
      final sortedModifiers2 = List<String>.from(modifiers2)..sort();

      for (int i = 0; i < sortedModifiers1.length; i++) {
        if (sortedModifiers1[i] != sortedModifiers2[i]) return false;
      }
    }

    return true;
  }

  void _handleProductTap(Product product) {
    // Check if product has modifier groups
    final hasModifierGroups = product.modifiersGroup.isNotEmpty;

    if (hasModifierGroups) {
      // Show modal for products with modifiers
      showDialog(
        context: context,
        builder: (context) => CartModal(
          product: product,
          guestGroup: _selectedGuestGroup, // Pass selected guest group
          onConfirm: (cartItem) {
            Navigator.of(context).pop();
            setState(() {
              // Check if identical item already exists in cart
              final existingIndex = _cartItems.indexWhere(
                (item) => _areCartItemsIdentical(item, cartItem),
              );

              if (existingIndex != -1) {
                // Identical item found - increment quantity
                _cartItems[existingIndex] = _cartItems[existingIndex].copyWith(
                  quantity:
                      _cartItems[existingIndex].quantity + cartItem.quantity,
                );
              } else {
                // No identical item - add as new
                _cartItems.add(cartItem);
              }
            });
            // Play add to cart sound
            _audioService.playAddToCart();
          },
          onCancel: () {
            Navigator.of(context).pop();
          },
        ),
      );
    } else {
      // Direct add for products without modifiers
      final existingIndex = _cartItems.indexWhere(
        (item) =>
            item.product.id == product.id &&
            item.modifiers.isEmpty &&
            item.itemNote.isEmpty &&
            item.itemDiscount == null &&
            !item.inKitchen, // Don't merge with items already in kitchen
      );

      if (existingIndex != -1) {
        // Increment quantity
        setState(() {
          _cartItems[existingIndex] = _cartItems[existingIndex].copyWith(
            quantity: _cartItems[existingIndex].quantity + 1,
          );
        });
      } else {
        // Add new item to cart
        setState(() {
          _cartItems.add(
            CartItem(
              id: const Uuid().v4(),
              product: product,
              quantity: 1,
              guestGroup: 'whole_table',
            ),
          );
        });
      }
      // Play add to cart sound
      _audioService.playAddToCart();
    }
  }

  void _handleAddCustomItem() {
    showDialog(
      context: context,
      builder: (context) => CustomItemModal(
        onAdd: (customItemData) {
          // Create a Product object from custom item data
          // Note: ID is empty string since custom items don't have product IDs
          final customProduct = Product(
            id: '', // Empty ID for custom items - won't be sent to API
            name: customItemData['customItem'],
            description: '',
            category: '',
            price: customItemData['price'],
            posPrice: customItemData['price'],
            isAvailable: true,
            status: 'active',
            type: 'custom',
            images: [],
            taxEnable: customItemData['taxEnable'] ?? false,
            taxRule: customItemData['taxRule'] != null
                ? TaxRule(
                    id: customItemData['taxRule']['_id'],
                    name: customItemData['taxRule']['name'],
                    taxClass: customItemData['taxRule']['taxClass'],
                    amount: (customItemData['taxRule']['amount'] as num)
                        .toDouble(),
                    taxType: customItemData['taxRule']['taxType'],
                  )
                : null,
            modifiers: [],
            modifiersGroup: [],
          );

          // Create CartItem with unique ID for cart management
          final cartItem = CartItem(
            id: const Uuid().v4(), // Unique ID for cart item management only
            product: customProduct,
            quantity: customItemData['quantity'],
            itemNote: customItemData['itemNote'] ?? '',
            guestGroup: 'whole_table',
          );

          setState(() {
            _cartItems.add(cartItem);
          });

          // Play add to cart sound
          _audioService.playAddToCart();
        },
      ),
    );
  }

  void _handleCartItemUpdate(CartItem item, int newQuantity) {
    if (newQuantity <= 0) {
      _handleCartItemRemove(item);
      return;
    }
    setState(() {
      final index = _cartItems.indexWhere((i) => i.id == item.id);
      if (index != -1) {
        // Replace the entire item to handle modifier/note changes
        // Reset inKitchen status since item was modified
        _cartItems[index] = item.copyWith(
          quantity: newQuantity,
          inKitchen: false,
        );
      }
    });
  }

  void _handleCartItemRemove(CartItem item) {
    setState(() {
      _cartItems.removeWhere((i) => i.id == item.id);
    });
    // Play remove cart item sound
    _audioService.playRemoveCartItem();
  }

  Future<void> _handleNoteUpdate(String? note) async {
    setState(() {
      _cartData = CartData(
        note: note,
        discount: _cartData?.discount,
        coupon: _cartData?.coupon,
        fees: _cartData?.fees ?? [],
      );
    });

    // If in edit mode, immediately update the order with new note
    if (_isEditMode && _editingOrderId != null) {
      try {
        // Calculate totals for all items (rounded to 2 decimal places)
        final subtotal = double.parse(
          _cartItems
              .where((item) => item.itemStatus != 'Voided')
              .fold(0.0, (sum, item) => sum + _calculateItemTotal(item))
              .toStringAsFixed(2),
        );

        final discountAmount = _cartData?.discount != null
            ? double.parse(
                (_cartData!.discount!.type == '%'
                        ? subtotal * (_cartData!.discount!.value / 100)
                        : _cartData!.discount!.value)
                    .toStringAsFixed(2),
              )
            : 0.0;

        final couponAmount =
            _cartData?.coupon != null && _cartData!.coupon!.code.isNotEmpty
            ? double.parse(
                (_cartData!.coupon!.type == '%'
                        ? subtotal * (_cartData!.coupon!.discount / 100)
                        : _cartData!.coupon!.discount)
                    .toStringAsFixed(2),
              )
            : 0.0;

        final discountedTotal = double.parse(
          (subtotal - discountAmount - couponAmount).toStringAsFixed(2),
        );

        final tax = double.parse(
          _cartItems
              .where(
                (item) => item.itemStatus != 'Voided' && item.product.taxEnable,
              )
              .fold(0.0, (sum, item) {
                final itemTotal = _calculateItemTotal(item);
                // Avoid division by zero when subtotal is 0
                final itemRatio = subtotal > 0 ? itemTotal / subtotal : 0.0;
                final itemDiscount = discountAmount * itemRatio;
                final itemCoupon = couponAmount * itemRatio;
                final finalItemTotal = itemTotal - itemDiscount - itemCoupon;
                final taxRate = (item.product.taxRule?.amount ?? 0) / 100;
                return sum + (finalItemTotal * taxRate);
              })
              .toStringAsFixed(2),
        );

        final total = double.parse((discountedTotal + tax).toStringAsFixed(2));

        // Convert ALL cart items to API format (including previously sent items)
        final items = _cartItems
            .where((item) => item.itemStatus != 'Voided')
            .map((item) {
              // Get all modifier IDs as a flat list
              final modifierIds = item.modifiers.values
                  .expand((modifierList) => modifierList)
                  .toList();

              // Build item discount if present
              Map<String, dynamic>? itemDiscount;
              if (item.itemDiscount != null && item.itemDiscount!.value > 0) {
                itemDiscount = {
                  'type': item.itemDiscount!.type,
                  'value': item.itemDiscount!.value,
                };
              }

              return {
                // Regular products: include 'item' field with product ID
                if (item.product.type != 'custom') 'item': item.product.id,
                // Custom items: include 'customItem' field with custom name
                if (item.product.type == 'custom')
                  'customItem': item.product.name,
                'quantity': item.quantity,
                'price': _calculateItemPricePerUnit(
                  item,
                ), // Price per item with modifiers
                'modifiers': modifierIds, // Array of modifier IDs
                'itemNote': item.itemNote,
                if (itemDiscount != null) 'itemDiscount': itemDiscount,
                'guestGroup': item.guestGroup, // Guest group assignment
                'taxEnable': item.product.taxEnable,
                if (item.product.taxRule != null)
                  'taxRule': item.product.taxRule!.toJson(),
              };
            })
            .toList();

        // Build discount if present
        Map<String, dynamic>? discountMap;
        if (_cartData?.discount != null) {
          discountMap = {
            'type': _cartData!.discount!.type,
            'value': _cartData!.discount!.value,
          };
        }

        // Resolve store and update order via API
        final storeId = await _resolveStoreId(_editingOrderId);
        final updatedOrder = await _ordersService.updateOrder(
          orderId: _editingOrderId!,
          store: storeId,
          items: items,
          subtotal: subtotal,
          total: total,
          tax: tax,
          comment: note,
          discount: discountMap,
        );

        debugPrint('Order note updated: ${updatedOrder.orderNumber}');

        // Update DataProvider's in-memory list for immediate UI update
        _dataProvider.updateTakeoutOrderInMemory(updatedOrder);

        // Force refresh from API to ensure cache is updated with latest data
        await _dataProvider.loadTakeoutOrders(forceRefresh: true);

        // Show success message
        if (mounted) {
          AppToast.success(
            context: context,
            title: 'Note Updated',
            description: note != null && note.isNotEmpty
                ? 'Note updated successfully'
                : 'Note removed successfully',
          );
        }
      } catch (e) {
        debugPrint('Error updating note: $e');
        if (mounted) {
          AppToast.error(
            context: context,
            title: 'Failed to Update Note',
            description: e.toString(),
          );
        }
      }
    }
  }

  Future<void> _handleDiscountUpdate(CartDiscount? discount) async {
    setState(() {
      _cartData = CartData(
        note: _cartData?.note,
        discount: discount,
        coupon: _cartData?.coupon,
        fees: _cartData?.fees ?? [],
      );
    });

    // If in edit mode, immediately update the order with new discount
    if (_isEditMode && _editingOrderId != null) {
      try {
        // Calculate totals for all items (rounded to 2 decimal places)
        final subtotal = double.parse(
          _cartItems
              .where((item) => item.itemStatus != 'Voided')
              .fold(0.0, (sum, item) => sum + _calculateItemTotal(item))
              .toStringAsFixed(2),
        );

        final discountAmount = discount != null
            ? double.parse(
                (discount.type == '%'
                        ? subtotal * (discount.value / 100)
                        : discount.value)
                    .toStringAsFixed(2),
              )
            : 0.0;

        final couponAmount =
            _cartData?.coupon != null && _cartData!.coupon!.code.isNotEmpty
            ? double.parse(
                (_cartData!.coupon!.type == '%'
                        ? subtotal * (_cartData!.coupon!.discount / 100)
                        : _cartData!.coupon!.discount)
                    .toStringAsFixed(2),
              )
            : 0.0;

        final discountedTotal = double.parse(
          (subtotal - discountAmount - couponAmount).toStringAsFixed(2),
        );

        final tax = double.parse(
          _cartItems
              .where(
                (item) => item.itemStatus != 'Voided' && item.product.taxEnable,
              )
              .fold(0.0, (sum, item) {
                final itemTotal = _calculateItemTotal(item);
                // Avoid division by zero when subtotal is 0
                final itemRatio = subtotal > 0 ? itemTotal / subtotal : 0.0;
                final itemDiscount = discountAmount * itemRatio;
                final itemCoupon = couponAmount * itemRatio;
                final finalItemTotal = itemTotal - itemDiscount - itemCoupon;
                final taxRate = (item.product.taxRule?.amount ?? 0) / 100;
                return sum + (finalItemTotal * taxRate);
              })
              .toStringAsFixed(2),
        );

        final total = double.parse((discountedTotal + tax).toStringAsFixed(2));

        // Convert ALL cart items to API format (including previously sent items)
        final items = _cartItems
            .where((item) => item.itemStatus != 'Voided')
            .map((item) {
              // Get all modifier IDs as a flat list
              final modifierIds = item.modifiers.values
                  .expand((modifierList) => modifierList)
                  .toList();

              // Build item discount if present
              Map<String, dynamic>? itemDiscount;
              if (item.itemDiscount != null && item.itemDiscount!.value > 0) {
                itemDiscount = {
                  'type': item.itemDiscount!.type,
                  'value': item.itemDiscount!.value,
                };
              }

              return {
                // Regular products: include 'item' field with product ID
                if (item.product.type != 'custom') 'item': item.product.id,
                // Custom items: include 'customItem' field with custom name
                if (item.product.type == 'custom')
                  'customItem': item.product.name,
                'quantity': item.quantity,
                'price': _calculateItemPricePerUnit(
                  item,
                ), // Price per item with modifiers
                'modifiers': modifierIds, // Array of modifier IDs
                'itemNote': item.itemNote,
                if (itemDiscount != null) 'itemDiscount': itemDiscount,
                'guestGroup': item.guestGroup, // Guest group assignment
                'taxEnable': item.product.taxEnable,
                if (item.product.taxRule != null)
                  'taxRule': item.product.taxRule!.toJson(),
              };
            })
            .toList();

        // Build discount if present
        final clearDiscount = discount == null;
        Map<String, dynamic>? discountMap;
        if (discount != null) {
          discountMap = {'type': discount.type, 'value': discount.value};
        }

        // Resolve store and update order via API
        final storeId = await _resolveStoreId(_editingOrderId);
        final updatedOrder = await _ordersService.updateOrder(
          orderId: _editingOrderId!,
          store: storeId,
          items: items,
          subtotal: subtotal,
          total: total,
          tax: tax,
          comment: _cartData?.note,
          discount: discountMap,
          clearDiscount: clearDiscount,
        );

        debugPrint('Order discount updated: ${updatedOrder.orderNumber}');

        // Update DataProvider's in-memory list for immediate UI update
        _dataProvider.updateTakeoutOrderInMemory(updatedOrder);

        // Force refresh from API to ensure cache is updated with latest data
        await _dataProvider.loadTakeoutOrders(forceRefresh: true);

        // Show success message
        if (mounted) {
          AppToast.success(
            context: context,
            title: 'Discount Updated',
            description: discount != null
                ? 'Discount applied successfully'
                : 'Discount removed successfully',
          );
        }
      } catch (e) {
        debugPrint('Error updating discount: $e');
        if (mounted) {
          AppToast.error(
            context: context,
            title: 'Failed to Update Discount',
            description: e.toString(),
          );
        }
      }
    }
  }

  Future<void> _handleSendToKitchen() async {
    if (_cartItems.isEmpty) {
      return;
    }

    if (_isCreatingOrder) return;

    // Refresh customer data before printing to ensure returning badge is accurate
    await _refreshSelectedCustomerForPrint();

    setState(() {
      _isCreatingOrder = true;
    });

    try {
      // Resolve store ID early (used for create AND update flows)
      final dataProvider = DataProvider();
      final profile = _authService.getProfile();
      String? storeId =
          dataProvider.store?.id ??
          profile?.storeId ??
          _authService.getStoreId();

      // If still null and we're editing an order, try fetching order details
      if (storeId == null && _isEditMode && _editingOrderId != null) {
        try {
          final existingOrder = await _ordersService.getOrderById(
            _editingOrderId!,
            forceRefresh: true,
          );
          storeId = existingOrder.store?.id;
        } catch (e) {
          debugPrint('Failed to fetch existing order to resolve store: $e');
        }
      }

      if (storeId == null) {
        throw Exception('Store ID not found. Please login again.');
      }

      // If not edit mode, create a new order; otherwise fall through to update
      if (!_isEditMode) {
        // Calculate totals
        final subtotal = _cartItems
            .where((item) => item.itemStatus != 'Voided')
            .fold(0.0, (sum, item) => sum + _calculateItemTotal(item));

        final discountAmount = _cartData?.discount != null
            ? (_cartData!.discount!.type == '%'
                  ? subtotal * (_cartData!.discount!.value / 100)
                  : _cartData!.discount!.value)
            : 0.0;

        final couponAmount =
            _cartData?.coupon != null && _cartData!.coupon!.code.isNotEmpty
            ? (_cartData!.coupon!.type == '%'
                  ? subtotal * (_cartData!.coupon!.discount / 100)
                  : _cartData!.coupon!.discount)
            : 0.0;

        final discountedTotal = subtotal - discountAmount - couponAmount;

        final feeAmount = _cartData?.fees.isEmpty ?? true
            ? 0.0
            : _cartData!.fees.fold(0.0, (sum, fee) {
                if (fee.type == '%') {
                  return sum + (subtotal * fee.value / 100);
                }
                return sum + fee.value;
              });

        final tax = _cartItems
            .where(
              (item) => item.itemStatus != 'Voided' && item.product.taxEnable,
            )
            .fold(0.0, (sum, item) {
              final itemTotal = _calculateItemTotal(item);
              final itemRatio = subtotal > 0 ? itemTotal / subtotal : 0.0;
              final itemDiscount = discountAmount * itemRatio;
              final itemCoupon = couponAmount * itemRatio;
              final finalItemTotal = itemTotal - itemDiscount - itemCoupon;
              final taxRate = (item.product.taxRule?.amount ?? 0) / 100;
              return sum + (finalItemTotal * taxRate);
            });

        final total = discountedTotal + feeAmount + tax;

        // Dine-in page always uses dine-in order type
        const orderType = ApiConstants.orderTypeDineIn;

        // Convert cart items to API format
        final items = _cartItems
            .where((item) => item.itemStatus != 'Voided')
            .map((item) {
              // Get all modifier IDs as a flat list
              final modifierIds = item.modifiers.values
                  .expand((modifierList) => modifierList)
                  .toList();

              // Build item discount if present
              Map<String, dynamic>? itemDiscount;
              if (item.itemDiscount != null && item.itemDiscount!.value > 0) {
                itemDiscount = {
                  'type': item.itemDiscount!.type,
                  'value': item.itemDiscount!.value,
                };
              }

              return {
                // Regular products: include 'item' field with product ID
                if (item.product.type != 'custom') 'item': item.product.id,
                // Custom items: include 'customItem' field with custom name
                if (item.product.type == 'custom')
                  'customItem': item.product.name,
                'quantity': item.quantity,
                'price': _calculateItemPricePerUnit(
                  item,
                ), // Price per item with modifiers
                'modifiers': modifierIds, // Array of modifier IDs
                'itemNote': item.itemNote,
                if (itemDiscount != null) 'itemDiscount': itemDiscount,
                'guestGroup': item.guestGroup, // Guest group assignment
                'taxEnable': item.product.taxEnable,
                if (item.product.taxRule != null)
                  'taxRule': item.product.taxRule!.toJson(),
              };
            })
            .toList();

        // Build discount if present
        Map<String, dynamic>? discount;
        if (_cartData?.discount != null) {
          discount = {
            'type': _cartData!.discount!.type,
            'value': _cartData!.discount!.value,
          };
        }

        // Send pickup time as ISO timestamp if available
        final delayTime = _selectedPickupTime?.toIso8601String();

        // Create or retrieve customer if we have one
        String? customerId;
        if (_selectedCustomer != null) {
          if (_selectedCustomer!.id.isEmpty) {
            // Customer has no ID, so create them first
            try {
              final createdCustomer = await _customersService.createCustomer(
                firstName: _selectedCustomer!.firstName,
                lastName: _selectedCustomer!.lastName ?? '',
                phone: _selectedCustomer!.phone,
                email: _selectedCustomer!.email,
              );
              customerId = createdCustomer.id;
              // Update the selected customer with the new ID
              setState(() {
                _selectedCustomer = createdCustomer;
              });
            } catch (e) {
              debugPrint('Error creating customer: $e');
              // Continue without customer if creation fails
            }
          } else {
            customerId = _selectedCustomer!.id;
          }
        }

        // Create order via API
        final createdOrder = await _ordersService.createOrder(
          store: storeId,
          customer: customerId,
          phone:
              _selectedCustomer != null &&
                  _selectedCustomer!.phone != null &&
                  _selectedCustomer!.phone!.isNotEmpty
              ? _selectedCustomer!.phone
              : null,
          orderType: orderType,
          paymentStatus: 'Pending', // Will be paid at checkout
          subtotal: subtotal,
          total: total,
          orderstatus: ApiConstants.orderStatusInKitchen, // Start as Pending
          items: items,
          tax: tax,
          comment: _cartData?.note,
          discount: discount,
          delayTime: delayTime,
          tableInfo: _tableInfo, // Pass table info for dine-in orders
          // Server-assigned staff (selected in the party-size dialog) becomes
          // the visible "Created By" for dine-in. createdBy on the server
          // remains the authenticated user for audit.
          staffId: _selectedStaff?['_id'] as String?,
        );

        // Store the created order ID and number for future reference
        setState(() {
          _editingOrderId = createdOrder.id;
          _editingOrderNumber = createdOrder.orderNumber;
          _isEditMode = true;
          _orderCreatedAt = createdOrder.createdAt; // Store creation time
        });

        debugPrint('Order created: ${createdOrder.orderNumber}');

        // Show success message
        if (mounted) {
          AppToast.success(
            context: context,
            title: 'Order Created Successfully',
            description: 'Order #${createdOrder.orderNumber}',
          );
        }

        // Print pending items to kitchen before clearing cart
        await _handlePrintKitchenPending();

        // For NEW dine-in orders, clear cart and redirect to dine-in page
        const redirectRoute = '/dinein';

        setState(() {
          _cartItems.clear();
          _cartData = null;
          _selectedCustomer = null;
          _selectedPickupTime = null;
          _isEditMode = false;
          _editingOrderId = null;
          _editingOrderNumber = null;
        });

        // Redirect back to appropriate page after successful creation
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            redirectRoute,
            (route) => route.settings.name == '/',
            arguments: {'tableInfo': _tableInfo},
          );
        }
      } else {
        // In edit mode, update the order with all current items
        if (_editingOrderId == null) {
          throw Exception('Order ID not found for editing');
        }

        // Calculate totals for all items (not just pending)
        final subtotal = _cartItems
            .where((item) => item.itemStatus != 'Voided')
            .fold(0.0, (sum, item) => sum + _calculateItemTotal(item));

        final discountAmount = _cartData?.discount != null
            ? (_cartData!.discount!.type == '%'
                  ? subtotal * (_cartData!.discount!.value / 100)
                  : _cartData!.discount!.value)
            : 0.0;

        final couponAmount =
            _cartData?.coupon != null && _cartData!.coupon!.code.isNotEmpty
            ? (_cartData!.coupon!.type == '%'
                  ? subtotal * (_cartData!.coupon!.discount / 100)
                  : _cartData!.coupon!.discount)
            : 0.0;

        final discountedTotal = subtotal - discountAmount - couponAmount;

        final feeAmount = _cartData?.fees.isEmpty ?? true
            ? 0.0
            : _cartData!.fees.fold(0.0, (sum, fee) {
                if (fee.type == '%') {
                  return sum + (subtotal * fee.value / 100);
                }
                return sum + fee.value;
              });

        final tax = _cartItems
            .where(
              (item) => item.itemStatus != 'Voided' && item.product.taxEnable,
            )
            .fold(0.0, (sum, item) {
              final itemTotal = _calculateItemTotal(item);
              final itemRatio = subtotal > 0 ? itemTotal / subtotal : 0.0;
              final itemDiscount = discountAmount * itemRatio;
              final itemCoupon = couponAmount * itemRatio;
              final finalItemTotal = itemTotal - itemDiscount - itemCoupon;
              final taxRate = (item.product.taxRule?.amount ?? 0) / 100;
              return sum + (finalItemTotal * taxRate);
            });

        final total = discountedTotal + feeAmount + tax;

        // Convert ALL cart items to API format (including previously sent items)
        final items = _cartItems
            .where((item) => item.itemStatus != 'Voided')
            .map((item) {
              // Get all modifier IDs as a flat list
              final modifierIds = item.modifiers.values
                  .expand((modifierList) => modifierList)
                  .toList();

              // Build item discount if present
              Map<String, dynamic>? itemDiscount;
              if (item.itemDiscount != null && item.itemDiscount!.value > 0) {
                itemDiscount = {
                  'type': item.itemDiscount!.type,
                  'value': item.itemDiscount!.value,
                };
              }

              return {
                // Regular products: include 'item' field with product ID
                if (item.product.type != 'custom') 'item': item.product.id,
                // Custom items: include 'customItem' field with custom name
                if (item.product.type == 'custom')
                  'customItem': item.product.name,
                'quantity': item.quantity,
                'price': _calculateItemPricePerUnit(
                  item,
                ), // Price per item with modifiers
                'modifiers': modifierIds, // Array of modifier IDs
                'itemNote': item.itemNote,
                if (itemDiscount != null) 'itemDiscount': itemDiscount,
                'guestGroup': item.guestGroup, // Guest group assignment
                'taxEnable': item.product.taxEnable,
                if (item.product.taxRule != null)
                  'taxRule': item.product.taxRule!.toJson(),
              };
            })
            .toList();

        // Build discount if present
        Map<String, dynamic>? discount;
        if (_cartData?.discount != null) {
          discount = {
            'type': _cartData!.discount!.type,
            'value': _cartData!.discount!.value,
          };
        }

        // Update order via API
        final updatedOrder = await _ordersService.updateOrder(
          orderId: _editingOrderId!,
          store: storeId,
          items: items,
          subtotal: subtotal,
          total: total,
          tax: tax,
          comment: _cartData?.note,
          discount: discount,
        );

        debugPrint('Order updated: ${updatedOrder.orderNumber}');

        // Update DataProvider's in-memory list for immediate UI update
        _dataProvider.updateTakeoutOrderInMemory(updatedOrder);

        // Capture the pending items BEFORE flipping inKitchen flags so we
        // can still print them after the UI updates.
        final pendingItemsToPrint = _cartItems
            .where((item) => item.itemStatus != 'Voided' && !item.inKitchen)
            .toList();

        // Mark all non-voided cart items as inKitchen=true since the API
        // update succeeded. The order is logically sent to the kitchen even
        // if the physical print fails -- the user can manually reprint via
        // the kitchen-print action.
        if (mounted) {
          setState(() {
            _cartItems = _cartItems.map((item) {
              if (item.itemStatus != 'Voided' && !item.inKitchen) {
                return item.copyWith(inKitchen: true);
              }
              return item;
            }).toList();
          });
        }

        // Show success message
        if (mounted) {
          AppToast.success(
            context: context,
            title: 'Order Updated Successfully',
            description: 'Order #${updatedOrder.orderNumber}',
          );
        }

        // Stop the button spinner immediately -- the user-visible work
        // (API update + cart UI flip) is done. Printing and the orders
        // refresh below run as fire-and-forget background work so the
        // user doesn't have to wait for the printer or the network.
        if (mounted) {
          setState(() {
            _isCreatingOrder = false;
          });
        }

        // Print pending items to kitchen BEFORE the forced reload. The
        // reload triggers `_onDataUpdate` -> setState which can rebuild
        // the page mid-print and interleave with the printer flow.
        // Run sequentially in background so order is preserved.
        unawaited(() async {
          await _handlePrintKitchenPending(
            pendingItemsOverride: pendingItemsToPrint,
          );
          await _dataProvider.loadTakeoutOrders(forceRefresh: true);
        }());
      }
    } catch (e) {
      debugPrint('Error creating/updating order: $e');
      if (mounted) {
        AppToast.error(
          context: context,
          title: _isEditMode
              ? 'Failed to Update Order'
              : 'Failed to Create Order',
          description: e.toString(),
        );
      }
    } finally {
      if (mounted && _isCreatingOrder) {
        setState(() {
          _isCreatingOrder = false;
        });
      }
    }
  }

  Future<void> _handlePrintKitchen() async {
    if (_cartItems.isEmpty) {
      return;
    }

    // Refresh customer data before printing to ensure returning badge is accurate
    await _refreshSelectedCustomerForPrint();

    if (mounted) {
      setState(() {
        _isPrintingKitchen = true;
      });
    }

    try {
      // Refresh products to ensure labels are up-to-date (non-fatal if it fails)
      try {
        await _dataProvider.loadProducts(forceRefresh: true);
      } catch (e) {
        debugPrint('Failed to refresh products for label check: $e');
      }

      // Get kitchen printers (kitchen group) only
      final printers = await PrinterService.getSavedPrinters();
      final kitchenPrinters = printers
          .where((p) => p.group == PrinterGroup.kitchen)
          .where((p) => p.status != PrinterStatus.error)
          .toList();

      if (kitchenPrinters.isEmpty) {
        if (mounted) {
          AppToast.warning(
            context: context,
            title: 'No Kitchen Printers Found',
            description: 'Please add a kitchen printer (Kitchen group) first.',
          );
        }
        return;
      }

      final allItems = _cartItems
          .where((item) => item.itemStatus != 'Voided')
          .toList();

      // Print to each kitchen printer with label-based filtering
      bool allSuccess = true;
      bool anyPrinted = false;
      bool usedFallback = false;
      // Track which item IDs landed on at least one printer so we can
      // rescue items that no printer's label set matched.
      final printedItemIds = <String>{};
      for (final printer in kitchenPrinters) {
        final filteredItems = _filterItemsForPrinter(allItems, printer);
        if (filteredItems.isEmpty) continue;

        anyPrinted = true;
        final orderData = _formatOrderDataForPendingItems(filteredItems);
        try {
          final interfaceType = _printerTypeToString(printer.type);
          final success = await PrinterService.printKitchenOrder(
            interfaceType: interfaceType,
            identifier: printer.identifier,
            orderData: orderData,
          );
          if (success) {
            for (final item in filteredItems) {
              printedItemIds.add(item.id);
            }
          } else {
            allSuccess = false;
          }
        } catch (e) {
          debugPrint('Error printing to ${printer.name}: $e');
          allSuccess = false;
        }
      }

      // Safety fallback: any item that didn't end up on any printer (label
      // mismatch on every kitchen printer) is sent to every kitchen printer
      // so a wildcard item like a custom item can't mask labelled items
      // being silently dropped.
      if (kitchenPrinters.isNotEmpty) {
        final unmatchedItems = allItems
            .where((i) => !printedItemIds.contains(i.id))
            .toList();
        if (unmatchedItems.isNotEmpty) {
          usedFallback = true;
          final orderData = _formatOrderDataForPendingItems(unmatchedItems);
          for (final printer in kitchenPrinters) {
            anyPrinted = true;
            try {
              final interfaceType = _printerTypeToString(printer.type);
              final success = await PrinterService.printKitchenOrder(
                interfaceType: interfaceType,
                identifier: printer.identifier,
                orderData: orderData,
              );
              if (success) {
                for (final item in unmatchedItems) {
                  printedItemIds.add(item.id);
                }
              } else {
                allSuccess = false;
              }
            } catch (e) {
              debugPrint('Error printing to ${printer.name} (fallback): $e');
              allSuccess = false;
            }
          }
        }
      }

      // Mark items as sent to kitchen ONLY if at least one printer was actually
      // called and every print succeeded.
      if (allSuccess && anyPrinted && mounted) {
        setState(() {
          _cartItems = _cartItems.map((item) {
            if (item.itemStatus != 'Voided') {
              return item.copyWith(inKitchen: true);
            }
            return item;
          }).toList();
        });
      }

      if (mounted) {
        if (!anyPrinted) {
          AppToast.warning(
            context: context,
            title: 'No Items to Print',
            description:
                'No items matched kitchen printer labels. Check printer label settings.',
          );
        } else if (allSuccess) {
          AppToast.success(
            context: context,
            title: 'Sent to Kitchen',
            description: usedFallback
                ? 'Items sent. Some items had no matching printer labels and were sent to all kitchen printers.'
                : 'All items sent to kitchen and printed successfully',
          );
        } else {
          AppToast.warning(
            context: context,
            title: 'Partially Printed',
            description:
                'Some printers failed. Items remain pending so you can retry.',
          );
        }
      }
    } catch (e) {
      debugPrint('Kitchen print error: $e');
      if (mounted) {
        AppToast.error(
          context: context,
          title: 'Printing Error',
          description: 'Printing failed: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPrintingKitchen = false;
        });
      }
    }
  }

  Future<void> _handlePrintKitchenPending({
    List<CartItem>? pendingItemsOverride,
  }) async {
    // Capture state upfront before any async gap -- when called fire-and-forget
    // from _handleSendToKitchen, these fields may be cleared before async resumes.
    // Caller may provide an override (used when items have already been marked
    // inKitchen=true for UI but should still be printed).
    final pendingItems =
        pendingItemsOverride ??
        _cartItems
            .where((item) => !item.inKitchen && item.itemStatus != 'Voided')
            .toList();
    final capturedCartData = _cartData;
    final capturedCustomer = _selectedCustomer;
    final capturedPickupTime = _selectedPickupTime;
    final capturedOrderNumber = _editingOrderNumber;
    final capturedResolvedCustomer = _getResolvedCustomer();

    if (pendingItems.isEmpty) {
      if (mounted) {
        AppToast.warning(
          context: context,
          title: 'No Pending Items',
          description:
              'All items have been sent to kitchen or there are no items in cart.',
        );
      }
      return;
    }

    // Now try to print. We DO NOT optimistically mark items as inKitchen
    // before the print succeeds -- if the print silently fails (no label
    // match, native error, etc.) the user must be able to retry.
    try {
      // Refresh products to ensure labels are up-to-date (non-fatal if it fails)
      try {
        await _dataProvider.loadProducts(forceRefresh: true);
      } catch (e) {
        debugPrint('Failed to refresh products for label check: $e');
      }

      // Get kitchen printers (kitchen group) only
      final printers = await PrinterService.getSavedPrinters();
      final kitchenPrinters = printers
          .where((p) => p.group == PrinterGroup.kitchen)
          .where((p) => p.status != PrinterStatus.error)
          .toList();

      if (kitchenPrinters.isEmpty) {
        if (mounted) {
          AppToast.warning(
            context: context,
            title: 'No Kitchen Printers',
            description:
                'Items sent to kitchen but not printed. Please configure printers.',
          );
        }
        return;
      }

      // Print to each kitchen printer with label-based filtering
      bool allSuccess = true;
      bool anyPrinted = false;
      bool usedFallback = false;
      // Track which item IDs landed on at least one printer so we can
      // rescue items that no printer's label set matched.
      final printedItemIds = <String>{};
      for (final printer in kitchenPrinters) {
        final filteredItems = _filterItemsForPrinter(pendingItems, printer);
        if (filteredItems.isEmpty) continue;

        anyPrinted = true;
        final orderData = _formatOrderDataForPendingItems(
          filteredItems,
          cartDataOverride: capturedCartData,
          customerOverride: capturedCustomer,
          pickupTimeOverride: capturedPickupTime,
          orderNumberOverride: capturedOrderNumber,
          resolvedCustomerOverride: capturedResolvedCustomer,
        );
        try {
          final interfaceType = _printerTypeToString(printer.type);
          final success = await PrinterService.printKitchenOrder(
            interfaceType: interfaceType,
            identifier: printer.identifier,
            orderData: orderData,
          );
          if (success) {
            for (final item in filteredItems) {
              printedItemIds.add(item.id);
            }
          } else {
            allSuccess = false;
          }
        } catch (e) {
          debugPrint('Error printing to ${printer.name}: $e');
          allSuccess = false;
        }
      }

      // Safety fallback: any pending item that didn't end up on any printer
      // (label mismatch on every kitchen printer) is sent to every kitchen
      // printer. This rescues mismatched items even when other items in the
      // same cart were already printed (e.g. a custom item went through as
      // a wildcard).
      if (kitchenPrinters.isNotEmpty) {
        final unmatchedItems = pendingItems
            .where((i) => !printedItemIds.contains(i.id))
            .toList();
        if (unmatchedItems.isNotEmpty) {
          usedFallback = true;
          final orderData = _formatOrderDataForPendingItems(
            unmatchedItems,
            cartDataOverride: capturedCartData,
            customerOverride: capturedCustomer,
            pickupTimeOverride: capturedPickupTime,
            orderNumberOverride: capturedOrderNumber,
            resolvedCustomerOverride: capturedResolvedCustomer,
          );
          for (final printer in kitchenPrinters) {
            anyPrinted = true;
            try {
              final interfaceType = _printerTypeToString(printer.type);
              final success = await PrinterService.printKitchenOrder(
                interfaceType: interfaceType,
                identifier: printer.identifier,
                orderData: orderData,
              );
              if (success) {
                for (final item in unmatchedItems) {
                  printedItemIds.add(item.id);
                }
              } else {
                allSuccess = false;
              }
            } catch (e) {
              debugPrint('Error printing to ${printer.name} (fallback): $e');
              allSuccess = false;
            }
          }
        }
      }

      // Only mark items as inKitchen=true after a confirmed successful print.
      // Leaving them as pending lets the user retry when nothing actually
      // printed (no label match, native error, partial failure, etc.).
      final pendingIds = pendingItems.map((i) => i.id).toSet();
      if (allSuccess && anyPrinted && mounted) {
        setState(() {
          _cartItems = _cartItems.map((item) {
            if (pendingIds.contains(item.id) && item.itemStatus != 'Voided') {
              return item.copyWith(inKitchen: true);
            }
            return item;
          }).toList();
        });
      }

      if (mounted) {
        if (!anyPrinted) {
          AppToast.warning(
            context: context,
            title: 'No Items to Print',
            description:
                'No items matched kitchen printer labels. Check printer label settings.',
          );
        } else if (allSuccess) {
          AppToast.success(
            context: context,
            title: 'Sent to Kitchen',
            description: usedFallback
                ? 'Items sent. Some items had no matching printer labels and were sent to all kitchen printers.'
                : 'Items sent to kitchen and printed successfully',
          );
        } else {
          AppToast.warning(
            context: context,
            title: 'Partially Printed',
            description:
                'Some printers failed. Items remain pending so you can retry.',
          );
        }
      }
    } catch (e) {
      debugPrint('Kitchen print error: $e');
      if (mounted) {
        AppToast.error(
          context: context,
          title: 'Printing Error',
          description: 'Print failed and items remain pending. ${e.toString()}',
        );
      }
    }
  }

  Future<void> _handlePrintCustomer() async {
    if (_cartItems.isEmpty) {
      return;
    }

    try {
      // Get receipt printers (receipt group) only
      final printers = await PrinterService.getSavedPrinters();
      final receiptPrinters = printers
          .where((p) => p.group == PrinterGroup.receipt)
          .where((p) => p.status != PrinterStatus.error)
          .toList();

      if (receiptPrinters.isEmpty) {
        AppToast.warning(
          context: context,
          title: 'No Receipt Printers Found',
          description: 'Please add a receipt printer (Receipt group) first.',
        );
        return;
      }

      setState(() {
        _isPrintingCustomer = true;
      });

      // Format order data
      final orderData = _formatOrderData();

      // Print to all receipt printers
      bool allSuccess = true;
      for (final printer in receiptPrinters) {
        try {
          final interfaceType = _printerTypeToString(printer.type);
          final success = await PrinterService.printCustomerReceipt(
            interfaceType: interfaceType,
            identifier: printer.identifier,
            orderData: orderData,
          );
          if (!success) {
            allSuccess = false;
          }
        } catch (e) {
          debugPrint('Error printing to ${printer.name}: $e');
          allSuccess = false;
        }
      }

      setState(() {
        _isPrintingCustomer = false;
      });

      if (allSuccess) {
        AppToast.success(
          context: context,
          title: 'Receipt Printed',
          description: 'Customer receipt printed successfully',
        );
      } else {
        AppToast.error(
          context: context,
          title: 'Printing Failed',
          description: 'Some printers failed. Please check printer status.',
        );
      }
    } catch (e) {
      setState(() {
        _isPrintingCustomer = false;
      });
      AppToast.error(
        context: context,
        title: 'Printing Error',
        description: 'Error printing: $e',
      );
    }
  }

  Future<void> _handlePrintQuote() async {
    if (_cartItems.isEmpty) {
      return;
    }

    try {
      // Get quote printers (quote group) only
      final printers = await PrinterService.getSavedPrinters();
      final quotePrinters = printers
          .where((p) => p.group == PrinterGroup.quote)
          .where((p) => p.status != PrinterStatus.error)
          .toList();

      if (quotePrinters.isEmpty) {
        AppToast.warning(
          context: context,
          title: 'No Quote Printers Found',
          description: 'Please add a quote printer (Quote group) first.',
        );
        return;
      }

      setState(() {
        _isPrintingQuote = true;
      });

      // Format order data
      final orderData = _formatOrderData();

      // Print to all quote printers
      bool allSuccess = true;
      for (final printer in quotePrinters) {
        try {
          final interfaceType = _printerTypeToString(printer.type);
          final success = await PrinterService.printQuote(
            interfaceType: interfaceType,
            identifier: printer.identifier,
            orderData: orderData,
          );
          if (!success) {
            allSuccess = false;
          }
        } catch (e) {
          debugPrint('Error printing to ${printer.name}: $e');
          allSuccess = false;
        }
      }

      setState(() {
        _isPrintingQuote = false;
      });

      if (allSuccess) {
        AppToast.success(
          context: context,
          title: 'Quote Printed',
          description: 'Quote printed successfully',
        );
      } else {
        AppToast.error(
          context: context,
          title: 'Printing Failed',
          description: 'Some printers failed. Please check printer status.',
        );
      }
    } catch (e) {
      setState(() {
        _isPrintingQuote = false;
      });
      AppToast.error(
        context: context,
        title: 'Printing Error',
        description: 'Error printing: $e',
      );
    }
  }

  /// Show split receipt dialog and print receipts per selection
  Future<void> _handlePrintSplitReceipts() async {
    if (_cartItems.isEmpty) {
      AppToast.info(
        context: context,
        title: 'No Items',
        description: 'Add items to print receipts',
      );
      return;
    }

    final partySize = _tableInfo?['partySize'] as int? ?? 4;

    await showDialog(
      context: context,
      builder: (context) => PrintSplitReceiptDialog(
        partySize: partySize,
        items: _cartItems.where((item) => item.itemStatus != 'Voided').toList(),
        currentTableName: _currentTableName,
        onPrintSelected: (result) async {
          await _printSplitReceipts(result);
        },
      ),
    );
  }

  /// Print receipts for each selected guest group and table
  Future<void> _printSplitReceipts(PrintSplitReceiptResult result) async {
    try {
      // Get receipt printers
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

      int printedCount = 0;
      int failedCount = 0;

      // Print receipts for each selected guest group
      for (final guestGroup in result.selectedGuestGroups) {
        final orderData = _formatOrderDataForGuestGroup(guestGroup);
        if (orderData == null) continue;

        for (final printer in receiptPrinters) {
          try {
            final interfaceType = _printerTypeToString(printer.type);
            final success = await PrinterService.printCustomerReceipt(
              interfaceType: interfaceType,
              identifier: printer.identifier,
              orderData: orderData,
            );
            if (success) {
              printedCount++;
            } else {
              failedCount++;
            }
          } catch (e) {
            debugPrint('Error printing split receipt: $e');
            failedCount++;
          }
        }
      }

      if (mounted) {
        if (failedCount == 0 && printedCount > 0) {
          AppToast.success(
            context: context,
            title: 'Receipts Printed',
            description: 'Printed $printedCount receipt(s) successfully',
          );
        } else if (printedCount > 0) {
          AppToast.warning(
            context: context,
            title: 'Partial Success',
            description: 'Printed $printedCount, failed $failedCount',
          );
        } else {
          AppToast.error(
            context: context,
            title: 'Printing Failed',
            description: 'Failed to print receipts',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context: context,
          title: 'Printing Error',
          description: 'Error: $e',
        );
      }
    }
  }

  /// Format order data for a specific guest group
  Map<String, dynamic>? _formatOrderDataForGuestGroup(String guestGroup) {
    // Filter items for this guest group only
    final filteredItems = _cartItems
        .where((item) => item.itemStatus != 'Voided')
        .where((item) => item.guestGroup == guestGroup)
        .toList();

    if (filteredItems.isEmpty) return null;

    // Calculate totals for filtered items only
    final subtotal = filteredItems.fold(
      0.0,
      (sum, item) => sum + _calculateItemTotal(item),
    );

    // Calculate guest-specific discount based on this guest's subtotal
    // Percentage discounts apply directly to guest's subtotal;
    // flat-amount discounts are prorated by guest's share of total order subtotal.
    final totalOrderSubtotal = _cartItems
        .where((item) => item.itemStatus != 'Voided')
        .fold(0.0, (sum, item) => sum + _calculateItemTotal(item));

    final guestDiscountAmount = _cartData?.discount != null
        ? (_cartData!.discount!.type == '%'
              ? subtotal * (_cartData!.discount!.value / 100)
              : (totalOrderSubtotal > 0
                    ? _cartData!.discount!.value *
                          (subtotal / totalOrderSubtotal)
                    : 0.0))
        : 0.0;

    final guestCouponAmount =
        _cartData?.coupon != null && _cartData!.coupon!.code.isNotEmpty
        ? (_cartData!.coupon!.type == '%'
              ? subtotal * (_cartData!.coupon!.discount / 100)
              : (totalOrderSubtotal > 0
                    ? _cartData!.coupon!.discount *
                          (subtotal / totalOrderSubtotal)
                    : 0.0))
        : 0.0;

    final guestDiscount = guestDiscountAmount + guestCouponAmount;

    // Calculate tax only for taxable items using per-item tax rules
    // This matches the main cart tax calculation logic in cart_drawer.dart
    final taxableItems = filteredItems
        .where((item) => item.product.taxEnable)
        .toList();

    final tax = taxableItems.fold(0.0, (sum, item) {
      final itemTotal = _calculateItemTotal(item);
      // Apply guest discount proportionally based on item's ratio to guest subtotal
      final itemRatio = subtotal > 0 ? itemTotal / subtotal : 0.0;
      final itemDiscountShare = guestDiscount * itemRatio;
      final finalItemTotal = itemTotal - itemDiscountShare;

      final taxRate = (item.product.taxRule?.amount ?? 0) / 100;
      return sum + (finalItemTotal * taxRate);
    });

    // Apply discount to calculate total
    final discountedSubtotal = subtotal - guestDiscount;
    final total = discountedSubtotal + tax;

    // Format items with modifiers
    final items = filteredItems.map((item) {
      final populatedModifiers = _getPopulatedModifiers(item.modifiers);
      final modifierList = populatedModifiers.entries
          .expand(
            (entry) => entry.value.map(
              (mod) => {
                'name': mod.name,
                'priceAdjustment': mod.priceAdjustment,
                'group': entry.key,
              },
            ),
          )
          .toList();

      double basePrice = item.product.posEffectivePrice;
      double modifierPrice = 0.0;
      for (final mods in populatedModifiers.values) {
        for (final mod in mods) {
          modifierPrice += mod.priceAdjustment;
        }
      }
      final itemPrice = (basePrice + modifierPrice) * item.quantity;

      return {
        'quantity': item.quantity,
        'name': item.product.name,
        'price': itemPrice,
        'modifiers': modifierList,
        'itemNote': item.itemNote,
        'guestGroup': item.guestGroup,
      };
    }).toList();

    final now = DateTime.now();
    final dateFormat = DateFormat('MMM dd, yyyy, HH:mm');
    final orderDate = dateFormat.format(now);
    final store = _dataProvider.store;

    // Get guest label for split info
    final guestLabel = guestGroup == 'whole_table'
        ? 'Whole Table'
        : 'Guest ${guestGroup.split('_').last}';

    return {
      'storeName': store?.name ?? 'Store',
      'storeAddress': store?.address?.fullAddress ?? '',
      'storePhone': store?.phone ?? '',
      'storeEmail': store?.email ?? '',
      'orderNumber': _editingOrderNumber ?? 'NEW',
      'orderDate': orderDate,
      'orderType': _getOrderTypeLabel(_orderType),
      'placedAt': DateFormat('MMMM dd, h:mm a').format(now),
      'floorPlanName': _tableInfo?['floorPlanName'] as String? ?? '',
      'tableName': _tableInfo?['tableName'] as String? ?? '',
      'partySize': _tableInfo?['partySize'] as int? ?? 0,
      'dueAt': DateFormat(
        'MMMM dd, h:mm a',
      ).format(_selectedPickupTime ?? now.add(const Duration(minutes: 25))),
      'customerName': _selectedCustomer?.fullName ?? '',
      'customerPhone': _selectedCustomer?.phone ?? '',
      'items': items,
      'subtotal': subtotal,
      'tax': tax,
      'tip': 0.0,
      'discount': guestDiscount,
      'total': total,
      'note': _cartData?.note ?? '',
      'splitInfo': guestLabel,
    };
  }

  List<CartItem> _filterItemsForPrinter(List<CartItem> items, Printer printer) {
    if (printer.selectedLabels.isEmpty) return items;
    final products = _dataProvider.productsList;
    return items.where((item) {
      final matching = products.where((p) => p.id == item.product.id);
      final labels = matching.isNotEmpty
          ? matching.first.labels
          : item.product.labels;
      if (labels.isEmpty) return true;
      return labels.any((labelId) => printer.selectedLabels.contains(labelId));
    }).toList();
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

  String _getOrderTypeLabel(String orderType) {
    switch (orderType) {
      case ApiConstants.uiOrderTypeTakeout:
      case ApiConstants.uiOrderTypePrepay:
        return 'PICKUP';
      case ApiConstants.uiOrderTypeDelivery:
        return 'DELIVERY';
      case ApiConstants.uiOrderTypeDineIn:
        return 'DINE-IN';
      default:
        return orderType.toUpperCase();
    }
  }

  Map<String, dynamic> _formatOrderDataForPendingItems(
    List<CartItem> pendingItems, {
    CartData? cartDataOverride,
    Customer? customerOverride,
    DateTime? pickupTimeOverride,
    String? orderNumberOverride,
    Customer? resolvedCustomerOverride,
  }) {
    final effectiveCartData = cartDataOverride ?? _cartData;
    final effectiveCustomer = customerOverride ?? _selectedCustomer;
    final effectivePickupTime = pickupTimeOverride ?? _selectedPickupTime;
    final effectiveOrderNumber = orderNumberOverride ?? _editingOrderNumber;
    final effectiveResolvedCustomer =
        resolvedCustomerOverride ?? _getResolvedCustomer();

    // Calculate totals for pending items only
    final subtotal = pendingItems.fold(
      0.0,
      (sum, item) => sum + _calculateItemTotal(item),
    );

    final discountAmount = effectiveCartData?.discount != null
        ? (effectiveCartData!.discount!.type == '%'
              ? subtotal * (effectiveCartData.discount!.value / 100)
              : effectiveCartData.discount!.value)
        : 0.0;

    final couponAmount =
        effectiveCartData?.coupon != null &&
            effectiveCartData!.coupon!.code.isNotEmpty
        ? (effectiveCartData.coupon!.type == '%'
              ? subtotal * (effectiveCartData.coupon!.discount / 100)
              : effectiveCartData.coupon!.discount)
        : 0.0;

    final discountedTotal = subtotal - discountAmount - couponAmount;

    final tax = pendingItems.where((item) => item.product.taxEnable).fold(0.0, (
      sum,
      item,
    ) {
      final itemTotal = _calculateItemTotal(item);
      final itemRatio = subtotal > 0 ? itemTotal / subtotal : 0.0;
      final itemDiscount = discountAmount * itemRatio;
      final itemCoupon = couponAmount * itemRatio;
      final finalItemTotal = itemTotal - itemDiscount - itemCoupon;
      final taxRate = (item.product.taxRule?.amount ?? 0) / 100;
      return sum + (finalItemTotal * taxRate);
    });

    final feeAmount = effectiveCartData?.fees.isEmpty ?? true
        ? 0.0
        : effectiveCartData!.fees.fold(0.0, (sum, fee) {
            if (fee.type == '%') {
              return sum + (subtotal * fee.value / 100);
            }
            return sum + fee.value;
          });

    final total = discountedTotal + feeAmount + tax;

    final items = pendingItems.map((item) {
      final populatedModifiers = _getPopulatedModifiers(item.modifiers);
      final modifierList = populatedModifiers.entries
          .expand(
            (entry) => entry.value.map(
              (mod) => {
                'name': mod.name,
                'priceAdjustment': mod.priceAdjustment,
                'group': entry.key,
              },
            ),
          )
          .toList();

      double basePrice = item.product.posEffectivePrice;
      double modifierPrice = 0.0;
      for (final mods in populatedModifiers.values) {
        for (final mod in mods) {
          modifierPrice += mod.priceAdjustment;
        }
      }
      final itemPrice = (basePrice + modifierPrice) * item.quantity;

      return {
        'quantity': item.quantity,
        'name': item.product.name,
        'price': itemPrice,
        'modifiers': modifierList,
        'itemNote': item.itemNote,
        'guestGroup': item.guestGroup,
      };
    }).toList();

    final now = DateTime.now();
    final dateFormat = DateFormat('MMM dd, yyyy, HH:mm');
    final orderDate = dateFormat.format(now);

    final store = _dataProvider.store;

    final orderNote = effectiveCartData?.note ?? '';
    debugPrint('🔍 Kitchen receipt note: "$orderNote"');

    return {
      'storeName': store?.name ?? 'Store',
      'storeAddress': store?.address?.fullAddress ?? '',
      'storePhone': store?.phone ?? '',
      'storeEmail': store?.email ?? '',
      'orderNumber': effectiveOrderNumber ?? 'NEW',
      'orderDate': orderDate,
      'orderType': _getOrderTypeLabel(_orderType),
      'placedAt': DateFormat('MMMM dd, h:mm a').format(now),
      'dueAt': DateFormat(
        'MMMM dd, h:mm a',
      ).format(effectivePickupTime ?? now.add(const Duration(minutes: 25))),
      'customerName': effectiveCustomer?.fullName ?? '',
      'floorPlanName': _tableInfo?['floorPlanName'] as String? ?? '',
      'tableName': _tableInfo?['tableName'] as String? ?? '',
      'partySize': _tableInfo?['partySize'] as int? ?? 0,
      'customerPhone': effectiveCustomer?.phone ?? '',
      'isReturningCustomer': effectiveResolvedCustomer?.isReturning ?? false,
      'customerOrderCount': effectiveResolvedCustomer?.ordersCount ?? 0,
      'items': items,
      'subtotal': subtotal,
      'tax': tax,
      'tip': 0.0,
      'discount': discountAmount + couponAmount,
      'total': total,
      'note': orderNote,
      // Prefer the staff selected in the party-size dialog (the assigned
      // server) so kitchen receipts show the right name; fall back to the
      // logged-in user otherwise.
      'createdBy':
          _selectedStaff ??
          (_authService.getProfile() != null
              ? {
                  '_id': _authService.getProfile()!.id,
                  'email': _authService.getProfile()!.email,
                  'firstName': _authService.getProfile()!.firstName,
                  'lastName': _authService.getProfile()!.lastName,
                }
              : null),
    };
  }

  Map<String, dynamic> _formatOrderData() {
    debugPrint('🔍 _formatOrderData cartData: $_cartData');
    // Calculate totals (similar to cart_drawer)
    final subtotal = _cartItems
        .where((item) => item.itemStatus != 'Voided')
        .fold(0.0, (sum, item) => sum + _calculateItemTotal(item));

    final discountAmount = _cartData?.discount != null
        ? (_cartData!.discount!.type == '%'
              ? subtotal * (_cartData!.discount!.value / 100)
              : _cartData!.discount!.value)
        : 0.0;

    final couponAmount =
        _cartData?.coupon != null && _cartData!.coupon!.code.isNotEmpty
        ? (_cartData!.coupon!.type == '%'
              ? subtotal * (_cartData!.coupon!.discount / 100)
              : _cartData!.coupon!.discount)
        : 0.0;

    final discountedTotal = subtotal - discountAmount - couponAmount;

    final tax = _cartItems
        .where((item) => item.itemStatus != 'Voided' && item.product.taxEnable)
        .fold(0.0, (sum, item) {
          final itemTotal = _calculateItemTotal(item);
          final itemRatio = subtotal > 0 ? itemTotal / subtotal : 0.0;
          final itemDiscount = discountAmount * itemRatio;
          final itemCoupon = couponAmount * itemRatio;
          final finalItemTotal = itemTotal - itemDiscount - itemCoupon;
          final taxRate = (item.product.taxRule?.amount ?? 0) / 100;
          return sum + (finalItemTotal * taxRate);
        });

    final feeAmount = _cartData?.fees.isEmpty ?? true
        ? 0.0
        : _cartData!.fees.fold(0.0, (sum, fee) {
            if (fee.type == '%') {
              return sum + (subtotal * fee.value / 100);
            }
            return sum + fee.value;
          });

    final total = discountedTotal + feeAmount + tax;

    // Format items with modifiers
    final items = _cartItems.where((item) => item.itemStatus != 'Voided').map((
      item,
    ) {
      // Get modifiers for this item
      final populatedModifiers = _getPopulatedModifiers(item.modifiers);
      final modifierList = populatedModifiers.entries
          .expand(
            (entry) => entry.value.map(
              (mod) => {
                'name': mod.name,
                'priceAdjustment': mod.priceAdjustment,
                'group': entry.key,
              },
            ),
          )
          .toList();

      // Calculate item price with modifiers
      double basePrice = item.product.posEffectivePrice;
      double modifierPrice = 0.0;
      for (final mods in populatedModifiers.values) {
        for (final mod in mods) {
          modifierPrice += mod.priceAdjustment;
        }
      }
      final itemPrice = (basePrice + modifierPrice) * item.quantity;

      return {
        'quantity': item.quantity,
        'name': item.product.name,
        'price': itemPrice,
        'modifiers': modifierList,
        'itemNote': item.itemNote,
        'guestGroup':
            item.guestGroup, // Include guest group for dine-in grouping
      };
    }).toList();

    // Format date
    final now = DateTime.now();
    final dateFormat = DateFormat('MMM dd, yyyy, HH:mm');
    final orderDate = dateFormat.format(now);

    // Get store details from DataProvider
    final store = _dataProvider.store;

    // Resolve full customer from DataProvider for accurate returning customer data
    final resolvedCustomer = _getResolvedCustomer();

    return {
      'storeName': store?.name ?? 'Store',
      'storeAddress': store?.address?.fullAddress ?? '',
      'storePhone': store?.phone ?? '',
      'storeEmail': store?.email ?? '',
      'orderNumber': _editingOrderNumber ?? 'NEW',
      'orderDate': orderDate,
      'orderType': _getOrderTypeLabel(_orderType),
      'placedAt': DateFormat('MMMM dd, h:mm a').format(now),
      // Dine-in specific fields
      'floorPlanName': _tableInfo?['floorPlanName'] as String? ?? '',
      'tableName': _tableInfo?['tableName'] as String? ?? '',
      'partySize': _tableInfo?['partySize'] as int? ?? 0,
      'dueAt': DateFormat(
        'MMMM dd, h:mm a',
      ).format(_selectedPickupTime ?? now.add(const Duration(minutes: 25))),
      'customerName': _selectedCustomer?.fullName ?? '',
      'customerPhone': _selectedCustomer?.phone ?? '',
      'isReturningCustomer': resolvedCustomer?.isReturning ?? false,
      'customerOrderCount': resolvedCustomer?.ordersCount ?? 0,
      'items': items,
      'subtotal': subtotal,
      'tax': tax,
      'tip': 0.0, // Tip is added at checkout
      'discount': discountAmount + couponAmount,
      'total': total,
      'note': _cartData?.note ?? '',
      // Prefer the assigned server (selected in the party-size dialog).
      // Falls back to the authenticated user.
      'createdBy':
          _selectedStaff ??
          (_authService.getProfile() != null
              ? {
                  '_id': _authService.getProfile()!.id,
                  'email': _authService.getProfile()!.email,
                  'firstName': _authService.getProfile()!.firstName,
                  'lastName': _authService.getProfile()!.lastName,
                }
              : null),
    };
  }

  // Helper to resolve full customer from DataProvider for accurate returning customer data
  Customer? _getResolvedCustomer() {
    if (_selectedCustomer == null) return null;

    // Try to find the full customer from DataProvider for complete data (including orders)
    final fullCustomer = _dataProvider.customersList.firstWhere(
      (c) => c.id == _selectedCustomer!.id,
      orElse: () => _selectedCustomer!,
    );
    return fullCustomer;
  }

  // Refresh selected customer from API to ensure returning customer data is accurate
  // Refresh selected customer from API to ensure returning customer data is accurate.
  // We always refetch (no ordersCount short-circuit) because the cached customer
  // record can have a stale `isReturning` flag -- e.g. the customer placed a web
  // order between the POS's last customer load and this print, which flips
  // isReturning=true on the server but leaves the local cache untouched.
  Future<void> _refreshSelectedCustomerForPrint() async {
    if (_selectedCustomer == null) return;

    try {
      debugPrint(
        'Refreshing customer data for print: ${_selectedCustomer!.id}',
      );
      final freshCustomer = await _customersService.getCustomerById(
        _selectedCustomer!.id,
      );

      // Update selected customer and DataProvider
      setState(() {
        _selectedCustomer = freshCustomer;
      });
      _dataProvider.updateCustomerInMemory(freshCustomer);

      debugPrint(
        '✅ Customer refreshed: isReturning=${freshCustomer.isReturning}, ordersCount=${freshCustomer.ordersCount}',
      );
    } catch (e) {
      debugPrint('⚠️ Failed to refresh customer for print: $e');
      // Continue with existing data if refresh fails
    }
  }

  // Cache for modifier lookups to improve performance
  Map<String, Modifier>? _modifierCache;

  Map<String, Modifier> _getModifierCache() {
    if (_modifierCache == null) {
      _modifierCache = {};
      for (final modifier in _modifiers) {
        _modifierCache![modifier.id] = modifier;
      }
    }
    return _modifierCache!;
  }

  Map<String, List<Modifier>> _getPopulatedModifiers(
    Map<String, List<String>> itemModifiers,
  ) {
    final Map<String, List<Modifier>> populated = {};
    if (itemModifiers.isEmpty) return populated;

    // Use cached HashMap for O(1) lookups instead of O(n) firstWhere
    final cache = _getModifierCache();

    itemModifiers.forEach((groupName, modifierIds) {
      if (!populated.containsKey(groupName)) {
        populated[groupName] = [];
      }
      for (final modifierId in modifierIds) {
        final modifier =
            cache[modifierId] ??
            Modifier(
              id: modifierId,
              name: 'Unknown',
              priceAdjustment: 0,
              isActive: true,
            );
        populated[groupName]!.add(modifier);
      }
    });
    return populated;
  }

  // Helper method to calculate item price per unit with modifiers
  double _calculateItemPricePerUnit(CartItem item) {
    double basePrice = item.product.posEffectivePrice;
    double modifierPrice = 0.0;

    if (item.modifiers.isNotEmpty) {
      final populatedModifiers = _getPopulatedModifiers(item.modifiers);
      for (final mods in populatedModifiers.values) {
        for (final mod in mods) {
          modifierPrice += mod.priceAdjustment;
        }
      }
    }

    return basePrice + modifierPrice;
  }

  // Helper method to calculate item total with modifiers and discounts
  double _calculateItemTotal(CartItem item) {
    final pricePerUnit = _calculateItemPricePerUnit(item);
    final baseTotal = pricePerUnit * item.quantity;

    // Apply item discount if any
    if (item.itemDiscount != null && item.itemDiscount!.value > 0) {
      if (item.itemDiscount!.type == '%') {
        return baseTotal * (1 - item.itemDiscount!.value / 100);
      } else {
        return baseTotal - item.itemDiscount!.value;
      }
    }

    return baseTotal;
  }

  int get _totalCartItems =>
      _cartItems.fold(0, (sum, item) => sum + item.quantity);

  bool get _hasPendingItems {
    return _cartItems.any(
      (item) => item.itemStatus != 'Voided' && !item.inKitchen,
    );
  }

  /// Show shift table dialog for dine-in orders
  Future<void> _handleShiftTable() async {
    if (!_isEditMode || _editingOrderId == null || _tableInfo == null) {
      AppToast.info(
        context: context,
        title: 'Not Available',
        description: 'Table can only be changed after order is created',
      );
      return;
    }

    final currentPartySize = _tableInfo?['partySize'] as int?;

    await showDialog(
      context: context,
      builder: (context) => ShiftTableDialog(
        orderId: _editingOrderId!,
        currentTableId: _tableInfo?['tableId'] as String?,
        currentTableName: _tableInfo?['tableName'] as String?,
        currentPartySize: currentPartySize,
        onTableShifted: (newTable, floorPlan) {
          // Update local table info, preserving original party size
          setState(() {
            _tableInfo = {
              'tableId': newTable.id,
              'tableName': newTable.name,
              'floorPlanId': floorPlan.id,
              'partySize':
                  currentPartySize ?? 0, // Preserve original guest count
            };
          });
        },
      ),
    );
  }

  /// Get current table name for display
  String? get _currentTableName => _tableInfo?['tableName'] as String?;

  /// Show shift guest dialog to move items between guests
  Future<void> _handleShiftGuest() async {
    final partySize = _tableInfo?['partySize'] as int? ?? 4;

    // Get items in the selected guest group that can be shifted
    final shiftableItems = _cartItems
        .where(
          (item) =>
              item.guestGroup == _selectedGuestGroup &&
              item.itemStatus != 'Voided',
        )
        .toList();

    if (shiftableItems.isEmpty) {
      AppToast.info(
        context: context,
        title: 'No Items',
        description: 'No items to shift from this guest',
      );
      return;
    }

    final sourceGuestGroup = _selectedGuestGroup;

    await showDialog(
      context: context,
      builder: (context) => ShiftGuestDialog(
        currentGuestGroup: sourceGuestGroup,
        partySize: partySize,
        items: shiftableItems,
        onGuestShifted: (targetGuestGroup, selectedItemIds) async {
          // Update only the selected cart items
          final updatedCartItems = _cartItems.map((item) {
            if (selectedItemIds.contains(item.id) &&
                item.guestGroup == sourceGuestGroup &&
                item.itemStatus != 'Voided') {
              return item.copyWith(guestGroup: targetGuestGroup);
            }
            return item;
          }).toList();

          // If in edit mode, call API to persist the change
          if (_isEditMode && _editingOrderId != null) {
            try {
              // Convert updated cart items to API format
              final items = updatedCartItems
                  .where((item) => item.itemStatus != 'Voided')
                  .map((item) {
                    final modifierIds = item.modifiers.values
                        .expand((modifierList) => modifierList)
                        .toList();

                    Map<String, dynamic>? itemDiscount;
                    if (item.itemDiscount != null &&
                        item.itemDiscount!.value > 0) {
                      itemDiscount = {
                        'type': item.itemDiscount!.type,
                        'value': item.itemDiscount!.value,
                      };
                    }

                    return {
                      if (item.product.type != 'custom')
                        'item': item.product.id,
                      if (item.product.type == 'custom')
                        'customItem': item.product.name,
                      'quantity': item.quantity,
                      'price': _calculateItemPricePerUnit(item),
                      'modifiers': modifierIds,
                      'itemNote': item.itemNote,
                      if (itemDiscount != null) 'itemDiscount': itemDiscount,
                      'guestGroup': item.guestGroup,
                      'taxEnable': item.product.taxEnable,
                      if (item.product.taxRule != null)
                        'taxRule': item.product.taxRule!.toJson(),
                    };
                  })
                  .toList();

              // Resolve store and call updateOrder with updated items
              final storeId = await _resolveStoreId(_editingOrderId);
              final updatedOrder = await _ordersService.updateOrder(
                orderId: _editingOrderId!,
                store: storeId,
                items: items,
              );

              // Update local cart items from the returned order
              if (mounted) {
                _convertOrderItemsToCartItems(updatedOrder.items);
                setState(() {
                  _selectedGuestGroup = targetGuestGroup;
                });

                AppToast.success(
                  context: context,
                  title: 'Items Shifted',
                  description:
                      '${selectedItemIds.length} item(s) moved successfully',
                );
              }
            } catch (e) {
              if (mounted) {
                AppToast.error(
                  context: context,
                  title: 'Error',
                  description: e.toString().replaceAll('Exception: ', ''),
                );
              }
            }
          } else {
            // For new orders (not yet created), just update local state
            setState(() {
              _cartItems = updatedCartItems;
              _selectedGuestGroup = targetGuestGroup;
            });

            AppToast.success(
              context: context,
              title: 'Items Shifted',
              description:
                  '${selectedItemIds.length} item(s) moved successfully',
            );
          }
        },
      ),
    );
  }

  Future<bool> _handleWillPop() async {
    if (!_hasPendingItems) {
      return true; // Allow navigation if no pending items
    }

    // Show warning dialog
    final shouldLeave = await WarningDialog.show(
      context: context,
      title: 'Pending Items in Cart',
      message:
          'You have items in your cart that haven\'t been sent to kitchen.',
      infoMessage:
          'If you leave now, these items will be removed from the cart.',
      confirmText: 'Leave',
      cancelText: 'Cancel',
      type: WarningDialogType.warning,
      barrierDismissible: false,
    );

    if (shouldLeave == true) {
      // Clear cart when user confirms leaving
      setState(() {
        _cartItems.clear();
        _cartData = null;
        _selectedCustomer = null;
      });
      return true;
    }

    return false; // Prevent navigation
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 1024;

    return PopScope(
      canPop: !_hasPendingItems,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (!didPop && _hasPendingItems) {
          final shouldLeave = await _handleWillPop();
          if (shouldLeave && mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: const AppDrawer(),
        body: Scaffold(
          key: _categoriesScaffoldKey,
          onEndDrawerChanged: (isOpened) {
            setState(() {
              _isDrawerOpen = isOpened;
            });
          },
          drawer: isSmallScreen
              ? Drawer(
                  width: 270,
                  child: SafeArea(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(color: Colors.white),
                      child: CategoriesSidebar(
                        categories: _categories,
                        products: _allProducts,
                        selectedCategoryId: _selectedCategoryId,
                        onCategorySelected: (categoryId) {
                          _handleCategorySelected(categoryId);
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ),
                )
              : null,
          endDrawer: isSmallScreen
              ? CartDrawer(
                  isSelfOrder: true,
                  cartItems: _cartItems,
                  cartData: _cartData,
                  orderId: _editingOrderId,
                  orderNumber: _editingOrderNumber,
                  customerName: _selectedCustomer?.fullName,
                  customer: _selectedCustomer,
                  isEditMode: _isEditMode,
                  orderType: _orderType,
                  onItemUpdate: _handleCartItemUpdate,
                  onItemRemove: _handleCartItemRemove,
                  onCustomerSelect: _showCustomerModal,
                  onNoteTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => CartNoteModal(
                        note: _cartData?.note,
                        onConfirm: (note) {
                          setState(() {
                            _cartData = CartData(
                              note: note,
                              discount: _cartData?.discount,
                              coupon: _cartData?.coupon,
                              fees: _cartData?.fees ?? [],
                            );
                          });
                        },
                        onCancel: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    );
                  },
                  onDiscountTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => CartDiscountModal(
                        discount: _cartData?.discount,
                        onConfirm: (discount) {
                          _handleDiscountUpdate(discount);
                        },
                        onCancel: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    );
                  },
                  onNoteUpdate: (note) {
                    _handleNoteUpdate(note);
                  },
                  onDiscountUpdate: (discount) {
                    _handleDiscountUpdate(discount);
                  },
                  onCouponTap: () {
                    // TODO: Handle coupon tap
                    AppToast.info(
                      context: context,
                      title: 'Coming Soon',
                      description: 'Coupon feature will be available soon',
                    );
                  },
                  onContactTap: () {
                    // TODO: Handle contact tap
                    AppToast.info(
                      context: context,
                      title: 'Coming Soon',
                      description: 'Contact feature will be available soon',
                    );
                  },
                  onAddItemTap: _handleAddCustomItem,
                  // Dine-in uses shift table instead of pickup time
                  onShiftTableTap: _handleShiftTable,
                  onShiftGuestTap: _handleShiftGuest,
                  currentTableName: _currentTableName,
                  onPrintKitchen: _handlePrintKitchen,
                  isPrintingKitchen: _isPrintingKitchen,
                  onPrintCustomer: _handlePrintCustomer,
                  isPrintingCustomer: _isPrintingCustomer,
                  onPrintQuote: _handlePrintQuote,
                  isPrintingQuote: _isPrintingQuote,
                  onPrintSplitReceipt: _handlePrintSplitReceipts,
                  isCreatingOrder: _isCreatingOrder,
                  onSendToKitchen: () async {
                    // Create order and send to kitchen
                    await _handleSendToKitchen();
                  },
                  onCheckout: () {
                    // Navigate to checkout for prepay orders or when all items are in kitchen (edit mode)
                    final allInKitchen =
                        _cartItems.isNotEmpty &&
                        _cartItems.every(
                          (item) =>
                              item.itemStatus == 'Voided' || item.inKitchen,
                        );

                    if (_orderType == ApiConstants.uiOrderTypePrepay ||
                        allInKitchen) {
                      Navigator.pushNamed(
                        context,
                        '/orders/checkout',
                        arguments: {
                          'cartItems': _cartItems,
                          'cartData': _cartData,
                          'customer': _selectedCustomer,
                          'orderType': _orderType,
                          'orderId': _editingOrderId,
                          'orderNumber': _editingOrderNumber,
                          'isEditMode': _isEditMode,
                          'pickupTime': _selectedPickupTime,
                        },
                      );
                    } else {
                      // TODO: Handle checkout for other order types
                      AppToast.info(
                        context: context,
                        title: 'Coming Soon',
                        description: 'Checkout feature will be available soon',
                      );
                    }
                  },
                  onClearCart: () {
                    setState(() {
                      _cartItems.clear();
                      _cartData = null;
                      _selectedCustomer = null;
                      _selectedPickupTime = null;
                    });
                    // Play clear cart sound
                    _audioService.playClearCart();
                  },
                  onVoidOrder: (updatedOrder) {
                    // Use the order returned from void API directly - no refetch needed!
                    if (mounted && updatedOrder.items.isNotEmpty) {
                      _convertOrderItemsToCartItems(updatedOrder.items);
                    }
                  },
                  // Dine-in specific props
                  onGuestGroupChanged: (guestGroup) {
                    setState(() {
                      _selectedGuestGroup = guestGroup;
                    });
                  },
                  selectedGuestGroup: _selectedGuestGroup,
                  partySize: _tableInfo?['partySize'] as int?,
                  orderCreatedAt: _orderCreatedAt,
                )
              : null,
          body: SafeArea(
            child: Column(
              children: [
                Builder(
                  builder: (context) => Row(
                    children: [
                      Expanded(
                        child: HeaderWidget(
                          logoUrl: 'https://zipzappos.com',
                          onHomePressed: () async {
                            if (_hasPendingItems) {
                              final shouldLeave = await _handleWillPop();
                              if (shouldLeave && mounted) {
                                Navigator.of(
                                  context,
                                ).popUntil((route) => route.isFirst);
                              }
                            } else {
                              Navigator.of(
                                context,
                              ).popUntil((route) => route.isFirst);
                            }
                          },
                          onDrawerPressed: () {
                            _scaffoldKey.currentState?.openDrawer();
                          },
                          onCategoriesPressed: isSmallScreen
                              ? () {
                                  _categoriesScaffoldKey.currentState
                                      ?.openDrawer();
                                }
                              : null,
                          onSearchChanged: _handleSearchChanged,
                          serverStatus: true,
                          isRefetching: _dataProvider.isRefetching,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Categories Sidebar (left)
                      if (!isSmallScreen)
                        CategoriesSidebar(
                          categories: _categories,
                          products: _allProducts,
                          selectedCategoryId: _selectedCategoryId,
                          onCategorySelected: _handleCategorySelected,
                        ),
                      // Products List (middle)
                      Expanded(
                        child: ProductsList(
                          products: _filteredProducts,
                          onProductTap: _handleProductTap,
                          cartProductIds: _cartItems
                              .map((item) => item.product.id)
                              .toSet()
                              .toList(),
                        ),
                      ),
                      // Cart Sidebar (right) - only on large screens
                      if (!isSmallScreen)
                        CartDrawer(
                          isSelfOrder: true,
                          cartItems: _cartItems,
                          cartData: _cartData,
                          orderId: _editingOrderId,
                          orderNumber: _editingOrderNumber,
                          customerName: _selectedCustomer?.fullName,
                          customer: _selectedCustomer,
                          isEditMode: _isEditMode,
                          orderType: _orderType,
                          onItemUpdate: _handleCartItemUpdate,
                          onItemRemove: _handleCartItemRemove,
                          onCustomerSelect: _showCustomerModal,
                          onNoteTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => CartNoteModal(
                                note: _cartData?.note,
                                onConfirm: (note) {
                                  setState(() {
                                    _cartData = CartData(
                                      note: note,
                                      discount: _cartData?.discount,
                                      coupon: _cartData?.coupon,
                                      fees: _cartData?.fees ?? [],
                                    );
                                  });
                                },
                                onCancel: () {
                                  Navigator.of(context).pop();
                                },
                              ),
                            );
                          },
                          onDiscountTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => CartDiscountModal(
                                discount: _cartData?.discount,
                                onConfirm: (discount) {
                                  _handleDiscountUpdate(discount);
                                },
                                onCancel: () {
                                  Navigator.of(context).pop();
                                },
                              ),
                            );
                          },
                          onNoteUpdate: (note) {
                            _handleNoteUpdate(note);
                          },
                          onDiscountUpdate: (discount) {
                            _handleDiscountUpdate(discount);
                          },
                          onCouponTap: () {
                            // TODO: Handle coupon tap
                            AppToast.info(
                              context: context,
                              title: 'Coming Soon',
                              description:
                                  'Coupon feature will be available soon',
                            );
                          },
                          onContactTap: () {
                            // TODO: Handle contact tap
                            AppToast.info(
                              context: context,
                              title: 'Coming Soon',
                              description:
                                  'Contact feature will be available soon',
                            );
                          },
                          onAddItemTap: _handleAddCustomItem,
                          // Dine-in uses shift table instead of pickup time
                          onShiftTableTap: _handleShiftTable,
                          onShiftGuestTap: _handleShiftGuest,
                          currentTableName: _currentTableName,
                          onPrintKitchen: _handlePrintKitchen,
                          isPrintingKitchen: _isPrintingKitchen,
                          onPrintCustomer: _handlePrintCustomer,
                          isPrintingCustomer: _isPrintingCustomer,
                          onPrintQuote: _handlePrintQuote,
                          isPrintingQuote: _isPrintingQuote,
                          onPrintSplitReceipt: _handlePrintSplitReceipts,
                          isCreatingOrder: _isCreatingOrder,
                          onSendToKitchen: () async {
                            // Create order and send to kitchen
                            await _handleSendToKitchen();
                          },
                          onCheckout: () {
                            // Navigate to checkout for prepay orders or when all items are in kitchen (edit mode)
                            final allInKitchen =
                                _cartItems.isNotEmpty &&
                                _cartItems.every(
                                  (item) =>
                                      item.itemStatus == 'Voided' ||
                                      item.inKitchen,
                                );

                            if (_orderType == ApiConstants.uiOrderTypePrepay ||
                                allInKitchen) {
                              Navigator.pushNamed(
                                context,
                                '/orders/checkout',
                                arguments: {
                                  'cartItems': _cartItems,
                                  'cartData': _cartData,
                                  'customer': _selectedCustomer,
                                  'orderType': _orderType,
                                  'orderId': _editingOrderId,
                                  'orderNumber': _editingOrderNumber,
                                  'isEditMode': _isEditMode,
                                  'pickupTime': _selectedPickupTime,
                                },
                              );
                            } else {
                              // TODO: Handle checkout for other order types
                              AppToast.info(
                                context: context,
                                title: 'Coming Soon',
                                description:
                                    'Checkout feature will be available soon',
                              );
                            }
                          },
                          onClearCart: () {
                            setState(() {
                              _cartItems.clear();
                              _cartData = null;
                              _selectedCustomer = null;
                              _selectedPickupTime = null;
                            });
                          },
                          onVoidOrder: (updatedOrder) {
                            // Use the order returned from void API directly - no refetch needed!
                            if (mounted && updatedOrder.items.isNotEmpty) {
                              _convertOrderItemsToCartItems(updatedOrder.items);
                            }
                          },
                          // Dine-in specific props
                          onGuestGroupChanged: (guestGroup) {
                            setState(() {
                              _selectedGuestGroup = guestGroup;
                            });
                          },
                          selectedGuestGroup: _selectedGuestGroup,
                          partySize: _tableInfo?['partySize'] as int?,
                          orderCreatedAt: _orderCreatedAt,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: isSmallScreen && !_isDrawerOpen
            ? FloatingActionButton.extended(
                onPressed: () {
                  _categoriesScaffoldKey.currentState?.openEndDrawer();
                },
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                icon: Stack(children: [const Icon(Icons.shopping_cart)]),
                label: Text(
                  '(${_totalCartItems > 99 ? '99+' : _totalCartItems})',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              )
            : null,
      ),
    );
  }
}
