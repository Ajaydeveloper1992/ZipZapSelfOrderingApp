class ReportModel {
  final String date;
  final String store;
  final String createdBy;
  final double netSale;
  final double grossSale;
  final double tax;
  final double refund;
  final double discount;
  final double itemDiscount;
  final double orderDiscount;
  final int voidOrders;
  final double voidOrdersTotal;
  final double tip;
  final double totalCollectedInCash;
  final double totalCollectedInCard;
  final int totalOrders;
  final double averageOrderValue;
  final int totalItems;
  final double averageItemsPerOrder;
  final List<TopSellingItem> topSellingItems;
  final List<PaymentMethod> paymentMethods;
  final List<HourlyBreakdown> hourlyBreakdown;

  ReportModel({
    required this.date,
    required this.store,
    required this.createdBy,
    required this.netSale,
    required this.grossSale,
    required this.tax,
    required this.refund,
    required this.discount,
    required this.itemDiscount,
    required this.orderDiscount,
    required this.voidOrders,
    required this.voidOrdersTotal,
    required this.tip,
    required this.totalCollectedInCash,
    required this.totalCollectedInCard,
    required this.totalOrders,
    required this.averageOrderValue,
    required this.totalItems,
    required this.averageItemsPerOrder,
    required this.topSellingItems,
    required this.paymentMethods,
    required this.hourlyBreakdown,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      date: json['date'] as String? ?? '',
      store: json['store'] as String? ?? '',
      createdBy: json['createdBy'] as String? ?? '',
      netSale: (json['netSale'] as num?)?.toDouble() ?? 0.0,
      grossSale: (json['grossSale'] as num?)?.toDouble() ?? 0.0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0.0,
      refund: (json['refund'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      itemDiscount: (json['itemDiscount'] as num?)?.toDouble() ?? 0.0,
      orderDiscount: (json['orderDiscount'] as num?)?.toDouble() ?? 0.0,
      voidOrders: (json['voidOrders'] as int?) ?? 0,
      voidOrdersTotal: (json['voidOrdersTotal'] as num?)?.toDouble() ?? 0.0,
      tip: (json['tip'] as num?)?.toDouble() ?? 0.0,
      totalCollectedInCash: (json['totalCollectedInCash'] as num?)?.toDouble() ?? 0.0,
      totalCollectedInCard: (json['totalCollectedInCard'] as num?)?.toDouble() ?? 0.0,
      totalOrders: (json['totalOrders'] as int?) ?? 0,
      averageOrderValue: (json['averageOrderValue'] as num?)?.toDouble() ?? 0.0,
      totalItems: (json['totalItems'] as int?) ?? 0,
      averageItemsPerOrder: (json['averageItemsPerOrder'] as num?)?.toDouble() ?? 0.0,
      topSellingItems: (json['topSellingItems'] as List<dynamic>?)
              ?.map((item) => TopSellingItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      paymentMethods: (json['paymentMethods'] as List<dynamic>?)
              ?.map((method) => PaymentMethod.fromJson(method as Map<String, dynamic>))
              .toList() ??
          [],
      hourlyBreakdown: (json['hourlyBreakdown'] as List<dynamic>?)
              ?.map((hour) => HourlyBreakdown.fromJson(hour as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class TopSellingItem {
  final String itemId;
  final String itemName;
  final int quantity;
  final double revenue;

  TopSellingItem({
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.revenue,
  });

  factory TopSellingItem.fromJson(Map<String, dynamic> json) {
    return TopSellingItem(
      itemId: json['itemId'] as String? ?? '',
      itemName: json['itemName'] as String? ?? '',
      quantity: (json['quantity'] as int?) ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class PaymentMethod {
  final String method;
  final int count;
  final double amount;

  PaymentMethod({
    required this.method,
    required this.count,
    required this.amount,
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      method: json['method'] as String? ?? '',
      count: (json['count'] as int?) ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class HourlyBreakdown {
  final int hour;
  final int orders;
  final double revenue;

  HourlyBreakdown({
    required this.hour,
    required this.orders,
    required this.revenue,
  });

  factory HourlyBreakdown.fromJson(Map<String, dynamic> json) {
    return HourlyBreakdown(
      hour: (json['hour'] as int?) ?? 0,
      orders: (json['orders'] as int?) ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

