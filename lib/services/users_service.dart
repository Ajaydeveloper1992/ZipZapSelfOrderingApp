import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:zipzap_pos_self_orders/core/services/http_service.dart';
import 'package:zipzap_pos_self_orders/models/staff_member.dart';

class UsersService {
  static final UsersService _instance = UsersService._internal();
  factory UsersService() => _instance;
  UsersService._internal();

  final HttpService _httpService = HttpService();

  /// Fetch all active staff members for the current user's store. Used to
  /// populate the "Server" dropdown when creating a dine-in order.
  Future<List<StaffMember>> getStaff({String? storeId}) async {
    try {
      final queryParams = <String, String>{'limit': '100', 'status': 'active'};
      if (storeId != null && storeId.isNotEmpty) {
        queryParams['storeId'] = storeId;
      }

      final response = await _httpService.get(
        '/users/staff',
        queryParams: queryParams,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final dataList = (jsonResponse['data'] as List?) ?? const [];

        final staff = dataList
            .whereType<Map<String, dynamic>>()
            .map(StaffMember.fromJson)
            .where((s) => s.id.isNotEmpty)
            .toList();

        debugPrint('Staff fetched: ${staff.length} members');
        return staff;
      }

      final errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
      final message =
          errorBody?['message'] as String? ?? 'Failed to fetch staff';
      throw Exception(message);
    } catch (e) {
      debugPrint('Error fetching staff: $e');
      rethrow;
    }
  }
}
