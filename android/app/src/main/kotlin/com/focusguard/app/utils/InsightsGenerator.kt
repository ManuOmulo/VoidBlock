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
        val recommendations = mutableListOf<Insight>()
        val achievements = mutableListOf<Insight>()
        val warnings = mutableListOf<Insight>()
        val others = mutableListOf<Insight>()
        
        // 0. Usage Spike Detection (New Recommendation Logic)
        val totalUsageTime = appBreakdown.sumOf { it.totalTime }
        if (totalUsageTime > 0) {
            val mostUsedApp = appBreakdown.maxByOrNull { it.totalTime }
            if (mostUsedApp != null) {
                val usagePercentage = (mostUsedApp.totalTime.toDouble() / totalUsageTime) * 100
                if (usagePercentage > 15 && mostUsedApp.totalTime > 30 * 60 * 1000) { // >15% and >30 mins
                    recommendations.add(Insight(
                        type = "RECOMMENDATION",
                        title = "Usage Spike Detected",
                        message = "You've spent ${usagePercentage.toInt()}% of your screen time today on ${mostUsedApp.appName}. Consider a 15-minute limit.",
                        value = formatDuration(mostUsedApp.totalTime),
                        severity = "NEUTRAL"
                    ))
                }
            }
        }
        
        // 1. Productivity Score Insight
        val productivityInsight = generateProductivityInsight(productivityScore)
        if (productivityInsight.type == "TIP") {
            recommendations.add(productivityInsight.copy(type = "RECOMMENDATION"))
        } else {
            achievements.add(productivityInsight)
        }
        
        // 2. Most Blocked App
        val mostBlockedApp = appBreakdown.maxByOrNull { it.blockedCount }
        if (mostBlockedApp != null && mostBlockedApp.blockedCount > 5) {
            warnings.add(Insight(
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
            achievements.add(Insight(
                type = "ACHIEVEMENT",
                title = "Blocking Streak!",
                message = "You've used FocusGuard for $consecutiveDays days in a row",
                value = "$consecutiveDays days",
                severity = "POSITIVE"
            ))
        }
        
        // 4. Time Saved Insight (Cumulative over the period)
        val totalBlocks = dailySummary.sumOf { it.blockedCount }
        val totalTimeSaved = (totalBlocks * 5L * 60 * 1000).coerceAtMost(dailySummary.size * 16L * 60 * 60 * 1000)
        if (totalTimeSaved > 15 * 60 * 1000) { // More than 15 mins saved
            val formattedTime = formatDuration(totalTimeSaved)
            achievements.add(Insight(
                type = "ACHIEVEMENT",
                title = "Total Time Saved",
                message = "You've successfully reclaimed $formattedTime from distractions recently",
                value = formattedTime,
                severity = "POSITIVE"
            ))
        }
        
        // 5. Improvement Trend
        if (dailySummary.size >= 7) {
            val trend = calculateTrend(dailySummary)
            if (trend < -0.1) { // 10% improvement
                achievements.add(Insight(
                    type = "TREND",
                    title = "Improving!",
                    message = "Blocked attempts decreased compared to last week",
                    value = "Trending down",
                    severity = "POSITIVE"
                ))
            }
        }
        
        // 6. Milestone Check
        when {
            totalBlocks >= 500 -> achievements.add(Insight(
                type = "MILESTONE",
                title = "Grand Master!",
                message = "You've successfully blocked $totalBlocks distraction attempts",
                value = "$totalBlocks blocks",
                severity = "POSITIVE"
            ))
            totalBlocks >= 100 -> achievements.add(Insight(
                type = "MILESTONE",
                title = "Century Club!",
                message = "You've successfully blocked $totalBlocks distraction attempts",
                value = "$totalBlocks blocks",
                severity = "POSITIVE"
            ))
        }
        
        // Priority Combine: Recommendations first, then Warnings, then Achievements, then Others
        return recommendations + warnings + achievements + others
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

    private fun formatDuration(millis: Long): String {
        val hours = millis / (1000 * 60 * 60)
        val minutes = (millis % (1000 * 60 * 60)) / (1000 * 60)
        return if (hours > 0) {
            "${hours}h ${minutes}m"
        } else {
            "${minutes}m"
        }
    }
}
