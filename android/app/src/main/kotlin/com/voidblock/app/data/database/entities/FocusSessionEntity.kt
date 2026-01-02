package com.voidblock.app.data.database.entities

import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * Entity representing a focused time period (manual session, schedule, or app limit)
 */
@Entity(tableName = "focus_sessions")
data class FocusSessionEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    
    val startTime: Long,
    
    val endTime: Long? = null,
    
    val type: String, // MANUAL, SCHEDULE, LIMIT
    
    val relatedId: Long?, // ID of the manual session, schedule, or limit
    
    val durationMinutes: Int, // The target duration if applicable
    
    val createdAt: Long = System.currentTimeMillis()
)
