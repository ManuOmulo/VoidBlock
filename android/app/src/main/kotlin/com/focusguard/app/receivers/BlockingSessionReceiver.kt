package com.focusguard.app.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.focusguard.app.data.database.AppDatabase
import com.focusguard.app.services.BlockingService
import com.focusguard.app.utils.SessionTimerManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * Broadcast receiver for blocking session timer events
 * Handles automatic session termination when timer expires
 */
class BlockingSessionReceiver : BroadcastReceiver() {
    
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            SessionTimerManager.ACTION_STOP_SESSION -> {
                val sessionId = intent.getLongExtra("session_id", -1)
                if (sessionId != -1L) {
                    stopSession(context, sessionId)
                }
            }
        }
    }
    
    /**
     * Stop a blocking session and end the blocking service
     */
    private fun stopSession(context: Context, sessionId: Long) {
        val scope = CoroutineScope(Dispatchers.IO)
        scope.launch {
            try {
                val database = AppDatabase.getInstance(context)
                val session = database.blockingSessionDao().getSessionById(sessionId)
                
                if (session != null && session.isActive) {
                    // Mark session as ended
                    database.blockingSessionDao().endSession(
                        sessionId,
                        System.currentTimeMillis()
                    )
                    
                    // Stop the blocking service
                    val serviceIntent = Intent(context, BlockingService::class.java).apply {
                        action = BlockingService.ACTION_STOP_BLOCKING
                        putExtra("session_id", sessionId)
                    }
                    context.startService(serviceIntent)
                    
                    // Show notification
                    val durationMinutes = ((System.currentTimeMillis() - session.startTime) / 60000).toInt()
                    com.focusguard.app.utils.NotificationHelper(context).showSessionEndNotification(durationMinutes)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
