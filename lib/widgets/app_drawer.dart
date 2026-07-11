import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:zipzap_pos_self_orders/core/services/auth_service.dart';
import 'package:zipzap_pos_self_orders/core/services/websocket_service.dart';
import 'package:zipzap_pos_self_orders/providers/data_provider.dart';
import 'package:zipzap_pos_self_orders/widgets/auth_wrapper.dart';
import 'package:zipzap_pos_self_orders/core/constants/api_constants.dart';
import 'package:zipzap_pos_self_orders/widgets/app_toast.dart';
import 'package:zipzap_pos_self_orders/core/services/time_clock_service.dart';
import 'package:zipzap_pos_self_orders/widgets/pin_confirmation_dialog.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final DataProvider _dataProvider = DataProvider();
  final AuthService _authService = AuthService();
  String? _storeName;
  String? _storeLogo;
  bool _isLoading = true;
  bool _isTakeoutEnabled = true;
  bool _isDineInEnabled = true;
  bool _hasFloorPlanPermission = false;
  final TimeClockService _timeClockService = TimeClockService();
  String _clockStatus = '';

  @override
  void initState() {
    super.initState();
    _setupDataProviderListener();
    _loadStoreData();
    _updateFloorPlanPermission();
    _loadClockStatus();
  }

  @override
  void dispose() {
    _dataProvider.removeListener(_onDataUpdate);
    super.dispose();
  }

  void _setupDataProviderListener() {
    _dataProvider.addListener(_onDataUpdate);
  }

  void _onDataUpdate() {
    // Update store data when DataProvider notifies
    if (mounted) {
      _updateStoreFromProvider();
      _updateFloorPlanPermission();
    }
  }

  void _updateStoreFromProvider() {
    setState(() {
      final store = _dataProvider.store;
      if (store != null) {
        _storeName = store.name;
        _storeLogo = store.logo;
        _isLoading = false;
        final servicesOffered = store.servicesOffered;
        if (servicesOffered != null) {
          _isTakeoutEnabled =
              servicesOffered['pickUp'] == true ||
              servicesOffered['delivery'] == true;
          _isDineInEnabled = servicesOffered['dineIn'] == true;
        }
      } else if (!_dataProvider.isLoadingStore) {
        // Only set loading to false if not currently loading
        _isLoading = false;
      }
    });
  }

  void _updateFloorPlanPermission() {
    final profile = _authService.getProfile();
    setState(() {
      _hasFloorPlanPermission = profile?.canReadFloorPlans ?? false;
    });
  }

  Future<void> _loadClockStatus() async {
    try {
      final entry = await _timeClockService.getStatus();
      if (mounted) {
        setState(() {
          _clockStatus = entry?.status ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading clock status: $e');
    }
  }

  Future<void> _loadStoreData() async {
    try {
      // Trigger DataProvider to load store if not already loaded
      if (_dataProvider.store == null && !_dataProvider.isLoadingStore) {
        await _dataProvider.loadStore();
      }

      // Update from provider
      _updateStoreFromProvider();
    } catch (e) {
      debugPrint('Error loading store data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _menuItems {
    final items = <Map<String, dynamic>>[];

    if (_isTakeoutEnabled) {
      items.add({
        'title': 'Takeout',
        'icon': Icons.shopping_bag,
        'route': '/takeout',
      });
    }

    // Show Dine-In only if service is enabled AND user has floor_plans permission
    if (_isDineInEnabled && _hasFloorPlanPermission) {
      items.add({
        'title': 'Dine-In',
        'icon': Icons.table_restaurant,
        'route': '/dinein',
      });
    }

    items.addAll([
      {'title': 'All Orders', 'icon': Icons.shopping_cart, 'route': '/orders'},
      {
        'title': 'Pre-Pay Order',
        'icon': Icons.inventory_2,
        'route': '/orders/new',
        'arguments': {'orderType': ApiConstants.uiOrderTypePrepay},
      },
      {'title': 'Products', 'icon': Icons.checklist, 'route': '/products/list'},
      {'title': 'Categories', 'icon': Icons.list, 'route': '/categories/list'},
      {'title': 'Customers', 'icon': Icons.people, 'route': '/customers'},
      {'title': 'Report', 'icon': Icons.description, 'route': '/report'},
      {
        'title': 'Time Clock',
        'icon': Icons.access_time_rounded,
        'route': '#time_clock',
        'clockStatus': _clockStatus,
      },
      {'title': 'Settings', 'icon': Icons.settings, 'route': '/settings'},
      {'title': 'My Account', 'icon': Icons.person, 'route': '/profile'},
      {'title': 'Printer Settings', 'icon': Icons.print, 'route': '/printers'},
    ]);

    return items;
  }

  String? _getCurrentRoute(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route == null) return null;
    final settings = route.settings;
    if (settings.name != null) {
      return settings.name;
    }
    // Fallback: check if we're on home page
    if (route.isFirst) {
      return '/';
    }
    return null;
  }

  bool _isRouteActive(String route, String? currentRoute) {
    if (currentRoute == null) return false;
    if (route == '/' && currentRoute == '/') return true;
    if (route != '/' && currentRoute.startsWith(route)) return true;
    return false;
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    try {
      // Fetch fresh status from API to avoid stale in-memory state
      await _timeClockService.getStatus();

      if (_timeClockService.isClockedIn) {
        final clockedOut = await _showClockOutGuard(context);
        if (!clockedOut) return;
      }

      // Show confirmation dialog
      final shouldLogout = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Logout'),
            ),
          ],
        ),
      );

      if (shouldLogout != true) {
        return;
      }

      // Clear all API response data from DataProvider
      final dataProvider = DataProvider();
      dataProvider.clearAllData();

      // Disconnect WebSocket
      final webSocketService = WebSocketService();
      webSocketService.disconnect();

      // Logout from AuthService (keeps login credentials)
      final authService = AuthService();
      await authService.logout();

      // Clear clock-in state
      _timeClockService.clearStatus();

      // Navigate to root (AuthWrapper will show login page)
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error during logout: $e');
      if (context.mounted) {
        AppToast.error(
          context: context,
          title: 'Logout Error',
          description: 'Error during logout: $e',
        );
      }
    }
  }

  /// Returns true if clock-out succeeded or was not needed.
  Future<bool> _showClockOutGuard(BuildContext context) async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(
          Icons.access_time_rounded,
          size: 40,
          color: Colors.orange.shade700,
        ),
        title: const Text('Clock Out Required'),
        content: const Text(
          'You are currently clocked in. Please clock out before logging out.',
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('cancel'),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop('clockout'),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Clock Out'),
          ),
        ],
      ),
    );

    if (action != 'clockout' || !context.mounted) return false;

    final pin = await PinConfirmationDialog.show(
      context,
      title: 'Confirm Clock Out',
      description: 'Enter your PIN to clock out',
    );
    if (pin == null || !context.mounted) return false;

    final result = await _timeClockService.clockOut(pin: pin);
    if (result.success) {
      if (context.mounted) {
        AppToast.success(
          context: context,
          title: 'Clocked Out',
          description: result.message,
        );
      }
      return true;
    } else {
      if (context.mounted) {
        AppToast.error(
          context: context,
          title: 'Clock Out Failed',
          description: result.message,
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = _getCurrentRoute(context);
    final hasStoreData = _storeName != null && _storeLogo != null;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Header Section - Store or Zipzap Branding
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 60,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : hasStoreData
                  ? _buildStoreHeader(context)
                  : _buildZipzapHeader(context),
            ),
            // Menu Items
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(4),
                itemCount: _menuItems.length,
                itemBuilder: (context, index) {
                  final item = _menuItems[index];
                  final route = item['route'] as String;
                  final arguments = item['arguments'] as Map<String, dynamic>?;
                  final isSelected = _isRouteActive(route, currentRoute);
                  final clockStatus = item['clockStatus'] as String?;
                  return _buildMenuItem(
                    context,
                    title: item['title'] as String,
                    icon: item['icon'] as IconData,
                    route: route,
                    arguments: arguments,
                    isSelected: isSelected,
                    isLast: index == _menuItems.length - 1,
                    clockStatus: clockStatus,
                  );
                },
              ),
            ),
            // Logout Button
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _handleLogout(context);
                  },
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('Logout', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Store Logo and Name
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                _storeLogo!,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.store,
                      size: 20,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _storeName!,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Powered by Zipzap',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Zipzap Link
        InkWell(
          onTap: () => _launchUrl('https://zipzappos.com'),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/images/zipzap-icon.svg',
                  width: 16,
                  height: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'zipzappos.com',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.open_in_new,
                  size: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildZipzapHeader(BuildContext context) {
    return InkWell(
      onTap: () => _launchUrl('https://zipzappos.com'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SvgPicture.asset(
              'assets/images/zipzap-icon.svg',
              width: 40,
              height: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Zipzap POS',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'zipzappos.com',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.open_in_new,
              size: 16,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String route,
    Map<String, dynamic>? arguments,
    required bool isSelected,
    required bool isLast,
    String? clockStatus,
  }) {
    final leftBorderWidth = 4.0;
    final horizontalPadding = 8.0;
    final height = 36.0;
    final fontSize = 12.0;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pop(context);
            if (route == '#time_clock') {
              return;
            }
            if (route != '#') {
              if (arguments != null) {
                Navigator.pushNamed(context, route, arguments: arguments);
              } else {
                Navigator.pushNamed(context, route);
              }
            }
          },
          borderRadius: BorderRadius.circular(8),
          splashColor: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
              : Colors.grey.shade200,
          highlightColor: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.05)
              : Colors.grey.shade100,
          child: Container(
            height: height,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                  : Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.025),
              borderRadius: BorderRadius.circular(6),
              border: isSelected
                  ? Border(
                      left: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: leftBorderWidth,
                      ),
                      top: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1,
                      ),
                      right: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1,
                      ),
                      bottom: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1,
                      ),
                    )
                  : Border(
                      left: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: leftBorderWidth,
                      ),
                    ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (clockStatus != null && clockStatus.isNotEmpty)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(left: 6),
                    decoration: BoxDecoration(
                      color: clockStatus == 'on_break'
                          ? Colors.amber.shade600
                          : Colors.green.shade600,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
