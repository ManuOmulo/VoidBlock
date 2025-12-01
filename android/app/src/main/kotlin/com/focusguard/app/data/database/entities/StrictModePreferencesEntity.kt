package com.focusguard.app.data.database.entities

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * Entity for storing user's default strict mode preferences
 * This is a singleton table (id=1) for app-wide defaults
 */
@Entity(tableName = "strict_mode_preferences")
data class StrictModePreferencesEntity(
    @PrimaryKey
    val id: Int = 1, // Singleton - always 1
    
    @ColumnInfo(name = "default_level")
    val defaultLevel: String = "NONE", // NONE, EASY, MEDIUM, HARD
    
    @ColumnInfo(name = "default_pin")
    val defaultPin: String? = null, // Encrypted PIN for Easy mode
    
    @ColumnInfo(name = "default_cooldown_minutes")
    val defaultCooldownMinutes: Int = 10, // Default: 10 minutes
    
    @ColumnInfo(name = "emergency_unlock_enabled")
    val emergencyUnlockEnabled: Boolean = true,
    
    @ColumnInfo(name = "pin_lockout_until")
    val pinLockoutUntil: Long = 0, // Timestamp when PIN lockout expires
    
    @ColumnInfo(name = "failed_pin_attempts")
    val failedPinAttempts: Int = 0
)
