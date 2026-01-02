package com.voidblock.app.data.database.entities

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * Entity representing a manual blocking session
 * Tracks active, paused, and completed blocking sessions
 */
@Entity(tableName = "blocking_sessions")
data class BlockingSessionEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val startTime: Long,
    val endTime: Long?,
    val durationMinutes: Int,
    val isActive: Boolean,
    val isPaused: Boolean = false,
    val isStrictMode: Boolean,
    val motivationalMessage: String?,
    val pausedAt: Long? = null,
    val accumulatedPausedMs: Long = 0,
    val remainingMinutes: Int? = null,
    val createdAt: Long = System.currentTimeMillis(),
    
    // Strict Mode fields
    @ColumnInfo(name = "strict_mode_level", defaultValue = "NONE")
    val strictModeLevel: String = "NONE", // NONE, EASY, MEDIUM, HARD
    
    @ColumnInfo(name = "strict_mode_pin")
    val strictModePin: String? = null, // Encrypted PIN for Easy mode
    
    @ColumnInfo(name = "strict_mode_cooldown_minutes")
    val strictModeCooldownMinutes: Int? = null, // Cooldown duration for Medium mode
    
    @ColumnInfo(name = "cooldown_started_at")
    val cooldownStartedAt: Long? = null, // When cooldown was initiated
    
    @ColumnInfo(name = "cooldown_confirmed")
    val cooldownConfirmed: Boolean = false // Whether user confirmed after cooldown
)
