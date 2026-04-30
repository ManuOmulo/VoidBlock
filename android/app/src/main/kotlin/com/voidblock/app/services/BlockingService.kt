package com.voidblock.app.services

import android.app.Service
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.app.usage.UsageEvents
import android.os.IBinder
import android.content.SharedPreferences
import com.voidblock.app.data.database.AppDatabase
import com.voidblock.app.data.database.dao.BlockedAppDao
import com.voidblock.app.utils.MotivationalQuotes
import com.voidblock.app.utils.NotificationHelper
import kotlinx.coroutines.*
import java.text.SimpleDateFormat
import java.util.*
import android.view.WindowManager
import android.view.LayoutInflater
import android.view.View
import android.widget.TextView
import android.widget.Button
import com.voidblock.app.R
import android.graphics.LinearGradient
import android.graphics.Shader
import android.graphics.Color
import android.graphics.Typeface

/**
 * Foreground service that monitors app usage and blocks access to specified apps
 * Runs continuously to detect when blocked apps are launched
 */
class BlockingService : Service() {

    private lateinit var usageStatsManager: UsageStatsManager
    private lateinit var blockedAppDao: BlockedAppDao
    private lateinit var appLimitDao: com.voidblock.app.data.database.dao.AppLimitDao
    private lateinit var blockingSessionDao: com.voidblock.app.data.database.dao.BlockingSessionDao
    private lateinit var sessionBlockedAppDao: com.voidblock.app.data.database.dao.SessionBlockedAppDao
    private lateinit var focusSessionDao: com.voidblock.app.data.database.dao.FocusSessionDao
    private lateinit var notificationHelper: NotificationHelper

