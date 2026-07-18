import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zipzap_pos_self_orders/core/services/auth_service.dart';
import 'package:zipzap_pos_self_orders/models/cart_item_model.dart';
import 'package:zipzap_pos_self_orders/models/cart_data_model.dart';
import 'package:zipzap_pos_self_orders/models/modifier_group_model.dart';
import 'package:zipzap_pos_self_orders/models/customer_model.dart';
import 'package:zipzap_pos_self_orders/models/order_model.dart';
import 'package:zipzap_pos_self_orders/models/printer_model.dart';
import 'package:zipzap_pos_self_orders/models/staff_member.dart';
import 'package:zipzap_pos_self_orders/modals/cart_modal.dart';
import 'package:zipzap_pos_self_orders/modals/cart_note_modal.dart';
import 'package:zipzap_pos_self_orders/modals/contact_modal.dart';
import 'package:zipzap_pos_self_orders/modals/custom_item_modal.dart';
import 'package:zipzap_pos_self_orders/modals/void_modal.dart';
import 'package:zipzap_pos_self_orders/providers/data_provider.dart';
import 'package:zipzap_pos_self_orders/widgets/app_toast.dart';
import 'package:zipzap_pos_self_orders/services/orders_service.dart';
import 'package:zipzap_pos_self_orders/services/printer_service.dart';

// Re-export cart data models for backward compatibility
export 'package:zipzap_pos_self_orders/models/cart_data_model.dart';

class CartDrawer extends StatefulWidget {
  final List<CartItem> cartItems;
  final Function(CartItem, int) onItemUpdate;
  final Function(CartItem) onItemRemove;
  final Function(CartItem)? onItemTap;
  final CartData? cartData;
  final String? orderId;
  final String? orderNumber;
  final String? customerName;
  final Customer? customer;
  final VoidCallback? onCustomerSelect;
  final VoidCallback? onNoteTap;
  final Function(String?)? onNoteUpdate;
  final VoidCallback? onDiscountTap;
  final Function(CartDiscount?)? onDiscountUpdate;
  final VoidCallback? onCouponTap;
  final VoidCallback? onContactTap;
  final VoidCallback? onAddItemTap;
  final VoidCallback? onPickupTimeTap;
  final Function(DateTime?)? onPickupTimeChanged;
  final DateTime? initialPickupTime;
  final VoidCallback? onPrintKitchen;
  final VoidCallback? onPrintCustomer;
  final VoidCallback? onPrintQuote;
  final VoidCallback? onSendToKitchen;
  final VoidCallback? onCheckout;
  final VoidCallback? onClearCart;
  final Function(Order)? onVoidOrder;
  final VoidCallback? onStaffSelect;
  final StaffMember? selectedStaff;
  final bool isPending;
  final bool isPrintingKitchen;
  final bool isPrintingCustomer;
  final bool isPrintingQuote;
  final bool isCreatingOrder;
  final bool isEditMode;
  final String? orderType;

  const CartDrawer({
    super.key,
    required this.cartItems,
    required this.onItemUpdate,
    required this.onItemRemove,
    this.onItemTap,
    this.cartData,
    this.orderId,
    this.orderNumber,
    this.customerName,
    this.customer,
    this.onCustomerSelect,
    this.onNoteTap,
    this.onNoteUpdate,
    this.onDiscountTap,
    this.onDiscountUpdate,
    this.onCouponTap,
    this.onContactTap,
    this.onAddItemTap,
    this.onPickupTimeTap,
    this.onPickupTimeChanged,
    this.initialPickupTime,
    this.onPrintKitchen,
    this.onPrintCustomer,
    this.onPrintQuote,
    this.onSendToKitchen,
    this.onCheckout,
    this.onClearCart,
    this.onVoidOrder,
    this.onStaffSelect,
    this.selectedStaff,
    this.isPending = false,
    this.isPrintingKitchen = false,
    this.isPrintingCustomer = false,
    this.isPrintingQuote = false,
    this.isCreatingOrder = false,
    this.isEditMode = false,
    this.orderType,
  });

