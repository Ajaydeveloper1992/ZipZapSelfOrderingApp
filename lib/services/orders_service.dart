import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:zipzap_pos_self_orders/core/constants/api_constants.dart';
import 'package:zipzap_pos_self_orders/core/models/api_response.dart';
import 'package:zipzap_pos_self_orders/core/services/cache_service.dart';
import 'package:zipzap_pos_self_orders/core/services/http_service.dart';
import 'package:zipzap_pos_self_orders/models/order_model.dart';
import 'package:zipzap_pos_self_orders/utils/timezone_utils.dart';

class OrdersService {
  static final OrdersService _instance = OrdersService._internal();
  factory OrdersService() => _instance;
  OrdersService._internal();

  final HttpService _httpService = HttpService();
  final CacheService _cacheService = CacheService();

  // Get takeout orders with caching
  Future<OrdersResponse> getTakeoutOrders({
    bool forceRefresh = false,
    int page = 1,
    List<String>? orderstatuses,
  }) async {
    try {
      debugPrint('🔄 getTakeoutOrders called. forceRefresh: $forceRefresh');

      // Check cache first if not forcing refresh
      if (!forceRefresh) {
        final cachedOrders = await _getCachedTakeoutOrders();
        final isCacheValid = await _cacheService.isCacheValid(
          ApiConstants.cacheKeyTakeoutOrdersTimestamp,
          ApiConstants.cacheDuration,
        );

        debugPrint(
          '📦 Cache check: cachedOrders count: ${cachedOrders?.orders.length ?? 0}, isCacheValid: $isCacheValid',
        );

        if (cachedOrders != null && isCacheValid) {
          debugPrint(
            '✅ Returning cached takeout orders (${cachedOrders.orders.length} orders)',
          );
          if (cachedOrders.orders.isNotEmpty) {
            debugPrint(
              '✅ First 3 cached order numbers: ${cachedOrders.orders.take(3).map((o) => o.orderNumber).join(", ")}',
            );
          }
          return cachedOrders;
        } else {
          debugPrint('⚠️ Cache miss or invalid. Will fetch from API.');
        }
      } else {
        debugPrint('🔄 Force refresh enabled, skipping cache check');
      }

      // Build query parameters
      final queryParams = <String, String>{
        ApiConstants.orderTypeParam: ApiConstants.orderTypePickup,
        'limit': '-1', // Get all orders
      };

      if (orderstatuses != null && orderstatuses.isNotEmpty) {
        queryParams[ApiConstants.orderStatusParam] = orderstatuses.join(',');
      } else {
        // Default to Pending and InKitchen
        queryParams[ApiConstants.orderStatusParam] =
            '${ApiConstants.orderStatusPending},${ApiConstants.orderStatusInKitchen}';
      }

      // Make API call
      final response = await _httpService.get(
        ApiConstants.orders,
        queryParams: queryParams,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final ordersResponse = OrdersResponse.fromJson(jsonResponse);

        debugPrint(
          '📡 API response received: ${ordersResponse.orders.length} orders',
        );
        if (ordersResponse.orders.isNotEmpty) {
          debugPrint(
            '📡 First 3 API order numbers: ${ordersResponse.orders.take(3).map((o) => o.orderNumber).join(", ")}',
          );
        }

        // Cache the response
        await _cacheTakeoutOrders(ordersResponse);
        debugPrint('💾 API response cached');

        return ordersResponse;
      } else {
        throw Exception(
          'Failed to load orders: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching takeout orders: $e');

      // Try to return cached data as fallback
      final cachedOrders = await _getCachedTakeoutOrders();
      if (cachedOrders != null) {
        debugPrint('Returning cached orders as fallback');
        return cachedOrders;
      }

      rethrow;
    }
  }

  // Get cached takeout orders
  Future<OrdersResponse?> _getCachedTakeoutOrders() async {
    try {
      debugPrint('🔍 _getCachedTakeoutOrders: Reading from cache...');
      final cachedData = await _cacheService.get<Map<String, dynamic>>(
        ApiConstants.cacheKeyTakeoutOrders,
        (json) => json,
      );

      if (cachedData != null) {
        debugPrint('🔍 _getCachedTakeoutOrders: Raw cache data found');
        final response = OrdersResponse.fromJson(cachedData);
        debugPrint(
          '🔍 _getCachedTakeoutOrders: Parsed ${response.orders.length} orders from cache',
        );
        return response;
      }
      debugPrint('🔍 _getCachedTakeoutOrders: No cache data found');
      return null;
    } catch (e) {
      debugPrint('❌ Error getting cached takeout orders: $e');
      return null;
    }
  }

  // Cache takeout orders
  Future<void> _cacheTakeoutOrders(OrdersResponse ordersResponse) async {
    try {
      debugPrint(
        '💾 _cacheTakeoutOrders: Caching ${ordersResponse.orders.length} orders',
      );

      final jsonData = <String, dynamic>{
        'data': ordersResponse.orders
            .map((order) => _orderToJson(order))
            .toList(),
        if (ordersResponse.pagination != null)
          'pagination': {
            'currentPage': ordersResponse.pagination!.currentPage,
            'totalPages': ordersResponse.pagination!.totalPages,
            'totalItems': ordersResponse.pagination!.totalItems,
            'itemsPerPage': ordersResponse.pagination!.itemsPerPage,
            'hasNextPage': ordersResponse.pagination!.hasNextPage,
            'hasPrevPage': ordersResponse.pagination!.hasPrevPage,
          },
        if (ordersResponse.stats != null)
          'stats': {
            'all': ordersResponse.stats!.all,
            'Pending': ordersResponse.stats!.pending,
            'InKitchen': ordersResponse.stats!.inKitchen,
            'Complete': ordersResponse.stats!.complete,
            'Voided': ordersResponse.stats!.voided,
            'Rejected': ordersResponse.stats!.rejected,
            'Refunded': ordersResponse.stats!.refunded,
            'Partially Refunded': ordersResponse.stats!.partiallyRefunded,
          },
      };

      debugPrint(
        '💾 _cacheTakeoutOrders: JSON data prepared with ${(jsonData['data'] as List).length} orders',
      );

      await _cacheService.set(
        ApiConstants.cacheKeyTakeoutOrders,
        jsonData,
        (data) => data,
      );

      await _cacheService.setTimestamp(
        ApiConstants.cacheKeyTakeoutOrdersTimestamp,
      );

      debugPrint('💾 _cacheTakeoutOrders: Successfully saved to cache');
    } catch (e) {
      debugPrint('❌ Error caching takeout orders: $e');
    }
  }

  // Convert Order to JSON for caching
  Map<String, dynamic> _orderToJson(Order order) {
    return {
      '_id': order.id,
      'orderNumber': order.orderNumber,
      'store': order.store != null
          ? {'_id': order.store!.id, 'name': order.store!.name}
          : null,
      'customer': order.customer != null
          ? {
              '_id': order.customer!.id,
              'firstName': order.customer!.firstName,
              'lastName': order.customer!.lastName,
              'phone': order.customer!.phone,
            }
          : null,
      'orderType': order.orderType,
      'origin': order.origin,
      'paymentStatus': order.paymentStatus,
      'subtotal': order.subtotal,
      'total': order.total,
      'tip': order.tip,
      'tax': order.tax,
      'totalRefund': order.totalRefund,
      'orderstatus': order.orderstatus,
      'items': order.items.map((item) {
        return {
          '_id': item.id,
          'item': item.item != null
              ? {
                  '_id': item.item!.id,
                  'name': item.item!.name,
                  'price': item.item!.price,
                }
              : null,
          'customItem': item.customItem,
          'quantity': item.quantity,
          'price': item.price,
          'modifiers': item.modifiers.map((mod) {
            return {'_id': mod.id, 'name': mod.name};
          }).toList(),
          'itemNote': item.itemNote,
          'itemStatus': item.itemStatus,
          'refundQuantity': item.refundQuantity,
          'voidQuantity': item.voidQuantity,
          'voidReason': item.voidReason,
          'taxEnable': item.taxEnable,
          if (item.taxRule != null) 'taxRule': item.taxRule!.toJson(),
        };
      }).toList(),
      'prePaid': order.prePaid,
      'date': order.date,
      'payments': order.payments.map((payment) {
        return {
          'method': payment.method,
          'amount': payment.amount,
          'refund': payment.refund,
          'status': payment.status,
        };
      }).toList(),
      'pickupInfo': order.pickupInfo != null
          ? {
              'orderType': order.pickupInfo!.orderType,
              'pickupTime': TimezoneUtils.toUtcIsoString(
                order.pickupInfo!.pickupTime,
              ),
              'delayTime': TimezoneUtils.toUtcIsoString(
                order.pickupInfo!.delayTime,
              ),
            }
          : null,
      'updatedAt': order.updatedAt,
    };
  }

  // Update a single order in cache (optimized for quick UI updates)
  Future<void> updateOrderInCache(Order updatedOrder) async {
    try {
      // Update in takeout orders list cache
      final cachedOrders = await _getCachedTakeoutOrders();
      if (cachedOrders != null) {
        // Find and update the order in the list
        final orderIndex = cachedOrders.orders.indexWhere(
          (order) => order.id == updatedOrder.id,
        );

        if (orderIndex != -1) {
          // Update the order
          cachedOrders.orders[orderIndex] = updatedOrder;

          // Save back to cache
          await _cacheTakeoutOrders(cachedOrders);
        }
      }

      // Also update the order details cache
      await _cacheOrderDetails(updatedOrder.id, updatedOrder);
    } catch (e) {
      debugPrint('Error updating order in cache: $e');
    }
  }

  // Add a new order to cache (optimistic update for newly created orders)
  Future<void> addOrderToCache(
    Order newOrder, {
    List<Order>? existingOrders,
  }) async {
    try {
      debugPrint(
        '📥 addOrderToCache called for order: ${newOrder.orderNumber}',
      );

      // Get current cached orders
      final cachedOrders = await _getCachedTakeoutOrders();

      debugPrint(
        '📦 Current cached orders count: ${cachedOrders?.orders.length ?? 0}',
      );
      if (cachedOrders != null && cachedOrders.orders.isNotEmpty) {
        debugPrint(
          '📦 First 3 cached order numbers: ${cachedOrders.orders.take(3).map((o) => o.orderNumber).join(", ")}',
        );
      }

      List<Order> baseOrders;
      if (cachedOrders != null && cachedOrders.orders.isNotEmpty) {
        baseOrders = List<Order>.from(cachedOrders.orders);
      } else if (existingOrders != null && existingOrders.isNotEmpty) {
        baseOrders = List<Order>.from(existingOrders);
      } else {
        baseOrders = [];
      }

      List<Order> updatedOrdersList;

      if (baseOrders.isEmpty) {
        // If no cache exists, create a list with just this order
        updatedOrdersList = [newOrder];
        debugPrint(
          '🆕 No cached orders found, creating new cache with order: ${newOrder.orderNumber}',
        );
      } else {
        // Check if order already exists (avoid duplicates)
        final existingIndex = baseOrders.indexWhere(
          (order) => order.id == newOrder.id,
        );

        debugPrint('🔍 Checking if order exists. Index: $existingIndex');

        if (existingIndex == -1) {
          // Create a NEW list with the new order at the beginning + all existing orders
          final existingWithoutNew = baseOrders
              .where((order) => order.id != newOrder.id)
              .toList();
          updatedOrdersList = [newOrder, ...existingWithoutNew];
          debugPrint(
            '✅ New order added to cache: ${newOrder.orderNumber} (Total orders: ${updatedOrdersList.length})',
          );
          debugPrint(
            '✅ First 3 order numbers after adding: ${updatedOrdersList.take(3).map((o) => o.orderNumber).join(", ")}',
          );
        } else {
          // Order already exists, create a new list with the updated order
          updatedOrdersList = List<Order>.from(baseOrders);
          updatedOrdersList[existingIndex] = newOrder;
          debugPrint(
            '🔄 Order already in cache, updated: ${newOrder.orderNumber} (Total orders: ${updatedOrdersList.length})',
          );
        }
      }

      // Create a new OrdersResponse with the updated list
      final updatedResponse = OrdersResponse(
        orders: updatedOrdersList,
        pagination: cachedOrders?.pagination,
      );

      debugPrint(
        '💾 About to save to cache. Orders count: ${updatedOrdersList.length}',
      );

      // Save to cache
      await _cacheTakeoutOrders(updatedResponse);

      debugPrint(
        '✅ Cache updated successfully. Total orders in cache: ${updatedOrdersList.length}',
      );

      // Verify the cache was saved correctly
      final verifyCache = await _getCachedTakeoutOrders();
      debugPrint(
        '🔍 Verification: Orders in cache after save: ${verifyCache?.orders.length ?? 0}',
      );
      if (verifyCache != null && verifyCache.orders.isNotEmpty) {
        debugPrint(
          '🔍 Verification: First 3 order numbers: ${verifyCache.orders.take(3).map((o) => o.orderNumber).join(", ")}',
        );
      }
    } catch (e) {
      debugPrint('❌ Error adding order to cache: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
    }
  }

  // Invalidate cache (call this when orders are updated via websocket)
  Future<void> invalidateCache() async {
    await _cacheService.remove(ApiConstants.cacheKeyTakeoutOrders);
    await _cacheService.remove(ApiConstants.cacheKeyTakeoutOrdersTimestamp);
  }

  // Refresh orders (force API call)
  Future<OrdersResponse> refreshTakeoutOrders({
    List<String>? orderstatuses,
  }) async {
    return getTakeoutOrders(forceRefresh: true, orderstatuses: orderstatuses);
  }

  // Get all orders with server-side filtering (for orders page)
  Future<OrdersResponse> getAllOrders({
    String? sortBy,
    String? sortOrder,
    String? search,
    String? orderType,
    String? orderstatus,
    String? paymentStatus,
    String? origin,
    String? store,
    String? customer,
    DateTime? dateFrom,
    DateTime? dateTo,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      // Build query parameters
      final queryParams = <String, String>{};

      if (sortBy != null) queryParams['sortBy'] = sortBy;
      if (sortOrder != null) queryParams['sortOrder'] = sortOrder;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (orderType != null) queryParams['orderType'] = orderType;
      if (orderstatus != null) queryParams['orderstatus'] = orderstatus;
      if (paymentStatus != null) queryParams['paymentStatus'] = paymentStatus;
      if (origin != null) queryParams['origin'] = origin;
      if (store != null) queryParams['store'] = store;
      if (customer != null) queryParams['customer'] = customer;
      if (dateFrom != null) {
        queryParams['dateFrom'] = dateFrom.toIso8601String();
      }
      if (dateTo != null) {
        queryParams['dateTo'] = dateTo.toIso8601String();
      }
      queryParams['page'] = page.toString();
      queryParams['limit'] = limit.toString();

      // Make API call
      final response = await _httpService.get(
        ApiConstants.orders,
        queryParams: queryParams,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final ordersResponse = OrdersResponse.fromJson(jsonResponse);
        return ordersResponse;
      } else {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
        final message =
            errorBody?['message'] as String? ??
            'Failed to fetch orders. Please try again.';
        throw Exception(message);
      }
    } catch (e) {
      debugPrint('Error fetching all orders: $e');
      rethrow;
    }
  }

  // Update order status
  Future<Order> updateOrderStatus({
    required String orderId,
    required String orderstatus,
    String? delayTime,
  }) async {
    try {
      // Build request body
      final body = <String, dynamic>{'orderstatus': orderstatus};

      // Add delay time if provided
      if (delayTime != null && delayTime.isNotEmpty) {
        body['delayTime'] = delayTime;
      }

      // Make API call
      final response = await _httpService.patch(
        '${ApiConstants.orders}/$orderId/status',
        body: body,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final success = jsonResponse['success'] as bool? ?? false;

        if (success) {
          final orderData = jsonResponse['data'] as Map<String, dynamic>;
          final order = Order.fromJson(orderData);

          // Update the order in cache instead of invalidating
          await updateOrderInCache(order);

          debugPrint(
            'Order status updated: ${order.orderNumber} -> $orderstatus',
          );
          return order;
        } else {
          final message =
              jsonResponse['message'] as String? ??
              'Failed to update order status';
          throw Exception(message);
        }
      } else {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
        final message =
            errorBody?['message'] as String? ??
            'Failed to update order status. Please try again.';
        throw Exception(message);
      }
    } catch (e) {
      debugPrint('Error updating order status: $e');
      rethrow;
    }
  }

  // Update an existing order
  Future<Order> updateOrder({
    required String orderId,
    String? store,
    List<Map<String, dynamic>>? items,
    double? subtotal,
    double? total,
    double? tax,
    double? tip,
    String? comment,
    Map<String, dynamic>? discount,
    bool clearDiscount = false,
    String? paymentStatus,
    String? orderstatus,
    List<Map<String, dynamic>>? payments,
    String? delayTime,
    DateTime? pickupTime, // pickupTime as DateTime, null = ASAP
    String? customer,
    String? phone,
  }) async {
    try {
      // Build request body with only provided fields
      final body = <String, dynamic>{};

      if (items != null) body['items'] = items;
      if (store != null && store.isNotEmpty) body['store'] = store;
      if (subtotal != null) body['subtotal'] = subtotal;
      if (total != null) body['total'] = total;
      if (tax != null) body['tax'] = tax;
      if (tip != null) body['tip'] = tip;
      if (comment != null) body['comment'] = comment;
      if (discount != null) {
        body['discount'] = discount;
      } else if (clearDiscount) {
        body['discount'] = null;
      }
      if (paymentStatus != null) body['paymentStatus'] = paymentStatus;
      if (orderstatus != null) body['orderstatus'] = orderstatus;
      if (payments != null) body['payments'] = payments;
      // Build pickupInfo with delayTime and/or pickupTime
      if (delayTime != null || pickupTime != null) {
        body['pickupInfo'] = {
          if (delayTime != null) 'delayTime': delayTime,
          'pickupTime': TimezoneUtils.toUtcIsoString(pickupTime), // null = ASAP
        };
      }
      if (customer != null) body['customer'] = customer;
      if (phone != null) body['phone'] = phone;

      // Make API call
      final response = await _httpService.put(
        '${ApiConstants.orders}/$orderId',
        body: body,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final success = jsonResponse['success'] as bool? ?? false;

        if (success) {
          final orderData = jsonResponse['data'] as Map<String, dynamic>;
          final order = Order.fromJson(orderData);

          // Update the order in cache
          await updateOrderInCache(order);

          debugPrint('Order updated successfully: ${order.orderNumber}');
          return order;
        } else {
          final message =
              jsonResponse['message'] as String? ?? 'Failed to update order';
          throw Exception(message);
        }
      } else {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
        final message =
            errorBody?['message'] as String? ??
            'Failed to update order. Please try again.';
        throw Exception(message);
      }
    } catch (e) {
      debugPrint('Error updating order: $e');
      rethrow;
    }
  }

  // Get orders by customer ID
  Future<OrdersResponse> getOrdersByCustomer({
    required String customerId,
    String? sortBy,
    String? sortOrder,
    String? orderstatus,
    String? paymentStatus,
  }) async {
    try {
      debugPrint('Fetching orders for customer: $customerId');

      // Build query parameters
      final queryParams = <String, String>{};

      if (sortBy != null) queryParams['sortBy'] = sortBy;
      if (sortOrder != null) queryParams['sortOrder'] = sortOrder;
      if (orderstatus != null) queryParams['orderstatus'] = orderstatus;
      if (paymentStatus != null) queryParams['paymentStatus'] = paymentStatus;

      // Make API call
      final response = await _httpService.get(
        '${ApiConstants.orders}/customer/$customerId',
        queryParams: queryParams.isEmpty ? null : queryParams,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final ordersResponse = OrdersResponse.fromJson(jsonResponse);

        debugPrint(
          'Customer orders fetched: ${ordersResponse.orders.length} orders',
        );

        return ordersResponse;
      } else {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
        final message =
            errorBody?['message'] as String? ??
            'Failed to fetch customer orders. Please try again.';
        throw Exception(message);
      }
    } catch (e) {
      debugPrint('Error fetching customer orders: $e');
      rethrow;
    }
  }

  // Create a new order
  Future<Order> createOrder({
    required String store,
    String? customer,
    String? phone,
    required String orderType,
    required String paymentStatus,
    required double subtotal,
    required double total,
    required String orderstatus,
    required List<Map<String, dynamic>> items,
    double? tax,
    double? tip,
    String? comment,
    Map<String, dynamic>? discount,
    double? totalRefund,
    List<Map<String, dynamic>>? payments,
    String? delayTime,
    DateTime? pickupTime, // pickupTime as DateTime, null = ASAP
    Map<String, dynamic>? tableInfo,
    String? staffId,
  }) async {
    try {
      // Build request body
      final body = <String, dynamic>{
        'store': store,
        'orderType': orderType,
        'paymentStatus': paymentStatus,
        'subtotal': subtotal,
        'total': total,
        'orderstatus': orderstatus,
        'items': items,
      };

      // Add optional fields
      if (customer != null) body['customer'] = customer;
      if (phone != null) body['phone'] = phone;
      if (tax != null) body['tax'] = tax;
      if (tip != null) body['tip'] = tip;
      if (comment != null && comment.isNotEmpty) body['comment'] = comment;
      if (discount != null) body['discount'] = discount;
      if (totalRefund != null) body['totalRefund'] = totalRefund;
      if (payments != null && payments.isNotEmpty) body['payments'] = payments;
      // The staff field carries the assigned server (for dine-in). createdBy
      // remains the authenticated user on the server for an audit trail.
      if (staffId != null && staffId.isNotEmpty) body['staff'] = staffId;
      // Build pickupInfo with orderType, pickupTime (ISO or null), and delayTime
      if (orderType == 'Pickup' || delayTime != null || pickupTime != null) {
        body['pickupInfo'] = {
          'orderType': orderType,
          'pickupTime': TimezoneUtils.toUtcIsoString(pickupTime), // null = ASAP
          if (delayTime != null && delayTime.isNotEmpty) 'delayTime': delayTime,
        };
      }
      if (tableInfo != null) body['tableInfo'] = tableInfo;

      // Debug: Log order payload date fields in development
      if (kDebugMode && body['pickupInfo'] != null) {
        debugPrint('📦 Order payload date fields: ${body['pickupInfo']}');
      }

      // Make API call
      final response = await _httpService.post(ApiConstants.orders, body: body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final success = jsonResponse['success'] as bool? ?? false;

        if (success) {
          final orderData = jsonResponse['data'] as Map<String, dynamic>;
          final order = Order.fromJson(orderData);

          // Invalidate cache to force refresh
          await invalidateCache();

          debugPrint('Order created successfully: ${order.orderNumber}');
          return order;
        } else {
          final message =
              jsonResponse['message'] as String? ?? 'Failed to create order';
          throw Exception(message);
        }
      } else {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
        final message =
            errorBody?['message'] as String? ??
            'Failed to create order. Please try again.';
        throw Exception(message);
      }
    } catch (e) {
      debugPrint('Error creating order: $e');
      rethrow;
    }
  }

  // Cache order details
  Future<void> _cacheOrderDetails(String orderId, Order order) async {
    try {
      final cacheKey = '${ApiConstants.cacheKeyOrderDetails}$orderId';
      final timestampKey =
          '${ApiConstants.cacheKeyOrderDetailsTimestamp}$orderId';

      // Store the raw order data with all fields
      await _cacheService.set(
        cacheKey,
        order,
        (order) => {
          '_id': order.id,
          'orderNumber': order.orderNumber,
          'date': order.date.toIso8601String(),
          'orderType': order.orderType,
          'origin': order.origin,
          'paymentStatus': order.paymentStatus,
          'subtotal': order.subtotal,
          'total': order.total,
          'tip': order.tip,
          'tax': order.tax,
          'totalRefund': order.totalRefund,
          'orderstatus': order.orderstatus,
          'prePaid': order.prePaid,
          'comment': order.comment,
          'note': order.note,
          'phone': order.customerPhone,
          'store': order.store != null
              ? {'_id': order.store!.id, 'name': order.store!.name}
              : null,
          'customer': order.customer != null
              ? {
                  '_id': order.customer!.id,
                  'firstName': order.customer!.firstName,
                  'lastName': order.customer!.lastName,
                  'phone': order.customer!.phone,
                  'email': order.customer!.email,
                }
              : null,
          'items': order.items
              .map(
                (item) => {
                  '_id': item.id,
                  'item': item.item != null
                      ? {
                          '_id': item.item!.id,
                          'name': item.item!.name,
                          'price': item.item!.price,
                        }
                      : null,
                  'customItem': item.customItem,
                  'quantity': item.quantity,
                  'price': item.price,
                  'modifiers': item.modifiers
                      .map((mod) => {'_id': mod.id, 'name': mod.name})
                      .toList(),
                  'modifiersgroup': item.modifiersgroup,
                  'itemNote': item.itemNote,
                  'discount': item.discount != null
                      ? {
                          'type': item.discount!.type,
                          'value': item.discount!.value,
                        }
                      : null,
                  'itemStatus': item.itemStatus,
                  'refundQuantity': item.refundQuantity,
                  'taxEnable': item.taxEnable,
                  if (item.taxRule != null) 'taxRule': item.taxRule!.toJson(),
                },
              )
              .toList(),
          'payments': order.payments
              .map(
                (payment) => {
                  'method': payment.method,
                  'amount': payment.amount,
                  'cardType': payment.cardType,
                  'change': payment.change,
                  'refund': payment.refund,
                  'status': payment.status,
                },
              )
              .toList(),
          'discount': order.discount != null
              ? {'type': order.discount!.type, 'value': order.discount!.value}
              : null,
          'pickupInfo': order.pickupInfo != null
              ? {
                  'orderType': order.pickupInfo!.orderType,
                  // Serialize pickupTime as ISO string or null (null = ASAP)
                  'pickupTime': TimezoneUtils.toUtcIsoString(
                    order.pickupInfo!.pickupTime,
                  ),
                  'delayTime': TimezoneUtils.toUtcIsoString(
                    order.pickupInfo!.delayTime,
                  ),
                }
              : null,
          'createdBy': order.createdBy != null
              ? {
                  '_id': order.createdBy!.id,
                  'email': order.createdBy!.email,
                  'firstName': order.createdBy!.firstName,
                  'lastName': order.createdBy!.lastName,
                }
              : null,
          'staff': order.staff != null
              ? {
                  '_id': order.staff!.id,
                  'email': order.staff!.email,
                  'firstName': order.staff!.firstName,
                  'lastName': order.staff!.lastName,
                }
              : null,
          'createdAt': order.createdAt?.toIso8601String(),
          'updatedAt': order.updatedAt?.toIso8601String(),
        },
      );

      // Store timestamp
      await _cacheService.setTimestamp(timestampKey);
      debugPrint('Order details cached for ID: $orderId');
    } catch (e) {
      debugPrint('Error caching order details: $e');
    }
  }

  // Get cached order details
  Future<Order?> _getCachedOrderDetails(String orderId) async {
    try {
      final cacheKey = '${ApiConstants.cacheKeyOrderDetails}$orderId';
      final order = await _cacheService.get<Order>(
        cacheKey,
        (json) => Order.fromJson(json),
      );
      return order;
    } catch (e) {
      debugPrint('Error getting cached order details: $e');
      return null;
    }
  }

  // Get order by ID with caching
  Future<Order> getOrderById(
    String orderId, {
    bool forceRefresh = false,
  }) async {
    try {
      debugPrint(
        '🔄 getOrderById called for: $orderId. forceRefresh: $forceRefresh',
      );

      // Check cache first if not forcing refresh
      if (!forceRefresh) {
        final cachedOrder = await _getCachedOrderDetails(orderId);
        final timestampKey =
            '${ApiConstants.cacheKeyOrderDetailsTimestamp}$orderId';
        final isCacheValid = await _cacheService.isCacheValid(
          timestampKey,
          ApiConstants.cacheDuration,
        );

        debugPrint(
          '📦 Cache check: cachedOrder exists: ${cachedOrder != null}, isCacheValid: $isCacheValid',
        );

        if (cachedOrder != null && isCacheValid) {
          debugPrint('✅ Returning cached order: ${cachedOrder.orderNumber}');
          return cachedOrder;
        } else {
          debugPrint('⚠️ Cache miss or invalid. Will fetch from API.');
        }
      } else {
        debugPrint('🔄 Force refresh enabled, skipping cache check');
      }

      // Make API call
      debugPrint('📡 Fetching order from API with ID: $orderId');
      final response = await _httpService.get(
        '${ApiConstants.orders}/$orderId',
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final success = jsonResponse['success'] as bool? ?? false;

        if (success) {
          final orderData = jsonResponse['data'] as Map<String, dynamic>;
          final order = Order.fromJson(orderData);

          debugPrint(
            '📡 Order fetched successfully from API: ${order.orderNumber}',
          );

          // Cache the order
          await _cacheOrderDetails(orderId, order);

          return order;
        } else {
          final message =
              jsonResponse['message'] as String? ?? 'Failed to fetch order';
          throw Exception(message);
        }
      } else {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
        final message =
            errorBody?['message'] as String? ??
            'Failed to fetch order. Please try again.';
        throw Exception(message);
      }
    } catch (e) {
      debugPrint('Error fetching order: $e');
      rethrow;
    }
  }

  // Refund order items (supports both cash and card refunds)
  Future<Order> refundOrder({
    required String orderId,
    List<Map<String, dynamic>>? itemsToRefund,
    required String paymentMethod,
    required String refundReason,
  }) async {
    try {
      // Build request body
      final body = <String, dynamic>{
        'refundReason': refundReason,
        'paymentMethod': paymentMethod,
      };

      // Add items only if provided (if null, it means full order refund)
      if (itemsToRefund != null && itemsToRefund.isNotEmpty) {
        body['itemsToRefund'] = itemsToRefund;
      }

      // Use different endpoint based on payment method
      // Card refunds go through /refund-card which handles Nuvei gateway refund
      final endpoint = paymentMethod == 'Card'
          ? '${ApiConstants.orders}/$orderId/refund-card'
          : '${ApiConstants.orders}/$orderId/refund';

      debugPrint('🔄 Refund API Request - Endpoint: $endpoint');
      debugPrint('🔄 Refund API Request - Body: $body');

      // Make API call
      final response = await _httpService.post(endpoint, body: body);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final success = jsonResponse['success'] as bool? ?? false;

        if (success) {
          final orderData = jsonResponse['data'] as Map<String, dynamic>;
          final order = Order.fromJson(orderData);

          // Update the order in cache
          await updateOrderInCache(order);

          debugPrint('Order refund processed: ${order.orderNumber}');
          return order;
        } else {
          final message =
              jsonResponse['message'] as String? ?? 'Failed to process refund';
          throw Exception(message);
        }
      } else {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
        final message =
            errorBody?['message'] as String? ??
            'Failed to process refund. Please try again.';
        throw Exception(message);
      }
    } catch (e) {
      debugPrint('Error processing refund: $e');
      rethrow;
    }
  }

  // Void order items
  Future<Order> voidOrder({
    required String orderId,
    List<String>? itemsToVoid,
    required String voidReason,
  }) async {
    try {
      // Build request body
      final body = <String, dynamic>{'voidReason': voidReason};

      // Add item IDs only if provided (if null, it means full order void)
      if (itemsToVoid != null && itemsToVoid.isNotEmpty) {
        body['itemsToVoid'] = itemsToVoid;
      }

      debugPrint('🔵 Void API Request - Order ID: $orderId');
      debugPrint('🔵 Void API Request - Body: $body');

      // Make API call
      final response = await _httpService.post(
        '${ApiConstants.orders}/$orderId/void',
        body: body,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final success = jsonResponse['success'] as bool? ?? false;

        if (success) {
          final orderData = jsonResponse['data'] as Map<String, dynamic>;
          final order = Order.fromJson(orderData);

          // Update the order in cache
          await updateOrderInCache(order);

          debugPrint('Order voided: ${order.orderNumber}');
          return order;
        } else {
          final message =
              jsonResponse['message'] as String? ?? 'Failed to void order';
          throw Exception(message);
        }
      } else {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
        final message =
            errorBody?['message'] as String? ??
            'Failed to void order. Please try again.';
        throw Exception(message);
      }
    } catch (e) {
      debugPrint('Error voiding order: $e');
      rethrow;
    }
  }

  // Send email receipt
  Future<void> sendEmailReceipt({
    required String orderId,
    String? email,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (email != null && email.isNotEmpty) {
        body['email'] = email;
      }

      final response = await _httpService.post(
        '${ApiConstants.orders}/$orderId/send-receipt',
        body: body,
      );

      if (response.statusCode == 200) {
        debugPrint('Email receipt sent successfully for order: $orderId');
      } else {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
        final message =
            errorBody?['message'] as String? ?? 'Failed to send receipt';
        throw Exception(message);
      }
    } catch (e) {
      debugPrint('Error sending email receipt: $e');
      rethrow;
    }
  }

  // Get active dine-in order for a specific table
  Future<Order?> getActiveOrderForTable(String tableId) async {
    try {
      // Fetch dine-in orders with Pending or InKitchen status
      final response = await getAllOrders(
        orderType: ApiConstants.orderTypeDineIn,
        orderstatus:
            '${ApiConstants.orderStatusPending},${ApiConstants.orderStatusInKitchen}',
        limit: -1, // Get all matching orders
      );

      // Find order with matching tableId
      for (final order in response.orders) {
        if (order.tableInfo?.tableId == tableId) {
          return order;
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error fetching active order for table: $e');
      return null;
    }
  }

  // Clear cached order details for a specific order
  Future<void> clearOrderDetailsCache(String orderId) async {
    try {
      final cacheKey = '${ApiConstants.cacheKeyOrderDetails}$orderId';
      final timestampKey =
          '${ApiConstants.cacheKeyOrderDetailsTimestamp}$orderId';

      await _cacheService.remove(cacheKey);
      await _cacheService.remove(timestampKey);

      debugPrint('Order details cache cleared for ID: $orderId');
    } catch (e) {
      debugPrint('Error clearing order details cache: $e');
    }
  }
}
