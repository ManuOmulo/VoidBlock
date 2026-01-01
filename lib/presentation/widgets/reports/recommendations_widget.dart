import 'package:flutter/material.dart';
import '../../../routes/app_routes.dart';

class RecommendationsWidget extends StatelessWidget {
  final List<Map<String, dynamic>> insights;

  const RecommendationsWidget({
    super.key,
    required this.insights,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Filter for recommendations and take the first one, or use a default if none
    final recommendations = insights
        .where((i) => i['type'] == 'RECOMMENDATION' || i['type'] == 'WARNING')
        .toList();

    // Fallback tip if no specific recommendations
    final defaultTip = {
      'message':
          "Focus is a muscle. Every time you resist an app notification, you're making that muscle stronger.",
    };

    final recommendation =
        recommendations.isNotEmpty ? recommendations.first : defaultTip;

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
                  recommendations.isNotEmpty
                      ? (recommendation['title'] ?? 'Quick Tip')
                      : 'Quick Tip',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  recommendation['message'] as String,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (recommendation['actionType'] != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(
                          color: theme.colorScheme.primary,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                      ),
                      onPressed: () {
                        final route = _getActionRoute(
                          recommendation['actionType'] as String?,
                        );
                        if (route != null) {
                          Navigator.pushNamed(context, route);
                        }
                      },
                      child: Text(
                        _getActionLabel(
                            recommendation['actionType'] as String?),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _getActionRoute(String? actionType) {
    switch (actionType) {
      case 'CREATE_LIMIT':
        return AppRoutes.appLimits;
      case 'CREATE_SCHEDULE':
        return AppRoutes.scheduleCreator;
      case 'SETTINGS':
        return AppRoutes.settings;
      default:
        return null;
    }
  }

  String _getActionLabel(String? actionType) {
    switch (actionType) {
      case 'CREATE_LIMIT':
        return 'Set App Limit';
      case 'CREATE_SCHEDULE':
        return 'Create Schedule';
      case 'SETTINGS':
        return 'Open Settings';
      default:
        return 'Take Action';
    }
  }
}
