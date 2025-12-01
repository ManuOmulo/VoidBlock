package com.focusguard.app.data.database.entities

import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * Strict mode session entity to track active strict mode periods
 */
@Entity(tableName = "strict_mode_sessions")
data class StrictModeSessionEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    
    val scheduleId: Long,
    
    val scheduleName: String,
    
    val startTime: Long,
    
    val endTime: Long,
    
    val isActive: Boolean,
    
    val pin: String? = null, // Encrypted PIN for emergency unlock
    
    val lockDurationDays: Int = 30, // How long until changes allowed
    
    val unlockableAt: Long = 0 // Timestamp when modifications are allowed
)
