package com.voidblock.app.utils

import com.voidblock.app.data.database.dao.AppUsageBreakdown
import com.voidblock.app.data.database.dao.DailyUsageSummary
import com.voidblock.app.data.database.entities.UsageLogEntity
import java.util.Calendar

/**
 * Generates meaningful insights from usage data
 */
class InsightsGenerator {
    
    data class Insight(
        val type: String,
        val title: String,
        val message: String,
        val value: String,
        val severity: String,
        val actionType: String? = null // For deeplink actions
    )
    
    // App categories for categorization
    private val appCategories = mapOf(
        // Social Media
        "com.instagram.android" to "Social",
        "com.twitter.android" to "Social",
        "com.facebook.katana" to "Social",
        "com.snapchat.android" to "Social",
        "com.tiktok.android" to "Social",
        "com.linkedin.android" to "Social",
        "com.pinterest" to "Social",
        "com.reddit.frontpage" to "Social",
        "com.whatsapp" to "Social",
        "org.telegram.messenger" to "Social",
        
        // Entertainment
        "com.google.android.youtube" to "Entertainment",
        "com.netflix.mediaclient" to "Entertainment",
        "com.spotify.music" to "Entertainment",
        "tv.twitch.android.app" to "Entertainment",
        "com.disney.disneyplus" to "Entertainment",
        "com.amazon.avod.thirdpartyclient" to "Entertainment",
        
        // Games
        "com.supercell.clashofclans" to "Games",
        "com.supercell.clashroyale" to "Games",
        "com.king.candycrushsaga" to "Games",
        "com.mojang.minecraftpe" to "Games",
        "com.activision.callofduty.shooter" to "Games",
        "com.pubg.imobile" to "Games",
        
        // Productivity
        "com.google.android.apps.docs" to "Productivity",
        "com.microsoft.office.word" to "Productivity",
        "com.microsoft.office.excel" to "Productivity",
        "com.notion.id" to "Productivity",
        "com.todoist" to "Productivity",
        "com.google.android.calendar" to "Productivity"
    )
    
