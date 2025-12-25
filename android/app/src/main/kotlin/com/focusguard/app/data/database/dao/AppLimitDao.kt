package com.focusguard.app.data.database.dao

import androidx.room.*
import com.focusguard.app.data.database.entities.AppLimitAppEntity
import com.focusguard.app.data.database.entities.AppLimitEntity

@Dao
interface AppLimitDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertLimit(limit: AppLimitEntity): Long

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertLimitApps(apps: List<AppLimitAppEntity>)

    @Query("SELECT * FROM app_limits ORDER BY createdAt DESC")
    suspend fun getAllLimits(): List<AppLimitEntity>

    @Query("SELECT * FROM app_limits WHERE id = :id")
    suspend fun getLimitById(id: Long): AppLimitEntity?

    @Transaction
    @Query("SELECT * FROM app_limit_apps WHERE limitId = :limitId")
    suspend fun getAppsForLimit(limitId: Long): List<AppLimitAppEntity>

    @Update
    suspend fun updateLimit(limit: AppLimitEntity)

    @Delete
    suspend fun deleteLimit(limit: AppLimitEntity)

    @Query("UPDATE app_limits SET isActive = :isActive WHERE id = :id")
    suspend fun toggleLimit(id: Long, isActive: Boolean)

    @Query("UPDATE app_limits SET unlocked_until_midnight = :unlocked WHERE id = :id")
    suspend fun setUnlockedStatus(id: Long, unlocked: Boolean)

    @Query("UPDATE app_limits SET last_unlocked_at = :timestamp WHERE id = :id")
    suspend fun updateLastUnlockedAt(id: Long, timestamp: Long)

    @Query("SELECT * FROM app_limits WHERE isActive = 1")
    suspend fun getActiveLimits(): List<AppLimitEntity>

    @Query("SELECT packageName FROM app_limit_apps WHERE limitId = :limitId")
    suspend fun getPackageNamesForLimit(limitId: Long): List<String>

    @Query("SELECT limitId FROM app_limit_apps WHERE packageName = :packageName")
    suspend fun getLimitIdForPackage(packageName: String): Long?

    @Query("DELETE FROM app_limit_apps WHERE limitId = :limitId")
    suspend fun deleteAppsForLimit(limitId: Long)
}
