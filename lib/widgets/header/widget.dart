import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/widgets/header/_logo.dart';
import 'package:zipzap_pos_self_orders/widgets/header/_action_button.dart';
import 'package:zipzap_pos_self_orders/widgets/header/_search_box.dart';
import 'package:zipzap_pos_self_orders/widgets/header/_user_dropdown.dart';
import 'package:zipzap_pos_self_orders/widgets/header/_server_status.dart';
import 'package:zipzap_pos_self_orders/core/services/websocket_service.dart';

class HeaderWidget extends StatelessWidget {
  final String? logoUrl;
  final VoidCallback? onHomePressed;
  final VoidCallback? onDrawerPressed;
  final VoidCallback? onCategoriesPressed;
  final Function(String)? onSearchChanged;
  final bool serverStatus;
  final String? userName;
  final WebSocketStatus? websocketStatus;
  final bool? isServerDown;
  final bool? isRefetching;
  final VoidCallback? onRefresh;

  const HeaderWidget({
    super.key,
    this.logoUrl,
    this.onHomePressed,
    this.onDrawerPressed,
    this.onCategoriesPressed,
    this.onSearchChanged,
    this.serverStatus = true,
    this.userName,
    this.websocketStatus,
    this.isServerDown,
    this.isRefetching,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final isSmallScreen = MediaQuery.of(context).size.width < 1024;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 80),
        child: Row(
          spacing: 4,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            HeaderLogo(logoUrl: logoUrl),

            HeaderActionButton(
              icon: Icons.home_outlined,
              tooltip: 'Home',
              onPressed:
                  onHomePressed ??
                  () {
                    // Pop back to the first route (HomePage) instead of re-pushing '/'
                    // This avoids re-triggering AuthWrapper and showing splash screen
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
            ),

            // HeaderActionButton(
            //   icon: Icons.menu,
            //   tooltip: 'Menu',
            //   onPressed:
            //       onDrawerPressed ??
            //       () {
            //         Scaffold.of(context).openDrawer();
            //       },
            // ),
            //if (isSmallScreen && onCategoriesPressed != null)
            // HeaderActionButton(
            //   icon: Icons.category,
            //   tooltip: 'Categories',
            //   onPressed: onCategoriesPressed,
            // ),
            //if (isTablet) ...[HeaderSearchBox(onChanged: onSearchChanged)],
            const Spacer(),
            if (onRefresh != null)
              IconButton(
                icon: (isRefetching ?? false)
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: (isRefetching ?? false) ? null : onRefresh,
                constraints: const BoxConstraints(),
                style: ButtonStyle(
                  shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            if (websocketStatus != null)
              HeaderServerStatus(
                status: websocketStatus!,
                isServerDown: isServerDown ?? false,
                isRefetching: isRefetching ?? false,
              ),
            const SizedBox(width: 4),
            HeaderUserDropdown(userName: userName, showName: isTablet),
          ],
        ),
      ),
    );
  }
}
