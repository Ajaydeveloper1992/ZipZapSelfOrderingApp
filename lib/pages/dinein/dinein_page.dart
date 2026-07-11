import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/models/floor_plan_model.dart';
import 'package:zipzap_pos_self_orders/models/order_model.dart';
import 'package:zipzap_pos_self_orders/models/staff_member.dart';
import 'package:zipzap_pos_self_orders/services/floor_plans_service.dart';
import 'package:zipzap_pos_self_orders/services/orders_service.dart';
import 'package:zipzap_pos_self_orders/services/users_service.dart';
import 'package:zipzap_pos_self_orders/pages/dinein/widgets/floor_plan_canvas.dart';
import 'package:zipzap_pos_self_orders/widgets/header/widget.dart';
import 'package:zipzap_pos_self_orders/widgets/app_drawer.dart';
import 'package:zipzap_pos_self_orders/widgets/app_toast.dart';
import 'package:zipzap_pos_self_orders/providers/websocket_provider.dart';
import 'package:zipzap_pos_self_orders/providers/data_provider.dart';
import 'package:zipzap_pos_self_orders/core/services/auth_service.dart';

class DineInPage extends StatefulWidget {
  const DineInPage({super.key});

  @override
  State<DineInPage> createState() => _DineInPageState();
}

class _DineInPageState extends State<DineInPage> {
  final FloorPlansService _floorPlansService = FloorPlansService();
  final OrdersService _ordersService = OrdersService();
  final WebSocketProvider _webSocketProvider = WebSocketProvider();
  final DataProvider _dataProvider = DataProvider();
  final AuthService _authService = AuthService();

  List<FloorPlan> _floorPlans = [];
  bool _isLoading = true;
  String? _error;
  int _currentTabIndex = 0;
  bool _isDineInEnabled = false;
  bool _isCheckingDineIn = true;
  bool _isFetchingOrder = false;
  bool _hasFloorPlanPermission = false;

  @override
  void initState() {
    super.initState();
    _checkFloorPlanPermission();
    _checkDineInAvailability();
    // Listen to WebSocket updates for floor plan and table status changes
    _webSocketProvider.addListener(_onWebSocketUpdate);
  }

  void _checkFloorPlanPermission() {
    final profile = _authService.getProfile();
    setState(() {
      _hasFloorPlanPermission = profile?.canReadFloorPlans ?? false;
    });
  }

  @override
  void dispose() {
    _webSocketProvider.removeListener(_onWebSocketUpdate);
    super.dispose();
  }

  /// Handle WebSocket updates for floor plan and table status changes
  void _onWebSocketUpdate() {
    final lastMessage = _webSocketProvider.lastMessage;
    if (lastMessage == null) return;

    // Handle floor plan updates with optimistic update (no refetch)
    if (lastMessage.type == 'floor_plan_updated') {
      _handleFloorPlanUpdate();
      return;
    }

    // Handle table status updates with optimistic update (no refetch)
    if (lastMessage.type == 'table_status_updated') {
      _handleTableStatusUpdate();
      return;
    }
  }

  /// Handle floor plan update optimistically (create/update/delete)
  void _handleFloorPlanUpdate() {
    final updateData = _webSocketProvider.lastFloorPlanUpdate;
    if (updateData == null) return;

    final floorPlanData = updateData['floorPlan'];
    final action = updateData['action'] ?? 'updated';

    if (floorPlanData == null) {
      // Fallback: refetch if no floor plan data provided
      _loadFloorPlans();
      return;
    }

    try {
      final updatedFloorPlan = FloorPlan.fromJson(
        floorPlanData as Map<String, dynamic>,
      );

      setState(() {
        if (action == 'deleted') {
          _floorPlans.removeWhere((plan) => plan.id == updatedFloorPlan.id);
          // Reset tab index if current tab was deleted
          if (_currentTabIndex >= _floorPlans.length) {
            _currentTabIndex = _floorPlans.isNotEmpty ? 0 : 0;
          }
        } else if (action == 'created') {
          // Add new floor plan if not exists
          final exists = _floorPlans.any(
            (plan) => plan.id == updatedFloorPlan.id,
          );
          if (!exists) {
            _floorPlans.add(updatedFloorPlan);
          }
        } else {
          // Update existing floor plan
          final index = _floorPlans.indexWhere(
            (plan) => plan.id == updatedFloorPlan.id,
          );
          if (index != -1) {
            _floorPlans[index] = updatedFloorPlan;
          } else {
            // Floor plan not in list, add it
            _floorPlans.add(updatedFloorPlan);
          }
        }
      });

      // Clear the update data after consuming
      _webSocketProvider.clearFloorPlanUpdate();
    } catch (e) {
      debugPrint('Error parsing floor plan update: $e');
      _loadFloorPlans();
    }
  }

