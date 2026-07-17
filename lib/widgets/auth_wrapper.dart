import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:zipzap_pos_self_orders/core/services/auth_service.dart';
import 'package:zipzap_pos_self_orders/core/services/http_service.dart';
import 'package:zipzap_pos_self_orders/main.dart' show navigatorKey;
import 'package:zipzap_pos_self_orders/pages/auth/login_page.dart';
import 'package:zipzap_pos_self_orders/pages/home/home_page.dart';
import 'package:zipzap_pos_self_orders/providers/websocket_provider.dart';
import 'package:zipzap_pos_self_orders/providers/data_provider.dart';
import 'package:zipzap_pos_self_orders/widgets/splash_screen.dart';
import 'package:zipzap_pos_self_orders/services/app_update_service.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  final HttpService _httpService = HttpService();
  final WebSocketProvider _webSocketProvider = WebSocketProvider();
  final AppUpdateService _updateService = AppUpdateService();
  bool _isLoading = true;
  bool _isAuthenticated = false;
  bool _forceUpdateRequired = false;

  @override
  void initState() {
    super.initState();
    // Set up 401 unauthorized handler for auto-logout
    _httpService.setOnUnauthorized(_handleUnauthorized);
    _initializeApp();
  }

  @override
  void dispose() {
    // Clean up the callback
    _httpService.setOnUnauthorized(null);
    super.dispose();
  }

  // Handle 401 unauthorized - auto logout
  void _handleUnauthorized() {
    debugPrint('🔒 Handling 401 Unauthorized - Auto logging out');

    // Logout and disconnect
    _authService.logout();
    _webSocketProvider.disconnect();

    // Use post-frame callback to ensure UI is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Pop all routes back to root (AuthWrapper)
      final navigator = navigatorKey.currentState;
      if (navigator != null && navigator.canPop()) {
        debugPrint('🔒 Popping all routes to root');
        navigator.popUntil((route) => route.isFirst);
      }

      // Update UI to show login page
      if (mounted) {
        debugPrint('🔒 Setting _isAuthenticated = false');
        setState(() {
          _isAuthenticated = false;
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _initializeApp() async {
    // 1. Initialize profile from storage
    await _authService.initializeProfile();

    // 2. Remove native splash screen immediately so our custom SplashScreen is visible
    FlutterNativeSplash.remove();

    // 3. Check for app updates FIRST
    await _checkForUpdates();

    // If force update is required, don't proceed
    if (_forceUpdateRequired) {
      return;
    }

    // 4. Add a minimum delay to keep the custom splash screen visible
    await Future.delayed(const Duration(seconds: 1));

    // 5. Check authentication
    await _checkAuth();
  }

  Future<void> _checkForUpdates() async {
    final result = await _updateService.checkForUpdate();

    if (result != null && mounted) {
      // If force update required, clear session first
      if (result.isForceUpdate) {
        await _authService.logout();
        _webSocketProvider.disconnect();

        setState(() {
          _forceUpdateRequired = true;
          _isLoading = false;
          _isAuthenticated = false;
        });

        // Wait for next frame to ensure UI is built before showing dialog
        await Future.delayed(const Duration(milliseconds: 100));

        // Show update dialog (non-dismissible for force updates)
        if (mounted) {
          await _updateService.showUpdateDialog(context, result);
        }
        return;
      }

      // Optional update - show dialog, user can dismiss and continue
      if (mounted) {
        await _updateService.showUpdateDialog(context, result);
      }
    }
  }

  Future<void> _checkAuth() async {
    final isAuth = await _authService.isAuthenticated();
    if (mounted) {
      setState(() {
        _isAuthenticated = isAuth;
        _isLoading = false;
      });

      // Initialize DataProvider and connect WebSocket if authenticated
      if (isAuth) {
        // Initialize DataProvider to start loading data
        final dataProvider = DataProvider();
        await dataProvider.ensureInitialized();

        // Get userId from profile and storeId from DataProvider (source of truth for store)
        final profile = _authService.getProfile();
        final userId = profile?.id ?? _authService.getUserIdFromToken();

        // Get storeId from DataProvider's cached store (similar to NextJS Zustand store)
        final storeId =
            dataProvider.store?.id ??
            profile?.storeId ??
            _authService.getStoreId();

        debugPrint(
          'Connecting WebSocket: userId=$userId, storeId=$storeId (from store: ${dataProvider.store?.name})',
        );
        _webSocketProvider.connect(userId: userId, storeId: storeId);
      }
    }
  }

  // Callback to refresh auth state after login
  void _onLoginSuccess() async {
    _authService.clearAuthCache();

    // Check if authenticated
    final isAuth = await _authService.isAuthenticated();
    if (!isAuth || !mounted) return;

    // Start DataProvider reinitialization (this will set isInitialLoad flag)
    // but don't await it yet - let it run in background
    final dataProvider = DataProvider();
    final reinitFuture = dataProvider.reinitialize(forceRefresh: true);

    // Update UI state to show HomePage (which will show progress dialog)
    if (mounted) {
      setState(() {
        _isAuthenticated = true;
        _isLoading = false;
      });
    }

    // Now wait for data loading to complete
    await reinitFuture;

    // Connect WebSocket after data is loaded
    final profile = _authService.getProfile();
    final userId = profile?.id ?? _authService.getUserIdFromToken();
    final storeId =
        dataProvider.store?.id ?? profile?.storeId ?? _authService.getStoreId();

    debugPrint(
      'Reconnecting WebSocket after login: userId=$userId, storeId=$storeId (from store: ${dataProvider.store?.name})',
    );
    _webSocketProvider.connect(userId: userId, storeId: storeId);

    // Wait for progress dialog to finish its dismiss animation before
    // showing the clock-in prompt (progress dialog has a 300ms close delay)
    await Future.delayed(const Duration(milliseconds: 500));

    // Clock in/out is disabled in this app version.
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SplashScreen();
    }

    return _isAuthenticated
        ? const HomePage()
        : LoginPage(onLoginSuccess: _onLoginSuccess);
  }
}
