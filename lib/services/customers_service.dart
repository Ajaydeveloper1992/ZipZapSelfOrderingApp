import 'dart:convert';
import 'package:flutter/foundation.dart' hide Category;
import 'package:zipzap_pos_self_orders/core/constants/api_constants.dart';
import 'package:zipzap_pos_self_orders/core/models/api_response.dart';
import 'package:zipzap_pos_self_orders/core/services/cache_service.dart';
import 'package:zipzap_pos_self_orders/core/services/http_service.dart';
import 'package:zipzap_pos_self_orders/models/customer_model.dart';

class CustomersService {
  static final CustomersService _instance = CustomersService._internal();
  factory CustomersService() => _instance;
  CustomersService._internal();

  final HttpService _httpService = HttpService();
  final CacheService _cacheService = CacheService();

  static const String cacheKeyCustomers = 'customers';
  static const String cacheKeyCustomersTimestamp = 'customers_timestamp';

  // Get customers with caching and optional pagination
  Future<CustomersResponse> getCustomers({
    bool forceRefresh = false,
    int? limit,
    int? page,
  }) async {
    try {
      // Check cache first if not forcing refresh and no pagination specified
      if (!forceRefresh && limit == null && page == null) {
        final cachedCustomers = await _getCachedCustomers();
        final isCacheValid = await _cacheService.isCacheValid(
          cacheKeyCustomersTimestamp,
          ApiConstants.cacheDuration,
        );

        if (cachedCustomers != null && isCacheValid) {
          debugPrint('Returning cached customers');
          return cachedCustomers;
        }
      }

      // Build URL with query parameters
      String url = ApiConstants.customers;
      final queryParams = <String>[];
      if (limit != null) queryParams.add('limit=$limit');
      if (page != null) queryParams.add('page=$page');
      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }

      debugPrint('Fetching customers: $url');
      final response = await _httpService.get(url);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint(
          'Customers API response: ${jsonResponse['data']?.length ?? 0} customers',
        );
        final customersResponse = CustomersResponse.fromJson(jsonResponse);
        debugPrint(
          'Parsed ${customersResponse.customers.length} customers successfully',
        );

        // Only cache if fetching all customers (no pagination)
        if (limit == null && page == null) {
          await _cacheCustomers(customersResponse);
          debugPrint('Cached ${customersResponse.customers.length} customers');
        }

        return customersResponse;
      } else {
        throw Exception(
          'Failed to load customers: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching customers: $e');

      // Try to return cached data as fallback (only if not paginated request)
      if (limit == null && page == null) {
        final cachedCustomers = await _getCachedCustomers();
        if (cachedCustomers != null) {
          debugPrint('Returning cached customers as fallback');
          return cachedCustomers;
        }
      }

      rethrow;
    }
  }

  // Get cached customers
  Future<CustomersResponse?> _getCachedCustomers() async {
    try {
      final cachedData = await _cacheService.get<Map<String, dynamic>>(
        cacheKeyCustomers,
        (json) => json,
      );

      if (cachedData != null) {
        return CustomersResponse.fromJson(cachedData);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting cached customers: $e');
      return null;
    }
  }

  // Public method to cache customers (for background fetch completion)
  Future<void> cacheCustomersData(CustomersResponse customersResponse) async {
    await _cacheCustomers(customersResponse);
  }

  // Cache customers
  Future<void> _cacheCustomers(CustomersResponse customersResponse) async {
    try {
      final jsonData = <String, dynamic>{
        'data': customersResponse.customers.map((c) => c.toJson()).toList(),
        if (customersResponse.pagination != null)
          'pagination': {
            'currentPage': customersResponse.pagination!.currentPage,
            'totalPages': customersResponse.pagination!.totalPages,
            'totalItems': customersResponse.pagination!.totalItems,
            'itemsPerPage': customersResponse.pagination!.itemsPerPage,
            'hasNextPage': customersResponse.pagination!.hasNextPage,
            'hasPrevPage': customersResponse.pagination!.hasPrevPage,
          },
      };

      final result = await _cacheService.set(
        cacheKeyCustomers,
        jsonData,
        (data) => data,
      );

      if (result) {
        debugPrint(
          'Successfully cached ${customersResponse.customers.length} customers',
        );
      } else {
        debugPrint('Failed to cache customers - set() returned false');
      }

      final timestampResult = await _cacheService.setTimestamp(
        cacheKeyCustomersTimestamp,
      );

      if (timestampResult) {
        debugPrint('Successfully cached customers timestamp');
      } else {
        debugPrint('Failed to cache customers timestamp');
      }
    } catch (e, stackTrace) {
      debugPrint('Error caching customers: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  // Create a new customer
  Future<Customer> createCustomer({
    required String firstName,
    String? lastName,
    bool? isReturning,
    String? email,
    String? phone,
    Map<String, dynamic>? address,
    String? note,
    String? store,
  }) async {
    try {
      // Build request body
      final body = <String, dynamic>{'firstName': firstName};

      // Add optional fields
      if (lastName != null && lastName.isNotEmpty) body['lastName'] = lastName;
      if (isReturning != null) body['isReturning'] = isReturning;
      if (email != null && email.isNotEmpty) body['email'] = email;
      if (phone != null && phone.isNotEmpty) body['phone'] = phone;
      if (address != null) body['address'] = address;
      if (note != null && note.isNotEmpty) body['note'] = note;
      if (store != null) body['store'] = store;

      // Make API call
      final response = await _httpService.post(
        ApiConstants.customers,
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final success = jsonResponse['success'] as bool? ?? false;

        if (success) {
          final customerData = jsonResponse['data'] as Map<String, dynamic>;
          final customer = Customer.fromJson(customerData);

          // Invalidate cache to force refresh
          invalidateCache();

          debugPrint('Customer created successfully: ${customer.id}');
          return customer;
        } else {
          final message =
              jsonResponse['message'] as String? ?? 'Failed to create customer';
          throw Exception(message);
        }
      } else {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
        final message =
            errorBody?['message'] as String? ??
            'Failed to create customer. Please try again.';
        throw Exception(message);
      }
    } catch (e) {
      debugPrint('Error creating customer: $e');
      rethrow;
    }
  }

  // Update an existing customer
  Future<Customer> updateCustomer({
    required String customerId,
    String? firstName,
    String? lastName,
    bool? isReturning,
    String? email,
    String? phone,
    Map<String, dynamic>? address,
    String? note,
  }) async {
    try {
      // Build request body with only provided fields
      final body = <String, dynamic>{};

      if (firstName != null && firstName.isNotEmpty) {
        body['firstName'] = firstName;
      }
      if (lastName != null) body['lastName'] = lastName;
      if (isReturning != null) body['isReturning'] = isReturning;
      if (email != null) body['email'] = email;
      if (phone != null) body['phone'] = phone;
      if (address != null) body['address'] = address;
      if (note != null) body['note'] = note;

      // Make API call
      final response = await _httpService.put(
        '${ApiConstants.customers}/$customerId',
        body: body,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final success = jsonResponse['success'] as bool? ?? false;

        if (success) {
          final customerData = jsonResponse['data'] as Map<String, dynamic>;
          final customer = Customer.fromJson(customerData);

          // Invalidate cache to force refresh
          invalidateCache();

          debugPrint('Customer updated successfully: ${customer.id}');
          return customer;
        } else {
          final message =
              jsonResponse['message'] as String? ?? 'Failed to update customer';
          throw Exception(message);
        }
      } else {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
        final message =
            errorBody?['message'] as String? ??
            'Failed to update customer. Please try again.';
        throw Exception(message);
      }
    } catch (e) {
      debugPrint('Error updating customer: $e');
      rethrow;
    }
  }

  // Get a single customer by ID (with full data including orders)
  Future<Customer> getCustomerById(String customerId) async {
    try {
      debugPrint('Fetching customer by ID: $customerId');

      final response = await _httpService.get(
        '${ApiConstants.customers}/$customerId',
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final success = jsonResponse['success'] as bool? ?? false;

        if (success) {
          final customerData = jsonResponse['data'] as Map<String, dynamic>;

          // Transform phone number if it's NumberLong
          if (customerData['phone'] != null &&
              customerData['phone'] is Map &&
              (customerData['phone'] as Map)['\$numberLong'] != null) {
            customerData['phone'] =
                (customerData['phone'] as Map)['\$numberLong'];
          }

          final customer = Customer.fromJson(customerData);
          debugPrint(
            'Customer fetched: ${customer.fullName}, isReturning: ${customer.isReturning}, ordersCount: ${customer.ordersCount}',
          );
          return customer;
        } else {
          final message =
              jsonResponse['message'] as String? ?? 'Failed to fetch customer';
          throw Exception(message);
        }
      } else {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
        final message =
            errorBody?['message'] as String? ??
            'Failed to fetch customer. Please try again.';
        throw Exception(message);
      }
    } catch (e) {
      debugPrint('Error fetching customer by ID: $e');
      rethrow;
    }
  }

  // Contact customer via email/SMS
  Future<Map<String, dynamic>> contactCustomer({
    required String customerId,
    required String contactType, // 'email' | 'sms' | 'both'
    required String
    templateType, // 'order_ready' | 'delay' | 'reminder' | 'custom'
    required String messageBody,
    String? orderNumber,
    String? subject,
    Map<String, dynamic>? orderInfo,
    String? ctaText,
    String? ctaUrl,
    List<String>? tags,
  }) async {
    try {
      // Build request body
      final body = <String, dynamic>{
        'contactType': contactType,
        'templateType': templateType,
        'messageBody': messageBody,
      };

      // Add optional fields
      if (orderNumber != null && orderNumber.isNotEmpty) {
        body['orderNumber'] = orderNumber;
      }
      if (subject != null && subject.isNotEmpty) body['subject'] = subject;
      if (orderInfo != null) body['orderInfo'] = orderInfo;
      if (ctaText != null && ctaText.isNotEmpty) body['ctaText'] = ctaText;
      if (ctaUrl != null && ctaUrl.isNotEmpty) body['ctaUrl'] = ctaUrl;
      if (tags != null && tags.isNotEmpty) body['tags'] = tags;

      debugPrint('Contacting customer $customerId with type: $contactType');

      // Make API call
      final response = await _httpService.post(
        '${ApiConstants.customers}/$customerId/contact',
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final success = jsonResponse['success'] as bool? ?? false;

        if (success) {
          debugPrint('Customer contacted successfully');
          return jsonResponse;
        } else {
          final message =
              jsonResponse['message'] as String? ??
              'Failed to send notification';
          throw Exception(message);
        }
      } else {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
        final message =
            errorBody?['message'] as String? ??
            'Failed to send notification. Please try again.';
        throw Exception(message);
      }
    } catch (e) {
      debugPrint('Error contacting customer: $e');
      rethrow;
    }
  }

  // Invalidate cache
  void invalidateCache() {
    _cacheService.remove(cacheKeyCustomers);
    _cacheService.remove(cacheKeyCustomersTimestamp);
  }
}
