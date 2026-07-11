import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:zipzap_pos_self_orders/core/constants/api_constants.dart';

/// WebSocket connection status
enum WebSocketStatus { connecting, connected, disconnected, error }

/// WebSocket event types
enum WebSocketEventType {
  profileUpdated('profile_updated'),
  orderCreated('order_created'),
  orderUpdated('order_updated'),
  orderStatusChanged('order_status_changed'),
  customerCreated('customer_created'),
  customerUpdated('customer_updated'),
  productUpdated('product_updated'),
  categoryUpdated('category_updated'),
  storeUpdated('store_updated'),
  floorPlanUpdated('floor_plan_updated'),
  tableStatusUpdated('table_status_updated'),
  userJoined('user_joined'),
  userLeft('user_left'),
  generalNotification('general_notification'),
  ping('ping'),
  pong('pong'),
  serverStatus('server_status');

  final String value;
  const WebSocketEventType(this.value);
}

/// WebSocket message model
class WebSocketMessage {
  final String type;
  final Map<String, dynamic>? data;
  final String timestamp;
  final String? userId;
  final String? storeId;
  final String? sessionId;

  WebSocketMessage({
    required this.type,
    this.data,
    required this.timestamp,
    this.userId,
    this.storeId,
    this.sessionId,
  });

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    return WebSocketMessage(
      type: json['type'] as String? ?? '',
      data: json['data'] as Map<String, dynamic>?,
      timestamp: json['timestamp'] as String? ?? '',
      userId: json['userId'] as String?,
      storeId: json['storeId'] as String?,
      sessionId: json['sessionId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'data': data,
      'timestamp': timestamp,
      if (userId != null) 'userId': userId,
      if (storeId != null) 'storeId': storeId,
      if (sessionId != null) 'sessionId': sessionId,
    };
  }
}

