package com.voidblock.app.data.database.entities

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * Blocked app entity representing an app that should be blocked in a schedule
 */
@Entity(
    tableName = "blocked_apps",
    foreignKeys = [
        ForeignKey(
            entity = ScheduleEntity::class,
            parentColumns = ["id"],
            childColumns = ["scheduleId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index("scheduleId")]
)
data class BlockedAppEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    
    val scheduleId: Long,
    
    val packageName: String,
    
    val appName: String,
    
    val iconPath: String? = null,
    
    val addedAt: Long = System.currentTimeMillis()
)
