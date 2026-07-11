import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:zipzap_pos_self_orders/core/constants/api_constants.dart';
import 'package:zipzap_pos_self_orders/core/services/http_service.dart';
import 'package:zipzap_pos_self_orders/models/floor_plan_model.dart';

class FloorPlansService {
  static final FloorPlansService _instance = FloorPlansService._internal();
  factory FloorPlansService() => _instance;
  FloorPlansService._internal();

  final HttpService _httpService = HttpService();

  /// Get all floor plans
  Future<FloorPlansResponse> getFloorPlans({
    bool? isActive,
    String? search,
    String? sortBy,
    String? sortOrder,
  }) async {
    try {
      debugPrint('🔄 getFloorPlans called');

      // Build query parameters
      final queryParams = <String, String>{
        'limit': '-1', // Get all floor plans
      };

      if (isActive != null) {
        queryParams['isActive'] = isActive.toString();
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (sortBy != null) {
        queryParams['sortBy'] = sortBy;
      }
      if (sortOrder != null) {
        queryParams['sortOrder'] = sortOrder;
      }

      // Make API call
      final response = await _httpService.get(
        ApiConstants.floorPlans,
        queryParams: queryParams,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final floorPlansResponse = FloorPlansResponse.fromJson(jsonResponse);

        debugPrint(
          '📡 API response received: ${floorPlansResponse.floorPlans.length} floor plans',
        );

        return floorPlansResponse;
      } else {
        throw Exception(
          'Failed to load floor plans: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching floor plans: $e');
      rethrow;
    }
  }

  /// Get floor plan by ID
  Future<FloorPlan> getFloorPlanById(String id) async {
    try {
      debugPrint('🔄 getFloorPlanById called for: $id');

      final response = await _httpService.get('${ApiConstants.floorPlans}/$id');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final success = jsonResponse['success'] as bool? ?? false;

        if (success) {
          final floorPlanData = jsonResponse['data'] as Map<String, dynamic>;
          final floorPlan = FloorPlan.fromJson(floorPlanData);

          debugPrint('📡 Floor plan fetched: ${floorPlan.name}');
          return floorPlan;
        } else {
          final message =
              jsonResponse['message'] as String? ??
              'Failed to fetch floor plan';
          throw Exception(message);
        }
      } else {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
        final message =
            errorBody?['message'] as String? ??
            'Failed to fetch floor plan. Please try again.';
        throw Exception(message);
      }
    } catch (e) {
      debugPrint('Error fetching floor plan: $e');
      rethrow;
    }
  }

  /// Update table status in a floor plan
  Future<FloorPlan> updateTableStatus({
    required String floorPlanId,
    required String tableId,
    required TableStatus status,
  }) async {
    try {
      debugPrint(
        '🔄 updateTableStatus called: $floorPlanId, $tableId -> ${status.value}',
      );

      final response = await _httpService.put(
        '${ApiConstants.floorPlans}/$floorPlanId/table-status',
        body: {'tableId': tableId, 'status': status.value},
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final success = jsonResponse['success'] as bool? ?? false;

        if (success) {
          final floorPlanData = jsonResponse['data'] as Map<String, dynamic>;
          final floorPlan = FloorPlan.fromJson(floorPlanData);

          debugPrint('✅ Table status updated: $tableId -> ${status.value}');
          return floorPlan;
        } else {
          final message =
              jsonResponse['message'] as String? ??
              'Failed to update table status';
          throw Exception(message);
        }
      } else {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
        final message =
            errorBody?['message'] as String? ??
            'Failed to update table status. Please try again.';
        throw Exception(message);
      }
    } catch (e) {
      debugPrint('Error updating table status: $e');
      rethrow;
    }
  }

  /// Shift order to a different table
  Future<void> shiftOrderTable({
    required String orderId,
    required String tableId,
    required String tableName,
    required String floorPlanId,
    int? partySize,
  }) async {
    try {
      debugPrint(
        '🔄 shiftOrderTable called: orderId=$orderId, tableId=$tableId',
      );

      final response = await _httpService.post(
        '${ApiConstants.floorPlans}/shift-table',
        body: {
          'orderId': orderId,
          'tableInfo': {
            'tableId': tableId,
            'tableName': tableName,
            'floorPlanId': floorPlanId,
            if (partySize != null) 'partySize': partySize,
          },
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final success = jsonResponse['success'] as bool? ?? false;

        if (success) {
          debugPrint('✅ Order table shifted: $orderId -> $tableName');
          return;
        } else {
          final message =
              jsonResponse['message'] as String? ?? 'Failed to shift table';
          throw Exception(message);
        }
      } else {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
        final message =
            errorBody?['message'] as String? ??
            'Failed to shift table. Please try again.';
        throw Exception(message);
      }
    } catch (e) {
      debugPrint('Error shifting table: $e');
      rethrow;
    }
  }
}
