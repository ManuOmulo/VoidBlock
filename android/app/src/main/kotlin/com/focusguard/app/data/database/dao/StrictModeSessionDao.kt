package com.focusguard.app.data.database.dao

import androidx.room.*
import com.focusguard.app.data.database.entities.StrictModeSessionEntity
import kotlinx.coroutines.flow.Flow

/**
 * Data Access Object for StrictModeSession operations
 */
@Dao
interface StrictModeSessionDao {
    
    @Query("SELECT * FROM strict_mode_sessions WHERE isActive = 1")
    fun getActiveSessions(): Flow<List<StrictModeSessionEntity>>
    
    @Query("SELECT * FROM strict_mode_sessions WHERE isActive = 1 LIMIT 1")
    suspend fun getActiveSession(): StrictModeSessionEntity?
    
    @Query("SELECT * FROM strict_mode_sessions WHERE scheduleId = :scheduleId AND isActive = 1")
    suspend fun getActiveSessionForSchedule(scheduleId: Long): StrictModeSessionEntity?
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertSession(session: StrictModeSessionEntity): Long
    
    @Update
    suspend fun updateSession(session: StrictModeSessionEntity)
    
    @Query("UPDATE strict_mode_sessions SET isActive = 0 WHERE id = :sessionId")
    suspend fun deactivateSession(sessionId: Long)
    
    @Query("UPDATE strict_mode_sessions SET isActive = 0")
    suspend fun deactivateAllSessions()
    
    @Delete
    suspend fun deleteSession(session: StrictModeSessionEntity)
    
    @Query("SELECT COUNT(*) FROM strict_mode_sessions WHERE isActive = 1")
    suspend fun getActiveSessionCount(): Int
}
