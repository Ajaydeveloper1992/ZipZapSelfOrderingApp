import 'package:flutter/foundation.dart';

/// Permission resource keys matching server's PermissionResource enum
class PermissionResource {
  static const String users = 'users';
  static const String roles = 'roles';
  static const String stores = 'stores';
  static const String customers = 'customers';
  static const String orders = 'orders';
  static const String categories = 'categories';
  static const String products = 'products';
  static const String modifiers = 'modifiers';
  static const String modifierGroups = 'modifier_groups';
  static const String methods = 'methods';
  static const String reports = 'reports';
  static const String settings = 'settings';
  static const String taxRules = 'tax_rules';
  static const String coupons = 'coupons';
  static const String labels = 'labels';
  static const String media = 'media';
  static const String floorPlans = 'floor_plans';
  static const String cashDrawer = 'cash_drawer';
}

class UserProfile {
  final String id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? role; // Role name (e.g., 'admin', 'manager')
  final String? roleId; // Role ID for reference
  final Map<String, dynamic>? permissions; // Role permissions
  final String? storeId; // Store ID as string (from user.store or user.storeId)
  final Store? store; // Store object (from response.data.store)
  final bool isAdmin;
  final bool isSuperAdmin;
  final String status;
  final String? avatar;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;
  final DateTime? lastActiveAt;

  UserProfile({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.role,
    this.roleId,
    this.permissions,
    this.storeId,
    this.store,
    this.isAdmin = false,
    this.isSuperAdmin = false,
    this.status = 'active',
    this.avatar,
    this.createdAt,
    this.updatedAt,
    this.lastLoginAt,
    this.lastActiveAt,
  });

  String get fullName {
    if (lastName.isEmpty) return firstName;
    return '$firstName $lastName';
  }

