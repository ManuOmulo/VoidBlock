package com.focusguard.app.data.database.dao

import androidx.room.*
import com.focusguard.app.data.database.entities.BlockedAppEntity
import kotlinx.coroutines.flow.Flow

/**
 * Data Access Object for BlockedApp operations
 */
@Dao
interface BlockedAppDao {
    
    @Query("SELECT * FROM blocked_apps WHERE scheduleId = :scheduleId")
    fun getBlockedAppsForSchedule(scheduleId: Long): Flow<List<BlockedAppEntity>>
    
    @Query("SELECT * FROM blocked_apps WHERE scheduleId = :scheduleId")
    suspend fun getBlockedAppsForScheduleSync(scheduleId: Long): List<BlockedAppEntity>
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertBlockedApp(app: BlockedAppEntity): Long
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertBlockedApps(apps: List<BlockedAppEntity>)
    
    @Delete
    suspend fun deleteBlockedApp(app: BlockedAppEntity)
    
    @Query("DELETE FROM blocked_apps WHERE scheduleId = :scheduleId")
    suspend fun deleteAllBlockedAppsForSchedule(scheduleId: Long)
    
    @Query("DELETE FROM blocked_apps WHERE scheduleId = :scheduleId AND packageName = :packageName")
    suspend fun deleteBlockedAppByPackage(scheduleId: Long, packageName: String)
    
    @Query("SELECT packageName FROM blocked_apps WHERE scheduleId IN (SELECT id FROM schedules WHERE isActive = 1)")
    suspend fun getAllActiveBlockedPackages(): List<String>
}
