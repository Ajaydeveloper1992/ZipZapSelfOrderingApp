import 'dart:convert';
import 'package:flutter/foundation.dart' hide Category;
import 'package:zipzap_pos_self_orders/core/constants/api_constants.dart';
import 'package:zipzap_pos_self_orders/core/models/api_response.dart';
import 'package:zipzap_pos_self_orders/core/services/cache_service.dart';
import 'package:zipzap_pos_self_orders/core/services/http_service.dart';
import 'package:zipzap_pos_self_orders/core/services/auth_service.dart';
import 'package:zipzap_pos_self_orders/models/modifier_group_model.dart';
import 'package:zipzap_pos_self_orders/providers/data_provider.dart';

class ModifiersService {
  static final ModifiersService _instance = ModifiersService._internal();
  factory ModifiersService() => _instance;
  ModifiersService._internal();

  final HttpService _httpService = HttpService();
  final CacheService _cacheService = CacheService();
  final AuthService _authService = AuthService();

  static const String cacheKeyModifiers = 'modifiers';
  static const String cacheKeyModifiersTimestamp = 'modifiers_timestamp';

  // Get modifiers with caching
  Future<ModifiersResponse> getModifiers({
    bool forceRefresh = false,
    String? storeId,
  }) async {
    try {
      // Check cache first if not forcing refresh
      if (!forceRefresh) {
        final cachedModifiers = await _getCachedModifiers();
        final isCacheValid = await _cacheService.isCacheValid(
          cacheKeyModifiersTimestamp,
          ApiConstants.cacheDuration,
        );

        if (cachedModifiers != null && isCacheValid) {
          debugPrint('Returning cached modifiers');
          return cachedModifiers;
        }
      }

      // Get storeId from DataProvider (source of truth) if not provided
      final dataProvider = DataProvider();
      final finalStoreId =
          storeId ??
          dataProvider.store?.id ??
          _authService.getProfile()?.storeId;

      // Build query parameters
      final queryParams = <String, String>{
        'limit': '-1', // Get all modifiers
        'page': '1',
      };
      if (finalStoreId != null) {
        queryParams['store'] = finalStoreId;
      }

      // Make API call
      final response = await _httpService.get(
        ApiConstants.modifiers,
        queryParams: queryParams,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint(
          'Modifiers API response: ${jsonResponse['data']?.length ?? 0} modifiers',
        );
        final modifiersResponse = ModifiersResponse.fromJson(jsonResponse);
        debugPrint(
          'Parsed ${modifiersResponse.modifiers.length} modifiers successfully',
        );

        // Cache the response
        await _cacheModifiers(modifiersResponse);
        debugPrint('Cached ${modifiersResponse.modifiers.length} modifiers');

        return modifiersResponse;
      } else {
        throw Exception(
          'Failed to load modifiers: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching modifiers: $e');

      // Try to return cached data as fallback
      final cachedModifiers = await _getCachedModifiers();
      if (cachedModifiers != null) {
        debugPrint('Returning cached modifiers as fallback');
        return cachedModifiers;
      }

      rethrow;
    }
  }

  // Get cached modifiers
  Future<ModifiersResponse?> _getCachedModifiers() async {
    try {
      final cachedData = await _cacheService.get<Map<String, dynamic>>(
        cacheKeyModifiers,
        (json) => json,
      );

      if (cachedData != null) {
        return ModifiersResponse.fromJson(cachedData);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting cached modifiers: $e');
      return null;
    }
  }

  // Cache modifiers
  Future<void> _cacheModifiers(ModifiersResponse modifiersResponse) async {
    try {
      final jsonData = <String, dynamic>{
        'data': modifiersResponse.modifiers
            .map((m) => _modifierToJson(m))
            .toList(),
        if (modifiersResponse.pagination != null)
          'pagination': {
            'currentPage': modifiersResponse.pagination!.currentPage,
            'totalPages': modifiersResponse.pagination!.totalPages,
            'totalItems': modifiersResponse.pagination!.totalItems,
            'itemsPerPage': modifiersResponse.pagination!.itemsPerPage,
            'hasNextPage': modifiersResponse.pagination!.hasNextPage,
            'hasPrevPage': modifiersResponse.pagination!.hasPrevPage,
          },
      };

      final result = await _cacheService.set(
        cacheKeyModifiers,
        jsonData,
        (data) => data,
      );

      if (result) {
        debugPrint(
          'Successfully cached ${modifiersResponse.modifiers.length} modifiers',
        );
      } else {
        debugPrint('Failed to cache modifiers - set() returned false');
      }

      final timestampResult = await _cacheService.setTimestamp(
        cacheKeyModifiersTimestamp,
      );

      if (timestampResult) {
        debugPrint('Successfully cached modifiers timestamp');
      } else {
        debugPrint('Failed to cache modifiers timestamp');
      }
    } catch (e, stackTrace) {
      debugPrint('Error caching modifiers: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  // Convert Modifier to JSON for caching
  Map<String, dynamic> _modifierToJson(Modifier modifier) {
    return {
      '_id': modifier.id,
      'name': modifier.name,
      'priceAdjustment': modifier.priceAdjustment,
      'isActive': modifier.isActive,
      'modifiersgroup': modifier.modifierGroupId,
      'posEnabled': modifier.posEnabled,
    };
  }

  // Invalidate cache
  void invalidateCache() {
    _cacheService.remove(cacheKeyModifiers);
    _cacheService.remove(cacheKeyModifiersTimestamp);
  }
}