  /// Handle table status update optimistically
  void _handleTableStatusUpdate() {
    final updateData = _webSocketProvider.lastTableStatusUpdate;
    if (updateData == null) return;

    final floorPlanId = updateData['floorPlanId'] as String?;
    final tableId = updateData['tableId'] as String?;
    final newStatus = updateData['status'] as String?;
    final floorPlanData = updateData['floorPlan'];

    if (floorPlanId == null || tableId == null || newStatus == null) {
      _loadFloorPlans();
      return;
    }

    // If full floor plan data is provided, use it for a complete update
    if (floorPlanData != null) {
      try {
        final updatedFloorPlan = FloorPlan.fromJson(
          floorPlanData as Map<String, dynamic>,
        );
        setState(() {
          final index = _floorPlans.indexWhere(
            (plan) => plan.id == updatedFloorPlan.id,
          );
          if (index != -1) {
            _floorPlans[index] = updatedFloorPlan;
          }
        });
        _webSocketProvider.clearTableStatusUpdate();
        return;
      } catch (e) {
        debugPrint('Error parsing floor plan from table status update: $e');
      }
    }

    // Fallback: update just the table status in local state
    setState(() {
      final floorPlanIndex = _floorPlans.indexWhere(
        (plan) => plan.id == floorPlanId,
      );
      if (floorPlanIndex != -1) {
        final floorPlan = _floorPlans[floorPlanIndex];
        final tableIndex = floorPlan.items.indexWhere(
          (item) => item.id == tableId,
        );
        if (tableIndex != -1) {
          final updatedItems = List<FloorItem>.from(floorPlan.items);
          updatedItems[tableIndex] = updatedItems[tableIndex].copyWith(
            status: TableStatus.fromString(newStatus),
          );
          _floorPlans[floorPlanIndex] = floorPlan.copyWith(items: updatedItems);
        }
      }
    });

    _webSocketProvider.clearTableStatusUpdate();
  }

  Future<void> _checkDineInAvailability() async {
    setState(() {
      _isCheckingDineIn = true;
    });

    try {
      // Load store if not already loaded
      if (_dataProvider.store == null && !_dataProvider.isLoadingStore) {
        await _dataProvider.loadStore();
      }

      final store = _dataProvider.store;
      final servicesOffered = store?.servicesOffered;
      final isDineInEnabled = servicesOffered?['dineIn'] == true;

      setState(() {
        _isDineInEnabled = isDineInEnabled;
        _isCheckingDineIn = false;
      });

      // Only load floor plans if dine-in is enabled AND user has permission
      if (isDineInEnabled && _hasFloorPlanPermission) {
        _loadFloorPlans();
      }
    } catch (e) {
      setState(() {
        _isDineInEnabled = false;
        _isCheckingDineIn = false;
      });
    }
  }

