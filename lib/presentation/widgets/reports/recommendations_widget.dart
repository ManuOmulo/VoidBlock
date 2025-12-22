import 'package:flutter/material.dart';

class RecommendationsWidget extends StatelessWidget {
  final Map<String, dynamic> dailyStats;
  final List<Map<String, dynamic>> usageStats;

  const RecommendationsWidget({
    super.key,
    required this.dailyStats,
    required this.usageStats,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recommendation = _generateRecommendation();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lightbulb_outline,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Tip',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  recommendation,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _generateRecommendation() {
    // Simple logic for recommendation
    if (usageStats.isNotEmpty) {
      final mostUsed = usageStats.first;
      final minutes = mostUsed['usageMinutes'] as int? ?? 0;
      if (minutes > 120) {
        return "You've spent over 2 hours on ${mostUsed['appName']} today. Consider setting a limit.";
      }
    }

    // Check if yesterday was productive
    // ... simplified logic
    return "Consistently tracking your focus time helps improve productivity by 20%.";
  }
}
