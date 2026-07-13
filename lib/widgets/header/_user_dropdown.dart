import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/core/services/auth_service.dart';
import 'package:zipzap_pos_self_orders/core/services/websocket_service.dart';
import 'package:zipzap_pos_self_orders/core/services/time_clock_service.dart';
import 'package:zipzap_pos_self_orders/core/constants/api_constants.dart';
import 'package:zipzap_pos_self_orders/providers/data_provider.dart';
import 'package:zipzap_pos_self_orders/widgets/auth_wrapper.dart';
import 'package:zipzap_pos_self_orders/widgets/app_toast.dart';
import 'package:zipzap_pos_self_orders/widgets/pin_confirmation_dialog.dart';

class HeaderUserDropdown extends StatelessWidget {
  final String? userName;
  final bool showName;

  const HeaderUserDropdown({super.key, this.userName, this.showName = true});

  Future<void> _handleMenuItemSelected(
    BuildContext context,
    String value,
  ) async {
    switch (value) {
      case 'profile':
        Navigator.of(context).pushNamed('/profile');
        break;
      case 'settings':
        // Navigate to settings page
        debugPrint('Settings selected');
        // Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsPage()));
        break;
      case 'printers':
        Navigator.of(context).pushNamed('/printers');
        break;
      case 'logout':
        await _handleLogout(context);
        break;
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    try {
      final timeClockService = TimeClockService();

      // Fetch fresh status from API to avoid stale in-memory state
      await timeClockService.getStatus();

      if (timeClockService.isClockedIn) {
        final clockedOut = await _showClockOutGuard(context, timeClockService);
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
      timeClockService.clearStatus();

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

  Future<bool> _showClockOutGuard(
    BuildContext context,
    TimeClockService timeClockService,
  ) async {
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

    final result = await timeClockService.clockOut(pin: pin);
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

  Widget _buildAvatar(BuildContext context, String? avatar, String fullName) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: avatar != null
          ? ClipOval(
              child: Image.network(
                avatar.startsWith('http')
                    ? avatar
                    : '${ApiConstants.baseUrl}$avatar',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildAvatarIcon(context, fullName),
              ),
            )
          : _buildAvatarIcon(context, fullName),
    );
  }

  Widget _buildAvatarIcon(BuildContext context, String fullName) {
    final initials = fullName
        .split(' ')
        .take(2)
        .map((n) => n.isNotEmpty ? n[0].toUpperCase() : '')
        .join();
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final profile = authService.getProfile();
    final displayName = userName ?? profile?.fullName ?? 'User';
    final role = profile?.role;
    final avatar = profile?.avatar;

    return PopupMenuButton<String>(
      color: Colors.white,
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      onSelected: (value) => _handleMenuItemSelected(context, value),
      offset: const Offset(-2, 44),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'printers',
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.print, size: 16),
              const SizedBox(width: 8),
              const Text('Printer Settings'),
            ],
          ),
        ),
        // PopupMenuItem(
        //   value: 'profile',
        //   height: 40,
        //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        //   child: Row(
        //     children: [
        //       const Icon(Icons.person, size: 16),
        //       const SizedBox(width: 8),
        //       const Text('My Profile'),
        //     ],
        //   ),
        // ),
        // const PopupMenuDivider(height: 1),
        // PopupMenuItem(
        //   value: 'settings',
        //   height: 40,
        //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        //   child: Row(
        //     children: [
        //       const Icon(Icons.settings, size: 16),
        //       const SizedBox(width: 8),
        //       const Text('Settings'),
        //     ],
        //   ),
        // ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          value: 'logout',
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.logout,
                size: 16,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 8),
              Text(
                'Logout',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAvatar(context, avatar, displayName),
            if (showName) ...[
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Text(
                  //   displayName,
                  //   style: const TextStyle(
                  //     fontSize: 14,
                  //     fontWeight: FontWeight.w600,
                  //     height: 1.1,
                  //   ),
                  //   overflow: TextOverflow.ellipsis,
                  // ),
                  if (role != null)
                    Text(
                      role,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w400,
                        height: 1.0,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ],
            const SizedBox(width: 8),
            Icon(Icons.arrow_drop_down, size: 20, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }
}
