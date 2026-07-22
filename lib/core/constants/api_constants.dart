import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  static const String _apiBaseUrlFromDefine = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static const String _websocketUrlFromDefine = String.fromEnvironment(
    'WS_URL',
    defaultValue: '',
  );

  static String _getConfigValue(String key, String fallback) {
    if (key == 'API_BASE_URL' && _apiBaseUrlFromDefine.isNotEmpty) {
      return _apiBaseUrlFromDefine;
    }
    if (key == 'WS_URL' && _websocketUrlFromDefine.isNotEmpty) {
      return _websocketUrlFromDefine;
    }

    return dotenv.env[key] ?? fallback;
  }

  // Base URL for the API
  // Build-time define (--dart-define=API_BASE_URL=...) overrides .env.
  // .env is used at runtime for mobile installs.
  static String get baseUrl =>
      _getConfigValue('API_BASE_URL', 'http://localhost:8000/api/v1');

  // WebSocket URL
  // Build-time define (--dart-define=WS_URL=...) overrides .env.
  // .env is used at runtime for mobile installs.
  static String get websocketUrl =>
      _getConfigValue('WS_URL', 'ws://localhost:8000/ws');

  // Endpoints
  static const String orders = '/orders';
  static const String products = '/products/pos';
  static const String categories = '/categories';
  static const String customers = '/customers';
  static const String modifierGroups = '/modifier-groups';
  static const String modifiers = '/modifiers';
  static const String stores = '/stores';
  static const String reports = '/reports';
  static const String labels = '/labels';
  static const String taxRules = '/tax-rules';
  static const String pinLogin = '/users/pin-login';
  static const String userProfile = '/users/profile';
  static const String floorPlans = '/floor-plans';
  static const String timeClock = '/time-clock';
  static const String selfOrderRequests = '/self-order-requests';

  // Query Parameters
  static const String orderTypeParam = 'orderType';
  static const String orderStatusParam = 'orderstatus';

  // Order Types (API values)
  static const String orderTypePickup = 'Pickup';
  static const String orderTypeDelivery = 'Delivery';
  static const String orderTypeDineIn = 'Dine-in';

  // UI Order Types (user-facing values passed through routes/modals)
  static const String uiOrderTypeTakeout = 'takeout';
  static const String uiOrderTypeDelivery = 'delivery';
  static const String uiOrderTypeDineIn = 'dineIn';
  static const String uiOrderTypePrepay = 'prepay';

  // Order Statuses
  static const String orderStatusPending = 'Pending';
  static const String orderStatusInKitchen = 'InKitchen';
  static const String orderStatusReady = 'Ready';
  static const String orderStatusComplete = 'Complete';
  static const String orderStatusCancelled = 'Cancelled';
  static const String orderStatusRejected = 'Rejected';
  static const String orderStatusVoided = 'Voided';

  // Payment Statuses
  static const String paymentStatusPaid = 'Paid';
  static const String paymentStatusPending = 'Pending';
  static const String paymentStatusRefunded = 'Refunded';
  static const String paymentStatusVoided = 'Voided';

  // Cache Keys
  static const String cacheKeyTakeoutOrders = 'takeout_orders';
  static const String cacheKeyTakeoutOrdersTimestamp =
      'takeout_orders_timestamp';
  static const String cacheKeyOrderDetails = 'order_details_';
  static const String cacheKeyOrderDetailsTimestamp =
      'order_details_timestamp_';
  static const String cacheKeyProducts = 'products';
  static const String cacheKeyProductsTimestamp = 'products_timestamp';
  static const String cacheKeyCategories = 'categories';
  static const String cacheKeyCategoriesTimestamp = 'categories_timestamp';
  static const String cacheKeyCustomers = 'customers';
  static const String cacheKeyCustomersTimestamp = 'customers_timestamp';
  static const String cacheKeyModifierGroups = 'modifier_groups';
  static const String cacheKeyModifierGroupsTimestamp =
      'modifier_groups_timestamp';
  static const String cacheKeyModifiers = 'modifiers';
  static const String cacheKeyModifiersTimestamp = 'modifiers_timestamp';
  static const String cacheKeyLabels = 'labels';
  static const String cacheKeyLabelsTimestamp = 'labels_timestamp';
  static const String cacheKeyTaxRules = 'tax_rules';
  static const String cacheKeyTaxRulesTimestamp = 'tax_rules_timestamp';

  // Cache Duration (7 days)
  static const Duration cacheDuration = Duration(days: 7);

  // Session Duration (7 days)
  static const Duration sessionDuration = Duration(days: 7);
}
