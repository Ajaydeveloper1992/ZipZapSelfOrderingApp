import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:zipzap_pos_self_orders/core/constants/api_constants.dart';
import 'package:zipzap_pos_self_orders/core/models/api_response.dart';
import 'package:zipzap_pos_self_orders/core/services/auth_service.dart';
import 'package:zipzap_pos_self_orders/core/services/cache_service.dart';
import 'package:zipzap_pos_self_orders/core/services/http_service.dart';
import 'package:zipzap_pos_self_orders/models/product_model.dart';
import 'package:zipzap_pos_self_orders/providers/data_provider.dart';

class ProductsService {
  static final ProductsService _instance = ProductsService._internal();
  factory ProductsService() => _instance;
  ProductsService._internal();

  final HttpService _httpService = HttpService();
  final CacheService _cacheService = CacheService();
  final AuthService _authService = AuthService();

  static const String cacheKeyProducts = 'products';
  static const String cacheKeyProductsTimestamp = 'products_timestamp';

  // Get products with caching
  Future<ProductsResponse> getProducts({
    bool forceRefresh = false,
    String? storeId,
  }) async {
    try {
      // Check cache first if not forcing refresh
      if (!forceRefresh) {
        final cachedProducts = await _getCachedProducts();
        final isCacheValid = await _cacheService.isCacheValid(
          cacheKeyProductsTimestamp,
          ApiConstants.cacheDuration,
        );

        if (cachedProducts != null && isCacheValid) {
          debugPrint(
            'Returning cached products: ${cachedProducts.products.length} items',
          );
          return cachedProducts;
        }
      }

      // Get storeId from DataProvider (source of truth) if not provided
      final dataProvider = DataProvider();
      final effectiveStoreId =
          storeId ??
          dataProvider.store?.id ??
          _authService.getProfile()?.storeId;

      // Build query parameters
      final queryParams = <String, String>{
        'limit': '-1', // Get all products
      };
      if (effectiveStoreId != null) {
        queryParams['store'] = effectiveStoreId;
      }

      // Make API call
      final response = await _httpService.get(
        ApiConstants.products,
        queryParams: queryParams,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final productsResponse = ProductsResponse.fromJson(jsonResponse);

        debugPrint('API returned ${productsResponse.products.length} products');

        // Cache the response
        await _cacheProducts(productsResponse);

        return productsResponse;
      } else {
        throw Exception(
          'Failed to load products: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching products: $e');

      // Try to return cached data as fallback
      final cachedProducts = await _getCachedProducts();
      if (cachedProducts != null) {
        debugPrint(
          'Returning cached products as fallback: ${cachedProducts.products.length} items',
        );
        return cachedProducts;
      }

      rethrow;
    }
  }

  // Get cached products
  Future<ProductsResponse?> _getCachedProducts() async {
    try {
      final cachedData = await _cacheService.get<Map<String, dynamic>>(
        cacheKeyProducts,
        (json) => json,
      );

      if (cachedData != null) {
        return ProductsResponse.fromJson(cachedData);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting cached products: $e');
      return null;
    }
  }

  // Cache products
  Future<void> _cacheProducts(ProductsResponse productsResponse) async {
    try {
      final jsonData = <String, dynamic>{
        'data': productsResponse.products
            .map((p) => _productToJson(p))
            .toList(),
        if (productsResponse.pagination != null)
          'pagination': {
            'currentPage': productsResponse.pagination!.currentPage,
            'totalPages': productsResponse.pagination!.totalPages,
            'totalItems': productsResponse.pagination!.totalItems,
            'itemsPerPage': productsResponse.pagination!.itemsPerPage,
            'hasNextPage': productsResponse.pagination!.hasNextPage,
            'hasPrevPage': productsResponse.pagination!.hasPrevPage,
          },
      };

      await _cacheService.set(cacheKeyProducts, jsonData, (data) => data);

      await _cacheService.setTimestamp(cacheKeyProductsTimestamp);
    } catch (e) {
      debugPrint('Error caching products: $e');
    }
  }

  // Convert Product to JSON for caching
  Map<String, dynamic> _productToJson(Product product) {
    return {
      '_id': product.id,
      'name': product.name,
      'description': product.description,
      'category': product.category,
      'price': product.price,
      'salePrice': product.salePrice,
      'posPrice': product.posPrice,
      'posSalePrice': product.posSalePrice,
      'stockQuantity': product.stockQuantity,
      'lowStockThreshold': product.lowStockThreshold,
      'trackInventory': product.trackInventory,
      'isAvailable': product.isAvailable,
      'status': product.status,
      'type': product.type,
      'images': product.images,
      'modifiers': product.modifiers,
      'modifierGroups': product.modifiersGroup,
      'showOnPos': product.showOnPos,
      'showOnWeb': product.showOnWeb,
      'taxEnable': product.taxEnable,
      'taxRule': product.taxRule != null
          ? {
              '_id': product.taxRule!.id,
              'name': product.taxRule!.name,
              'taxClass': product.taxRule!.taxClass,
              'amount': product.taxRule!.amount,
              'taxType': product.taxRule!.taxType,
            }
          : null,
      'labels': product.labels,
    };
  }

  // Update a product (partial update)
  Future<Product> updateProduct({
    required String productId,
    bool? showOnPos,
    bool? showOnWeb,
    bool? isAvailable,
    String? name,
    String? description,
    double? price,
    double? posPrice,
  }) async {
    try {
      if (productId.isEmpty) {
        throw Exception('Product ID is required');
      }

      // Build request body with only provided fields
      final body = <String, dynamic>{};
      if (showOnPos != null) body['showOnPos'] = showOnPos;
      if (showOnWeb != null) body['showOnWeb'] = showOnWeb;
      if (isAvailable != null) body['isAvailable'] = isAvailable;
      if (name != null && name.isNotEmpty) body['name'] = name;
      if (description != null) body['description'] = description;
      if (price != null) body['price'] = price;
      if (posPrice != null) body['posPrice'] = posPrice;

      final response = await _httpService.put(
        '/products/$productId',
        body: body,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final success = jsonResponse['success'] as bool? ?? false;

        if (success) {
          final productData = jsonResponse['data'] as Map<String, dynamic>;
          final product = Product.fromJson(productData);

          // Invalidate cache to force refresh on next fetch
          invalidateCache();

          debugPrint('Product updated successfully: ${product.id}');
          return product;
        } else {
          final message =
              jsonResponse['message'] as String? ?? 'Failed to update product';
          throw Exception(message);
        }
      } else {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
        final message =
            errorBody?['message'] as String? ??
            'Failed to update product. Please try again.';
        throw Exception(message);
      }
    } catch (e) {
      debugPrint('Error updating product: $e');
      rethrow;
    }
  }

  // Invalidate cache
  void invalidateCache() {
    _cacheService.remove(cacheKeyProducts);
    _cacheService.remove(cacheKeyProductsTimestamp);
  }
}
