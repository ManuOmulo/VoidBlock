import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/analytics_service.dart';

class PeakUsageHeatmap extends StatefulWidget {
  const PeakUsageHeatmap({Key? key}) : super(key: key);

  @override
  State<PeakUsageHeatmap> createState() => PeakUsageHeatmapState();
}

class PeakUsageHeatmapState extends State<PeakUsageHeatmap> {
  final AnalyticsService _analyticsService = AnalyticsService();
  List<int> _hourlyData = List.filled(24, 0);
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final data = await _analyticsService.getPeakUsagePattern(days: 1);
      if (mounted) {
        setState(() {
          _hourlyData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading peak usage: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Public method to refresh the peak usage data
  Future<void> refresh() async {
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Peak Phone Usage',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                'Today',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          _isLoading
              ? Container(
                  height: 150,
                  child: Center(child: CircularProgressIndicator()),
                )
              : Container(
                  height: 150,
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: _getMaxY(),
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          tooltipBgColor:
                              theme.colorScheme.surfaceContainerHighest,
                          tooltipRoundedRadius: 8,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              '${_formatHour(group.x.toInt())}\n',
                              theme.textTheme.labelMedium!.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                              children: [
                                TextSpan(
                                  text: '${rod.toY.round()}m',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value % 6 != 0) return Container();
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  _formatHour(value.toInt(), short: true),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 9,
                                    color: theme.colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: _generateGroups(theme),
                    ),
                  ),
                ),
          SizedBox(height: 12),
          Text(
            'Your peak usage today was around ${_formatHour(int.parse(_getPeakHour()))}.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  double _getMaxY() {
    int maxVal = 0;
    for (var val in _hourlyData) {
      if (val > maxVal) maxVal = val;
    }
    return (maxVal + 5).toDouble().clamp(30.0, 1440.0);
  }

  List<BarChartGroupData> _generateGroups(ThemeData theme) {
    return List.generate(24, (i) {
      final value = _hourlyData[i].toDouble();
      final isPeak =
          value > 0 && value == _hourlyData.reduce((a, b) => a > b ? a : b);

      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: value,
            color: isPeak
                ? theme.colorScheme.primary
                : theme.colorScheme.primary.withValues(alpha: 0.3),
            width: 8,
            borderRadius: BorderRadius.circular(4),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: _getMaxY(),
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
            ),
          ),
        ],
      );
    });
  }

  String _getPeakHour() {
    int maxIdx = 0;
    for (int i = 0; i < _hourlyData.length; i++) {
      if (_hourlyData[i] > _hourlyData[maxIdx]) maxIdx = i;
    }
    return maxIdx.toString().padLeft(2, '0');
  }

  String _formatHour(int hour, {bool short = false}) {
    if (hour == 0) return short ? '12 AM' : '12 AM';
    if (hour == 12) return short ? '12 PM' : '12 PM';
    if (hour < 12) return short ? '${hour} AM' : '$hour AM';
    return short ? '${hour - 12} PM' : '${hour - 12} PM';
  }
}
