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
    // 1. High Usage Detection (Personalized)
    if (usageStats.isNotEmpty) {
      final topApp = usageStats.first;
      final minutes = topApp['usageMinutes'] as int? ?? 0;
      final appName = topApp['appName'] ?? 'distracting apps';

      if (minutes > 120) {
        return "You've spent over 2 hours on $appName today. Even a 15-minute limit could save you an hour by next week!";
      }
    }

    // 2. Consistency & Streaks (Based on Daily Stats)
    final sessions =
        dailyStats.values.where((v) => (v is num && v > 0)).toList();
    if (sessions.length >= 3) {
      return "You're on a ${sessions.length}-day focus streak! Keeping this up for 7 days rewires your brain for deeper concentration.";
    }

    // 3. Reclaim Targets (Based on Time Saved data if available)
    // We can infer time saved from totalTime in dailyStats if we treat it as the new metric
    final totalMinutesSaved = dailyStats.values
        .fold<int>(0, (sum, val) => sum + (val as num).toInt());
    if (totalMinutesSaved > 60) {
      return "You've reclaimed ${totalMinutesSaved ~/ 60}h ${totalMinutesSaved % 60}m this week! That's time you can now spend on what truly matters.";
    }

    // 4. Fallback: Educational Tips (Randomized)
    final tips = [
      "The first 2 hours of your day are your brain's most productive. Try blocking all socials until 10 AM.",
      "Most people check their phones 58 times a day. FocusGuard has already stopped a few of those for you!",
      "Focus is a muscle. Every time you resist an app notification, you're making that muscle stronger.",
      "Try the '1-minute rule': if a task takes less than a minute, do it now instead of opening a distracting app.",
    ];

    // Simple deterministic randomize based on current day
    return tips[DateTime.now().day % tips.length];
  }
}
