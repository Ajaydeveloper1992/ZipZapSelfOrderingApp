import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:zipzap_pos_self_orders/core/constants/api_constants.dart';
import 'package:zipzap_pos_self_orders/core/services/auth_service.dart';
import 'package:zipzap_pos_self_orders/core/services/cache_service.dart';
import 'package:zipzap_pos_self_orders/core/services/http_service.dart';
import 'package:zipzap_pos_self_orders/models/printer_label_model.dart';
import 'package:zipzap_pos_self_orders/providers/data_provider.dart';

class LabelsResponse {
  final List<PrinterLabel> labels;

  LabelsResponse({required this.labels});

  factory LabelsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as List<dynamic>? ?? [];
    return LabelsResponse(
      labels: data.map((item) => PrinterLabel.fromJson(item)).toList(),
    );
  }
}

class LabelsService {
  static final LabelsService _instance = LabelsService._internal();
  factory LabelsService() => _instance;
  LabelsService._internal();

  final HttpService _httpService = HttpService();
  final CacheService _cacheService = CacheService();
  final AuthService _authService = AuthService();

  // Get labels with caching
  Future<LabelsResponse> getLabels({
    bool forceRefresh = false,
    String? storeId,
  }) async {
    try {
      debugPrint('🔄 getLabels called. forceRefresh: $forceRefresh');

      // Check cache first if not forcing refresh
      if (!forceRefresh) {
        final cachedLabels = await _getCachedLabels();
        final isCacheValid = await _cacheService.isCacheValid(
          ApiConstants.cacheKeyLabelsTimestamp,
          ApiConstants.cacheDuration,
        );

        if (cachedLabels != null && isCacheValid) {
          debugPrint(
            '✅ Returning cached labels (${cachedLabels.labels.length} labels)',
          );
          return cachedLabels;
        } else {
          debugPrint('⚠️ Cache miss or invalid. Will fetch from API.');
        }
      } else {
        debugPrint('🔄 Force refresh enabled, skipping cache check');
      }

      // Get storeId from DataProvider (source of truth) if not provided
      final dataProvider = DataProvider();
      final effectiveStoreId =
          storeId ??
          dataProvider.store?.id ??
          _authService.getProfile()?.storeId;

      // Build query parameters
      final queryParams = <String, String>{};
      if (effectiveStoreId != null) {
        queryParams['store'] = effectiveStoreId;
      }

      // Make API call
      final response = await _httpService.get(
        ApiConstants.labels,
        queryParams: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final labelsResponse = LabelsResponse.fromJson(jsonResponse);

        debugPrint(
          '📡 API response received: ${labelsResponse.labels.length} labels',
        );

        // Cache the response
        await _cacheLabels(labelsResponse);
        debugPrint('💾 API response cached');

        return labelsResponse;
      } else {
        throw Exception(
          'Failed to load labels: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error fetching labels: $e');

      // Try to return cached data as fallback
      final cachedLabels = await _getCachedLabels();
      if (cachedLabels != null) {
        debugPrint('Returning cached labels as fallback');
        return cachedLabels;
      }

      rethrow;
    }
  }

  // Get cached labels
  Future<LabelsResponse?> _getCachedLabels() async {
    try {
      final cachedData = await _cacheService.get<Map<String, dynamic>>(
        ApiConstants.cacheKeyLabels,
        (json) => json,
      );

      if (cachedData != null) {
        return LabelsResponse.fromJson(cachedData);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting cached labels: $e');
      return null;
    }
  }

  // Cache labels
  Future<void> _cacheLabels(LabelsResponse labelsResponse) async {
    try {
      final jsonData = <String, dynamic>{
        'data': labelsResponse.labels.map((label) => label.toJson()).toList(),
      };

      await _cacheService.set(
        ApiConstants.cacheKeyLabels,
        jsonData,
        (data) => data,
      );

      await _cacheService.setTimestamp(ApiConstants.cacheKeyLabelsTimestamp);

      debugPrint(
        '💾 Successfully cached ${labelsResponse.labels.length} labels',
      );
    } catch (e) {
      debugPrint('❌ Error caching labels: $e');
    }
  }

  // Invalidate cache
  Future<void> invalidateCache() async {
    await _cacheService.remove(ApiConstants.cacheKeyLabels);
    await _cacheService.remove(ApiConstants.cacheKeyLabelsTimestamp);
  }

  // Refresh labels (force API call)
  Future<LabelsResponse> refreshLabels() async {
    return getLabels(forceRefresh: true);
  }
}
