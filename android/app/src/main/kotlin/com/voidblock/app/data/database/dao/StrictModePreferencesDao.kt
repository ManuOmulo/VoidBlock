package com.voidblock.app.data.database.dao

import androidx.room.*
import com.voidblock.app.data.database.entities.StrictModePreferencesEntity

/**
 * Data Access Object for StrictModePreferences
 * Handles CRUD operations for strict mode preferences
 */
@Dao
interface StrictModePreferencesDao {
    
    @Query("SELECT * FROM strict_mode_preferences WHERE id = 1")
    suspend fun getPreferences(): StrictModePreferencesEntity?
    
    @Query("SELECT * FROM strict_mode_preferences WHERE id = 1")
    fun getPreferencesSync(): StrictModePreferencesEntity?
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertOrUpdate(preferences: StrictModePreferencesEntity)
    
    @Query("UPDATE strict_mode_preferences SET default_level = :level WHERE id = 1")
    suspend fun updateDefaultLevel(level: String)
    
    @Query("UPDATE strict_mode_preferences SET default_pin = :pin WHERE id = 1")
    suspend fun updateDefaultPin(pin: String?)
    
    @Query("UPDATE strict_mode_preferences SET default_cooldown_minutes = :minutes WHERE id = 1")
    suspend fun updateDefaultCooldown(minutes: Int)
    
    @Query("UPDATE strict_mode_preferences SET failed_pin_attempts = :attempts WHERE id = 1")
    suspend fun updateFailedAttempts(attempts: Int)
    
    @Query("UPDATE strict_mode_preferences SET pin_lockout_until = :timestamp WHERE id = 1")
    suspend fun updatePinLockout(timestamp: Long)
    
    @Query("UPDATE strict_mode_preferences SET failed_pin_attempts = 0, pin_lockout_until = 0 WHERE id = 1")
    suspend fun resetPinLockout()
}
