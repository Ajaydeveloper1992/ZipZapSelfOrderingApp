import 'package:zipzap_pos_self_orders/models/order_model.dart'
    hide OrderCustomer, OrderModifier;
import 'package:zipzap_pos_self_orders/models/product_model.dart';
import 'package:zipzap_pos_self_orders/models/category_model.dart';
import 'package:zipzap_pos_self_orders/models/modifier_group_model.dart';
import 'package:zipzap_pos_self_orders/models/customer_model.dart';

class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final Pagination? pagination;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.pagination,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    return ApiResponse<T>(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : null,
      pagination: json['pagination'] != null
          ? Pagination.fromJson(json['pagination'] as Map<String, dynamic>)
          : null,
    );
  }
}

class Pagination {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int itemsPerPage;
  final bool hasNextPage;
  final bool hasPrevPage;

  Pagination({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.itemsPerPage,
    required this.hasNextPage,
    required this.hasPrevPage,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      currentPage: json['currentPage'] as int? ?? 1,
      totalPages: json['totalPages'] as int? ?? 1,
      totalItems: json['totalItems'] as int? ?? 0,
      itemsPerPage: json['itemsPerPage'] as int? ?? 20,
      hasNextPage: json['hasNextPage'] as bool? ?? false,
      hasPrevPage: json['hasPrevPage'] as bool? ?? false,
    );
  }
}

class OrdersResponse {
  final List<Order> orders;
  final Pagination? pagination;
  final OrderStats? stats;

  OrdersResponse({required this.orders, this.pagination, this.stats});

  factory OrdersResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> ordersJson = json['data'] as List<dynamic>? ?? [];
    final orders = ordersJson
        .map((orderJson) => Order.fromJson(orderJson as Map<String, dynamic>))
        .toList();

    return OrdersResponse(
      orders: orders,
      pagination: json['pagination'] != null
          ? Pagination.fromJson(json['pagination'] as Map<String, dynamic>)
          : null,
      stats: json['stats'] != null
          ? OrderStats.fromJson(json['stats'] as Map<String, dynamic>)
          : null,
    );
  }
}

class OrderStats {
  final int all;
  final int pending;
  final int inKitchen;
  final int complete;
  final int voided;
  final int rejected;
  final int refunded;
  final int partiallyRefunded;

  OrderStats({
    required this.all,
    required this.pending,
    required this.inKitchen,
    required this.complete,
    required this.voided,
    required this.rejected,
    required this.refunded,
    required this.partiallyRefunded,
  });

  factory OrderStats.fromJson(Map<String, dynamic> json) {
    return OrderStats(
      all: json['all'] as int? ?? 0,
      pending: json['Pending'] as int? ?? 0,
      inKitchen: json['InKitchen'] as int? ?? 0,
      complete: json['Complete'] as int? ?? 0,
      voided: json['Voided'] as int? ?? 0,
      rejected: json['Rejected'] as int? ?? 0,
      refunded: json['Refunded'] as int? ?? 0,
      partiallyRefunded: json['Partially Refunded'] as int? ?? 0,
    );
  }

  // Helper method to get count by status key (lowercase)
  int getCount(String status) {
    switch (status.toLowerCase()) {
      case 'all':
        return all;
      case 'pending':
        return pending;
      case 'inkitchen':
        return inKitchen;
      case 'complete':
        return complete;
      case 'voided':
        return voided;
      case 'rejected':
        return rejected;
      case 'refunded':
        return refunded;
      case 'partiallyrefunded':
        return partiallyRefunded;
      default:
        return 0;
    }
  }
}

class ProductsResponse {
  final List<Product> products;
  final Pagination? pagination;

  ProductsResponse({required this.products, this.pagination});

  factory ProductsResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> productsJson = json['data'] as List<dynamic>? ?? [];
    final products = productsJson
        .map(
          (productJson) =>
              Product.fromJson(productJson as Map<String, dynamic>),
        )
        .toList();

    return ProductsResponse(
      products: products,
      pagination: json['pagination'] != null
          ? Pagination.fromJson(json['pagination'] as Map<String, dynamic>)
          : null,
    );
  }
}

class CategoriesResponse {
  final List<Category> categories;
  final Pagination? pagination;

  CategoriesResponse({required this.categories, this.pagination});

  factory CategoriesResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> categoriesJson = json['data'] as List<dynamic>? ?? [];
    final categories = categoriesJson
        .map(
          (categoryJson) =>
              Category.fromJson(categoryJson as Map<String, dynamic>),
        )
        .toList();

    return CategoriesResponse(
      categories: categories,
      pagination: json['pagination'] != null
          ? Pagination.fromJson(json['pagination'] as Map<String, dynamic>)
          : null,
    );
  }
}

class CustomersResponse {
  final List<Customer> customers;
  final Pagination? pagination;

  CustomersResponse({required this.customers, this.pagination});

  factory CustomersResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> customersJson = json['data'] as List<dynamic>? ?? [];
    final customers = customersJson
        .map(
          (customerJson) =>
              Customer.fromJson(customerJson as Map<String, dynamic>),
        )
        .toList();

    return CustomersResponse(
      customers: customers,
      pagination: json['pagination'] != null
          ? Pagination.fromJson(json['pagination'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ModifierGroupsResponse {
  final List<ModifierGroup> modifierGroups;
  final Pagination? pagination;

  ModifierGroupsResponse({required this.modifierGroups, this.pagination});

  factory ModifierGroupsResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> modifierGroupsJson =
        json['data'] as List<dynamic>? ?? [];
    final modifierGroups = modifierGroupsJson
        .map(
          (modifierGroupJson) =>
              ModifierGroup.fromJson(modifierGroupJson as Map<String, dynamic>),
        )
        .toList();

    return ModifierGroupsResponse(
      modifierGroups: modifierGroups,
      pagination: json['pagination'] != null
          ? Pagination.fromJson(json['pagination'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ModifiersResponse {
  final List<Modifier> modifiers;
  final Pagination? pagination;

  ModifiersResponse({required this.modifiers, this.pagination});

  factory ModifiersResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> modifiersJson = json['data'] as List<dynamic>? ?? [];
    final modifiers = modifiersJson
        .map(
          (modifierJson) =>
              Modifier.fromJson(modifierJson as Map<String, dynamic>),
        )
        .toList();

    return ModifiersResponse(
      modifiers: modifiers,
      pagination: json['pagination'] != null
          ? Pagination.fromJson(json['pagination'] as Map<String, dynamic>)
          : null,
    );
  }
}
