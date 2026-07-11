import 'dart:convert';
import 'package:flutter/foundation.dart';

class Customer {
  final String id;
  final String firstName;
  final String lastName;
  final bool isReturning;
  final String? email;
  final String? phone;
  final CustomerAddress? address;
  final CustomerCreatedBy? createdBy;
  final CustomerStore? store;
  final List<CustomerOrder> orders;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Customer({
    required this.id,
    required this.firstName,
    this.lastName = '',
    this.isReturning = false,
    this.email,
    this.phone,
    this.address,
    this.createdBy,
    this.store,
    List<CustomerOrder>? orders,
    this.note,
    this.createdAt,
    this.updatedAt,
  }) : orders = orders ?? [];

  String get fullName =>
      firstName.isNotEmpty ? firstName : lastName.isNotEmpty ? lastName : '';

  int get ordersCount => orders.length;

  double get totalSpent {
    return orders.fold(0.0, (sum, order) => sum + order.total);
  }

  factory Customer.fromJson(Map<String, dynamic> json) {
    try {
      // Handle phone - can be string or number
      String? phoneValue;
      if (json['phone'] != null) {
        if (json['phone'] is String) {
          phoneValue = json['phone'] as String;
        } else if (json['phone'] is num) {
          phoneValue = (json['phone'] as num).toString();
        } else {
          phoneValue = json['phone'].toString();
        }
      }

      // Handle email - convert empty string to null, handle if it's a Map
      String? emailValue;
      if (json['email'] != null) {
        if (json['email'] is String) {
          final emailStr = json['email'] as String;
          emailValue = emailStr.isEmpty ? null : emailStr;
        } else if (json['email'] is Map) {
          // Skip if email is a Map (unexpected format)
          emailValue = null;
        } else {
          final emailStr = json['email'].toString();
          emailValue = emailStr.isEmpty ? null : emailStr;
        }
      }

      // Handle note - convert empty string to null, handle if it's a Map
      String? noteValue;
      if (json['note'] != null) {
        if (json['note'] is String) {
          final noteStr = json['note'] as String;
          noteValue = noteStr.isEmpty ? null : noteStr;
        } else if (json['note'] is Map) {
          // Skip if note is a Map (unexpected format)
          noteValue = null;
        } else {
          final noteStr = json['note'].toString();
          noteValue = noteStr.isEmpty ? null : noteStr;
        }
      }

      // Handle address - safely parse, skip if not a Map
      CustomerAddress? addressValue;
      if (json['address'] != null && json['address'] is Map) {
        try {
          addressValue = CustomerAddress.fromJson(
            json['address'] as Map<String, dynamic>,
          );
        } catch (e) {
          // If address parsing fails, set to null
          addressValue = null;
        }
      }

      // Handle createdBy
      CustomerCreatedBy? createdByValue;
      if (json['createdBy'] != null && json['createdBy'] is Map) {
        try {
          createdByValue = CustomerCreatedBy.fromJson(
            json['createdBy'] as Map<String, dynamic>,
          );
        } catch (e) {
          createdByValue = null;
        }
      }

      // Handle store
      CustomerStore? storeValue;
      if (json['store'] != null && json['store'] is Map) {
        try {
          storeValue = CustomerStore.fromJson(
            json['store'] as Map<String, dynamic>,
          );
        } catch (e) {
          storeValue = null;
        }
      }

      // Handle orders
      List<CustomerOrder> ordersValue = [];
      if (json['orders'] != null && json['orders'] is List) {
        try {
          ordersValue = (json['orders'] as List<dynamic>)
              .map(
                (order) =>
                    CustomerOrder.fromJson(order as Map<String, dynamic>),
              )
              .toList();
        } catch (e) {
          ordersValue = [];
        }
      }

      return Customer(
        id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
        firstName: json['firstName']?.toString() ?? '',
        lastName: json['lastName']?.toString() ?? '',
        isReturning: json['isReturning'] as bool? ?? false,
        email: emailValue,
        phone: phoneValue,
        address: addressValue,
        createdBy: createdByValue,
        store: storeValue,
        orders: ordersValue,
        note: noteValue,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'].toString())
            : null,
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'].toString())
            : null,
      );
    } catch (e) {
      debugPrint('Error parsing Customer from JSON: $e');
      try {
        // Safely convert JSON to string for logging using jsonEncode
        final jsonStr = jsonEncode(json);
        debugPrint('JSON data: $jsonStr');
      } catch (_) {
        // If jsonEncode fails, just log the ID
        debugPrint('JSON data (ID only): ${json['_id'] ?? json['id']}');
      }
      // Return a minimal valid Customer to prevent app crash
      return Customer(
        id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
        firstName: json['firstName']?.toString() ?? 'Unknown',
        lastName: json['lastName']?.toString() ?? '',
        isReturning: false,
        orders: [],
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'firstName': firstName,
      'lastName': lastName,
      'isReturning': isReturning,
      'email': email,
      'phone': phone,
      'address': address?.toJson(),
      'createdBy': createdBy?.toJson(),
      'store': store?.toJson(),
      'orders': orders.map((order) => order.toJson()).toList(),
      'note': note,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

class CustomerAddress {
  final String? street;
  final String? city;
  final String? state;
  final String? zipCode;

  CustomerAddress({this.street, this.city, this.state, this.zipCode});

  String get fullAddress {
    final parts = <String>[];
    if (street?.isNotEmpty ?? false) parts.add(street!);
    if (city?.isNotEmpty ?? false) parts.add(city!);
    if (state?.isNotEmpty ?? false) parts.add(state!);
    if (zipCode?.isNotEmpty ?? false) parts.add(zipCode!);
    return parts.isEmpty ? 'N/A' : parts.join(', ');
  }

  factory CustomerAddress.fromJson(Map<String, dynamic> json) {
    return CustomerAddress(
      street: json['street'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      zipCode: json['zipCode'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'street': street, 'city': city, 'state': state, 'zipCode': zipCode};
  }
}

class CustomerCreatedBy {
  final String id;
  final String username;
  final String firstName;
  final String lastName;

  CustomerCreatedBy({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
  });

  factory CustomerCreatedBy.fromJson(Map<String, dynamic> json) {
    return CustomerCreatedBy(
      id: json['_id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      firstName: json['firstName']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'username': username,
      'firstName': firstName,
      'lastName': lastName,
    };
  }
}

class CustomerStore {
  final String id;
  final String name;

  CustomerStore({required this.id, required this.name});

  factory CustomerStore.fromJson(Map<String, dynamic> json) {
    return CustomerStore(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'_id': id, 'name': name};
  }
}

class CustomerOrder {
  final String id;
  final double total;
  final String orderstatus;
  final DateTime createdAt;

  CustomerOrder({
    required this.id,
    required this.total,
    required this.orderstatus,
    required this.createdAt,
  });

  factory CustomerOrder.fromJson(Map<String, dynamic> json) {
    return CustomerOrder(
      id: json['_id']?.toString() ?? '',
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      orderstatus: json['orderstatus']?.toString() ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'total': total,
      'orderstatus': orderstatus,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
