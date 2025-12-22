import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MonthlyActivityGrid extends StatelessWidget {
  /// Map of date (YYYY-MM-DD) to minutes/status
  final Map<String, dynamic> dailyStats;

  const MonthlyActivityGrid({
    super.key,
    required this.dailyStats,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = _getLast30Days();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Consistency Goal',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Monthly',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Days header (S M T W T F S)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length + _getFirstDayOffset(days.first),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final offset = _getFirstDayOffset(days.first);
              if (index < offset) return const SizedBox();

              final date = days[index - offset];
              final dateKey = DateFormat('yyyy-MM-dd').format(date);
              final minutes = (dailyStats[dateKey] ?? 0.0).toDouble();

              // Determine status:
              // - 0 minutes: inactive
              // - > 0 minutes: active
              // - > 30 minutes: goal met (example logic)
              final isActive = minutes > 0;
              final isGoalMet = minutes >= 25; // Pomodoro length
              final isToday = _isSameDay(date, DateTime.now());

              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isGoalMet
                      ? theme.colorScheme.primary
                      : isActive
                          ? theme.colorScheme.primaryContainer
                          : Colors.transparent,
                  border: isToday
                      ? Border.all(color: theme.colorScheme.primary, width: 2)
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  date.day.toString(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isGoalMet
                        ? theme.colorScheme.onPrimary
                        : isActive
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurface,
                    fontWeight: (isGoalMet || isToday)
                        ? FontWeight.bold
                        : FontWeight.w400,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<DateTime> _getLast30Days() {
    final now = DateTime.now();
    // Start from the beginning of the current month view or similar logic
    // But for a simple "last 30 days" view, we might want to align with weeks.
    // Let's just show the current month for simplicity, relative to today.
    // Actually, Figma shows a specific month "December 2023".
    // Let's imply showing the "Current Month" days.

    final startOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

    final days = <DateTime>[];
    for (int i = 0; i < lastDayOfMonth.day; i++) {
      days.add(startOfMonth.add(Duration(days: i)));
    }
    return days;
  }

  int _getFirstDayOffset(DateTime firstDayOfMonth) {
    // weekday 1 = Mon, 7 = Sun.
    // We want 0 = Sun, 1 = Mon... if our header is S M T...
    // Adjust logic accordingly.
    // DateTime.weekday is 1(Mon)..7(Sun).
    // If we want Sun as first column (0), then Sun(7) -> 0, Mon(1) -> 1
    return firstDayOfMonth.weekday % 7;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
