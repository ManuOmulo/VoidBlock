package com.voidblock.app.receivers

import android.app.Notification
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Broadcast receiver for strict mode events (cooldown completion)
 */
class StrictModeReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_COOLDOWN_COMPLETE = "com.voidblock.app.COOLDOWN_COMPLETE"
        const val ACTION_SCHEDULE_COOLDOWN_COMPLETE = "com.voidblock.app.SCHEDULE_COOLDOWN_COMPLETE"
        const val EXTRA_ID = "id"
        const val NOTIFICATION_ID = 9001
    }

    override fun onReceive(context: Context, intent: Intent?) {
        if (intent == null) return
        
        val id = intent.getLongExtra(EXTRA_ID, -1)
        if (id == -1L) return

        when (intent.action) {
            ACTION_COOLDOWN_COMPLETE -> {
                showCooldownCompleteNotification(
                    context, 
                    "Session cooldown complete. You can now stop the focus session."
                )
            }
            ACTION_SCHEDULE_COOLDOWN_COMPLETE -> {
                showCooldownCompleteNotification(
                    context, 
                    "Schedule cooldown complete. You can now edit the schedule settings."
                )
            }
        }
    }

    private fun showCooldownCompleteNotification(context: Context, message: String) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, "strict_mode_cooldown")
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

        val notification = builder
            .setContentTitle("Cooldown Finished")
            .setContentText(message)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setAutoCancel(true)
            .setOngoing(false) // This is the key: make it dismissible now
            .setPriority(Notification.PRIORITY_HIGH)
            .build()

        notificationManager.notify(NOTIFICATION_ID, notification)
    }
}
