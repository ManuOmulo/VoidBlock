package com.voidblock.app.utils

import android.content.Context
import com.voidblock.app.data.database.AppDatabase
import com.voidblock.app.data.database.entities.BlockingSessionEntity
import com.voidblock.app.data.database.entities.ScheduleEntity
import com.voidblock.app.data.database.entities.StrictModePreferencesEntity
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import com.voidblock.app.receivers.StrictModeReceiver
import android.content.Intent
import android.app.PendingIntent
import android.app.AlarmManager
import android.os.Build
import android.util.Log
/**
 * Manager for strict mode enforcement
 * Handles PIN validation, cooldown periods, and hard mode protection
 */
class StrictModeManager(private val context: Context) {
    
    private val database = AppDatabase.getInstance(context)
    
    enum class StrictModeLevel {
        NONE, EASY, MEDIUM, HARD;
        
        companion object {
            fun fromString(value: String): StrictModeLevel {
                return when (value.uppercase()) {
                    "EASY" -> EASY
                    "MEDIUM" -> MEDIUM
                    "HARD" -> HARD
                    else -> NONE
                }
            }
        }
    }
    
    data class UnlockAttemptResult(
        val success: Boolean,
        val reason: String,
        val failedAttempts: Int = 0,
        val lockoutUntil: Long = 0
    )
    
    /**
     * Attempt to unlock a strict mode session
     */
    suspend fun attemptUnlock(
        sessionId: Long,
        inputPin: String? = null
    ): UnlockAttemptResult {
        return withContext(Dispatchers.IO) {
            val session = database.blockingSessionDao().getActiveSession()
            if (session == null || session.id != sessionId) {
                return@withContext UnlockAttemptResult(
                    false,
                    "Session not found or not active"
                )
            }
            
            val level = StrictModeLevel.fromString(session.strictModeLevel)
            
            when (level) {
                StrictModeLevel.NONE -> UnlockAttemptResult(true, "No strict mode")
                StrictModeLevel.EASY -> attemptPinUnlock(session, inputPin)
                StrictModeLevel.MEDIUM -> attemptCooldownUnlock(session)
                StrictModeLevel.HARD -> UnlockAttemptResult(false, "Hard mode: Cannot unlock until time expires")
            }
        }
    }
    
    /**
     * Attempt to unlock schedule with strict mode
     */
    suspend fun attemptScheduleUnlock(
        scheduleId: Long,
        inputPin: String? = null
    ): UnlockAttemptResult {
        return withContext(Dispatchers.IO) {
            val schedule = database.scheduleDao().getScheduleById(scheduleId)
            if (schedule == null) {
                return@withContext UnlockAttemptResult(false, "Schedule not found")
            }
            
            val level = StrictModeLevel.fromString(schedule.strictModeLevel)
            
            when (level) {
                StrictModeLevel.NONE -> UnlockAttemptResult(true, "No strict mode")
                StrictModeLevel.EASY -> attemptSchedulePinUnlock(schedule, inputPin)
                StrictModeLevel.MEDIUM -> attemptScheduleCooldown(schedule)
                StrictModeLevel.HARD -> UnlockAttemptResult(false, "Hard mode: Cannot unlock until schedule ends")
            }
        }
    }
    
    /**
 * Ensure preferences row exists (create if missing)
 */
private suspend fun ensurePreferencesExist() {
    val existing = database.strictModePreferencesDao().getPreferencesSync()
    if (existing == null) {
        val default = StrictModePreferencesEntity(
            id = 1,
            defaultLevel = "NONE",
            defaultPin = null,
            defaultCooldownMinutes = 10,
            emergencyUnlockEnabled = true,
            pinLockoutUntil = 0,
            failedPinAttempts = 0
        )
        database.strictModePreferencesDao().insertOrUpdate(default)
    }
}

