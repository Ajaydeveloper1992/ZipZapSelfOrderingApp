import 'package:flutter/foundation.dart' show debugPrint;
import 'package:zipzap_pos_self_orders/models/product_model.dart' show TaxRule;
import 'package:zipzap_pos_self_orders/providers/data_provider.dart';

class Order {
  final String id;
  final String orderNumber;
  final OrderStore? store;
  final OrderCustomer? customer;
  final String? phone;
  final String orderType;
  final String origin;
  final String paymentStatus;
  final double subtotal;
  final double total;
  final double tip;
  final double tax;
  final double totalRefund;
  final String orderstatus;
  final String? comment;
  final String? note;
  final List<OrderItem> items;
  final OrderCreatedBy? createdBy;
  final OrderCreatedBy? staff;
  final OrderDiscount? discount;
  final bool prePaid;
  final DateTime date;
  final List<OrderPayment> payments;
  final OrderPickupInfo? pickupInfo;
  final OrderTableInfo? tableInfo;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String
  storeTimezone; // IANA timezone for consistent display (e.g., 'America/Toronto')

  Order({
    required this.id,
    required this.orderNumber,
    this.store,
    this.customer,
    this.phone,
    required this.orderType,
    required this.origin,
    required this.paymentStatus,
    required this.subtotal,
    required this.total,
    required this.tip,
    required this.tax,
    this.totalRefund = 0.0,
    required this.orderstatus,
    this.comment,
    this.note,
    required this.items,
    this.createdBy,
    this.staff,
    this.discount,
    this.prePaid = false,
    required this.date,
    required this.payments,
    this.pickupInfo,
    this.tableInfo,
    this.createdAt,
    this.updatedAt,
    this.storeTimezone = 'America/Toronto',
  });

