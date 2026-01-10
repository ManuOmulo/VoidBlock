package com.voidblock.app.data.database.dao

import androidx.room.*
import com.voidblock.app.data.database.entities.FocusSessionEntity

@Dao
interface FocusSessionDao {
    @Insert
    suspend fun insertSession(session: FocusSessionEntity): Long
    
    @Update
    suspend fun updateSession(session: FocusSessionEntity)
    
    @Query("SELECT * FROM focus_sessions WHERE id = :id")
    suspend fun getSessionById(id: Long): FocusSessionEntity?
    
    @Query("UPDATE focus_sessions SET endTime = :endTime WHERE id = :id")
    suspend fun endSession(id: Long, endTime: Long)
    
    @Query("SELECT * FROM focus_sessions WHERE startTime <= :endTime AND (endTime IS NULL OR endTime >= :startTime) ORDER BY startTime DESC")
    suspend fun getOverlappingSessions(startTime: Long, endTime: Long): List<FocusSessionEntity>

    @Query("SELECT * FROM focus_sessions WHERE startTime <= :endTime AND (endTime IS NULL OR endTime >= :startTime) AND type != 'LIMIT' ORDER BY startTime DESC")
    suspend fun getOverlappingSessionsExcludingType(startTime: Long, endTime: Long): List<FocusSessionEntity>
    
    @Query("UPDATE focus_sessions SET endTime = :endTime WHERE type = :type AND endTime IS NULL")
    suspend fun endSessionsByType(type: String, endTime: Long)

    @Query("SELECT * FROM focus_sessions WHERE endTime IS NULL")
    suspend fun getActiveSessions(): List<FocusSessionEntity>
}

data class DailyFocusSummary(
    val daysSinceEpoch: Int,
    val totalMillis: Long
)
