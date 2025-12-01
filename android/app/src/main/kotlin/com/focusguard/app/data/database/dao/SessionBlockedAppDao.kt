package com.focusguard.app.data.database.dao

import androidx.room.*
import com.focusguard.app.data.database.entities.SessionBlockedAppEntity

/**
 * Data Access Object for session blocked apps operations
 */
@Dao
interface SessionBlockedAppDao {
    
    @Insert
    suspend fun insert(app: SessionBlockedAppEntity): Long
    
    @Insert
    suspend fun insertAll(apps: List<SessionBlockedAppEntity>)
    
    @Query("SELECT * FROM session_blocked_apps WHERE sessionId = :sessionId")
    suspend fun getAppsForSession(sessionId: Long): List<SessionBlockedAppEntity>
    
    @Query("SELECT packageName FROM session_blocked_apps WHERE sessionId = :sessionId")
    suspend fun getPackageNamesForSession(sessionId: Long): List<String>
    
    @Query("DELETE FROM session_blocked_apps WHERE sessionId = :sessionId")
    suspend fun deleteAppsForSession(sessionId: Long)
}
