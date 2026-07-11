import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:zipzap_pos_self_orders/core/constants/api_constants.dart';
import 'package:zipzap_pos_self_orders/core/services/cache_service.dart';
import 'package:zipzap_pos_self_orders/core/services/http_service.dart';
import 'package:zipzap_pos_self_orders/models/product_model.dart';

class TaxRulesService {
  static final TaxRulesService _instance = TaxRulesService._internal();
  factory TaxRulesService() => _instance;
  TaxRulesService._internal();

  final HttpService _httpService = HttpService();
  final CacheService _cacheService = CacheService();

  // Get tax rules with caching
  Future<TaxRulesResponse> getTaxRules({bool forceRefresh = false}) async {
    try {
      // Check cache first if not forcing refresh
      if (!forceRefresh) {
        final cachedTaxRules = await _getCachedTaxRules();
        final isCacheValid = await _cacheService.isCacheValid(
          ApiConstants.cacheKeyTaxRulesTimestamp,
          ApiConstants.cacheDuration,
        );

        if (cachedTaxRules != null && isCacheValid) {
          debugPrint('Returning cached tax rules');
          return cachedTaxRules;
        }
      }

      // Make API call
      final response = await _httpService.get(ApiConstants.taxRules);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint(
          'Tax Rules API response: ${jsonResponse['data']?.length ?? 0} tax rules',
        );
        final taxRulesResponse = TaxRulesResponse.fromJson(jsonResponse);
        debugPrint(
          'Parsed ${taxRulesResponse.taxRules.length} tax rules successfully',
        );

        // Cache the response
        await _cacheTaxRules(taxRulesResponse);
        debugPrint('Cached ${taxRulesResponse.taxRules.length} tax rules');

        return taxRulesResponse;
      } else {
        throw Exception(
          'Failed to load tax rules: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching tax rules: $e');

      // Try to return cached data as fallback
      final cachedTaxRules = await _getCachedTaxRules();
      if (cachedTaxRules != null) {
        debugPrint('Returning cached tax rules as fallback');
        return cachedTaxRules;
      }

      rethrow;
    }
  }

  // Get cached tax rules
  Future<TaxRulesResponse?> _getCachedTaxRules() async {
    try {
      final cachedData = await _cacheService.get<Map<String, dynamic>>(
        ApiConstants.cacheKeyTaxRules,
        (json) => json,
      );

      if (cachedData != null) {
        return TaxRulesResponse.fromJson(cachedData);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting cached tax rules: $e');
      return null;
    }
  }

  // Cache tax rules
  Future<void> _cacheTaxRules(TaxRulesResponse taxRulesResponse) async {
    try {
      final jsonData = <String, dynamic>{
        'data': taxRulesResponse.taxRules
            .map((t) => _taxRuleToJson(t))
            .toList(),
      };

      final result = await _cacheService.set(
        ApiConstants.cacheKeyTaxRules,
        jsonData,
        (data) => data,
      );

      if (result) {
        debugPrint(
          'Successfully cached ${taxRulesResponse.taxRules.length} tax rules',
        );
      } else {
        debugPrint('Failed to cache tax rules - set() returned false');
      }

      final timestampResult = await _cacheService.setTimestamp(
        ApiConstants.cacheKeyTaxRulesTimestamp,
      );

      if (timestampResult) {
        debugPrint('Successfully cached tax rules timestamp');
      } else {
        debugPrint('Failed to cache tax rules timestamp');
      }
    } catch (e, stackTrace) {
      debugPrint('Error caching tax rules: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  // Convert TaxRule to JSON for caching
  Map<String, dynamic> _taxRuleToJson(TaxRule taxRule) {
    return {
      '_id': taxRule.id,
      'name': taxRule.name,
      'taxClass': taxRule.taxClass,
      'amount': taxRule.amount,
      'taxType': taxRule.taxType,
    };
  }

  // Invalidate cache
  void invalidateCache() {
    _cacheService.remove(ApiConstants.cacheKeyTaxRules);
    _cacheService.remove(ApiConstants.cacheKeyTaxRulesTimestamp);
  }
}

// Response model for tax rules API
class TaxRulesResponse {
  final List<TaxRule> taxRules;
  final bool success;
  final String? message;

  TaxRulesResponse({required this.taxRules, this.success = true, this.message});

  factory TaxRulesResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    List<TaxRule> taxRules = [];

    if (data is List) {
      taxRules = data
          .map((item) => TaxRule.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return TaxRulesResponse(
      taxRules: taxRules,
      success: json['success'] as bool? ?? true,
      message: json['message'] as String?,
    );
  }
}
