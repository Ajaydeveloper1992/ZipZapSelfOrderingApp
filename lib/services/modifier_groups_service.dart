import 'dart:convert';
import 'package:flutter/foundation.dart' hide Category;
import 'package:zipzap_pos_self_orders/core/constants/api_constants.dart';
import 'package:zipzap_pos_self_orders/core/models/api_response.dart';
import 'package:zipzap_pos_self_orders/core/services/cache_service.dart';
import 'package:zipzap_pos_self_orders/core/services/http_service.dart';
import 'package:zipzap_pos_self_orders/core/services/auth_service.dart';
import 'package:zipzap_pos_self_orders/models/modifier_group_model.dart';
import 'package:zipzap_pos_self_orders/providers/data_provider.dart';

class ModifierGroupsService {
  static final ModifierGroupsService _instance =
      ModifierGroupsService._internal();
  factory ModifierGroupsService() => _instance;
  ModifierGroupsService._internal();

  final HttpService _httpService = HttpService();
  final CacheService _cacheService = CacheService();
  final AuthService _authService = AuthService();

  static const String cacheKeyModifierGroups = 'modifier_groups';
  static const String cacheKeyModifierGroupsTimestamp =
      'modifier_groups_timestamp';

  // Get modifier groups with caching
  Future<ModifierGroupsResponse> getModifierGroups({
    bool forceRefresh = false,
    String? storeId,
  }) async {
    try {
      // Check cache first if not forcing refresh
      if (!forceRefresh) {
        final cachedModifierGroups = await _getCachedModifierGroups();
        final isCacheValid = await _cacheService.isCacheValid(
          cacheKeyModifierGroupsTimestamp,
          ApiConstants.cacheDuration,
        );

        if (cachedModifierGroups != null && isCacheValid) {
          debugPrint('Returning cached modifier groups');
          return cachedModifierGroups;
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
        'limit': '-1', // Get all modifier groups
        'page': '1',
      };
      if (finalStoreId != null) {
        queryParams['store'] = finalStoreId;
      }

      // Make API call
      final response = await _httpService.get(
        ApiConstants.modifierGroups,
        queryParams: queryParams,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint(
          'Modifier groups API response: ${jsonResponse['data']?.length ?? 0} modifier groups',
        );
        final modifierGroupsResponse = ModifierGroupsResponse.fromJson(
          jsonResponse,
        );
        debugPrint(
          'Parsed ${modifierGroupsResponse.modifierGroups.length} modifier groups successfully',
        );

        // Cache the response
        await _cacheModifierGroups(modifierGroupsResponse);
        debugPrint(
          'Cached ${modifierGroupsResponse.modifierGroups.length} modifier groups',
        );

        return modifierGroupsResponse;
      } else {
        throw Exception(
          'Failed to load modifier groups: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching modifier groups: $e');

      // Try to return cached data as fallback
      final cachedModifierGroups = await _getCachedModifierGroups();
      if (cachedModifierGroups != null) {
        debugPrint('Returning cached modifier groups as fallback');
        return cachedModifierGroups;
      }

      rethrow;
    }
  }

  // Get cached modifier groups
  Future<ModifierGroupsResponse?> _getCachedModifierGroups() async {
    try {
      final cachedData = await _cacheService.get<Map<String, dynamic>>(
        cacheKeyModifierGroups,
        (json) => json,
      );

      if (cachedData != null) {
        return ModifierGroupsResponse.fromJson(cachedData);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting cached modifier groups: $e');
      return null;
    }
  }

  // Cache modifier groups
  Future<void> _cacheModifierGroups(
    ModifierGroupsResponse modifierGroupsResponse,
  ) async {
    try {
      final jsonData = <String, dynamic>{
        'data': modifierGroupsResponse.modifierGroups
            .map((mg) => _modifierGroupToJson(mg))
            .toList(),
        if (modifierGroupsResponse.pagination != null)
          'pagination': {
            'currentPage': modifierGroupsResponse.pagination!.currentPage,
            'totalPages': modifierGroupsResponse.pagination!.totalPages,
            'totalItems': modifierGroupsResponse.pagination!.totalItems,
            'itemsPerPage': modifierGroupsResponse.pagination!.itemsPerPage,
            'hasNextPage': modifierGroupsResponse.pagination!.hasNextPage,
            'hasPrevPage': modifierGroupsResponse.pagination!.hasPrevPage,
          },
      };

      final result = await _cacheService.set(
        cacheKeyModifierGroups,
        jsonData,
        (data) => data,
      );

      if (result) {
        debugPrint(
          'Successfully cached ${modifierGroupsResponse.modifierGroups.length} modifier groups',
        );
      } else {
        debugPrint('Failed to cache modifier groups - set() returned false');
      }

      final timestampResult = await _cacheService.setTimestamp(
        cacheKeyModifierGroupsTimestamp,
      );

      if (timestampResult) {
        debugPrint('Successfully cached modifier groups timestamp');
      } else {
        debugPrint('Failed to cache modifier groups timestamp');
      }
    } catch (e, stackTrace) {
      debugPrint('Error caching modifier groups: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  // Convert ModifierGroup to JSON for caching
  Map<String, dynamic> _modifierGroupToJson(ModifierGroup modifierGroup) {
    return {
      '_id': modifierGroup.id,
      'name': modifierGroup.name,
      'description': modifierGroup.description,
      'isActive': modifierGroup.isActive,
      'enabled': modifierGroup.enabled,
      'requiredModifiersCount': modifierGroup.requiredModifiersCount,
      'allowedModifiersCount': modifierGroup.allowedModifiersCount,
      'modifiers': modifierGroup.modifiers
          .map(
            (m) => {
              '_id': m.id,
              'name': m.name,
              'priceAdjustment': m.priceAdjustment,
              'isActive': m.isActive,
            },
          )
          .toList(),
      'products': modifierGroup.products,
      'sortOrder': modifierGroup.sortOrder,
    };
  }

  // Invalidate cache
  void invalidateCache() {
    _cacheService.remove(cacheKeyModifierGroups);
    _cacheService.remove(cacheKeyModifierGroupsTimestamp);
  }
}
