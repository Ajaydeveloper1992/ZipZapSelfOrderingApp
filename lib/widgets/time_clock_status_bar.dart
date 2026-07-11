import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/core/services/time_clock_service.dart';
import 'package:zipzap_pos_self_orders/core/services/auth_service.dart';
import 'package:zipzap_pos_self_orders/models/time_clock_model.dart';
import 'package:zipzap_pos_self_orders/widgets/app_toast.dart';
import 'package:zipzap_pos_self_orders/widgets/pin_confirmation_dialog.dart';
import 'package:zipzap_pos_self_orders/widgets/transfer_orders_dialog.dart';

class TimeClockStatusBar extends StatefulWidget {
  const TimeClockStatusBar({super.key});

  @override
  State<TimeClockStatusBar> createState() => _TimeClockStatusBarState();
}

class _TimeClockStatusBarState extends State<TimeClockStatusBar> {
  final TimeClockService _timeClockService = TimeClockService();
  final AuthService _authService = AuthService();
  TimeClockEntry? _entry;
  bool _isLoading = true;
  bool _isActioning = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchStatus());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchStatus() async {
    final entry = await _timeClockService.getStatus();
    if (mounted) {
      setState(() {
        _entry = entry;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleClockIn() async {
    final storeId = _authService.getStoreId();
    if (storeId == null) return;

    final pin = await PinConfirmationDialog.show(
      context,
      title: 'Confirm Clock In',
      description: 'Enter your PIN to clock in',
    );
    if (pin == null || !mounted) return;

    setState(() => _isActioning = true);
    final result = await _timeClockService.clockIn(storeId: storeId, pin: pin);
    if (mounted) {
      setState(() {
        _isActioning = false;
        if (result.success) _entry = result.entry;
      });
      if (result.success) {
        AppToast.success(
          context: context,
          title: 'Clocked In',
          description: result.message,
        );
      } else {
        AppToast.error(
          context: context,
          title: 'Clock In Failed',
          description: result.message,
        );
      }
    }
  }

  Future<void> _handleClockOut() async {
    final pin = await PinConfirmationDialog.show(
      context,
      title: 'Confirm Clock Out',
      description: 'Enter your PIN to clock out',
    );
    if (pin == null || !mounted) return;

    setState(() => _isActioning = true);
    final result = await _timeClockService.clockOut(pin: pin);
    if (!mounted) return;

    if (result.success) {
      setState(() {
        _isActioning = false;
        _entry = result.entry;
      });
      AppToast.success(
        context: context,
        title: 'Clocked Out',
        description: result.message,
      );
      await _fetchStatus();
      return;
    }

    setState(() => _isActioning = false);

    if (result.hasActiveOrders) {
      await _showTransferDialog(pin, result.activeOrderCount);
    } else {
      AppToast.error(
        context: context,
        title: 'Cannot Clock Out',
        description: result.message,
      );
    }
  }

  Future<void> _showTransferDialog(String pin, int orderCount) async {
    final staff = await _timeClockService.getStoreStaff();
    if (!mounted) return;

    if (staff.isEmpty) {
      AppToast.error(
        context: context,
        title: 'Cannot Transfer',
        description: 'No other staff available to transfer orders to.',
      );
      return;
    }

    final selectedStaffId = await TransferOrdersDialog.show(
      context,
      orderCount: orderCount,
      staff: staff,
    );
    if (selectedStaffId == null || !mounted) return;

    setState(() => _isActioning = true);

    final transferResult = await _timeClockService.transferOrders(
      targetStaffId: selectedStaffId,
      pin: pin,
    );
    if (!mounted) return;

    if (!transferResult.success) {
      setState(() => _isActioning = false);
      AppToast.error(
        context: context,
        title: 'Transfer Failed',
        description: transferResult.message,
      );
      return;
    }

    AppToast.success(
      context: context,
      title: 'Orders Transferred',
      description: transferResult.message,
    );

    final retryResult = await _timeClockService.clockOut(pin: pin);
    if (!mounted) return;

    setState(() {
      _isActioning = false;
      if (retryResult.success) _entry = retryResult.entry;
    });

    if (retryResult.success) {
      AppToast.success(
        context: context,
        title: 'Clocked Out',
        description: retryResult.message,
      );
      await _fetchStatus();
    } else {
      AppToast.error(
        context: context,
        title: 'Clock Out Failed',
        description: retryResult.message,
      );
    }
  }

  Future<void> _handleBreakToggle() async {
    final isOnBreak = _entry?.isOnBreak ?? false;

    final pin = await PinConfirmationDialog.show(
      context,
      title: isOnBreak ? 'Confirm End Break' : 'Confirm Start Break',
      description: isOnBreak
          ? 'Enter your PIN to end break'
          : 'Enter your PIN to start break',
    );
    if (pin == null || !mounted) return;

    setState(() => _isActioning = true);

    final result = isOnBreak
        ? await _timeClockService.endBreak(pin: pin)
        : await _timeClockService.startBreak(pin: pin);

    if (mounted) {
      setState(() => _isActioning = false);
      if (result.success) {
        await _fetchStatus();
        AppToast.success(
          context: context,
          title: isOnBreak ? 'Break Ended' : 'Break Started',
          description: result.message,
        );
      } else {
        AppToast.error(
          context: context,
          title: 'Error',
          description: result.message,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox.shrink();

    final isClockedIn = _entry?.isClockedIn ?? false;

    if (!isClockedIn) {
      return _buildNotClockedInBar(context);
    }

    return _buildClockedInBar(context);
  }

  Widget _buildNotClockedInBar(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Not clocked in',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          SizedBox(
            height: 30,
            child: FilledButton.icon(
              onPressed: _isActioning ? null : _handleClockIn,
              icon: _isActioning
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.login, size: 14),
              label: const Text('Clock In', style: TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClockedInBar(BuildContext context) {
    final isOnBreak = _entry?.isOnBreak ?? false;
    final statusColor = isOnBreak ? Colors.amber : Colors.green;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor.shade600,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isOnBreak ? 'On Break' : 'Clocked In',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor.shade800,
                  ),
                ),
                _ElapsedTimer(
                  startTime: _entry!.clockIn,
                  style: TextStyle(fontSize: 11, color: statusColor.shade600),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 28,
            child: OutlinedButton(
              onPressed: _isActioning ? null : _handleBreakToggle,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                side: BorderSide(
                  color: isOnBreak
                      ? Colors.amber.shade600
                      : Colors.orange.shade400,
                ),
                foregroundColor: isOnBreak
                    ? Colors.amber.shade700
                    : Colors.orange.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(
                isOnBreak ? 'End Break' : 'Break',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            height: 28,
            child: OutlinedButton(
              onPressed: _isActioning ? null : _handleClockOut,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                side: BorderSide(color: Colors.red.shade400),
                foregroundColor: Colors.red.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: _isActioning
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.red.shade600,
                      ),
                    )
                  : const Text('Clock Out', style: TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ElapsedTimer extends StatefulWidget {
  final DateTime startTime;
  final TextStyle? style;

  const _ElapsedTimer({required this.startTime, this.style});

  @override
  State<_ElapsedTimer> createState() => _ElapsedTimerState();
}

class _ElapsedTimerState extends State<_ElapsedTimer> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.startTime);
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes.remainder(60);
    final text = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';

    return Text(text, style: widget.style);
  }
}