    /**
     * Attempt PIN unlock for Easy mode
     */
    private suspend fun attemptPinUnlock(
        session: BlockingSessionEntity,
        inputPin: String?
    ): UnlockAttemptResult {
        // Ensure preferences exist
        ensurePreferencesExist()
        
        val preferences = database.strictModePreferencesDao().getPreferencesSync()
            ?: return UnlockAttemptResult(false, "Failed to initialize preferences")
        
        // Check if locked out
        if (preferences.pinLockoutUntil > System.currentTimeMillis()) {
            val remainingSeconds = (preferences.pinLockoutUntil - System.currentTimeMillis()) / 1000
            return UnlockAttemptResult(
                false,
                "Locked out. Try again in $remainingSeconds seconds",
                preferences.failedPinAttempts,
                preferences.pinLockoutUntil
            )
        }
        
        if (inputPin == null || session.strictModePin == null) {
            return UnlockAttemptResult(false, "PIN required")
        }
        
        // Validate PIN
        return if (PinEncryptionUtil.validatePin(inputPin, session.strictModePin)) {
            // Reset failed attempts on success
            database.strictModePreferencesDao().resetPinLockout()
            UnlockAttemptResult(true, "PIN correct")
        } else {
            // Increment failed attempts
            val newAttempts = preferences.failedPinAttempts + 1
            database.strictModePreferencesDao().updateFailedAttempts(newAttempts)
            
            // Lockout after 5 failed attempts (15 minutes)
            if (newAttempts >= 5) {
                val lockoutUntil = System.currentTimeMillis() + (15 * 60 * 1000)
                database.strictModePreferencesDao().updatePinLockout(lockoutUntil)
                return UnlockAttemptResult(
                    false,
                    "Too many failed attempts. Locked out for 15 minutes",
                    newAttempts,
                    lockoutUntil
                )
            }
            
            UnlockAttemptResult(
                false,
                "Incorrect PIN. ${5 - newAttempts} attempts remaining",
                newAttempts
            )
        }
    }
    
    /**
     * Attempt PIN unlock for schedule
     */
    private suspend fun attemptSchedulePinUnlock(
        schedule: ScheduleEntity,
        inputPin: String?
    ): UnlockAttemptResult {
        ensurePreferencesExist()
        val preferences = database.strictModePreferencesDao().getPreferencesSync()
            ?: return UnlockAttemptResult(false, "No preferences found")
        
        // Check lockout (same as session)
        if (preferences.pinLockoutUntil > System.currentTimeMillis()) {
            val remainingSeconds = (preferences.pinLockoutUntil - System.currentTimeMillis()) / 1000
            return UnlockAttemptResult(
                false,
                "Locked out. Try again in $remainingSeconds seconds",
                preferences.failedPinAttempts,
                preferences.pinLockoutUntil
            )
        }
        
        if (inputPin == null || schedule.strictModePin == null) {
            return UnlockAttemptResult(false, "PIN required")
        }
        
        return if (PinEncryptionUtil.validatePin(inputPin, schedule.strictModePin)) {
            database.strictModePreferencesDao().resetPinLockout()
            UnlockAttemptResult(true, "PIN correct")
        } else {
            val newAttempts = preferences.failedPinAttempts + 1
            database.strictModePreferencesDao().updateFailedAttempts(newAttempts)
            
            if (newAttempts >= 5) {
                val lockoutUntil = System.currentTimeMillis() + (15 * 60 * 1000)
                database.strictModePreferencesDao().updatePinLockout(lockoutUntil)
                return UnlockAttemptResult(
                    false,
                    "Too many failed attempts. Locked out for 15 minutes",
                    newAttempts,
                    lockoutUntil
                )
            }
            
            UnlockAttemptResult(
                false,
                "Incorrect PIN. ${5 - newAttempts} attempts remaining",
                newAttempts
            )
        }
    }
    
    /**
     * Attempt cooldown unlock for Medium mode
     */
    private suspend fun attemptCooldownUnlock(
        session: BlockingSessionEntity
    ): UnlockAttemptResult {
        val cooldownMinutes = session.strictModeCooldownMinutes ?: 10
        
        // Check if cooldown already started
        if (session.cooldownStartedAt != null) {
            val now = System.currentTimeMillis()
            val cooldownStartTime = session.cooldownStartedAt
            val expectedCooldownEnd = cooldownStartTime + (cooldownMinutes * 60 * 1000)
            
            // TIME MANIPULATION DETECTION
            // Check if time went backwards (user changed system time back)
            if (now < cooldownStartTime) {
                android.util.Log.w("StrictMode", "Time manipulation detected: time went backwards")
                // Reset cooldown
                val updated = session.copy(
                    cooldownStartedAt = null,
                    cooldownConfirmed = false
                )
                database.blockingSessionDao().updateSession(updated)
                return UnlockAttemptResult(
                    false,
                    "Time manipulation detected. Cooldown reset. Please try again."
                )
            }
            
            // Check if time skipped forward suspiciously (>10 seconds tolerance for normal drift)
            val elapsed = now - cooldownStartTime
            val expectedElapsed = cooldownMinutes * 60 * 1000L
            if (elapsed > expectedElapsed + 10000) {
                // Time might have been changed forward
                android.util.Log.w("StrictMode", "Possible time manipulation: suspicious forward skip")
                // We'll allow it but log it - could make stricter by resetting
            }
            
            if (now >= expectedCooldownEnd) {
                // Cooldown complete
                if (session.cooldownConfirmed) {
                    return UnlockAttemptResult(true, "Cooldown complete and confirmed")
                }
                return UnlockAttemptResult(false, "Cooldown complete. Please confirm to unlock")
            } else {
                // Still in cooldown
                val remainingSeconds = (expectedCooldownEnd - now) / 1000
                return UnlockAttemptResult(
                    false,
                    "Cooldown in progress. $remainingSeconds seconds remaining"
                )
            }
        }
        
        // Start cooldown
        return UnlockAttemptResult(false, "Cooldown started. Wait $cooldownMinutes minutes")
    }
    
