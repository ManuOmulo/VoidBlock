import 'package:flutter/material.dart';

class ProductivityScoreBreakdownWidget extends StatelessWidget {
  final Map<String, dynamic> breakdown;

  const ProductivityScoreBreakdownWidget({
    Key? key,
    required this.breakdown,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (breakdown.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No breakdown data available',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final totalScore = (breakdown['totalScore'] as double).toStringAsFixed(1);
    final weights = Map<String, dynamic>.from(breakdown['weights'] as Map);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Productivity Score',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  // color: theme.colorScheme.primary,
                ),
              ),
              Text(
                totalScore,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: _getScoreColor(breakdown['totalScore']),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildFactorBar(
            context,
            'Blocked Attempts',
            breakdown['blockedAttemptsScore'],
            weights['blockedAttempts'],
            'Starts at 100, decreases with more blocked attempts',
          ),
          const SizedBox(height: 16),
          _buildFactorBar(
            context,
            'Time Saved',
            breakdown['timeSavedScore'],
            weights['timeSaved'],
            'More time blocked improves score',
          ),
          const SizedBox(height: 16),
          _buildFactorBar(
            context,
            'Focus Ratio',
            breakdown['focusRatioScore'],
            weights['focusRatio'],
            'Ratio of saved time to total usage',
          ),
          const SizedBox(height: 16),
          _buildFactorBar(
            context,
            'Consistency',
            breakdown['consistencyScore'],
            weights['consistency'],
            'Regular blocking sessions improve score',
          ),
          const SizedBox(height: 16),
          _buildFactorBar(
            context,
            'Usage Pattern',
            breakdown['usagePatternScore'],
            weights['usagePattern'],
            'Improving trends over time improve score',
          ),
        ],
      ),
    );
  }

  Widget _buildFactorBar(
    BuildContext context,
    String label,
    dynamic score,
    dynamic weight,
    String description,
  ) {
    final theme = Theme.of(context);
    final scoreValue = score.toStringAsFixed(1);
    final weightValue = (weight * 100).toStringAsFixed(0);
    final progressValue = score / 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: scoreValue,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: ' ($weightValue%)',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progressValue,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getScoreColor(score),
              ),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 70) return Colors.green;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }
}