  @override
  State<CartDrawer> createState() => _CartDrawerState();
}

class _CartDrawerState extends State<CartDrawer> {
  List<Modifier> _modifiers = [];
  DateTime? _selectedPickupTime;
  bool _showKitchenPrintButton = true;
  bool _showCustomerReceiptButton = true;
  final OrdersService _ordersService = OrdersService();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _selectedPickupTime = widget.initialPickupTime;
    _loadModifiers();
    _loadPrintButtonSettings();
  }

  @override
  void didUpdateWidget(CartDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update pickup time if it changes from parent
    if (oldWidget.initialPickupTime != widget.initialPickupTime) {
      setState(() {
        _selectedPickupTime = widget.initialPickupTime;
      });
    }
  }

  bool get _allItemsInKitchen {
    if (widget.cartItems.isEmpty) return false;
    return widget.cartItems.every(
      (item) => item.itemStatus == 'Voided' || item.inKitchen,
    );
  }

  bool get _hasNewItems {
    if (widget.cartItems.isEmpty) return false;
    return widget.cartItems.any(
      (item) => item.itemStatus != 'Voided' && !item.inKitchen,
    );
  }

  bool get _hasItemsInKitchen {
    if (widget.cartItems.isEmpty) return false;
    return widget.cartItems.any(
      (item) => item.itemStatus != 'Voided' && item.inKitchen,
    );
  }

  bool get _hasAnyItems {
    if (widget.cartItems.isEmpty) return false;
    return widget.cartItems.any((item) => item.itemStatus != 'Voided');
  }

  Future<void> _loadModifiers() async {
    try {
      final dataProvider = DataProvider();
      setState(() {
        // Get modifiers from DataProvider
        _modifiers = dataProvider.modifiersList
            .where((m) => m.isActive && m.posEnabled)
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading modifiers: $e');
    }
  }

  Future<void> _loadPrintButtonSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = _authService.getProfile()?.username;
      final kitchenKey = username != null && username.isNotEmpty
          ? 'print_kitchen_btn_$username'
          : 'print_kitchen_btn';
      final receiptKey = username != null && username.isNotEmpty
          ? 'print_customer_receipt_btn_$username'
          : 'print_customer_receipt_btn';

      if (!mounted) return;
      setState(() {
        _showKitchenPrintButton = prefs.getBool(kitchenKey) ?? true;
        _showCustomerReceiptButton = prefs.getBool(receiptKey) ?? true;
      });
    } catch (e) {
      debugPrint('Error loading print button settings: $e');
    }
  }

  String _formatPickupTime(DateTime time) {
    // Format as "8:20 AM"
    final hour = time.hour == 0
        ? 12
        : time.hour > 12
        ? time.hour - 12
        : time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _showTimePicker() async {
    final now = DateTime.now();
    final initialTime = _selectedPickupTime ?? now;

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => Container(
        height: 280,
        padding: const EdgeInsets.only(top: 6.0),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              // Header with Done button
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: CupertinoColors.separator,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const Text(
                      'Select Pickup Time',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        Navigator.of(context).pop();
                        // Notify parent of the change
                        widget.onPickupTimeChanged?.call(_selectedPickupTime);
                      },
                      child: const Text(
                        'Done',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              // Time picker with colon separator
              Expanded(
                child: Stack(
                  children: [
                    CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.time,
                      initialDateTime: initialTime,
                      use24hFormat: false,
                      onDateTimeChanged: (DateTime newTime) {
                        setState(() {
                          _selectedPickupTime = newTime;
                        });
                      },
                    ),
                    // Overlay colon separator between hour and minute
                    // Positioned at center with slight left offset to sit between hour and minute columns
                    Center(
                      child: Transform.translate(
                        offset: const Offset(-30, -2),
                        child: const Text(
                          ':',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w300,
                            color: CupertinoColors.label,
                          ),
                        ),
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

  Map<String, List<Modifier>> _populateModifiers(
    Map<String, List<String>> itemModifiers,
  ) {
    final Map<String, List<Modifier>> populated = {};
    if (itemModifiers.isEmpty) return populated;

    itemModifiers.forEach((groupName, modifierIds) {
      if (!populated.containsKey(groupName)) {
        populated[groupName] = [];
      }
      for (final modifierId in modifierIds) {
        final modifier = _modifiers.firstWhere(
          (m) => m.id == modifierId,
          orElse: () => Modifier(
            id: modifierId,
            name: 'Unknown',
            priceAdjustment: 0,
            isActive: true,
          ),
        );
        populated[groupName]!.add(modifier);
      }
    });
    return populated;
  }

  double _calculateItemBaseTotal(CartItem item) {
    double basePrice = item.product.posEffectivePrice;
    double modifierPrice = 0.0;

    // Calculate modifier price adjustments
    final populatedModifiers = _populateModifiers(item.modifiers);
    for (final entry in populatedModifiers.entries) {
      for (final modifier in entry.value) {
        modifierPrice += modifier.priceAdjustment;
      }
    }

    // Calculate base total with modifiers
    return (basePrice + modifierPrice) * item.quantity;
  }

  double _calculateItemTotal(CartItem item) {
    double baseTotal = _calculateItemBaseTotal(item);

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

  double get _subtotal {
    return widget.cartItems
        .where((item) => item.itemStatus != 'Voided')
        .fold(0.0, (sum, item) => sum + _calculateItemTotal(item));
  }

  double get _discountAmount {
    if (widget.cartData?.discount == null) return 0.0;
    final discount = widget.cartData!.discount!;
    if (discount.type == '%') {
      return _subtotal * (discount.value / 100);
    }
    return discount.value;
  }

  double get _couponAmount {
    if (widget.cartData?.coupon == null ||
        widget.cartData!.coupon!.code.isEmpty) {
      return 0.0;
    }
    final coupon = widget.cartData!.coupon!;
    if (coupon.type == '%') {
      return _subtotal * (coupon.discount / 100);
    }
    return coupon.discount;
  }

  double get _feeAmount {
    if (widget.cartData?.fees.isEmpty ?? true) return 0.0;
    return widget.cartData!.fees.fold(0.0, (sum, fee) {
      if (fee.type == '%') {
        return sum + (_subtotal * fee.value / 100);
      }
      return sum + fee.value;
    });
  }

  double get _discountedTotal => _subtotal - _discountAmount - _couponAmount;

  double get _tax {
    // Calculate tax only for items with taxEnable = true
    // Items with taxEnable = false are excluded from tax calculation
    final taxableItems = widget.cartItems
        .where((item) => item.itemStatus != 'Voided' && item.product.taxEnable)
        .toList();

    return taxableItems.fold(0.0, (sum, item) {
      final itemTotal = _calculateItemTotal(item);
      // Apply cart-level discounts proportionally
      // Avoid division by zero when subtotal is 0
      final itemRatio = _subtotal > 0 ? itemTotal / _subtotal : 0.0;
      final itemDiscount = _discountAmount * itemRatio;
      final itemCoupon = _couponAmount * itemRatio;
      final finalItemTotal = itemTotal - itemDiscount - itemCoupon;

      final taxRate = (item.product.taxRule?.amount ?? 0) / 100;
      return sum + (finalItemTotal * taxRate);
    });
  }

  double get _total => _discountedTotal + _feeAmount + _tax;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 1024;

    // Responsive drawer width: larger for medium screens
    final drawerWidth = isSmallScreen ? screenWidth * 0.9 : 450.0;

    return Drawer(
      width: drawerWidth,
      child: SafeArea(
        child: Column(
          children: [
            // Header with actions
            _buildHeader(context),
            // Cart Items
            Expanded(
              child:
                  widget.cartItems
                      .where((item) => item.itemStatus != 'Voided')
                      .isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_cart_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.cartItems.isEmpty
                                ? 'Cart is empty'
                                : 'All items voided',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(4),
                        itemCount: widget.cartItems
                            .where((item) => item.itemStatus != 'Voided')
                            .length,
                        itemBuilder: (context, index) {
                          final nonVoidedItems = widget.cartItems
                              .where((item) => item.itemStatus != 'Voided')
                              .toList();
                          final item = nonVoidedItems[index];
                          return _CartItemCard(
                            item: item,
                            index: index,
                            onUpdate: (newQuantity) =>
                                widget.onItemUpdate(item, newQuantity),
                            onRemove: () => widget.onItemRemove(item),
                            onTap: widget.onItemTap != null
                                ? () => widget.onItemTap!(item)
                                : null,
                            onItemUpdate: widget.onItemUpdate,
                            populateModifiers: _populateModifiers,
                            calculateItemTotal: _calculateItemTotal,
                            calculateItemBaseTotal: _calculateItemBaseTotal,
                          );
                        },
                      ),
                    ),
            ),
            // Footer with actions and totals
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          // Print Kitchen Button
          if (_showKitchenPrintButton)
            IconButton(
              icon: widget.isPrintingKitchen
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(
                      Icons.print,
                      size: 20,
                      color: _hasAnyItems
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                    ),
              onPressed: (!_hasAnyItems || widget.isPrintingKitchen)
                  ? null
                  : widget.onPrintKitchen,
              tooltip: 'Print Kitchen',
            ),
          // Order Info and Customer
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Takeout (${widget.orderNumber ?? 'new'})',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 8),
                if (widget.customerName == null || widget.customerName!.isEmpty)
                  TextButton(
                    onPressed: widget.onCustomerSelect,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Add Customer',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  )
                else
                  TextButton(
                    onPressed: widget.onCustomerSelect,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      widget.customerName!,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          // Menu Button
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
            color: Theme.of(context).colorScheme.surface,
            offset: const Offset(-10, 40),
            onSelected: (value) {
              switch (value) {
                case 'customer':
                  widget.onCustomerSelect?.call();
                  break;
                case 'print_quote':
                  widget.onPrintQuote?.call();
                  break;
                case 'select_server':
                  widget.onStaffSelect?.call();
                  break;
                case 'void':
                  _showVoidModal(context);
                  break;
                case 'clear':
                  widget.onClearCart?.call();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'customer',
                height: 24,
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 16),
                    const SizedBox(width: 8),
                    const Text('Customer'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'print_quote',
                height: 24,
                child: Row(
                  children: [
                    const Icon(Icons.print, size: 16),
                    const SizedBox(width: 8),
                    const Text('Print Quote'),
                  ],
                ),
              ),
              if (widget.onStaffSelect != null) ...[
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'select_server',
                  height: 24,
                  child: Row(
                    children: [
                      const Icon(Icons.badge_outlined, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Select Server'),
                            if (widget.selectedStaff != null)
                              Text(
                                widget.selectedStaff!.fullName,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const PopupMenuDivider(),
              if (widget.orderId != null)
                PopupMenuItem(
                  value: 'void',
                  height: 24,
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete,
                        size: 16,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Void Order',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                )
              else
                PopupMenuItem(
                  value: 'clear',
                  height: 24,
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete,
                        size: 16,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Clear',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Add Actions Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Add:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                Wrap(
                  spacing: 4,
                  children: [
                    _buildActionButton(
                      context,
                      'Note',
                      widget.onNoteUpdate != null
                          ? () => _showNoteModal(context)
                          : widget.onNoteTap,
                      isActive: widget.cartData?.note?.isNotEmpty ?? false,
                    ),
                    _buildActionButton(
                      context,
                      'Discount',
                      widget.onDiscountTap,
                      isActive:
                          widget.cartData?.discount != null &&
                          widget.cartData!.discount!.value != 0,
                    ),
                    _buildActionButton(
                      context,
                      'Coupon',
                      widget.onCouponTap,
                      isActive:
                          widget.cartData?.coupon?.code.isNotEmpty ?? false,
                    ),
                    if (widget.isEditMode)
                      _buildActionButton(
                        context,
                        'Contact',
                        () => _showContactModal(context),
                      ),
                    _buildActionButton(
                      context,
                      'Add Item',
                      widget.onAddItemTap,
                      isActive: widget.cartData?.fees.isNotEmpty ?? false,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Summary Rows
          _buildSummaryRow(context, 'Sub Total:', _subtotal),
          if (widget.cartData?.fees.isNotEmpty ?? false)
            _buildSummaryRow(context, 'Fee:', _feeAmount, isPositive: true),
          if (widget.cartData?.discount != null &&
              widget.cartData!.discount!.value != 0)
            _buildSummaryRow(
              context,
              'Discount${widget.cartData?.discount?.type == '%' ? ' (${widget.cartData!.discount!.value % 1 == 0 ? widget.cartData!.discount!.value.toInt() : widget.cartData!.discount!.value}%)' : ''}:',
              _discountAmount,
              isDiscount: true,
              onRemove: widget.onDiscountUpdate != null
                  ? () {
                      widget.onDiscountUpdate!(null);
                    }
                  : null,
            ),
          if (widget.cartData?.coupon?.code.isNotEmpty ?? false)
            _buildSummaryRow(
              context,
              'Coupon:',
              _couponAmount,
              isDiscount: true,
            ),
          if (_tax > 0)
            _buildSummaryRow(context, 'Tax:', _tax, isPositive: true),
          // Total Row
          Container(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  '\$${_total.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          // Action Buttons Row
          SizedBox(
            height: 42,
            child: Builder(
              builder: (context) {
                final hasItems = widget.cartItems
                    .where((item) => item.itemStatus != 'Voided')
                    .isNotEmpty;

                return Row(
                  children: [
                    SizedBox(
                      width: 50,
                      child: Tooltip(
                        message: _selectedPickupTime != null
                            ? 'Pickup: ${_formatPickupTime(_selectedPickupTime!)}'
                            : 'Set Pickup Time',
                        child: OutlinedButton.icon(
                          onPressed: _showTimePicker,
                          icon: Icon(
                            _selectedPickupTime != null
                                ? Icons.check_circle
                                : Icons.access_time_outlined,
                            size: 20,
                            color: _selectedPickupTime != null
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          label: const Text(''),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: _selectedPickupTime != null
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outline,
                            ),
                            backgroundColor: _selectedPickupTime != null
                                ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.1)
                                : null,
                            shape: const RoundedRectangleBorder(),
                            fixedSize: const Size.fromHeight(42),
                            padding: const EdgeInsets.only(left: 8),
                          ),
                        ),
                      ),
                    ),
                    // Print Customer Receipt Button
                    if (_showCustomerReceiptButton)
                      SizedBox(
                        width: 50,
                        child: OutlinedButton.icon(
                          onPressed:
                              (!hasItems ||
                                  !_hasItemsInKitchen ||
                                  widget.isPrintingCustomer)
                              ? null
                              : widget.onPrintCustomer,
                          icon: widget.isPrintingCustomer
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  Icons.print,
                                  size: 20,
                                  color: _hasItemsInKitchen
                                      ? null
                                      : Theme.of(context).colorScheme.primary
                                            .withValues(alpha: 0.5),
                                ),
                          label: const Text(''),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            shape: const RoundedRectangleBorder(),
                            fixedSize: const Size.fromHeight(42),
                            padding: EdgeInsets.only(left: 8),
                          ),
                        ),
                      ),
                    Expanded(
                      flex: 3,
                      child: FilledButton.icon(
                        onPressed:
                            !hasItems ||
                                widget.isPending ||
                                widget.isCreatingOrder ||
                                _total <= 0
                            ? null
                            : (widget.orderType == 'prepay' ||
                                      (!_hasNewItems && _allItemsInKitchen)
                                  ? widget.onCheckout
                                  : widget.onSendToKitchen),
                        icon: widget.isCreatingOrder
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.restaurant, size: 20),
                        label: Text(
                          widget.isCreatingOrder
                              ? 'Creating Order...'
                              : widget.orderType == 'prepay'
                              ? 'Confirm Order'
                              : (!_hasNewItems && _allItemsInKitchen)
                              ? 'Checkout'
                              : 'Send to Kitchen',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          shape: const RoundedRectangleBorder(),
                          fixedSize: const Size.fromHeight(42),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    VoidCallback? onTap, {
    bool isActive = false,
  }) {
    return CupertinoButton(
      onPressed: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      minimumSize: const Size(40, 20),
      color: isActive
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
          : null,
      borderRadius: BorderRadius.circular(4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: isActive
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.secondary,
        ),
      ),
    );
  }

  void _showNoteModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => CartNoteModal(
        note: widget.cartData?.note,
        onConfirm: (note) {
          if (widget.onNoteUpdate != null) {
            widget.onNoteUpdate!(note);
          }
        },
        onCancel: () {
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _showVoidModal(BuildContext context) async {
    // Check if we have an order ID
    if (widget.orderId == null) {
      AppToast.warning(
        context: context,
        title: 'Cannot Void',
        description: 'No order to void',
      );
      return;
    }

    try {
      // Fetch the full order details with forceRefresh to get latest void status
      final order = await _ordersService.getOrderById(
        widget.orderId!,
        forceRefresh: true,
      );

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => VoidModal(
          order: order,
          onCancel: () {
            Navigator.of(context).pop();
          },
          onVoid: ({required items, required reason}) async {
            // Prepare void data - use item's own _id (works for both regular and custom items)
            final itemsToVoid = items
                .map((voidItem) => voidItem.orderItem.id)
                .where((id) => id.isNotEmpty)
                .toList();

            debugPrint('🔴 Voiding items with IDs: $itemsToVoid');
            debugPrint('🔴 Items details:');
            for (final item in items) {
              debugPrint(
                '  - ID: ${item.orderItem.id}, Name: ${item.orderItem.displayName}, isCustom: ${item.orderItem.item == null}',
              );
            }

            // Call the API - returns updated order
            final updatedOrder = await _ordersService.voidOrder(
              orderId: widget.orderId!,
              itemsToVoid: itemsToVoid,
              voidReason: reason,
            );

            // Update DataProvider in-memory list immediately
            DataProvider().updateTakeoutOrderInMemory(updatedOrder);

            // Print void receipt for items that were in kitchen
            await _printVoidReceipt(items, updatedOrder);

            // Pass the updated order directly - no need to refetch!
            widget.onVoidOrder?.call(updatedOrder);
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context: context,
          title: 'Error',
          description:
              'Failed to load order: ${e.toString().replaceAll('Exception: ', '')}',
        );
      }
    }
  }

  List<String> _getLabelsForVoidItem(VoidItem voidItem) {
    final productId = voidItem.orderItem.item?.id;
    if (productId == null || productId.isEmpty) return [];
    final products = DataProvider().productsList;
    final matching = products.where((p) => p.id == productId);
    if (matching.isEmpty) return [];
    return matching.first.labels;
  }

  List<VoidItem> _filterVoidItemsForPrinter(
    List<VoidItem> items,
    Printer printer,
  ) {
    if (printer.selectedLabels.isEmpty) return items;
    return items.where((voidItem) {
      final labels = _getLabelsForVoidItem(voidItem);
      if (labels.isEmpty) return true;
      return labels.any((labelId) => printer.selectedLabels.contains(labelId));
    }).toList();
  }

  /// Print void receipt for all voided items
  Future<void> _printVoidReceipt(
    List<VoidItem> voidedItems,
    Order updatedOrder,
  ) async {
    try {
      final dataProvider = DataProvider();
      final store = dataProvider.store;
      if (store?.isVoidedPrint != true) {
        debugPrint('🔴 Void print disabled for store');
        return;
      }

      if (voidedItems.isEmpty) {
        debugPrint('🔴 No voided items, skipping void print');
        return;
      }

      // Refresh products to ensure labels are up-to-date
      await dataProvider.loadProducts(forceRefresh: true);

      final printers = await PrinterService.getSavedPrinters();
      final kitchenPrinters = printers
          .where((p) => p.group == PrinterGroup.kitchen)
          .where((p) => p.status != PrinterStatus.error)
          .toList();

      if (kitchenPrinters.isEmpty) {
        debugPrint('🔴 No kitchen printers available for void print');
        return;
      }

      for (final printer in kitchenPrinters) {
        final filteredItems = _filterVoidItemsForPrinter(voidedItems, printer);
        if (filteredItems.isEmpty) continue;

        final orderData = _formatVoidReceiptData(
          filteredItems,
          updatedOrder,
          store!,
        );
        try {
          final interfaceType = _printerTypeToString(printer.type);
          await PrinterService.printVoidReceipt(
            interfaceType: interfaceType,
            identifier: printer.identifier,
            orderData: orderData,
          );
          debugPrint('🔴 Void receipt printed to ${printer.name}');
        } catch (e) {
          debugPrint('🔴 Error printing void receipt to ${printer.name}: $e');
        }
      }
    } catch (e) {
      debugPrint('🔴 Error in void print: $e');
    }
  }

  /// Format data for void receipt printing
  Map<String, dynamic> _formatVoidReceiptData(
    List<VoidItem> voidedItems,
    Order order,
    dynamic store,
  ) {
    final dateFormat = DateFormat('MMM d, yyyy h:mm a');
    final now = DateTime.now();

    return {
      'storeName': store.name,
      'orderNumber': order.orderNumber,
      'orderType': widget.orderType?.toUpperCase() ?? 'PICKUP',
      'placedAt': order.createdAt != null
          ? dateFormat.format(order.createdAt!)
          : '',
      'voidedAt': dateFormat.format(now),
      'items': voidedItems.map((voidItem) {
        final orderItem = voidItem.orderItem;
        final modifierList = orderItem.modifiers.map((mod) {
          String name = mod.name;
          if (name.isEmpty && mod.id.isNotEmpty) {
            final resolved = _modifiers.where((m) => m.id == mod.id);
            if (resolved.isNotEmpty) name = resolved.first.name;
          }
          return {'name': name.isEmpty ? 'Unknown' : name};
        }).toList();

        return {
          'name': orderItem.displayName,
          'quantity': orderItem.quantity,
          'itemNote': orderItem.itemNote ?? '',
          'modifiers': modifierList,
        };
      }).toList(),
    };
  }

  /// Convert printer type enum to string for method channel
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

  void _showContactModal(BuildContext context) {
    // Check if customer is available
    if (widget.customer == null) {
      AppToast.warning(
        context: context,
        title: 'No Customer',
        description: 'Please add a customer before sending a message',
      );
      return;
    }

    // Get store name
    final dataProvider = DataProvider();
    final storeName = dataProvider.store?.name ?? '';

    showDialog(
      context: context,
      builder: (context) => ContactModal(
        customer: widget.customer,
        orderNumber: widget.orderNumber,
        storeName: storeName,
        currentPickupTime: _selectedPickupTime,
        onCancel: () {
          Navigator.of(context).pop();
        },
        // The ContactModal handles the API call directly, onSend is optional for additional handling
      ),
    );
  }

  Widget _buildSummaryRow(
    BuildContext context,
    String label,
    double amount, {
    bool isDiscount = false,
    bool isPositive = false,
    VoidCallback? onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 3),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onRemove != null) ...[
                InkWell(
                  onTap: onRemove,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
              ],
              Text(
                label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Text(
            '${isDiscount
                ? '-'
                : isPositive
                ? '+'
                : ''}\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDiscount
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartItem item;
  final int index;
  final Function(int) onUpdate;
  final VoidCallback onRemove;
  final VoidCallback? onTap;
  final Function(CartItem, int) onItemUpdate;
  final Map<String, List<Modifier>> Function(Map<String, List<String>>)
  populateModifiers;
  final double Function(CartItem) calculateItemTotal;
  final double Function(CartItem) calculateItemBaseTotal;

  const _CartItemCard({
    required this.item,
    required this.index,
    required this.onUpdate,
    required this.onRemove,
    this.onTap,
    required this.onItemUpdate,
    required this.populateModifiers,
    required this.calculateItemTotal,
    required this.calculateItemBaseTotal,
  });

  Widget _buildItemPriceDisplay(BuildContext context, CartItem item) {
    final baseTotal = calculateItemBaseTotal(item);
    final discountedTotal = calculateItemTotal(item);
    final hasDiscount =
        item.itemDiscount != null && item.itemDiscount!.value > 0;

    if (hasDiscount && baseTotal != discountedTotal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '(\$${baseTotal.toStringAsFixed(2)})',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '(\$${discountedTotal.toStringAsFixed(2)})',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      );
    }

    return Text(
      '(\$${discountedTotal.toStringAsFixed(2)})',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isInKitchen = item.inKitchen;

    // Check if this is a custom item (type == 'custom' or empty product id)
    final isCustomItem =
        item.product.type == 'custom' || item.product.id.isEmpty;

    return InkWell(
      onTap: isInKitchen
          ? null
          : onTap ??
                () {
                  if (isCustomItem) {
                    // Open custom item modal for custom items
                    showDialog(
                      context: context,
                      builder: (dialogContext) => CustomItemModal(
                        cartItem: item,
                        onUpdate: (updatedItem) {
                          // Modal handles its own closing
                          onItemUpdate(updatedItem, updatedItem.quantity);
                        },
                      ),
                    );
                  } else {
                    // Open regular cart modal for products
                    showDialog(
                      context: context,
                      builder: (dialogContext) => CartModal(
                        cartItem: item,
                        onConfirm: (updatedItem) {
                          Navigator.of(dialogContext).pop();
                          onItemUpdate(updatedItem, updatedItem.quantity);
                        },
                        onCancel: () {
                          Navigator.of(dialogContext).pop();
                        },
                      ),
                    );
                  }
                },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        decoration: BoxDecoration(
          color: index % 2 == 0
              ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.surface,
          border: Border(
            left: BorderSide(
              color: isInKitchen
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 8.0,
          children: [
            // Check icon
            Icon(
              Icons.check,
              size: 16,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.6),
            ),
            // Item Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Quantity x Name and Price
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          spacing: 4.0,
                          children: [
                            Flexible(
                              child: Text(
                                '${item.quantity} x ${item.product.name.toLowerCase()}',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: isInKitchen
                                          ? Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.7)
                                          : null,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _buildItemPriceDisplay(context, item),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Modifiers
                  if (item.modifiers.isNotEmpty)
                    ...populateModifiers(item.modifiers).entries.map((entry) {
                      final modifierNames = entry.value
                          .map(
                            (modifier) =>
                                '${modifier.name}${modifier.priceAdjustment > 0 ? ' (+${modifier.priceAdjustment.toStringAsFixed(2)})' : ''}',
                          )
                          .join(', ');
                      return Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${entry.key}: ',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text: modifierNames,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  // Item Note
                  if (item.itemNote.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Note: ',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text: item.itemNote,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Timestamp
            Text(
              DateFormat('h:mm a').format(item.timestamp),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            // Remove/Void Button
            IconButton(
              icon: Icon(
                Icons.close,
                size: 20,
                color: Theme.of(
                  context,
                ).colorScheme.error.withValues(alpha: 0.6),
              ),
              onPressed: isInKitchen ? null : onRemove,
              padding: EdgeInsets.all(8),
              tooltip: isInKitchen ? 'Void Item' : 'Remove Item',
            ),
          ],
        ),
      ),
    );
  }
}
