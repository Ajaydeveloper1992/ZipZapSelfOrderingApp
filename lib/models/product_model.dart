import 'package:flutter/foundation.dart' show debugPrint;
import 'package:zipzap_pos_self_orders/core/constants/api_constants.dart';
import 'package:zipzap_pos_self_orders/providers/data_provider.dart';

class Product {
  final String id;
  final String name;
  final String description;
  final String category;
  final List<Map<String, dynamic>>? categories;
  final double price;
  final double salePrice;
  final double posPrice;
  final double posSalePrice;
  final int stockQuantity;
  final int lowStockThreshold;
  final bool trackInventory;
  final bool isAvailable;
  final String status;
  final String type;
  final List<String> images;
  final String? imageUrl;
  final bool taxEnable;
  final TaxRule? taxRule;
  final List<dynamic> modifiers;
  final List<dynamic> modifiersGroup;
  final List<String> labels; // Label IDs
  final int sort;
  final bool showOnPos;
  final bool showOnWeb;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    this.categories,
    required this.price,
    this.salePrice = 0.0,
    required this.posPrice,
    this.posSalePrice = 0.0,
    this.stockQuantity = 0,
    this.lowStockThreshold = 0,
    this.trackInventory = false,
    required this.isAvailable,
    required this.status,
    required this.type,
    required this.images,
    this.imageUrl,
    this.taxEnable = true,
    this.taxRule,
    required this.modifiers,
    required this.modifiersGroup,
    this.labels = const [],
    this.sort = 0,
    this.showOnPos = true,
    this.showOnWeb = true,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    try {
      // Parse categories array if present
      List<Map<String, dynamic>>? categoriesList;
      String categoryId = '';

      // Try to parse categories array (new API format)
      if (json['categories'] != null && json['categories'] is List<dynamic>) {
        final categoriesRaw = json['categories'] as List<dynamic>;
        categoriesList = [];

        for (final cat in categoriesRaw) {
          if (cat is Map<String, dynamic>) {
            categoriesList.add(cat);
          } else if (cat is String) {
            // If it's just an ID string, we can't add it to categoriesList
            // but we can use it as the categoryId
            if (categoryId.isEmpty) {
              categoryId = cat;
            }
          }
        }

        // If we have categories list but no categoryId, use the first category's ID
        if (categoriesList.isNotEmpty && categoryId.isEmpty) {
          categoryId = categoriesList.first['_id'] as String? ?? '';
        }
      }

      // Fallback to category field (old database format)
      if (categoryId.isEmpty && json['category'] != null) {
        if (json['category'] is String) {
          categoryId = json['category'] as String;
        } else if (json['category'] is Map<String, dynamic>) {
          final categoryObj = json['category'] as Map<String, dynamic>;
          categoryId = categoryObj['_id'] as String? ?? '';
        }
      }

      // Handle images - can be images array or mediaFiles array
      List<String> imagesList = [];
      if (json['images'] != null && json['images'] is List<dynamic>) {
        imagesList = (json['images'] as List<dynamic>)
            .map((e) => e?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList();
      } else if (json['mediaFiles'] != null &&
          json['mediaFiles'] is List<dynamic>) {
        imagesList = (json['mediaFiles'] as List<dynamic>)
            .map((e) => e?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList();
      }

      // Parse labels - extract only IDs for efficient storage
      List<String> labelsList = [];
      if (json['labels'] != null && json['labels'] is List<dynamic>) {
        labelsList = (json['labels'] as List<dynamic>)
            .map((e) {
              if (e is Map<String, dynamic>) {
                return e['_id'] as String? ?? '';
              } else if (e is String) {
                return e;
              }
              return '';
            })
            .where((e) => e.isNotEmpty)
            .toList();
      }

      return Product(
        id: json['_id'] as String? ?? '',
        name: json['name'] as String? ?? 'Unnamed Product',
        description: json['description'] as String? ?? '',
        category: categoryId,
        categories: categoriesList,
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        salePrice: (json['salePrice'] as num?)?.toDouble() ?? 0.0,
        posPrice:
            (json['posPrice'] as num?)?.toDouble() ??
            (json['posprice'] as num?)?.toDouble() ??
            (json['price'] as num?)?.toDouble() ??
            0.0,
        posSalePrice: (json['posSalePrice'] as num?)?.toDouble() ?? 0.0,
        stockQuantity: (json['stockQuantity'] as num?)?.toInt() ?? 0,
        lowStockThreshold: (json['lowStockThreshold'] as num?)?.toInt() ?? 0,
        trackInventory: json['trackInventory'] as bool? ?? false,
        isAvailable: json['isAvailable'] as bool? ?? true,
        status: json['status'] as String? ?? 'active',
        type: json['type'] as String? ?? 'food',
        images: imagesList,
        imageUrl: _getImageUrl(json),
        taxEnable: json['taxEnable'] as bool? ?? true,
        taxRule: _resolveTaxRule(json['taxRule']),
        // Handle modifiers - filter out string IDs, keep only Maps
        modifiers: _parseListWithMixedTypes(json['modifiers']),
        modifiersGroup: _parseListWithMixedTypes(
          json['modifierGroups'] ?? json['modifiersgroup'],
        ),
        labels: labelsList,
        sort: (json['sort'] as num?)?.toInt() ?? 0,
        showOnPos: json['showOnPos'] as bool? ?? true,
        showOnWeb: json['showOnWeb'] as bool? ?? true,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Get categories as comma-separated string, with fallback to category field
  String get categoriesDisplay {
    // Use categories array first (new API format)
    if (categories != null && categories!.isNotEmpty) {
      return categories!
          .map((cat) => cat['name'] as String? ?? '')
          .where((name) => name.isNotEmpty)
          .join(', ');
    }
    // Fallback to category field (old database format)
    return category.isNotEmpty ? category : 'N/A';
  }

  /// Returns the effective POS price, preferring posSalePrice when > 0,
  /// otherwise posPrice, with price as the final fallback.
  double get posEffectivePrice {
    if (posSalePrice > 0) return posSalePrice;
    if (posPrice > 0) return posPrice;
    return price;
  }

  Product copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    List<Map<String, dynamic>>? categories,
    double? price,
    double? salePrice,
    double? posPrice,
    double? posSalePrice,
    int? stockQuantity,
    int? lowStockThreshold,
    bool? trackInventory,
    bool? isAvailable,
    String? status,
    String? type,
    List<String>? images,
    String? imageUrl,
    bool? taxEnable,
    TaxRule? taxRule,
    List<dynamic>? modifiers,
    List<dynamic>? modifiersGroup,
    List<String>? labels,
    int? sort,
    bool? showOnPos,
    bool? showOnWeb,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      categories: categories ?? this.categories,
      price: price ?? this.price,
      salePrice: salePrice ?? this.salePrice,
      posPrice: posPrice ?? this.posPrice,
      posSalePrice: posSalePrice ?? this.posSalePrice,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      trackInventory: trackInventory ?? this.trackInventory,
      isAvailable: isAvailable ?? this.isAvailable,
      status: status ?? this.status,
      type: type ?? this.type,
      images: images ?? this.images,
      imageUrl: imageUrl ?? this.imageUrl,
      taxEnable: taxEnable ?? this.taxEnable,
      taxRule: taxRule ?? this.taxRule,
      modifiers: modifiers ?? this.modifiers,
      modifiersGroup: modifiersGroup ?? this.modifiersGroup,
      labels: labels ?? this.labels,
      sort: sort ?? this.sort,
      showOnPos: showOnPos ?? this.showOnPos,
      showOnWeb: showOnWeb ?? this.showOnWeb,
    );
  }

  /// Parse a list that may contain mixed types (Maps and Strings)
  /// Returns only the items that are valid (keeps Maps as-is, converts Strings to simple id Maps)
  static List<dynamic> _parseListWithMixedTypes(dynamic list) {
    if (list == null) return [];
    if (list is! List) return [];

    return list.map((item) {
      if (item is Map<String, dynamic>) {
        return item; // Keep populated objects as-is
      } else if (item is String) {
        // Convert unpopulated ID string to a simple map with just the ID
        return {'_id': item};
      }
      return item;
    }).toList();
  }

  static String? _getImageUrl(Map<String, dynamic> json) {
    // Check if there's an image object with fileUrl
    if (json['image'] != null && json['image'] is Map<String, dynamic>) {
      final imageObj = json['image'] as Map<String, dynamic>;
      final fileUrl = imageObj['fileUrl'] as String?;
      if (fileUrl != null && fileUrl.isNotEmpty) {
        // Extract filename from fileUrl (e.g., "/media/8bfa23f3.jpg" -> "8bfa23f3.jpg")
        final filename = fileUrl.split('/').last;
        // Construct full URL using API base URL
        return '${ApiConstants.baseUrl}/media/$filename';
      }
    }
    return null;
  }

  /// Resolve taxRule from various formats: full Map object, string ID, or null.
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
          '⚠️ Product._resolveTaxRule: Failed to find taxRule with ID "$value" '
          'in ${DataProvider().taxRulesList.length} cached rules',
        );
        return null;
      }
    }
    return null;
  }
}

class TaxRule {
  final String id;
  final String name;
  final String taxClass;
  final double amount;
  final String? taxType;

  TaxRule({
    required this.id,
    required this.name,
    required this.taxClass,
    required this.amount,
    this.taxType,
  });

  factory TaxRule.fromJson(Map<String, dynamic> json) {
    return TaxRule(
      id: json['_id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unknown',
      taxClass: json['taxClass'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      taxType: json['taxType'] as String? ?? json['tax_type'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'taxClass': taxClass,
      'amount': amount,
      if (taxType != null) 'taxType': taxType,
    };
  }
}
