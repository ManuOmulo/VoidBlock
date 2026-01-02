package com.voidblock.app.utils

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.voidblock.app.R

/**
 * Helper class for managing notifications
 */
class NotificationHelper(private val context: Context) {

    private val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    companion object {
        const val CHANNEL_BLOCKING_SERVICE = "blocking_service_channel"
        const val CHANNEL_SCHEDULES = "schedules_channel"
        const val CHANNEL_SESSIONS = "sessions_channel"
        const val CHANNEL_INSIGHTS = "insights_channel"
        
        const val ID_SERVICE = 1001
        const val ID_SCHEDULE_START = 2001
        const val ID_SCHEDULE_END = 2002
        const val ID_SESSION_END = 3001
    }

    init {
        createChannels()
    }

    private fun createChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channels = listOf(
                NotificationChannel(
                    CHANNEL_BLOCKING_SERVICE,
                    "App Blocking Service",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Keeps the app blocking service running"
                    setShowBadge(false)
                },
                NotificationChannel(
                    CHANNEL_SCHEDULES,
                    "Schedules",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Notifications for schedule start and end"
                    enableVibration(true)
                },
                NotificationChannel(
                    CHANNEL_SESSIONS,
                    "Blocking Sessions",
                    NotificationManager.IMPORTANCE_DEFAULT
                ).apply {
                    description = "Notifications for manual blocking sessions"
                },
                NotificationChannel(
                    CHANNEL_INSIGHTS,
                    "Insights & Tips",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Daily insights and productivity tips"
                }
            )
            
            channels.forEach { notificationManager.createNotificationChannel(it) }
        }
    }

    fun getServiceNotification(message: String): android.app.Notification {
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            context.packageManager.getLaunchIntentForPackage(context.packageName),
            PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(context, CHANNEL_BLOCKING_SERVICE)
            .setContentTitle("VoidBlock Active")
            .setContentText(message)
            .setSmallIcon(R.drawable.ic_stat_notification)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    fun showScheduleStartNotification(scheduleName: String) {
        val notification = NotificationCompat.Builder(context, CHANNEL_SCHEDULES)
            .setContentTitle("Schedule Started")
            .setContentText("$scheduleName is now active. Stay focused!")
            .setSmallIcon(R.drawable.ic_stat_notification)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()
            
        notificationManager.notify(ID_SCHEDULE_START, notification)
    }

    fun showScheduleEndNotification(scheduleName: String) {
        val notification = NotificationCompat.Builder(context, CHANNEL_SCHEDULES)
            .setContentTitle("Schedule Ended")
            .setContentText("$scheduleName has ended. Great job!")
            .setSmallIcon(R.drawable.ic_stat_notification)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .build()
            
        notificationManager.notify(ID_SCHEDULE_END, notification)
    }

    fun showSessionEndNotification(durationMinutes: Int) {
        val notification = NotificationCompat.Builder(context, CHANNEL_SESSIONS)
            .setContentTitle("Session Complete")
            .setContentText("You completed a $durationMinutes minute blocking session!")
            .setSmallIcon(R.drawable.ic_stat_notification)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .build()
            
        notificationManager.notify(ID_SESSION_END, notification)
    }
}
