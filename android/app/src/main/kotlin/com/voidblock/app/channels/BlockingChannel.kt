package com.voidblock.app.channels

import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.content.ContextCompat
import com.voidblock.app.data.database.AppDatabase
import com.voidblock.app.data.database.entities.BlockingSessionEntity
import com.voidblock.app.data.database.entities.SessionBlockedAppEntity
import com.voidblock.app.services.BlockingService
import com.voidblock.app.utils.SessionTimerManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Platform channel for blocking operations between Flutter and native Android
 * Manages blocking sessions with database persistence and timer management
 */
class BlockingChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    private val database = AppDatabase.getInstance(context)
    private val timerManager = SessionTimerManager(context)
    private val scope = CoroutineScope(Dispatchers.Main)

    companion object {
        const val CHANNEL_NAME = "com.voidblock.app/blocking"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startBlocking" -> {
                val apps = call.argument<List<String>>("apps") ?: emptyList()
                val durationMinutes = call.argument<Int>("durationMinutes") ?: 0
                val isStrictMode = call.argument<Boolean>("strictMode") ?: false
                val strictModeLevel = call.argument<String>("strictModeLevel") ?: "NONE"
                val strictModePin = call.argument<String>("strictModePin")
                val strictModeCooldownMinutes = call.argument<Int>("strictModeCooldownMinutes")
                val message = call.argument<String>("message")

                startBlocking(
                    apps,
                    durationMinutes,
                    isStrictMode,
                    strictModeLevel,
                    strictModePin,
                    strictModeCooldownMinutes,
                    message,
                    result
                )
            }

            "stopBlocking" -> {
                stopBlocking(result)
            }

            "getActiveSession" -> {
                getActiveSession(result)
            }

            "isAppBlocked" -> {
                val packageName = call.argument<String>("packageName")
                isAppBlocked(packageName, result)
            }

            "pauseBlocking" -> {
                pauseBlocking(result)
            }

            "resumeBlocking" -> {
                resumeBlocking(result)
            }

            "getAllBlockedApps" -> {
                getAllBlockedApps(result)
            }

            else -> result.notImplemented()
        }
    }

    /**
     * Start blocking service with specified apps and create session in database
     */
    private fun startBlocking(
        apps: List<String>,
        durationMinutes: Int,
        isStrictMode: Boolean,
        strictModeLevel: String,
        strictModePin: String?,
        strictModeCooldownMinutes: Int?,
        message: String?,
        result: MethodChannel.Result
    ) {
        scope.launch {
            try {
                // 1. Check if there's already an active session
                val existingSession = withContext(Dispatchers.IO) {
                    database.blockingSessionDao().getActiveSession()
                }

                if (existingSession != null) {
                    // Check if the session has expired
                    val isExpired = if (existingSession.durationMinutes > 0) {
                        val elapsedMinutes = (System.currentTimeMillis() - existingSession.startTime) / (60 * 1000)
                        elapsedMinutes >= existingSession.durationMinutes
                    } else {
                        false // No duration means indefinite
                    }

                    if (isExpired) {
                        // Auto-cleanup expired session
                        withContext(Dispatchers.IO) {
                            database.blockingSessionDao().endSession(
                                existingSession.id,
                                System.currentTimeMillis()
                            )
                        }

                        // Stop the blocking service if still running
                        val stopIntent = Intent(context, BlockingService::class.java).apply {
                            action = BlockingService.ACTION_STOP_BLOCKING
                        }
                        context.startService(stopIntent)

                        // Cancel timer if exists
                        timerManager.cancelAutoStop(existingSession.id)
                    } else {
                        // Session is still active and not expired
                        result.error("ACTIVE_SESSION", "A blocking session is already active", null)
                        return@launch
                    }
                }

                // 2. Create new session in database
                val session = BlockingSessionEntity(
                    startTime = System.currentTimeMillis(),
                    endTime = null,
                    durationMinutes = durationMinutes,
                    isActive = true,
                    isPaused = false,
                    isStrictMode = isStrictMode,
                    motivationalMessage = message,
                    strictModeLevel = strictModeLevel,
                    strictModePin = strictModePin,
                    strictModeCooldownMinutes = strictModeCooldownMinutes
                )

                val sessionId = withContext(Dispatchers.IO) {
                    database.blockingSessionDao().insertSession(session)
                }

                // 3. Insert blocked apps for this session
                withContext(Dispatchers.IO) {
                    apps.forEach { packageName ->
                        val appName = getAppName(packageName)
                        database.sessionBlockedAppDao().insert(
                            SessionBlockedAppEntity(
                                sessionId = sessionId,
                                packageName = packageName,
                                appName = appName
                            )
                        )
                    }
                }

                // 4. Start the blocking service
                val intent = Intent(context, BlockingService::class.java).apply {
                    action = BlockingService.ACTION_START_BLOCKING
                    putExtra("session_id", sessionId)
                    putStringArrayListExtra(BlockingService.EXTRA_APP_PACKAGES, ArrayList(apps))
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    ContextCompat.startForegroundService(context, intent)
                } else {
                    context.startService(intent)
                }

                // 5. Schedule auto-stop if duration is set
                if (durationMinutes > 0) {
                    timerManager.scheduleAutoStop(sessionId, durationMinutes)
                }

                result.success(true)
            } catch (e: Exception) {
                e.printStackTrace()
                result.error("START_ERROR", e.message, null)
            }
        }
    }

    /**
     * Stop the current blocking session
     */
    private fun stopBlocking(result: MethodChannel.Result) {
        scope.launch {
            try {
                val session = withContext(Dispatchers.IO) {
                    database.blockingSessionDao().getActiveSession()
                }

                if (session != null) {
                    // Cancel timer if exists
                    timerManager.cancelAutoStop(session.id)

                    // Mark session as ended
                    withContext(Dispatchers.IO) {
                        database.blockingSessionDao().endSession(
                            session.id,
                            System.currentTimeMillis()
                        )
                    }
                }

                // Stop the blocking service
                val intent = Intent(context, BlockingService::class.java).apply {
                    action = BlockingService.ACTION_STOP_BLOCKING
                }
                context.startService(intent)

                result.success(true)
            } catch (e: Exception) {
                e.printStackTrace()
                result.error("STOP_ERROR", e.message, null)
            }
        }
    }

    /**
     * Get the current active blocking session
     */
    private fun getActiveSession(result: MethodChannel.Result) {
        scope.launch {
            try {
                // 1. Check for manual session
                val session = withContext(Dispatchers.IO) {
                    database.blockingSessionDao().getActiveSession()
                }

                if (session != null) {
                    val apps = withContext(Dispatchers.IO) {
                        database.sessionBlockedAppDao().getAppsForSession(session.id)
                    }

                    val sessionMap = mapOf(
                        "id" to session.id,
                        "startTime" to session.startTime,
                        "endTime" to (session.startTime + (session.durationMinutes * 60 * 1000)),
                        "durationMinutes" to session.durationMinutes,
                        "isActive" to session.isActive,
                        "isPaused" to session.isPaused,
                        "isStrictMode" to session.isStrictMode,
                        "strictModeLevel" to (session.strictModeLevel ?: "NONE"),
                        "strictModePin" to session.strictModePin,
                        "strictModeCooldownMinutes" to session.strictModeCooldownMinutes,
                        "cooldownStartedAt" to session.cooldownStartedAt,
                        "cooldownConfirmed" to session.cooldownConfirmed,
                        "message" to session.motivationalMessage,
                        "remainingMinutes" to calculateRemainingMinutes(session),
                        "accumulatedPausedMs" to session.accumulatedPausedMs,
                        "pausedAt" to session.pausedAt,
                        "blockedApps" to apps.map { mapOf(
                            "packageName" to it.packageName,
                            "appName" to it.appName
                        )},
                        "type" to "manual"
                    )
                    result.success(sessionMap)
                    return@launch
                }

                // 2. Check for active schedule
                val schedules = withContext(Dispatchers.IO) {
                    database.scheduleDao().getActiveSchedulesSync()
                }

                // Find currently running schedule
                val currentSchedule = schedules.find { schedule ->
                    // Check if within time window
                    val now = java.util.Calendar.getInstance()
                    val currentMinutes = now.get(java.util.Calendar.HOUR_OF_DAY) * 60 + now.get(java.util.Calendar.MINUTE)
                    val currentDay = now.get(java.util.Calendar.DAY_OF_WEEK) - 1 // 0-6 (Sun-Sat)

                    val startParts = schedule.startTime.split(":")
                    val startMinutes = startParts[0].toInt() * 60 + startParts[1].toInt()

                    val endParts = schedule.endTime.split(":")
                    val endMinutes = endParts[0].toInt() * 60 + endParts[1].toInt()

                    val days = org.json.JSONArray(schedule.daysOfWeek)
                    var isToday = false
                    for (i in 0 until days.length()) {
                        if (days.getInt(i) == currentDay) {
                            isToday = true
                            break
                        }
                    }

                    if (!isToday) return@find false

                    if (endMinutes < startMinutes) {
                        currentMinutes >= startMinutes || currentMinutes < endMinutes
                    } else {
                        currentMinutes >= startMinutes && currentMinutes < endMinutes
                    }
                }

                if (currentSchedule != null) {
                    val blockedApps = withContext(Dispatchers.IO) {
                        database.blockedAppDao().getBlockedAppsForScheduleSync(currentSchedule.id)
                    }

                    // Calculate remaining minutes
                    val now = java.util.Calendar.getInstance()
                    val currentMinutes = now.get(java.util.Calendar.HOUR_OF_DAY) * 60 + now.get(java.util.Calendar.MINUTE)
                    val endParts = currentSchedule.endTime.split(":")
                    val endMinutes = endParts[0].toInt() * 60 + endParts[1].toInt()

                    var remaining = endMinutes - currentMinutes
                    if (remaining < 0) remaining += 24 * 60

                    // Calculate end time
                    val endHour = endParts[0].toInt()
                    val endMinute = endParts[1].toInt()
                    val endCal = java.util.Calendar.getInstance()
                    endCal.set(java.util.Calendar.HOUR_OF_DAY, endHour)
                    endCal.set(java.util.Calendar.MINUTE, endMinute)
                    endCal.set(java.util.Calendar.SECOND, 0)
                    // If end time is before current time, it's tomorrow
                    if (endCal.timeInMillis < System.currentTimeMillis()) {
                        endCal.add(java.util.Calendar.DAY_OF_MONTH, 1)
                    }

                    val sessionMap = mapOf(
                        "id" to currentSchedule.id,
                        "startTime" to System.currentTimeMillis(), // Approximate
                        "endTime" to endCal.timeInMillis,
                        "durationMinutes" to 0,
                        "isActive" to currentSchedule.isActive,
                        "isPaused" to currentSchedule.isPaused,
                        "isStrictMode" to currentSchedule.isStrictMode,
                        "strictModeLevel" to (currentSchedule.strictModeLevel ?: "NONE"),
                        "strictModePin" to currentSchedule.strictModePin,
                        "strictModeCooldownMinutes" to currentSchedule.strictModeCooldownMinutes,
                        "cooldownStartedAt" to currentSchedule.cooldownStartedAt,
                        "cooldownConfirmed" to currentSchedule.cooldownConfirmed,
                        "message" to currentSchedule.motivationalMessage,
                        "remainingMinutes" to remaining,
                        "blockedApps" to blockedApps.map { mapOf(
                            "packageName" to it.packageName,
                            "appName" to it.appName
                        )},
                        "type" to "schedule",
                        "scheduleId" to currentSchedule.id
                    )
                    result.success(sessionMap)
                } else {
                    result.success(null)
                }
            } catch (e: Exception) {
                e.printStackTrace()
                result.error("GET_SESSION_ERROR", e.message, null)
            }
        }
    }

    /**
     * Check if a specific app is currently blocked
     */
    private fun isAppBlocked(packageName: String?, result: MethodChannel.Result) {
        if (packageName == null) {
            result.success(false)
            return
        }

        scope.launch {
            try {
                // Check manual session
                val session = withContext(Dispatchers.IO) {
                    database.blockingSessionDao().getActiveSession()
                }

                if (session != null && session.isActive && !session.isPaused) {
                    val packages = withContext(Dispatchers.IO) {
                        database.sessionBlockedAppDao().getPackageNamesForSession(session.id)
                    }
                    if (packages.contains(packageName)) {
                        result.success(true)
                        return@launch
                    }
                }

                // Check active schedules
                // (Simplified: just check if BlockingService is blocking it?)
                // But BlockingService doesn't expose state easily.
                // Better to check DB for active schedules like in getActiveSession
                // For now, let's rely on getActiveSession logic or just return false if manual session not found
                // Ideally we should replicate getActiveSession logic here but optimized

                // ... (Optimized check omitted for brevity, assuming getActiveSession covers dashboard needs)
                // Actually, let's do a quick check
                val schedules = withContext(Dispatchers.IO) {
                    database.scheduleDao().getActiveSchedulesSync()
                }

                val isBlockedBySchedule = schedules.any { schedule ->
                    if (schedule.isPaused) return@any false

                    // Check time window (same logic as above)
                    val now = java.util.Calendar.getInstance()
                    val currentMinutes = now.get(java.util.Calendar.HOUR_OF_DAY) * 60 + now.get(java.util.Calendar.MINUTE)
                    val currentDay = now.get(java.util.Calendar.DAY_OF_WEEK) - 1

                    val startParts = schedule.startTime.split(":")
                    val startMinutes = startParts[0].toInt() * 60 + startParts[1].toInt()
                    val endParts = schedule.endTime.split(":")
                    val endMinutes = endParts[0].toInt() * 60 + endParts[1].toInt()

                    val days = org.json.JSONArray(schedule.daysOfWeek)
                    var isToday = false
                    for (i in 0 until days.length()) {
                        if (days.getInt(i) == currentDay) {
                            isToday = true
                            break
                        }
                    }

                    if (!isToday) return@any false

                    val isRunning = if (endMinutes < startMinutes) {
                        currentMinutes >= startMinutes || currentMinutes < endMinutes
                    } else {
                        currentMinutes >= startMinutes && currentMinutes < endMinutes
                    }

                    if (isRunning) {
                        val blockedApps = withContext(Dispatchers.IO) {
                            database.blockedAppDao().getBlockedAppsForScheduleSync(schedule.id)
                        }
                        blockedApps.any { it.packageName == packageName }
                    } else {
                        false
                    }
                }

                result.success(isBlockedBySchedule)

            } catch (e: Exception) {
                e.printStackTrace()
                result.success(false)
            }
        }
    }

    /**
     * Pause the current blocking session
     */
    private fun pauseBlocking(result: MethodChannel.Result) {
        scope.launch {
            try {
                // 1. Try manual session
                val session = withContext(Dispatchers.IO) {
                    database.blockingSessionDao().getActiveSession()
                }

                if (session != null && session.isActive && !session.isPaused) {
                    // Check if Hard mode (Easy/Medium can be paused after unlock validation in Flutter)
                    val strictLevel = session.strictModeLevel ?: "NONE"
                    if (strictLevel == "HARD") {
                        result.error("STRICT_MODE", "Cannot pause Hard mode session", null)
                        return@launch
                    }

                    val remaining = calculateRemainingMinutes(session)

                    withContext(Dispatchers.IO) {
                        database.blockingSessionDao().updatePauseStatus(
                            id = session.id,
                            isPaused = true,
                            pausedAt = System.currentTimeMillis(),
                            accumulated = session.accumulatedPausedMs,
                            remaining = remaining
                        )
                    }

                    timerManager.cancelAutoStop(session.id)

                    val intent = Intent(context, BlockingService::class.java).apply {
                        action = BlockingService.ACTION_STOP_BLOCKING
                    }
                    context.startService(intent)

                    result.success(true)
                    return@launch
                }

                // 2. Try active schedule
                // We need to find the running schedule and pause it
                // This requires calling ScheduleChannel logic or duplicating it
                // Since we are in BlockingChannel, we can access ScheduleDao directly

                // Find running schedule (reuse logic from getActiveSession)
                val schedules = withContext(Dispatchers.IO) {
                    database.scheduleDao().getActiveSchedulesSync()
                }

                val currentSchedule = schedules.find { schedule ->
                    if (schedule.isPaused) return@find false
                    // ... (time window check) ...
                    val now = java.util.Calendar.getInstance()
                    val currentMinutes = now.get(java.util.Calendar.HOUR_OF_DAY) * 60 + now.get(java.util.Calendar.MINUTE)
                    val currentDay = now.get(java.util.Calendar.DAY_OF_WEEK) - 1
                    val startParts = schedule.startTime.split(":")
                    val startMinutes = startParts[0].toInt() * 60 + startParts[1].toInt()
                    val endParts = schedule.endTime.split(":")
                    val endMinutes = endParts[0].toInt() * 60 + endParts[1].toInt()
                    val days = org.json.JSONArray(schedule.daysOfWeek)
                    var isToday = false
                    for (i in 0 until days.length()) {
                        if (days.getInt(i) == currentDay) {
                            isToday = true
                            break
                        }
                    }
                    if (!isToday) return@find false
                    if (endMinutes < startMinutes) {
                        currentMinutes >= startMinutes || currentMinutes < endMinutes
                    } else {
                        currentMinutes >= startMinutes && currentMinutes < endMinutes
                    }
                }

                if (currentSchedule != null) {
                    // Check if Hard mode (Easy/Medium can be paused after unlock validation in Flutter)
                    val strictLevel = currentSchedule.strictModeLevel ?: "NONE"
                    if (strictLevel == "HARD") {
                        result.error("STRICT_MODE", "Cannot pause Hard mode schedule", null)
                        return@launch
                    }

                    // Pause schedule
                    val updatedSchedule = currentSchedule.copy(isPaused = true)
                    withContext(Dispatchers.IO) {
                        database.scheduleDao().updateSchedule(updatedSchedule)
                    }

                    // Stop blocking service
                    val stopIntent = Intent(context, BlockingService::class.java).apply {
                        action = BlockingService.ACTION_STOP_SCHEDULE
                        val blockedApps = database.blockedAppDao().getBlockedAppsForScheduleSync(currentSchedule.id)
                            .map { it.packageName }
                        putStringArrayListExtra(BlockingService.EXTRA_APP_PACKAGES, ArrayList(blockedApps))
                    }
                    context.startService(stopIntent)

                    result.success(true)
                } else {
                    result.success(false)
                }
            } catch (e: Exception) {
                e.printStackTrace()
                result.error("PAUSE_ERROR", e.message, null)
            }
        }
    }

    /**
     * Resume a paused blocking session
     */
    private fun resumeBlocking(result: MethodChannel.Result) {
        scope.launch {
            try {
                // 1. Try manual session
                val session = withContext(Dispatchers.IO) {
                    database.blockingSessionDao().getActiveSession()
                }

                if (session != null && session.isActive && session.isPaused) {
                    // ... (existing manual resume logic) ...
                    val now = System.currentTimeMillis()
                    val pauseDuration = if (session.pausedAt != null) now - session.pausedAt else 0L
                    val newAccumulated = session.accumulatedPausedMs + pauseDuration

                    withContext(Dispatchers.IO) {
                        database.blockingSessionDao().updatePauseStatus(
                            id = session.id,
                            isPaused = false,
                            pausedAt = null,
                            accumulated = newAccumulated,
                            remaining = null
                        )
                    }

                    // Recalculate remaining based on new accumulation
                    val updatedSession = session.copy(
                        isPaused = false,
                        pausedAt = null,
                        accumulatedPausedMs = newAccumulated
                    )
                    val remaining = calculateRemainingMinutes(updatedSession)
                    timerManager.scheduleAutoStop(session.id, remaining)

                    val packages = withContext(Dispatchers.IO) {
                        database.sessionBlockedAppDao().getPackageNamesForSession(session.id)
                    }

                    val intent = Intent(context, BlockingService::class.java).apply {
                        action = BlockingService.ACTION_START_BLOCKING
                        putExtra("session_id", session.id)
                        putStringArrayListExtra(BlockingService.EXTRA_APP_PACKAGES, ArrayList(packages))
                    }

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        ContextCompat.startForegroundService(context, intent)
                    } else {
                        context.startService(intent)
                    }

                    result.success(true)
                    return@launch
                }

                // 2. Try paused schedule
                val schedules = withContext(Dispatchers.IO) {
                    database.scheduleDao().getActiveSchedulesSync()
                }

                val pausedSchedule = schedules.find { schedule ->
                    if (!schedule.isPaused) return@find false
                    // ... (time window check) ...
                    val now = java.util.Calendar.getInstance()
                    val currentMinutes = now.get(java.util.Calendar.HOUR_OF_DAY) * 60 + now.get(java.util.Calendar.MINUTE)
                    val currentDay = now.get(java.util.Calendar.DAY_OF_WEEK) - 1
                    val startParts = schedule.startTime.split(":")
                    val startMinutes = startParts[0].toInt() * 60 + startParts[1].toInt()
                    val endParts = schedule.endTime.split(":")
                    val endMinutes = endParts[0].toInt() * 60 + endParts[1].toInt()
                    val days = org.json.JSONArray(schedule.daysOfWeek)
                    var isToday = false
                    for (i in 0 until days.length()) {
                        if (days.getInt(i) == currentDay) {
                            isToday = true
                            break
                        }
                    }
                    if (!isToday) return@find false
                    if (endMinutes < startMinutes) {
                        currentMinutes >= startMinutes || currentMinutes < endMinutes
                    } else {
                        currentMinutes >= startMinutes && currentMinutes < endMinutes
                    }
                }

                if (pausedSchedule != null) {
                    // Resume schedule
                    val updatedSchedule = pausedSchedule.copy(isPaused = false)
                    withContext(Dispatchers.IO) {
                        database.scheduleDao().updateSchedule(updatedSchedule)
                    }

                    // Start blocking service
                    // We can use ScheduleManager logic or just start service manually
                    // ScheduleManager.scheduleAlarms handles alarms, but checkAndStartIfActive handles immediate start
                    // Let's just start service manually here as we know it's active

                    val blockedApps = withContext(Dispatchers.IO) {
                        database.blockedAppDao().getBlockedAppsForScheduleSync(pausedSchedule.id)
                    }

                    if (blockedApps.isNotEmpty()) {
                        val serviceIntent = Intent(context, BlockingService::class.java).apply {
                            action = BlockingService.ACTION_START_BLOCKING
                            putExtra(BlockingService.EXTRA_SCHEDULE_ID, pausedSchedule.id)
                            putStringArrayListExtra(
                                BlockingService.EXTRA_APP_PACKAGES,
                                ArrayList(blockedApps.map { it.packageName })
                            )
                        }

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            ContextCompat.startForegroundService(context, serviceIntent)
                        } else {
                            context.startService(serviceIntent)
                        }
                    }

                    result.success(true)
                } else {
                    result.success(false)
                }
            } catch (e: Exception) {
                e.printStackTrace()
                result.error("RESUME_ERROR", e.message, null)
            }
        }
    }

    /**
     * Get a unified list of ALL currently blocked apps from all sources
     */
    private fun getAllBlockedApps(result: MethodChannel.Result) {
        scope.launch {
            try {
                val blockedAppsMap = mutableMapOf<String, MutableMap<String, Any>>()
                val now = System.currentTimeMillis()

                // 1. Manual Session
                val manualSession = withContext(Dispatchers.IO) {
                    database.blockingSessionDao().getActiveSession()
                }
                if (manualSession != null && manualSession.isActive && !manualSession.isPaused) {
                    val apps = withContext(Dispatchers.IO) {
                        database.sessionBlockedAppDao().getAppsForSession(manualSession.id)
                    }
                    val remaining = calculateRemainingMinutes(manualSession)

                    apps.forEach { app ->
                        blockedAppsMap[app.packageName] = mutableMapOf(
                            "packageName" to app.packageName,
                            "appName" to app.appName,
                            "remainingMinutes" to remaining,
                            "source" to "manual",
                            "isStrictMode" to manualSession.isStrictMode
                        )
                    }
                }

                // 2. Active Schedules
                val schedules = withContext(Dispatchers.IO) {
                    database.scheduleDao().getActiveSchedulesSync()
                }

                schedules.forEach { schedule ->
                    // Check if schedule is active NOW
                    val calendar = java.util.Calendar.getInstance()
                    val currentMinutes = calendar.get(java.util.Calendar.HOUR_OF_DAY) * 60 + calendar.get(java.util.Calendar.MINUTE)
                    val currentDay = calendar.get(java.util.Calendar.DAY_OF_WEEK) - 1 // 0-6

                    // Parse days
                    val days = try {
                        org.json.JSONArray(schedule.daysOfWeek).let { arr ->
                            (0 until arr.length()).map { arr.getInt(it) }
                        }
                    } catch (e: Exception) { emptyList<Int>() }

                    if (days.contains(currentDay)) {
                        val startParts = schedule.startTime.split(":")
                        val startMins = startParts[0].toInt() * 60 + startParts[1].toInt()

                        val endParts = schedule.endTime.split(":")
                        val endMins = endParts[0].toInt() * 60 + endParts[1].toInt()

                        val isActive = if (endMins < startMins) {
                            currentMinutes >= startMins || currentMinutes < endMins
                        } else {
                            currentMinutes >= startMins && currentMinutes < endMins
                        }

                        if (isActive) {
                            // Calculate remaining for this schedule
                            var remainingMins = 0
                            if (endMins < currentMinutes) {
                                // Overnight ending tomorrow
                                remainingMins = (24 * 60 - currentMinutes) + endMins
                            } else {
                                remainingMins = endMins - currentMinutes
                            }

                            val scheApps = withContext(Dispatchers.IO) {
                                database.blockedAppDao().getBlockedAppsForScheduleSync(schedule.id)
                            }

                            scheApps.forEach { app ->
                                // Schedule takes priority - always add/update
                                blockedAppsMap[app.packageName] = mutableMapOf(
                                    "packageName" to app.packageName,
                                    "appName" to app.appName,
                                    "remainingMinutes" to remainingMins,
                                    "source" to "schedule",
                                    "isStrictMode" to schedule.isStrictMode
                                )
                            }
                        }
                    }
                }

                // 3. App Limits
                // Query Active Focus Sessions for Limits using correct DAO method name 'getActiveSessions'
                val activeLimitSessions = withContext(Dispatchers.IO) {
                    database.focusSessionDao().getActiveSessions()
                }.filter { it.type == "LIMIT" }

                activeLimitSessions.forEach { session ->
                     val limitId = session.relatedId
                     if (limitId != null) {
                         val limitApps = withContext(Dispatchers.IO) {
                             database.appLimitDao().getPackageNamesForLimit(limitId)
                         }

                         // Time to midnight calculation
                         val cal = java.util.Calendar.getInstance()
                         val nowMins = cal.get(java.util.Calendar.HOUR_OF_DAY) * 60 + cal.get(java.util.Calendar.MINUTE)
                         val minsToMidnight = (24 * 60) - nowMins

                         limitApps.forEach { pkg ->
                             // Only add if not already blocked by schedule or manual
                             if (!blockedAppsMap.containsKey(pkg)) {
                                 val appName = getAppName(pkg)
                                 blockedAppsMap[pkg] = mutableMapOf(
                                    "packageName" to pkg,
                                    "appName" to appName,
                                    "remainingMinutes" to minsToMidnight,
                                    "source" to "limit",
                                    "isStrictMode" to true
                                )
                             }
                         }
                     }
                }

                result.success(blockedAppsMap.values.toList())
            } catch (e: Exception) {
                e.printStackTrace()
                result.error("GET_ALL_APPS_ERROR", e.message, null)
            }
        }
    }

    // Private helpers

    /**
     * Calculate remaining minutes for a session
     */
    private fun calculateRemainingMinutes(session: BlockingSessionEntity): Int {
        if (session.durationMinutes <= 0) return 0

        val now = System.currentTimeMillis()
        val totalElapsedMs = if (session.isPaused && session.pausedAt != null) {
            // If paused, we only count time up to when it was paused
            session.pausedAt - session.startTime - session.accumulatedPausedMs
        } else {
            // If active, we count everything minus total pause time
            now - session.startTime - session.accumulatedPausedMs
        }

        val elapsedMinutes = (totalElapsedMs / (60 * 1000)).toInt()
        val remaining = session.durationMinutes - elapsedMinutes
        return maxOf(0, remaining)
    }

    /**
     * Get app name from package name
     */
    private fun getAppName(packageName: String): String {
        return try {
            val appInfo = context.packageManager.getApplicationInfo(packageName, 0)
            context.packageManager.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            packageName
        }
    }
}
