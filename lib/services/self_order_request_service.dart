import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:zipzap_pos_self_orders/core/constants/api_constants.dart';
import 'package:zipzap_pos_self_orders/core/services/http_service.dart';
import 'package:zipzap_pos_self_orders/models/self_order_request_model.dart';

class SelfOrderRequestService {
  static final SelfOrderRequestService _instance =
      SelfOrderRequestService._internal();
  factory SelfOrderRequestService() => _instance;
  SelfOrderRequestService._internal();

  final HttpService _httpService = HttpService();

  /// Create a new self-order request
  Future<SelfOrderRequest> createRequest(SelfOrderRequest request) async {
    try {
      debugPrint(
        '📤 Creating self-order request for order: ${request.orderNumber}',
      );

      final response = await _httpService.post(
        ApiConstants.selfOrderRequests,
        body: request.toJson(),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;

        // Handle both direct response and nested data
        final requestData = jsonResponse['data'] ?? jsonResponse;
        final createdRequest = SelfOrderRequest.fromJson(requestData);

        debugPrint('✅ Self-order request created: ${createdRequest.id}');
        return createdRequest;
      } else {
        throw Exception(
          'Failed to create request: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error creating self-order request: $e');
      rethrow;
    }
  }

  /// Get all self-order requests (admin/staff)
  Future<SelfOrderRequestsResponse> getRequests({
    int page = 1,
    int limit = 10,
    String? status,
    String? store,
  }) async {
    try {
      debugPrint(
        '🔄 Fetching self-order requests - page: $page, limit: $limit, status: $status',
      );

      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }

      if (store != null && store.isNotEmpty) {
        queryParams['store'] = store;
      }

      final response = await _httpService.get(
        ApiConstants.selfOrderRequests,
        queryParams: queryParams,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final requestsResponse = SelfOrderRequestsResponse.fromJson(
          jsonResponse,
        );

        debugPrint(
          '✅ Fetched ${requestsResponse.requests.length} self-order requests',
        );
        return requestsResponse;
      } else {
        throw Exception(
          'Failed to fetch requests: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error fetching self-order requests: $e');
      rethrow;
    }
  }

  /// Get a single request by ID
  Future<SelfOrderRequest> getRequestById(String requestId) async {
    try {
      debugPrint('🔄 Fetching self-order request: $requestId');

      final response = await _httpService.get(
        '${ApiConstants.selfOrderRequests}/$requestId',
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;

        // Handle both direct response and nested data
        final requestData = jsonResponse['data'] ?? jsonResponse;
        final request = SelfOrderRequest.fromJson(requestData);

        debugPrint('✅ Fetched self-order request: ${request.id}');
        return request;
      } else {
        throw Exception(
          'Failed to fetch request: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error fetching self-order request: $e');
      rethrow;
    }
  }

  /// Update request status (admin/staff)
  Future<SelfOrderRequest> updateRequestStatus(
    String requestId,
    String newStatus,
  ) async {
    try {
      debugPrint('📤 Updating request $requestId status to: $newStatus');

      final response = await _httpService.patch(
        '${ApiConstants.selfOrderRequests}/$requestId/status',
        body: {'status': newStatus},
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;

        // Handle both direct response and nested data
        final requestData = jsonResponse['data'] ?? jsonResponse;
        final updatedRequest = SelfOrderRequest.fromJson(requestData);

        debugPrint('✅ Request status updated to: $newStatus');
        return updatedRequest;
      } else {
        throw Exception(
          'Failed to update request: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error updating request status: $e');
      rethrow;
    }
  }

  /// Get requests for a specific order
  Future<List<SelfOrderRequest>> getRequestsByOrderNumber(
    String orderNumber, {
    String? storeId,
  }) async {
    try {
      debugPrint('🔄 Fetching requests for order: $orderNumber');

      final queryParams = <String, String>{
        'orderNumber': orderNumber,
        'limit': '100', // Get all for this order
      };

      if (storeId != null && storeId.isNotEmpty) {
        queryParams['store'] = storeId;
      }

      final response = await _httpService.get(
        ApiConstants.selfOrderRequests,
        queryParams: queryParams,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;

        // Handle array or paginated response
        if (jsonResponse['data'] is List) {
          final requests = (jsonResponse['data'] as List)
              .map(
                (item) =>
                    SelfOrderRequest.fromJson(item as Map<String, dynamic>),
              )
              .toList();
          debugPrint(
            '✅ Fetched ${requests.length} requests for order $orderNumber',
          );
          return requests;
        } else if (jsonResponse['requests'] is List) {
          final requests = (jsonResponse['requests'] as List)
              .map(
                (item) =>
                    SelfOrderRequest.fromJson(item as Map<String, dynamic>),
              )
              .toList();
          debugPrint(
            '✅ Fetched ${requests.length} requests for order $orderNumber',
          );
          return requests;
        }

        return [];
      } else {
        throw Exception(
          'Failed to fetch requests: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error fetching requests by order: $e');
      rethrow;
    }
  }
}
