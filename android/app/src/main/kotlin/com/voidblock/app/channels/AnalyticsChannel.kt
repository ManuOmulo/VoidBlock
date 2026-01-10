package com.voidblock.app.channels

import android.content.Context
import java.text.SimpleDateFormat
import java.util.*
import com.voidblock.app.data.database.AppDatabase
import com.voidblock.app.data.database.dao.DailyFocusSummary
import com.voidblock.app.utils.InstalledAppsManager
import com.voidblock.app.utils.ProductivityCalculator
import com.voidblock.app.utils.InsightsGenerator
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import android.app.usage.UsageStatsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStats
import java.io.File

/**
 * Platform channel for analytics and usage tracking operations
 */
class AnalyticsChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    
    private val appsManager = InstalledAppsManager(context)
    private val database = AppDatabase.getInstance(context)
    private val productivityCalculator = ProductivityCalculator()
    private val insightsGenerator = InsightsGenerator()
    private val scope = CoroutineScope(Dispatchers.Main)
    private val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
    
    companion object {
        const val CHANNEL_NAME = "com.voidblock.app/analytics"
    }
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getUsageStats" -> {
                val days = call.argument<Int>("days") ?: 7
                getUsageStats(days, result)
            }
            
            "getInstalledApps" -> {
                getInstalledApps(result)
            }
            
            "getUserApps" -> {
                getUserApps(result)
            }
            
            "searchApps" -> {
                val query = call.argument<String>("query") ?: ""
                val includeSystem = call.argument<Boolean>("includeSystem") ?: false
                searchApps(query, includeSystem, result)
            }
            
            "getAppInfo" -> {
                val packageName = call.argument<String>("packageName")
                if (packageName != null) {
                    getAppInfo(packageName, result)
                } else {
                    result.error("INVALID_ARGS", "Package name is required", null)
                }
            }
            
            "getAppUsageTime" -> {
                val packageName = call.argument<String>("packageName")
                val days = call.argument<Int>("days") ?: 7
                if (packageName != null) {
                    getAppUsageTime(packageName, days, result)
                } else {
                    result.error("INVALID_ARGS", "Package name is required", null)
                }
            }
            
            "getProductivityScore" -> {
                val days = call.argument<Int>("days") ?: 7
                getProductivityScore(days, result)
            }
            
            "getMostUsedApps" -> {
                val limit = call.argument<Int>("limit") ?: 10
                val days = call.argument<Int>("days") ?: 7
                getMostUsedApps(days, limit, result)
            }
            
            "getInsights" -> {
                val days = call.argument<Int>("days") ?: 7
                getInsights(days, result)
            }
            
            "getDailyStats" -> {
                val days = call.argument<Int>("days") ?: 30
                getDailyStats(days, result)
            }
            
            "exportUsageData" -> {
                val startTime = call.argument<Long>("startTime") ?: 0
                val endTime = call.argument<Long>("endTime") ?: System.currentTimeMillis()
                exportUsageData(startTime, endTime, result)
            }

            "clearUsageData" -> {
                clearUsageData(result)
            }
            
            "getPeakUsagePattern" -> {
                val days = call.argument<Int>("days") ?: 1
                getPeakUsagePattern(days, result)
            }
            
            else -> result.notImplemented()
        }
    }
    
    /**
     * Clear all usage data
     */
    private fun clearUsageData(result: MethodChannel.Result) {
        scope.launch {
            try {
                withContext(Dispatchers.IO) {
                    database.usageLogDao().clearAllLogs()
                }
                result.success(true)
            } catch (e: Exception) {
                e.printStackTrace()
                result.error("CLEAR_ERROR", e.message, null)
            }
        }
    }
    
    /**
     * Get usage statistics for specified period
     */
    private fun getUsageStats(days: Int, result: MethodChannel.Result) {
        scope.launch {
            try {
                val startTime = if (days == 1) {
                    val cal = Calendar.getInstance()
                    cal.set(Calendar.HOUR_OF_DAY, 0)
                    cal.set(Calendar.MINUTE, 0)
                    cal.set(Calendar.SECOND, 0)
                    cal.set(Calendar.MILLISECOND, 0)
                    cal.timeInMillis
                } else if (days == 7) {
                    // Weekly reset: Start of current week (Monday 00:00:00)
                    val cal = Calendar.getInstance()
                    cal.set(Calendar.DAY_OF_WEEK, Calendar.MONDAY)
                    cal.set(Calendar.HOUR_OF_DAY, 0)
                    cal.set(Calendar.MINUTE, 0)
                    cal.set(Calendar.SECOND, 0)
                    cal.set(Calendar.MILLISECOND, 0)
                    
                    if (cal.timeInMillis > System.currentTimeMillis()) {
                        cal.add(Calendar.WEEK_OF_YEAR, -1)
                    }
                    cal.timeInMillis
                } else {
                    System.currentTimeMillis() - (days * 24 * 60 * 60 * 1000L)
                }
                
                val stats = withContext(Dispatchers.IO) {
                    val rawBlockedTime = database.usageLogDao().getTotalBlockedTime(startTime) ?: 0L
                    val blockedCount = database.usageLogDao().getBlockedAttemptsCount(startTime)
                    val uniqueApps = database.usageLogDao().getUniqueBlockedAppsCount(startTime)
                    
                    val currentTime = System.currentTimeMillis()
                    
                    // NEW: Calculate Total Focus Time by merging overlapping intervals (Excluding LIMIT type)
                    val rawSessions = database.focusSessionDao().getOverlappingSessionsExcludingType(startTime, currentTime)
                    val intervals = rawSessions.map { 
                        // Clip intervals to the requested period [startTime, currentTime]
                        maxOf(startTime, it.startTime) to minOf(currentTime, it.endTime ?: currentTime)
                    }.filter { it.first < it.second }.sortedBy { it.first }
                    
                    var totalFocusTimeMs = 0L
                    if (intervals.isNotEmpty()) {
                        var currentStart = intervals[0].first
                        var currentEnd = intervals[0].second
                        
                        for (i in 1 until intervals.size) {
                            val nextStart = intervals[i].first
                            val nextEnd = intervals[i].second
                            
                            if (nextStart <= currentEnd) {
                                currentEnd = maxOf(currentEnd, nextEnd)
                            } else {
                                totalFocusTimeMs += (currentEnd - currentStart)
                                currentStart = nextStart
                                currentEnd = nextEnd
                            }
                        }
                        totalFocusTimeMs += (currentEnd - currentStart)
                    }
                    
                    // Improved Time Saved Calculation (Personalized)
                    val thirtyDaysAgo = System.currentTimeMillis() - (30 * 24 * 60 * 60 * 1000L)
                    val historyBreakdown = database.usageLogDao().getAppUsageBreakdown(thirtyDaysAgo)
                    
                    var totalActiveTime = 0L
                    var totalActiveSessions = 0L
                    for (row in historyBreakdown) {
                        totalActiveTime += row.totalTime
                        totalActiveSessions += (row.usageCount - row.blockedCount).coerceAtLeast(0)
                    }
                    
                    val avgSessionDurationMs = if (totalActiveSessions > 0) {
                        (totalActiveTime / totalActiveSessions).coerceAtMost(15 * 60 * 1000L)
                    } else {
                        5 * 60 * 1000L // 5 min fallback
                    }
                    
                    val estimatedTimeSaved = rawBlockedTime + (blockedCount * avgSessionDurationMs)
                    
                    // Real System Usage Total
                    val systemStats = usageStatsManager.queryAndAggregateUsageStats(startTime, System.currentTimeMillis())
                    val totalSystemUsageMs = systemStats.values.sumOf { it.totalTimeInForeground }
                    
                    mapOf(
                        "blockedTime" to estimatedTimeSaved,
                        "totalFocusTime" to totalFocusTimeMs,
                        "blockedCount" to blockedCount,
                        "uniqueBlockedApps" to uniqueApps,
                        "totalUsageTime" to totalSystemUsageMs,
                        "days" to days
                    )
                }
                
                result.success(stats)
            } catch (e: Exception) {
                e.printStackTrace()
                result.error("STATS_ERROR", e.message, null)
            }
        }
    }
    
    /**
     * Calculate productivity score
     */
    private fun getProductivityScore(days: Int, result: MethodChannel.Result) {
        scope.launch {
            try {
                val startTime = System.currentTimeMillis() - (days * 24 * 60 * 60 * 1000L)
                
                val score = withContext(Dispatchers.IO) {
                    val logs = database.usageLogDao().getLogsForPastDays(startTime)
                    val blockedCount = logs.filter { it.wasBlocked }.size
                    val totalBlockedTime = logs.filter { it.wasBlocked }.sumOf { it.durationMillis }
                    
                    val systemStats = usageStatsManager.queryAndAggregateUsageStats(startTime, System.currentTimeMillis())
                    val totalUsageTime = systemStats.values.sumOf { it.totalTimeInForeground }
                    
                    productivityCalculator.calculateProductivityScore(blockedCount, totalBlockedTime, totalUsageTime, days)
                }
                
                result.success(score)
            } catch (e: Exception) {
                e.printStackTrace()
                result.error("SCORE_ERROR", e.message, null)
            }
        }
    }
    
    /**
     * Get most used apps
     */
    private fun getMostUsedApps(days: Int, limit: Int, result: MethodChannel.Result) {
        scope.launch {
            try {
                val startTime = System.currentTimeMillis() - (days * 24 * 60 * 60 * 1000L)
                
                val apps = withContext(Dispatchers.IO) {
                    database.usageLogDao().getMostUsedApps(startTime, limit)
                }
                
                val appsList = withContext(Dispatchers.IO) {
                    val systemStats = usageStatsManager.queryAndAggregateUsageStats(startTime, System.currentTimeMillis())
                    
                    systemStats.values
                        .filter { it.totalTimeInForeground > 0 }
                        .sortedByDescending { it.totalTimeInForeground }
                        .take(limit)
                        .map { stat ->
                            val appInfo = appsManager.getAppInfo(stat.packageName)
                            mapOf(
                                "packageName" to stat.packageName,
                                "appName" to (appInfo?.appName ?: stat.packageName),
                                "usageMinutes" to (stat.totalTimeInForeground / 60000).toInt()
                            )
                        }
                }
                
                result.success(appsList)
            } catch (e: Exception) {
                e.printStackTrace()
                result.error("FETCH_ERROR", e.message, null)
            }
        }
    }
    
    /**
     * Get usage time for specific app
     */
    private fun getAppUsageTime(packageName: String, days: Int, result: MethodChannel.Result) {
        scope.launch {
            try {
                val startTime = System.currentTimeMillis() - (days * 24 * 60 * 60 * 1000L)
                
                val usageTime = withContext(Dispatchers.IO) {
                    database.usageLogDao().getTotalUsageForApp(packageName, startTime) ?: 0L
                }
                
                result.success(usageTime)
            } catch (e: Exception) {
                e.printStackTrace()
                result.error("FETCH_ERROR", e.message, null)
            }
        }
    }
    
    /**
     * Generate insights from usage data
     */
    private fun getInsights(days: Int, result: MethodChannel.Result) {
        scope.launch {
            try {
                val startTime = System.currentTimeMillis() - (days * 24 * 60 * 60 * 1000L)
                
                val insights = withContext(Dispatchers.IO) {
                    val dailySummary = database.usageLogDao().getDailyUsageSummary(startTime)
                    val appBreakdown = database.usageLogDao().getAppUsageBreakdown(startTime)
                    val logs = database.usageLogDao().getLogsForPastDays(startTime)
                    
                    val blockedCount = logs.filter { it.wasBlocked }.size
                    val totalBlockedTime = logs.filter { it.wasBlocked }.sumOf { it.durationMillis }
                    val systemStats = usageStatsManager.queryAndAggregateUsageStats(startTime, System.currentTimeMillis())
                    val totalUsageTime = systemStats.values.sumOf { it.totalTimeInForeground }
                    
                    val focusSessions = database.focusSessionDao().getOverlappingSessionsExcludingType(startTime, System.currentTimeMillis())
                    
                    val score = productivityCalculator.calculateProductivityScore(blockedCount, totalBlockedTime, totalUsageTime, days)
                    
                    insightsGenerator.generateInsights(dailySummary, appBreakdown, logs, focusSessions, score)
                }
                
                val insightsList = insights.map { insight ->
                    mapOf(
                        "type" to insight.type,
                        "title" to insight.title,
                        "message" to insight.message,
                        "value" to insight.value,
                        "severity" to insight.severity
                    )
                }
                
                result.success(insightsList)
            } catch (e: Exception) {
                e.printStackTrace()
                result.error("INSIGHTS_ERROR", e.message, null)
            }
        }
    }
    
    /**
     * Get daily statistics summary
     */
    private fun getDailyStats(days: Int, result: MethodChannel.Result) {
        scope.launch {
            try {
                val currentTime = System.currentTimeMillis()
                val globalStartTime = currentTime - (days * 24 * 60 * 60 * 1000L)
                
                val dailyFocusStats: List<DailyFocusSummary> = withContext(Dispatchers.IO) {
                    val rawSessions = database.focusSessionDao().getOverlappingSessionsExcludingType(globalStartTime, currentTime)
                    
                    // 1. Merge overlapping intervals globally first
                    val globalIntervals = rawSessions.map { 
                        maxOf(globalStartTime, it.startTime) to minOf(currentTime, it.endTime ?: currentTime)
                    }.filter { it.first < it.second }.sortedBy { it.first }
                    
                    val mergedIntervals = mutableListOf<Pair<Long, Long>>()
                    if (globalIntervals.isNotEmpty()) {
                        var currentStart = globalIntervals[0].first
                        var currentEnd = globalIntervals[0].second
                        for (i in 1 until globalIntervals.size) {
                            val nextStart = globalIntervals[i].first
                            val nextEnd = globalIntervals[i].second
                            if (nextStart <= currentEnd) {
                                currentEnd = maxOf(currentEnd, nextEnd)
                            } else {
                                mergedIntervals.add(currentStart to currentEnd)
                                currentStart = nextStart
                                currentEnd = nextEnd
                            }
                        }
                        mergedIntervals.add(currentStart to currentEnd)
                    }
                    
                    // 2. Fragment merged intervals into days
                    val dayMap = mutableMapOf<Int, Long>()
                    mergedIntervals.forEach { (start, end) ->
                        var s = start
                        while (s < end) {
                            val cal = Calendar.getInstance()
                            cal.timeInMillis = s
                            cal.set(Calendar.HOUR_OF_DAY, 0)
                            cal.set(Calendar.MINUTE, 0)
                            cal.set(Calendar.SECOND, 0)
                            cal.set(Calendar.MILLISECOND, 0)
                            val dayStart = cal.timeInMillis
                            val daySinceEpoch = (dayStart / 86400000).toInt()
                            
                            val nextMidnight = dayStart + 86400000
                            val endOfThisDayFragment = minOf(end, nextMidnight)
                            
                            val duration = endOfThisDayFragment - s
                            dayMap[daySinceEpoch] = (dayMap[daySinceEpoch] ?: 0L) + duration
                            s = nextMidnight
                        }
                    }
                    
                    dayMap.map { (day, total) ->
                        DailyFocusSummary(day, total)
                    }.sortedByDescending { it.daysSinceEpoch }
                }
                
                val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
                val statsList = mutableListOf<Map<String, Any>>()
                
                // Aggregate focus time per day
                for (i in 0 until days) {
                    val cal = Calendar.getInstance()
                    cal.add(Calendar.DAY_OF_YEAR, -i)
                    cal.set(Calendar.HOUR_OF_DAY, 0)
                    cal.set(Calendar.MINUTE, 0)
                    cal.set(Calendar.SECOND, 0)
                    cal.set(Calendar.MILLISECOND, 0)
                    val dayStart = cal.timeInMillis
                    val daySinceEpoch = (dayStart / 86400000).toInt()
                    
                    val focusMillis = dailyFocusStats.find { it.daysSinceEpoch == daySinceEpoch }?.totalMillis ?: 0L
                    
                    statsList.add(mapOf(
                        "date" to dateFormat.format(Date(dayStart)),
                        "focusMinutes" to (focusMillis / 60000).toInt(),
                        "totalTime" to (focusMillis / 60000).toInt() // For backward compatibility
                    ))
                }
                
                result.success(statsList)
            } catch (e: Exception) {
                e.printStackTrace()
                result.error("STATS_ERROR", e.message, null)
            }
        }
    }
    
    /**
     * Export usage data to CSV
     */
    private fun exportUsageData(startTime: Long, endTime: Long, result: MethodChannel.Result) {
        scope.launch {
            try {
                val csvData = withContext(Dispatchers.IO) {
                    val logs = database.usageLogDao().getLogsForPeriod(startTime, endTime)
                    val focusSessions = database.focusSessionDao().getOverlappingSessionsExcludingType(startTime, endTime)
                    
                    val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
                    val timeFormat = SimpleDateFormat("HH:mm:ss", Locale.US)
                    
                    val csv = StringBuilder()
                    csv.append("Date,Time,Type,Subject,Category,Duration/Target (min),Status,Related Session\n")
                    
                    // Group data by day for summaries
                    val allDays = mutableSetOf<String>()
                    logs.forEach { allDays.add(dateFormat.format(Date(it.startTime))) }
                    focusSessions.forEach { allDays.add(dateFormat.format(Date(it.startTime))) }
                    
                    val sortedDays = allDays.sortedDescending()
                    
                    sortedDays.forEach { dayStr ->
                        val dayStartCal = Calendar.getInstance()
                        dayStartCal.time = dateFormat.parse(dayStr) ?: Date()
                        val dayStart = dayStartCal.timeInMillis
                        val dayEnd = dayStart + 86400000L
                        
                        // 1. Daily Summary Row
                        val dayLogs = logs.filter { dateFormat.format(Date(it.startTime)) == dayStr }
                        val dayFocus = focusSessions.filter { dateFormat.format(Date(it.startTime)) == dayStr }
                        
                        val totalFocusTimeMs = dayFocus.sumOf { (it.endTime ?: System.currentTimeMillis()) - it.startTime }
                        val blockedCount = dayLogs.filter { it.wasBlocked }.size
                        val totalBlockedTimeMs = dayLogs.filter { it.wasBlocked }.sumOf { it.durationMillis }
                        
                        // Estimate total usage for productivity score (or use a placeholder if not available for export window)
                        // For the summary row in CSV, let's keep it simple or fetch stats
                        val stats = usageStatsManager.queryAndAggregateUsageStats(dayStart, dayEnd)
                        val totalUsageTimeMs = stats.values.sumOf { it.totalTimeInForeground }
                        
                        val score = productivityCalculator.calculateProductivityScore(
                            blockedCount, totalBlockedTimeMs, totalUsageTimeMs, 1
                        )
                        
                        csv.append("$dayStr,00:00:00,SUMMARY,Daily Productivity Summary,N/A,${totalFocusTimeMs / 60000},Score: ${String.format(Locale.US, "%.1f", score)},Focus: ${totalFocusTimeMs / 60000}m Blocks: $blockedCount\n")
                        
                        // 2. Interleave Sessions and Logs for that day, sorted by time
                        val dayItems = mutableListOf<Pair<Long, String>>()
                        
                        dayFocus.forEach { session ->
                            val startTimeStr = timeFormat.format(Date(session.startTime))
                            val duration = if (session.endTime != null) (session.endTime - session.startTime) / 60000 else 0
                            val status = if (session.endTime != null) "Completed" else "Active/Dangling"
                            val row = "$dayStr,$startTimeStr,FOCUS_SESSION,${session.type},N/A,${session.durationMinutes}, $status,${session.relatedId ?: "N/A"}\n"
                            dayItems.add(session.startTime to row)
                        }
                        
                        dayLogs.forEach { log ->
                            val startTimeStr = timeFormat.format(Date(log.startTime))
                            val category = appsManager.getCategoryForApp(log.packageName)
                            val duration = log.durationMillis / 60000
                            val status = if (log.wasBlocked) "Blocked" else "Allowed"
                            val row = "$dayStr,$startTimeStr,APP_USAGE,\"${log.appName}\",$category,$duration,$status,${log.scheduleName ?: "N/A"}\n"
                            dayItems.add(log.startTime to row)
                        }
                        
                        dayItems.sortByDescending { it.first }
                        dayItems.forEach { csv.append(it.second) }
                    }
                    
                    csv.toString()
                }
                
                // Save to file
                val filename = "voidblock_productivity_report_${System.currentTimeMillis()}.csv"
                val file = File(context.getExternalFilesDir(null), filename)
                file.writeText(csvData)
                
                result.success(mapOf(
                    "success" to true,
                    "path" to file.absolutePath,
                    "filename" to filename,
                    "recordCount" to csvData.lines().size - 1
                ))
            } catch (e: Exception) {
                e.printStackTrace()
                result.error("EXPORT_ERROR", e.message, null)
            }
        }
    }
    
    /**
     * Get all installed apps
     */
    private fun getInstalledApps(result: MethodChannel.Result) {
        scope.launch {
            try {
                val apps = withContext(Dispatchers.IO) {
                    appsManager.getAllInstalledApps(includeSystemApps = true)
                }
                
                val appsList = apps.map { app ->
                    mapOf(
                        "packageName" to app.packageName,
                        "appName" to app.appName,
                        "isSystemApp" to app.isSystemApp,
                        "iconBase64" to app.iconBase64
                    )
                }
                
                result.success(appsList)
            } catch (e: Exception) {
                e.printStackTrace()
                result.error("FETCH_ERROR", e.message, null)
            }
        }
    }
    
    /**
     * Get only user-installed apps
     */
    private fun getUserApps(result: MethodChannel.Result) {
        scope.launch {
            try {
                val apps = withContext(Dispatchers.IO) {
                    appsManager.getUserApps()
                }
                
                val appsList = apps.map { app ->
                    mapOf(
                        "packageName" to app.packageName,
                        "appName" to app.appName,
                        "isSystemApp" to app.isSystemApp,
                        "iconBase64" to app.iconBase64
                    )
                }
                
                result.success(appsList)
            } catch (e: Exception) {
                e.printStackTrace()
                result.error("FETCH_ERROR", e.message, null)
            }
        }
    }
    
    /**
     * Search apps by query
     */
    private fun searchApps(query: String, includeSystem: Boolean, result: MethodChannel.Result) {
        scope.launch {
            try {
                val apps = withContext(Dispatchers.IO) {
                    appsManager.searchApps(query, includeSystem)
                }
                
                val appsList = apps.map { app ->
                    mapOf(
                        "packageName" to app.packageName,
                        "appName" to app.appName,
                        "isSystemApp" to app.isSystemApp,
                        "iconBase64" to app.iconBase64
                    )
                }
                
                result.success(appsList)
            } catch (e: Exception) {
                e.printStackTrace()
                result.error("SEARCH_ERROR", e.message, null)
            }
        }
    }
    
    /**
     * Get info for specific app
     */
    private fun getAppInfo(packageName: String, result: MethodChannel.Result) {
        scope.launch {
            try {
                val app = withContext(Dispatchers.IO) {
                    appsManager.getAppInfo(packageName)
                }
                
                if (app != null) {
                    result.success(
                        mapOf(
                            "packageName" to app.packageName,
                            "appName" to app.appName,
                            "isSystemApp" to app.isSystemApp,
                            "iconBase64" to app.iconBase64
                        )
                    )
                } else {
                    result.success(null)
                }
            } catch (e: Exception) {
                e.printStackTrace()
                result.error("FETCH_ERROR", e.message, null)
            }
        }
    }

    /**
     * Get hourly usage pattern for peak usage heatmap
     */
    private fun getPeakUsagePattern(days: Int, result: MethodChannel.Result) {
        scope.launch {
            try {
                val cal = Calendar.getInstance()
                cal.set(Calendar.HOUR_OF_DAY, 0)
                cal.set(Calendar.MINUTE, 0)
                cal.set(Calendar.SECOND, 0)
                cal.set(Calendar.MILLISECOND, 0)
                val dayStartTime = cal.timeInMillis
                val currentTime = System.currentTimeMillis()
                
                val pattern = withContext(Dispatchers.IO) {
                    val hourlyUsage = LongArray(24) { 0L }
                    
                    val events = usageStatsManager.queryEvents(dayStartTime, currentTime)
                    val event = UsageEvents.Event()
                    val startTimes = mutableMapOf<String, Long>()
                    
                    while (events.hasNextEvent()) {
                        events.getNextEvent(event)
                        val pkg = event.packageName ?: continue
                        
                        when (event.eventType) {
                            UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                                startTimes[pkg] = event.timeStamp
                            }
                            UsageEvents.Event.MOVE_TO_BACKGROUND,
                            UsageEvents.Event.ACTIVITY_PAUSED,
                            UsageEvents.Event.ACTIVITY_STOPPED -> {
                                val startTime = startTimes.remove(pkg)
                                if (startTime != null && startTime >= dayStartTime) {
                                    val endTime = event.timeStamp
                                    addDurationToHours(startTime, endTime, hourlyUsage, dayStartTime)
                                }
                            }
                        }
                    }
                    
                    // Handle apps currently in foreground
                    startTimes.forEach { (pkg, startTime) ->
                        if (startTime >= dayStartTime) {
                            addDurationToHours(startTime, currentTime, hourlyUsage, dayStartTime)
                        }
                    }
                    
                    hourlyUsage.map { (it / 60000).toInt() }
                }
                
                result.success(pattern)
            } catch (e: Exception) {
                e.printStackTrace()
                result.error("PATTERN_ERROR", e.message, null)
            }
        }
    }

    private fun addDurationToHours(start: Long, end: Long, hourlyUsage: LongArray, dayStart: Long) {
        var s = start
        val e = end
        
        while (s < e) {
            val hourIndex = ((s - dayStart) / 3600000).toInt()
            if (hourIndex !in 0..23) break
            
            val hourEnd = dayStart + (hourIndex + 1) * 3600000
            val fragmentEnd = minOf(e, hourEnd)
            
            hourlyUsage[hourIndex] += (fragmentEnd - s)
            s = fragmentEnd
        }
    }
}