  // Helper method to parse createdBy field
  static OrderCreatedBy? _parseCreatedBy(dynamic data) {
    if (data == null) return null;

    if (data is String) {
      // If it's a string (user ID), create minimal OrderCreatedBy object
      return OrderCreatedBy(id: data, email: '', firstName: '', lastName: '');
    } else if (data is Map<String, dynamic>) {
      // If it's an object, parse it normally
      return OrderCreatedBy.fromJson(data);
    }

    return null;
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    // Handle store - can be string ID or object
    OrderStore? store;
    if (json['store'] != null) {
      if (json['store'] is String) {
        store = OrderStore(id: json['store'] as String, name: '');
      } else if (json['store'] is Map<String, dynamic>) {
        store = OrderStore.fromJson(json['store'] as Map<String, dynamic>);
      }
    }

    // Handle customer - can be string ID or object
    OrderCustomer? customer;
    if (json['customer'] != null) {
      if (json['customer'] is String) {
        customer = OrderCustomer(
          id: json['customer'] as String,
          firstName: '',
          lastName: '',
          phone: '',
        );
      } else if (json['customer'] is Map<String, dynamic>) {
        customer = OrderCustomer.fromJson(
          json['customer'] as Map<String, dynamic>,
        );
      }
    }

    return Order(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      orderNumber: json['orderNumber'] as String? ?? '',
      store: store,
      customer: customer,
      phone: json['phone']?.toString(),
      orderType: json['orderType'] as String? ?? '',
      origin: json['origin'] as String? ?? '',
      paymentStatus: json['paymentStatus'] as String? ?? 'Pending',
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      tip: (json['tip'] as num?)?.toDouble() ?? 0.0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0.0,
      totalRefund: (json['totalRefund'] as num?)?.toDouble() ?? 0.0,
      orderstatus:
          json['orderstatus'] as String? ??
          json['orderStatus'] as String? ??
          'Pending',
      comment: json['comment'] as String?,
      note: json['note'] as String?,
      items:
          (json['items'] as List<dynamic>?)
              ?.map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      createdBy: _parseCreatedBy(json['createdBy']),
      staff: _parseCreatedBy(json['staff']),
      discount: json['discount'] != null
          ? OrderDiscount.fromJson(json['discount'] as Map<String, dynamic>)
          : null,
      prePaid: json['prePaid'] as bool? ?? false,
      // Parse date and convert to local timezone for consistent display
      date: json['date'] != null
          ? (DateTime.tryParse(json['date'].toString())?.toLocal() ??
                DateTime.now())
          : DateTime.now(),
      payments:
          (json['payments'] as List<dynamic>?)
              ?.map(
                (payment) =>
                    OrderPayment.fromJson(payment as Map<String, dynamic>),
              )
              .toList() ??
          [],
      pickupInfo: json['pickupInfo'] != null
          ? OrderPickupInfo.fromJson(json['pickupInfo'] as Map<String, dynamic>)
          : null,
      tableInfo: json['tableInfo'] != null
          ? OrderTableInfo.fromJson(json['tableInfo'] as Map<String, dynamic>)
          : null,
      // Parse timestamps and convert to local timezone for consistent display
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())?.toLocal()
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())?.toLocal()
          : null,
      storeTimezone: json['storeTimezone'] as String? ?? 'America/Toronto',
    );
  }

  /// Who to show in the "Created By" / "Server" UI row.
  ///
  /// Prefers the explicitly assigned staff (the server selected for the
  /// table when the order was created) and falls back to the actual
  /// authenticated creator. The raw [createdBy] field is still kept
  /// untouched for audit/reporting purposes.
  OrderCreatedBy? get displayCreator => staff ?? createdBy;

  String get customerName {
    if (customer != null) {
      final name = '${customer!.firstName} ${customer!.lastName}'.trim();
      return name.isEmpty ? 'N/A' : name;
    }
    return 'N/A';
  }

  String get customerPhone {
    return customer?.phone ?? phone ?? 'N/A';
  }

  String get paymentMethod {
    if (payments.isEmpty) return 'N/A';
    final methods = payments.map((p) => p.method).toSet().toList();
    return methods.join(', ');
  }

  String get displayPaymentStatus {
    if (origin == 'WEB' &&
        paymentStatus == 'Pending' &&
        orderstatus == 'Rejected') {
      return 'Unpaid';
    }
    return paymentStatus;
  }

  double get displayTotal {
    if (origin == 'WEB' &&
        paymentStatus == 'Pending' &&
        orderstatus == 'Rejected') {
      return 0;
    }
    return total;
  }

  String get customerEmail {
    return customer?.email ?? 'N/A';
  }

  int get refundedItemCount {
    return items
        .where(
          (item) =>
              item.itemStatus?.toLowerCase() == 'refunded' ||
              (item.refundQuantity ?? 0) > 0,
        )
        .fold(0, (sum, item) => sum + (item.refundQuantity ?? item.quantity));
  }

  int get voidedItemCount {
    return items.fold(0, (sum, item) {
      if (item.itemStatus?.toLowerCase() == 'voided') {
        return sum + item.quantity;
      }
      return sum;
    });
  }

  int get activeItemCount {
    return items.fold(0, (sum, item) {
      if (item.itemStatus?.toLowerCase() == 'voided') return sum;
      return sum + item.quantity;
    });
  }
}

class OrderStore {
  final String id;
  final String name;

  OrderStore({required this.id, required this.name});

