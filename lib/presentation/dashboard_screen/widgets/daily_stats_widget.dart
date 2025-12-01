import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_export.dart';
import '../../../services/analytics_service.dart';
import '../../../widgets/custom_icon_widget.dart';

/// Daily statistics widget showing productivity metrics
class DailyStatsWidget extends StatefulWidget {
  const DailyStatsWidget({Key? key}) : super(key: key);

  @override
  State<DailyStatsWidget> createState() => DailyStatsWidgetState();
}

class DailyStatsWidgetState extends State<DailyStatsWidget> {
  final AnalyticsService _analyticsService = AnalyticsService();

  String _timeSaved = '0m';
  int _appsBlocked = 0;
  double _productivityScore = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> loadStats() async {
    await _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      // Get stats for today
      final stats = await _analyticsService.getUsageStats(days: 1).timeout(
        Duration(seconds: 5),
        onTimeout: () {
          print('Stats loading timed out');
          return {};
        },
      );
      final score =
          await _analyticsService.getProductivityScore(days: 7).timeout(
        Duration(seconds: 5),
        onTimeout: () {
          print('Score loading timed out');
          return 0.0;
        },
      );

      if (mounted) {
        setState(() {
          final blockedMs = (stats['blockedTime'] as int?) ?? 0;
          _timeSaved = _formatDuration(blockedMs);
          _appsBlocked = (stats['blockedCount'] as int?) ?? 0;
          _productivityScore = score;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading stats: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDuration(int milliseconds) {
    final hours = milliseconds ~/ (1000 * 60 * 60);
    final minutes = (milliseconds ~/ (1000 * 60)) % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return '0m';
    }
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
                'Today\'s Progress',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pushNamed(context, '/analytics-screen');
                },
                child: Text('View Details'),
              ),
            ],
          ),
          SizedBox(height: 12),
          _isLoading
              ? _buildLoadingState(theme)
              : Card(
                  elevation: 2,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatItem(
                                context,
                                theme,
                                icon: 'timer',
                                label: 'Time Saved',
                                value: _timeSaved,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 60,
                              color: theme.dividerColor,
                            ),
                            Expanded(
                              child: _buildStatItem(
                                context,
                                theme,
                                icon: 'block',
                                label: 'Apps Blocked',
                                value: '$_appsBlocked',
                                color: theme.colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Divider(height: 1),
                        SizedBox(height: 16),
                        _buildProductivityScore(context, theme),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(48),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    ThemeData theme, {
    required String icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: CustomIconWidget(iconName: icon, size: 24, color: color),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildProductivityScore(BuildContext context, ThemeData theme) {
    final score = _productivityScore.round();
    final progress = _productivityScore / 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Productivity Score',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getScoreColor(score, theme).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$score%',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _getScoreColor(score, theme),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getScoreColor(score, theme),
                    ),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  SizedBox(height: 8),
                  Text(
                    _getScoreMessage(score),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 16),
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getScoreColor(score, theme),
                    ),
                  ),
                  CustomIconWidget(
                    iconName: _getScoreIcon(score),
                    size: 28,
                    color: _getScoreColor(score, theme),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getScoreColor(int score, ThemeData theme) {
    if (score >= 80) return theme.colorScheme.secondary;
    if (score >= 60) return theme.colorScheme.primary;
    if (score >= 40) return AppTheme.warningLight;
    return theme.colorScheme.error;
  }

  String _getScoreIcon(int score) {
    if (score >= 80) return 'emoji_events';
    if (score >= 60) return 'thumb_up';
    if (score >= 40) return 'trending_up';
    return 'trending_down';
  }

  String _getScoreMessage(int score) {
    if (score >= 80) return 'Excellent! Keep up the great work!';
    if (score >= 60) return 'Good progress! Stay focused!';
    if (score >= 40) return 'You can do better! Stay committed!';
    return 'Let\'s improve together!';
  }
}
