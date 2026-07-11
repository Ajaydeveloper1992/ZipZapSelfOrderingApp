import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zipzap_pos_self_orders/core/constants/api_constants.dart';
import 'package:zipzap_pos_self_orders/core/models/user_profile.dart';
import 'package:zipzap_pos_self_orders/core/services/http_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final HttpService _httpService = HttpService();
  bool? _isAuthenticated;
  String? _storeId;
  UserProfile? _profile;
  String? _lastStoreSlug;
  String? _lastUsername;

  // Decode JWT token to get user ID
  String? getUserIdFromToken() {
    try {
      final token = _httpService.authToken;
      if (token == null || token.isEmpty) return null;

      // JWT tokens have 3 parts separated by dots: header.payload.signature
      final parts = token.split('.');
      if (parts.length != 3) return null;

      // Decode the payload (second part)
      final payload = parts[1];
      // Add padding if needed
      String normalizedPayload = payload;
      final remainder = payload.length % 4;
      if (remainder > 0) {
        normalizedPayload += '=' * (4 - remainder);
      }

      final decoded = utf8.decode(base64Url.decode(normalizedPayload));
      final json = jsonDecode(decoded) as Map<String, dynamic>;

      // Extract user ID from token
      return json['id'] as String?;
    } catch (e) {
      debugPrint('Error decoding JWT token: $e');
      return null;
    }
  }

  // Check if user is authenticated and session is not expired
  Future<bool> isAuthenticated() async {
    if (_isAuthenticated != null) {
      return _isAuthenticated!;
    }

    try {
      final token = _httpService.authToken;
      if (token == null || token.isEmpty) {
        _isAuthenticated = false;
        return false;
      }

      // Check if session has expired (7 days)
      final isExpired = await isSessionExpired();
      if (isExpired) {
        debugPrint('Session expired. Auto-logout triggered.');
        await logout();
        _isAuthenticated = false;
        return false;
      }

      _isAuthenticated = true;
      return true;
    } catch (e) {
      debugPrint('Error checking authentication: $e');
      return false;
    }
  }

  // Check if session has expired
  Future<bool> isSessionExpired() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt('auth_timestamp');

      if (timestamp == null) {
        // No timestamp means old session, consider it expired
        return true;
      }

      final loginTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      final difference = now.difference(loginTime);

      return difference > ApiConstants.sessionDuration;
    } catch (e) {
      debugPrint('Error checking session expiration: $e');
      return true; // Consider expired on error for safety
    }
  }

  // Pin login - call API and store token + profile
  Future<void> pinLogin({
    required String user,
    required String pin,
    required String storeSlug,
  }) async {
    try {
      final response = await _httpService.post(
        ApiConstants.pinLogin,
        body: {'user': user, 'pin': pin, 'storeSlug': storeSlug},
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final success = jsonResponse['success'] as bool? ?? false;

        if (success) {
          final data = jsonResponse['data'] as Map<String, dynamic>;
          final token = data['token'] as String;

          // Store token first
          await _httpService.setAuthToken(token);

          // Save store slug and username for auto-population
          _lastStoreSlug = storeSlug;
          _lastUsername = user;
          await _saveLastLoginCredentials(storeSlug, user);

          _isAuthenticated = true;

          // Note: Profile will be fetched via fetchProfile() method
          // This is done during initial data loading to get complete profile data
        } else {
          final message = jsonResponse['message'] as String? ?? 'Login failed';
          throw Exception(message);
        }
      } else {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
        final message =
            errorBody?['message'] as String? ??
            'Login failed. Please try again.';
        throw Exception(message);
      }
    } catch (e) {
      debugPrint('Pin login error: $e');
      rethrow;
    }
  }

  // Login - set auth token and optionally store ID (legacy method for testing)
  Future<void> login(String token, {String? storeId}) async {
    await _httpService.setAuthToken(token);
    if (storeId != null) {
      _storeId = storeId;
      // Store storeId in SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('store_id', storeId);
      } catch (e) {
        debugPrint('Error storing storeId: $e');
      }
    }
    _isAuthenticated = true;
  }

  // Get user profile
  UserProfile? getProfile() {
    return _profile;
  }

  // Get profile from storage
  Future<UserProfile?> getProfileFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = prefs.getString('user_profile');
      if (profileJson != null) {
        final json = jsonDecode(profileJson) as Map<String, dynamic>;
        _profile = UserProfile.fromJson(json);
        return _profile;
      }
      return null;
    } catch (e) {
      debugPrint('Error loading profile from storage: $e');
      return null;
    }
  }

  // Initialize profile from storage
  Future<void> initializeProfile() async {
    try {
      _profile = await getProfileFromStorage();
      if (_profile != null) {
        _storeId = _profile!.storeId;
      } else {
        // Fallback to loading storeId separately
        final prefs = await SharedPreferences.getInstance();
        _storeId = prefs.getString('store_id');
      }

      // Load last login credentials
      await _loadLastLoginCredentials();
    } catch (e) {
      debugPrint('Error initializing profile: $e');
    }
  }

  // Save profile to storage
  Future<void> _saveProfile(UserProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileJson = jsonEncode(profile.toJson());
      await prefs.setString('user_profile', profileJson);
      _profile = profile;
    } catch (e) {
      debugPrint('Error saving profile: $e');
    }
  }

  /// Update profile from WebSocket data (OPTIMISTIC UPDATE)
  /// This is called when a profile_updated WebSocket message is received
  Future<void> updateProfileFromWebSocket(
    Map<String, dynamic> profileData,
  ) async {
    try {
      // Only update if this is the current user's profile
      final currentUserId = _profile?.id ?? getUserIdFromToken();
      final incomingUserId =
          profileData['_id'] as String? ?? profileData['id'] as String?;

      if (currentUserId == null || incomingUserId != currentUserId) {
        // This update is for a different user, ignore it
        return;
      }

      // Parse and save the updated profile
      final updatedProfile = UserProfile.fromJson(profileData);
      await _saveProfile(updatedProfile);

      // Update storeId if changed
      _storeId = updatedProfile.storeId;

      debugPrint('Profile updated from WebSocket: ${updatedProfile.fullName}');
    } catch (e) {
      debugPrint('Error updating profile from WebSocket: $e');
    }
  }

  /// Update role from WebSocket data (when role permissions change)
  /// This is called when a role_changed WebSocket message is received
  Future<void> updateRoleFromWebSocket(Map<String, dynamic> roleData) async {
    try {
      if (_profile == null) return;

      // Parse the new role data
      final roleName = roleData['name'] as String?;
      final roleId = roleData['_id'] as String? ?? roleData['id'] as String?;
      final permissions = roleData['permissions'] as Map<String, dynamic>?;

      // Create updated profile with new role
      final updatedProfile = UserProfile(
        id: _profile!.id,
        username: _profile!.username,
        email: _profile!.email,
        firstName: _profile!.firstName,
        lastName: _profile!.lastName,
        phone: _profile!.phone,
        role: roleName ?? _profile!.role,
        roleId: roleId ?? _profile!.roleId,
        permissions: permissions ?? _profile!.permissions,
        storeId: _profile!.storeId,
        store: _profile!.store,
        isAdmin: _profile!.isAdmin,
        isSuperAdmin: _profile!.isSuperAdmin,
        status: _profile!.status,
        avatar: _profile!.avatar,
        createdAt: _profile!.createdAt,
        updatedAt: DateTime.now(),
        lastLoginAt: _profile!.lastLoginAt,
        lastActiveAt: _profile!.lastActiveAt,
      );

      await _saveProfile(updatedProfile);
      debugPrint(
        'Role updated from WebSocket: ${updatedProfile.role} (permissions updated)',
      );
    } catch (e) {
      debugPrint('Error updating role from WebSocket: $e');
    }
  }

  /// Update store from WebSocket data (when store settings change)
  /// This is called when a store_updated WebSocket message is received
  Future<void> updateStoreFromWebSocket(Map<String, dynamic> storeData) async {
    try {
      if (_profile == null) return;

      // Parse the store data
      final storeId = storeData['_id'] as String? ?? storeData['id'] as String?;

      // Only update if this is the current user's store
      if (_profile!.storeId != storeId) {
        return;
      }

      // Create updated Store object
      final updatedStore = Store.fromJson(storeData);

      // Create updated profile with new store
      final updatedProfile = UserProfile(
        id: _profile!.id,
        username: _profile!.username,
        email: _profile!.email,
        firstName: _profile!.firstName,
        lastName: _profile!.lastName,
        phone: _profile!.phone,
        role: _profile!.role,
        roleId: _profile!.roleId,
        permissions: _profile!.permissions,
        storeId: storeId ?? _profile!.storeId,
        store: updatedStore,
        isAdmin: _profile!.isAdmin,
        isSuperAdmin: _profile!.isSuperAdmin,
        status: _profile!.status,
        avatar: _profile!.avatar,
        createdAt: _profile!.createdAt,
        updatedAt: DateTime.now(),
        lastLoginAt: _profile!.lastLoginAt,
        lastActiveAt: _profile!.lastActiveAt,
      );

      await _saveProfile(updatedProfile);
      debugPrint('Store updated from WebSocket: ${updatedStore.name}');
    } catch (e) {
      debugPrint('Error updating store from WebSocket: $e');
    }
  }

  // Get store ID
  String? getStoreId() {
    return _profile?.storeId ?? _storeId;
  }

  // Initialize store ID from storage (legacy method)
  Future<void> initializeStoreId() async {
    await initializeProfile();
  }

  // Save last login credentials (store slug and username)
  Future<void> _saveLastLoginCredentials(
    String storeSlug,
    String username,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_store_slug', storeSlug);
      await prefs.setString('last_username', username);
      _lastStoreSlug = storeSlug;
      _lastUsername = username;
    } catch (e) {
      debugPrint('Error saving last login credentials: $e');
    }
  }

  // Load last login credentials
  Future<void> _loadLastLoginCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastStoreSlug = prefs.getString('last_store_slug');
      _lastUsername = prefs.getString('last_username');
    } catch (e) {
      debugPrint('Error loading last login credentials: $e');
    }
  }

  // Get last store slug
  String? getLastStoreSlug() {
    return _lastStoreSlug;
  }

  // Get last username
  String? getLastUsername() {
    return _lastUsername;
  }

  // Logout - clear auth token and profile, but keep login credentials
  Future<void> logout() async {
    await _httpService.setAuthToken(null);
    _isAuthenticated = false;
    _profile = null;
    _storeId = null;
    // Note: We keep last login credentials (store slug and username) for convenience

    // Clear from storage (except login credentials)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_profile');
      await prefs.remove('store_id');
      // Note: We don't remove last_store_slug and last_username
      // These will be used to auto-populate the login form
    } catch (e) {
      debugPrint('Error clearing profile from storage: $e');
    }
  }

  // Clear cached auth status (force re-check)
  void clearAuthCache() {
    _isAuthenticated = null;
  }

  // Fetch user profile from API
  Future<UserProfile> fetchProfile() async {
    try {
      final response = await _httpService.get(ApiConstants.userProfile);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final success = jsonResponse['success'] as bool? ?? false;

        if (success) {
          final data = jsonResponse['data'] as Map<String, dynamic>?;

          if (data == null) {
            throw Exception('Profile data is null');
          }

          // Log data structure for debugging
          debugPrint('Profile API response structure:');
          debugPrint('  - Has store: ${data.containsKey('store')}');
          debugPrint('  - Store type: ${data['store']?.runtimeType}');
          debugPrint('  - Has role: ${data.containsKey('role')}');
          debugPrint('  - Role type: ${data['role']?.runtimeType}');
          debugPrint('  - Has storeId: ${data.containsKey('storeId')}');

          // Create user profile (fromJson handles role as string or object, store as string or object)
          _profile = UserProfile.fromJson(data);

          // Verify profile was created successfully
          if (_profile == null) {
            throw Exception('Failed to create profile from API response');
          }

          // Update storeId
          _storeId = _profile?.storeId;

          // Log successful profile creation
          debugPrint('Profile fetched successfully:');
          debugPrint('  - User ID: ${_profile!.id}');
          debugPrint('  - Username: ${_profile!.username}');
          debugPrint('  - Store ID: ${_profile!.storeId}');
          debugPrint('  - Store Name: ${_profile!.storeName}');
          debugPrint('  - Role: ${_profile!.role}');

          // Save to storage
          await _saveProfile(_profile!);

          return _profile!;
        } else {
          final message =
              jsonResponse['message'] as String? ?? 'Failed to fetch profile';
          throw Exception(message);
        }
      } else {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
        final message =
            errorBody?['message'] as String? ??
            'Failed to fetch profile. Please try again.';
        throw Exception(message);
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      rethrow;
    }
  }
}