  factory OrderStore.fromJson(Map<String, dynamic> json) {
    return OrderStore(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}

class OrderCustomer {
  final String id;
  final String firstName;
  final String lastName;
  final String phone;
  final String? email;
  final bool isReturning;
  final int totalOrders;

  OrderCustomer({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.email,
    this.isReturning = false,
    this.totalOrders = 0,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory OrderCustomer.fromJson(Map<String, dynamic> json) {
    return OrderCustomer(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email'] as String?,
      isReturning: json['isReturning'] as bool? ?? false,
      totalOrders: (json['totalOrders'] as num?)?.toInt() ?? 0,
    );
  }
}

class OrderItem {
  final String id; // MongoDB's _id for this item
  final OrderItemDetail? item;
  final String customItem;
  final int quantity;
  final double price;
  final List<OrderModifier> modifiers;
  final List<dynamic> modifiersgroup;
  final String? itemNote;
  final OrderDiscount? discount;
  final String? itemStatus;
  final int? refundQuantity;
  final int? voidQuantity;
  final String? voidReason;
  final String? guestGroup; // Guest group assignment for dine-in orders
  final bool taxEnable;
  final TaxRule? taxRule;

  OrderItem({
    required this.id,
    this.item,
    required this.customItem,
    required this.quantity,
    required this.price,
    required this.modifiers,
    required this.modifiersgroup,
    this.itemNote,
    this.discount,
    this.itemStatus,
    this.guestGroup,
    this.refundQuantity,
    this.voidQuantity,
    this.voidReason,
    this.taxEnable = true,
    this.taxRule,
  });

  String get displayName => item?.name ?? customItem;

  /// Helper to extract ID from various formats (String, Map with $oid, etc.)
  static String _extractId(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is Map) {
      // Handle MongoDB Extended JSON format: { "$oid": "..." }
      if (value['\$oid'] != null) return value['\$oid'] as String;
      // Handle regular map with _id or id
      if (value['_id'] != null) return _extractId(value['_id']);
      if (value['id'] != null) return _extractId(value['id']);
    }
    // Fallback: convert to string
    return value.toString();
  }

  /// Resolve taxRule from various formats: full Map object, string ID, or null.
  /// When the API returns just a string ID, looks up the full TaxRule from
  /// DataProvider's cached tax rules list.
  static TaxRule? _resolveTaxRule(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) {
      return TaxRule.fromJson(value);
    }
    if (value is String && value.isNotEmpty) {
      try {
        final taxRules = DataProvider().taxRulesList;
        return taxRules.firstWhere((rule) => rule.id == value);
      } catch (_) {
        debugPrint(
          '⚠️ _resolveTaxRule: Failed to find taxRule with ID "$value" '
          'in ${DataProvider().taxRulesList.length} cached rules',
        );
        return null;
      }
    }
    return null;
  }

  /// Counter for generating fallback IDs when server doesn't provide them
  static int _fallbackIdCounter = 0;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    // Handle item - can be string ID or object
    OrderItemDetail? item;
    if (json['item'] != null) {
      if (json['item'] is String) {
        item = OrderItemDetail(
          id: json['item'] as String,
          name: json['customItem'] as String? ?? '',
          price: (json['price'] as num?)?.toDouble() ?? 0.0,
        );
      } else if (json['item'] is Map<String, dynamic>) {
        item = OrderItemDetail.fromJson(json['item'] as Map<String, dynamic>);
      }
    }

    // Handle modifiers - can be array of strings (IDs) or array of objects
    List<OrderModifier> modifiers = [];
    if (json['modifiers'] != null) {
      final modsList = json['modifiers'] as List<dynamic>;
      modifiers = modsList.map((mod) {
        if (mod is String) {
          return OrderModifier(id: mod, name: '');
        } else if (mod is Map<String, dynamic>) {
          return OrderModifier.fromJson(mod);
        }
        return OrderModifier(id: '', name: '');
      }).toList();
    }

    // Extract order item's unique _id (handles String, Map with $oid, etc.)
    String itemId = _extractId(json['_id']) != ''
        ? _extractId(json['_id'])
        : _extractId(json['id']);

    // Generate fallback ID if server doesn't provide one
    // This is common for sub-documents in MongoDB arrays
    if (itemId.isEmpty) {
      itemId =
          'item_${_fallbackIdCounter++}_${DateTime.now().millisecondsSinceEpoch}';
    }

    return OrderItem(
      id: itemId,
      item: item,
      customItem: json['customItem'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 1,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      modifiers: modifiers,
      modifiersgroup: json['modifiersgroup'] ?? [],
      itemNote: json['itemNote'] as String?,
      discount: json['discount'] != null
          ? OrderDiscount.fromJson(json['discount'] as Map<String, dynamic>)
          : null,
      itemStatus: json['itemStatus'] as String?,
      refundQuantity: json['refundQuantity'] as int?,
      voidQuantity: json['voidQuantity'] as int?,
      voidReason: json['voidReason'] as String?,
      guestGroup: json['guestGroup'] as String? ?? 'whole_table',
      taxEnable: json['taxEnable'] == null
          ? json['taxRule'] != null
          : json['taxEnable'] is bool
          ? json['taxEnable']
          : json['taxEnable'].toString().toLowerCase() == 'true',
      taxRule: _resolveTaxRule(json['taxRule']),
    );
  }
}

class OrderItemDetail {
  final String id;
  final String name;
  final double price;

  OrderItemDetail({required this.id, required this.name, required this.price});

  factory OrderItemDetail.fromJson(Map<String, dynamic> json) {
    return OrderItemDetail(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class OrderModifier {
  final String id;
  final String name;

  OrderModifier({required this.id, required this.name});

  factory OrderModifier.fromJson(Map<String, dynamic> json) {
    return OrderModifier(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}

class OrderCreatedBy {
  final String id;
  final String email;
  final String firstName;
  final String lastName;

  OrderCreatedBy({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
  });

  factory OrderCreatedBy.fromJson(Map<String, dynamic> json) {
    return OrderCreatedBy(
      id: json['_id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
    );
  }
}

class OrderDiscount {
  final String type; // '$' or '%'
  final double value;

  OrderDiscount({required this.type, required this.value});

  factory OrderDiscount.fromJson(Map<String, dynamic> json) {
    return OrderDiscount(
      type: json['type'] as String? ?? '%',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class OrderPayment {
  final String method;
  final double amount;
  final String? cardType;
  final double? change;
  final double refund;
  final String status;

  OrderPayment({
    required this.method,
    required this.amount,
    this.cardType,
    this.change,
    required this.refund,
    required this.status,
  });

  factory OrderPayment.fromJson(Map<String, dynamic> json) {
    return OrderPayment(
      method: json['method'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      cardType: json['cardType'] as String?,
      change: json['change'] != null
          ? (json['change'] as num).toDouble()
          : null,
      refund: (json['refund'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? '',
    );
  }
}

class OrderPickupInfo {
  final String orderType;
  final DateTime?
  delayTime; // Changed from String to DateTime for proper timezone handling
  final DateTime?
  pickupTime; // Changed from String to DateTime for proper timezone handling

  OrderPickupInfo({required this.orderType, this.delayTime, this.pickupTime});

  factory OrderPickupInfo.fromJson(Map<String, dynamic> json) {
    DateTime? pickupTime;
    final pickupTimeValue = json['pickupTime'];

    if (pickupTimeValue != null) {
      if (pickupTimeValue is String) {
        // Try to parse as ISO date string (new format)
        try {
          pickupTime = DateTime.tryParse(pickupTimeValue)?.toLocal();
        } catch (e) {
          // If parsing fails, it's likely a legacy string format, set to null
          pickupTime = null;
        }
      } else if (pickupTimeValue is int) {
        // Handle timestamp as milliseconds
        pickupTime = DateTime.fromMillisecondsSinceEpoch(
          pickupTimeValue,
        ).toLocal();
      }
    }

    // Parse delayTime similar to pickupTime
    DateTime? delayTime;
    final delayTimeValue = json['delayTime'];

    if (delayTimeValue != null) {
      if (delayTimeValue is String && delayTimeValue.isNotEmpty) {
        // Try to parse as ISO date string (new format)
        try {
          delayTime = DateTime.tryParse(delayTimeValue)?.toLocal();
        } catch (e) {
          // If parsing fails, it's likely a legacy string format, set to null
          delayTime = null;
        }
      } else if (delayTimeValue is int) {
        // Handle timestamp as milliseconds
        delayTime = DateTime.fromMillisecondsSinceEpoch(
          delayTimeValue,
        ).toLocal();
      }
    }

    return OrderPickupInfo(
      orderType: json['orderType'] as String? ?? '',
      delayTime: delayTime,
      pickupTime: pickupTime,
    );
  }
}

class OrderTableInfo {
  final String tableId;
  final String tableName;
  final String floorPlanId;
  final int partySize;
  final DateTime? bookingDate;
  final String? bookingTime;

  OrderTableInfo({
    required this.tableId,
    required this.tableName,
    required this.floorPlanId,
    required this.partySize,
    this.bookingDate,
    this.bookingTime,
  });

  factory OrderTableInfo.fromJson(Map<String, dynamic> json) {
    return OrderTableInfo(
      tableId: json['tableId'] as String? ?? '',
      tableName: json['tableName'] as String? ?? '',
      floorPlanId: json['floorPlanId'] as String? ?? '',
      partySize: (json['partySize'] as num?)?.toInt() ?? 0,
      bookingDate: json['bookingDate'] != null
          ? DateTime.tryParse(json['bookingDate'].toString())
          : null,
      bookingTime: json['bookingTime'] as String?,
    );
  }
}
