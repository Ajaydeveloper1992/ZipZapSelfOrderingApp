import 'package:flutter/material.dart';
import 'package:zipzap_pos_self_orders/core/services/websocket_service.dart';

class HeaderServerStatus extends StatelessWidget {
  final WebSocketStatus status;
  final bool isServerDown;
  final bool isRefetching;

  const HeaderServerStatus({
    super.key,
    required this.status,
    required this.isServerDown,
    this.isRefetching = false,
  });

  Color _getStatusColor() {
    if (isServerDown) {
      return Colors.red;
    }
    switch (status) {
      case WebSocketStatus.connected:
        return Colors.green;
      case WebSocketStatus.connecting:
        return Colors.orange;
      case WebSocketStatus.disconnected:
        return Colors.grey;
      case WebSocketStatus.error:
        return Colors.red;
    }
  }

  IconData _getStatusIcon() {
    if (isServerDown) {
      return Icons.cloud_off;
    }
    switch (status) {
      case WebSocketStatus.connected:
        return Icons.cloud_done;
      case WebSocketStatus.connecting:
        return Icons.cloud_sync;
      case WebSocketStatus.disconnected:
        return Icons.cloud_off;
      case WebSocketStatus.error:
        return Icons.error_outline;
    }
  }

  String _getStatusTooltip() {
    if (isServerDown) {
      return 'Server unavailable';
    }
    switch (status) {
      case WebSocketStatus.connected:
        return 'Connected to server';
      case WebSocketStatus.connecting:
        return 'Connecting...';
      case WebSocketStatus.disconnected:
        return 'Disconnected';
      case WebSocketStatus.error:
        return 'Connection error';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _getStatusTooltip(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getStatusColor().withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getStatusColor().withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            isRefetching
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getStatusColor(),
                      ),
                    ),
                  )
                : Icon(_getStatusIcon(), size: 16, color: _getStatusColor()),
            const SizedBox(width: 4),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _getStatusColor(),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