    /**
     * Generate insights from usage data
     */
    fun generateInsights(
        dailySummary: List<DailyUsageSummary>,
        appBreakdown: List<AppUsageBreakdown>,
        logs: List<UsageLogEntity>,
        focusSessions: List<com.voidblock.app.data.database.entities.FocusSessionEntity>,
        productiveRatio: Double
    ): List<Insight> {
        val recommendations = mutableListOf<Insight>()
        val achievements = mutableListOf<Insight>()
        val warnings = mutableListOf<Insight>()
        val others = mutableListOf<Insight>()
        
        val totalBlocks = dailySummary.sumOf { it.blockedCount }
        
        // 0. Usage Spike Detection
        val totalUsageTime = appBreakdown.sumOf { it.totalTime }
        if (totalUsageTime > 0) {
            val mostUsedApp = appBreakdown.maxByOrNull { it.totalTime }
            if (mostUsedApp != null) {
                val usagePercentage = (mostUsedApp.totalTime.toDouble() / totalUsageTime) * 100
                if (usagePercentage > 15 && mostUsedApp.totalTime > 30 * 60 * 1000) {
                    recommendations.add(Insight(
                        type = "RECOMMENDATION",
                        title = "Usage Spike Detected",
                        message = "You've spent ${usagePercentage.toInt()}% of your screen time on ${mostUsedApp.appName}. Consider setting a limit.",
                        value = formatDuration(mostUsedApp.totalTime),
                        severity = "RECOMMENDATION",
                        actionType = "CREATE_LIMIT"
                    ))
                }
            }
        }
        
        // 1. Category Breakdown
        val categoryBreakdown = generateCategoryBreakdown(appBreakdown)
        if (categoryBreakdown != null) {
            val (topCategory, percentage) = categoryBreakdown
            if (topCategory in listOf("Social", "Entertainment", "Games") && percentage > 40) {
                recommendations.add(Insight(
                    type = "RECOMMENDATION",
                    title = "$topCategory Apps Dominating",
                    message = "$topCategory apps take ${percentage}% of your screen time. Try blocking this category during work hours.",
                    value = "${percentage}%",
                    severity = "RECOMMENDATION"
                ))
            }
        }
        
        // 2. Enhanced Productive Ratio
        val productivityInsight = generateProductiveRatioInsight(productiveRatio, dailySummary)
        if (productivityInsight.severity == "POSITIVE") {
            achievements.add(productivityInsight)
        } else {
            recommendations.add(productivityInsight)
        }
        
        // 3. Most Blocked App
        val mostBlockedApp = appBreakdown.maxByOrNull { it.blockedCount }
        if (mostBlockedApp != null && mostBlockedApp.blockedCount > 5) {
            warnings.add(Insight(
                type = "WARNING",
                title = "Most Distracted By",
                message = "You tried to open ${mostBlockedApp.appName} ${mostBlockedApp.blockedCount} times while blocked.",
                value = "${mostBlockedApp.blockedCount} attempts",
                severity = "NEGATIVE"
            ))
        }
        
        // 4. Streak Insight
        val consecutiveDays = calculateConsecutiveDays(dailySummary)
        if (consecutiveDays >= 3) {
            val nextMilestone = when {
                consecutiveDays < 7 -> 7
                consecutiveDays < 14 -> 14
                consecutiveDays < 30 -> 30
                else -> ((consecutiveDays / 30) + 1) * 30
            }
            val daysToMilestone = nextMilestone - consecutiveDays
            
            achievements.add(Insight(
                type = "ACHIEVEMENT",
                title = "Blocking Streak!",
                message = "You've used VoidBlock for $consecutiveDays days in a row. $daysToMilestone more to reach $nextMilestone!",
                value = "$consecutiveDays days",
                severity = "POSITIVE"
            ))
        }
        
        // 5. Best Focus Day
        val bestDay = findBestFocusDay(dailySummary)
        if (bestDay != null) {
            others.add(Insight(
                type = "TREND",
                title = "Best Focus Day",
                message = "${bestDay.first} was your most focused day with only ${bestDay.second} blocks needed.",
                value = bestDay.first,
                severity = "POSITIVE"
            ))
        }
        
        // 6. Weekend vs Weekday
        val weekendComparison = compareWeekendVsWeekday(dailySummary)
        if (weekendComparison != null) {
            val (weekdayAvg, weekendAvg) = weekendComparison
            if (weekendAvg > weekdayAvg * 1.3) {
                val percentMore = ((weekendAvg - weekdayAvg) / weekdayAvg * 100).toInt()
                recommendations.add(Insight(
                    type = "RECOMMENDATION",
                    title = "Weekend Screen Time Higher",
                    message = "You get blocked ${percentMore}% more on weekends. Consider a weekend schedule.",
                    value = "+${percentMore}%",
                    severity = "NEUTRAL",
                    actionType = "CREATE_SCHEDULE"
                ))
            }
        }
        
        // 7. Peak Distraction Hour (NEW)
        val peakHour = findPeakDistractionHour(logs)
        if (peakHour != null) {
            val (hour, count) = peakHour
            val hourStr = if (hour == 0) "12 AM" else if (hour < 12) "$hour AM" else if (hour == 12) "12 PM" else "${hour - 12} PM"
            recommendations.add(Insight(
                type = "RECOMMENDATION",
                title = "Peak Distraction Time",
                message = "You get blocked most around $hourStr. A scheduled session then could be effective.",
                value = "$count blocks",
                severity = "RECOMMENDATION",
                actionType = "CREATE_SCHEDULE"
            ))
        }

        // 8. Limit Enforcement (NEW)
        // Assuming logs show distinct blocking events. High frequency short blocks might indicate limit enforcement struggle.
        // Or we just check total blocked count ratio to active time?
        // Let's check for repeated rapid blocks.
        val rapidBlocks = countRapidBlocks(logs)
        if (rapidBlocks > 5) {
             warnings.add(Insight(
                type = "WARNING",
                title = "Persistently Distracted",
                message = "You triggered multiple blocks in short succession $rapidBlocks times. Try increasing Strict Mode.",
                value = "$rapidBlocks incidents",
                severity = "NEGATIVE",
                actionType = "SETTINGS"
            ))
        }
        
        // 9. Focus Time Achievement (Using Union to avoid double counting)
        val currentTime = System.currentTimeMillis()
        val intervals = focusSessions.map { 
            it.startTime to (it.endTime ?: currentTime)
        }.sortedBy { it.first }
        
        var totalFocusMillis = 0L
        if (intervals.isNotEmpty()) {
            var currentStart = intervals[0].first
            var currentEnd = intervals[0].second
            
            for (i in 1 until intervals.size) {
                val nextStart = intervals[i].first
                val nextEnd = intervals[i].second
                
                if (nextStart <= currentEnd) {
                    currentEnd = maxOf(currentEnd, nextEnd)
                } else {
                    totalFocusMillis += (currentEnd - currentStart)
                    currentStart = nextStart
                    currentEnd = nextEnd
                }
            }
            totalFocusMillis += (currentEnd - currentStart)
        }

        if (totalFocusMillis > 15 * 60 * 1000) {
            val formattedTime = formatDuration(totalFocusMillis)
            achievements.add(Insight(
                type = "TREND",
                title = "Focus Milestone",
                message = "You've dedicated $formattedTime to deep work this week. Remarkable!",
                value = formattedTime,
                severity = "POSITIVE"
            ))
        }
        
        // 10. Improvement Trend
        if (dailySummary.size >= 7) {
            val trend = calculateTrend(dailySummary)
            if (trend < -0.1) {
                achievements.add(Insight(
                    type = "TREND",
                    title = "Improving!",
                    message = "Blocked attempts decreased compared to last week. You're building better habits!",
                    value = "Trending down",
                    severity = "POSITIVE"
                ))
            } else if (trend > 0.2) {
                recommendations.add(Insight(
                    type = "RECOMMENDATION",
                    title = "Distraction Increasing",
                    message = "Block attempts are up this week. Try MEDIUM or HARD strict mode.",
                    value = "Trending up",
                    severity = "RECOMMENDATION"
                ))
            }
        }
        
        // 11. Milestones
        when {
            totalBlocks >= 500 -> achievements.add(Insight(
                type = "MILESTONE",
                title = "Grand Master!",
                message = "You've successfully blocked $totalBlocks distraction attempts!",
                value = "$totalBlocks blocks",
                severity = "POSITIVE"
            ))
            totalBlocks >= 100 -> achievements.add(Insight(
                type = "MILESTONE",
                title = "Century Club!",
                message = "You've successfully blocked $totalBlocks distraction attempts!",
                value = "$totalBlocks blocks",
                severity = "POSITIVE"
            ))
        }
        
        return recommendations + warnings + achievements + others
    }
    
