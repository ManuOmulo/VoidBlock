package com.voidblock.app.channels

import android.app.usage.UsageStatsManager
import android.app.usage.UsageEvents
import android.content.Context
import android.content.Intent
import com.voidblock.app.data.database.AppDatabase
import com.voidblock.app.data.database.entities.AppLimitAppEntity
import com.voidblock.app.data.database.entities.AppLimitEntity
import com.voidblock.app.services.BlockingService
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.*

class AppLimitChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    private val database = AppDatabase.getInstance(context)
    private val scope = CoroutineScope(Dispatchers.Main)
    private val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

    companion object {
        const val CHANNEL_NAME = "com.voidblock.app/app_limit"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "createLimit" -> {
                val name = call.argument<String>("name") ?: ""
                val limitMinutes = call.argument<Int>("limitMinutes") ?: 0
                val apps = call.argument<List<Map<String, String>>>("apps") ?: emptyList()
                val isStrictMode = call.argument<Boolean>("isStrictMode") ?: false
                val strictModeLevel = call.argument<String>("strictModeLevel") ?: "NONE"
                val strictModePin = call.argument<String>("strictModePin")
                val strictModeCooldownMinutes = call.argument<Int>("strictModeCooldownMinutes")
                val hardModeDurationMinutes = call.argument<Int>("hardModeDurationMinutes")
                
                createLimit(name, limitMinutes, apps, isStrictMode, strictModeLevel, strictModePin, strictModeCooldownMinutes, hardModeDurationMinutes, result)
            }
            "getAllLimits" -> getAllLimits(result)
            "getLimitById" -> {
                val id = (call.argument<Any>("id") as? Number)?.toLong() ?: 0L
                getLimitById(id, result)
            }
            "updateLimit" -> {
                val id = (call.argument<Any>("id") as? Number)?.toLong() ?: 0L
                val name = call.argument<String>("name") ?: ""
                val limitMinutes = call.argument<Int>("limitMinutes") ?: 0
                val apps = call.argument<List<Map<String, String>>>("apps") ?: emptyList()
                val isActive = call.argument<Boolean>("isActive") ?: true
                val isStrictMode = call.argument<Boolean>("isStrictMode") ?: false
                val strictModeLevel = call.argument<String>("strictModeLevel") ?: "NONE"
                val strictModePin = call.argument<String>("strictModePin")
                val strictModeCooldownMinutes = call.argument<Int>("strictModeCooldownMinutes")
                val hardModeDurationMinutes = call.argument<Int>("hardModeDurationMinutes")
                
                updateLimit(id, name, limitMinutes, apps, isActive, isStrictMode, strictModeLevel, strictModePin, strictModeCooldownMinutes, hardModeDurationMinutes, result)
            }
            "deleteLimit" -> {
                val id = (call.argument<Any>("id") as? Number)?.toLong() ?: 0L
                deleteLimit(id, result)
            }
            "toggleLimit" -> {
                val id = (call.argument<Any>("id") as? Number)?.toLong() ?: 0L
                val isActive = call.argument<Boolean>("isActive") ?: true
                toggleLimit(id, isActive, result)
            }
            "unlockLimit" -> {
                val id = (call.argument<Any>("id") as? Number)?.toLong() ?: 0L
                unlockLimit(id, result)
            }
            "requestUnlock" -> {
                val id = (call.argument<Any>("id") as? Number)?.toLong() ?: 0L
                requestUnlock(id, result)
            }
            "getDailyUsage" -> {
                val packageNames = call.argument<List<String>>("packageNames") ?: emptyList()
                getDailyUsage(packageNames, result)
            }
            else -> result.notImplemented()
        }
    }

    private fun createLimit(
        name: String,
        limitMinutes: Int,
        apps: List<Map<String, String>>,
        isStrictMode: Boolean,
        strictModeLevel: String,
        strictModePin: String?,
        strictModeCooldownMinutes: Int?,
        hardModeDurationMinutes: Int?,
        result: MethodChannel.Result
    ) {
        scope.launch {
            try {
                val hardModeEndsAt = if (strictModeLevel == "HARD" && hardModeDurationMinutes != null) {
                    System.currentTimeMillis() + (hardModeDurationMinutes.toLong() * 60 * 1000)
                } else null

                val limit = AppLimitEntity(
                    name = name,
                    limitMinutes = limitMinutes,
                    isStrictMode = isStrictMode,
                    strictModeLevel = strictModeLevel,
                    strictModePin = strictModePin,
                    strictModeCooldownMinutes = strictModeCooldownMinutes,
                    hardModeDurationMinutes = hardModeDurationMinutes,
                    hardModeEndsAt = hardModeEndsAt
                )

                val limitId = withContext(Dispatchers.IO) {
                    val id = database.appLimitDao().insertLimit(limit)
                    val appEntities = apps.map { 
                        AppLimitAppEntity(
                            limitId = id,
                            packageName = it["packageName"] ?: "",
                            appName = it["appName"] ?: ""
                        )
                    }
                    database.appLimitDao().insertLimitApps(appEntities)
                    id
                }

                // Notify service to refresh
                notifyService()
                
                result.success(limitId)
            } catch (e: Exception) {
                result.error("CREATE_LIMIT_ERROR", e.message, null)
            }
        }
    }

    private fun getAllLimits(result: MethodChannel.Result) {
        scope.launch {
            try {
                val limits = withContext(Dispatchers.IO) {
                    database.appLimitDao().getAllLimits()
                }
                
                val now = System.currentTimeMillis()
                val expiredLimitIds = mutableListOf<Long>()
                
                // Check for expired HARD mode limits
                for (limit in limits) {
                    if (limit.isStrictMode && limit.strictModeLevel == "HARD" && limit.hardModeEndsAt != null) {
                        if (now >= limit.hardModeEndsAt) {
                            expiredLimitIds.add(limit.id)
                        }
                    }
                }
                
                // Delete expired limits from database
                if (expiredLimitIds.isNotEmpty()) {
                    withContext(Dispatchers.IO) {
                        for (limitId in expiredLimitIds) {
                            val limit = database.appLimitDao().getLimitById(limitId)
                            if (limit != null) {
                                database.appLimitDao().deleteLimit(limit)
                            }
                        }
                    }
                }
                
                // Filter out expired limits and build response
                val limitsList = limits.filter { limit ->
                    !expiredLimitIds.contains(limit.id)
                }.map { limit ->
                    val apps = withContext(Dispatchers.IO) {
                        database.appLimitDao().getAppsForLimit(limit.id)
                    }
                    mapOf(
                        "id" to limit.id,
                        "name" to limit.name,
                        "limitMinutes" to limit.limitMinutes,
                        "isActive" to limit.isActive,
                        "isStrictMode" to limit.isStrictMode,
                        "strictModeLevel" to limit.strictModeLevel,
                        "strictModePin" to limit.strictModePin,
                        "strictModeCooldownMinutes" to limit.strictModeCooldownMinutes,
                        "hardModeDurationMinutes" to limit.hardModeDurationMinutes,
                        "hardModeEndsAt" to limit.hardModeEndsAt,
                        "lastUnlockedAt" to limit.lastUnlockedAt,
                        "unlockedUntilMidnight" to limit.unlockedUntilMidnight,
                        "apps" to apps.map { mapOf("packageName" to it.packageName, "appName" to it.appName) }
                    )
                }
                result.success(limitsList)
            } catch (e: Exception) {
                result.error("GET_LIMITS_ERROR", e.message, null)
            }
        }
    }

    private fun getLimitById(id: Long, result: MethodChannel.Result) {
        scope.launch {
            try {
                val limit = withContext(Dispatchers.IO) {
                    database.appLimitDao().getLimitById(id)
                }
                if (limit != null) {
                    val apps = withContext(Dispatchers.IO) {
                        database.appLimitDao().getAppsForLimit(limit.id)
                    }
                    val resultMap = mapOf(
                        "id" to limit.id,
                        "name" to limit.name,
                        "limitMinutes" to limit.limitMinutes,
                        "isActive" to limit.isActive,
                        "isStrictMode" to limit.isStrictMode,
                        "strictModeLevel" to limit.strictModeLevel,
                        "strictModePin" to limit.strictModePin,
                        "strictModeCooldownMinutes" to limit.strictModeCooldownMinutes,
                        "hardModeDurationMinutes" to limit.hardModeDurationMinutes,
                        "hardModeEndsAt" to limit.hardModeEndsAt,
                        "lastUnlockedAt" to limit.lastUnlockedAt,
                        "unlockedUntilMidnight" to limit.unlockedUntilMidnight,
                        "apps" to apps.map { mapOf("packageName" to it.packageName, "appName" to it.appName) }
                    )
                    result.success(resultMap)
                } else {
                    result.success(null)
                }
            } catch (e: Exception) {
                result.error("GET_LIMIT_ERROR", e.message, null)
            }
        }
    }

    private fun updateLimit(
        id: Long,
        name: String,
        limitMinutes: Int,
        apps: List<Map<String, String>>,
        isActive: Boolean,
        isStrictMode: Boolean,
        strictModeLevel: String,
        strictModePin: String?,
        strictModeCooldownMinutes: Int?,
        hardModeDurationMinutes: Int?,
        result: MethodChannel.Result
    ) {
        scope.launch {
            try {
                withContext(Dispatchers.IO) {
                    val existing = database.appLimitDao().getLimitById(id) ?: return@withContext
                    
                    // Calculate hardModeEndsAt if switching to HARD mode
                    val hardModeEndsAt = if (strictModeLevel == "HARD" && hardModeDurationMinutes != null) {
                        System.currentTimeMillis() + (hardModeDurationMinutes.toLong() * 60 * 1000)
                    } else if (strictModeLevel != "HARD") {
                        // Clear hard mode end time if switching away from HARD
                        null
                    } else {
                        existing.hardModeEndsAt
                    }
                    
                    val updated = existing.copy(
                        name = name,
                        limitMinutes = limitMinutes,
                        isActive = isActive,
                        isStrictMode = isStrictMode,
                        strictModeLevel = strictModeLevel,
                        strictModePin = strictModePin,
                        strictModeCooldownMinutes = strictModeCooldownMinutes,
                        hardModeDurationMinutes = hardModeDurationMinutes,
                        hardModeEndsAt = hardModeEndsAt
                    )
                    database.appLimitDao().updateLimit(updated)
                    
                    // Update apps
                    database.appLimitDao().deleteAppsForLimit(id)
                    val appEntities = apps.map { 
                        AppLimitAppEntity(
                            limitId = id,
                            packageName = it["packageName"] ?: "",
                            appName = it["appName"] ?: ""
                        )
                    }
                    database.appLimitDao().insertLimitApps(appEntities)
                }
                notifyService()
                result.success(true)
            } catch (e: Exception) {
                result.error("UPDATE_LIMIT_ERROR", e.message, null)
            }
        }
    }

    private fun deleteLimit(id: Long, result: MethodChannel.Result) {
        scope.launch {
            try {
                val limit = withContext(Dispatchers.IO) {
                    database.appLimitDao().getLimitById(id)
                }
                if (limit != null) {
                    // Check strict mode - Hard mode check
                    if (limit.isStrictMode && limit.strictModeLevel == "HARD") {
                        val now = System.currentTimeMillis()
                        if (limit.hardModeEndsAt != null && now < limit.hardModeEndsAt) {
                            result.error("STRICT_MODE_LOCKED", "Hard mode limit is still active and cannot be deleted.", null)
                            return@launch
                        }
                    }
                    
                    withContext(Dispatchers.IO) {
                        database.appLimitDao().deleteLimit(limit)
                    }
                    notifyService()
                    result.success(true)
                } else {
                    result.error("NOT_FOUND", "Limit not found", null)
                }
            } catch (e: Exception) {
                result.error("DELETE_LIMIT_ERROR", e.message, null)
            }
        }
    }

    private fun toggleLimit(id: Long, isActive: Boolean, result: MethodChannel.Result) {
        scope.launch {
            try {
                withContext(Dispatchers.IO) {
                    database.appLimitDao().toggleLimit(id, isActive)
                }
                notifyService()
                result.success(true)
            } catch (e: Exception) {
                result.error("TOGGLE_LIMIT_ERROR", e.message, null)
            }
        }
    }

    private fun unlockLimit(id: Long, result: MethodChannel.Result) {
        scope.launch {
            try {
                withContext(Dispatchers.IO) {
                    database.appLimitDao().setUnlockedStatus(id, true)
                    database.appLimitDao().updateLastUnlockedAt(id, System.currentTimeMillis())
                }
                notifyService()
                result.success(true)
            } catch (e: Exception) {
                result.error("UNLOCK_LIMIT_ERROR", e.message, null)
            }
        }
    }

    private fun requestUnlock(id: Long, result: MethodChannel.Result) {
        scope.launch {
            try {
                withContext(Dispatchers.IO) {
                    database.appLimitDao().updateLastUnlockedAt(id, System.currentTimeMillis())
                }
                result.success(true)
            } catch (e: Exception) {
                result.error("REQUEST_UNLOCK_ERROR", e.message, null)
            }
        }
    }

    private fun getDailyUsage(packageNames: List<String>, result: MethodChannel.Result) {
        scope.launch {
            try {
                val usageMap = mutableMapOf<String, Long>()
                val startOfDay = getStartOfDay()
                val currentTime = System.currentTimeMillis()
                
                // Use the new accurate aggregator
                val usageMapDetails = getAccurateUsageToday(packageNames.toSet())
                
                packageNames.forEach { pkg ->
                    val usage = usageMapDetails[pkg] ?: 0L
                    usageMap[pkg] = (usage / (60 * 1000)).toInt().toLong() // Convert to minutes for UI
                }
                
                result.success(usageMap)
            } catch (e: Exception) {
                result.error("USAGE_STATS_ERROR", e.message, null)
            }
        }
    }

    private fun getAccurateUsageToday(targetPackages: Set<String>): Map<String, Long> {
        val startOfDay = getStartOfDay()
        val currentTime = System.currentTimeMillis()
        val events = usageStatsManager.queryEvents(startOfDay, currentTime)
        val event = UsageEvents.Event()
        
        val usageMap = mutableMapOf<String, Long>()
        val startMap = mutableMapOf<String, Long>()
        
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (!targetPackages.contains(event.packageName)) continue
            
            when (event.eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                    startMap[event.packageName] = event.timeStamp
                }
                UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    val start = startMap[event.packageName]
                    if (start != null) {
                        val duration = event.timeStamp - start
                        usageMap[event.packageName] = (usageMap[event.packageName] ?: 0L) + duration
                        startMap.remove(event.packageName)
                    }
                }
            }
        }
        
        // Add currently active sessions
        startMap.forEach { (pkg, start) ->
            val duration = currentTime - start
            usageMap[pkg] = (usageMap[pkg] ?: 0L) + duration
        }
        
        return usageMap
    }

    private fun getStartOfDay(): Long {
        val calendar = Calendar.getInstance()
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        return calendar.timeInMillis
    }

    private fun notifyService() {
        val intent = Intent(context, BlockingService::class.java).apply {
            action = BlockingService.ACTION_UPDATE_BLOCKED_APPS
        }
        context.startService(intent)
    }
}
