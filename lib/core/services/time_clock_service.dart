import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:zipzap_pos_self_orders/core/services/http_service.dart';
import 'package:zipzap_pos_self_orders/models/time_clock_model.dart';

class TimeClockService {
  static final TimeClockService _instance = TimeClockService._internal();
  factory TimeClockService() => _instance;
  TimeClockService._internal();

  final HttpService _httpService = HttpService();
  static const String _basePath = '/time-clock';

  TimeClockEntry? _currentEntry;
  TimeClockEntry? get currentEntry => _currentEntry;
  bool get isClockedIn => _currentEntry?.isClockedIn ?? false;

  Future<TimeClockEntry?> getStatus() async {
    try {
      final response = await _httpService.get('$_basePath/status');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        if (json['success'] == true && json['data'] != null) {
          _currentEntry = TimeClockEntry.fromJson(
            json['data'] as Map<String, dynamic>,
          );
          return _currentEntry;
        }
        _currentEntry = null;
        return null;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting clock status: $e');
      return null;
    }
  }

  Future<({bool success, String message, TimeClockEntry? entry})> clockIn({
    required String storeId,
    required String pin,
    String? note,
  }) async {
    try {
      final body = <String, dynamic>{'store': storeId, 'pin': pin};
      if (note != null && note.trim().isNotEmpty) {
        body['note'] = note.trim();
      }

      final response = await _httpService.post(
        '$_basePath/clock-in',
        body: body,
      );

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final success = json['success'] == true;
      final message = json['message'] as String? ?? 'Unknown error';

      if (success && json['data'] != null) {
        _currentEntry = TimeClockEntry.fromJson(
          json['data'] as Map<String, dynamic>,
        );
        return (success: true, message: message, entry: _currentEntry);
      }

      return (success: false, message: message, entry: null);
    } catch (e) {
      debugPrint('Error clocking in: $e');
      return (
        success: false,
        message: e.toString().replaceFirst('Exception: ', ''),
        entry: null,
      );
    }
  }

  Future<ClockOutResult> clockOut({required String pin, String? note}) async {
    try {
      final body = <String, dynamic>{'pin': pin};
      if (note != null && note.trim().isNotEmpty) {
        body['note'] = note.trim();
      }

      final response = await _httpService.post(
        '$_basePath/clock-out',
        body: body,
      );

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final success = json['success'] == true;
      final message = json['message'] as String? ?? 'Unknown error';
      final hasActiveOrders = json['hasActiveOrders'] == true;
      final activeOrderCount = (json['activeOrders'] as List?)?.length ?? 0;

      if (success && json['data'] != null) {
        _currentEntry = TimeClockEntry.fromJson(
          json['data'] as Map<String, dynamic>,
        );
        return ClockOutResult(
          success: true,
          message: message,
          entry: _currentEntry,
        );
      }

      return ClockOutResult(
        success: false,
        message: message,
        hasActiveOrders: hasActiveOrders,
        activeOrderCount: activeOrderCount,
      );
    } catch (e) {
      debugPrint('Error clocking out: $e');
      return ClockOutResult(
        success: false,
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<({bool success, String message})> startBreak({
    required String pin,
  }) async {
    try {
      final response = await _httpService.post(
        '$_basePath/break-start',
        body: {'pin': pin},
      );

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final success = json['success'] == true;
      final message = json['message'] as String? ?? 'Unknown error';

      if (success && json['data'] != null) {
        _currentEntry = TimeClockEntry.fromJson(
          json['data'] as Map<String, dynamic>,
        );
      }

      return (success: success, message: message);
    } catch (e) {
      debugPrint('Error starting break: $e');
      return (
        success: false,
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<({bool success, String message})> endBreak({
    required String pin,
  }) async {
    try {
      final response = await _httpService.post(
        '$_basePath/break-end',
        body: {'pin': pin},
      );

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final success = json['success'] == true;
      final message = json['message'] as String? ?? 'Unknown error';

      if (success && json['data'] != null) {
        _currentEntry = TimeClockEntry.fromJson(
          json['data'] as Map<String, dynamic>,
        );
      }

      return (success: success, message: message);
    } catch (e) {
      debugPrint('Error ending break: $e');
      return (
        success: false,
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<List<StoreStaffMember>> getStoreStaff() async {
    try {
      final response = await _httpService.get('$_basePath/store-staff');

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['success'] == true && json['data'] != null) {
        return (json['data'] as List)
            .map((e) => StoreStaffMember.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting store staff: $e');
      return [];
    }
  }

  Future<({bool success, String message, int transferredCount})>
  transferOrders({required String targetStaffId, required String pin}) async {
    try {
      final response = await _httpService.post(
        '$_basePath/transfer-orders',
        body: {'targetStaffId': targetStaffId, 'pin': pin},
      );

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final success = json['success'] == true;
      final message = json['message'] as String? ?? 'Unknown error';
      final count = json['transferredCount'] as int? ?? 0;

      return (success: success, message: message, transferredCount: count);
    } catch (e) {
      debugPrint('Error transferring orders: $e');
      return (
        success: false,
        message: e.toString().replaceFirst('Exception: ', ''),
        transferredCount: 0,
      );
    }
  }

  void clearStatus() {
    _currentEntry = null;
  }
}

class ClockOutResult {
  final bool success;
  final String message;
  final TimeClockEntry? entry;
  final bool hasActiveOrders;
  final int activeOrderCount;

  ClockOutResult({
    required this.success,
    required this.message,
    this.entry,
    this.hasActiveOrders = false,
    this.activeOrderCount = 0,
  });
}

class StoreStaffMember {
  final String id;
  final String firstName;
  final String? lastName;
  final String? username;
  final String? avatar;
  final String? clockStatus;

  StoreStaffMember({
    required this.id,
    required this.firstName,
    this.lastName,
    this.username,
    this.avatar,
    this.clockStatus,
  });

  String get fullName => lastName != null && lastName!.isNotEmpty
      ? '$firstName $lastName'
      : firstName;

  bool get isClockedIn => clockStatus != null;

  factory StoreStaffMember.fromJson(Map<String, dynamic> json) {
    return StoreStaffMember(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String?,
      username: json['username'] as String?,
      avatar: json['avatar'] as String?,
      clockStatus: json['clockStatus'] as String?,
    );
  }
}
