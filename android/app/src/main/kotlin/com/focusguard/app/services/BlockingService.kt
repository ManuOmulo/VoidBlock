package com.focusguard.app.services

import android.app.Service
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.IBinder
import com.focusguard.app.data.database.AppDatabase
import com.focusguard.app.data.database.dao.BlockedAppDao
import com.focusguard.app.utils.MotivationalQuotes
import com.focusguard.app.utils.NotificationHelper
import kotlinx.coroutines.*

/**
 * Foreground service that monitors app usage and blocks access to specified apps
 * Runs continuously to detect when blocked apps are launched
 */
class BlockingService : Service() {
    
    private lateinit var usageStatsManager: UsageStatsManager
    private lateinit var blockedAppDao: BlockedAppDao
    private lateinit var appLimitDao: com.focusguard.app.data.database.dao.AppLimitDao
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
                    checkAppLimits()
                    checkMidnightReset()
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
                    var totalUsageMillis = 0L
                    
                    pgs.forEach { pkg ->
                        val usage = stats[pkg]?.totalTimeInForeground ?: 0L
                        totalUsageMillis += usage
                        
                        // Augment with current session if this app is currently in foreground
                        if (pkg == currentForegroundPackage && currentSessionStartTime > 0) {
                            val sessionDuration = currentTime - currentSessionStartTime
                            if (sessionDuration > 0) {
                                totalUsageMillis += sessionDuration
                            }
                        }
                    }
                    
                    val totalUsageMinutes = totalUsageMillis / (60 * 1000)
                    if (totalUsageMinutes >= limit.limitMinutes) {
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
     * Reset unlocked status at midnight
     */
    private suspend fun checkMidnightReset() {
        val currentDay = java.util.Calendar.getInstance().get(java.util.Calendar.DAY_OF_YEAR)
        if (currentDay != lastDayOfMonth) {
            lastDayOfMonth = currentDay
            // Reset all limits' unlocked status
            val allLimits = appLimitDao.getAllLimits()
            for (limit in allLimits) {
                if (limit.unlockedUntilMidnight) {
                    appLimitDao.setUnlockedStatus(limit.id, false)
                }
            }
        }
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
        
        // Track session changes
        if (foregroundPackage != currentForegroundPackage) {
            currentForegroundPackage = foregroundPackage
            currentSessionStartTime = System.currentTimeMillis()
            // android.util.Log.d("BlockingService", "Foreground app changed to: $foregroundPackage")
        }
        
        if (foregroundPackage != null && blockedPackages.contains(foregroundPackage)) {
            android.util.Log.d("BlockingService", "BLOCKED APP DETECTED: $foregroundPackage - showing overlay")
            // Log the blocked attempt
            logBlockedAttempt(foregroundPackage)
            
            // Blocked app detected - show blocking overlay
            showBlockingOverlay(foregroundPackage)
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
        val stats = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            currentTime - 1000 * 10, // Last 10 seconds
            currentTime
        )
        
        // Find the app with most recent timestamp
        return stats?.maxByOrNull { it.lastTimeUsed }?.packageName
    }
    
    /**
     * Show blocking overlay activity
     */
    private fun showBlockingOverlay(packageName: String) {
        val intent = Intent(this, Class.forName("com.focusguard.app.activities.BlockingOverlayActivity")).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("blocked_package", packageName)
            putExtra("blocked_app_name", getAppName(packageName))
            putExtra("quote", MotivationalQuotes.getRandomQuote())
        }
        
        try {
            startActivity(intent)
        } catch (e: Exception) {
            e.printStackTrace()
            // Fallback: navigate to home screen
            navigateToHome()
        }
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
     * Navigate to home screen (fallback when overlay fails)
     */
    private fun navigateToHome() {
        val homeIntent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(homeIntent)
    }
    
    /**
     * Update existing notification
     */
    private fun updateNotification(message: String) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        notificationManager.notify(NotificationHelper.ID_SERVICE, notificationHelper.getServiceNotification(message))
    }
}
