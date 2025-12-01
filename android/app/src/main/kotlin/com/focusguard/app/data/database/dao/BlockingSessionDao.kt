package com.focusguard.app.data.database.dao

import androidx.room.*
import com.focusguard.app.data.database.entities.BlockingSessionEntity

/**
 * Data Access Object for blocking session operations
 */
@Dao
interface BlockingSessionDao {
    
    @Insert
    suspend fun insertSession(session: BlockingSessionEntity): Long
    
    @Query("SELECT * FROM blocking_sessions WHERE isActive = 1 LIMIT 1")
    suspend fun getActiveSession(): BlockingSessionEntity?
    
    @Query("SELECT * FROM blocking_sessions WHERE id = :id")
    suspend fun getSessionById(id: Long): BlockingSessionEntity?
    
    @Query("UPDATE blocking_sessions SET isActive = 0, endTime = :endTime WHERE id = :id")
    suspend fun endSession(id: Long, endTime: Long)
    
    @Update
    suspend fun updateSession(session: BlockingSessionEntity)
    
    @Query("UPDATE blocking_sessions SET isPaused = :isPaused, pausedAt = :pausedAt, remainingMinutes = :remaining WHERE id = :id")
    suspend fun updatePauseStatus(id: Long, isPaused: Boolean, pausedAt: Long?, remaining: Int?)
    
    @Query("SELECT * FROM blocking_sessions ORDER BY startTime DESC LIMIT :limit")
    suspend fun getRecentSessions(limit: Int = 10): List<BlockingSessionEntity>
    
    @Query("DELETE FROM blocking_sessions WHERE endTime IS NOT NULL AND endTime < :timestamp")
    suspend fun deleteOldSessions(timestamp: Long)
}
