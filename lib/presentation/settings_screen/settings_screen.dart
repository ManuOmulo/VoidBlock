import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import '../../core/app_export.dart';

import '../../services/analytics_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_icon_widget.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // Only functional settings verification needed here if any
    // For now, nothing to load for the functional parts
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _exportData() async {
    HapticFeedback.mediumImpact();
    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preparing usage report...')),
    );

    final now = DateTime.now();
    final startTime =
        now.subtract(const Duration(days: 30)).millisecondsSinceEpoch;
    final endTime = now.millisecondsSinceEpoch;

    final result = await _analyticsService.exportUsageData(
      startTime: startTime,
      endTime: endTime,
    );

    if (mounted) {
      if (result['success'] == true) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Report Exported'),
            content: Text(
                'Your productivity report has been saved to:\n\n${result['path']}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Export failed: ${result['message'] ?? 'Unknown error'}')),
        );
      }
    }
  }

  Future<void> _clearHistory() async {
    HapticFeedback.heavyImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Usage History?'),
        content: const Text(
          'This will permanently delete all your local productivity logs. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _analyticsService.clearUsageData();
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Usage history cleared successfully.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to clear history.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Settings',
        variant: CustomAppBarVariant.standard,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _buildSectionHeader(theme, 'Data & Privacy'),
                _buildSettingTile(
                  theme,
                  icon: 'file_download',
                  title: 'Export Personal Report',
                  subtitle: 'Download your 30-day history as CSV',
                  onTap: _exportData,
                ),
                _buildSettingTile(
                  theme,
                  icon: 'delete_forever',
                  title: 'Clear Usage History',
                  subtitle: 'Delete all local productivity logs',
                  textColor: theme.colorScheme.error,
                  onTap: _clearHistory,
                ),
                const Divider(height: 32),
                _buildSectionHeader(theme, 'Support'),
                _buildSettingTile(
                  theme,
                  icon: 'admin_panel_settings',
                  title: 'System Permissions',
                  subtitle: 'Review required Android permissions',
                  onTap: () => Navigator.pushNamed(
                      context, '/permission-onboarding-screen'),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: Text(
                      'VoidBlock v1.0.0',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingTile(
    ThemeData theme, {
    required String icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    Color? textColor,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (textColor ?? theme.colorScheme.primary).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: CustomIconWidget(
          iconName: icon,
          size: 20,
          color: textColor ?? theme.colorScheme.primary,
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: textColor?.withOpacity(0.7),
        ),
      ),
      trailing: trailing ??
          Icon(Icons.chevron_right,
              size: 20, color: theme.colorScheme.onSurfaceVariant),
      onTap: onTap,
    );
  }
}