    // ... helper methods ...

    private fun findPeakDistractionHour(logs: List<UsageLogEntity>): Pair<Int, Int>? {
        if (logs.isEmpty()) return null
        
        val blockedLogs = logs.filter { it.wasBlocked }
        if (blockedLogs.isEmpty()) return null
        
        val hourCounts = IntArray(24)
        val calendar = Calendar.getInstance()
        
        for (log in blockedLogs) {
            calendar.timeInMillis = log.startTime
            val hour = calendar.get(Calendar.HOUR_OF_DAY)
            hourCounts[hour]++
        }
        
        var maxCount = 0
        var peakHour = -1
        
        for (i in 0 until 24) {
            if (hourCounts[i] > maxCount) {
                maxCount = hourCounts[i]
                peakHour = i
            }
        }
        
        return if (peakHour != -1 && maxCount >= 3) { // Threshold of 3 to be significant
            Pair(peakHour, maxCount)
        } else {
            null
        }
    }

    private fun countRapidBlocks(logs: List<UsageLogEntity>): Int {
        val blockedLogs = logs.filter { it.wasBlocked }.sortedBy { it.startTime }
        if (blockedLogs.size < 2) return 0
        
        var rapidBlockIncidents = 0
        var i = 0
        while (i < blockedLogs.size - 1) {
            if (blockedLogs[i+1].startTime - blockedLogs[i].startTime < 60 * 1000) { // Less than 1 minute apart
                rapidBlockIncidents++
                i += 2 // Skip the pair
            } else {
                i++
            }
        }
        return rapidBlockIncidents
    }

