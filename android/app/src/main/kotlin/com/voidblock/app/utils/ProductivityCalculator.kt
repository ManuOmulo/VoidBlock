package com.voidblock.app.utils

import com.voidblock.app.data.database.entities.UsageLogEntity
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
     * Data class for detailed score breakdown
     */
    data class ScoreBreakdown(
        val totalScore: Double,
        val blockedAttemptsScore: Double,
        val timeSavedScore: Double,
        val focusRatioScore: Double,
        val consistencyScore: Double,
        val usagePatternScore: Double,
        val weights: Map<String, Double>
    )
    
    /**
     * Calculate overall productivity score
     */
    fun calculateProductivityScore(
        blockedAttempts: Int,
        totalBlockedTime: Long,
        totalUsageTime: Long,
        daysCount: Int
    ): Double {
        if (daysCount <= 0) return 0.0

        // 1. Blocked Attempts Score (inverse - fewer is better)
        val avgBlocksPerDay = blockedAttempts.toDouble() / daysCount
        val attemptScore = (1.0 - min(avgBlocksPerDay / MAX_ACCEPTABLE_BLOCKS_PER_DAY, 1.0)) * 100

        // 2. Time Saved Score (higher is better)
        val avgBlockedTimePerDay = totalBlockedTime.toDouble() / daysCount
        val timeSavedScore = min(avgBlockedTimePerDay / IDEAL_BLOCKED_TIME_PER_DAY, 1.0) * 100

        // 3. Focus Ratio Score (unblocked usage vs blocked attempts)
        val focusRatioScore = if (totalUsageTime > 0) {
            val totalSavedMinutes = totalBlockedTime / 60000.0
            val totalUsageMinutes = totalUsageTime / 60000.0
            (totalSavedMinutes / (totalSavedMinutes + totalUsageMinutes)) * 100
        } else {
            0.0
        }

        // Weighted average
        val totalScore = (
            attemptScore * BLOCKED_ATTEMPTS_WEIGHT +
            timeSavedScore * TIME_SAVED_WEIGHT +
            focusRatioScore * (CONSISTENCY_WEIGHT + USAGE_PATTERN_WEIGHT) // Consolidate simpler metrics
        )

        return totalScore.coerceIn(0.0, 100.0)
    }

    /**
     * Calculate productivity score with detailed breakdown
     */
    fun calculateProductivityScoreWithBreakdown(
        blockedAttempts: Int,
        totalBlockedTime: Long,
        totalUsageTime: Long,
        daysCount: Int
    ): ScoreBreakdown {
        if (daysCount <= 0) {
            return ScoreBreakdown(
                totalScore = 0.0,
                blockedAttemptsScore = 0.0,
                timeSavedScore = 0.0,
                focusRatioScore = 0.0,
                consistencyScore = 0.0,
                usagePatternScore = 0.0,
                weights = emptyMap()
            )
        }

        // 1. Blocked Attempts Score (inverse - fewer is better)
        val avgBlocksPerDay = blockedAttempts.toDouble() / daysCount
        val attemptScore = (1.0 - min(avgBlocksPerDay / MAX_ACCEPTABLE_BLOCKS_PER_DAY, 1.0)) * 100

        // 2. Time Saved Score (higher is better)
        val avgBlockedTimePerDay = totalBlockedTime.toDouble() / daysCount
        val timeSavedScore = min(avgBlockedTimePerDay / IDEAL_BLOCKED_TIME_PER_DAY, 1.0) * 100

        // 3. Focus Ratio Score (unblocked usage vs blocked attempts)
        val focusRatioScore = if (totalUsageTime > 0) {
            val totalSavedMinutes = totalBlockedTime / 60000.0
            val totalUsageMinutes = totalUsageTime / 60000.0
            (totalSavedMinutes / (totalSavedMinutes + totalUsageMinutes)) * 100
        } else {
            0.0
        }

        // 4. Consistency Score (placeholder - would need actual consistency data)
        val consistencyScore = 50.0

        // 5. Usage Pattern Score (placeholder - would need trend analysis)
        val usagePatternScore = 50.0

        val weights = mapOf(
            "blockedAttempts" to BLOCKED_ATTEMPTS_WEIGHT,
            "timeSaved" to TIME_SAVED_WEIGHT,
            "focusRatio" to (CONSISTENCY_WEIGHT + USAGE_PATTERN_WEIGHT),
            "consistency" to CONSISTENCY_WEIGHT,
            "usagePattern" to USAGE_PATTERN_WEIGHT
        )

        // Weighted average
        val totalScore = (
            attemptScore * BLOCKED_ATTEMPTS_WEIGHT +
            timeSavedScore * TIME_SAVED_WEIGHT +
            focusRatioScore * (CONSISTENCY_WEIGHT + USAGE_PATTERN_WEIGHT)
        ).coerceIn(0.0, 100.0)

        return ScoreBreakdown(
            totalScore = totalScore,
            blockedAttemptsScore = attemptScore,
            timeSavedScore = timeSavedScore,
            focusRatioScore = focusRatioScore,
            consistencyScore = consistencyScore,
            usagePatternScore = usagePatternScore,
            weights = weights
        )
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
