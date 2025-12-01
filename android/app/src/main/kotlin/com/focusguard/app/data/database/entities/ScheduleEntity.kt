package com.focusguard.app.data.database.entities

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * Entity representing a scheduled blocking period
 * Defines when apps should be automatically blocked
 */
@Entity(tableName = "schedules")
data class ScheduleEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val name: String,
    val startTime: String, // Format: "HH:mm"
    val endTime: String,   // Format: "HH:mm"
    val daysOfWeek: String, // JSON array: "[0,1,2]" (0=Sunday, 6=Saturday)
    val isActive: Boolean,
    val isStrictMode: Boolean,
    val motivationalMessage: String?,
    val notificationsEnabled: Boolean = true,
    val createdAt: Long = System.currentTimeMillis(),
    
    // Pause/Resume functionality
    @ColumnInfo(name = "is_paused")
    val isPaused: Boolean = false,
    
    // Strict Mode fields
    @ColumnInfo(name = "strict_mode_level", defaultValue = "NONE")
    val strictModeLevel: String = "NONE", // NONE, EASY, MEDIUM, HARD
    
    @ColumnInfo(name = "strict_mode_pin")
    val strictModePin: String? = null, // Encrypted PIN for Easy mode
    
    @ColumnInfo(name = "strict_mode_cooldown_minutes")
    val strictModeCooldownMinutes: Int? = null // Cooldown duration for Medium mode
)