    private var monitoringJob: Job? = null
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())

    // Track blocked packages per source
    private var blockedPackages = mutableSetOf<String>()

    // Manual blocking (Set is fine, only one session at a time)
    private var manualBlockedPackages = mutableSetOf<String>()

    // Schedule blocking: Map<ScheduleId, Set<PackageName>>
    // This allows multiple schedules to block the same app without unblocking it early
    private var activeScheduleApps = java.util.concurrent.ConcurrentHashMap<Long, Set<String>>()

    // App Limits (Set is fine, limits are additive)
    private var limitBlockedPackages = mutableSetOf<String>()

    private var isMonitoring = false

    // Window Manager for Overlay
    private lateinit var windowManager: WindowManager
    private var currentOverlayView: View? = null
    private var lastOverlayPackage: String? = null
    private var lastOverlayTime: Long = 0
    private var lastDismissalTime: Long = 0  // Cooldown after user clicks "Close"
    private var overlayRemovalRequestedAt: Long = 0  // Delayed removal during swipe animations
    private var lastAccessibilityBlockedAt: Long = 0  // Trust Accessibility detection for a period

    // Session Tracking
    private var currentForegroundPackage: String? = null
    private var currentSessionStartTime: Long = 0
    private val activeFocusSessionIds = java.util.concurrent.ConcurrentHashMap<String, Long>()

    // Constants
    companion object {
        const val ACTION_START_BLOCKING = "com.voidblock.app.service.START_BLOCKING"
        const val ACTION_STOP_BLOCKING = "com.voidblock.app.service.STOP_BLOCKING"
        const val ACTION_START_SCHEDULE = "com.voidblock.app.service.START_SCHEDULE"
        const val ACTION_STOP_SCHEDULE = "com.voidblock.app.service.STOP_SCHEDULE"
        const val ACTION_UPDATE_BLOCKED_APPS = "com.voidblock.app.service.UPDATE_BLOCKED_APPS"
        const val ACTION_ACCESSIBILITY_EVENT = "com.voidblock.app.service.ACCESSIBILITY_EVENT"

        const val EXTRA_APP_PACKAGES = "app_packages"
        const val EXTRA_SCHEDULE_ID = "schedule_id"
        const val EXTRA_PACKAGE_NAME = "package_name"

        const val CHECK_INTERVAL_MS = 500L
        const val LIMIT_CHECK_INTERVAL_MS = 60000L
    }

    override fun onCreate() {
        super.onCreate()
        usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        val db = AppDatabase.getInstance(applicationContext)
        blockedAppDao = db.blockedAppDao()
        appLimitDao = db.appLimitDao()
        blockingSessionDao = db.blockingSessionDao()
        sessionBlockedAppDao = db.sessionBlockedAppDao()
        focusSessionDao = db.focusSessionDao()

        notificationHelper = NotificationHelper(this)
        startForeground(NotificationHelper.ID_SERVICE, notificationHelper.getServiceNotification("Monitoring apps..."))

        // Clean up any stale sessions
        cleanupDanglingSessions()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) return START_STICKY

        when (intent.action) {
            ACTION_START_BLOCKING -> {
                val packages = intent.getStringArrayListExtra(EXTRA_APP_PACKAGES)
                startBlocking(0, packages)
            }
            ACTION_STOP_BLOCKING -> {
                manualBlockedPackages.clear()
                endFocusSession("MANUAL", null)
                recalculateBlockedPackages()
                if (blockedPackages.isEmpty() && activeScheduleApps.isEmpty() && limitBlockedPackages.isEmpty()) {
                    stopBlocking()
                } else {
                    updateNotification("Blocking ${blockedPackages.size} apps")
                }
            }
            ACTION_START_SCHEDULE -> {
                val scheduleId = intent.getLongExtra(EXTRA_SCHEDULE_ID, -1)
                startBlocking(scheduleId, null)
            }
            ACTION_STOP_SCHEDULE -> {
                stopSchedule(null)
            }
            ACTION_UPDATE_BLOCKED_APPS -> {
                updateBlockedApps()
            }
            ACTION_ACCESSIBILITY_EVENT -> {
                val pkgName = intent.getStringExtra(EXTRA_PACKAGE_NAME)
                if (pkgName != null) {
                    scope.launch {
                        // Skip if user just dismissed the overlay (cooldown)
                        if (System.currentTimeMillis() - lastDismissalTime < 1000) {
                            return@launch
                        }
                        // Immediately check the app notified by accessibility service
                        if (blockedPackages.contains(pkgName)) {
                            if (pkgName != packageName && !pkgName.contains("com.voidblock.app")) {
                                android.util.Log.d("BlockingService", "ACCESSIBILITY TRIGGER: $pkgName is blocked!")
                                // Reset removal timer - we're on a blocked app
                                overlayRemovalRequestedAt = 0L
                                lastAccessibilityBlockedAt = System.currentTimeMillis()  // Trust this for 2 seconds
                                lastOverlayPackage = pkgName
                                lastOverlayTime = System.currentTimeMillis()
                                showBlockingOverlay(pkgName)
                            }
                        }

                        // NOTE: Don't call checkForegroundApp() for non-blocked apps here.
                        // Let the monitoring loop handle removal with its delayed logic.
                    }
                }
            }

        }

        // Always Update Blocked Apps on start/command to ensure sync
        updateBlockedApps()

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        isMonitoring = false
        monitoringJob?.cancel()
        removeOverlay()

        // End all active sessions
        activeFocusSessionIds.keys.forEach { key ->
             val type = key.split("_")[0]
             val id = key.substringAfter("_", "").toLongOrNull()
             if (type.isNotEmpty()) {
                 endFocusSession(type, id)
             }
        }
    }

    private fun stopBlocking() {
        android.util.Log.d("BlockingService", "Stopping BlockingService")
        stopSelf()
    }

    /**
     * Start blocking apps for a specific schedule
     */
    private fun startBlocking(scheduleId: Long, packages: ArrayList<String>?) {
        android.util.Log.d("BlockingService", "startBlocking called: scheduleId=$scheduleId, packages=$packages")
        scope.launch {
            if (scheduleId > 0) {
                // Load blocked apps from database for this schedule
                val apps = blockedAppDao.getBlockedAppsForScheduleSync(scheduleId)
                val appSet = apps.map { it.packageName }.toSet()

                // Store in Map under Schedule ID
                activeScheduleApps[scheduleId] = appSet
                android.util.Log.d("BlockingService", "Schedule $scheduleId added/updated with ${appSet.size} apps")

                // Start Focus Session for Schedule
                val database = AppDatabase.getInstance(applicationContext)
                val schedule = database.scheduleDao().getScheduleById(scheduleId)
                val duration = 0 // Schedules don't have a fixed duration in the session sense
                startFocusSession("SCHEDULE", scheduleId, duration)
            } else if (packages != null) {
                // Use provided package list (for manual blocking)
                manualBlockedPackages.clear()
                manualBlockedPackages.addAll(packages)
                android.util.Log.d("BlockingService", "Manual blocking started with ${packages.size} packages")

                // Start Focus Session for Manual
                val session = blockingSessionDao.getActiveSession()
                startFocusSession("MANUAL", session?.id, session?.durationMinutes ?: 0)
            }

            recalculateBlockedPackages()

            // Log for debugging
            logActiveSchedules()

            startMonitoring()
            updateNotification("Blocking ${blockedPackages.size} apps")
        }
    }

    /**
     * Stop blocking for a specific schedule's apps
     * NOTE: Takes ArrayList for compat, but relies on finding the right schedule to remove
     * Ideally this should just take an ID, but we use the existing Intent structure.
     * Actually, the intent passes packages usually, but we need the ID to remove correctly.
     * Let's check how it's called. It seems it's called with packages list.
     * Wait, BlockingChannel logic (which I saw earlier) might need to be adjusted or we infer.
     * Better: The caller SHOULD pass the ID.
     * Checking existing calls: ScheduleChannel passes "action = STOP_SCHEDULE" and extras.
     * I need to make sure I can remove by ID.
     *
     * IMPORTANT: The previous implementation of ACTION_STOP_SCHEDULE passed EXTRA_APP_PACKAGES.
     * But it didn't pass EXTRA_SCHEDULE_ID usually?
     * Let's look at ScheduleChannel again.
     * In toggleSchedule/deleteSchedule/pauseSchedule, it sets ACTION_STOP_SCHEDULE and passes blockedApps list.
     * It does NOT pass schedule ID in the intent currently!
     *
     * PROBLEM: We need the Schedule ID to remove it from the Map.
     * FIX: I will infer it if possible, OR I will assume updateBlockedPackages will clean it up.
     * BUT updateBlockedPackages is not called on stop.
     *
     * Wait, if I change the logic, I need to ensure the caller sends the ID.
     * I can't easily change the caller (ScheduleChannel.kt) in this same atomic step if I only edit this file.
     * ALTHOUGH, ScheduleChannel.kt IS in the codebase and I can edit it.
     *
     * ALTERNATIVE: For this step, I will modify this method to accept ID if present,
     * but if not (legacy call), I might have to do a somewhat expensive scan or just re-sync everything.
     *
     * ACTUALLY, checking ScheduleChannel code I read earlier:
     * It sends: ACTION_STOP_SCHEDULE and EXTRA_APP_PACKAGES.
     * It does NOT send EXTRA_SCHEDULE_ID.
     *
     * STRATEGY:
     * 1. I will assume for this specific refactor that I will ALSO update ScheduleChannel to send the ID.
     *    OR I can just call updateBlockedApps() which re-syncs everything from DB.
     * 2. Re-syncing from DB is safer and cleaner.
     *    `updateBlockedApps` pulls "Active" schedules.
     *    If a schedule was just paused/deleted in DB (which happens before the service call),
     *    then `updateBlockedApps` will see it's gone and remove it from the Map.
     *
     * So, implementation: stopSchedule will just call updateBlockedApps().
     */
    private fun stopSchedule(packages: ArrayList<String>?) {
        // We ignore the packages list now and rely on a full re-sync from DB
        // This ensures the Map activeScheduleApps is exactly in sync with DB state
        android.util.Log.d("BlockingService", "stopSchedule called - Triggering full re-sync")
        updateBlockedApps()
    }

    /**
     * Recalculate the union of all blocked apps
     */
    private fun recalculateBlockedPackages() {
        blockedPackages.clear()

        // 1. Add all manual apps
        blockedPackages.addAll(manualBlockedPackages)

        // 2. Add all apps from ALL active schedules
        activeScheduleApps.values.forEach { appSet ->
            blockedPackages.addAll(appSet)
        }

        // 3. Add limit apps
        blockedPackages.addAll(limitBlockedPackages)

        android.util.Log.d("BlockingService", "Recalculated blocked packages. Total: ${blockedPackages.size}")
    }

    private fun logActiveSchedules() {
        android.util.Log.d("BlockingService", "Active Schedules map size: ${activeScheduleApps.size}")
        activeScheduleApps.forEach { (id, apps) ->
            android.util.Log.d("BlockingService", " - Schedule $id: ${apps.size} apps")
        }
    }

    /**
     * Update blocked apps list from database (for active schedules and app limits)
     * Now with time-window validation!
     */
    private fun updateBlockedApps() {
        scope.launch {
            try {
                // 1. Get all schedules that are marked as 'isActive' in DB
                // We use the DAO to get the entities, not just the list of strings
                val database = AppDatabase.getInstance(applicationContext)
                val activeSchedules = database.scheduleDao().getActiveSchedulesSync()

                val userTime = Calendar.getInstance()
                val currentDay = userTime.get(Calendar.DAY_OF_WEEK) - 1 // 0-6
                val currentMinutes = userTime.get(Calendar.HOUR_OF_DAY) * 60 + userTime.get(Calendar.MINUTE)

                val validScheduleIds = mutableSetOf<Long>()

                // 2. Filter schedules that are ACTUALLY active right now (time window check)
                activeSchedules.forEach { schedule ->
                    // Skip if paused (already filtered by query usually, but double check)
                    if (schedule.isPaused) return@forEach

                    // Check Day
                    // JSON parsing of [0,1,2] from string
                    val days = try {
                         org.json.JSONArray(schedule.daysOfWeek).let { arr ->
                             (0 until arr.length()).map { arr.getInt(it) }
                         }
                    } catch (e: Exception) { emptyList<Int>() }

                    if (!days.contains(currentDay)) return@forEach

                    // Check Time
                    val startParts = schedule.startTime.split(":")
                    val startMins = startParts[0].toInt() * 60 + startParts[1].toInt()

                    val endParts = schedule.endTime.split(":")
                    val endMins = endParts[0].toInt() * 60 + endParts[1].toInt()

                    val isRunning = if (endMins < startMins) {
                         // Overnight
                         currentMinutes >= startMins || currentMinutes < endMins
                    } else {
                         // Standard
                         currentMinutes >= startMins && currentMinutes < endMins
                    }

                    if (isRunning) {
                        validScheduleIds.add(schedule.id)

                        // Load apps for this valid schedule if not already loaded
                        if (!activeScheduleApps.containsKey(schedule.id)) {
                             val apps = blockedAppDao.getBlockedAppsForScheduleSync(schedule.id)
                             activeScheduleApps[schedule.id] = apps.map { it.packageName }.toSet()

                             // Also start focus session tracking if missing
                             startFocusSession("SCHEDULE", schedule.id, 0)
                        }
                    }
                }

                // 3. Remove schedules from Map that are no longer valid
                val iterator = activeScheduleApps.keys.iterator()
                while (iterator.hasNext()) {
                    val id = iterator.next()
                    if (!validScheduleIds.contains(id)) {
                        iterator.remove()
                        endFocusSession("SCHEDULE", id) // Stop tracking duration
                        android.util.Log.d("BlockingService", "Removed inactive schedule ID: $id")
                    }
                }

                // 4. Handle Manual Session (Existing Logic)
                val activeSession = blockingSessionDao.getActiveSession()
                if (activeSession != null && activeSession.isActive) {
                    if (activeSession.isPaused) {
                        manualBlockedPackages.clear()
                        endFocusSession("MANUAL", activeSession.id)
                    } else {
                        val sessionApps = sessionBlockedAppDao.getPackageNamesForSession(activeSession.id)
                        manualBlockedPackages.clear()
                        manualBlockedPackages.addAll(sessionApps)
                        startFocusSession("MANUAL", activeSession.id, activeSession.durationMinutes)
                    }
                } else {
                    if (manualBlockedPackages.isNotEmpty()) {
                         manualBlockedPackages.clear()
                         endFocusSession("MANUAL", null)
                    }
                }

                // 5. Handle App Limits (Existing Logic)
                val activeLimits = appLimitDao.getActiveLimits()
                checkAppLimits()

                // 6. Recalculate & Monitor
                recalculateBlockedPackages()

                if (blockedPackages.isNotEmpty() || activeLimits.isNotEmpty()) {
                    startMonitoring()
                    updateNotification(if (blockedPackages.isNotEmpty()) "Blocking ${blockedPackages.size} apps" else "Monitoring app limits")
                } else {
                    // Only stop if completely clean
                    if (manualBlockedPackages.isEmpty() && activeScheduleApps.isEmpty() && limitBlockedPackages.isEmpty()) {
                        stopBlocking()
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun updateTotalBlockedPackages() {
        // Redirect to new method to ensure consistency
        recalculateBlockedPackages()
    }

    /**
     * Start monitoring foreground apps
     */
    private fun startMonitoring() {
        if (isMonitoring) return

        isMonitoring = true
        monitoringJob = scope.launch {
            var lastLimitCheck = 0L
            while (isActive && isMonitoring) {
                val now = System.currentTimeMillis()

                // Periodic checks
                if (now - lastLimitCheck >= LIMIT_CHECK_INTERVAL_MS) {
                    checkMidnightReset()
                    checkAppLimits()
                    lastLimitCheck = now
                }

                checkForegroundApp()
                delay(CHECK_INTERVAL_MS)
            }
        }
    }

    /**
     * Check app usage against limits
     */
    private suspend fun checkAppLimits() {
        try {
            val activeLimits = appLimitDao.getActiveLimits()
            if (activeLimits.isEmpty()) {
                if (limitBlockedPackages.isNotEmpty()) {
                    limitBlockedPackages.clear()
                    updateTotalBlockedPackages()
                }
                return
            }

            val calendar = java.util.Calendar.getInstance()
            calendar.set(java.util.Calendar.HOUR_OF_DAY, 0)
            calendar.set(java.util.Calendar.MINUTE, 0)
            calendar.set(java.util.Calendar.SECOND, 0)
            calendar.set(java.util.Calendar.MILLISECOND, 0)
            val startOfDay = calendar.timeInMillis
            val currentTime = System.currentTimeMillis()

            val newLimitBlocked = mutableSetOf<String>()

            val newlyExceededLimits = activeLimits.filter { limit ->
                if (limit.unlockedUntilMidnight) false
                else {
                    val pgs = appLimitDao.getPackageNamesForLimit(limit.id)
                    val eventUsageMillis = getAccurateUsageToday(pgs.toSet())
                    val totalUsageMinutes = eventUsageMillis / (60 * 1000)

                    val exceeded = totalUsageMinutes >= limit.limitMinutes
                    if (exceeded) {
                        newLimitBlocked.addAll(pgs)
                    }
                    exceeded
                }
            }

            val newlyExceededLimitIds = newlyExceededLimits.map { it.id }.toSet()

            // Start sessions for newly exceeded limits
            newlyExceededLimits.forEach { limit ->
                val key = "LIMIT_${limit.id}"
                if (!activeFocusSessionIds.containsKey(key)) {
                    startFocusSession("LIMIT", limit.id, limit.limitMinutes)
                }
            }

            // End sessions for limits that are no longer exceeded
            activeFocusSessionIds.keys.filter { it.startsWith("LIMIT_") }.toList().forEach { key ->
                val limitId = key.substringAfter("LIMIT_").toLongOrNull()
                if (limitId != null && !newlyExceededLimitIds.contains(limitId)) {
                    endFocusSession("LIMIT", limitId)
                }
            }

            if (newLimitBlocked != limitBlockedPackages) {
                limitBlockedPackages.clear()
                limitBlockedPackages.addAll(newLimitBlocked)
                updateTotalBlockedPackages()
                updateNotification(if (blockedPackages.isNotEmpty()) "Blocking ${blockedPackages.size} apps" else "Monitoring apps")
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    /**
     * Reset unlocked status at midnight using SharedPreferences for persistence
     */
    private suspend fun checkMidnightReset() {
        val prefs = getSharedPreferences("voidblock_prefs", Context.MODE_PRIVATE)
        val lastResetDate = prefs.getString("last_reset_date", "")
        val currentDate = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

        if (lastResetDate != currentDate) {
            android.util.Log.d("BlockingService", "MIDNIGHT RESET TRIGGERED: $lastResetDate -> $currentDate")

            // Reset all limits' unlocked status in DB
            val allLimits = appLimitDao.getAllLimits()
            for (limit in allLimits) {
                if (limit.unlockedUntilMidnight) {
                    appLimitDao.setUnlockedStatus(limit.id, false)
                }
            }

            // Clear current tracking to avoid spillover from yesterday
            currentSessionStartTime = System.currentTimeMillis()

            // Update last reset date
            prefs.edit().putString("last_reset_date", currentDate).apply()
        }
    }

    private fun getStartOfDay(): Long {
        val calendar = Calendar.getInstance()
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        return calendar.timeInMillis
    }

    private fun getAccurateUsageToday(targetPackages: Set<String>): Long {
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

        return usageMap.values.sum()
    }

    /**
     * Stop monitoring
     */
    private fun stopMonitoring() {
        isMonitoring = false
        monitoringJob?.cancel()
        monitoringJob = null
    }

    /**
     * Check if current foreground app is blocked
     */
    private suspend fun checkForegroundApp() {
        val foregroundPackage = getForegroundApp()
        val now = System.currentTimeMillis()

        // Log detected app periodically (every ~5s) to avoid spam but ensure visibility
        if (now % 5000 < 600) { // Approximate check
             android.util.Log.d("BlockingService", "Monitoring... Current foreground: $foregroundPackage. Blocked list size: ${blockedPackages.size}")
             if (blockedPackages.isNotEmpty()) {
                 android.util.Log.v("BlockingService", "Blocked packages: $blockedPackages")
             }
        }

        // Track session changes
        if (foregroundPackage != null && foregroundPackage != currentForegroundPackage) {
            currentForegroundPackage = foregroundPackage
            currentSessionStartTime = now
            android.util.Log.d("BlockingService", "Foreground transition -> $foregroundPackage")
        }

        if (foregroundPackage != null && blockedPackages.contains(foregroundPackage)) {
            // Check if it's the VoidBlock app itself or our overlay - DON'T block those
            if (foregroundPackage == packageName || foregroundPackage.contains("com.voidblock.app")) {
                removeOverlay()
                return
            }

            // Skip if user just dismissed the overlay (cooldown to prevent flash)
            if (now - lastDismissalTime < 1000) {
                return
            }

            // Cooldown to prevent "machine gun" launches of the overlay
            // If we launched an overlay for THIS package in the last 2 seconds, skip
            if (foregroundPackage == lastOverlayPackage && now - lastOverlayTime < 2000) {
                return
            }

            android.util.Log.d("BlockingService", "BLOCKED APP DETECTED: $foregroundPackage - showing overlay")

            overlayRemovalRequestedAt = 0L  // Reset removal timer since we're on a blocked app
            lastOverlayTime = now
            lastOverlayPackage = foregroundPackage

            // Log the blocked attempt
            logBlockedAttempt(foregroundPackage)

            // Blocked app detected - show blocking overlay
            showBlockingOverlay(foregroundPackage)
        } else {
            // Non-blocked app detected - but wait to confirm it's not a brief flicker during swipe
            if (currentOverlayView != null) {
                // Trust Accessibility Service detection for 2 seconds
                // During swipe animations, getForegroundApp() can be unreliable
                if (now - lastAccessibilityBlockedAt < 2000) {
                    // Accessibility recently confirmed a blocked app, ignore monitoring loop's detection
                    overlayRemovalRequestedAt = 0L  // Reset removal timer
                    return
                }

                if (overlayRemovalRequestedAt == 0L) {
                    // First time seeing non-blocked app, start the timer
                    overlayRemovalRequestedAt = now
                    android.util.Log.d("BlockingService", "Overlay removal requested, waiting 500ms to confirm...")
                } else if (now - overlayRemovalRequestedAt > 500) {
                    // Confirmed: user has been on non-blocked app for 500ms, safe to remove
                    android.util.Log.d("BlockingService", "Confirmed non-blocked foreground for 500ms, removing overlay")
                    removeOverlay()
                    overlayRemovalRequestedAt = 0L
                }
                // Otherwise, wait for next check cycle
            }
        }
    }

    // Track last logged time to prevent stats inflation
    private val lastLoggedStatTime = mutableMapOf<String, Long>()

    /**
     * Log blocked app access attempt to database
     */
    private suspend fun logBlockedAttempt(packageName: String) {
        val now = System.currentTimeMillis()
        val lastLogged = lastLoggedStatTime[packageName] ?: 0L

        // Only log 1 "try" per minute to avoid inflation
        if (now - lastLogged < 60_000) {
            return
        }

        lastLoggedStatTime[packageName] = now

        try {
            val log = com.voidblock.app.data.database.entities.UsageLogEntity(
                packageName = packageName,
                appName = getAppName(packageName),
                startTime = now,
                endTime = now,
                durationMillis = 0,
                wasBlocked = true
            )
            AppDatabase.getInstance(applicationContext).usageLogDao().insertLog(log)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    /**
     * Get the current foreground app package name
     */
    private fun getForegroundApp(): String? {
        val currentTime = System.currentTimeMillis()

        // 1. Try granular Events first (wide window)
        val events = usageStatsManager.queryEvents(currentTime - 30000, currentTime)
        val event = UsageEvents.Event()
        var lastEventPackage: String? = null
        var lastEventTime = 0L

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                lastEventPackage = event.packageName
                lastEventTime = event.timeStamp
            }
        }

        // 2. Fallback: queryUsageStats for apps that were already open
        val stats = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            currentTime - 1000 * 120, // Last 2 minutes
            currentTime
        )

        if (stats != null && stats.isNotEmpty()) {
            var mostRecentApp: android.app.usage.UsageStats? = null
            for (usageStats in stats) {
                // Skip our own app to find the actual foreground app we might need to block
                if (usageStats.packageName == packageName) continue

                if (mostRecentApp == null || usageStats.lastTimeUsed > mostRecentApp.lastTimeUsed) {
                    mostRecentApp = usageStats
                }
            }

            // If usage stats show something more recent than the last event, trust it
            if (mostRecentApp != null && (lastEventPackage == null || mostRecentApp.lastTimeUsed > lastEventTime)) {
                return mostRecentApp.packageName
            }
        }

        // 3. Final fallback: Return last event package if we had one, else current state
        return lastEventPackage ?: currentForegroundPackage
    }

    /**
     * Show blocking overlay using WindowManager
     */
    private fun showBlockingOverlay(packageName: String) {
        // Enforce overlay permission check
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M &&
            !android.provider.Settings.canDrawOverlays(this)) {
            android.util.Log.w("BlockingService", "Missing SYSTEM_ALERT_WINDOW permission. Cannot show overlay.")
            return
        }

        scope.launch(Dispatchers.Main) {
            try {
                // If the same package is already handled, don't re-add
                if (currentOverlayView != null && lastOverlayPackage == packageName) {
                    return@launch
                }

                removeOverlay() // Clear existing if any


                val inflater = getSystemService(Context.LAYOUT_INFLATER_SERVICE) as LayoutInflater
                val overlayView = inflater.inflate(R.layout.activity_blocking_overlay, null)

                // Set up fonts and text
                val appName = getAppName(packageName)
                val restrictedText = overlayView.findViewById<TextView>(R.id.app_name_text)
                val titleText = overlayView.findViewById<TextView>(R.id.title_text)
                val messageText = overlayView.findViewById<TextView>(R.id.message_text)
                val closeButton = overlayView.findViewById<Button>(R.id.close_button)

                // Force Roboto to bypass system fonts
                val robotoBold = Typeface.create("sans-serif", Typeface.BOLD)
                val robotoBlack = Typeface.create("sans-serif-black", Typeface.NORMAL)
                val robotoNormal = Typeface.create("sans-serif", Typeface.NORMAL)

                restrictedText.typeface = robotoNormal
                restrictedText.text = "VoidBlock restricted $appName"

                titleText.typeface = robotoBlack // Making it "thicker" as requested

                messageText.typeface = robotoNormal
                messageText.text = MotivationalQuotes.getRandomQuote()

                closeButton.typeface = robotoBold

                // Apply VERTICAL LinearGradient Shader to the title text
                titleText.post {
                    val paint = titleText.paint
                    val height = titleText.height.toFloat()
                    // Top to bottom gradient for a more "solid" premium look
                    val textShader = LinearGradient(0f, 0f, 0f, height,
                        intArrayOf(Color.parseColor("#4FACFE"), Color.parseColor("#8E2DE2")),
                        null, Shader.TileMode.CLAMP)
                    paint.shader = textShader
                    titleText.invalidate()
                }

                // Set up button
                closeButton.setOnClickListener {
                    lastDismissalTime = System.currentTimeMillis()
                    navigateToHomeInternal()
                    removeOverlay()
                }

                // Setup safe fade-in animation for the central content
                val contentRoot = overlayView.findViewById<View>(R.id.main_content_root)
                if (contentRoot != null) {
                    contentRoot.alpha = 0f
                    contentRoot.animate()
                        .alpha(1f)
                        .setDuration(400)
                        .start()
                }

                val params = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.MATCH_PARENT,
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O)
                        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                    else
                        @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE,
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                    WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS,
                    android.graphics.PixelFormat.TRANSLUCENT
                )

                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.P) {
                    params.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
                }

                // Force system UI visibility for transparent bars and dark icons
                @Suppress("DEPRECATION")
                overlayView.systemUiVisibility = (View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                        or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                        or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                        or View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR)

                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    @Suppress("DEPRECATION")
                    overlayView.systemUiVisibility = overlayView.systemUiVisibility or View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
                }

                windowManager.addView(overlayView, params)
                currentOverlayView = overlayView
                lastOverlayPackage = packageName
                lastOverlayTime = System.currentTimeMillis()

                android.util.Log.d("BlockingService", "WindowManager overlay added for $packageName")
            } catch (e: Exception) {
                android.util.Log.e("BlockingService", "Error showing WindowManager overlay", e)
            }
        }
    }

    /**
     * Remove the current overlay if it exists
     */
    private fun removeOverlay() {
        try {
            currentOverlayView?.let {
                windowManager.removeView(it)
                currentOverlayView = null
                lastOverlayPackage = null
                android.util.Log.d("BlockingService", "WindowManager overlay removed")
            }
        } catch (e: Exception) {
            android.util.Log.e("BlockingService", "Error removing overlay", e)
        }
    }

    /**
     * Start a focus session in the database
     */
    private fun startFocusSession(type: String, relatedId: Long?, durationMinutes: Int) {
        val key = if (relatedId != null) "${type}_$relatedId" else type
        if (activeFocusSessionIds.containsKey(key)) return

        scope.launch(Dispatchers.IO) {
            val session = com.voidblock.app.data.database.entities.FocusSessionEntity(
                startTime = System.currentTimeMillis(),
                type = type,
                relatedId = relatedId,
                durationMinutes = durationMinutes
            )
            val id = focusSessionDao.insertSession(session)
            activeFocusSessionIds[key] = id
            android.util.Log.d("BlockingService", "Started Focus Session: $key, ID: $id")
        }
    }

    /**
     * End a focus session in the database
     */
    private fun endFocusSession(type: String, relatedId: Long?) {
        val now = System.currentTimeMillis()

        if (relatedId == null) {
            // 1. Safety fallback: End ALL active sessions of this type in DB
            // This handles cases where the service was restarted and the map is empty
            scope.launch(Dispatchers.IO) {
                focusSessionDao.endSessionsByType(type, now)
            }

            // End ALL sessions of this type in the in-memory map
            val keysToEnd = activeFocusSessionIds.keys.filter { it.startsWith("${type}") }
            if (keysToEnd.isEmpty()) {
                android.util.Log.w("BlockingService", "No active focus sessions found in map for type: $type")
            }

            keysToEnd.forEach { k ->
                val id = activeFocusSessionIds.remove(k)
                if (id != null) {
                    scope.launch(Dispatchers.IO) {
                        focusSessionDao.endSession(id, now)
                        android.util.Log.d("BlockingService", "Ended Focus Session: $k, ID: $id")
                    }
                }
            }
            return
        }

        val key = "${type}_$relatedId"
        val id = activeFocusSessionIds.remove(key)
        if (id != null) {
            scope.launch(Dispatchers.IO) {
                focusSessionDao.endSession(id, now)
                android.util.Log.d("BlockingService", "Ended Focus Session: $key, ID: $id")
            }
        } else {
            // Check for prefix match just in case it was stored without ID
            val fallbackId = activeFocusSessionIds.remove(type)
            if (fallbackId != null) {
                scope.launch(Dispatchers.IO) {
                    focusSessionDao.endSession(fallbackId, now)
                    android.util.Log.d("BlockingService", "Ended Focus Session (Fallback): $type, ID: $fallbackId")
                }
            }
        }
    }

    /**
     * Navigate to home screen
     */
    private fun navigateToHomeInternal() {
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(homeIntent)
    }

    /**
     * Get app name from package name
     */
    private fun getAppName(packageName: String): String {
        return try {
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            packageName
        }
    }


    /**
     * Clean up any focus sessions that were left open (e.g. app crash)
     */
    private fun cleanupDanglingSessions() {
        scope.launch(Dispatchers.IO) {
            try {
                val dangling = focusSessionDao.getActiveSessions()
                if (dangling.isNotEmpty()) {
                    val now = System.currentTimeMillis()
                    dangling.forEach { session ->
                        focusSessionDao.endSession(session.id, now)
                    }
                    android.util.Log.d("BlockingService", "Cleaned up ${dangling.size} dangling focus sessions.")
                }
            } catch (e: Exception) {
                android.util.Log.e("BlockingService", "Error cleaning up dangling sessions", e)
            }
        }
    }

    /**
     * Update existing notification
     */
    private fun updateNotification(message: String) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        notificationManager.notify(NotificationHelper.ID_SERVICE, notificationHelper.getServiceNotification(message))
    }
}
