package com.focusguard.app.services

import android.app.Service
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.app.usage.UsageEvents
import android.os.IBinder
import android.content.SharedPreferences
import com.focusguard.app.data.database.AppDatabase
import com.focusguard.app.data.database.dao.BlockedAppDao
import com.focusguard.app.utils.MotivationalQuotes
import com.focusguard.app.utils.NotificationHelper
import kotlinx.coroutines.*
import java.text.SimpleDateFormat
import java.util.*
import android.view.WindowManager
import android.view.LayoutInflater
import android.view.View
import android.widget.TextView
import android.widget.Button
import com.focusguard.app.R

/**
 * Foreground service that monitors app usage and blocks access to specified apps
 * Runs continuously to detect when blocked apps are launched
 */
class BlockingService : Service() {
    
    private lateinit var usageStatsManager: UsageStatsManager
    private lateinit var blockedAppDao: BlockedAppDao
    private lateinit var appLimitDao: com.focusguard.app.data.database.dao.AppLimitDao
    private lateinit var blockingSessionDao: com.focusguard.app.data.database.dao.BlockingSessionDao
    private lateinit var sessionBlockedAppDao: com.focusguard.app.data.database.dao.SessionBlockedAppDao
    private lateinit var notificationHelper: NotificationHelper
    
    private var monitoringJob: Job? = null
    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())
    
    private var blockedPackages = mutableSetOf<String>()
    private var manualBlockedPackages = mutableSetOf<String>()
    private var scheduleBlockedPackages = mutableSetOf<String>()
    private var limitBlockedPackages = mutableSetOf<String>()
    private var isMonitoring = false
    
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
        notificationHelper = NotificationHelper(this)
        val database = AppDatabase.getInstance(applicationContext)
        blockedAppDao = database.blockedAppDao()
        appLimitDao = database.appLimitDao()
        blockingSessionDao = database.blockingSessionDao()
        sessionBlockedAppDao = database.sessionBlockedAppDao()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_BLOCKING -> {
                val scheduleId = intent.getLongExtra(EXTRA_SCHEDULE_ID, -1)
                val packages = intent.getStringArrayListExtra(EXTRA_APP_PACKAGES)
                startBlocking(scheduleId, packages)
            }
            ACTION_STOP_BLOCKING -> {
                stopManualBlocking()
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
            } else if (packages != null) {
                // Use provided package list (for manual blocking)
                manualBlockedPackages.addAll(packages)
                android.util.Log.d("BlockingService", "Added ${packages.size} packages: $packages")
            }
            
            updateTotalBlockedPackages()
            startMonitoring()
            updateNotification("Blocking ${blockedPackages.size} apps")
        }
    }
    
    /**
     * Stop manual blocking
     */
    private fun stopManualBlocking() {
        manualBlockedPackages.clear()
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
        stopSelf()
    }
    
    /**
     * Stop blocking for a specific schedule's apps
     */
    private fun stopSchedule(packages: ArrayList<String>?) {
        if (packages != null) {
            scheduleBlockedPackages.removeAll(packages.toSet())
            android.util.Log.d("BlockingService", "Stopped blocking for ${packages.size} apps from schedule")
            
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
                
                // Restore manual session if exists
                val activeSession = blockingSessionDao.getActiveSession()
                if (activeSession != null && activeSession.isActive && !activeSession.isPaused) {
                    val sessionApps = sessionBlockedAppDao.getPackageNamesForSession(activeSession.id)
                    manualBlockedPackages.clear()
                    manualBlockedPackages.addAll(sessionApps)
                    android.util.Log.d("BlockingService", "Restored ${sessionApps.size} manual blocked apps from DB")
                } else {
                    // Only clear if we are sure there is no active session (or it is paused)
                    // But wait, if we are just updating, we should probably reflect the DB state.
                    // If DB says no active session, then manualBlockedPackages should be empty for consistency.
                    // However, startBlocking() adds to this list.
                    // If we blindly clear it here, we might interfere if updateBlockedApps() is called concurrently with startBlocking?
                    // But updateBlockedApps is called on start/restart.
                    // Let's rely on DB as source of truth.
                    if (manualBlockedPackages.isNotEmpty() && (activeSession == null || !activeSession.isActive)) {
                         manualBlockedPackages.clear()
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
            val newLimitBlocked = mutableSetOf<String>()
            
            if (activeLimits.isNotEmpty()) {
                val calendar = java.util.Calendar.getInstance()
                calendar.set(java.util.Calendar.HOUR_OF_DAY, 0)
                calendar.set(java.util.Calendar.MINUTE, 0)
                calendar.set(java.util.Calendar.SECOND, 0)
                calendar.set(java.util.Calendar.MILLISECOND, 0)
                val startOfDay = calendar.timeInMillis
                val currentTime = System.currentTimeMillis()
                
                val stats = usageStatsManager.queryAndAggregateUsageStats(startOfDay, currentTime)
                
                for (limit in activeLimits) {
                    if (limit.unlockedUntilMidnight) continue
                    
                    val pgs = appLimitDao.getPackageNamesForLimit(limit.id)
                    
                    // Method 1: Aggregate UsageStats (usually more reliable for total time)
                    var aggregateUsageMillis = 0L
                    for (pkg in pgs) {
                        aggregateUsageMillis += stats[pkg]?.totalTimeInForeground ?: 0L
                    }
                    
                    // Method 2: Manual Event Tracking (more real-time but can miss boundaries)
                    val eventUsageMillis = getAccurateUsageToday(pgs.toSet())
                    
                    // Use the higher value to be safe, but prioritize aggregate stats as baseline
                    val totalUsageMillis = maxOf(aggregateUsageMillis, eventUsageMillis)
                    val totalUsageMinutes = totalUsageMillis / (60 * 1000)
                    
                    if (totalUsageMinutes >= limit.limitMinutes) {
                        android.util.Log.d("BlockingService", "LIMIT EXCEEDED for limit ID=${limit.id}")
                        newLimitBlocked.addAll(pgs)
                    }
                }
            }
            
            if (newLimitBlocked != limitBlockedPackages) {
                limitBlockedPackages.clear()
                limitBlockedPackages.addAll(newLimitBlocked)
                updateTotalBlockedPackages()
                updateNotification("Blocking ${blockedPackages.size} apps")
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    /**
     * Reset unlocked status at midnight using SharedPreferences for persistence
     */
    private suspend fun checkMidnightReset() {
        val prefs = getSharedPreferences("focusguard_prefs", Context.MODE_PRIVATE)
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
            // Check if it's the FocusGuard app itself or our overlay - DON'T block those
            if (foregroundPackage == packageName || foregroundPackage.contains("com.focusguard.app")) {
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
            val log = com.focusguard.app.data.database.entities.UsageLogEntity(
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
     * Update existing notification
     */
    private fun updateNotification(message: String) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        notificationManager.notify(NotificationHelper.ID_SERVICE, notificationHelper.getServiceNotification(message))
    }
}
