import 'dart:convert';
import 'dart:async';
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
  Map<String, dynamic>? _currentSession;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedApps();
    // No full-widget timer anymore. Time updates are handled by individual widgets.
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
              "remainingMinutes": 0, // Calculated dynamically by widget
              "isStrictMode": session['strictMode'] ?? false,
            });
          }
        }

        if (mounted) {
          setState(() {
            _blockedApps = loadedApps;
            _currentSession = session;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _blockedApps = [];
            _isLoading = false;
            _currentSession = null;
          });
        }
      }
    } catch (e) {
      print('Error loading blocked apps: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Public method to refresh blocked apps list
  Future<void> refresh() async {
    if (_blockedApps.isEmpty) {
      setState(() => _isLoading = true);
    }
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
                  : GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 2.3,
                      ),
                      itemCount: _blockedApps.length,
                      itemBuilder: (context, index) {
                        return _buildBlockedAppChip(
                          context,
                          theme,
                          _blockedApps[index],
                          _currentSession,
                        );
                      },
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
    Map<String, dynamic>? fullSession,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
        children: [
          _buildAppIcon(app, theme),
          SizedBox(width: 10),
          Expanded(
            child: Column(
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
                // Use isolated widget for time updates
                if (fullSession != null)
                  _BlockedAppTimer(
                    session: fullSession,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                    iconColor: theme.colorScheme.primary,
                  ),
              ],
            ),
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

/// A standalone widget that updates its own time every minute
/// prevented parent redraws
class _BlockedAppTimer extends StatefulWidget {
  final Map<String, dynamic> session;
  final TextStyle? style;
  final Color iconColor;

  const _BlockedAppTimer({
    Key? key,
    required this.session,
    this.style,
    required this.iconColor,
  }) : super(key: key);

  @override
  State<_BlockedAppTimer> createState() => _BlockedAppTimerState();
}

class _BlockedAppTimerState extends State<_BlockedAppTimer> {
  late Timer _timer;
  int _remainingMinutes = 0;

  @override
  void initState() {
    super.initState();
    _updateTime();
    // Update every 30 seconds to be safe
    _timer = Timer.periodic(Duration(seconds: 30), (_) {
      if (mounted) _updateTime();
    });
  }

  void _updateTime() {
    final newValue = _calculateRemainingValue(widget.session);
    if (newValue != _remainingMinutes) {
      setState(() {
        _remainingMinutes = newValue;
      });
    }
  }

  @override
  void didUpdateWidget(_BlockedAppTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      _updateTime();
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  int _calculateRemainingValue(Map<String, dynamic> session) {
    final String type = session['type'] as String? ?? 'manual';
    final int now = DateTime.now().millisecondsSinceEpoch;

    if (type == 'schedule') {
      final int endTime = session['endTime'] as int? ?? 0;
      final int remainingMs = endTime - now;
      return remainingMs > 0 ? (remainingMs / (60 * 1000)).floor() : 0;
    }

    // Manual session logic
    final int startTime = session['startTime'] as int? ?? 0;
    final int durationMinutes = session['durationMinutes'] as int? ?? 0;
    final bool isPaused = session['isPaused'] as bool? ?? false;
    final int? pausedAt = session['pausedAt'] as int?;
    final int accumulatedPausedMs = session['accumulatedPausedMs'] as int? ?? 0;

    if (durationMinutes <= 0) return 0;

    final int totalElapsedMs;
    if (isPaused && pausedAt != null) {
      totalElapsedMs = pausedAt - startTime - accumulatedPausedMs;
    } else {
      totalElapsedMs = now - startTime - accumulatedPausedMs;
    }

    final int totalDurationMs = durationMinutes * 60 * 1000;
    final int remainingMs = totalDurationMs - totalElapsedMs;

    return remainingMs > 0 ? (remainingMs / (60 * 1000)).floor() : 0;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.access_time_filled_rounded,
          size: 10,
          color: widget.iconColor,
        ),
        SizedBox(width: 4),
        Text(
          '${_remainingMinutes}m left',
          style: widget.style,
        ),
      ],
    );
  }
}
