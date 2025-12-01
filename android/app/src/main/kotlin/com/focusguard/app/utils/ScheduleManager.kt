package com.focusguard.app.utils

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import com.focusguard.app.data.database.entities.ScheduleEntity
import com.focusguard.app.receivers.ScheduleAlarmReceiver
import org.json.JSONArray
import java.util.*

/**
 * Utility class for managing schedule alarms
 * Handles scheduling and canceling alarms using AlarmManager
 */
class ScheduleManager(private val context: Context) {
    
    private val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    
    /**
     * Schedule alarms for a schedule (start and end times)
     */
    fun scheduleAlarms(schedule: ScheduleEntity) {
        val daysOfWeek = parseDaysOfWeek(schedule.daysOfWeek)
        
        if (daysOfWeek.isEmpty()) {
            // No days selected, don't schedule
            return
        }
        
        daysOfWeek.forEach { dayOfWeek ->
            scheduleStartAlarm(schedule, dayOfWeek)
            scheduleEndAlarm(schedule, dayOfWeek)
        }
        
        // Check if schedule should be running right now
        checkAndStartIfActive(schedule, daysOfWeek)
    }
    
    /**
     * Check if schedule is currently active and start it immediately if so
     */
    private fun checkAndStartIfActive(schedule: ScheduleEntity, daysOfWeek: List<Int>) {
        // Don't start if schedule is paused
        if (schedule.isPaused) {
            android.util.Log.d("ScheduleManager", "Schedule ${schedule.id} is paused, skipping auto-start")
            return
        }
        
        val now = Calendar.getInstance()
        val currentDay = now.get(Calendar.DAY_OF_WEEK) - 1 // Convert 1-7 to 0-6
        
        if (daysOfWeek.contains(currentDay)) {
            val (startHour, startMinute) = parseTime(schedule.startTime)
            val (endHour, endMinute) = parseTime(schedule.endTime)
            
            val start = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, startHour)
                set(Calendar.MINUTE, startMinute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            
            val end = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, endHour)
                set(Calendar.MINUTE, endMinute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            
            // Handle overnight schedules (end < start)
            if (end.before(start)) {
                end.add(Calendar.DAY_OF_YEAR, 1)
            }
            
            val currentTime = System.currentTimeMillis()
            if (currentTime >= start.timeInMillis && currentTime < end.timeInMillis) {
                android.util.Log.d("ScheduleManager", "Schedule ${schedule.id} is currently active, starting immediately")
                val intent = Intent(context, ScheduleAlarmReceiver::class.java).apply {
                    action = ScheduleAlarmReceiver.ACTION_START_SCHEDULE
                    putExtra(ScheduleAlarmReceiver.EXTRA_SCHEDULE_ID, schedule.id)
                }
                context.sendBroadcast(intent)
            }
        }
    }
    
    /**
     * Cancel all alarms for a schedule
     */
    fun cancelAlarms(schedule: ScheduleEntity) {
        val daysOfWeek = parseDaysOfWeek(schedule.daysOfWeek)
        
        daysOfWeek.forEach { dayOfWeek ->
            cancelAlarm(schedule.id, dayOfWeek, isStartAlarm = true)
            cancelAlarm(schedule.id, dayOfWeek, isStartAlarm = false)
        }
    }
    
