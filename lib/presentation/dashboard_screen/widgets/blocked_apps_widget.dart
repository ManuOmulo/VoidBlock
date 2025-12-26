import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_export.dart';
import '../../../services/blocking_service.dart';
import '../../../services/analytics_service.dart';

/// Currently blocked apps section showing active blocking sessions
class BlockedAppsWidget extends StatefulWidget {
  const BlockedAppsWidget({Key? key}) : super(key: key);

  @override
  State<BlockedAppsWidget> createState() => BlockedAppsWidgetState();
}

class BlockedAppsWidgetState extends State<BlockedAppsWidget> {
  List<Map<String, dynamic>> _blockedApps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedApps();
  }

  Future<void> _loadBlockedApps() async {
    try {
      final blockingService = BlockingService();
      final analyticsService = AnalyticsService();
      final session = await blockingService.getActiveSession();

      if (session != null && session['blockedApps'] != null) {
        final List<dynamic> apps = session['blockedApps'];
        final List<Map<String, dynamic>> loadedApps = [];

        for (final app in apps) {
          final packageName = app['packageName'];
          final appInfo =
              await analyticsService.getAppInfo(packageName.toString());

          if (appInfo != null) {
            loadedApps.add({
              "id": session['id'],
              "name": appInfo.appName,
              "iconBase64": appInfo.iconBase64,
              "package": appInfo.packageName,
              "remainingMinutes": _calculateRemaining(session['endTime']),
              "isStrictMode": session['strictMode'] ?? false,
            });
          }
        }

        if (mounted) {
          setState(() {
            _blockedApps = loadedApps;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _blockedApps = [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading blocked apps: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _calculateRemaining(int? endTime) {
    if (endTime == null) return 0;
    final remaining = DateTime.fromMillisecondsSinceEpoch(endTime)
        .difference(DateTime.now())
        .inMinutes;
    return remaining > 0 ? remaining : 0;
  }

  /// Public method to refresh blocked apps list
  Future<void> refresh() async {
    setState(() => _isLoading = true);
    await _loadBlockedApps();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Currently Blocked',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_blockedApps.isNotEmpty)
                  GestureDetector(
                    onTap: () =>
                        Navigator.pushNamed(context, '/app-selection-screen'),
                    child: Text(
                      'Manage',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 12),
          _isLoading
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ))
              : _blockedApps.isEmpty
                  ? _buildEmptyState(theme)
                  : SizedBox(
                      height: 70,
                      child: ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: _blockedApps.length,
                        itemBuilder: (context, index) {
                          return _buildBlockedAppChip(
                            context,
                            theme,
                            _blockedApps[index],
                          );
                        },
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            CustomIconWidget(
              iconName: 'check_circle',
              size: 20,
              color: theme.colorScheme.secondary,
            ),
            SizedBox(width: 12),
            Text(
              'All clear! No distractions active.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockedAppChip(
    BuildContext context,
    ThemeData theme,
    Map<String, dynamic> app,
  ) {
    final remaining = app["remainingMinutes"];

    return Container(
      margin: EdgeInsets.only(right: 12),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAppIcon(app, theme),
          SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                app["name"],
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Row(
                children: [
                  Icon(
                    Icons.access_time_filled_rounded,
                    size: 10,
                    color: theme.colorScheme.primary,
                  ),
                  SizedBox(width: 4),
                  Text(
                    '${remaining}m left',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (app["isStrictMode"]) ...[
            SizedBox(width: 8),
            Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_rounded,
                size: 8,
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAppIcon(Map<String, dynamic> app, ThemeData theme) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: app["iconBase64"] != null
            ? Image.memory(
                base64Decode(app["iconBase64"]),
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallbackIcon(theme),
              )
            : _fallbackIcon(theme),
      ),
    );
  }

  Widget _fallbackIcon(ThemeData theme) {
    return Center(
      child: CustomIconWidget(
        iconName: 'apps',
        size: 16,
        color: theme.colorScheme.primary.withValues(alpha: 0.5),
      ),
    );
  }
}
