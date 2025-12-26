import 'package:flutter/material.dart';

import '../../../services/analytics_service.dart';

/// Widget to display personalized insights
class InsightsWidget extends StatefulWidget {
  const InsightsWidget({Key? key}) : super(key: key);

  @override
  State<InsightsWidget> createState() => InsightsWidgetState();
}

class InsightsWidgetState extends State<InsightsWidget> {
  final AnalyticsService _analyticsService = AnalyticsService();
  List<Map<String, dynamic>> _insights = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  Future<void> refresh() async {
    await _loadInsights();
  }

  Future<void> _loadInsights() async {
    try {
      final insights = await _analyticsService.getInsights(days: 7);

      if (mounted) {
        setState(() {
          _insights = insights;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading insights: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_insights.isEmpty) {
      return SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Insights',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
          ),
          SizedBox(height: 12),
          ..._insights
              .where((insight) => insight['type'] != 'ACHIEVEMENT')
              .take(3)
              .map((insight) => _buildInsightCard(insight)),
        ],
      ),
    );
  }

  Widget _buildInsightCard(Map<String, dynamic> insight) {
    final theme = Theme.of(context);
    final severity = insight['severity'] as String? ?? 'NEUTRAL';

    Color cardColor;
    IconData icon;

    switch (severity) {
      case 'POSITIVE':
        cardColor = theme.colorScheme.primaryContainer;
        icon = Icons.star;
        break;
      case 'RECOMMENDATION':
        cardColor = theme.colorScheme.tertiaryContainer;
        icon = Icons.lightbulb_outline;
        break;
      case 'NEGATIVE':
        cardColor = theme.colorScheme.errorContainer;
        icon = Icons.warning_amber;
        break;
      default:
        cardColor = theme.colorScheme.secondaryContainer;
        icon = insight['type'] == 'RECOMMENDATION'
            ? Icons.lightbulb_outline
            : Icons.info_outline;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cardColor.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  color: theme.colorScheme.onSecondaryContainer, size: 20),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    insight['title'] as String? ?? '',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    insight['message'] as String? ?? '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (insight['value'] != null)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  insight['value'] as String? ?? '',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
