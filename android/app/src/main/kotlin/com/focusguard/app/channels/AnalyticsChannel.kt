package com.focusguard.app.channels

import android.content.Context
import java.text.SimpleDateFormat
import java.util.*
import com.focusguard.app.data.database.AppDatabase
import com.focusguard.app.utils.InstalledAppsManager
import com.focusguard.app.utils.ProductivityCalculator
import com.focusguard.app.utils.InsightsGenerator
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import android.app.usage.UsageStatsManager
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
        const val CHANNEL_NAME = "com.focusguard.app/analytics"
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
                    
                    val score = productivityCalculator.calculateProductivityScore(blockedCount, totalBlockedTime, totalUsageTime, days)
                    
                    insightsGenerator.generateInsights(dailySummary, appBreakdown, logs, score)
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
                val startTime = System.currentTimeMillis() - (days * 24 * 60 * 60 * 1000L)
                
                val dailyStats = withContext(Dispatchers.IO) {
                    database.usageLogDao().getDailyUsageSummary(startTime)
                }
                
                val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
                val statsList = mutableListOf<Map<String, Any>>()
                
                // Aggregate usage per day using UsageStatsManager
                for (i in 0 until days) {
                    val cal = Calendar.getInstance()
                    cal.add(Calendar.DAY_OF_YEAR, -i)
                    cal.set(Calendar.HOUR_OF_DAY, 0)
                    cal.set(Calendar.MINUTE, 0)
                    cal.set(Calendar.SECOND, 0)
                    cal.set(Calendar.MILLISECOND, 0)
                    val dayStart = cal.timeInMillis
                    
                    cal.set(Calendar.HOUR_OF_DAY, 23)
                    cal.set(Calendar.MINUTE, 59)
                    cal.set(Calendar.SECOND, 59)
                    val dayEnd = cal.timeInMillis
                    
                    // Calculate Estimated Time Saved for this day
                    val dayData = withContext(Dispatchers.IO) {
                        val blockedCountDay = database.usageLogDao().getBlockedAttemptsCountForPeriod(dayStart, dayEnd)
                        
                        // Use the same personalized average session length logic or a conservative 5-min default
                        // To keep it simple and consistent for charts, we use a 5-minute estimate per block here
                        // but cap the total saved time to 16 hours so it doesn't exceed a waking day.
                        val minutesSaved = (blockedCountDay * 5L).coerceAtMost(16 * 60L)
                        Pair(minutesSaved, blockedCountDay)
                    }
                    
                    statsList.add(mapOf(
                        "date" to dateFormat.format(Date(dayStart)),
                        "totalTime" to dayData.first.toInt(), // This is now "Minutes Saved"
                        "blockedCount" to dayData.second
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
                val data = withContext(Dispatchers.IO) {
                    val logs = database.usageLogDao().getLogsForPeriod(startTime, endTime)
                    
                    // Convert to CSV format
                    val csv = StringBuilder()
                    csv.append("Date,Time,App Name,Package Name,Duration (min),Was Blocked,Schedule\n")
                    
                    logs.forEach { log ->
                        val date = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.getDefault())
                            .format(java.util.Date(log.startTime))
                        val time = java.text.SimpleDateFormat("HH:mm:ss", java.util.Locale.getDefault())
                            .format(java.util.Date(log.startTime))
                        val duration = log.durationMillis / (1000 * 60)
                        
                        csv.append("$date,$time,\"${log.appName}\",${log.packageName},$duration,${log.wasBlocked},${log.scheduleName ?: ""}\n")
                    }
                    
                    csv.toString()
                }
                
                // Save to file
                val filename = "focusguard_export_${System.currentTimeMillis()}.csv"
                val file = File(context.getExternalFilesDir(null), filename)
                file.writeText(data)
                
                result.success(mapOf(
                    "success" to true,
                    "path" to file.absolutePath,
                    "filename" to filename,
                    "recordCount" to data.lines().size - 1
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
}
