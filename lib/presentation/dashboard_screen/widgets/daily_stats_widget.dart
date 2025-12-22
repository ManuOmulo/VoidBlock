import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_export.dart';
import '../../../services/analytics_service.dart';

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
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today\'s Progress',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pushNamed(context, '/analytics-screen');
                },
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                ),
                child: Row(
                  children: [
                    Text('View Details'),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          _isLoading
              ? _buildLoadingState(theme)
              : Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: theme.shadowColor.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.all(20),
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
                            color: theme.dividerColor.withValues(alpha: 0.5),
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
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Divider(
                          height: 1,
                          color: theme.dividerColor.withValues(alpha: 0.5),
                        ),
                      ),
                      _buildProductivityScore(context, theme),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: CircularProgressIndicator(),
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
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: CustomIconWidget(iconName: icon, size: 28, color: color),
        ),
        SizedBox(height: 12),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Productivity Score',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  _getScoreMessage(score),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getScoreColor(score, theme).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text(
                '$score%',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _getScoreColor(score, theme),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        Container(
          height: 12,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getScoreColor(score, theme),
              ),
            ),
          ),
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

  String _getScoreMessage(int score) {
    if (score >= 80) return 'Excellent! Keep up the great work!';
    if (score >= 60) return 'Good progress! Stay focused!';
    if (score >= 40) return 'You can do better! Stay committed!';
    return 'Let\'s improve together!';
  }
}
