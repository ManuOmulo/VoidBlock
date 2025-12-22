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

  void _endBlockingEarly(int index) {
    HapticFeedback.mediumImpact();
    final app = _blockedApps[index];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('End Blocking Early?'),
        content: Text(
          'Are you sure you want to unblock ${app["name"]}? This will end the current blocking session.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              // Stop the entire session
              final blockingService = BlockingService();
              await blockingService.stopBlocking();

              if (mounted) {
                setState(() {
                  _blockedApps = [];
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Blocking session ended'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Text(
              'End Session',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showEmergencyUnlock(int index) {
    HapticFeedback.heavyImpact();
    final app = _blockedApps[index];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CustomIconWidget(
              iconName: 'lock',
              size: 24,
              color: Theme.of(context).colorScheme.error,
            ),
            SizedBox(width: 8),
            Text('Strict Mode Active'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${app["name"]} is in strict mode and cannot be unblocked until the schedule ends.',
            ),
            SizedBox(height: 16),
            Text(
              'Emergency unlock requires PIN verification and will be logged in your productivity report.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/strict-mode-lock-screen');
            },
            child: Text(
              'Emergency Unlock',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Currently Blocked',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_blockedApps.isNotEmpty)
                TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pushNamed(context, '/app-selection-screen');
                  },
                  child: Text('Manage'),
                ),
            ],
          ),
          SizedBox(height: 12),
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : _blockedApps.isEmpty
                  ? _buildEmptyState(theme)
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: _blockedApps.length,
                      itemBuilder: (context, index) {
                        return _buildBlockedAppCard(
                          context,
                          theme,
                          _blockedApps[index],
                          index,
                        );
                      },
                    ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      padding: EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          CustomIconWidget(
            iconName: 'block',
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          SizedBox(height: 16),
          Text(
            'No Apps Blocked',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'Start a blocking session to improve your focus',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedAppCard(
    BuildContext context,
    ThemeData theme,
    Map<String, dynamic> app,
    int index,
  ) {
    final hours = app["remainingMinutes"] ~/ 60;
    final minutes = app["remainingMinutes"] % 60;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            if (app["isStrictMode"]) {
              _showEmergencyUnlock(index);
            }
          },
          onLongPress: () {
            if (!app["isStrictMode"]) {
              _endBlockingEarly(index);
            } else {
              _showEmergencyUnlock(index);
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: app["iconBase64"] != null
                            ? Image.memory(
                                base64Decode(app["iconBase64"]),
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => CustomIconWidget(
                                  iconName: 'apps',
                                  size: 24,
                                  color: theme.colorScheme.primary,
                                ),
                              )
                            : CustomImageWidget(
                                imageUrl:
                                    app["icon"], // Fallback if icon URL exists
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                semanticLabel: "${app["name"]} icon",
                              ),
                      ),
                    ),
                    if (app["isStrictMode"])
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error,
                            shape: BoxShape.circle,
                          ),
                          child: CustomIconWidget(
                            iconName: 'lock',
                            size: 12,
                            color: theme.colorScheme.onError,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  app["name"],
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4),
                Text(
                  hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                if (!app["isStrictMode"])
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _endBlockingEarly(index),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        side: BorderSide(
                          color: theme.colorScheme.error,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'End Early',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Locked',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
