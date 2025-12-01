package com.focusguard.app.channels

import android.content.Context
import com.focusguard.app.data.database.AppDatabase
import com.focusguard.app.data.database.entities.ScheduleEntity
import com.focusguard.app.data.database.entities.BlockedAppEntity
import com.focusguard.app.utils.ScheduleManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray

/**
 * Platform channel for schedule operations between Flutter and native Android
 */
class ScheduleChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    
    private val database = AppDatabase.getInstance(context)
    private val scheduleManager = ScheduleManager(context)
    private val scope = CoroutineScope(Dispatchers.Main)
    
    companion object {
        const val CHANNEL_NAME = "com.focusguard.app/schedule"
    }
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "createSchedule" -> {
                val scheduleData = call.arguments as? Map<String, Any>
                createSchedule(scheduleData, result)
            }
            
            "getAllSchedules" -> {
                getAllSchedules(result)
            }
            
            "getScheduleById" -> {
                val scheduleId = (call.argument<Int>("id") ?: 0).toLong()
                getScheduleById(scheduleId, result)
            }
            
            "updateSchedule" -> {
                val scheduleData = call.arguments as? Map<String, Any>
                updateSchedule(scheduleData, result)
            }
            
            "deleteSchedule" -> {
                val scheduleId = (call.argument<Int>("id") ?: 0).toLong()
                deleteSchedule(scheduleId, result)
            }
            
            "toggleSchedule" -> {
                val scheduleId = (call.argument<Int>("id") ?: 0).toLong()
                val isActive = call.argument<Boolean>("isActive") ?: false
                toggleSchedule(scheduleId, isActive, result)
            }
            
            "pauseSchedule" -> {
                val scheduleId = (call.argument<Int>("id") ?: 0).toLong()
                pauseSchedule(scheduleId, result)
            }
            
            "resumeSchedule" -> {
                val scheduleId = (call.argument<Int>("id") ?: 0).toLong()
                resumeSchedule(scheduleId, result)
            }
            
            else -> result.notImplemented()
        }
    }
    
    private fun createSchedule(data: Map<String, Any>?, result: MethodChannel.Result) {
        if (data == null) {
            result.error("INVALID_DATA", "Schedule data is null", null)
            return
        }
        
        scope.launch {
            try {
                val schedule = mapToScheduleEntity(data)
                val id = withContext(Dispatchers.IO) {
                    database.scheduleDao().insertSchedule(schedule)
                }
                
                // Insert blocked apps
                val blockedApps = (data["blockedApps"] as? List<*>)?.map { it.toString() } ?: emptyList()
                blockedApps.forEach { packageName ->
                    val blockedApp = BlockedAppEntity(
                        scheduleId = id,
                        packageName = packageName,
                        appName = packageName
                    )
                    withContext(Dispatchers.IO) {
                        database.blockedAppDao().insertBlockedApp(blockedApp)
                    }
                }
                
                // Schedule alarms if active
                if (schedule.isActive) {
                    val newSchedule = schedule.copy(id = id)
                    scheduleManager.scheduleAlarms(newSchedule)
                }
                
                result.success(true)
            } catch (e: Exception) {
                result.error("CREATE_ERROR", e.message, null)
            }
        }
    }
    
    private fun getAllSchedules(result: MethodChannel.Result) {
        scope.launch {
            try {
                val schedules = withContext(Dispatchers.IO) {
                    database.scheduleDao().getAllSchedulesSync()
                }
                
                val schedulesList = schedules.map { schedule ->
                    scheduleEntityToMap(schedule)
                }
                
                result.success(schedulesList)
            } catch (e: Exception) {
                result.error("FETCH_ERROR", e.message, null)
            }
        }
    }
    
    private fun getScheduleById(id: Long, result: MethodChannel.Result) {
        scope.launch {
            try {
                val schedule = withContext(Dispatchers.IO) {
                    database.scheduleDao().getScheduleById(id)
                }
                
                if (schedule != null) {
                    result.success(scheduleEntityToMap(schedule))
                } else {
                    result.success(null)
                }
            } catch (e: Exception) {
                result.error("FETCH_ERROR", e.message, null)
            }
        }
    }

    private fun updateSchedule(data: Map<String, Any>?, result: MethodChannel.Result) {
        if (data == null) {
            result.error("INVALID_DATA", "Schedule data is null", null)
            return
        }
        
        scope.launch {
            try {
                val schedule = mapToScheduleEntity(data)
                
                // Cancel old alarms
                scheduleManager.cancelAlarms(schedule)
                
                // If schedule was active and is now inactive (or changed), stop blocking
                // We do this by sending stop intent for this schedule
                val stopIntent = android.content.Intent(context, com.focusguard.app.services.BlockingService::class.java).apply {
                    action = com.focusguard.app.services.BlockingService.ACTION_STOP_SCHEDULE
                    val blockedApps = database.blockedAppDao().getBlockedAppsForScheduleSync(schedule.id)
                        .map { it.packageName }
                    putStringArrayListExtra(com.focusguard.app.services.BlockingService.EXTRA_APP_PACKAGES, ArrayList(blockedApps))
                }
                context.startService(stopIntent)
                
                // Update schedule
                database.scheduleDao().updateSchedule(schedule)
                
                // Update blocked apps
                val blockedApps = (data["blockedApps"] as? List<*>)?.map { it.toString() } ?: emptyList()
                database.blockedAppDao().deleteAllBlockedAppsForSchedule(schedule.id)
                
                blockedApps.forEach { packageName ->
                    val blockedApp = BlockedAppEntity(
                        scheduleId = schedule.id,
                        packageName = packageName,
                        appName = packageName
                    )
                    database.blockedAppDao().insertBlockedApp(blockedApp)
                }
                
                // Re-schedule alarms if active
                if (schedule.isActive) {
                    scheduleManager.scheduleAlarms(schedule)
                }
                
                result.success(true)
            } catch (e: Exception) {
                result.error("UPDATE_ERROR", e.message, null)
            }
        }
    }
    
    
    private fun deleteSchedule(id: Long, result: MethodChannel.Result) {
        scope.launch {
            try {
                val schedule = withContext(Dispatchers.IO) {
                    database.scheduleDao().getScheduleById(id)
                }
                
                if (schedule != null) {
                    // HARD MODE PROTECTION: Cannot delete Hard mode schedule while blocking is active
                    if (schedule.strictModeLevel == "HARD") {
                        // Check if this schedule is currently running a blocking session
                        val activeSession = withContext(Dispatchers.IO) {
                            database.blockingSessionDao().getActiveSession()
                        }
                        
                        if (activeSession != null && activeSession.isActive) {
                            // Check if the active session is from this schedule
                            // We can check by looking at the session's start time and the schedule's time window
                            val now = java.util.Calendar.getInstance()
                            val currentHour = now.get(java.util.Calendar.HOUR_OF_DAY)
                            val currentMinute = now.get(java.util.Calendar.MINUTE)
                            val currentDayOfWeek = now.get(java.util.Calendar.DAY_OF_WEEK) - 1 // 0-6 (Sun-Sat)
                            
                            // Parse schedule times
                            val startParts = schedule.startTime.split(":")
                            val endParts = schedule.endTime.split(":")
                            val scheduleStartHour = startParts[0].toInt()
                            val scheduleStartMinute = startParts[1].toInt()
                            val scheduleEndHour = endParts[0].toInt()
                            val scheduleEndMinute = endParts[1].toInt()
                            
                            val currentTimeInMinutes = currentHour * 60 + currentMinute
                            val scheduleStartInMinutes = scheduleStartHour * 60 + scheduleStartMinute
                            val scheduleEndInMinutes = scheduleEndHour * 60 + scheduleEndMinute
                            
                            // Check if current time is within schedule window and day matches
                            val isInTimeWindow = if (scheduleEndInMinutes < scheduleStartInMinutes) {
                                // Schedule spans midnight
                                currentTimeInMinutes >= scheduleStartInMinutes || currentTimeInMinutes <= scheduleEndInMinutes
                            } else {
                                currentTimeInMinutes >= scheduleStartInMinutes && currentTimeInMinutes <= scheduleEndInMinutes
                            }
                            
                            val isDayMatch = schedule.daysOfWeek.split(",")
                                .mapNotNull { it.toIntOrNull() }
                                .contains(currentDayOfWeek)
                            
                            if (isInTimeWindow && isDayMatch && schedule.isActive) {
                                result.error(
                                    "HARD_MODE_ACTIVE",
                                    "Cannot delete Hard mode schedule while blocking is active. Wait for the session to end or change to a different strict mode level.",
                                    null
                                )
                                return@launch
                            }
                        }
                    }
                    
                    // Cancel alarms
                    scheduleManager.cancelAlarms(schedule)
                    
                    // Stop blocking if it was running
                    if (schedule.isActive) {
                        val stopIntent = android.content.Intent(context, com.focusguard.app.services.BlockingService::class.java).apply {
                            action = com.focusguard.app.services.BlockingService.ACTION_STOP_SCHEDULE
                            val blockedApps = database.blockedAppDao().getBlockedAppsForScheduleSync(schedule.id)
                                .map { it.packageName }
                            putStringArrayListExtra(com.focusguard.app.services.BlockingService.EXTRA_APP_PACKAGES, ArrayList(blockedApps))
                        }
                        context.startService(stopIntent)
                    }
                    
                    // Delete blocked apps
                    withContext(Dispatchers.IO) {
                        database.blockedAppDao().deleteAllBlockedAppsForSchedule(id)
                    }
                    
                    // Delete schedule
                    withContext(Dispatchers.IO) {
                        database.scheduleDao().deleteScheduleById(id)
                    }
                    
                    result.success(true)
                } else {
                    result.success(false)
                }
            } catch (e: Exception) {
                result.error("DELETE_ERROR", e.message, null)
            }
        }
    }
    
    private fun toggleSchedule(id: Long, isActive: Boolean, result: MethodChannel.Result) {
        scope.launch {
            try {
                val schedule = withContext(Dispatchers.IO) {
                    database.scheduleDao().getScheduleById(id)
                }
                
                if (schedule != null) {
                    if (isActive) {
                        // Reset isPaused when activating
                        val updatedSchedule = schedule.copy(isPaused = false)
                        database.scheduleDao().updateSchedule(updatedSchedule)
                        
                        // Schedule alarms
                        scheduleManager.scheduleAlarms(updatedSchedule)
                    } else {
                        // Cancel alarms
                        scheduleManager.cancelAlarms(schedule)
                        
                        // Stop blocking if it was running
                        val stopIntent = android.content.Intent(context, com.focusguard.app.services.BlockingService::class.java).apply {
                            action = com.focusguard.app.services.BlockingService.ACTION_STOP_SCHEDULE
                            val blockedApps = database.blockedAppDao().getBlockedAppsForScheduleSync(schedule.id)
                                .map { it.packageName }
                            putStringArrayListExtra(com.focusguard.app.services.BlockingService.EXTRA_APP_PACKAGES, ArrayList(blockedApps))
                        }
                        context.startService(stopIntent)
                    }
                    
                    // Update status
                    database.scheduleDao().setScheduleActive(id, isActive)
                }
                
                result.success(true)
            } catch (e: Exception) {
                result.error("TOGGLE_ERROR", e.message, null)
            }
        }
    }
    
    private fun pauseSchedule(id: Long, result: MethodChannel.Result) {
        scope.launch {
            try {
                val schedule = withContext(Dispatchers.IO) {
                    database.scheduleDao().getScheduleById(id)
                }
                
                if (schedule != null && schedule.isActive) {
                    // Update isPaused = true
                    // We need a DAO method for this, or update the whole entity
                    val updatedSchedule = schedule.copy(isPaused = true)
                    withContext(Dispatchers.IO) {
                        database.scheduleDao().updateSchedule(updatedSchedule)
                    }
                    
                    // Stop blocking service
                    val stopIntent = android.content.Intent(context, com.focusguard.app.services.BlockingService::class.java).apply {
                        action = com.focusguard.app.services.BlockingService.ACTION_STOP_SCHEDULE
                        val blockedApps = database.blockedAppDao().getBlockedAppsForScheduleSync(schedule.id)
                            .map { it.packageName }
                        putStringArrayListExtra(com.focusguard.app.services.BlockingService.EXTRA_APP_PACKAGES, ArrayList(blockedApps))
                    }
                    context.startService(stopIntent)
                    
                    result.success(true)
                } else {
                    result.success(false)
                }
            } catch (e: Exception) {
                result.error("PAUSE_ERROR", e.message, null)
            }
        }
    }
    
    private fun resumeSchedule(id: Long, result: MethodChannel.Result) {
        scope.launch {
            try {
                val schedule = withContext(Dispatchers.IO) {
                    database.scheduleDao().getScheduleById(id)
                }
                
                if (schedule != null && schedule.isActive) {
                    // Update isPaused = false
                    val updatedSchedule = schedule.copy(isPaused = false)
                    withContext(Dispatchers.IO) {
                        database.scheduleDao().updateSchedule(updatedSchedule)
                    }
                    
                    // Check if we should start blocking (is within time window?)
                    scheduleManager.scheduleAlarms(updatedSchedule)
                    
                    result.success(true)
                } else {
                    result.success(false)
                }
            } catch (e: Exception) {
                result.error("RESUME_ERROR", e.message, null)
            }
        }
    }
    
    private fun getActiveSchedules(result: MethodChannel.Result) {
        scope.launch {
            try {
                val schedules = withContext(Dispatchers.IO) {
                    database.scheduleDao().getActiveSchedulesSync()
                }
                
                val schedulesList = schedules.map { schedule ->
                    scheduleEntityToMap(schedule)
                }
                
                result.success(schedulesList)
            } catch (e: Exception) {
                result.error("FETCH_ERROR", e.message, null)
            }
        }
    }
    
    private fun mapToScheduleEntity(data: Map<String, Any>): ScheduleEntity {
        return ScheduleEntity(
            id = (data["id"] as? Int ?: 0).toLong(),
            name = data["name"] as? String ?: "",
            startTime = data["startTime"] as? String ?: "00:00",
            endTime = data["endTime"] as? String ?: "23:59",
            daysOfWeek = JSONArray(data["daysOfWeek"] as? List<Int> ?: emptyList<Int>()).toString(),
            isActive = data["isActive"] as? Boolean ?: true,
            isPaused = data["isPaused"] as? Boolean ?: false,
            isStrictMode = data["isStrictMode"] as? Boolean ?: false,
            motivationalMessage = data["motivationalMessage"] as? String,
            notificationsEnabled = data["notificationsEnabled"] as? Boolean ?: true,
            createdAt = (data["createdAt"] as? Long) ?: System.currentTimeMillis()
        )
    }
    
    private suspend fun scheduleEntityToMap(schedule: ScheduleEntity): Map<String, Any?> {
        val blockedApps = withContext(Dispatchers.IO) {
            database.blockedAppDao().getBlockedAppsForScheduleSync(schedule.id)
                .map { it.packageName }
        }
        
        return mapOf(
            "id" to schedule.id.toInt(),
            "name" to schedule.name,
            "startTime" to schedule.startTime,
            "endTime" to schedule.endTime,
            "daysOfWeek" to JSONArray(schedule.daysOfWeek).let { jsonArray ->
                (0 until jsonArray.length()).map { jsonArray.getInt(it) }
            },
            "isActive" to schedule.isActive,
            "isPaused" to schedule.isPaused,
            "isStrictMode" to schedule.isStrictMode,
            "motivationalMessage" to schedule.motivationalMessage,
            "notificationsEnabled" to schedule.notificationsEnabled,
            "blockedApps" to blockedApps
        )
    }
}
