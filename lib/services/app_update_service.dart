import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zipzap_pos_self_orders/core/constants/api_constants.dart';
import 'package:zipzap_pos_self_orders/core/services/auth_service.dart';
import 'package:zipzap_pos_self_orders/core/services/cache_service.dart';
import 'package:zipzap_pos_self_orders/core/services/http_service.dart';
import 'package:zipzap_pos_self_orders/providers/data_provider.dart';
import 'package:zipzap_pos_self_orders/core/services/websocket_service.dart';
import 'package:zipzap_pos_self_orders/main.dart' show navigatorKey;
import 'package:zipzap_pos_self_orders/widgets/auth_wrapper.dart';

class AppVersion {
  final String latestVersion;
  final String minVersion;
  final String? downloadUrl;
  final String? releaseNotes;
  final bool forceUpdate;

  AppVersion({
    required this.latestVersion,
    required this.minVersion,
    this.downloadUrl,
    this.releaseNotes,
    this.forceUpdate = false,
  });

  factory AppVersion.fromJson(Map<String, dynamic> json) {
    return AppVersion(
      latestVersion: json['latestVersion'] as String? ?? '1.0.0',
      minVersion: json['minVersion'] as String? ?? '1.0.0',
      downloadUrl: json['downloadUrl'] as String?,
      releaseNotes: json['releaseNotes'] as String?,
      forceUpdate: json['forceUpdate'] as bool? ?? false,
    );
  }
}

class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  final HttpService _httpService = HttpService();

  /// Get current platform name
  String _getPlatform() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'android'; // Default fallback
  }

  /// Compare two version strings (e.g., "1.2.3" vs "1.2.4")
  /// Returns: -1 if v1 < v2, 0 if equal, 1 if v1 > v2
  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // Pad shorter version with zeros
    while (parts1.length < parts2.length) {
      parts1.add(0);
    }
    while (parts2.length < parts1.length) {
      parts2.add(0);
    }

    for (int i = 0; i < parts1.length; i++) {
      if (parts1[i] < parts2[i]) return -1;
      if (parts1[i] > parts2[i]) return 1;
    }
    return 0;
  }

  /// Check for app updates
  Future<UpdateCheckResult?> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // Determine platform
      final platform = _getPlatform();

      // Call API endpoint for version info
      final response = await _httpService.get(
        '/app-release',
        queryParams: {'platform': platform},
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final data = json['data'] as Map<String, dynamic>?;

        if (data != null) {
          final appVersion = AppVersion.fromJson(data);

          final isUpdateAvailable =
              _compareVersions(currentVersion, appVersion.latestVersion) < 0;
          final isForceUpdate =
              _compareVersions(currentVersion, appVersion.minVersion) < 0 ||
              appVersion.forceUpdate;

          if (isUpdateAvailable) {
            return UpdateCheckResult(
              currentVersion: currentVersion,
              latestVersion: appVersion.latestVersion,
              downloadUrl: appVersion.downloadUrl,
              releaseNotes: appVersion.releaseNotes,
              isForceUpdate: isForceUpdate,
            );
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      return null;
    }
  }

  /// Logout user and clear all cache before update
  Future<void> _logoutAndClearCache() async {
    try {
      // Clear all API response data from DataProvider
      final dataProvider = DataProvider();
      dataProvider.clearAllData();

      // Disconnect WebSocket
      final webSocketService = WebSocketService();
      webSocketService.disconnect();

      // Logout from AuthService (preserves last_store_slug and last_username)
      final authService = AuthService();
      await authService.logout();

      // Clear specific cache keys (preserve login credentials for convenience)
      final cacheService = CacheService();
      await cacheService.remove(ApiConstants.cacheKeyTakeoutOrders);
      await cacheService.remove(ApiConstants.cacheKeyTakeoutOrdersTimestamp);
      await cacheService.remove(ApiConstants.cacheKeyProducts);
      await cacheService.remove(ApiConstants.cacheKeyProductsTimestamp);
      await cacheService.remove(ApiConstants.cacheKeyCategories);
      await cacheService.remove(ApiConstants.cacheKeyCategoriesTimestamp);
      await cacheService.remove(ApiConstants.cacheKeyCustomers);
      await cacheService.remove(ApiConstants.cacheKeyCustomersTimestamp);
      await cacheService.remove(ApiConstants.cacheKeyModifierGroups);
      await cacheService.remove(ApiConstants.cacheKeyModifierGroupsTimestamp);
      await cacheService.remove(ApiConstants.cacheKeyModifiers);
      await cacheService.remove(ApiConstants.cacheKeyModifiersTimestamp);
      await cacheService.remove(ApiConstants.cacheKeyLabels);
      await cacheService.remove(ApiConstants.cacheKeyLabelsTimestamp);
      await cacheService.remove(ApiConstants.cacheKeyTaxRules);
      await cacheService.remove(ApiConstants.cacheKeyTaxRulesTimestamp);
      await cacheService.remove('store_details');
      await cacheService.remove('store_details_timestamp');

      debugPrint('Successfully logged out and cleared all cache for update');

      // Navigate to login page
      final navigator = navigatorKey.currentState;
      if (navigator != null) {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error during logout and cache clear: $e');
    }
  }

  /// Show update dialog
  Future<void> showUpdateDialog(
    BuildContext context,
    UpdateCheckResult result,
  ) async {
    await showDialog(
      context: context,
      barrierDismissible: !result.isForceUpdate,
      builder: (context) => PopScope(
        canPop: !result.isForceUpdate,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.system_update,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Update Available'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A new version of Zipzap is available!',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          'v${result.currentVersion}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_forward, color: Colors.grey),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Latest',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          'v${result.latestVersion}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (result.releaseNotes != null) ...[
                const SizedBox(height: 12),
                Text(
                  "What's New:",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  result.releaseNotes!,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
              if (result.isForceUpdate) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This update is required to continue using the app.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (!result.isForceUpdate)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Later'),
              ),
            FilledButton.icon(
              onPressed:
                  result.downloadUrl != null && result.downloadUrl!.isNotEmpty
                  ? () async {
                      // Clear all data and logout before updating
                      await _logoutAndClearCache();

                      final uri = Uri.parse(result.downloadUrl!);
                      try {
                        // Try external app first (browser)
                        final launched = await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                        if (!launched) {
                          // Fallback to in-app browser
                          await launchUrl(
                            uri,
                            mode: LaunchMode.inAppBrowserView,
                          );
                        }
                      } catch (e) {
                        // Last resort: platform default
                        await launchUrl(uri);
                      }
                    }
                  : null,
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Update Now'),
            ),
          ],
        ),
      ),
    );
  }
}

class UpdateCheckResult {
  final String currentVersion;
  final String latestVersion;
  final String? downloadUrl;
  final String? releaseNotes;
  final bool isForceUpdate;

  UpdateCheckResult({
    required this.currentVersion,
    required this.latestVersion,
    this.downloadUrl,
    this.releaseNotes,
    this.isForceUpdate = false,
  });
}
