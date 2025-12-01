package com.focusguard.app.utils

import com.focusguard.app.data.database.entities.UsageLogEntity
import kotlin.math.min

/**
 * Calculates productivity score based on usage patterns
 * Score range: 0-100
 * 
 * Factors:
 * - Blocked attempts (fewer = higher score)
 * - Time saved from blocking
 * - Consistency of blocking sessions
 * - Usage patterns (less distraction time = higher score)
 */
class ProductivityCalculator {
    
    companion object {
        // Weights for different factors
        private const val BLOCKED_ATTEMPTS_WEIGHT = 0.35
        private const val TIME_SAVED_WEIGHT = 0.30
        private const val CONSISTENCY_WEIGHT = 0.20
        private const val USAGE_PATTERN_WEIGHT = 0.15
        
        // Reference values for normalization
        private const val MAX_ACCEPTABLE_BLOCKS_PER_DAY = 10
        private const val IDEAL_BLOCKED_TIME_PER_DAY = 2 * 60 * 60 * 1000L // 2 hours
    }
    
    /**
     * Calculate overall productivity score
     */
    fun calculateProductivityScore(
        logs: List<UsageLogEntity>,
        daysCount: Int
    ): Double {
        if (logs.isEmpty() || daysCount <= 0) return 0.0
        
        val blockedLogs = logs.filter { it.wasBlocked }
        val blockedAttempts = blockedLogs.size
        val totalBlockedTime = blockedLogs.sumOf { it.durationMillis }
        
        // 1. Blocked Attempts Score (inverse - fewer is better)
        val avgBlocksPerDay = blockedAttempts.toDouble() / daysCount
        val attemptScore = (1.0 - min(avgBlocksPerDay / MAX_ACCEPTABLE_BLOCKS_PER_DAY, 1.0)) * 100
        
        // 2. Time Saved Score (higher is better)
        val avgBlockedTimePerDay = totalBlockedTime.toDouble() / daysCount
        val timeSavedScore = min(avgBlockedTimePerDay / IDEAL_BLOCKED_TIME_PER_DAY, 1.0) * 100
        
        // 3. Consistency Score (blocking regularly is good)
        val daysWithBlocking = blockedLogs
            .groupBy { it.startTime / (24 * 60 * 60 * 1000) }
            .size
        val consistencyScore = (daysWithBlocking.toDouble() / daysCount) * 100
        
        // 4. Usage Pattern Score (declining blocked attempts over time = improvement)
        val usagePatternScore = calculateUsageTrendScore(blockedLogs)
        
        // Weighted average
        val totalScore = (
            attemptScore * BLOCKED_ATTEMPTS_WEIGHT +
            timeSavedScore * TIME_SAVED_WEIGHT +
            consistencyScore * CONSISTENCY_WEIGHT +
            usagePatternScore * USAGE_PATTERN_WEIGHT
        )
        
        return totalScore.coerceIn(0.0, 100.0)
    }
    
    /**
     * Calculate trend score - improving over time gets higher score
     */
    private fun calculateUsageTrendScore(logs: List<UsageLogEntity>): Double {
        if (logs.size < 2) return 50.0 // Neutral for insufficient data
        
        val sortedLogs = logs.sortedBy { it.startTime }
        val midpoint = sortedLogs.size / 2
        
        val firstHalfBlocks = sortedLogs.take(midpoint).size
        val secondHalfBlocks = sortedLogs.drop(midpoint).size
        
        // If blocked attempts decreased, that's good (higher score)
        val improvement = (firstHalfBlocks - secondHalfBlocks).toDouble() / midpoint
        
        // Normalize to 0-100 range
        return (50.0 + (improvement * 50)).coerceIn(0.0, 100.0)
    }
}
