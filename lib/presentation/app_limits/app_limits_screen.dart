import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/app_limit_service.dart';
import '../../services/analytics_service.dart';
import '../../widgets/custom_image_widget.dart';
import 'create_app_limit_screen.dart';
import '../strict_mode_setup/pin_entry_dialog.dart';

class AppLimitsScreen extends StatefulWidget {
  const AppLimitsScreen({Key? key}) : super(key: key);

  @override
  State<AppLimitsScreen> createState() => _AppLimitsScreenState();
}

class _AppLimitsScreenState extends State<AppLimitsScreen> {
  final AppLimitService _appLimitService = AppLimitService();
  final AnalyticsService _analyticsService = AnalyticsService();
  List<AppLimit> _limits = [];
  Map<String, String?> _iconCache = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLimits();
  }

  Future<void> _loadLimits() async {
    setState(() => _isLoading = true);
    final limits = await _appLimitService.getAllLimits();
    setState(() {
      _limits = limits;
      _isLoading = false;
    });
    _fetchMissingIcons();
  }

  Future<void> _fetchMissingIcons() async {
    bool updated = false;
    for (var limit in _limits) {
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Usage Limits'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _limits.isEmpty
              ? _buildEmptyState(theme)
              : _buildLimitsList(theme),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateAppLimitScreen(),
            ),
          );
          if (result == true) {
            _loadLimits();
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Limit'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.timer_off_rounded,
            size: 80,
            color: theme.colorScheme.outline.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 24),
          Text(
            'No Limits Set',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Create usage limits to stay focused.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitsList(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _limits.length,
      itemBuilder: (context, index) {
        final limit = _limits[index];
        return _buildLimitCard(limit, theme);
      },
    );
  }

  Widget _buildLimitCard(AppLimit limit, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
      color: theme.colorScheme.surface,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            // TODO: Open limit details or edit
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer
                            .withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.timer_rounded,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            limit.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                '${limit.limitMinutes}m limit',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (limit.isStrictMode) ...[
                                SizedBox(width: 8),
                                _buildStrictIcon(limit.strictModeLevel, theme),
                              ]
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Action Menu
                    Baseline(
                      baseline: 20, // Align with text roughly
                      baselineType: TextBaseline.alphabetic,
                      child: PopupMenuButton<String>(
                        icon: Icon(Icons.more_horiz_rounded,
                            color: theme.colorScheme.onSurfaceVariant),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        onSelected: (value) {
                          if (value == 'delete') {
                            _confirmDelete(limit);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_rounded,
                                    size: 18, color: theme.colorScheme.error),
                                SizedBox(width: 8),
                                Text(
                                  'Delete Limit',
                                  style: TextStyle(
                                      color: theme.colorScheme.error,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Apps Preview
                Row(
                  children: [
                    Expanded(child: _buildAppsRow(limit.apps)),
                    if (limit.isStrictMode)
                      _buildStrictModeBadge(limit.strictModeLevel, theme),
                  ],
                ),
                // Show hard mode expiry info
                if (limit.isStrictMode && limit.strictModeLevel == 'HARD')
                  _buildHardModeInfo(limit, theme),
                // Always show resets at midnight
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      Icon(Icons.refresh_rounded,
                          size: 14, color: Colors.grey),
                      SizedBox(width: 4),
                      Text('Resets at midnight',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHardModeInfo(AppLimit limit, ThemeData theme) {
    if (limit.hardModeEndsAt == null) return const SizedBox.shrink();

    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = limit.hardModeEndsAt! - now;

    if (diff <= 0) return const SizedBox.shrink();

    final days = diff ~/ (24 * 60 * 60 * 1000);
    final hours = (diff % (24 * 60 * 60 * 1000)) ~/ (60 * 60 * 1000);
    final mins = (diff % (60 * 60 * 1000)) ~/ (60 * 1000);

    String timeText;
    if (days > 0) {
      timeText = '${days}d ${hours}h remaining';
    } else if (hours > 0) {
      timeText = '${hours}h ${mins}m remaining';
    } else {
      timeText = '${mins}m remaining';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_clock_rounded, size: 16, color: Colors.red),
            SizedBox(width: 8),
            Text('Hard mode: $timeText',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildStrictIcon(String level, ThemeData theme) {
    Color color = Colors.grey;
    if (level == 'HARD') color = Colors.red;
    if (level == 'MEDIUM') color = Colors.orange;
    if (level == 'EASY') color = Colors.blue;
    return Icon(Icons.lock_rounded, size: 12, color: color);
  }

  Widget _buildAppsRow(List<dynamic> apps) {
    return Row(
      children: [
        for (var i = 0; i < apps.length && i < 5; i++)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildAppIcon(apps[i]['packageName'] as String),
          ),
        if (apps.length > 5)
          Text(
            '+${apps.length - 5} more',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
      ],
    );
  }

  Widget _buildAppIcon(String packageName) {
    final iconBase64 = _iconCache[packageName];
    if (iconBase64 != null) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: Colors.grey.shade100,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: CustomImageWidget(
            imageUrl: 'data:image/png;base64,$iconBase64',
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: 14,
      backgroundColor: Colors.grey.shade200,
      child: const Icon(Icons.apps_rounded, size: 16, color: Colors.grey),
    );
  }

  Widget _buildStrictModeBadge(String level, ThemeData theme) {
    Color color;
    IconData icon;
    String label;

    switch (level) {
      case 'EASY':
        color = Colors.blue;
        icon = Icons.pin_rounded;
        label = 'Easy';
        break;
      case 'MEDIUM':
        color = Colors.orange;
        icon = Icons.timer_rounded;
        label = 'Medium';
        break;
      case 'HARD':
        color = Colors.red;
        icon = Icons.lock_rounded;
        label = 'Hard';
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            'Strict: $label',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(AppLimit limit) async {
    // 1. HARD Mode Check
    if (limit.isStrictMode && limit.strictModeLevel == 'HARD') {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (limit.hardModeEndsAt != null && now < limit.hardModeEndsAt!) {
        _showLockedDialog(limit.hardModeEndsAt!);
        return;
      }
    }

    // 2. EASY Mode Check (PIN)
    if (limit.isStrictMode && limit.strictModeLevel == 'EASY') {
      final pin = await showDialog<String>(
        context: context,
        builder: (context) => const PinEntryDialog(),
      );
      if (pin == null) return;
      if (pin != limit.strictModePin) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Incorrect PIN')),
          );
        }
        return;
      }
    }

    // 3. MEDIUM Mode Check (Cooldown)
    if (limit.isStrictMode && limit.strictModeLevel == 'MEDIUM') {
      final now = DateTime.now().millisecondsSinceEpoch;
      final cooldownMs = (limit.strictModeCooldownMinutes ?? 10) * 60 * 1000;
      final lastReq = limit.lastUnlockedAt ?? 0;

      if (now - lastReq < cooldownMs) {
        final remainingMin =
            ((cooldownMs - (now - lastReq)) / (60 * 1000)).ceil();
        _showCooldownDialog(limit, remainingMin);
        return;
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Limit?'),
        content: Text('Are you sure you want to delete "${limit.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && limit.id != null) {
      try {
        await _appLimitService.deleteLimit(limit.id!);
        _loadLimits();
      } catch (e) {
        if (mounted) {
          String message = 'Cannot delete limit';
          if (e is PlatformException) {
            message = e.message ?? message;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      }
    }
  }

  void _showCooldownDialog(AppLimit limit, int remainingMinutes) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Icon(Icons.timer_rounded, color: Colors.orange, size: 48),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Cooldown Active',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            Text(
              'Medium Strict Mode requires a wait before deletion.\n\nYou must wait $remainingMinutes more minutes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (limit.id != null) {
                await _appLimitService.requestUnlock(limit.id!);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Wait period started. Come back soon!')),
                  );
                }
              }
            },
            child: const Text('Start Wait'),
          ),
        ],
      ),
    );
  }

  void _showLockedDialog(int endsAt) {
    final ends = DateTime.fromMillisecondsSinceEpoch(endsAt);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Icon(Icons.lock_rounded, color: Colors.red, size: 48),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Hard Mode Locked',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 12),
            Text(
              'This limit is in Hard Mode and cannot be deleted until:',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Text(
              '${ends.day}/${ends.month}/${ends.year} ${ends.hour}:${ends.minute}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
