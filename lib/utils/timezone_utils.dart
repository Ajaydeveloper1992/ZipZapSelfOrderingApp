import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Timezone utility for date/time display across the app.
/// All display methods format in the VIEWER'S LOCAL timezone for consistency.
/// API timestamps are stored in UTC and automatically converted to local.
class TimezoneUtils {
  static bool _initialized = false;

  /// Initialize timezone database. Call this once in main.dart.
  static void initialize() {
    if (!_initialized) {
      tz_data.initializeTimeZones();
      _initialized = true;
    }
  }

  /// Get a timezone location by IANA name (e.g., 'America/Toronto')
  /// Falls back to 'America/Toronto' if the timezone is invalid.
  static tz.Location getLocation(String timezone) {
    try {
      return tz.getLocation(timezone);
    } catch (e) {
      // Fallback to Toronto if timezone is invalid
      return tz.getLocation('America/Toronto');
    }
  }

  /// Convert a UTC DateTime to the specified timezone.
  static tz.TZDateTime toTimezone(DateTime utcDateTime, String timezone) {
    initialize(); // Ensure timezone database is initialized
    final location = getLocation(timezone);
    return tz.TZDateTime.from(utcDateTime.toUtc(), location);
  }

  /// Format a DateTime in a specific timezone (for store-timezone display if needed).
  /// [dateTime] - The DateTime to format (can be UTC or local)
  /// [timezone] - IANA timezone string (e.g., 'America/Toronto')
  /// [pattern] - DateFormat pattern (e.g., 'MMM dd, yyyy | hh:mm a')
  static String formatInTimezone(
    DateTime dateTime,
    String timezone,
    String pattern,
  ) {
    initialize();
    final tzDateTime = toTimezone(dateTime, timezone);
    return DateFormat(pattern).format(tzDateTime);
  }

  // ============================================================================
  // LOCAL TIMEZONE DISPLAY METHODS
  // These methods display times in the viewer's device local timezone.
  // ============================================================================

  /// Format a DateTime in the viewer's local timezone.
  /// [dateTime] - The DateTime to format (UTC timestamps are auto-converted)
  /// [pattern] - DateFormat pattern (e.g., 'MMM dd, yyyy | hh:mm a')
  static String formatLocal(DateTime dateTime, String pattern) {
    // toLocal() converts UTC to device local timezone
    return DateFormat(pattern).format(dateTime.toLocal());
  }

  /// Format order date for display in local timezone (e.g., "Jan 25, 2026 | 02:30 PM")
  static String formatOrderDateLocal(DateTime date) {
    return formatLocal(date, 'MMM dd, yyyy | hh:mm a');
  }

  /// Format order date only in local timezone (e.g., "Jan 25, 2026")
  static String formatOrderDateOnlyLocal(DateTime date) {
    return formatLocal(date, 'MMM dd, yyyy');
  }

  /// Format order time only in local timezone (e.g., "02:30 PM")
  static String formatOrderTimeLocal(DateTime date) {
    return formatLocal(date, 'hh:mm a');
  }

  /// Format for receipt printing in local timezone (e.g., "Jan 25, 2026, 14:30")
  static String formatForReceiptLocal(DateTime date) {
    return formatLocal(date, 'MMM dd, yyyy, HH:mm');
  }

  /// Format for placed at display in local timezone (e.g., "January 25, 2:30 PM")
  static String formatPlacedAtLocal(DateTime date) {
    return formatLocal(date, 'MMMM dd, h:mm a');
  }

  /// Format time only for pickup in local timezone (e.g., "2:30 PM")
  static String formatPickupTimeLocal(DateTime date) {
    return formatLocal(date, 'h:mm a');
  }

  // ============================================================================
  // API SERIALIZATION METHODS
  // Use these when sending dates to the backend.
  // ============================================================================

  /// Convert a DateTime to UTC ISO-8601 string for API payloads.
  /// Use this for all order date fields sent to the backend.
  /// [date] - DateTime to convert (can be local or UTC)
  /// Returns ISO-8601 string (e.g., "2025-03-20T13:42:00.000Z") or null
  ///
  /// Example:
  /// ```dart
  /// toUtcIsoString(DateTime.now()) // "2025-01-27T10:30:00.000Z"
  /// toUtcIsoString(null) // null
  /// ```
  static String? toUtcIsoString(DateTime? date) {
    if (date == null) return null;
    return date.toUtc().toIso8601String();
  }

  // ============================================================================
  // LEGACY STORE TIMEZONE METHODS (kept for backward compatibility)
  // ============================================================================

  /// Format order date for display (e.g., "Jan 25, 2026 | 02:30 PM")
  @Deprecated('Use formatOrderDateLocal instead for viewer local display')
  static String formatOrderDate(DateTime date, String timezone) {
    return formatInTimezone(date, timezone, 'MMM dd, yyyy | hh:mm a');
  }

  /// Format order date and time separately for display
  @Deprecated('Use formatOrderDateOnlyLocal instead for viewer local display')
  static String formatOrderDateOnly(DateTime date, String timezone) {
    return formatInTimezone(date, timezone, 'MMM dd, yyyy');
  }

  /// Format order time only (e.g., "02:30 PM")
  @Deprecated('Use formatOrderTimeLocal instead for viewer local display')
  static String formatOrderTime(DateTime date, String timezone) {
    return formatInTimezone(date, timezone, 'hh:mm a');
  }

  /// Format for receipt printing (e.g., "Jan 25, 2026, 14:30")
  @Deprecated('Use formatForReceiptLocal instead for viewer local display')
  static String formatForReceipt(DateTime date, String timezone) {
    return formatInTimezone(date, timezone, 'MMM dd, yyyy, HH:mm');
  }

  /// Format for placed at display (e.g., "January 25, 2:30 PM")
  @Deprecated('Use formatPlacedAtLocal instead for viewer local display')
  static String formatPlacedAt(DateTime date, String timezone) {
    return formatInTimezone(date, timezone, 'MMMM dd, h:mm a');
  }

  /// Format time only for pickup (e.g., "2:30 PM")
  @Deprecated('Use formatPickupTimeLocal instead for viewer local display')
  static String formatPickupTime(DateTime date, String timezone) {
    return formatInTimezone(date, timezone, 'h:mm a');
  }

  // ============================================================================
  // DATE FORMATTING FOR API REQUESTS
  // ============================================================================

  /// Format a DateTime as YYYY-MM-DD in a specific timezone.
  /// Use this when sending date strings to APIs where the date should represent
  /// a day in the store's timezone, not the device's timezone.
  /// [dateTime] - The DateTime to format (can be UTC or local)
  /// [timezone] - IANA timezone string (e.g., 'America/Toronto')
  static String formatDateStringInTimezone(DateTime dateTime, String timezone) {
    initialize();
    final tzDateTime = toTimezone(dateTime, timezone);
    return DateFormat('yyyy-MM-dd').format(tzDateTime);
  }

  /// Get the current date as YYYY-MM-DD in a specific timezone.
  /// Useful for getting "today" in the store's timezone.
  static String getTodayInTimezone(String timezone) {
    return formatDateStringInTimezone(DateTime.now().toUtc(), timezone);
  }
}
