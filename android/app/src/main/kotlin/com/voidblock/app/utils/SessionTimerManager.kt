package com.voidblock.app.utils

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import com.voidblock.app.receivers.BlockingSessionReceiver

/**
 * Manages timers for blocking sessions using AlarmManager
 * Schedules automatic session termination based on duration
 */
class SessionTimerManager(private val context: Context) {
    
    private val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    
    companion object {
        const val ACTION_STOP_SESSION = "com.voidblock.app.ACTION_STOP_SESSION"
    }
    
    /**
     * Schedule automatic session stop after specified duration
     */
    fun scheduleAutoStop(sessionId: Long, durationMinutes: Int) {
        val triggerTime = System.currentTimeMillis() + (durationMinutes * 60 * 1000L)
        
        val intent = Intent(context, BlockingSessionReceiver::class.java).apply {
            action = ACTION_STOP_SESSION
            putExtra("session_id", sessionId)
        }
        
        val pendingIntent = getPendingIntent(sessionId, intent) ?: return
        
        // Use exact alarm for critical timing
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerTime,
                pendingIntent
            )
        } else {
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP,
                triggerTime,
                pendingIntent
            )
        }
    }

    
    /**
     * Cancel scheduled auto-stop for a session
     */
    fun cancelAutoStop(sessionId: Long) {
        val intent = Intent(context, BlockingSessionReceiver::class.java).apply {
            action = ACTION_STOP_SESSION
        }
        
        val pendingIntent = getPendingIntent(sessionId, intent, PendingIntent.FLAG_NO_CREATE)
        pendingIntent?.let {
            alarmManager.cancel(it)
            it.cancel()
        }
    }
    
    /**
     * Get or create PendingIntent for session
     */
    private fun getPendingIntent(
        sessionId: Long,
        intent: Intent,
        flags: Int = PendingIntent.FLAG_UPDATE_CURRENT
    ): PendingIntent? {
        val finalFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags or PendingIntent.FLAG_IMMUTABLE
        } else {
            flags
        }
        
        return PendingIntent.getBroadcast(
            context,
            sessionId.toInt(),
            intent,
            finalFlags
        )
    }

}
