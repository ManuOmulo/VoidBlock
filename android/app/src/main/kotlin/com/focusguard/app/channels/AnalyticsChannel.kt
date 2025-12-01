package com.focusguard.app.channels

import android.content.Context
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
            
            else -> result.notImplemented()
        }
    }
    
    /**
     * Get usage statistics for specified period
     */
    private fun getUsageStats(days: Int, result: MethodChannel.Result) {
        scope.launch {
            try {
                val startTime = System.currentTimeMillis() - (days * 24 * 60 * 60 * 1000L)
                
                val stats = withContext(Dispatchers.IO) {
                    val blockedTime = database.usageLogDao().getTotalBlockedTime(startTime) ?: 0L
                    val blockedCount = database.usageLogDao().getBlockedAttemptsCount(startTime)
                    val uniqueApps = database.usageLogDao().getUniqueBlockedAppsCount(startTime)
                    
                    mapOf(
                        "blockedTime" to blockedTime,
                        "blockedCount" to blockedCount,
                        "uniqueBlockedApps" to uniqueApps,
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
                    productivityCalculator.calculateProductivityScore(logs, days)
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
                
                val appsList = apps.map { app ->
                    mapOf(
                        "packageName" to app.packageName,
                        "totalTime" to app.totalTime
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
                    val score = productivityCalculator.calculateProductivityScore(logs, days)
                    
                    insightsGenerator.generateInsights(dailySummary, appBreakdown, score)
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
                
                val statsList = dailyStats.map { stat ->
                    mapOf(
                        "day" to stat.daysSinceEpoch,
                        "totalTime" to stat.totalTime,
                        "sessionCount" to stat.sessionCount,
                        "blockedCount" to stat.blockedCount
                    )
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
