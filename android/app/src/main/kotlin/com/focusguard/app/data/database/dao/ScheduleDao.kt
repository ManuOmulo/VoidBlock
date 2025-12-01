package com.focusguard.app.data.database.dao

import androidx.room.*
import com.focusguard.app.data.database.entities.ScheduleEntity
import kotlinx.coroutines.flow.Flow

/**
 * Data Access Object for Schedule operations
 */
@Dao
interface ScheduleDao {
    
    @Query("SELECT * FROM schedules ORDER BY createdAt DESC")
    fun getAllSchedules(): Flow<List<ScheduleEntity>>
    
    @Query("SELECT * FROM schedules ORDER BY createdAt DESC")
    suspend fun getAllSchedulesSync(): List<ScheduleEntity>
    
    @Query("SELECT * FROM schedules WHERE id = :scheduleId")
    suspend fun getScheduleById(scheduleId: Long): ScheduleEntity?
    
    @Query("SELECT * FROM schedules WHERE isActive = 1")
    fun getActiveSchedules(): Flow<List<ScheduleEntity>>
    
    @Query("SELECT * FROM schedules WHERE isActive = 1")
    suspend fun getActiveSchedulesSync(): List<ScheduleEntity>
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertSchedule(schedule: ScheduleEntity): Long
    
    @Update
    suspend fun updateSchedule(schedule: ScheduleEntity)
    
    @Delete
    suspend fun deleteSchedule(schedule: ScheduleEntity)
    
    @Query("DELETE FROM schedules WHERE id = :scheduleId")
    suspend fun deleteScheduleById(scheduleId: Long)
    
    @Query("UPDATE schedules SET isActive = :isActive WHERE id = :scheduleId")
    suspend fun setScheduleActive(scheduleId: Long, isActive: Boolean)
    
    @Query("SELECT COUNT(*) FROM schedules WHERE isActive = 1")
    suspend fun getActiveScheduleCount(): Int
}
