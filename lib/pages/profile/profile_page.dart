import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zipzap_pos_self_orders/core/models/user_profile.dart';
import 'package:zipzap_pos_self_orders/core/services/auth_service.dart';
import 'package:zipzap_pos_self_orders/core/constants/api_constants.dart';
import 'package:zipzap_pos_self_orders/providers/websocket_provider.dart';
import 'package:zipzap_pos_self_orders/widgets/header/widget.dart';
import 'package:zipzap_pos_self_orders/widgets/app_drawer.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  final WebSocketProvider _webSocketProvider = WebSocketProvider();
  UserProfile? _profile;
  bool _isLoading = true;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    // Listen for WebSocket updates
    _webSocketProvider.addListener(_onWebSocketUpdate);
  }

  @override
  void dispose() {
    // Remove WebSocket listener
    _webSocketProvider.removeListener(_onWebSocketUpdate);
    super.dispose();
  }

  void _onWebSocketUpdate() {
    // Refresh profile when WebSocket sends profile update
    final lastMessage = _webSocketProvider.lastMessage;
    if (lastMessage?.type == 'profile_updated' ||
        lastMessage?.type == 'user_updated') {
      _loadProfile();
    }
  }

  void _loadProfile() {
    setState(() {
      _profile = _authService.getProfile();
      _isLoading = false;
    });
  }

  Future<void> _refreshProfile() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      await _authService.fetchProfile();
      _loadProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile refreshed'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 1024;

    return Scaffold(
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Builder(
              builder: (context) => HeaderWidget(
                logoUrl: 'https://zipzappos.com',
                onDrawerPressed: () {
                  Scaffold.of(context).openDrawer();
                },
                onSearchChanged: (query) {
                  // Handle search
                },
                serverStatus: true,
                userName: _profile?.fullName ?? 'User',
              ),
            ),
            // Main content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _profile == null
                  ? const Center(child: Text('Profile not found'))
                  : SingleChildScrollView(
                      padding: EdgeInsets.all(isSmallScreen ? 12 : 24),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 800),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Profile Header Card
                              _buildProfileHeader(),
                              const SizedBox(height: 16),
                              // Personal Information
                              _buildSectionCard(
                                title: 'Personal Information',
                                icon: Icons.person_outline,
                                children: [
                                  _buildInfoRow(
                                    icon: Icons.person,
                                    label: 'Full Name',
                                    value: _profile!.fullName,
                                  ),
                                  _buildInfoRow(
                                    icon: Icons.alternate_email,
                                    label: 'Username',
                                    value: _profile!.username,
                                  ),
                                  _buildInfoRow(
                                    icon: Icons.email_outlined,
                                    label: 'Email',
                                    value: _profile!.email,
                                  ),
                                  if (_profile!.phone != null)
                                    _buildInfoRow(
                                      icon: Icons.phone_outlined,
                                      label: 'Phone',
                                      value: _profile!.phone!,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Account Information
                              _buildSectionCard(
                                title: 'Account Information',
                                icon: Icons.account_circle_outlined,
                                children: [
                                  _buildInfoRow(
                                    icon: Icons.badge_outlined,
                                    label: 'Role',
                                    value:
                                        _profile!.role?.toUpperCase() ?? 'N/A',
                                    valueColor: Colors.blue,
                                  ),
                                  _buildInfoRow(
                                    icon: Icons.verified_user_outlined,
                                    label: 'Status',
                                    value: _profile!.status.toUpperCase(),
                                    valueColor: _profile!.status == 'active'
                                        ? Colors.green
                                        : Colors.grey,
                                  ),
                                  if (_profile!.isAdmin ||
                                      _profile!.isSuperAdmin)
                                    _buildInfoRow(
                                      icon: Icons.admin_panel_settings_outlined,
                                      label: 'Access Level',
                                      value: _profile!.isSuperAdmin
                                          ? 'Super Admin'
                                          : 'Admin',
                                      valueColor: Colors.purple,
                                    ),
                                ],
                              ),
                              // Permissions Section (if user has role permissions)
                              if (_profile!.permissions != null &&
                                  _profile!.permissions!.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                _buildPermissionsCard(),
                              ],
                              const SizedBox(height: 16),
                              // Store Information
                              if (_profile!.store != null ||
                                  _profile!.storeId != null)
                                _buildSectionCard(
                                  title: 'Store Information',
                                  icon: Icons.store_outlined,
                                  children: [
                                    if (_profile!.storeName != null)
                                      _buildInfoRow(
                                        icon: Icons.store,
                                        label: 'Store Name',
                                        value: _profile!.storeName!,
                                      ),
                                    if (_profile!.storeSlug != null)
                                      _buildInfoRow(
                                        icon: Icons.link,
                                        label: 'Store Slug',
                                        value: _profile!.storeSlug!,
                                      ),
                                    if (_profile!.storeId != null)
                                      _buildInfoRow(
                                        icon: Icons.tag_outlined,
                                        label: 'Store ID',
                                        value: _profile!.storeId!,
                                      ),
                                    if (_profile!.store?.address != null)
                                      _buildInfoRow(
                                        icon: Icons.location_on_outlined,
                                        label: 'Address',
                                        value: _profile!.store!.address!,
                                      ),
                                    if (_profile!.store?.phone != null)
                                      _buildInfoRow(
                                        icon: Icons.phone_outlined,
                                        label: 'Store Phone',
                                        value: _profile!.store!.phone!,
                                      ),
                                    if (_profile!.store?.email != null)
                                      _buildInfoRow(
                                        icon: Icons.email_outlined,
                                        label: 'Store Email',
                                        value: _profile!.store!.email!,
                                      ),
                                    if (_profile!.store?.status != null)
                                      _buildInfoRow(
                                        icon: Icons.info_outline,
                                        label: 'Status',
                                        value: _profile!.store!.status!
                                            .toUpperCase(),
                                        valueColor:
                                            _profile!.store!.status == 'open'
                                            ? Colors.green
                                            : Colors.orange,
                                      ),
                                    if (_profile!.store?.siteUrl != null)
                                      _buildInfoRow(
                                        icon: Icons.language_outlined,
                                        label: 'Website',
                                        value: _profile!.store!.siteUrl!,
                                      ),
                                    if (_profile!.store?.description != null)
                                      _buildInfoRow(
                                        icon: Icons.description_outlined,
                                        label: 'Description',
                                        value: _profile!.store!.description!,
                                      ),
                                  ],
                                ),
                              if (_profile!.store != null ||
                                  _profile!.storeId != null)
                                const SizedBox(height: 16),
                              // Activity Information
                              _buildSectionCard(
                                title: 'Activity',
                                icon: Icons.history_outlined,
                                children: [
                                  if (_profile!.createdAt != null)
                                    _buildInfoRow(
                                      icon: Icons.calendar_today_outlined,
                                      label: 'Member Since',
                                      value: DateFormat(
                                        'MMM dd, yyyy',
                                      ).format(_profile!.createdAt!),
                                    ),
                                  if (_profile!.lastLoginAt != null)
                                    _buildInfoRow(
                                      icon: Icons.login_outlined,
                                      label: 'Last Login',
                                      value: DateFormat(
                                        'MMM dd, yyyy h:mm a',
                                      ).format(_profile!.lastLoginAt!),
                                    ),
                                  if (_profile!.lastActiveAt != null)
                                    _buildInfoRow(
                                      icon: Icons.access_time_outlined,
                                      label: 'Last Active',
                                      value: DateFormat(
                                        'MMM dd, yyyy h:mm a',
                                      ).format(_profile!.lastActiveAt!),
                                    ),
                                ],
                              ),
                            ],
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

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: _profile!.avatar != null
                ? ClipOval(
                    child: Image.network(
                      _profile!.avatar!.startsWith('http')
                          ? _profile!.avatar!
                          : '${ApiConstants.baseUrl}${_profile!.avatar!}',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildAvatarIcon(),
                    ),
                  )
                : _buildAvatarIcon(),
          ),
          const SizedBox(width: 20),
          // Name and Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _profile!.fullName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                if (_profile!.role != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      _profile!.role!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.email_outlined,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _profile!.email,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Refresh Button
          IconButton.outlined(
            onPressed: _isRefreshing ? null : _refreshProfile,
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_outlined),
            tooltip: 'Refresh Profile',
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Edit Button
          IconButton.outlined(
            onPressed: () {
              // TODO: Implement edit functionality
            },
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Profile',
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarIcon() {
    final initials = _profile!.fullName
        .split(' ')
        .take(2)
        .map((n) => n.isNotEmpty ? n[0].toUpperCase() : '')
        .join();
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    color: valueColor ?? Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsCard() {
    final permissions = _profile!.permissions!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.security_outlined,
                  size: 20,
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Permissions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Display permissions in a grid
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: permissions.entries.map((entry) {
              final resource = entry.key;
              final perms = entry.value as Map<String, dynamic>?;

              if (perms == null) return const SizedBox.shrink();

              // Count enabled permissions
              final enabledCount = perms.values.where((v) => v == true).length;
              final totalCount = perms.length;

              return _buildPermissionChip(
                resource: resource,
                permissions: perms,
                enabledCount: enabledCount,
                totalCount: totalCount,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionChip({
    required String resource,
    required Map<String, dynamic> permissions,
    required int enabledCount,
    required int totalCount,
  }) {
    final hasFullAccess = enabledCount == totalCount && totalCount > 0;
    final hasNoAccess = enabledCount == 0;

    return Tooltip(
      message: _getPermissionTooltip(permissions),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: hasFullAccess
              ? Colors.green.shade50
              : hasNoAccess
              ? Colors.grey.shade100
              : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasFullAccess
                ? Colors.green.shade300
                : hasNoAccess
                ? Colors.grey.shade300
                : Colors.orange.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasFullAccess
                  ? Icons.check_circle
                  : hasNoAccess
                  ? Icons.cancel
                  : Icons.remove_circle,
              size: 16,
              color: hasFullAccess
                  ? Colors.green
                  : hasNoAccess
                  ? Colors.grey
                  : Colors.orange,
            ),
            const SizedBox(width: 6),
            Text(
              _formatResourceName(resource),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: hasNoAccess ? Colors.grey.shade600 : Colors.black87,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '($enabledCount/$totalCount)',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  String _formatResourceName(String resource) {
    // Convert camelCase or snake_case to Title Case
    return resource
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (m) => '${m.group(1)} ${m.group(2)}',
        )
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
              : '',
        )
        .join(' ');
  }

  String _getPermissionTooltip(Map<String, dynamic> permissions) {
    final enabled = <String>[];
    final disabled = <String>[];

    permissions.forEach((key, value) {
      if (value == true) {
        enabled.add(key);
      } else {
        disabled.add(key);
      }
    });

    final lines = <String>[];
    if (enabled.isNotEmpty) {
      lines.add('✓ ${enabled.join(', ')}');
    }
    if (disabled.isNotEmpty) {
      lines.add('✗ ${disabled.join(', ')}');
    }
    return lines.join('\n');
  }
}
