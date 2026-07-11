import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:zipzap_pos_self_orders/core/constants/api_constants.dart';
import 'package:zipzap_pos_self_orders/core/services/http_service.dart';
import 'package:zipzap_pos_self_orders/core/services/cache_service.dart';
import 'package:zipzap_pos_self_orders/core/services/auth_service.dart';

class StoresService {
  static final StoresService _instance = StoresService._internal();
  factory StoresService() => _instance;
  StoresService._internal();

  final HttpService _httpService = HttpService();
  final CacheService _cacheService = CacheService();
  final AuthService _authService = AuthService();

  static const String cacheKeyStore = 'store_details';
  static const String cacheKeyStoreTimestamp = 'store_details_timestamp';

  // Get store details by slug or ID with caching
  Future<StoreDetails> getStoreBySlugOrId({
    String? slugOrId,
    bool forceRefresh = false,
  }) async {
    try {
      // Get slugOrId from profile or last login credentials if not provided
      final finalSlugOrId =
          slugOrId ??
          _authService.getProfile()?.storeSlug ??
          _authService.getLastStoreSlug();

      if (finalSlugOrId == null || finalSlugOrId.isEmpty) {
        throw Exception('Store slug or ID is required');
      }

      // Check cache first if not forcing refresh
      if (!forceRefresh) {
        final cachedStore = await _getCachedStore();
        final isCacheValid = await _cacheService.isCacheValid(
          cacheKeyStoreTimestamp,
          ApiConstants.cacheDuration,
        );

        if (cachedStore != null && isCacheValid) {
          debugPrint('Returning cached store details');
          return cachedStore;
        }
      }

      // Make API call
      final response = await _httpService.get(
        '${ApiConstants.stores}/$finalSlugOrId',
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final success = jsonResponse['success'] as bool? ?? false;

        if (success) {
          final data = jsonResponse['data'] as Map<String, dynamic>;
          final storeDetails = StoreDetails.fromJson(data);

          // Cache the response
          await _cacheStore(storeDetails);

          return storeDetails;
        } else {
          final message =
              jsonResponse['message'] as String? ?? 'Failed to fetch store';
          throw Exception(message);
        }
      } else {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
        final message =
            errorBody?['message'] as String? ??
            'Failed to fetch store. Please try again.';
        throw Exception(message);
      }
    } catch (e) {
      debugPrint('Get store error: $e');

      // Try to return cached data as fallback
      final cachedStore = await _getCachedStore();
      if (cachedStore != null) {
        debugPrint('Returning cached store details as fallback');
        return cachedStore;
      }

      rethrow;
    }
  }

  // Get cached store
  Future<StoreDetails?> _getCachedStore() async {
    try {
      final cachedData = await _cacheService.get<Map<String, dynamic>>(
        cacheKeyStore,
        (json) => json,
      );

      if (cachedData != null) {
        return StoreDetails.fromJson(cachedData);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting cached store: $e');
      return null;
    }
  }

  // Cache store
  Future<void> _cacheStore(StoreDetails storeDetails) async {
    try {
      await _cacheService.set(
        cacheKeyStore,
        storeDetails.toJson(),
        (data) => data,
      );
      await _cacheService.setTimestamp(cacheKeyStoreTimestamp);
    } catch (e) {
      debugPrint('Error caching store: $e');
    }
  }

  // Invalidate cache
  void invalidateCache() {
    _cacheService.remove(cacheKeyStore);
    _cacheService.remove(cacheKeyStoreTimestamp);
  }

  /// Update store status (open/closed)
  /// Returns the updated StoreDetails on success
  Future<StoreDetails> updateStoreStatus({
    required String storeId,
    required String status,
  }) async {
    try {
      if (storeId.isEmpty) {
        throw Exception('Store ID is required');
      }

      if (status != 'open' && status != 'closed') {
        throw Exception('Status must be either "open" or "closed"');
      }

      final response = await _httpService.put(
        '${ApiConstants.stores}/$storeId',
        body: {'status': status},
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final success = jsonResponse['success'] as bool? ?? false;

        if (success) {
          final data = jsonResponse['data'] as Map<String, dynamic>;
          final storeDetails = StoreDetails.fromJson(data);

          // Invalidate cache so next fetch gets fresh data
          invalidateCache();

          // Also cache the updated store
          await _cacheStore(storeDetails);

          return storeDetails;
        } else {
          final message =
              jsonResponse['message'] as String? ?? 'Failed to update store';
          throw Exception(message);
        }
      } else {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
        final message =
            errorBody?['message'] as String? ??
            'Failed to update store. Please try again.';
        throw Exception(message);
      }
    } catch (e) {
      debugPrint('Update store status error: $e');
      rethrow;
    }
  }
}

// Store address model
class StoreAddress {
  final String? street;
  final String? city;
  final String? state;
  final String? country;
  final String? zip;
  final String? timezone;
  final String? language;

  StoreAddress({
    this.street,
    this.city,
    this.state,
    this.country,
    this.zip,
    this.timezone,
    this.language,
  });

  factory StoreAddress.fromJson(Map<String, dynamic> json) {
    return StoreAddress(
      street: json['street']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      country: json['country']?.toString(),
      zip: json['zip']?.toString(),
      timezone: json['timezone']?.toString(),
      language: json['language']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (street != null) 'street': street,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (country != null) 'country': country,
      if (zip != null) 'zip': zip,
      if (timezone != null) 'timezone': timezone,
      if (language != null) 'language': language,
    };
  }