    /**
     * Start cooldown period for Medium mode
     * Returns true if started, false if already in progress or session not found
     */
    suspend fun startCooldown(sessionId: Long): Boolean {
        return withContext(Dispatchers.IO) {
            val session = database.blockingSessionDao().getActiveSession()
            if (session != null && session.id == sessionId) {
                if (session.cooldownStartedAt != null) {
                    return@withContext false
                }
                // Update session to start cooldown
                val updated = session.copy(
                    cooldownStartedAt = System.currentTimeMillis(),
                    cooldownConfirmed = false
                )
                database.blockingSessionDao().updateSession(updated)
                
                // Show notification
                showCooldownNotification(session.strictModeCooldownMinutes ?: 10)
                
                // Schedule completion alarm
                scheduleCooldownAlarm(
                    session.id, 
                    session.strictModeCooldownMinutes ?: 10, 
                    StrictModeReceiver.ACTION_COOLDOWN_COMPLETE
                )
                return@withContext true
            }
            false
        }
    }

    /**
     * Schedule a background alarm for cooldown completion
     */
    private fun scheduleCooldownAlarm(id: Long, minutes: Int, action: String) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, StrictModeReceiver::class.java).apply {
            this.action = action
            putExtra(StrictModeReceiver.EXTRA_ID, id)
        }
        
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            id.toInt(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val triggerAtMillis = System.currentTimeMillis() + (minutes * 60 * 1000L)
        
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent
                )
            } else {
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent
                )
            }
            Log.d("StrictMode", "Scheduled cooldown alarm for $id in $minutes minutes")
        } catch (e: SecurityException) {
            // Fallback for exact alarm permission issues on Android 14+
            alarmManager.set(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent
            )
            Log.e("StrictMode", "SecurityException scheduling exact alarm, using inexact fallback", e)
        }
    }
    
    /**
     * Show persistent notification during cooldown
     */
    private fun showCooldownNotification(cooldownMinutes: Int) {
        val notificationManager = context.getSystemService(android.content.Context.NOTIFICATION_SERVICE) 
            as android.app.NotificationManager
        
        // Create notification channel for Android O+
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            val channel = android.app.NotificationChannel(
                "strict_mode_cooldown",
                "Strict Mode Cooldown",
                android.app.NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Notifications for strict mode cooldown periods"
            }
            notificationManager.createNotificationChannel(channel)
        }
        
        val notification = android.app.Notification.Builder(
            context,
            "strict_mode_cooldown"
        )
            .setContentTitle("Cooldown in Progress")
            .setContentText("Wait $cooldownMinutes minutes to unlock blocking")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true) // Cannot be dismissed
            .setPriority(android.app.Notification.PRIORITY_DEFAULT)
            .build()
        
        notificationManager.notify(9001, notification)
    }
    
    /**
     * Confirm unlock after cooldown completes
     */
    suspend fun confirmCooldownUnlock(sessionId: Long): UnlockAttemptResult {
        return withContext(Dispatchers.IO) {
            val session = database.blockingSessionDao().getActiveSession()
            if (session == null || session.id != sessionId) {
                return@withContext UnlockAttemptResult(false, "Session not found")
            }
            
            val cooldownMinutes = session.strictModeCooldownMinutes ?: 10
            val cooldownEnd = (session.cooldownStartedAt ?: 0) + (cooldownMinutes * 60 * 1000)
            
            if (System.currentTimeMillis() >= cooldownEnd) {
                // Mark as confirmed
                val updated = session.copy(cooldownConfirmed = true)
                database.blockingSessionDao().updateSession(updated)
                
                // Cancel notification
                val notificationManager = context.getSystemService(android.content.Context.NOTIFICATION_SERVICE) 
                    as android.app.NotificationManager
                notificationManager.cancel(9001)
                
                UnlockAttemptResult(true, "Cooldown confirmed. You may now stop the session")
            } else {
                UnlockAttemptResult(false, "Cooldown not yet complete")
            }
        }
    }
    
    /**
     * Attempt cooldown unlock for schedule with Medium mode
     */
    private suspend fun attemptScheduleCooldown(
        schedule: ScheduleEntity
    ): UnlockAttemptResult {
        val cooldownMinutes = schedule.strictModeCooldownMinutes ?: 10
        
        // Check if cooldown already started
        if (schedule.cooldownStartedAt != null) {
            val now = System.currentTimeMillis()
            val cooldownStartTime = schedule.cooldownStartedAt
            val expectedCooldownEnd = cooldownStartTime + (cooldownMinutes * 60 * 1000)
            
            // TIME MANIPULATION DETECTION
            if (now < cooldownStartTime) {
                android.util.Log.w("StrictMode", "Time manipulation detected for schedule: time went backwards")
                // Reset cooldown
                val updated = schedule.copy(
                    cooldownStartedAt = null,
                    cooldownConfirmed = false
                )
                database.scheduleDao().updateSchedule(updated)
                return UnlockAttemptResult(
                    false,
                    "Time manipulation detected. Cooldown reset. Please try again."
                )
            }
            
            if (now >= expectedCooldownEnd) {
                // Cooldown complete
                if (schedule.cooldownConfirmed) {
                    return UnlockAttemptResult(true, "Cooldown complete and confirmed")
                }
                return UnlockAttemptResult(false, "Cooldown complete. Please confirm to unlock")
            } else {
                // Still in cooldown
                val remainingSeconds = (expectedCooldownEnd - now) / 1000
                return UnlockAttemptResult(
                    false,
                    "Cooldown in progress. $remainingSeconds seconds remaining"
                )
            }
        }
        
        // Start cooldown
        return UnlockAttemptResult(false, "Cooldown started. Wait $cooldownMinutes minutes")
    }
    
    /**
     * Start cooldown period for a schedule with Medium mode
     * Returns true if started, false if already in progress or schedule not found
     */
    suspend fun startScheduleCooldown(scheduleId: Long): Boolean {
        Log.d("StrictMode", "startScheduleCooldown called for scheduleId=$scheduleId")
        return withContext(Dispatchers.IO) {
            val schedule = database.scheduleDao().getScheduleById(scheduleId)
            Log.d("StrictMode", "Schedule found: ${schedule != null}, isStrictMode=${schedule?.isStrictMode}, level=${schedule?.strictModeLevel}")
            if (schedule != null) {
                if (schedule.cooldownStartedAt != null) {
                    Log.d("StrictMode", "Cooldown already in progress for schedule $scheduleId")
                    return@withContext false
                }
                // Update schedule to start cooldown
                val updated = schedule.copy(
                    cooldownStartedAt = System.currentTimeMillis(),
                    cooldownConfirmed = false
                )
                database.scheduleDao().updateSchedule(updated)
                
                // Show notification
                showCooldownNotification(schedule.strictModeCooldownMinutes ?: 10)
                
                // Schedule completion alarm
                scheduleCooldownAlarm(
                    schedule.id, 
                    schedule.strictModeCooldownMinutes ?: 10, 
                    StrictModeReceiver.ACTION_SCHEDULE_COOLDOWN_COMPLETE
                )
                return@withContext true
            }
            false
        }
    }
    
    /**
     * Confirm unlock after cooldown completes for a schedule
     */
    suspend fun confirmScheduleCooldownUnlock(scheduleId: Long): UnlockAttemptResult {
        return withContext(Dispatchers.IO) {
            val schedule = database.scheduleDao().getScheduleById(scheduleId)
            if (schedule == null) {
                return@withContext UnlockAttemptResult(false, "Schedule not found")
            }
            
            val cooldownMinutes = schedule.strictModeCooldownMinutes ?: 10
            val cooldownEnd = (schedule.cooldownStartedAt ?: 0) + (cooldownMinutes * 60 * 1000)
            
            if (System.currentTimeMillis() >= cooldownEnd) {
                // Mark as confirmed
                val updated = schedule.copy(cooldownConfirmed = true)
                database.scheduleDao().updateSchedule(updated)
                
                // Cancel notification
                val notificationManager = context.getSystemService(android.content.Context.NOTIFICATION_SERVICE) 
                    as android.app.NotificationManager
                notificationManager.cancel(9001)
                
                UnlockAttemptResult(true, "Cooldown confirmed. You may now pause the schedule")
            } else {
                UnlockAttemptResult(false, "Cooldown not yet complete")
            }
        }
    }
}
