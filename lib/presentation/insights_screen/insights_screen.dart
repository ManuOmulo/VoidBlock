import 'package:flutter/material.dart';

import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_icon_widget.dart';

/// Insights Screen - Displays detailed productivity analytics and insights
/// TODO: Implement full analytics features in future iterations
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({Key? key}) : super(key: key);

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'More Insights',
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Coming Soon Card
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    CustomIconWidget(
                      iconName: 'insights',
                      color: theme.colorScheme.onPrimary,
                      size: 64,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Coming Soon',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Advanced insights and analytics are on the way!',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onPrimary.withOpacity(0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),

              // Planned Features Section
              Text(
                'Planned Features',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 16),

              _buildFeatureCard(
                context,
                theme,
                icon: 'trending_up',
                title: 'Productivity Trends',
                description:
                    'Track your focus patterns over weeks and months with detailed trend analysis.',
              ),
              SizedBox(height: 12),

              _buildFeatureCard(
                context,
                theme,
                icon: 'bar_chart',
                title: 'App Usage Analytics',
                description:
                    'Detailed breakdown of time spent on different apps and categories.',
              ),
              SizedBox(height: 12),

              _buildFeatureCard(
                context,
                theme,
                icon: 'emoji_events',
                title: 'Achievement Milestones',
                description:
                    'Celebrate your productivity wins with achievements and streaks.',
              ),
              SizedBox(height: 12),

              _buildFeatureCard(
                context,
                theme,
                icon: 'psychology',
                title: 'AI-Powered Recommendations',
                description:
                    'Get personalized suggestions to optimize your focus sessions.',
              ),
              SizedBox(height: 12),

              _buildFeatureCard(
                context,
                theme,
                icon: 'compare',
                title: 'Period Comparisons',
                description:
                    'Compare your productivity across different time periods.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    ThemeData theme, {
    required String icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: CustomIconWidget(
              iconName: icon,
              color: theme.colorScheme.primary,
              size: 28,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