  Future<void> _loadFloorPlans() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _floorPlansService.getFloorPlans(
        isActive: true,
        sortBy: 'createdAt',
        sortOrder: 'asc',
      );
      setState(() {
        _floorPlans = response.floorPlans;
        _isLoading = false;
        // Reset index if needed
        if (_currentTabIndex >= _floorPlans.length) {
          _currentTabIndex = 0;
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onTableTap(FloorItem table) {
    // Check table status
    if (table.status == TableStatus.occupied) {
      // Table is occupied - find the active order and open in edit mode
      _openExistingOrder(table);
    } else if (table.status == TableStatus.available) {
      // Table is available - show party size dialog for new order
      _showPartySizeDialog(table);
    } else if (table.status == TableStatus.reserved) {
      // Table is reserved for advance booking - show info
      AppToast.info(
        context: context,
        title: 'Table Reserved',
        description: 'This table is reserved for advance booking',
      );
    }
  }

  Future<void> _openExistingOrder(FloorItem table) async {
    if (_isFetchingOrder) return;

    setState(() {
      _isFetchingOrder = true;
    });

    try {
      final Order? order = await _ordersService.getActiveOrderForTable(
        table.id,
      );

      if (!mounted) return;

      setState(() {
        _isFetchingOrder = false;
      });

      if (order != null) {
        // Navigate to edit order page
        Navigator.pushNamed(
          context,
          '/dinein/new',
          arguments: {
            'orderType': 'dineIn',
            'isEditMode': true,
            'order': order,
            'tableInfo': {
              'tableId': table.id,
              'tableName': table.name,
              'floorPlanId': _floorPlans[_currentTabIndex].id,
              'floorPlanName': _floorPlans[_currentTabIndex].name,
              'partySize': order.tableInfo?.partySize ?? 1,
            },
          },
        );
      } else {
        // No active order found - table might have just been released
        AppToast.warning(
          context: context,
          title: 'No Active Order',
          description:
              'No active order found for ${table.name}. The table may have been released.',
        );
        // Refresh floor plans to get updated status
        _loadFloorPlans();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFetchingOrder = false;
        });
        AppToast.error(
          context: context,
          title: 'Error',
          description: 'Failed to load order for ${table.name}',
        );
      }
    }
  }

  void _showPartySizeDialog(FloorItem table) {
    showDialog(
      context: context,
      builder: (context) => _PartySizeDialog(
        table: table,
        onConfirm: (partySize, staff) {
          Navigator.of(context).pop();
          _createDineInOrder(table, partySize, staff);
        },
        onCancel: () {
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _createDineInOrder(FloorItem table, int partySize, StaffMember staff) {
    Navigator.pushNamed(
      context,
      '/dinein/new',
      arguments: {
        'orderType': 'dineIn',
        'tableInfo': {
          'tableId': table.id,
          'tableName': table.name,
          'floorPlanId': _floorPlans[_currentTabIndex].id,
          'floorPlanName': _floorPlans[_currentTabIndex].name,
          'partySize': partySize,
        },
        'staff': {
          '_id': staff.id,
          'firstName': staff.firstName,
          'lastName': staff.lastName,
          'email': staff.email,
          if (staff.username != null) 'username': staff.username,
          if (staff.avatar != null) 'avatar': staff.avatar,
        },
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Builder(
              builder: (context) => ListenableBuilder(
                listenable: _webSocketProvider,
                builder: (context, _) => HeaderWidget(
                  logoUrl: 'https://zipzappos.com',
                  onHomePressed: () => Navigator.pop(context),
                  onDrawerPressed: () => Scaffold.of(context).openDrawer(),
                  websocketStatus: _webSocketProvider.status,
                  isServerDown: _webSocketProvider.isServerDown,
                ),
              ),
            ),

            // Content
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    // Check if still checking dine-in availability
    if (_isCheckingDineIn) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Checking dine-in availability...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Show access denied if user doesn't have floor_plans permission
    if (!_hasFloorPlanPermission) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Icon(
                  Icons.lock_outline,
                  size: 40,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Access Denied',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You do not have permission to access floor plans. Please contact your administrator.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    // Show message if dine-in is not enabled
    if (!_isDineInEnabled) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Icon(
                  Icons.restaurant,
                  size: 40,
                  color: Colors.orange.shade700,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Dine-In Not Available',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Dine-in service is not enabled for this store. Please contact support to enable this feature.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading floor plans...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                'Failed to load floor plans',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadFloorPlans,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_floorPlans.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Icon(
                  Icons.grid_view_rounded,
                  size: 40,
                  color: Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No Floor Plans',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create floor plans in the admin panel\nto manage dine-in tables',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: _loadFloorPlans,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Floor plan selector (segmented control)
        if (_floorPlans.length > 1) _buildFloorPlanSelector(),

        // Canvas
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FloorPlanCanvas(
              floorPlan: _floorPlans[_currentTabIndex],
              onTableTap: _onTableTap,
            ),
          ),
        ),

        // Legend
        _buildLegend(),
      ],
    );
  }

  Widget _buildFloorPlanSelector() {
    // Build segment options
    final Map<int, Widget> segmentOptions = {};
    for (int i = 0; i < _floorPlans.length; i++) {
      final plan = _floorPlans[i];
      segmentOptions[i] = _buildSegmentLabel(
        plan.name,
        plan.availableTableCount,
        plan.tableCount,
        _currentTabIndex == i,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: CupertinoSlidingSegmentedControl<int>(
          groupValue: _currentTabIndex,
          onValueChanged: (value) {
            if (value != null) {
              setState(() {
                _currentTabIndex = value;
              });
            }
          },
          children: segmentOptions,
          thumbColor: Theme.of(context).primaryColor,
          backgroundColor: Colors.grey.shade200,
          padding: const EdgeInsets.all(2),
        ),
      ),
    );
  }

  Widget _buildSegmentLabel(
    String name,
    int availableCount,
    int totalCount,
    bool isSelected,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.2)
                  : Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$availableCount/$totalCount',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    if (_floorPlans.isEmpty) return const SizedBox.shrink();

    final plan = _floorPlans[_currentTabIndex];
    final available = plan.items
        .where((i) => i.type.isTable && i.status == TableStatus.available)
        .length;
    final occupied = plan.items
        .where((i) => i.type.isTable && i.status == TableStatus.occupied)
        .length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 24,
        children: [
          _buildLegendItem('Available', available, const Color(0xFF10B981)),
          _buildLegendItem('Occupied', occupied, const Color(0xFFF97316)),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: $count',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}

/// Dialog for selecting party size and the server (staff) for this table.
class _PartySizeDialog extends StatefulWidget {
  final FloorItem table;
  final void Function(int partySize, StaffMember staff) onConfirm;
  final VoidCallback onCancel;

  const _PartySizeDialog({
    required this.table,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<_PartySizeDialog> createState() => _PartySizeDialogState();
}

class _PartySizeDialogState extends State<_PartySizeDialog> {
  final UsersService _usersService = UsersService();
  final AuthService _authService = AuthService();

  int _partySize = 1;
  List<StaffMember> _staff = const [];
  StaffMember? _selectedStaff;
  bool _isLoadingStaff = true;
  String? _staffError;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    final profile = _authService.getProfile();
    final fallbackStaff = profile != null
        ? StaffMember(
            id: profile.id,
            firstName: profile.firstName,
            lastName: profile.lastName,
            email: profile.email,
            username: profile.username,
            avatar: profile.avatar,
          )
        : null;

    try {
      final staff = await _usersService.getStaff();
      if (!mounted) return;

      // Make sure the logged-in user is in the list (so it can be the default
      // selection even when the server response doesn't include them, e.g.
      // when filters happen to exclude their role).
      final list = List<StaffMember>.from(staff);
      if (fallbackStaff != null && !list.any((s) => s.id == fallbackStaff.id)) {
        list.insert(0, fallbackStaff);
      }

      final defaultStaff = fallbackStaff != null
          ? list.firstWhere(
              (s) => s.id == fallbackStaff.id,
              orElse: () => list.isNotEmpty ? list.first : fallbackStaff,
            )
          : (list.isNotEmpty ? list.first : null);

      setState(() {
        _staff = list;
        _selectedStaff = defaultStaff;
        _isLoadingStaff = false;
        _staffError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _staff = fallbackStaff != null ? [fallbackStaff] : const [];
        _selectedStaff = fallbackStaff;
        _isLoadingStaff = false;
        _staffError = fallbackStaff == null
            ? 'Unable to load staff. Please try again.'
            : null;
      });
    }
  }

  void _updatePartySize(int size) {
    if (size >= 1 && size <= 20) {
      setState(() {
        _partySize = size;
      });
    }
  }

  Future<void> _openStaffPicker() async {
    if (_staff.isEmpty) return;

    final picked = await showModalBottomSheet<StaffMember>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.badge_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Select Server',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _staff.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final s = _staff[index];
                    final isSelected = _selectedStaff?.id == s.id;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        child: Text(
                          _initialsFor(s),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      title: Text(
                        s.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: s.email.isNotEmpty
                          ? Text(
                              s.email,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            )
                          : null,
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: () => Navigator.of(context).pop(s),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedStaff = picked;
      });
    }
  }

  String _initialsFor(StaffMember s) {
    final f = s.firstName.isNotEmpty ? s.firstName[0] : '';
    final l = s.lastName.isNotEmpty ? s.lastName[0] : '';
    final initials = '$f$l'.trim();
    if (initials.isNotEmpty) return initials.toUpperCase();
    if (s.email.isNotEmpty) return s.email[0].toUpperCase();
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;
    final modalWidth = isSmallScreen ? screenWidth * 0.9 : 450.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: modalWidth,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildContent(context),
              ),
            ),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.people,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Party Size',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.table.name} • ${widget.table.seats ?? 0} seats',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 24),
            onPressed: widget.onCancel,
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(
                context,
              ).colorScheme.error.withValues(alpha: 0.1),
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Current selection display
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: _partySize > 1
                      ? () => _updatePartySize(_partySize - 1)
                      : null,
                  icon: const Icon(Icons.remove),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Column(
                  children: [
                    Text(
                      '$_partySize',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Text(
                      _partySize == 1 ? 'Guest' : 'Guests',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                IconButton(
                  onPressed: _partySize < 20
                      ? () => _updatePartySize(_partySize + 1)
                      : null,
                  icon: const Icon(Icons.add),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Server',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        _buildStaffSelector(context),
        const SizedBox(height: 20),
        Text(
          'Quick Select',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [1, 2, 3, 4, 5, 8, 10].map((size) {
            final isSelected = _partySize == size;
            return SizedBox(
              width: 54,
              height: 44,
              child: OutlinedButton(
                onPressed: () => _updatePartySize(size),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white,
                  foregroundColor: isSelected
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurface,
                  side: BorderSide(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade300,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  '$size',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStaffSelector(BuildContext context) {
    if (_isLoadingStaff) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Loading staff...',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_staffError != null && _selectedStaff == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              size: 18,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _staffError!,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() => _isLoadingStaff = true);
                _loadStaff();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final selected = _selectedStaff;
    final hasMultiple = _staff.length > 1;

    return InkWell(
      onTap: hasMultiple ? _openStaffPicker : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              foregroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                selected != null ? _initialsFor(selected) : '?',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    selected?.fullName ?? 'No staff available',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (selected?.email.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(
                      selected!.email,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (hasMultiple)
              Icon(Icons.unfold_more, size: 20, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final canConfirm = _selectedStaff != null;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: widget.onCancel,
              icon: const Icon(Icons.close, size: 20),
              label: const Text('Cancel'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                side: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: canConfirm
                  ? () => widget.onConfirm(_partySize, _selectedStaff!)
                  : null,
              icon: const Icon(Icons.check, size: 20),
              label: const Text('Confirm Table'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
