import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zipzap_pos_self_orders/models/cart_item_model.dart';
import 'package:zipzap_pos_self_orders/pages/orders/new/widgets/cart_drawer.dart';
import 'package:zipzap_pos_self_orders/models/modifier_group_model.dart';
import 'package:zipzap_pos_self_orders/models/customer_model.dart';
import 'package:zipzap_pos_self_orders/widgets/header/widget.dart';
import 'package:zipzap_pos_self_orders/widgets/app_drawer.dart';
import 'package:zipzap_pos_self_orders/widgets/app_toast.dart';
import 'package:zipzap_pos_self_orders/modals/split_bill_modal.dart';
import 'package:zipzap_pos_self_orders/modals/payment_modal.dart';
import 'package:zipzap_pos_self_orders/core/services/auth_service.dart';
import 'package:zipzap_pos_self_orders/services/orders_service.dart';
import 'package:zipzap_pos_self_orders/services/printer_service.dart';
import 'package:zipzap_pos_self_orders/services/audio_service.dart';
import 'package:zipzap_pos_self_orders/models/printer_model.dart';
import 'package:zipzap_pos_self_orders/core/constants/api_constants.dart';
import 'package:zipzap_pos_self_orders/providers/data_provider.dart';

class CheckoutPage extends StatefulWidget {
  final List<CartItem> cartItems;
  final CartData? cartData;
  final Customer? customer;
  final String? orderType;
  final String? orderId;
  final String? orderNumber;
  final bool isEditMode;
  final DateTime? pickupTime;