  /// Returns formatted full address string
  String get fullAddress {
    final parts = <String>[];
    if (street != null && street!.isNotEmpty) parts.add(street!);
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (state != null && state!.isNotEmpty) parts.add(state!);
    if (zip != null && zip!.isNotEmpty) parts.add(zip!);
    return parts.join(', ');
  }
}

// Store details model with all fields from API response
class StoreDetails {
  final String id;
  final String name;
  final String slug;
  final String status;
  final String? owner;
  final String? logo;
  final String? banner;
  final String? description;
  final String? closedNotice;
  final String? phone;
  final StoreAddress? address;
  final double? minOrderAmount;
  final int? orderPrepTime;
  final int? timeSlots;
  final String? siteUrl;
  final Map<String, dynamic>? openingHours;
  final Map<String, dynamic>? servicesOffered;
  final bool? isAutoPrint;
  final bool? isReturning;
  final bool? isCheckoutTipEnable;
  final bool? isPosTipEnable;
  final bool? isEmailUponVoid;
  final bool? isKitchenPrint;
  final bool? isVoidedPrint;
  final Map<String, dynamic>? paymentSettings;
  final Map<String, dynamic>? ghl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? email;

  StoreDetails({
    required this.id,
    required this.name,
    required this.slug,
    required this.status,
    this.owner,
    this.logo,
    this.banner,
    this.description,
    this.closedNotice,
    this.phone,
    this.address,
    this.minOrderAmount,
    this.orderPrepTime,
    this.timeSlots,
    this.siteUrl,
    this.openingHours,
    this.servicesOffered,
    this.isAutoPrint,
    this.isReturning,
    this.isCheckoutTipEnable,
    this.isPosTipEnable,
    this.isEmailUponVoid,
    this.isKitchenPrint,
    this.isVoidedPrint,
    this.paymentSettings,
    this.ghl,
    this.createdAt,
    this.updatedAt,
    this.email,
  });

  factory StoreDetails.fromJson(Map<String, dynamic> json) {
    return StoreDetails(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      status: json['status']?.toString() ?? 'open',
      owner: json['owner']?.toString(),
      logo: json['logo']?.toString(),
      banner: json['banner']?.toString(),
      description: json['description']?.toString(),
      closedNotice: json['closedNotice']?.toString(),
      phone: json['phone']?.toString(),
      address: json['address'] != null
          ? StoreAddress.fromJson(json['address'] as Map<String, dynamic>)
          : null,
      minOrderAmount: (json['minOrderAmount'] as num?)?.toDouble(),
      orderPrepTime: (json['orderPrepTime'] as num?)?.toInt(),
      timeSlots: (json['timeSlots'] as num?)?.toInt(),
      siteUrl: json['siteUrl']?.toString(),
      openingHours: json['openingHours'] as Map<String, dynamic>?,
      servicesOffered: json['servicesOffered'] as Map<String, dynamic>?,
      isAutoPrint: json['isAutoPrint'] as bool?,
      isReturning: json['isReturning'] as bool?,
      isCheckoutTipEnable: json['isCheckoutTipEnable'] as bool?,
      isPosTipEnable: json['isPosTipEnable'] as bool?,
      isEmailUponVoid: json['isEmailUponVoid'] as bool?,
      isKitchenPrint: json['isKitchenPrint'] as bool?,
      isVoidedPrint: json['isVoidedPrint'] as bool?,
      paymentSettings: json['paymentSettings'] as Map<String, dynamic>?,
      ghl: json['ghl'] as Map<String, dynamic>?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      email: json['email']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'id': id,
      'name': name,
      'slug': slug,
      'status': status,
      if (owner != null) 'owner': owner,
      if (logo != null) 'logo': logo,
      if (banner != null) 'banner': banner,
      if (description != null) 'description': description,
      if (closedNotice != null) 'closedNotice': closedNotice,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address!.toJson(),
      if (minOrderAmount != null) 'minOrderAmount': minOrderAmount,
      if (orderPrepTime != null) 'orderPrepTime': orderPrepTime,
      if (timeSlots != null) 'timeSlots': timeSlots,
      if (siteUrl != null) 'siteUrl': siteUrl,
      if (openingHours != null) 'openingHours': openingHours,
      if (servicesOffered != null) 'servicesOffered': servicesOffered,
      if (isAutoPrint != null) 'isAutoPrint': isAutoPrint,
      if (isReturning != null) 'isReturning': isReturning,
      if (isCheckoutTipEnable != null)
        'isCheckoutTipEnable': isCheckoutTipEnable,
      if (isPosTipEnable != null) 'isPosTipEnable': isPosTipEnable,
      if (isEmailUponVoid != null) 'isEmailUponVoid': isEmailUponVoid,
      if (isKitchenPrint != null) 'isKitchenPrint': isKitchenPrint,
      if (isVoidedPrint != null) 'isVoidedPrint': isVoidedPrint,
      if (paymentSettings != null) 'paymentSettings': paymentSettings,
      if (ghl != null) 'ghl': ghl,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (email != null) 'email': email,
    };
  }
}
