package com.voidblock.app.data.database.entities

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * Entity representing an app usage limit
 */
@Entity(tableName = "app_limits")
data class AppLimitEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,
    val name: String,
    val limitMinutes: Int,
    val isActive: Boolean = true,
    val createdAt: Long = System.currentTimeMillis(),
    
    // Strict Mode fields
    @ColumnInfo(name = "is_strict_mode")
    val isStrictMode: Boolean = false,
    
    @ColumnInfo(name = "strict_mode_level", defaultValue = "NONE")
    val strictModeLevel: String = "NONE", // NONE, EASY, MEDIUM, HARD
    
    @ColumnInfo(name = "strict_mode_pin")
    val strictModePin: String? = null, // Encrypted PIN for Easy mode
    
    @ColumnInfo(name = "strict_mode_cooldown_minutes")
    val strictModeCooldownMinutes: Int? = null, // Cooldown duration for Medium mode
    
    @ColumnInfo(name = "hard_mode_duration_minutes")
    val hardModeDurationMinutes: Int? = null, // Duration for Hard mode in minutes
    
    @ColumnInfo(name = "hard_mode_ends_at")
    val hardModeEndsAt: Long? = null, // Expiration timestamp for Hard mode
    
    @ColumnInfo(name = "last_unlocked_at")
    val lastUnlockedAt: Long? = null, // When strict mode was last unlocked
    
    @ColumnInfo(name = "unlocked_until_midnight")
    val unlockedUntilMidnight: Boolean = false // Whether it remains unlocked until midnight
)
