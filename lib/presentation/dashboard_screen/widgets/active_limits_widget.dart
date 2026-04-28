import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/app_export.dart';
import '../../../services/app_limit_service.dart';
import '../../../services/analytics_service.dart';
import '../../../widgets/custom_image_widget.dart';

class ActiveLimitsWidget extends StatefulWidget {
  const ActiveLimitsWidget({Key? key}) : super(key: key);

  @override
  State<ActiveLimitsWidget> createState() => ActiveLimitsWidgetState();
}

class ActiveLimitsWidgetState extends State<ActiveLimitsWidget> {
  final AppLimitService _appLimitService = AppLimitService();
  final AnalyticsService _analyticsService = AnalyticsService();
  List<AppLimit> _activeLimits = [];
  Map<int, int> _usageMap = {}; // limitId -> total usage minutes
  Map<String, String?> _iconCache = {}; // packageName -> iconBase64
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refreshData();
    // Removed local timer - redundant with DashboardScreen auto-refresh
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    await _refreshData();
  }

  Future<void> _refreshData() async {
    try {
      final limits = await _appLimitService.getAllLimits();
      final active = limits.where((l) => l.isActive).toList();

      Map<int, int> newUsageMap = {};
      for (var limit in active) {
        final packages =
            limit.apps.map((e) => e['packageName'] as String).toList();
        final usage = await _appLimitService.getDailyUsage(packages);
        int total = usage.values.fold(0, (sum, val) => sum + val);
        newUsageMap[limit.id!] = total;
      }

      if (mounted) {
        setState(() {
          _activeLimits = active;
          _usageMap = newUsageMap;
        });

        // Background fetch icons if not in cache
        _fetchMissingIcons();
      }
    } catch (e) {
      print('Error refreshing active limits: $e');
    }
  }

  Future<void> _fetchMissingIcons() async {
    bool updated = false;
    for (var limit in _activeLimits) {
      for (var app in limit.apps) {
        final pkg = app['packageName'] as String;
        if (!_iconCache.containsKey(pkg)) {
          final info = await _analyticsService.getAppInfo(pkg);
          if (info != null) {
            _iconCache[pkg] = info.iconBase64;
            updated = true;
          } else {
            _iconCache[pkg] = null;
          }
        }
      }
    }
    if (updated && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_activeLimits.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daily Limits',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              InkWell(
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.appLimits);
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    'Manage',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _activeLimits.length,
          itemBuilder: (context, index) {
            final limit = _activeLimits[index];
            final usage = _usageMap[limit.id] ?? 0;
            final progress = (usage / limit.limitMinutes).clamp(0.0, 1.0);
            final isExceeded = usage >= limit.limitMinutes;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isExceeded && !limit.unlockedUntilMidnight)
                              ? Colors.red.withValues(alpha: 0.1)
                              : theme.colorScheme.primary
                                  .withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isExceeded && !limit.unlockedUntilMidnight
                              ? Icons.block_rounded
                              : Icons.timer_rounded,
                          color: isExceeded && !limit.unlockedUntilMidnight
                              ? Colors.red
                              : theme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              limit.name,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${limit.apps.length} apps • $usage / ${limit.limitMinutes} min',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      if (limit.unlockedUntilMidnight)
                        _buildStatusChip('Unlocked', Colors.green)
                      else if (isExceeded)
                        _buildStatusChip('Blocked', Colors.red)
                      else
                        _buildStatusChip('Active', Colors.blue),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor:
                          theme.colorScheme.primary.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isExceeded && !limit.unlockedUntilMidnight
                            ? Colors.red
                            : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildAppsIcons(limit),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildAppsIcons(AppLimit limit) {
    final apps = limit.apps;
    return Row(
      children: [
        for (var i = 0; i < apps.length && i < 6; i++)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: _buildAppIcon(apps[i]['packageName'] as String),
          ),
        if (apps.length > 6)
          Text('+${apps.length - 6}',
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const Spacer(),
        ..._buildTimingInfo(limit),
      ],
    );
  }

  List<Widget> _buildTimingInfo(AppLimit limit) {
    final widgets = <Widget>[];

    // Show hard mode expiry only if the limit has HARD mode with an active end time
    if (limit.isStrictMode &&
        limit.strictModeLevel == 'HARD' &&
        limit.hardModeEndsAt != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final diff = limit.hardModeEndsAt! - now;
      if (diff > 0) {
        final days = diff ~/ (24 * 60 * 60 * 1000);
        final hours = (diff % (24 * 60 * 60 * 1000)) ~/ (60 * 60 * 1000);
        final mins = (diff % (60 * 60 * 1000)) ~/ (60 * 1000);
        String expiryText;
        if (days > 0) {
          expiryText = 'Expires: ${days}d ${hours}h';
        } else if (hours > 0) {
          expiryText = 'Expires: ${hours}h ${mins}m';
        } else {
          expiryText = 'Expires: ${mins}m';
        }
        widgets.add(Text(expiryText,
            style: const TextStyle(
                fontSize: 10,
                color: Colors.red,
                fontWeight: FontWeight.w600)));
        widgets.add(const SizedBox(width: 6));
        widgets.add(const Text('•',
            style: TextStyle(fontSize: 10, color: Colors.grey)));
        widgets.add(const SizedBox(width: 6));
      }
    }

    // Always show resets at midnight for all limits
    widgets.add(const Text('Resets at midnight',
        style: TextStyle(fontSize: 10, color: Colors.grey)));

    return widgets;
  }

  Widget _buildAppIcon(String packageName) {
    final iconBase64 = _iconCache[packageName];
    if (iconBase64 != null) {
      return Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: Colors.grey.shade100,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: CustomImageWidget(
            imageUrl: 'data:image/png;base64,$iconBase64',
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: 10,
      backgroundColor: Colors.grey.shade200,
      child: const Icon(Icons.apps_rounded, size: 12, color: Colors.grey),
    );
  }
}
