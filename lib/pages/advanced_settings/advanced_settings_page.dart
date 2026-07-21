import 'package:flutter/material.dart';

class AdvancedSettingsPage extends StatelessWidget {
  const AdvancedSettingsPage({
    super.key,
    this.onPartySizeSettings,
    this.onPrintButtonSettings,
    this.onAssignTable,
    this.onLogout,
    this.onOpenPrinters,
  });

  final Future<void> Function()? onPartySizeSettings;
  final Future<void> Function()? onPrintButtonSettings;
  final Future<void> Function()? onAssignTable;
  final Future<void> Function()? onLogout;
  final VoidCallback? onOpenPrinters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose an advanced action. This menu is protected by PIN.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  children: [
                    _SettingsActionTile(
                      icon: Icons.people_alt_outlined,
                      title: 'Party Size / Guest Settings',
                      subtitle: 'Manage guest and quick-select controls.',
                      onTap: onPartySizeSettings != null
                          ? () async {
                              await onPartySizeSettings?.call();
                            }
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _SettingsActionTile(
                      icon: Icons.print,
                      title: 'Print Button Settings',
                      subtitle: 'Control which print buttons appear.',
                      onTap: onPrintButtonSettings != null
                          ? () async {
                              await onPrintButtonSettings?.call();
                            }
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _SettingsActionTile(
                      icon: Icons.settings_applications_outlined,
                      title: 'Printer Settings',
                      subtitle: 'Configure connected printers.',
                      onTap: onOpenPrinters != null
                          ? () {
                              onOpenPrinters?.call();
                            }
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _SettingsActionTile(
                      icon: Icons.table_restaurant_outlined,
                      title: 'Assign Table for Customers',
                      subtitle: 'Assign an available table for self-ordering.',
                      onTap: onAssignTable != null
                          ? () async {
                              await onAssignTable?.call();
                            }
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _SettingsActionTile(
                      icon: Icons.logout,
                      title: 'Logout',
                      subtitle: 'Sign out from the current account.',
                      color: theme.colorScheme.error,
                      onTap: onLogout != null
                          ? () async {
                              await onLogout?.call();
                            }
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.color,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: effectiveColor.withOpacity(0.12),
          child: Icon(icon, color: effectiveColor),
        ),
        title: Text(title, style: theme.textTheme.titleMedium),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
