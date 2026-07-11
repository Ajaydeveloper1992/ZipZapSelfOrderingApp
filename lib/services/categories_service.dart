import 'dart:convert';
import 'package:flutter/foundation.dart' hide Category;
import 'package:zipzap_pos_self_orders/core/constants/api_constants.dart';
import 'package:zipzap_pos_self_orders/core/models/api_response.dart';
import 'package:zipzap_pos_self_orders/core/services/auth_service.dart';
import 'package:zipzap_pos_self_orders/core/services/cache_service.dart';
import 'package:zipzap_pos_self_orders/core/services/http_service.dart';
import 'package:zipzap_pos_self_orders/models/category_model.dart';
import 'package:zipzap_pos_self_orders/providers/data_provider.dart';

class CategoriesService {
  static final CategoriesService _instance = CategoriesService._internal();
  factory CategoriesService() => _instance;
  CategoriesService._internal();

  final HttpService _httpService = HttpService();
  final CacheService _cacheService = CacheService();
  final AuthService _authService = AuthService();

  static const String cacheKeyCategories = 'categories';
  static const String cacheKeyCategoriesTimestamp = 'categories_timestamp';

  // Get categories with caching
  Future<CategoriesResponse> getCategories({
    bool forceRefresh = false,
    String? storeId,
  }) async {
    try {
      // Check cache first if not forcing refresh
      if (!forceRefresh) {
        final cachedCategories = await _getCachedCategories();
        final isCacheValid = await _cacheService.isCacheValid(
          cacheKeyCategoriesTimestamp,
          ApiConstants.cacheDuration,
        );

        if (cachedCategories != null && isCacheValid) {
          debugPrint('Returning cached categories');
          return cachedCategories;
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
        'limit': '-1', // Get all categories
      };
      if (effectiveStoreId != null) {
        queryParams['store'] = effectiveStoreId;
      }

      // Make API call
      final response = await _httpService.get(
        ApiConstants.categories,
        queryParams: queryParams,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final categoriesResponse = CategoriesResponse.fromJson(jsonResponse);

        // Cache the response
        await _cacheCategories(categoriesResponse);

        return categoriesResponse;
      } else {
        throw Exception(
          'Failed to load categories: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');

      // Try to return cached data as fallback
      final cachedCategories = await _getCachedCategories();
      if (cachedCategories != null) {
        debugPrint('Returning cached categories as fallback');
        return cachedCategories;
      }

      rethrow;
    }
  }

  // Get cached categories
  Future<CategoriesResponse?> _getCachedCategories() async {
    try {
      final cachedData = await _cacheService.get<Map<String, dynamic>>(
        cacheKeyCategories,
        (json) => json,
      );

      if (cachedData != null) {
        return CategoriesResponse.fromJson(cachedData);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting cached categories: $e');
      return null;
    }
  }

  // Cache categories
  Future<void> _cacheCategories(CategoriesResponse categoriesResponse) async {
    try {
      final jsonData = <String, dynamic>{
        'data': categoriesResponse.categories
            .map((c) => _categoryToJson(c))
            .toList(),
        if (categoriesResponse.pagination != null)
          'pagination': {
            'currentPage': categoriesResponse.pagination!.currentPage,
            'totalPages': categoriesResponse.pagination!.totalPages,
            'totalItems': categoriesResponse.pagination!.totalItems,
            'itemsPerPage': categoriesResponse.pagination!.itemsPerPage,
            'hasNextPage': categoriesResponse.pagination!.hasNextPage,
            'hasPrevPage': categoriesResponse.pagination!.hasPrevPage,
          },
      };

      await _cacheService.set(cacheKeyCategories, jsonData, (data) => data);

      await _cacheService.setTimestamp(cacheKeyCategoriesTimestamp);
    } catch (e) {
      debugPrint('Error caching categories: $e');
    }
  }

  // Convert Category to JSON for caching
  Map<String, dynamic> _categoryToJson(Category category) {
    return {
      '_id': category.id,
      'name': category.name,
      'slug': category.slug,
      'isActive': category.isActive,
      'showOnPos': category.showOnPos,
      'sortOrder': category.sortOrder,
    };
  }

  // Public method to cache categories data (used by DataProvider for optimistic updates)
  Future<void> cacheCategoriesData(
    CategoriesResponse categoriesResponse,
  ) async {
    await _cacheCategories(categoriesResponse);
  }

  // Update a category (partial update)
  Future<Category> updateCategory({
    required String categoryId,
    bool? showOnPos,
    bool? showOnWeb,
    bool? isActive,
    String? name,
    String? slug,
    String? description,
    int? sortOrder,
  }) async {
    try {
      if (categoryId.isEmpty) {
        throw Exception('Category ID is required');
      }

      // Build request body with only provided fields
      final body = <String, dynamic>{};
      if (showOnPos != null) body['showOnPos'] = showOnPos;
      if (showOnWeb != null) body['showOnWeb'] = showOnWeb;
      if (isActive != null) body['isActive'] = isActive;
      if (name != null && name.isNotEmpty) body['name'] = name;
      if (slug != null && slug.isNotEmpty) body['slug'] = slug;
      if (description != null) body['description'] = description;
      if (sortOrder != null) body['sortOrder'] = sortOrder;

      final response = await _httpService.put(
        '${ApiConstants.categories}/$categoryId',
        body: body,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final success = jsonResponse['success'] as bool? ?? false;

        if (success) {
          final categoryData = jsonResponse['data'] as Map<String, dynamic>;
          final category = Category.fromJson(categoryData);

          // Invalidate cache to force refresh on next fetch
          invalidateCache();

          debugPrint('Category updated successfully: ${category.id}');
          return category;
        } else {
          final message =
              jsonResponse['message'] as String? ?? 'Failed to update category';
          throw Exception(message);
        }
      } else {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
        final message =
            errorBody?['message'] as String? ??
            'Failed to update category. Please try again.';
        throw Exception(message);
      }
    } catch (e) {
      debugPrint('Error updating category: $e');
      rethrow;
    }
  }

  // Invalidate cache
  void invalidateCache() {
    _cacheService.remove(cacheKeyCategories);
    _cacheService.remove(cacheKeyCategoriesTimestamp);
  }
}
