package com.focusguard.app.data.database.dao

import androidx.room.*
import com.focusguard.app.data.database.entities.UsageLogEntity
import kotlinx.coroutines.flow.Flow

/**
 * Data Access Object for UsageLog operations
 */
@Dao
interface UsageLogDao {
    
    @Query("SELECT * FROM usage_logs ORDER BY startTime DESC LIMIT :limit")
    fun getRecentLogs(limit: Int = 100): Flow<List<UsageLogEntity>>
    
    @Query("SELECT * FROM usage_logs WHERE startTime >= :startTime AND endTime <= :endTime ORDER BY startTime DESC")
    suspend fun getLogsForPeriod(startTime: Long, endTime: Long): List<UsageLogEntity>
    
    @Query("SELECT * FROM usage_logs WHERE startTime >= :startTime ORDER BY startTime DESC")
    suspend fun getLogsForPastDays(startTime: Long): List<UsageLogEntity>
    
    @Query("SELECT SUM(durationMillis) FROM usage_logs WHERE packageName = :packageName AND startTime >= :startTime")
    suspend fun getTotalUsageForApp(packageName: String, startTime: Long): Long?
    
    @Query("SELECT SUM(durationMillis) FROM usage_logs WHERE wasBlocked = 1 AND startTime >= :startTime")
    suspend fun getTotalBlockedTime(startTime: Long): Long?
    
    @Query("SELECT COUNT(*) FROM usage_logs WHERE wasBlocked = 1 AND startTime >= :startTime")
    suspend fun getBlockedAttemptsCount(startTime: Long): Int

    @Query("SELECT COUNT(*) FROM usage_logs WHERE wasBlocked = 1 AND startTime >= :startTime AND startTime <= :endTime")
    suspend fun getBlockedAttemptsCountForPeriod(startTime: Long, endTime: Long): Int
    
    @Query("SELECT COUNT(DISTINCT packageName) FROM usage_logs WHERE wasBlocked = 1 AND startTime >= :startTime")
    suspend fun getUniqueBlockedAppsCount(startTime: Long): Int
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertLog(log: UsageLogEntity): Long
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertLogs(logs: List<UsageLogEntity>)
    
    @Query("DELETE FROM usage_logs WHERE startTime < :timestamp")
    suspend fun deleteLogsOlderThan(timestamp: Long)

    @Query("DELETE FROM usage_logs")
    suspend fun clearAllLogs()
    
    @Query("SELECT packageName, SUM(durationMillis) as totalTime FROM usage_logs WHERE startTime >= :startTime GROUP BY packageName ORDER BY totalTime DESC LIMIT :limit")
    suspend fun getMostUsedApps(startTime: Long, limit: Int = 10): List<AppUsageSummary>
    
    @Query("""
        SELECT 
            packageName,
            appName,
            SUM(durationMillis) as totalTime,
            COUNT(*) as usageCount,
            SUM(CASE WHEN wasBlocked = 1 THEN 1 ELSE 0 END) as blockedCount
        FROM usage_logs 
        WHERE startTime >= :startTime
        GROUP BY packageName, appName
        ORDER BY totalTime DESC
    """)
    suspend fun getAppUsageBreakdown(startTime: Long): List<AppUsageBreakdown>
    
    @Query("""
        SELECT 
            CAST((startTime / 86400000) AS INTEGER) as daysSinceEpoch,
            SUM(durationMillis) as totalTime,
            COUNT(*) as sessionCount,
            SUM(CASE WHEN wasBlocked = 1 THEN 1 ELSE 0 END) as blockedCount
        FROM usage_logs 
        WHERE startTime >= :startTime
        GROUP BY daysSinceEpoch
        ORDER BY daysSinceEpoch DESC
    """)
    suspend fun getDailyUsageSummary(startTime: Long): List<DailyUsageSummary>
    
    @Query("""
        SELECT 
            CAST((startTime / 3600000) % 24 AS INTEGER) as hour,
            SUM(durationMillis) as totalTime,
            COUNT(*) as usageCount
        FROM usage_logs 
        WHERE startTime >= :startTime
        GROUP BY hour
        ORDER BY hour
    """)
    suspend fun getHourlyUsagePattern(startTime: Long): List<HourlyUsage>
}

data class AppUsageSummary(
    val packageName: String,
    val totalTime: Long
)

data class AppUsageBreakdown(
    val packageName: String,
    val appName: String,
    val totalTime: Long,
    val usageCount: Int,
    val blockedCount: Int
)

data class DailyUsageSummary(
    val daysSinceEpoch: Int,
    val totalTime: Long,
    val sessionCount: Int,
    val blockedCount: Int
)

data class HourlyUsage(
    val hour: Int,
    val totalTime: Long,
    val usageCount: Int
)