    private fun generateCategoryBreakdown(appBreakdown: List<AppUsageBreakdown>): Pair<String, Int>? {
        val categoryTotals = mutableMapOf<String, Long>()
        var totalTime = 0L
        
        for (app in appBreakdown) {
            val category = appCategories[app.packageName] ?: "Other"
            categoryTotals[category] = (categoryTotals[category] ?: 0L) + app.totalTime
            totalTime += app.totalTime
        }
        
        if (totalTime == 0L) return null
        
        val topCategory = categoryTotals.maxByOrNull { it.value } ?: return null
        val percentage = (topCategory.value * 100 / totalTime).toInt()
        
        return Pair(topCategory.key, percentage)
    }
    
    private fun generateProductiveRatioInsight(productiveRatio: Double, dailySummary: List<DailyUsageSummary>): Insight {
        val weekAgoComparison = if (dailySummary.size >= 14) {
            val thisWeek = dailySummary.take(7).sumOf { it.blockedCount }
            val lastWeek = dailySummary.drop(7).take(7).sumOf { it.blockedCount }
            if (lastWeek > 0) {
                val change = ((thisWeek - lastWeek).toDouble() / lastWeek * 100).toInt()
                if (change < 0) "down ${-change}% from last week" else "up $change% from last week"
            } else null
        } else null
        
        val contextSuffix = if (weekAgoComparison != null) " ($weekAgoComparison)" else ""
        
        return when {
            productiveRatio >= 50 -> Insight(
                type = "ACHIEVEMENT",
                title = "Excellent Focus! (7-day avg)",
                message = "Your productive ratio is outstanding$contextSuffix",
                value = "${productiveRatio.toInt()}%",
                severity = "POSITIVE"
            )
            productiveRatio >= 30 -> Insight(
                type = "TREND",
                title = "Good Progress (7-day avg)",
                message = "Your productive ratio is good$contextSuffix",
                value = "${productiveRatio.toInt()}%",
                severity = "NEUTRAL"
            )
            productiveRatio >= 15 -> Insight(
                type = "RECOMMENDATION",
                title = "Room for Improvement (7-day avg)",
                message = "Your productive ratio needs improvement$contextSuffix",
                value = "${productiveRatio.toInt()}%",
                severity = "RECOMMENDATION"
            )
            else -> Insight(
                type = "RECOMMENDATION",
                title = "Low Productive Ratio (7-day avg)",
                message = "Your productive ratio is low. Try longer focus sessions$contextSuffix",
                value = "${productiveRatio.toInt()}%",
                severity = "RECOMMENDATION"
            )
        }
    }
    
    private fun findBestFocusDay(summary: List<DailyUsageSummary>): Pair<String, Int>? {
        if (summary.isEmpty()) return null
        
        val bestDay = summary.filter { it.blockedCount > 0 }.minByOrNull { it.blockedCount } ?: return null
        
        val dayNames = listOf("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")
        val calendar = Calendar.getInstance()
        calendar.timeInMillis = System.currentTimeMillis() - ((summary.indexOf(bestDay)) * 24 * 60 * 60 * 1000L)
        val dayOfWeek = calendar.get(Calendar.DAY_OF_WEEK) - 1
        
        return Pair(dayNames.getOrElse(dayOfWeek) { "Day" }, bestDay.blockedCount)
    }
    
    private fun compareWeekendVsWeekday(summary: List<DailyUsageSummary>): Pair<Double, Double>? {
        if (summary.size < 7) return null
        
        val calendar = Calendar.getInstance()
        var weekdayTotal = 0
        var weekdayCount = 0
        var weekendTotal = 0
        var weekendCount = 0
        
        for (i in summary.indices) {
            calendar.timeInMillis = System.currentTimeMillis() - (i * 24 * 60 * 60 * 1000L)
            val dayOfWeek = calendar.get(Calendar.DAY_OF_WEEK)
            
            if (dayOfWeek == Calendar.SATURDAY || dayOfWeek == Calendar.SUNDAY) {
                weekendTotal += summary[i].blockedCount
                weekendCount++
            } else {
                weekdayTotal += summary[i].blockedCount
                weekdayCount++
            }
        }
        
        if (weekdayCount == 0 || weekendCount == 0) return null
        
        val weekdayAvg = weekdayTotal.toDouble() / weekdayCount
        val weekendAvg = weekendTotal.toDouble() / weekendCount
        
        return Pair(weekdayAvg, weekendAvg)
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
