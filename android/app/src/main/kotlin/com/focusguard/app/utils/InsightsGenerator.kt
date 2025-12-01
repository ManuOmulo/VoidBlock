package com.focusguard.app.utils

import com.focusguard.app.data.database.dao.AppUsageBreakdown
import com.focusguard.app.data.database.dao.DailyUsageSummary

/**
 * Generates meaningful insights from usage data
 */
class InsightsGenerator {
    
    data class Insight(
        val type: String,
        val title: String,
        val message: String,
        val value: String,
        val severity: String
    )
    
    /**
     * Generate insights from usage data
     */
    fun generateInsights(
        dailySummary: List<DailyUsageSummary>,
        appBreakdown: List<AppUsageBreakdown>,
        productivityScore: Double
    ): List<Insight> {
        val insights = mutableListOf<Insight>()
        
        // 1. Productivity Score Insight
        insights.add(generateProductivityInsight(productivityScore))
        
        // 2. Most Blocked App
        val mostBlockedApp = appBreakdown.maxByOrNull { it.blockedCount }
        if (mostBlockedApp != null && mostBlockedApp.blockedCount > 5) {
            insights.add(Insight(
                type = "WARNING",
                title = "Most Distracted By",
                message = "You attempted to open ${mostBlockedApp.appName} ${mostBlockedApp.blockedCount} times while blocked",
                value = "${mostBlockedApp.blockedCount} attempts",
                severity = "NEGATIVE"
            ))
        }
        
        // 3. Streak Insight
        val consecutiveDays = calculateConsecutiveDays(dailySummary)
        if (consecutiveDays >= 3) {
            insights.add(Insight(
                type = "ACHIEVEMENT",
                title = "Blocking Streak!",
                message = "You've used FocusGuard for $consecutiveDays days in a row",
                value = "$consecutiveDays days",
                severity = "POSITIVE"
            ))
        }
        
        // 4. Time Saved Insight
        val totalTimeSaved = dailySummary.sumOf { it.totalTime }
        val hours = totalTimeSaved / (1000 * 60 * 60)
        if (hours > 1) {
            insights.add(Insight(
                type = "ACHIEVEMENT",
                title = "Time Recovered",
                message = "You've saved ${hours}h from distracting apps",
                value = "${hours}h",
                severity = "POSITIVE"
            ))
        }
        
        // 5. Improvement Trend
        if (dailySummary.size >= 7) {
            val trend = calculateTrend(dailySummary)
            if (trend < -0.1) { // 10% improvement
                insights.add(Insight(
                    type = "TREND",
                    title = "Improving!",
                    message = "Blocked attempts decreased compared to last week",
                    value = "Trending down",
                    severity = "POSITIVE"
                ))
            }
        }
        
        // 6. Milestone Check
        val totalBlocks = dailySummary.sumOf { it.blockedCount }
        when {
            totalBlocks >= 500 -> insights.add(Insight(
                type = "MILESTONE",
                title = "Grand Master!",
                message = "You've successfully blocked $totalBlocks distraction attempts",
                value = "$totalBlocks blocks",
                severity = "POSITIVE"
            ))
            totalBlocks >= 100 -> insights.add(Insight(
                type = "MILESTONE",
                title = "Century Club!",
                message = "You've successfully blocked $totalBlocks distraction attempts",
                value = "$totalBlocks blocks",
                severity = "POSITIVE"
            ))
        }
        
        return insights
    }
    
    private fun generateProductivityInsight(score: Double): Insight {
        return when {
            score >= 80 -> Insight(
                type = "ACHIEVEMENT",
                title = "Excellent Focus!",
                message = "Your productivity score is outstanding",
                value = "${score.toInt()}%",
                severity = "POSITIVE"
            )
            score >= 60 -> Insight(
                type = "TREND",
                title = "Good Progress",
                message = "You're maintaining good focus habits",
                value = "${score.toInt()}%",
                severity = "NEUTRAL"
            )
            else -> Insight(
                type = "TIP",
                title = "Room for Improvement",
                message = "Try creating more blocking schedules to boost productivity",
                value = "${score.toInt()}%",
                severity = "NEUTRAL"
            )
        }
    }
    
    private fun calculateConsecutiveDays(summary: List<DailyUsageSummary>): Int {
        var streak = 0
        for (day in summary.sortedByDescending { it.daysSinceEpoch }) {
            if (day.blockedCount > 0) {
                streak++
            } else {
                break
            }
        }
        return streak
    }
    
    private fun calculateTrend(summary: List<DailyUsageSummary>): Double {
        val sorted = summary.sortedBy { it.daysSinceEpoch }
        val midpoint = sorted.size / 2
        
        val firstHalfAvg = sorted.take(midpoint).map { it.blockedCount }.average()
        val secondHalfAvg = sorted.drop(midpoint).map { it.blockedCount }.average()
        
        return if (firstHalfAvg > 0) {
            (secondHalfAvg - firstHalfAvg) / firstHalfAvg
        } else {
            0.0
        }
    }
}
