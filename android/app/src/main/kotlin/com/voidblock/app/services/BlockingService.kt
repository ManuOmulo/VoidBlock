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

    private var blockedPackages = mutableSetOf<String>()
    private var manualBlockedPackages = mutableSetOf<String>()
    private var scheduleBlockedPackages = mutableSetOf<String>()
    private var limitBlockedPackages = mutableSetOf<String>()
    private var isMonitoring = false

    // Track active focus sessions in DB
    private val activeFocusSessionIds = java.util.concurrent.ConcurrentHashMap<String, Long>()

    // Real-time session tracking
    private var currentForegroundPackage: String? = null
    private var currentSessionStartTime: Long = 0L

    private var lastDayOfMonth = java.util.Calendar.getInstance().get(java.util.Calendar.DAY_OF_YEAR)

    private var lastOverlayTime = 0L
    private var lastOverlayPackage: String? = null

    // WindowManager for overlay
    private val windowManager by lazy { getSystemService(Context.WINDOW_SERVICE) as WindowManager }
    private var currentOverlayView: View? = null

    companion object {
        private const val CHECK_INTERVAL_MS = 500L // Check every 500ms
        private const val LIMIT_CHECK_INTERVAL_MS = 2000L // Check limits every 2s

        const val ACTION_START_BLOCKING = "ACTION_START_BLOCKING"
        const val ACTION_STOP_BLOCKING = "ACTION_STOP_BLOCKING"
        const val ACTION_STOP_SCHEDULE = "ACTION_STOP_SCHEDULE"
        const val ACTION_UPDATE_BLOCKED_APPS = "ACTION_UPDATE_BLOCKED_APPS"

        const val EXTRA_SCHEDULE_ID = "schedule_id"
        const val EXTRA_APP_PACKAGES = "app_packages"
    }

    override fun onCreate() {
        super.onCreate()

        usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val database = AppDatabase.getInstance(applicationContext)
        blockedAppDao = database.blockedAppDao()
        appLimitDao = database.appLimitDao()
        blockingSessionDao = database.blockingSessionDao()
        sessionBlockedAppDao = database.sessionBlockedAppDao()
        focusSessionDao = database.focusSessionDao()
        notificationHelper = NotificationHelper(this)

        cleanupDanglingSessions()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_BLOCKING -> {
                val scheduleId = intent.getLongExtra(EXTRA_SCHEDULE_ID, -1)
                val packages = intent.getStringArrayListExtra(EXTRA_APP_PACKAGES)
                startBlocking(scheduleId, packages)
            }
            ACTION_STOP_BLOCKING -> {
                val sessionId = intent.getLongExtra("session_id", -1)
                stopManualBlocking(if (sessionId != -1L) sessionId else null)
            }
            ACTION_STOP_SCHEDULE -> {
                val packages = intent.getStringArrayListExtra(EXTRA_APP_PACKAGES)
                stopSchedule(packages)
            }
            ACTION_UPDATE_BLOCKED_APPS -> {
                updateBlockedApps()
            }
            else -> {
                // Default: load blocked apps from database and start monitoring
                updateBlockedApps()
            }
        }

        // Start as foreground service
        startForeground(NotificationHelper.ID_SERVICE, notificationHelper.getServiceNotification("Monitoring apps..."))

        return START_STICKY // Restart if killed by system
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        removeOverlay()
        super.onDestroy()
        stopMonitoring()
        scope.cancel()
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
                scheduleBlockedPackages.addAll(apps.map { it.packageName })
                android.util.Log.d("BlockingService", "Loaded ${apps.size} apps from database")

                // Start Focus Session for Schedule
                val database = AppDatabase.getInstance(applicationContext)
                val schedule = database.scheduleDao().getScheduleById(scheduleId)
                val duration = if (schedule != null) {
                    // Estimate duration if possible, or 0
                    0
                } else 0
                startFocusSession("SCHEDULE", scheduleId, duration)
            } else if (packages != null) {
                // Use provided package list (for manual blocking)
                manualBlockedPackages.addAll(packages)
                android.util.Log.d("BlockingService", "Added ${packages.size} packages: $packages")

                // Start Focus Session for Manual
                val session = blockingSessionDao.getActiveSession()
                startFocusSession("MANUAL", session?.id, session?.durationMinutes ?: 0)
            }

            updateTotalBlockedPackages()
            startMonitoring()
            updateNotification("Blocking ${blockedPackages.size} apps")
        }
    }

    /**
     * Stop manual blocking
     */
    private fun stopManualBlocking(sessionId: Long? = null) {
        manualBlockedPackages.clear()

        // Find the active manual session to end it precisely
        scope.launch {
            val session = if (sessionId != null) {
                blockingSessionDao.getSessionById(sessionId)
            } else {
                blockingSessionDao.getActiveSession()
            }
            endFocusSession("MANUAL", session?.id)
        }

        updateTotalBlockedPackages()
        if (blockedPackages.isEmpty()) {
            stopMonitoring()
            stopSelf()
        } else {
            updateNotification("Blocking ${blockedPackages.size} apps")
        }
    }

    /**
     * Stop all blocking
     */
    private fun stopBlocking() {
        stopMonitoring()
        manualBlockedPackages.clear()
        scheduleBlockedPackages.clear()
        limitBlockedPackages.clear()
        blockedPackages.clear()

        // End all active focus sessions
        scope.launch {
            // Copy keys to avoid concurrent modification
            val keys = activeFocusSessionIds.keys.toList()
            keys.forEach { key ->
                val type = key.substringBefore("_")
                val relatedId = key.substringAfter("_", "").toLongOrNull()
                endFocusSession(type, relatedId)
            }

            // Safety: Clear map and end manual session if map was out of sync
            activeFocusSessionIds.clear()
            val manual = blockingSessionDao.getActiveSession()
            endFocusSession("MANUAL", manual?.id)
        }

        stopSelf()
    }

    /**
     * Stop blocking for a specific schedule's apps
     */
    private fun stopSchedule(packages: ArrayList<String>?) {
        if (packages != null) {
            scheduleBlockedPackages.removeAll(packages.toSet())
            android.util.Log.d("BlockingService", "Stopped blocking for ${packages.size} apps from schedule")

            // Note: Stop any schedule session (we don't strictly track ID here,
            // but we can end all SCHEDULE sessions for safety or use a generic key)
            endFocusSession("SCHEDULE", null)

            updateTotalBlockedPackages()
            if (blockedPackages.isEmpty()) {
                stopBlocking()
            } else {
                updateNotification("Blocking ${blockedPackages.size} apps")
            }
        }
    }

    /**
     * Update blocked apps list from database (for active schedules and app limits)
     */
    private fun updateBlockedApps() {
        scope.launch {
            try {
                // Update schedule blocked apps
                val activeBlockedApps = blockedAppDao.getAllActiveBlockedPackages()
                scheduleBlockedPackages.clear()
                scheduleBlockedPackages.addAll(activeBlockedApps)

                val activeSession = blockingSessionDao.getActiveSession()
                if (activeSession != null && activeSession.isActive) {
                    if (activeSession.isPaused) {
                        // Ending the counter because it is paused
                        manualBlockedPackages.clear()
                        endFocusSession("MANUAL", activeSession.id)
                    } else {
                        val sessionApps = sessionBlockedAppDao.getPackageNamesForSession(activeSession.id)
                        manualBlockedPackages.clear()
                        manualBlockedPackages.addAll(sessionApps)
                        android.util.Log.d("BlockingService", "Restored ${sessionApps.size} manual blocked apps from DB")

                        // Restart focus session counter if not already tracked
                        startFocusSession("MANUAL", activeSession.id, activeSession.durationMinutes)
                    }
                } else {
                    // Only clear if we are sure there is no active session
                    if (manualBlockedPackages.isNotEmpty()) {
                         manualBlockedPackages.clear()
                         // End the DB counter just in case
                         endFocusSession("MANUAL", null)
                    }
                }

                // Check if there are any active limits (even if not exceeded yet)
                val activeLimits = appLimitDao.getActiveLimits()

                // Update app limits (first pass to see what's already exceeded)
                checkAppLimits()

                updateTotalBlockedPackages()

                // Start monitoring if anything is blocked OR if we have active limits to watch
                if (blockedPackages.isNotEmpty() || activeLimits.isNotEmpty()) {
                    startMonitoring()
                    updateNotification(if (blockedPackages.isNotEmpty()) "Blocking ${blockedPackages.size} apps" else "Monitoring app limits")
                } else {
                    // Check if we should stop
                    if (manualBlockedPackages.isEmpty() && scheduleBlockedPackages.isEmpty() && limitBlockedPackages.isEmpty()) {
                        stopBlocking()
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun updateTotalBlockedPackages() {
        blockedPackages.clear()
        blockedPackages.addAll(manualBlockedPackages)
        blockedPackages.addAll(scheduleBlockedPackages)
        blockedPackages.addAll(limitBlockedPackages)
        android.util.Log.d("BlockingService", "Total blocked packages: ${blockedPackages.size}. Manual: ${manualBlockedPackages.size}, Schedule: ${scheduleBlockedPackages.size}, Limits: ${limitBlockedPackages.size}")
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

            val stats = usageStatsManager.queryAndAggregateUsageStats(startOfDay, currentTime)
            val newLimitBlocked = mutableSetOf<String>()

            val newlyExceededLimits = activeLimits.filter { limit ->
                if (limit.unlockedUntilMidnight) false
                else {
                    val pgs = appLimitDao.getPackageNamesForLimit(limit.id)
                    val aggregateUsageMillis = stats.filter { pgs.contains(it.key) }
                        .values.sumOf { it.totalTimeInForeground }
                    val eventUsageMillis = getAccurateUsageToday(pgs.toSet())
                    val totalUsageMinutes = maxOf(aggregateUsageMillis, eventUsageMillis) / (60 * 1000)

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

            // Cooldown to prevent "machine gun" launches of the overlay
            // If we launched an overlay for THIS package in the last 2 seconds, skip
            if (foregroundPackage == lastOverlayPackage && now - lastOverlayTime < 2000) {
                return
            }

            android.util.Log.d("BlockingService", "BLOCKED APP DETECTED: $foregroundPackage - showing overlay")

            lastOverlayTime = now
            lastOverlayPackage = foregroundPackage

            // Log the blocked attempt
            logBlockedAttempt(foregroundPackage)

            // Blocked app detected - show blocking overlay
            showBlockingOverlay(foregroundPackage)
        } else {
            // App is not blocked, ensure overlay is removed
            removeOverlay()
        }
    }

    /**
     * Log blocked app access attempt to database
     */
    private suspend fun logBlockedAttempt(packageName: String) {
        try {
            val log = com.voidblock.app.data.database.entities.UsageLogEntity(
                packageName = packageName,
                appName = getAppName(packageName),
                startTime = System.currentTimeMillis(),
                endTime = System.currentTimeMillis(),
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

                // Set app info
                val appName = getAppName(packageName)
                overlayView.findViewById<TextView>(R.id.app_name_text).text = "$appName is blocked"
                overlayView.findViewById<TextView>(R.id.message_text).text = MotivationalQuotes.getRandomQuote()

                // Set up button
                overlayView.findViewById<Button>(R.id.close_button).setOnClickListener {
                    navigateToHomeInternal()
                    removeOverlay()
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
                    WindowManager.LayoutParams.FLAG_FULLSCREEN,
                    android.graphics.PixelFormat.TRANSLUCENT
                )

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
        if (relatedId == null) {
            // End ALL sessions of this type
            val keysToEnd = activeFocusSessionIds.keys.filter { it.startsWith("${type}") }
            if (keysToEnd.isEmpty()) {
                // Last ditch effort: if map is empty but we want to end,
                // we might need to check DB, but let's trust the map for now
                // unless we find it's consistently out of sync.
                android.util.Log.w("BlockingService", "No active focus sessions found in map for type: $type")
            }

            keysToEnd.forEach { k ->
                val id = activeFocusSessionIds.remove(k)
                if (id != null) {
                    scope.launch(Dispatchers.IO) {
                        focusSessionDao.endSession(id, System.currentTimeMillis())
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
                focusSessionDao.endSession(id, System.currentTimeMillis())
                android.util.Log.d("BlockingService", "Ended Focus Session: $key, ID: $id")
            }
        } else {
            // Check for prefix match just in case it was stored without ID
            val fallbackId = activeFocusSessionIds.remove(type)
            if (fallbackId != null) {
                scope.launch(Dispatchers.IO) {
                    focusSessionDao.endSession(fallbackId, System.currentTimeMillis())
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
