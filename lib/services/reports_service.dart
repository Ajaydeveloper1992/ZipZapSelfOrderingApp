import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:zipzap_pos_self_orders/core/constants/api_constants.dart';
import 'package:zipzap_pos_self_orders/core/services/http_service.dart';
import 'package:zipzap_pos_self_orders/models/report_model.dart';
import 'package:zipzap_pos_self_orders/utils/timezone_utils.dart';

class ReportsService {
  static final ReportsService _instance = ReportsService._internal();
  factory ReportsService() => _instance;
  ReportsService._internal();

  final HttpService _httpService = HttpService();

  /// Get daily report for a specific date
  /// [date] - The date to get the report for
  /// [storeId] - Optional store ID to filter the report
  /// [storeTimezone] - Optional IANA timezone string (e.g., 'America/Toronto')
  ///   If provided, the date will be formatted in this timezone.
  ///   This ensures that when the user picks "today", it uses the store's "today"
  ///   even if the device is in a different timezone.
  Future<ReportModel> getDailyReport({
    required DateTime date,
    String? storeId,
    String? storeTimezone,
  }) async {
    try {
      // Format date as YYYY-MM-DD in the store's timezone if provided
      final String dateString;
      if (storeTimezone != null && storeTimezone.isNotEmpty) {
        dateString = TimezoneUtils.formatDateStringInTimezone(
          date,
          storeTimezone,
        );
      } else {
        // Fallback to device local date formatting
        dateString =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      }

      // Build query parameters
      final queryParams = <String, String>{
        'reportType': 'daily',
        'includeVoided': 'true',
        'date': dateString,
      };

      // Add store ID if provided
      if (storeId != null) {
        queryParams['store'] = storeId;
      }

      // Make API call
      final response = await _httpService.get(
        ApiConstants.reports,
        queryParams: queryParams,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final success = jsonResponse['success'] as bool? ?? false;

        if (success) {
          final data = jsonResponse['data'] as Map<String, dynamic>;
          return ReportModel.fromJson(data);
        } else {
          final message =
              jsonResponse['message'] as String? ?? 'Failed to fetch report';
          throw Exception(message);
        }
      } else {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
        final message =
            errorBody?['message'] as String? ??
            'Failed to fetch report. Please try again.';
        throw Exception(message);
      }
    } catch (e) {
      debugPrint('Error fetching daily report: $e');
      rethrow;
    }
  }

  /// Get custom report for a date range
  /// [startDate] - The start date of the range
  /// [endDate] - The end date of the range
  /// [storeId] - Optional store ID to filter the report
  /// [storeTimezone] - Optional IANA timezone string (e.g., 'America/Toronto')
  ///   If provided, dates will be formatted in this timezone.
  Future<ReportModel> getCustomReport({
    required DateTime startDate,
    required DateTime endDate,
    String? storeId,
    String? storeTimezone,
  }) async {
    try {
      // Format dates as YYYY-MM-DD in the store's timezone if provided
      final String startDateString;
      final String endDateString;

      if (storeTimezone != null && storeTimezone.isNotEmpty) {
        startDateString = TimezoneUtils.formatDateStringInTimezone(
          startDate,
          storeTimezone,
        );
        endDateString = TimezoneUtils.formatDateStringInTimezone(
          endDate,
          storeTimezone,
        );
      } else {
        // Fallback to device local date formatting
        startDateString =
            '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
        endDateString =
            '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';
      }

      // Build query parameters
      final queryParams = <String, String>{
        'reportType': 'custom',
        'startDate': startDateString,
        'endDate': endDateString,
      };

      // Add store ID if provided
      if (storeId != null) {
        queryParams['store'] = storeId;
      }

      // Make API call
      final response = await _httpService.get(
        ApiConstants.reports,
        queryParams: queryParams,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final success = jsonResponse['success'] as bool? ?? false;

        if (success) {
          final data = jsonResponse['data'] as Map<String, dynamic>;
          return ReportModel.fromJson(data);
        } else {
          final message =
              jsonResponse['message'] as String? ?? 'Failed to fetch report';
          throw Exception(message);
        }
      } else {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
        final message =
            errorBody?['message'] as String? ??
            'Failed to fetch report. Please try again.';
        throw Exception(message);
      }
    } catch (e) {
      debugPrint('Error fetching custom report: $e');
      rethrow;
    }
  }

  /// Send report via email with the same params used for on-screen display
  Future<void> sendReportEmail({
    required String reportType,
    DateTime? date,
    DateTime? startDate,
    DateTime? endDate,
    String? storeId,
    String? storeTimezone,
    String? includeVoided,
    String? email,
  }) async {
    try {
      final queryParams = <String, String>{'reportType': reportType};

      String formatDate(DateTime d) {
        if (storeTimezone != null && storeTimezone.isNotEmpty) {
          return TimezoneUtils.formatDateStringInTimezone(d, storeTimezone);
        }
        return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      }

      if (date != null) {
        queryParams['date'] = formatDate(date);
      }
      if (startDate != null) {
        queryParams['startDate'] = formatDate(startDate);
      }
      if (endDate != null) {
        queryParams['endDate'] = formatDate(endDate);
      }
      if (storeId != null) {
        queryParams['store'] = storeId;
      }
      if (includeVoided != null) {
        queryParams['includeVoided'] = includeVoided;
      }
      if (email != null && email.isNotEmpty) {
        queryParams['email'] = email;
      }

      debugPrint('Sending report email with params: $queryParams');

      // Make API call
      final response = await _httpService.post(
        '${ApiConstants.reports}/send-email',
        queryParams: queryParams,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final success = jsonResponse['success'] as bool? ?? false;

        if (success) {
          debugPrint('Report email sent successfully');
          return;
        } else {
          final message =
              jsonResponse['message'] as String? ??
              'Failed to send report email';
          throw Exception(message);
        }
      } else {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>?;
        final message =
            errorBody?['message'] as String? ??
            'Failed to send report email. Please try again.';
        throw Exception(message);
      }
    } catch (e) {
      debugPrint('Error sending report email: $e');
      rethrow;
    }
  }
}