    /**
     * Schedule start alarm for a specific day
     */
    private fun scheduleStartAlarm(schedule: ScheduleEntity, dayOfWeek: Int) {
        val calendar = getCalendarForSchedule(schedule.startTime, dayOfWeek)
        
        // If the time has passed today, schedule for next week
        if (calendar.timeInMillis < System.currentTimeMillis()) {
            calendar.add(Calendar.WEEK_OF_YEAR, 1)
        }
        
        val intent = Intent(context, ScheduleAlarmReceiver::class.java).apply {
            action = ScheduleAlarmReceiver.ACTION_START_SCHEDULE
            putExtra(ScheduleAlarmReceiver.EXTRA_SCHEDULE_ID, schedule.id)
            putExtra(ScheduleAlarmReceiver.EXTRA_DAY_OF_WEEK, dayOfWeek)
        }
        
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            getRequestCode(schedule.id, dayOfWeek, true),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Schedule exact alarm
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (alarmManager.canScheduleExactAlarms()) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    calendar.timeInMillis,
                    pendingIntent
                )
            } else {
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    calendar.timeInMillis,
                    pendingIntent
                )
            }
        } else {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                calendar.timeInMillis,
                pendingIntent
            )
        }
    }
    
    /**
     * Schedule end alarm for a specific day
     */
    private fun scheduleEndAlarm(schedule: ScheduleEntity, dayOfWeek: Int) {
        val calendar = getCalendarForSchedule(schedule.endTime, dayOfWeek)
        
        // If the time has passed today, schedule for next week
        if (calendar.timeInMillis < System.currentTimeMillis()) {
            calendar.add(Calendar.WEEK_OF_YEAR, 1)
        }
        
        val intent = Intent(context, ScheduleAlarmReceiver::class.java).apply {
            action = ScheduleAlarmReceiver.ACTION_END_SCHEDULE
            putExtra(ScheduleAlarmReceiver.EXTRA_SCHEDULE_ID, schedule.id)
            putExtra(ScheduleAlarmReceiver.EXTRA_DAY_OF_WEEK, dayOfWeek)
        }
        
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            getRequestCode(schedule.id, dayOfWeek, false),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Schedule exact alarm
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (alarmManager.canScheduleExactAlarms()) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    calendar.timeInMillis,
                    pendingIntent
                )
            } else {
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    calendar.timeInMillis,
                    pendingIntent
                )
            }
        } else {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                calendar.timeInMillis,
                pendingIntent
            )
        }
    }
    
    /**
     * Cancel a specific alarm
     */
    private fun cancelAlarm(scheduleId: Long, dayOfWeek: Int, isStartAlarm: Boolean) {
        val intent = Intent(context, ScheduleAlarmReceiver::class.java)
        
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            getRequestCode(scheduleId, dayOfWeek, isStartAlarm),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()
    }
    
    /**
     * Parse days of week from JSON string
     * Format: "[0,1,2,3,4]" where 0=Sunday, 1=Monday, etc.
     */
    private fun parseDaysOfWeek(daysJson: String): List<Int> {
        return try {
            val jsonArray = JSONArray(daysJson)
            val days = mutableListOf<Int>()
            for (i in 0 until jsonArray.length()) {
                days.add(jsonArray.getInt(i))
            }
            days
        } catch (e: Exception) {
            emptyList()
        }
    }
    
    /**
     * Create calendar for a specific time and day of week
     * @param dayOfWeek in 0-6 format (0=Sunday, 6=Saturday)
     */
    private fun getCalendarForSchedule(time: String, dayOfWeek: Int): Calendar {
        val (hour, minute) = parseTime(time)
        
        // Convert 0-6 (Sun-Sat) to Calendar.DAY_OF_WEEK (1-7 where 1=Sun, 7=Sat)
        val calendarDayOfWeek = dayOfWeek + 1
        
        return Calendar.getInstance().apply {
            set(Calendar.DAY_OF_WEEK, calendarDayOfWeek)
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
    }
    
    /**
     * Parse time string (HH:mm format)
     */
    private fun parseTime(time: String): Pair<Int, Int> {
        val parts = time.split(":")
        val hour = parts.getOrNull(0)?.toIntOrNull() ?: 0
        val minute = parts.getOrNull(1)?.toIntOrNull() ?: 0
        return Pair(hour, minute)
    }
    
    /**
     * Reschedule an alarm for the next week
     */
    suspend fun rescheduleAlarm(scheduleId: Long, dayOfWeek: Int, isStartAlarm: Boolean) {
        val database = com.focusguard.app.data.database.AppDatabase.getInstance(context)
        val schedule = database.scheduleDao().getScheduleById(scheduleId)
        
        if (schedule != null && schedule.isActive) {
            if (isStartAlarm) {
                scheduleStartAlarm(schedule, dayOfWeek)
            } else {
                scheduleEndAlarm(schedule, dayOfWeek)
            }
        }
    }

    /**
     * Generate unique request code for pending intent
     * Format: scheduleId * 100 + dayOfWeek * 10 + (0 for start, 1 for end)
     */
    private fun getRequestCode(scheduleId: Long, dayOfWeek: Int, isStartAlarm: Boolean): Int {
        return (scheduleId * 100 + dayOfWeek * 10 + if (isStartAlarm) 0 else 1).toInt()
    }
}