  const CheckoutPage({
    super.key,
    required this.cartItems,
    this.cartData,
    this.customer,
    this.orderType,
    this.orderId,
    this.orderNumber,
    this.isEditMode = false,
    this.pickupTime,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  // Half-cent tolerance for floating-point comparisons on monetary values.
  // Prevents the "Finalize" button from staying stuck due to IEEE 754 rounding.
  static const double _paymentTolerance = 0.005;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final AuthService _authService = AuthService();
  final OrdersService _ordersService = OrdersService();
  final DataProvider _dataProvider = DataProvider();
  final AudioService _audioService = AudioService();
  List<Modifier> _modifiers = [];
  int _splitQty = 1;
  int _currentSplitIndex = 0;
  List<double> _splitPayments = [0.0];
  List<Map<String, dynamic>> _splitTips = [
    {'amount': 0, 'type': '%'},
  ];
  List<List<Map<String, dynamic>>> _splitPaymentMethods = [[]];
  bool _sendToKitchen = false;
  final bool _isPending = false;
  bool _isCreatingOrder = false;
  bool _isDrawerOpen = false;
  bool _isPrintingReceipt = false;
  bool _isPrintingAllReceipts = false;
  bool _isOpeningDrawer = false;

  @override
  void initState() {
    super.initState();
    _loadModifiers();
    _initializeSplitData();
  }

  void _loadModifiers() {
    try {
      // Get modifiers from DataProvider (synchronously - data is already loaded)
      _modifiers = _dataProvider.modifiersList
          .where((m) => m.isActive && m.posEnabled)
          .toList();
      debugPrint('Loaded ${_modifiers.length} modifiers for checkout');
    } catch (e) {
      debugPrint('Error loading modifiers: $e');
    }
  }

  double _calculateItemModifierPrice(CartItem item) {
    if (item.modifiers.isEmpty) return 0.0;

    double modifierPrice = 0.0;
    for (final modifierIds in item.modifiers.values) {
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
        modifierPrice += modifier.priceAdjustment;
      }
    }
    return modifierPrice;
  }

  void _initializeSplitData() {
    _splitPayments = List.generate(_splitQty, (index) => 0.0);
    _splitTips = List.generate(
      _splitQty,
      (index) => {'amount': 0, 'type': '%'},
    );
    _splitPaymentMethods = List.generate(_splitQty, (index) => []);
  }

  /// Distribute total tax across splits proportionally by their share of the discounted total.
  List<double> _getSplitTaxAmounts() {
    final totalTax = _calculateTax();
    final splitAmounts = _calculateSplitAmounts();
    final discountedTotal = _calculateDiscountedTotal();

    if (_splitQty <= 1 || discountedTotal <= 0) {
      return [totalTax];
    }

    final taxes = <double>[];
    double assigned = 0.0;
    for (int i = 0; i < splitAmounts.length - 1; i++) {
      final tax =
          (totalTax * splitAmounts[i] / discountedTotal * 100).round() / 100;
      taxes.add(tax);
      assigned += tax;
    }
    taxes.add((totalTax * 100).round() / 100 - assigned);
    return taxes;
  }

  double _calculateSubtotal() {
    final subtotal = widget.cartItems
        .where((item) => item.itemStatus != 'Voided')
        .fold(0.0, (sum, item) {
          final modifierPrice = _calculateItemModifierPrice(item);
          final baseTotal =
              (item.product.posEffectivePrice + modifierPrice) * item.quantity;
          // Apply item discount
          if (item.itemDiscount != null && item.itemDiscount!.value > 0) {
            if (item.itemDiscount!.type == '%') {
              return sum + (baseTotal * (1 - item.itemDiscount!.value / 100));
            } else {
              return sum + (baseTotal - item.itemDiscount!.value);
            }
          }
          return sum + baseTotal;
        });
    debugPrint(
      'Checkout Subtotal Calculation: ${widget.cartItems.length} items, subtotal=$subtotal',
    );
    return subtotal;
  }

  double _calculateDiscountAmount() {
    if (widget.cartData?.discount == null) return 0.0;
    final discount = widget.cartData!.discount!;
    final subtotal = _calculateSubtotal();
    return discount.type == '%'
        ? subtotal * (discount.value / 100)
        : discount.value;
  }

  double _calculateCouponAmount() {
    final coupon = widget.cartData?.coupon;
    if (coupon == null || coupon.code.isEmpty) return 0.0;
    final subtotal = _calculateSubtotal();
    return coupon.type == '%'
        ? subtotal * (coupon.discount / 100)
        : coupon.discount;
  }

  double _calculateFeeAmount() {
    final fees = widget.cartData?.fees;
    if (fees == null || fees.isEmpty) return 0.0;
    final subtotal = _calculateSubtotal();
    return fees.fold(0.0, (sum, fee) {
      if (fee.type == '%') {
        return sum + (subtotal * fee.value / 100);
      }
      return sum + fee.value;
    });
  }

  double _calculateDiscountedTotal() {
    final subtotal = _calculateSubtotal();
    final discountAmount = _calculateDiscountAmount();
    final couponAmount = _calculateCouponAmount();
    return subtotal - discountAmount - couponAmount;
  }

  double _calculateTax() {
    final subtotal = _calculateSubtotal();
    final discountAmount = _calculateDiscountAmount();
    final couponAmount = _calculateCouponAmount();

    final tax = widget.cartItems
        .where((item) => item.itemStatus != 'Voided')
        .fold(0.0, (sum, item) {
          if (!item.product.taxEnable || item.product.taxRule == null) {
            return sum;
          }

          final modifierPrice = _calculateItemModifierPrice(item);
          final baseTotal =
              (item.product.posEffectivePrice + modifierPrice) * item.quantity;
          double itemTotal = baseTotal;

          if (item.itemDiscount != null && item.itemDiscount!.value > 0) {
            if (item.itemDiscount!.type == '%') {
              itemTotal = baseTotal * (1 - item.itemDiscount!.value / 100);
            } else {
              itemTotal = baseTotal - item.itemDiscount!.value;
            }
          }

          final itemRatio = subtotal > 0 ? itemTotal / subtotal : 0.0;
          final cartDiscountForItem = discountAmount * itemRatio;
          final cartCouponForItem = couponAmount * itemRatio;
          final finalItemTotal =
              itemTotal - cartDiscountForItem - cartCouponForItem;
          final taxRate = item.product.taxRule!.amount / 100;
          return sum + (finalItemTotal * taxRate);
        });

    debugPrint(
      'Checkout Tax Calculation: subtotal=$subtotal, discount=$discountAmount, '
      'coupon=$couponAmount, tax=$tax',
    );
    return tax;
  }

  List<double> _calculateSplitAmounts() {
    final discountedTotal = _calculateDiscountedTotal();
    if (_splitQty <= 1) {
      return [discountedTotal];
    }
    final amounts = <double>[];
    // Round base amount to 2 decimal places (cents) to avoid floating point issues
    final baseAmount = (discountedTotal / _splitQty * 100).round() / 100;
    double totalAssigned = 0.0;
    // Assign rounded base amount to all splits except the last one
    for (int i = 0; i < _splitQty - 1; i++) {
      amounts.add(baseAmount);
      totalAssigned += baseAmount;
    }
    // Put the remainder in the last split to ensure total equals discountedTotal exactly
    amounts.add((discountedTotal * 100).round() / 100 - totalAssigned);
    return amounts;
  }

  List<double> _calculateSplitTotals() {
    final splitAmounts = _calculateSplitAmounts();
    final splitTaxAmounts = _getSplitTaxAmounts();
    return splitAmounts.asMap().entries.map((entry) {
      final index = entry.key;
      final amount = entry.value;
      final withTax = amount + splitTaxAmounts[index];
      final tip = _splitTips[index];
      final tipValue = tip['type'] == '%'
          ? (withTax * tip['amount']) / 100
          : tip['amount'].toDouble();
      return withTax + tipValue;
    }).toList();
  }

  double _calculateSummaryHeight() {
    final discountAmount = _calculateDiscountAmount();
    final tip = _splitTips[_currentSplitIndex];

    // Base height: container padding (24) + base rows height
    // Base rows: Subtotal, Divider, Total, Outstanding
    double height = 12.0; // Container padding (12 top + 12 bottom)

    // Each summary row has ~24px height (including vertical padding)
    height += 24.0; // Subtotal

    // Conditional rows
    if (discountAmount > 0) {
      height += 24.0; // Discount row
    }

    if (_calculateTax() > 0) {
      height += 24.0; // Tax row
    }

    if (tip['amount'] > 0) {
      height += 24.0; // Tip row
    }

    height += 12.0; // Divider
    height += 24.0; // Total row
    height += 24.0; // Outstanding row

    // Add extra buffer for safety
    height += 20.0;

    return height;
  }

  @override
  Widget build(BuildContext context) {
    final splitAmounts = _calculateSplitAmounts();
    final splitTaxAmounts = _getSplitTaxAmounts();
    final splitTotals = _calculateSplitTotals();
    final subtotal = _calculateSubtotal();
    final discountAmount = _calculateDiscountAmount();
    final couponAmount = _calculateCouponAmount();
    final feeAmount = _calculateFeeAmount();
    final taxAmount = _calculateTax();
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 1024;

    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      onEndDrawerChanged: (isOpened) {
        setState(() {
          _isDrawerOpen = isOpened;
        });
      },
      endDrawer: isSmallScreen
          ? Drawer(
              width: 260,
              child: SafeArea(
                child: _buildSidebar(splitTotals, splitTaxAmounts),
              ),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Builder(
              builder: (context) => HeaderWidget(
                logoUrl: 'https://zipzappos.com',
                onDrawerPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
                onSearchChanged: (query) {
                  // Handle search
                  debugPrint('Search query: $query');
                },
                serverStatus: true,
              ),
            ),
            // Main content
            Expanded(
              child: Row(
                children: [
                  // Main content area
                  Expanded(
                    child: Column(
                      children: [
                        // Tabs for split payments
                        Expanded(
                          child: DefaultTabController(
                            length: _splitQty,
                            initialIndex: _currentSplitIndex,
                            child: Column(
                              children: [
                                // Split payment tabs
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: List.generate(_splitQty, (
                                          index,
                                        ) {
                                          final isPaid =
                                              (splitTotals[index] -
                                                  _splitPayments[index]) <
                                              _paymentTolerance;
                                          final isSelected =
                                              _currentSplitIndex == index;
                                          return GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _currentSplitIndex = index;
                                              });
                                            },
                                            child: Stack(
                                              clipBehavior: Clip.none,
                                              children: [
                                                Container(
                                                  margin: const EdgeInsets.only(
                                                    right: 6,
                                                  ),
                                                  constraints:
                                                      const BoxConstraints(
                                                        minWidth: 140,
                                                        maxWidth: 180,
                                                      ),
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: isPaid
                                                        ? Colors.green.shade100
                                                        : (isSelected
                                                              ? Colors
                                                                    .blue
                                                                    .shade50
                                                              : Colors
                                                                    .grey
                                                                    .shade50),
                                                    border: Border.all(
                                                      color: isSelected
                                                          ? Theme.of(context)
                                                                .colorScheme
                                                                .primary
                                                          : Colors
                                                                .grey
                                                                .shade300,
                                                      width: isSelected ? 2 : 1,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                  child: _buildSplitTabContent(
                                                    index,
                                                    splitAmounts[index],
                                                    splitTaxAmounts[index],
                                                    _splitTips[index],
                                                    splitTotals[index],
                                                    _splitPayments[index],
                                                    isPaid,
                                                  ),
                                                ),
                                                if (isPaid)
                                                  Positioned(
                                                    top: -6,
                                                    right: 6,
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 3,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors
                                                            .green
                                                            .shade600,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.green
                                                                .withValues(
                                                                  alpha: 0.3,
                                                                ),
                                                            blurRadius: 4,
                                                            offset:
                                                                const Offset(
                                                                  0,
                                                                  2,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            Icons.check_circle,
                                                            size: 12,
                                                            color: Colors.white,
                                                          ),
                                                          const SizedBox(
                                                            width: 3,
                                                          ),
                                                          Text(
                                                            'Paid',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color:
                                                                  Colors.white,
                                                              letterSpacing:
                                                                  0.5,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          );
                                        }),
                                      ),
                                    ),
                                  ),
                                ),
                                // Order details
                                Expanded(
                                  child: _buildOrderDetails(
                                    subtotal,
                                    discountAmount,
                                    couponAmount,
                                    feeAmount,
                                    taxAmount,
                                    splitAmounts[_currentSplitIndex],
                                    splitTaxAmounts[_currentSplitIndex],
                                    _splitTips[_currentSplitIndex],
                                    splitTotals[_currentSplitIndex],
                                    splitTotals.fold(
                                      0.0,
                                      (sum, total) => sum + total,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Sidebar with actions (only for large screens)
                  if (!isSmallScreen)
                    _buildSidebar(splitTotals, splitTaxAmounts),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: isSmallScreen && !_isDrawerOpen
          ? Padding(
              padding: EdgeInsets.only(bottom: _calculateSummaryHeight()),
              child: FloatingActionButton.extended(
                onPressed: () {
                  _scaffoldKey.currentState?.openEndDrawer();
                },
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.menu),
                label: const Text(
                  'Actions',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildSidebar(List<double> splitTotals, List<double> splitTaxAmounts) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Column(
        spacing: 6,
        children: [
          // Order number
          Text(
            widget.isEditMode && widget.orderNumber != null
                ? 'Order #${widget.orderNumber}'
                : 'Order #(New)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          OutlinedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => SplitBillModal(
                  currentSplitQty: _splitQty,
                  onConfirm: (newSplitQty) {
                    setState(() {
                      _splitQty = newSplitQty;
                      _currentSplitIndex = 0;
                      _initializeSplitData();
                    });
                  },
                  onCancel: () {
                    Navigator.of(context).pop();
                  },
                ),
              );
            },
            icon: const Icon(Icons.account_balance_wallet, size: 16),
            label: Text(
              'Split Bill ($_splitQty)',
              style: const TextStyle(fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              minimumSize: const Size(double.infinity, 40),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _isPrintingReceipt ? null : _handlePrintReceipt,
            icon: _isPrintingReceipt
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print, size: 16),
            label: Text(
              _isPrintingReceipt ? 'Printing...' : 'Print Receipt',
              style: const TextStyle(fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              minimumSize: const Size(double.infinity, 40),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _isPrintingAllReceipts ? null : _handlePrintAllReceipts,
            icon: _isPrintingAllReceipts
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print_outlined, size: 16),
            label: Text(
              _isPrintingAllReceipts ? 'Printing...' : 'Print All Receipts',
              style: const TextStyle(fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              minimumSize: const Size(double.infinity, 40),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          if (_authService.getProfile()?.canOpenCashDrawer ?? false)
            OutlinedButton.icon(
              onPressed: _isOpeningDrawer
                  ? null
                  : () async {
                      setState(() {
                        _isOpeningDrawer = true;
                      });
                      try {
                        await _openCashDrawer();
                      } finally {
                        if (mounted) {
                          setState(() {
                            _isOpeningDrawer = false;
                          });
                        }
                      }
                    },
              icon: _isOpeningDrawer
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.point_of_sale, size: 16),
              label: Text(
                _isOpeningDrawer ? 'Opening...' : 'Open Cash Drawer',
                style: const TextStyle(fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                minimumSize: const Size(double.infinity, 40),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: () {
              // TODO: Email receipt
            },
            icon: const Icon(Icons.email_outlined, size: 16),
            label: const Text('Email Receipt', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              minimumSize: const Size(double.infinity, 40),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const Spacer(),
          // Back button
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Back to Orders', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
              minimumSize: const Size(double.infinity, 40),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          FilledButton.icon(
            onPressed: _isPending || _isCreatingOrder
                ? null
                : ((splitTotals[_currentSplitIndex] -
                              _splitPayments[_currentSplitIndex]) <
                          _paymentTolerance
                      ? (_currentSplitIndex < _splitQty - 1
                            ? () {
                                setState(() {
                                  _currentSplitIndex++;
                                });
                              }
                            : () => _handleFinalize())
                      : () {
                          final splitAmounts = _calculateSplitAmounts();

                          showDialog(
                            context: context,
                            builder: (context) => PaymentModal(
                              totalAmount:
                                  splitAmounts[_currentSplitIndex] +
                                  splitTaxAmounts[_currentSplitIndex],
                              currentPaid: _splitPayments[_currentSplitIndex],
                              currentTip: _splitTips[_currentSplitIndex],
                              orderType: widget.orderType,
                              isPosTipEnable:
                                  _dataProvider.store?.isPosTipEnable == true,
                              onConfirm: (cashAmount, cardAmount, tip, sendToKitchen) {
                                setState(() {
                                  _splitTips[_currentSplitIndex] = tip;
                                  _splitPayments[_currentSplitIndex] =
                                      cashAmount + cardAmount;
                                  _sendToKitchen = sendToKitchen;

                                  // Calculate total amount for this split including tip
                                  // Round all monetary values to 2 decimal places to avoid floating-point precision issues
                                  final splitAmount = double.parse(
                                    splitAmounts[_currentSplitIndex]
                                        .toStringAsFixed(2),
                                  );
                                  final splitTax = double.parse(
                                    splitTaxAmounts[_currentSplitIndex]
                                        .toStringAsFixed(2),
                                  );

                                  // Calculate and round tip value
                                  final tipValue = tip['type'] == '%'
                                      ? double.parse(
                                          (((splitAmount + splitTax) *
                                                      tip['amount']) /
                                                  100)
                                              .toStringAsFixed(2),
                                        )
                                      : double.parse(
                                          tip['amount']
                                              .toDouble()
                                              .toStringAsFixed(2),
                                        );

                                  // Round total amounts
                                  final totalDue = double.parse(
                                    (splitAmount + splitTax + tipValue)
                                        .toStringAsFixed(2),
                                  );
                                  final roundedCashAmount = double.parse(
                                    cashAmount.toStringAsFixed(2),
                                  );
                                  final roundedCardAmount = double.parse(
                                    cardAmount.toStringAsFixed(2),
                                  );
                                  final totalPaid = double.parse(
                                    (roundedCashAmount + roundedCardAmount)
                                        .toStringAsFixed(2),
                                  );

                                  // Calculate change (only from cash overpayment)
                                  double cashChange = 0.0;
                                  if (totalPaid > totalDue &&
                                      roundedCashAmount > 0) {
                                    // If overpaid and cash was used, change comes from cash
                                    final overpayment = totalPaid - totalDue;
                                    // Change is limited to the cash amount paid
                                    final rawChange =
                                        overpayment > roundedCashAmount
                                        ? roundedCashAmount
                                        : overpayment;
                                    cashChange = double.parse(
                                      rawChange.toStringAsFixed(2),
                                    );
                                  }

                                  // Build payment methods list
                                  final paymentMethods =
                                      <Map<String, dynamic>>[];
                                  if (roundedCashAmount > 0) {
                                    paymentMethods.add({
                                      'method': 'Cash',
                                      'amount': roundedCashAmount,
                                      'cardType': '',
                                      'change': cashChange,
                                      'refund': 0.0,
                                      'status': 'Not Refunded',
                                    });
                                  }
                                  if (roundedCardAmount > 0) {
                                    paymentMethods.add({
                                      'method': 'Card',
                                      'amount': roundedCardAmount,
                                      'cardType':
                                          'Visa', // TODO: Get actual card type from modal
                                      'change': 0.0,
                                      'refund': 0.0,
                                      'status': 'Not Refunded',
                                    });
                                  }
                                  _splitPaymentMethods[_currentSplitIndex] =
                                      paymentMethods;
                                });
                              },
                              onCancel: () {
                                Navigator.of(context).pop();
                              },
                              onPrint: () {
                                // TODO: Handle print receipt
                                Navigator.of(context).pop();
                              },
                            ),
                          );
                        }),
            icon: _isCreatingOrder
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(
                    (splitTotals[_currentSplitIndex] -
                                _splitPayments[_currentSplitIndex]) <
                            _paymentTolerance
                        ? Icons.check_circle
                        : Icons.payment,
                    size: 20,
                  ),
            label: Text(
              _isCreatingOrder
                  ? 'Creating Order...'
                  : (splitTotals[_currentSplitIndex] -
                            _splitPayments[_currentSplitIndex]) <
                        _paymentTolerance
                  ? (_currentSplitIndex < _splitQty - 1 ? 'Next' : 'Finalize')
                  : 'Pay Now',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              minimumSize: const Size(double.infinity, 64),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitTabContent(
    int index,
    double subtotal,
    double tax,
    Map<String, dynamic> tip,
    double total,
    double paid,
    bool isPaid,
  ) {
    final tipValue = tip['type'] == '%'
        ? ((subtotal + tax) * tip['amount']) / 100
        : tip['amount'].toDouble();
    final outstanding = total - paid;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_splitQty > 1)
          Text(
            '${index + 1} of $_splitQty',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        if (_splitQty > 1) const SizedBox(height: 4),
        _buildCompactSummaryRow('Subtotal:', subtotal),
        if (tax > 0) _buildCompactSummaryRow('Tax:', tax, isPositive: true),
        _buildCompactSummaryRow(
          'Tip:',
          tipValue,
          isPositive: true,
          color: Colors.green.shade700,
        ),
        Divider(
          height: 6,
          thickness: 1,
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
        _buildCompactSummaryRow('Total:', total, isBold: true),
        _buildCompactSummaryRow('Paid:', paid),
        _buildCompactSummaryRow(
          'Outstanding:',
          outstanding,
          color: outstanding > 0 ? Colors.red.shade700 : Colors.green.shade700,
          isBold: outstanding > 0,
        ),
      ],
    );
  }

  Widget _buildCompactSummaryRow(
    String label,
    double amount, {
    bool isBold = false,
    bool isPositive = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${isPositive ? '+' : ''}\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetails(
    double subtotal,
    double discountAmount,
    double couponAmount,
    double feeAmount,
    double taxAmount,
    double splitAmount,
    double splitTax,
    Map<String, dynamic> tip,
    double splitTotal,
    double fullTotal,
  ) {
    return Container(
      margin: const EdgeInsets.only(left: 8, right: 8, bottom: 0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          // Items table
          Expanded(
            child: SingleChildScrollView(
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(3),
                  1: FlexColumnWidth(1),
                },
                children: [
                  // Header
                  TableRow(
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    children: [
                      TableCell(
                        verticalAlignment: TableCellVerticalAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Text(
                            'Items',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                          ),
                        ),
                      ),
                      TableCell(
                        verticalAlignment: TableCellVerticalAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Text(
                            'Amount',
                            textAlign: TextAlign.right,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Items (excluding voided)
                  ...widget.cartItems
                      .where((item) => item.itemStatus != 'Voided')
                      .map((item) {
                        final modifierPrice = _calculateItemModifierPrice(item);
                        final itemPriceWithModifiers =
                            item.product.posEffectivePrice + modifierPrice;
                        final itemTotal =
                            itemPriceWithModifiers * item.quantity;
                        final itemDiscountAmount =
                            item.itemDiscount != null &&
                                item.itemDiscount!.value > 0
                            ? (item.itemDiscount!.type == '%'
                                  ? itemTotal * (item.itemDiscount!.value / 100)
                                  : item.itemDiscount!.value)
                            : 0.0;
                        final finalItemPrice = itemTotal - itemDiscountAmount;

                        return TableRow(
                          children: [
                            TableCell(
                              verticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                child: Text(
                                  '${item.product.name.toLowerCase()} x ${item.quantity}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                            TableCell(
                              verticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (itemDiscountAmount > 0)
                                      Text(
                                        '\$${(itemTotal).toStringAsFixed(2)}',
                                        style: TextStyle(
                                          decoration:
                                              TextDecoration.lineThrough,
                                          color: Colors.grey.shade500,
                                          fontSize: 11,
                                        ),
                                      ),
                                    if (itemDiscountAmount > 0)
                                      const SizedBox(width: 4),
                                    Text(
                                      '\$${finalItemPrice.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                ],
              ),
            ),
          ),
          // Summary
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(6),
                bottomRight: Radius.circular(6),
              ),
            ),
            child: Column(
              children: [
                _buildSummaryRow('Subtotal:', subtotal, isBold: true),
                if (feeAmount > 0)
                  _buildSummaryRow(
                    'Fee:',
                    feeAmount,
                    isPositive: true,
                    isBold: true,
                  ),
                if (discountAmount > 0)
                  _buildSummaryRow(
                    'Discount:',
                    discountAmount,
                    isDiscount: true,
                    isBold: true,
                  ),
                if (couponAmount > 0)
                  _buildSummaryRow(
                    'Coupon:',
                    couponAmount,
                    isDiscount: true,
                    isBold: true,
                  ),
                if (taxAmount > 0)
                  _buildSummaryRow(
                    'Tax:',
                    taxAmount,
                    isPositive: true,
                    isBold: true,
                  ),
                if (tip['amount'] > 0)
                  _buildSummaryRow(
                    'Tip:',
                    tip['type'] == '%'
                        ? ((splitAmount + splitTax) * tip['amount']) / 100
                        : tip['amount'].toDouble(),
                    isPositive: true,
                    isBold: true,
                    color: Colors.green.shade700,
                  ),
                const Divider(height: 12),
                _buildSummaryRow(
                  'Total:',
                  splitTotal,
                  isBold: true,
                  fontSize: 15,
                  fullTotal: _splitQty > 1 ? fullTotal : null,
                ),
                const SizedBox(height: 2),
                _buildSummaryRow(
                  _splitQty > 1
                      ? 'Part ${_currentSplitIndex + 1}/$_splitQty Outstanding:'
                      : 'Outstanding:',
                  (splitTotal - _splitPayments[_currentSplitIndex]).abs() <
                          0.001
                      ? 0.0
                      : splitTotal - _splitPayments[_currentSplitIndex],
                  isBold: true,
                  color:
                      (splitTotal - _splitPayments[_currentSplitIndex]) > 0.001
                      ? Colors.red.shade700
                      : Colors.green.shade700,
                  fontSize: 14,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double amount, {
    bool isBold = false,
    bool isPositive = false,
    bool isDiscount = false,
    Color? color,
    double fontSize = 13,
    double? fullTotal,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            fullTotal != null
                ? '\$${amount.toStringAsFixed(2)} / \$${fullTotal.toStringAsFixed(2)}'
                : amount < -0.001
                ? '-\$${amount.abs().toStringAsFixed(2)}'
                : '${isDiscount
                      ? '-'
                      : isPositive
                      ? '+'
                      : ''}\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              color: color ?? (isDiscount ? Colors.blue.shade700 : null),
            ),
          ),
        ],
      ),
    );
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

  Map<String, dynamic> _formatOrderDataForSplit(int splitIndex) {
    final splitAmounts = _calculateSplitAmounts();
    final splitTotals = _calculateSplitTotals();
    final subtotal = splitAmounts[splitIndex];
    final tax = _getSplitTaxAmounts()[splitIndex];
    final tip = _splitTips[splitIndex];
    final tipValue = tip['type'] == '%'
        ? ((subtotal + tax) * tip['amount']) / 100
        : tip['amount'].toDouble();
    final total = subtotal + tax + tipValue;
    // Calculate full order total (sum of all split totals)
    final fullTotal = splitTotals.fold(0.0, (sum, t) => sum + t);

    // Format items with modifiers
    final items = widget.cartItems
        .where((item) => item.itemStatus != 'Voided')
        .map((item) {
          final modifierPrice = _calculateItemModifierPrice(item);
          final basePrice = item.product.posEffectivePrice + modifierPrice;
          final itemTotal = basePrice * item.quantity;

          // Build modifiers list
          final modifierList = <Map<String, dynamic>>[];
          if (item.modifiers.isNotEmpty) {
            for (final modifierId in item.modifiers.values.expand((e) => e)) {
              final modifier = _modifiers.firstWhere(
                (m) => m.id == modifierId,
                orElse: () => Modifier(
                  id: modifierId,
                  name: 'Unknown',
                  priceAdjustment: 0,
                  isActive: true,
                ),
              );
              modifierList.add({
                'name': modifier.name,
                'priceAdjustment': modifier.priceAdjustment,
              });
            }
          }

          return {
            'quantity': item.quantity,
            'name': item.product.name,
            'price': itemTotal,
            'modifiers': modifierList,
            'itemNote': item.itemNote,
          };
        })
        .toList();

    final now = DateTime.now();
    final dateFormat = DateFormat('MMM dd, yyyy, HH:mm');
    final orderDate = dateFormat.format(now);

    // Get store details from DataProvider
    final store = _dataProvider.store;

    return {
      'storeName': store?.name ?? 'Store',
      'storeAddress': store?.address?.fullAddress ?? '',
      'storePhone': store?.phone ?? '',
      'storeEmail': store?.email ?? '',
      'orderNumber': widget.orderNumber ?? 'NEW',
      'orderDate': orderDate,
      'orderType': widget.orderType?.toUpperCase() ?? 'TAKEOUT',
      'placedAt': DateFormat('MMMM dd, h:mm a').format(now),
      'dueAt': DateFormat(
        'MMMM dd, h:mm a',
      ).format(widget.pickupTime ?? now.add(const Duration(minutes: 25))),
      'customerName': widget.customer?.fullName ?? '',
      'customerPhone': widget.customer?.phone ?? '',
      'items': items,
      'subtotal': subtotal,
      'tax': tax,
      'tip': tipValue,
      'discount': widget.cartData?.discount != null
          ? _calculateDiscountAmount()
          : 0.0,
      'total': total,
      'note': widget.cartData?.note ?? '',
      'splitInfo': _splitQty > 1
          ? 'Split ${splitIndex + 1} of $_splitQty'
          : null,
      'fullTotal': _splitQty > 1 ? fullTotal : null,
    };
  }

  Future<void> _openCashDrawer() async {
    try {
      final printers = await PrinterService.getSavedPrinters();
      final availablePrinters = printers
          .where((p) => p.status != PrinterStatus.error)
          .toList();

      if (availablePrinters.isEmpty) {
        debugPrint('No printers available to open cash drawer');
        if (mounted) {
          AppToast.warning(
            context: context,
            title: 'No Printers Found',
            description: 'Please configure a printer to open the cash drawer.',
          );
        }
        return;
      }

      var drawerPrinters = availablePrinters
          .where((p) => p.group == PrinterGroup.receipt)
          .toList();

      if (drawerPrinters.isEmpty) {
        drawerPrinters = availablePrinters;
        debugPrint(
          'No receipt printers configured, falling back to all available printers',
        );
        if (mounted) {
          AppToast.warning(
            context: context,
            title: 'No Receipt Printer',
            description: 'Using other available printers to open cash drawer.',
          );
        }
      }

      for (final printer in drawerPrinters) {
        try {
          final interfaceType = _printerTypeToString(printer.type);
          await PrinterService.openCashDrawer(
            interfaceType: interfaceType,
            identifier: printer.identifier,
          );
          debugPrint('Cash drawer opened on ${printer.name}');
        } catch (e) {
          debugPrint('Error opening cash drawer on ${printer.name}: $e');
        }
      }
    } catch (e) {
      debugPrint('Error opening cash drawer: $e');
    }
  }

  Future<void> _handlePrintReceipt() async {
    if (widget.cartItems.isEmpty) {
      return;
    }

    try {
      setState(() {
        _isPrintingReceipt = true;
      });

      // Get receipt printers (receipt group) only
      final printers = await PrinterService.getSavedPrinters();
      final receiptPrinters = printers
          .where((p) => p.group == PrinterGroup.receipt)
          .where((p) => p.status != PrinterStatus.error)
          .toList();

      if (receiptPrinters.isEmpty) {
        if (mounted) {
          AppToast.warning(
            context: context,
            title: 'No Receipt Printers Found',
            description: 'Please add a receipt printer (Receipt group) first.',
          );
        }
        return;
      }

      // Format order data for current split
      final orderData = _formatOrderDataForSplit(_currentSplitIndex);

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

      if (mounted) {
        if (allSuccess) {
          AppToast.success(
            context: context,
            title: 'Receipt Printed',
            description: _splitQty > 1
                ? 'Receipt for split ${_currentSplitIndex + 1} printed successfully'
                : 'Customer receipt printed successfully',
          );
        } else {
          AppToast.error(
            context: context,
            title: 'Printing Failed',
            description: 'Some printers failed. Please check printer status.',
          );
        }
      }
    } catch (e) {
      debugPrint('Error printing receipt: $e');
      if (mounted) {
        AppToast.error(
          context: context,
          title: 'Printing Error',
          description: 'Error printing: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPrintingReceipt = false;
        });
      }
    }
  }

  Future<void> _handlePrintAllReceipts() async {
    if (widget.cartItems.isEmpty) {
      return;
    }

    try {
      setState(() {
        _isPrintingAllReceipts = true;
      });

      // Get receipt printers (receipt group) only
      final printers = await PrinterService.getSavedPrinters();
      final receiptPrinters = printers
          .where((p) => p.group == PrinterGroup.receipt)
          .where((p) => p.status != PrinterStatus.error)
          .toList();

      if (receiptPrinters.isEmpty) {
        if (mounted) {
          AppToast.warning(
            context: context,
            title: 'No Receipt Printers Found',
            description: 'Please add a receipt printer (Receipt group) first.',
          );
        }
        return;
      }

      // Print receipts for all splits
      bool allSuccess = true;
      for (int i = 0; i < _splitQty; i++) {
        final orderData = _formatOrderDataForSplit(i);

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
            debugPrint('Error printing split $i to ${printer.name}: $e');
            allSuccess = false;
          }
        }
      }

      if (mounted) {
        if (allSuccess) {
          AppToast.success(
            context: context,
            title: 'All Receipts Printed',
            description: _splitQty > 1
                ? '$_splitQty receipts printed successfully'
                : 'Customer receipt printed successfully',
          );
        } else {
          AppToast.error(
            context: context,
            title: 'Printing Failed',
            description:
                'Some receipts failed to print. Please check printer status.',
          );
        }
      }
    } catch (e) {
      debugPrint('Error printing all receipts: $e');
      if (mounted) {
        AppToast.error(
          context: context,
          title: 'Printing Error',
          description: 'Error printing: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPrintingAllReceipts = false;
        });
      }
    }
  }

  Future<void> _handleFinalize() async {
    if (_isCreatingOrder) return;

    // Validate that payment is complete (allow overpayment)
    final splitTotals = _calculateSplitTotals();
    final outstanding =
        splitTotals[_currentSplitIndex] - _splitPayments[_currentSplitIndex];
    if (outstanding > 0.01) {
      AppToast.warning(
        context: context,
        title: 'Payment Incomplete',
        description:
            'Please complete payment. Outstanding: \$${outstanding.toStringAsFixed(2)}',
      );
      return;
    }

    setState(() {
      _isCreatingOrder = true;
    });

    try {
      // Open cash drawer if any payment has change owed
      bool hasChangeOwed = false;
      for (int i = 0; i < _splitQty; i++) {
        for (final paymentMethod in _splitPaymentMethods[i]) {
          final change = (paymentMethod['change'] as num?)?.toDouble() ?? 0;
          if (change > 0) {
            hasChangeOwed = true;
            break;
          }
        }
        if (hasChangeOwed) break;
      }

      if (hasChangeOwed) {
        await _openCashDrawer();
      }

      // Get store ID from DataProvider (source of truth)
      final dataProvider = DataProvider();
      final profile = _authService.getProfile();
      final storeId = dataProvider.store?.id ?? profile?.storeId;
      if (storeId == null) {
        throw Exception('Store ID not found. Please login again.');
      }

      // Calculate totals (rounded to 2 decimal places)
      final subtotal = double.parse(_calculateSubtotal().toStringAsFixed(2));
      final discountedTotal = double.parse(
        _calculateDiscountedTotal().toStringAsFixed(2),
      );
      final taxAmount = double.parse(_calculateTax().toStringAsFixed(2));
      final feeAmount = double.parse(_calculateFeeAmount().toStringAsFixed(2));
      final total = double.parse(
        (discountedTotal + feeAmount + taxAmount).toStringAsFixed(2),
      );

      // Convert order type to API format
      String orderType;
      switch (widget.orderType?.toLowerCase()) {
        case 'takeout':
        case 'pickup':
          orderType = ApiConstants.orderTypePickup;
          break;
        case 'delivery':
          orderType = ApiConstants.orderTypeDelivery;
          break;
        case 'dinein':
        case 'dine-in':
          orderType = ApiConstants.orderTypeDineIn;
          break;
        default:
          orderType = ApiConstants.orderTypePickup;
      }

      // Convert cart items to API format
      final items = widget.cartItems
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

            // Calculate price per unit with modifiers
            final modifierPrice = _calculateItemModifierPrice(item);
            final pricePerUnit = item.product.posEffectivePrice + modifierPrice;

            return {
              // Regular products: include 'item' field with product ID
              if (item.product.type != 'custom') 'item': item.product.id,
              // Custom items: include 'customItem' field with custom name
              if (item.product.type == 'custom')
                'customItem': item.product.name,
              'quantity': item.quantity,
              'price': pricePerUnit, // Price per item with modifiers
              'modifiers': modifierIds, // Array of modifier IDs
              'itemNote': item.itemNote,
              if (itemDiscount != null) 'itemDiscount': itemDiscount,
              'taxEnable': item.product.taxEnable,
              if (item.product.taxRule != null)
                'taxRule': item.product.taxRule!.toJson(),
            };
          })
          .toList();

      // Build discount if present
      Map<String, dynamic>? discount;
      if (widget.cartData?.discount != null) {
        discount = {
          'type': widget.cartData!.discount!.type,
          'value': widget.cartData!.discount!.value,
        };
      }

      // Build payments array from all splits
      final payments = <Map<String, dynamic>>[];
      for (int i = 0; i < _splitQty; i++) {
        if (_splitPaymentMethods[i].isNotEmpty) {
          payments.addAll(_splitPaymentMethods[i]);
        }
      }

      // Calculate total tip (rounded to 2 decimal places)
      double totalTipAmount = 0.0;
      for (int i = 0; i < _splitQty; i++) {
        final tip = _splitTips[i];
        final splitAmount = double.parse(
          _calculateSplitAmounts()[i].toStringAsFixed(2),
        );
        final splitTax = double.parse(
          _getSplitTaxAmounts()[i].toStringAsFixed(2),
        );
        final tipValue = tip['type'] == '%'
            ? double.parse(
                (((splitAmount + splitTax) * tip['amount']) / 100)
                    .toStringAsFixed(2),
              )
            : double.parse(tip['amount'].toDouble().toStringAsFixed(2));
        totalTipAmount += tipValue;
      }
      // Round final total tip amount
      totalTipAmount = double.parse(totalTipAmount.toStringAsFixed(2));

      // Determine order status based on sendToKitchen flag
      final orderStatus = _sendToKitchen
          ? ApiConstants.orderStatusInKitchen
          : ApiConstants.orderStatusComplete;

      // Calculate final total (ensure all amounts are properly rounded)
      final finalTotal = double.parse(
        (total + totalTipAmount).toStringAsFixed(2),
      );

      if (widget.isEditMode && widget.orderId != null) {
        // Update existing order
        final updatedOrder = await _ordersService.updateOrder(
          orderId: widget.orderId!,
          items: items,
          subtotal: subtotal,
          total: finalTotal,
          tax: taxAmount,
          tip: totalTipAmount,
          comment: widget.cartData?.note,
          discount: discount,
          paymentStatus: ApiConstants.paymentStatusPaid,
          orderstatus: orderStatus,
          payments: payments,
        );

        // Update DataProvider's in-memory list for immediate UI update
        _dataProvider.updateTakeoutOrderInMemory(updatedOrder);

        // Trigger background refresh to ensure latest data from API
        _dataProvider.loadTakeoutOrders(forceRefresh: true);

        // Background refetch the updated order to get server-generated item IDs
        // This ensures refund flow has proper item IDs even from cache
        Future.microtask(() async {
          try {
            final freshOrder = await _ordersService.getOrderById(
              updatedOrder.id,
              forceRefresh: true,
            );
            // Update caches with the fresh order containing server item IDs
            await _ordersService.updateOrderInCache(freshOrder);
            _dataProvider.updateTakeoutOrderInMemory(freshOrder);
            debugPrint(
              'Background refetch completed for order: ${freshOrder.orderNumber}',
            );
          } catch (e) {
            debugPrint('Background refetch failed: $e');
          }
        });

        // Play checkout completion sound
        _audioService.playCheckoutDone();

        // Show success message
        if (mounted) {
          AppToast.success(
            context: context,
            title: 'Order Updated Successfully',
            description: 'Order #${updatedOrder.orderNumber} payment completed',
          );

          // Navigate back to appropriate page based on order type
          final redirectRoute = widget.orderType?.toLowerCase() == 'dinein'
              ? '/dinein'
              : '/takeout';
          Navigator.of(context).pushNamedAndRemoveUntil(
            redirectRoute,
            (route) => route.settings.name == '/',
          );
        }
      } else {
        // Create new order
        final createdOrder = await _ordersService.createOrder(
          store: storeId,
          customer: widget.customer?.id,
          phone: widget.customer?.phone,
          orderType: orderType,
          paymentStatus: ApiConstants.paymentStatusPaid,
          subtotal: subtotal,
          total: finalTotal,
          orderstatus: orderStatus,
          items: items,
          tax: taxAmount,
          tip: totalTipAmount,
          comment: widget.cartData?.note,
          discount: discount,
          payments: payments,
          pickupTime: widget.pickupTime, // null = ASAP
        );

        // Optimistically add the new order to cache and in-memory state
        await _ordersService.addOrderToCache(
          createdOrder,
          existingOrders: _dataProvider.takeoutOrdersList,
        );
        _dataProvider.addOptimisticTakeoutOrder(createdOrder);

        // Trigger background refresh to ensure latest data from API
        _dataProvider.loadTakeoutOrders(forceRefresh: true);

        // Background refetch the created order to get server-generated item IDs
        // This ensures refund flow has proper item IDs even from cache
        Future.microtask(() async {
          try {
            final freshOrder = await _ordersService.getOrderById(
              createdOrder.id,
              forceRefresh: true,
            );
            // Update caches with the fresh order containing server item IDs
            await _ordersService.updateOrderInCache(freshOrder);
            _dataProvider.updateTakeoutOrderInMemory(freshOrder);
            debugPrint(
              'Background refetch completed for order: ${freshOrder.orderNumber}',
            );
          } catch (e) {
            debugPrint('Background refetch failed: $e');
          }
        });

        // Play checkout completion sound
        _audioService.playCheckoutDone();

        // Show success message
        if (mounted) {
          AppToast.success(
            context: context,
            title: 'Order Created Successfully',
            description: 'Order #${createdOrder.orderNumber}',
          );

          // Navigate back to appropriate page based on order type
          final redirectRoute = widget.orderType?.toLowerCase() == 'dinein'
              ? '/dinein'
              : '/takeout';
          Navigator.of(context).pushNamedAndRemoveUntil(
            redirectRoute,
            (route) => route.settings.name == '/',
          );
        }
      }
    } catch (e) {
      debugPrint('Error creating order: $e');
      if (mounted) {
        AppToast.error(
          context: context,
          title: 'Failed to Create Order',
          description: e.toString(),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingOrder = false;
        });
      }
    }
  }
}