/// WebSocket service with auto-reconnect, ping/pong, and exponential backoff
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  StreamController<WebSocketMessage>? _messageController;

  Timer? _pingTimer;
  Timer? _pingTimeoutTimer;
  Timer? _reconnectTimer;
  Timer? _serverRecoveryTimer;

  WebSocketStatus _status = WebSocketStatus.disconnected;
  bool _isConnected = false;
  bool _isServerDown = false;
  bool _isReconnecting = false;
  bool _hasReachedMaxAttempts = false;

  int _reconnectAttempts = 0;
  int _lastPongTime = 0;
  String? _lastUserId;
  String? _lastStoreId;

  // Configuration
  static const bool autoConnect = true;
  static const bool autoReconnect = true;
  static const int reconnectInterval = 5000; // 5 seconds base delay
  static const int maxReconnectAttempts = 5;
  static const int pingInterval = 30000; // 30 seconds when connected
  static const int pingTimeout = 10000; // 10 seconds timeout for ping response
  static const bool exponentialBackoff = true;
  static const int maxReconnectDelay = 30000; // 30 seconds max delay

  // Getters
  WebSocketStatus get status => _status;
  bool get isConnected => _isConnected;
  bool get isServerDown => _isServerDown;
  int get reconnectAttempts => _reconnectAttempts;
  int get lastPongTime => _lastPongTime;

  // Message stream
  Stream<WebSocketMessage> get messages {
    _messageController ??= StreamController<WebSocketMessage>.broadcast();
    return _messageController!.stream;
  }

  // Initialize message controller if not already initialized
  void _ensureMessageController() {
    _messageController ??= StreamController<WebSocketMessage>.broadcast();
  }

  // Calculate reconnect delay with exponential backoff
  int _getReconnectDelay() {
    if (!exponentialBackoff) {
      return reconnectInterval;
    }

    final baseDelay = reconnectInterval;
    final maxDelay = maxReconnectDelay;
    final attempt = _reconnectAttempts;

    // Exponential backoff: baseDelay * 2^attempt, capped at maxDelay
    final delay = (baseDelay * (1 << attempt)).clamp(0, maxDelay);

    // Add some jitter to prevent thundering herd
    final jitter = (DateTime.now().millisecondsSinceEpoch % 1000);
    return delay + jitter;
  }

  // Send ping to server
  void _sendPing() {
    if (_channel != null && _isConnected) {
      try {
        final message = WebSocketMessage(
          type: WebSocketEventType.ping.value,
          data: {'ping': true},
          timestamp: DateTime.now().toIso8601String(),
        );
        _channel!.sink.add(jsonEncode(message.toJson()));

        // Set timeout for pong response
        _pingTimeoutTimer?.cancel();
        _pingTimeoutTimer = Timer(Duration(milliseconds: pingTimeout), () {
          debugPrint('Ping timeout - no pong response received');
          _isServerDown = true;
          disconnect(clearCredentials: false);
        });
      } catch (error) {
        debugPrint('Error sending ping: $error');
      }
    }
  }

  // Start ping interval
  void _startPingInterval() {
    _pingTimer?.cancel();
    _sendPing(); // Send initial ping
    _pingTimer = Timer.periodic(
      Duration(milliseconds: pingInterval),
      (_) => _sendPing(),
    );
  }

  // Stop ping interval
  void _stopPingInterval() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _pingTimeoutTimer?.cancel();
    _pingTimeoutTimer = null;
  }

  // Connect to WebSocket
  Future<void> connect({String? userId, String? storeId}) async {
    // Keep latest auth for reconnect flows (retries, recovery timer, app resume).
    if (userId != null && userId.isNotEmpty) {
      _lastUserId = userId;
    }
    if (storeId != null && storeId.isNotEmpty) {
      _lastStoreId = storeId;
    }

    final effectiveUserId = userId ?? _lastUserId;
    final effectiveStoreId = storeId ?? _lastStoreId;

    // Prevent multiple simultaneous connection attempts
    if (_isReconnecting || _isConnected || _hasReachedMaxAttempts) {
      return;
    }

    try {
      _isReconnecting = true;
      _status = WebSocketStatus.connecting;
      _isConnected = false;

      // Build WebSocket URL (no token needed in URL)
      final uri = Uri.parse(ApiConstants.websocketUrl);
      debugPrint('🔄 Connecting to WebSocket: ${uri.toString()}');
      debugPrint(
        '   With userId: ${effectiveUserId ?? "not provided"}, storeId: ${effectiveStoreId ?? "not provided"}',
      );

      // Ensure message controller is initialized before connecting
      _ensureMessageController();

      _channel = WebSocketChannel.connect(uri);

      // Set up message listener (similar to ws.onmessage in Next.js)
      _channel!.stream.listen(
        (message) {
          debugPrint('WebSocket RAW message received: $message');
          try {
            final json = jsonDecode(message as String) as Map<String, dynamic>;
            final messageType = json['type'] as String?;
            debugPrint('WebSocket message parsed: type=$messageType');

            // Log order_created messages specifically
            if (messageType == 'order_created') {
              debugPrint('*** ORDER_CREATED MESSAGE RECEIVED ***');
              debugPrint('Full message: $message');
            }

            final wsMessage = WebSocketMessage.fromJson(json);
            _messageController?.add(wsMessage);
            _handleMessage(wsMessage);
          } catch (error) {
            debugPrint('Error parsing WebSocket message: $error');
            debugPrint('Raw message: $message');
          }
        },
        onError: (error) {
          debugPrint('WebSocket stream error: $error');
          _status = WebSocketStatus.error;
          _isConnected = false;
          _stopPingInterval();
          _isReconnecting = false;
        },
        onDone: () {
          debugPrint('WebSocket connection closed');
          _status = WebSocketStatus.disconnected;
          _isConnected = false;
          _stopPingInterval();
          _isReconnecting = false;

          // Increment reconnect attempts
          _reconnectAttempts++;

          // Attempt to reconnect if auto-reconnect is enabled
          if (autoReconnect &&
              _reconnectAttempts <= maxReconnectAttempts &&
              !_hasReachedMaxAttempts) {
            final delay = _getReconnectDelay();
            debugPrint(
              'Attempting to reconnect in ${(delay / 1000).round()}s ($_reconnectAttempts/$maxReconnectAttempts)...',
            );

            _reconnectTimer?.cancel();
            _reconnectTimer = Timer(Duration(milliseconds: delay), () {
              if (_reconnectAttempts >= maxReconnectAttempts) {
                _hasReachedMaxAttempts = true;
                _isServerDown = true;
                debugPrint(
                  'Max reconnection attempts reached. Server appears to be down.',
                );
                _startServerRecoveryCheck();
                return;
              }
              connect(userId: effectiveUserId, storeId: effectiveStoreId);
            });
          } else {
            _hasReachedMaxAttempts = true;
            _isServerDown = true;
            debugPrint(
              'Max reconnection attempts ($maxReconnectAttempts) reached. Server appears to be down.',
            );
            _startServerRecoveryCheck();
          }
        },
        cancelOnError: false,
      );

      // Connection opened (similar to ws.onopen in Next.js)
      // Note: WebSocketChannel.connect() connects immediately, but we need to wait
      // a bit to ensure the connection is fully established before sending auth
      _status = WebSocketStatus.connected;
      _isConnected = true;
      _isServerDown = false;
      _reconnectAttempts = 0;
      _hasReachedMaxAttempts = false;
      _lastPongTime = DateTime.now().millisecondsSinceEpoch;
      _isReconnecting = false;

      _stopServerRecoveryCheck();
      _startPingInterval();

      // Wait a small delay to ensure connection is fully established before authenticating
      // This ensures the server is ready to receive the authentication message
      await Future.delayed(const Duration(milliseconds: 100));

      // Authenticate the connection with user and store info
      // This is critical - server filters messages based on authentication
      // Ensure storeId is converted to string to match API format

      if (effectiveUserId != null && effectiveStoreId != null) {
        final authMessage = {
          'type': 'authenticate',
          'data': {
            'userId': effectiveUserId.toString(),
            'storeId': effectiveStoreId.toString(),
          },
        };

        debugPrint(
          '🔐 WebSocket authenticating: userId=$effectiveUserId, storeId=$effectiveStoreId',
        );
        try {
          _channel!.sink.add(jsonEncode(authMessage));
          debugPrint('✅ WebSocket authentication message sent successfully');
        } catch (error) {
          debugPrint('❌ Error sending authentication message: $error');
        }
      } else {
        debugPrint(
          '⚠️ WARNING: WebSocket connecting without userId/storeId - messages will be filtered!',
        );
        debugPrint(
          '   userId: ${effectiveUserId ?? "missing"}, storeId: ${effectiveStoreId ?? "missing"}',
        );
      }

      debugPrint('✅ WebSocket connected successfully');
    } catch (error) {
      _status = WebSocketStatus.error;
      _isConnected = false;
      _stopPingInterval();
      _isReconnecting = false;
      debugPrint('Error creating WebSocket connection: $error');
    }
  }

  // Handle incoming messages
  void _handleMessage(WebSocketMessage message) {
    switch (message.type) {
      case 'pong':
        debugPrint('🏓 Pong received from server');
        _lastPongTime = DateTime.now().millisecondsSinceEpoch;
        _isServerDown = false;
        _pingTimeoutTimer?.cancel();
        _pingTimeoutTimer = null;
        break;

      case 'ping':
        // Handle ping from server and send pong response
        sendMessage(
          WebSocketMessage(
            type: WebSocketEventType.pong.value,
            data: {'pong': true},
            timestamp: DateTime.now().toIso8601String(),
          ),
        );
        break;

      case 'general_notification':
        // Check for authentication confirmation
        if (message.data?['message']?.toString().contains(
              'Authentication successful',
            ) ==
            true) {
          debugPrint('✅ WebSocket authenticated successfully:');
          debugPrint('   sessionId: ${message.data?['sessionId']}');
          debugPrint('   userSessions: ${message.data?['userSessions']}');
          debugPrint('   storeSessions: ${message.data?['storeSessions']}');
        }
        break;

      case 'order_created':
        debugPrint('🆕 New order received via WebSocket');
        break;

      case 'order_updated':
        debugPrint('📦 Order update received via WebSocket');
        break;

      case 'user_joined':
        debugPrint('👋 User joined store via WebSocket');
        break;

      case 'user_left':
        debugPrint('🚪 User left store via WebSocket');
        break;

      case 'floor_plan_updated':
        debugPrint('🗺️ Floor plan update received via WebSocket');
        break;

      case 'table_status_updated':
        debugPrint('🪑 Table status update received via WebSocket');
        break;

      default:
        // Other messages are handled by listeners
        break;
    }
  }

  // Start server recovery check
  void _startServerRecoveryCheck() {
    _serverRecoveryTimer?.cancel();
    debugPrint(
      'Starting server recovery check - will attempt to reconnect every 5 seconds',
    );

    _serverRecoveryTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_hasReachedMaxAttempts && !_isConnected) {
        debugPrint('Server recovery check: attempting to reconnect...');
        _reconnectAttempts = 0;
        _hasReachedMaxAttempts = false;
        connect(userId: _lastUserId, storeId: _lastStoreId);
      }
    });
  }

  /// Force reconnect using latest known auth context.
  Future<void> reconnect({String? userId, String? storeId}) async {
    if (userId != null && userId.isNotEmpty) {
      _lastUserId = userId;
    }
    if (storeId != null && storeId.isNotEmpty) {
      _lastStoreId = storeId;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stopServerRecoveryCheck();
    _hasReachedMaxAttempts = false;
    _isServerDown = false;
    _reconnectAttempts = 0;
    _isReconnecting = false;

    await connect(userId: _lastUserId, storeId: _lastStoreId);
  }

  // Stop server recovery check
  void _stopServerRecoveryCheck() {
    _serverRecoveryTimer?.cancel();
    _serverRecoveryTimer = null;
  }

  // Disconnect from WebSocket
  void disconnect({bool clearCredentials = true}) {
    _stopPingInterval();
    _stopServerRecoveryCheck();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    _channel?.sink.close();
    _channel = null;

    _status = WebSocketStatus.disconnected;
    _isConnected = false;
    _isServerDown = false;
    _reconnectAttempts = 0;
    _hasReachedMaxAttempts = false;
    _isReconnecting = false;

    if (clearCredentials) {
      _lastUserId = null;
      _lastStoreId = null;
    }
  }

  // Send message to WebSocket
  void sendMessage(WebSocketMessage message) {
    if (_channel != null && _isConnected) {
      try {
        _channel!.sink.add(jsonEncode(message.toJson()));
      } catch (error) {
        debugPrint('Error sending WebSocket message: $error');
      }
    } else {
      debugPrint('WebSocket is not connected');
    }
  }

  // Dispose
  void dispose() {
    disconnect();
    _messageController?.close();
    _messageController = null;
  }
}
