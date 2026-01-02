package com.voidblock.app.data.database.entities

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * Usage log entity for tracking app usage and blocking history
 */
@Entity(
    tableName = "usage_logs",
    indices = [Index("packageName"), Index("startTime")]
)
data class UsageLogEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    
    val packageName: String,
    
    val appName: String,
    
    val startTime: Long,
    
    val endTime: Long,
    
    val durationMillis: Long,
    
    val wasBlocked: Boolean,
    
    val scheduleName: String? = null
)
