import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/core/services/auth_service.dart';
import 'package:zipzap_pos_self_orders/models/staff_member.dart';
import 'package:zipzap_pos_self_orders/services/users_service.dart';

/// Reusable modal for selecting the "server" / staff member assigned to an
/// order. Defaults to the currently logged-in user. The chosen staff is
/// returned via [onConfirm]; the modal closes itself on confirm/cancel.
class StaffSelectorModal extends StatefulWidget {
  final StaffMember? initialStaff;
  final void Function(StaffMember staff) onConfirm;
  final VoidCallback onCancel;

  const StaffSelectorModal({
    super.key,
    this.initialStaff,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<StaffSelectorModal> createState() => _StaffSelectorModalState();
}

class _StaffSelectorModalState extends State<StaffSelectorModal> {
  final UsersService _usersService = UsersService();
  final AuthService _authService = AuthService();

  List<StaffMember> _staff = const [];
  StaffMember? _selectedStaff;
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _selectedStaff = widget.initialStaff;
    _loadStaff();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  StaffMember? _profileAsStaff() {
    final profile = _authService.getProfile();
    if (profile == null) return null;
    return StaffMember(
      id: profile.id,
      firstName: profile.firstName,
      lastName: profile.lastName,
      email: profile.email,
      username: profile.username,
      avatar: profile.avatar,
    );
  }

  Future<void> _loadStaff() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final fallback = _profileAsStaff();

    try {
      final staff = await _usersService.getStaff();
      if (!mounted) return;

      final list = List<StaffMember>.from(staff);
      // Make sure the logged-in user is always selectable, even when the
      // server-side filters happen to exclude them.
      if (fallback != null && !list.any((s) => s.id == fallback.id)) {
        list.insert(0, fallback);
      }

      // Pre-select: explicit initial selection > current user > first entry.
      StaffMember? defaultStaff = widget.initialStaff != null
          ? list.firstWhere(
              (s) => s.id == widget.initialStaff!.id,
              orElse: () => widget.initialStaff!,
            )
          : null;
      defaultStaff ??= fallback != null
          ? list.firstWhere(
              (s) => s.id == fallback.id,
              orElse: () => list.isNotEmpty ? list.first : fallback,
            )
          : (list.isNotEmpty ? list.first : null);

      setState(() {
        _staff = list;
        _selectedStaff = defaultStaff;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _staff = fallback != null ? [fallback] : const [];
        _selectedStaff = widget.initialStaff ?? fallback;
        _isLoading = false;
        _error = fallback == null
            ? 'Unable to load staff. Please try again.'
            : null;
      });
    }
  }

  List<StaffMember> get _filteredStaff {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _staff;
    return _staff.where((s) {
      return s.fullName.toLowerCase().contains(q) ||
          s.email.toLowerCase().contains(q) ||
          (s.username ?? '').toLowerCase().contains(q);
    }).toList();
  }

  String _initialsFor(StaffMember s) {
    final f = s.firstName.isNotEmpty ? s.firstName[0] : '';
    final l = s.lastName.isNotEmpty ? s.lastName[0] : '';
    final initials = '$f$l'.trim();
    if (initials.isNotEmpty) return initials.toUpperCase();
    if (s.email.isNotEmpty) return s.email[0].toUpperCase();
    return '?';
  }

  void _handleConfirm() {
    final staff = _selectedStaff;
    if (staff == null) return;
    widget.onConfirm(staff);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 768;
    final modalWidth = isSmallScreen
        ? screenWidth * 0.95
        : (screenWidth < 1024 ? 460.0 : 520.0);

    return Dialog(
      child: Container(
        width: modalWidth,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            Flexible(child: _buildContent(context)),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.badge_outlined,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Select Server',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(icon: const Icon(Icons.close), onPressed: widget.onCancel),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && _staff.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 36,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadStaff,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final filtered = _filteredStaff;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search staff by name or email...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No staff matched "$_searchQuery"',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          )
        else
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final s = filtered[index];
                final isSelected = _selectedStaff?.id == s.id;
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      _initialsFor(s),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  title: Text(
                    s.fullName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: s.email.isNotEmpty
                      ? Text(
                          s.email,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        )
                      : null,
                  trailing: isSelected
                      ? Icon(
                          Icons.check_circle,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : const Icon(
                          Icons.radio_button_unchecked,
                          color: Colors.grey,
                        ),
                  onTap: () => setState(() => _selectedStaff = s),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    final canConfirm = _selectedStaff != null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: widget.onCancel,
              icon: const Icon(Icons.close),
              label: const Text('Cancel'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: canConfirm ? _handleConfirm : null,
              icon: const Icon(Icons.check),
              label: const Text('Select'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
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

/// Convenience helper that mirrors the other modal helpers in this folder.
Future<void> showStaffSelectorModal(
  BuildContext context, {
  StaffMember? initialStaff,
  required void Function(StaffMember staff) onConfirm,
}) {
  return showDialog(
    context: context,
    builder: (context) => StaffSelectorModal(
      initialStaff: initialStaff,
      onConfirm: onConfirm,
      onCancel: () => Navigator.of(context).pop(),
    ),
  );
}
