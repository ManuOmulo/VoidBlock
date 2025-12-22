import 'package:flutter/material.dart';
import '../../services/analytics_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../widgets/reports/weekly_bar_chart.dart';
import '../widgets/reports/monthly_activity_grid.dart';
import '../widgets/reports/app_usage_pie_chart.dart';
import '../widgets/reports/productivity_trend_chart.dart';
import '../widgets/reports/recommendations_widget.dart';

/// Insights Screen - Displays detailed productivity analytics and insights
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({Key? key}) : super(key: key);

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();
  late Future<Map<String, dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _fetchAllData();
  }

  Future<Map<String, dynamic>> _fetchAllData() async {
    // Fetch all necessary data in parallel
    final dailyStatsList = await _analyticsService.getDailyStats(days: 30);
    final usageStats = await _analyticsService.getMostUsedApps(limit: 5);

    // Convert List<Map> to Map<DateString, Minutes> for easier chart consumption
    final Map<String, dynamic> dailyStatsMap = {};
    for (var stat in dailyStatsList) {
      if (stat['date'] != null && stat['totalTime'] != null) {
        // Assuming date is in format compatible with our charts or needs parsing
        // If API returns timestamp, we might need conversion.
        // For now assuming existing service contract returns readable date or we handle it.
        dailyStatsMap[stat['date']] = stat['totalTime'];
      }
    }

    return {
      'dailyStats': dailyStatsMap,
      'usageStats': usageStats,
    };
  }

  @override
  Widget build(BuildContext context) {
    // final theme = Theme.of(context); // Unused

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Report',
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text('Error loading insights: ${snapshot.error}'),
              );
            }

            final data = snapshot.data ?? {};
            final dailyStats =
                data['dailyStats'] as Map<String, dynamic>? ?? {};
            final usageStats =
                (data['usageStats'] as List?)?.cast<Map<String, dynamic>>() ??
                    [];

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WeeklyBarChart(dailyStats: dailyStats),
                  const SizedBox(height: 16),
                  MonthlyActivityGrid(dailyStats: dailyStats),
                  const SizedBox(height: 16),
                  AppUsagePieChart(appUsageData: usageStats),
                  const SizedBox(height: 16),
                  ProductivityTrendChart(dailyStats: dailyStats),
                  const SizedBox(height: 16),
                  RecommendationsWidget(
                    dailyStats: dailyStats,
                    usageStats: usageStats,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