  String? get storeName => store?.name;
  String? get storeSlug => store?.slug;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    try {
      // Handle store - can be string ID or object
      String? storeIdValue;
      Store? storeObj;

      if (json['store'] != null) {
        if (json['store'] is String) {
          storeIdValue = json['store'] as String;
        } else if (json['store'] is Map<String, dynamic>) {
          try {
            storeObj = Store.fromJson(json['store'] as Map<String, dynamic>);
            storeIdValue = storeObj.id;
          } catch (e) {
            debugPrint('Error parsing store object: $e');
            // Try to extract ID as fallback
            final storeMap = json['store'] as Map<String, dynamic>;
            storeIdValue =
                storeMap['_id'] as String? ?? storeMap['id'] as String?;
          }
        }
      }

      // Also check storeId field directly
      storeIdValue ??= json['storeId'] as String?;

      // Handle role - can be string or object with permissions
      String? roleValue;
      String? roleIdValue;
      Map<String, dynamic>? permissionsValue;

      if (json['role'] != null) {
        if (json['role'] is String) {
          roleValue = json['role'] as String;
          roleIdValue = json['role'] as String;
        } else if (json['role'] is Map<String, dynamic>) {
          try {
            final roleObj = json['role'] as Map<String, dynamic>;
            roleValue = roleObj['name'] as String?;
            roleIdValue = roleObj['_id'] as String? ?? roleObj['id'] as String?;
            // Parse permissions if available
            if (roleObj['permissions'] != null) {
              permissionsValue =
                  roleObj['permissions'] as Map<String, dynamic>?;
            }
          } catch (e) {
            debugPrint('Error parsing role object: $e');
          }
        }
      }

      return UserProfile(
        id: json['_id'] as String? ?? json['id'] as String? ?? '',
        username: json['username'] as String? ?? '',
        email: json['email'] as String? ?? '',
        firstName: json['firstName'] as String? ?? '',
        lastName: json['lastName'] as String? ?? '',
        phone: json['phone']?.toString(),
        role: roleValue,
        roleId: roleIdValue,
        permissions: permissionsValue,
        storeId: storeIdValue,
        store: storeObj,
        isAdmin: json['isAdmin'] as bool? ?? false,
        isSuperAdmin: json['isSuperAdmin'] as bool? ?? false,
        status: json['status'] as String? ?? 'active',
        avatar: json['avatar'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'].toString())
            : null,
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'].toString())
            : null,
        lastLoginAt: json['lastLoginAt'] != null
            ? DateTime.tryParse(json['lastLoginAt'].toString())
            : null,
        lastActiveAt: json['lastActiveAt'] != null
            ? DateTime.tryParse(json['lastActiveAt'].toString())
            : null,
      );
    } catch (e, stackTrace) {
      debugPrint('Error parsing UserProfile from JSON: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'id': id,
      'username': username,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      if (phone != null) 'phone': phone,
      if (role != null || roleId != null)
        'role': {
          if (roleId != null) '_id': roleId,
          if (role != null) 'name': role,
          if (permissions != null) 'permissions': permissions,
        },
      if (storeId != null) 'storeId': storeId,
      if (store != null) 'store': store!.toJson(),
      'isAdmin': isAdmin,
      'isSuperAdmin': isSuperAdmin,
      'status': status,
      if (avatar != null) 'avatar': avatar,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (lastLoginAt != null) 'lastLoginAt': lastLoginAt!.toIso8601String(),
      if (lastActiveAt != null) 'lastActiveAt': lastActiveAt!.toIso8601String(),
    };
  }

  /// Check if user has a specific permission
  bool hasPermission(String resource, String action) {
    if (isSuperAdmin) return true; // Superadmins have all permissions
    if (permissions == null) return false;

    final resourcePerms = permissions![resource];
    if (resourcePerms == null) return false;

    if (resourcePerms is Map<String, dynamic>) {
      return resourcePerms[action] == true;
    }
    return false;
  }

  /// Check if user can create a resource
  bool canCreate(String resource) => hasPermission(resource, 'create');

  /// Check if user can read a resource
  bool canRead(String resource) => hasPermission(resource, 'read');

  /// Check if user can update a resource
  bool canUpdate(String resource) => hasPermission(resource, 'update');

  /// Check if user can delete a resource
  bool canDelete(String resource) => hasPermission(resource, 'delete');

  // ─────────────────────────────────────────────────────────────────────────
  // Convenience getters for common permission checks
  // ─────────────────────────────────────────────────────────────────────────

  /// Check if user can read floor plans (for Dine-In access)
  bool get canReadFloorPlans => canRead(PermissionResource.floorPlans);

  /// Check if user can create floor plans
  bool get canCreateFloorPlans => canCreate(PermissionResource.floorPlans);

  /// Check if user can update floor plans
  bool get canUpdateFloorPlans => canUpdate(PermissionResource.floorPlans);

  /// Check if user can delete floor plans
  bool get canDeleteFloorPlans => canDelete(PermissionResource.floorPlans);

  /// Check if user can open cash drawer (read permission for cash drawer)
  bool get canOpenCashDrawer => canRead(PermissionResource.cashDrawer);

  /// Check if user can create cash drawer entries
  bool get canCreateCashDrawer => canCreate(PermissionResource.cashDrawer);

  /// Check if user can update cash drawer settings
  bool get canUpdateCashDrawer => canUpdate(PermissionResource.cashDrawer);

  /// Check if user can delete cash drawer entries
  bool get canDeleteCashDrawer => canDelete(PermissionResource.cashDrawer);
}

class Store {
  final String id;
  final String name;
  final String? slug;
  final String? address;
  final String? status;
  final String? owner;
  final String? logo;
  final String? banner;
  final String? description;
  final String? closedNotice;
  final String? phone;
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
  final String? email;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Store({
    required this.id,
    required this.name,
    this.slug,
    this.address,
    this.status,
    this.owner,
    this.logo,
    this.banner,
    this.description,
    this.closedNotice,
    this.phone,
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
    this.email,
    this.createdAt,
    this.updatedAt,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    try {
      // Extract id - can be _id or id
      final idValue = json['_id'] as String? ?? json['id'] as String? ?? '';

      // Extract name - required field
      final nameValue = json['name'] as String? ?? '';

      if (idValue.isEmpty) {
        throw Exception('Store ID is required but not found in JSON');
      }
      if (nameValue.isEmpty) {
        throw Exception('Store name is required but not found in JSON');
      }

      return Store(
        id: idValue,
        name: nameValue,
        slug: json['slug'] as String?,
        address: json['address'] as String?,
        status: json['status'] as String?,
        owner: json['owner'] as String?,
        logo: json['logo'] as String?,
        banner: json['banner'] as String?,
        description: json['description'] as String?,
        closedNotice: json['closedNotice'] as String?,
        phone: json['phone']?.toString(),
        minOrderAmount: (json['minOrderAmount'] as num?)?.toDouble(),
        orderPrepTime: json['orderPrepTime'] as int?,
        timeSlots: json['timeSlots'] as int?,
        siteUrl: json['siteUrl'] as String?,
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
        email: json['email'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'].toString())
            : null,
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'].toString())
            : null,
      );
    } catch (e) {
      debugPrint('Error parsing Store from JSON: $e');
      debugPrint('Store JSON keys: ${json.keys.toList()}');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'id': id,
      'name': name,
      if (slug != null) 'slug': slug,
      if (address != null) 'address': address,
      if (status != null) 'status': status,
      if (owner != null) 'owner': owner,
      if (logo != null) 'logo': logo,
      if (banner != null) 'banner': banner,
      if (description != null) 'description': description,
      if (closedNotice != null) 'closedNotice': closedNotice,
      if (phone != null) 'phone': phone,
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
      if (email != null) 'email': email,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }
}
