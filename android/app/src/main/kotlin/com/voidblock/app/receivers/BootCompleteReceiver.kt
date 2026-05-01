package com.voidblock.app.receivers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.voidblock.app.data.database.AppDatabase
import com.voidblock.app.utils.ScheduleManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * Broadcast receiver that handles device boot completion
 * Restores all scheduled alarms after device restart
 */
class BootCompleteReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            restoreSchedules(context)
        }
    }

    /**
     * Restore all active schedules after device boot
     */
    private fun restoreSchedules(context: Context) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val database = AppDatabase.getInstance(context)
                val scheduleManager = ScheduleManager(context)

                // Get all active schedules
                val schedules = database.scheduleDao().getActiveSchedulesSync()

                schedules.forEach { schedule ->
                    // Re-schedule alarms for each active schedule
                    scheduleManager.scheduleAlarms(schedule)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
