package com.focusguard.app.receivers

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import com.focusguard.app.services.BlockingService
import com.focusguard.app.data.database.AppDatabase
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * Broadcast receiver that handles scheduled alarms
 * Activates/deactivates blocking based on schedule times
 */
class ScheduleAlarmReceiver : BroadcastReceiver() {
    
    companion object {
        const val ACTION_START_SCHEDULE = "com.focusguard.app.START_SCHEDULE"
        const val ACTION_END_SCHEDULE = "com.focusguard.app.END_SCHEDULE"
        const val EXTRA_SCHEDULE_ID = "schedule_id"
        const val EXTRA_DAY_OF_WEEK = "day_of_week"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        val scheduleId = intent.getLongExtra(EXTRA_SCHEDULE_ID, -1)
        val dayOfWeek = intent.getIntExtra(EXTRA_DAY_OF_WEEK, -1)
        
        if (scheduleId == -1L) {
            return
        }
        
        when (intent.action) {
            ACTION_START_SCHEDULE -> {
                activateSchedule(context, scheduleId, dayOfWeek)
            }
            ACTION_END_SCHEDULE -> {
                deactivateSchedule(context, scheduleId, dayOfWeek)
            }
        }
    }
    
    /**
     * Activate a schedule by starting the blocking service
     */
    private fun activateSchedule(context: Context, scheduleId: Long, dayOfWeek: Int) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                // Reschedule for next week if this was a recurring alarm
                if (dayOfWeek != -1) {
                    com.focusguard.app.utils.ScheduleManager(context)
                        .rescheduleAlarm(scheduleId, dayOfWeek, true)
                }

                val database = AppDatabase.getInstance(context)
                val schedule = database.scheduleDao().getScheduleById(scheduleId)
                
                // Don't start if schedule is paused
                if (schedule != null && schedule.isActive && !schedule.isPaused) {
                    // Get blocked apps for this schedule
                    val blockedApps = database.blockedAppDao()
                        .getBlockedAppsForScheduleSync(scheduleId)
                    
                    if (blockedApps.isNotEmpty()) {
                        // Start blocking service
                        val serviceIntent = Intent(context, BlockingService::class.java).apply {
                            action = BlockingService.ACTION_START_BLOCKING
                            putExtra(BlockingService.EXTRA_SCHEDULE_ID, scheduleId)
                            putStringArrayListExtra(
                                BlockingService.EXTRA_APP_PACKAGES,
                                ArrayList(blockedApps.map { it.packageName })
                            )
                        }
                        
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            context.startForegroundService(serviceIntent)
                        } else {
                            context.startService(serviceIntent)
                        }
                        
                        // Show notification
                        com.focusguard.app.utils.NotificationHelper(context).showScheduleStartNotification(schedule.name)
                    }
                } else if (schedule != null && schedule.isPaused) {
                    android.util.Log.d("ScheduleAlarmReceiver", "Schedule ${schedule.id} is paused, skipping activation")
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
    
    /**
     * Deactivate a schedule by stopping blocking for its apps
     */
    private fun deactivateSchedule(context: Context, scheduleId: Long, dayOfWeek: Int) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                // Reschedule for next week if this was a recurring alarm
                if (dayOfWeek != -1) {
                    com.focusguard.app.utils.ScheduleManager(context)
                        .rescheduleAlarm(scheduleId, dayOfWeek, false)
                }

                val database = AppDatabase.getInstance(context)
                val schedule = database.scheduleDao().getScheduleById(scheduleId)
                
                if (schedule != null) {
                    // Show notification
                    com.focusguard.app.utils.NotificationHelper(context).showScheduleEndNotification(schedule.name)
                    
                    // Get the blocked apps for this schedule
                    val scheduledApps = database.blockedAppDao()
                        .getBlockedAppsForScheduleSync(scheduleId)
                        .map { it.packageName }
                    
                    // Send stop intent with the specific schedule ID and packages to remove
                    val serviceIntent = Intent(context, BlockingService::class.java).apply {
                        action = BlockingService.ACTION_STOP_SCHEDULE
                        putExtra(BlockingService.EXTRA_SCHEDULE_ID, scheduleId)
                        putStringArrayListExtra(
                            BlockingService.EXTRA_APP_PACKAGES,
                            ArrayList(scheduledApps)
                        )
                    }
                    context.startService(serviceIntent)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
