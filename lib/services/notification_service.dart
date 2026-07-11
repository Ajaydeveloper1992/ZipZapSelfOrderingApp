import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Android settings
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );

      // iOS settings
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // Initialize
      final result = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      if (result == true) {
        _isInitialized = true;
        debugPrint('✅ Notification service initialized successfully');

        // Request permissions for iOS
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          await _requestIOSPermissions();
        }
      } else {
        debugPrint('❌ Failed to initialize notification service');
      }
    } catch (e) {
      debugPrint('❌ Error initializing notification service: $e');
    }
  }

  /// Request iOS permissions
  Future<void> _requestIOSPermissions() async {
    await _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // You can add navigation logic here if needed
  }

  /// Show a notification for a new web order
  Future<void> showNewWebOrderNotification({
    required String orderNumber,
    required String customerName,
    required double totalAmount,
    String? origin,
  }) async {
    if (!_isInitialized) {
      debugPrint('⚠️ Notification service not initialized');
      return;
    }

    try {
      // Format origin
      String originText = '';
      if (origin == 'AI') {
        originText = '🤖 AI Order';
      } else if (origin == 'WEB') {
        originText = '🌐 Web Order';
      } else {
        originText = '📱 Online Order';
      }

      // Android notification details
      const androidDetails = AndroidNotificationDetails(
        'web_orders',
        'Web Orders',
        channelDescription: 'Notifications for new web orders',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(''),
      );

      // iOS notification details
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Generate unique notification ID using timestamp
      final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(
        100000,
      );

      // Show notification
      await _notifications.show(
        notificationId,
        '🎉 New $originText Received!',
        'Order #$orderNumber from $customerName - \$${totalAmount.toStringAsFixed(2)}',
        notificationDetails,
        payload: 'order:$orderNumber',
      );

      debugPrint('✅ Notification shown for order #$orderNumber');
    } catch (e) {
      debugPrint('❌ Error showing notification: $e');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }
}
