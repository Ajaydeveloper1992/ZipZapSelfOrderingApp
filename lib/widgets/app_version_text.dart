import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:zipzap_pos_self_orders/services/app_update_service.dart';

class AppVersionText extends StatefulWidget {
  final Color? color;
  final double fontSize;
  final bool showIcon;
  final bool checkForUpdates;

  const AppVersionText({
    super.key,
    this.color,
    this.fontSize = 12,
    this.showIcon = false,
    this.checkForUpdates = false,
  });

  @override
  State<AppVersionText> createState() => _AppVersionTextState();
}

class _AppVersionTextState extends State<AppVersionText> {
  String _version = '';
  UpdateCheckResult? _updateResult;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = 'v${packageInfo.version}';
      });

      // Check for updates if enabled
      if (widget.checkForUpdates) {
        _checkForUpdates();
      }
    }
  }

  Future<void> _checkForUpdates() async {
    if (_isChecking) return;

    setState(() => _isChecking = true);

    final updateService = AppUpdateService();
    final result = await updateService.checkForUpdate();

    if (mounted) {
      setState(() {
        _updateResult = result;
        _isChecking = false;
      });
    }
  }

  void _showVersionDialog() {
    showDialog(
      context: context,
      builder: (context) => _VersionInfoDialog(
        currentVersion: _version,
        initialUpdateResult: _updateResult,
        onUpdateResultChanged: (result) {
          setState(() {
            _updateResult = result;
          });
        },
      ),
    );
  }

  Color _getVersionColor() {
    if (_updateResult != null) {
      // Update available - use warning/highlight color
      if (_updateResult!.isForceUpdate) {
        return Colors.red.shade400;
      }
      return Colors.orange.shade400;
    }
    // No update or not checked - use default color
    return widget.color ?? Colors.grey.shade500;
  }

  @override
  Widget build(BuildContext context) {
    if (_version.isEmpty) return const SizedBox.shrink();

    final versionColor = widget.checkForUpdates
        ? _getVersionColor()
        : (widget.color ?? Colors.grey.shade500);

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _version,
          style: TextStyle(
            fontSize: widget.fontSize,
            color: versionColor,
            fontWeight: _updateResult != null
                ? FontWeight.w600
                : FontWeight.normal,
          ),
        ),
        if (widget.showIcon) ...[
          const SizedBox(width: 4),
          Icon(
            _updateResult != null ? Icons.system_update : Icons.info_outline,
            size: widget.fontSize + 2,
            color: versionColor,
          ),
        ],
      ],
    );

    if (widget.showIcon) {
      return InkWell(
        onTap: _showVersionDialog,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: content,
        ),
      );
    }

    return content;
  }
}

class _VersionInfoDialog extends StatefulWidget {
  final String currentVersion;
  final UpdateCheckResult? initialUpdateResult;
  final ValueChanged<UpdateCheckResult?> onUpdateResultChanged;

  const _VersionInfoDialog({
    required this.currentVersion,
    required this.initialUpdateResult,
    required this.onUpdateResultChanged,
  });

  @override
  State<_VersionInfoDialog> createState() => _VersionInfoDialogState();
}

class _VersionInfoDialogState extends State<_VersionInfoDialog> {
  UpdateCheckResult? _updateResult;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _updateResult = widget.initialUpdateResult;
  }

  Future<void> _checkForUpdates() async {
    if (_isChecking) return;

    setState(() => _isChecking = true);

    final updateService = AppUpdateService();
    final result = await updateService.checkForUpdate();

    if (mounted) {
      setState(() {
        _updateResult = result;
        _isChecking = false;
      });
      widget.onUpdateResultChanged(result);
    }
  }

  Future<void> _openDownloadUrl() async {
    if (_updateResult != null) {
      final updateService = AppUpdateService();
      Navigator.of(context).pop();
      await updateService.showUpdateDialog(context, _updateResult!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLatest = _updateResult == null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isChecking
                  ? Colors.blue.withOpacity(0.1)
                  : isLatest
                  ? Colors.green.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _isChecking
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  )
                : Icon(
                    isLatest ? Icons.check_circle : Icons.system_update,
                    color: isLatest ? Colors.green : Colors.orange,
                  ),
          ),
          const SizedBox(width: 12),
          Text(
            _isChecking
                ? 'Checking...'
                : isLatest
                ? 'App Info'
                : 'Update Available',
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current version
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Version',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.currentVersion,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          if (_isChecking) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Checking for updates...',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isLatest) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "You're on the latest version!",
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.new_releases,
                        color: Colors.orange.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'New Version Available',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.currentVersion,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: Colors.grey,
                      ),
                      Text(
                        'v${_updateResult!.latestVersion}',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isChecking ? null : () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (!isLatest && !_isChecking)
          FilledButton.icon(
            onPressed: _openDownloadUrl,
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Update'),
          )
        else
          TextButton.icon(
            onPressed: _isChecking ? null : _checkForUpdates,
            icon: _isChecking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 18),
            label: Text(_isChecking ? 'Checking...' : 'Check for Updates'),
          ),
      ],
    );
  }
}
