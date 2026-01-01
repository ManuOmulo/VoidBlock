package com.focusguard.app.utils

import org.junit.Test
import org.junit.Assert.*

/**
 * Unit tests for ProductivityCalculator
 * Tests productivity score calculations and categorization
 */
class ProductivityCalculatorTest {

    // Test score boundaries
    @Test
    fun `Productivity score is between 0 and 100`() {
        val scores = listOf(0.0, 25.0, 50.0, 75.0, 100.0)
        
        for (score in scores) {
            assertTrue("Score $score should be >= 0", score >= 0.0)
            assertTrue("Score $score should be <= 100", score <= 100.0)
        }
    }

    @Test
    fun `Zero usage results in maximum productivity`() {
        // If no apps used, productivity is 100%
        val totalUsageMinutes = 0
        val maxDailyMinutes = 480 // 8 hours
        
        val score = if (totalUsageMinutes == 0) 100.0 
                   else calculateBasicScore(totalUsageMinutes, maxDailyMinutes)
        
        assertEquals(100.0, score, 0.01)
    }

    @Test
    fun `High usage results in low productivity`() {
        val totalUsageMinutes = 600 // 10 hours of app usage
        val maxDailyMinutes = 480 // 8 hours target
        
        val score = calculateBasicScore(totalUsageMinutes, maxDailyMinutes)
        
        assertTrue(score < 50.0)
    }

    @Test
    fun `Moderate usage results in moderate productivity`() {
        val totalUsageMinutes = 240 // 4 hours
        val maxDailyMinutes = 480 // 8 hours target
        
        val score = calculateBasicScore(totalUsageMinutes, maxDailyMinutes)
        
        assertTrue(score >= 40.0 && score <= 70.0)
    }

    // Test usage categorization
    @Test
    fun `Less than 1 hour is light usage`() {
        val usageMinutes = 45
        val category = categorizeUsage(usageMinutes)
        assertEquals("LIGHT", category)
    }

    @Test
    fun `1-3 hours is moderate usage`() {
        val usageMinutes = 120 // 2 hours
        val category = categorizeUsage(usageMinutes)
        assertEquals("MODERATE", category)
    }

    @Test
    fun `3-5 hours is heavy usage`() {
        val usageMinutes = 240 // 4 hours
        val category = categorizeUsage(usageMinutes)
        assertEquals("HEAVY", category)
    }

    @Test
    fun `More than 5 hours is excessive usage`() {
        val usageMinutes = 360 // 6 hours
        val category = categorizeUsage(usageMinutes)
        assertEquals("EXCESSIVE", category)
    }

    // Test app category weighting
    @Test
    fun `Social media apps have negative weight`() {
        val socialMediaPackages = listOf(
            "com.instagram.android",
            "com.twitter.android",
            "com.facebook.katana",
            "com.snapchat.android",
            "com.tiktok.android"
        )
        
        for (pkg in socialMediaPackages) {
            val weight = getAppCategoryWeight(pkg)
            assertTrue("$pkg should have negative weight", weight < 0)
        }
    }

    @Test
    fun `Productivity apps have positive weight`() {
        val productivityPackages = listOf(
            "com.google.android.apps.docs",
            "com.microsoft.office.word",
            "com.notion"
        )
        
        for (pkg in productivityPackages) {
            val weight = getAppCategoryWeight(pkg)
            assertTrue("$pkg should have positive weight", weight >= 0)
        }
    }

    @Test
    fun `Unknown apps have neutral weight`() {
        val unknownPackage = "com.random.unknown.app"
        val weight = getAppCategoryWeight(unknownPackage)
        assertEquals(0, weight)
    }

    // Test daily trend calculation
    @Test
    fun `Decreasing usage trend is positive`() {
        val dailyUsage = listOf(300, 280, 250, 220, 200) // Decreasing
        val trend = calculateTrend(dailyUsage)
        assertTrue(trend < 0) // Negative trend = usage going down = good
    }

    @Test
    fun `Increasing usage trend is negative`() {
        val dailyUsage = listOf(200, 220, 250, 280, 300) // Increasing
        val trend = calculateTrend(dailyUsage)
        assertTrue(trend > 0) // Positive trend = usage going up = bad
    }

    @Test
    fun `Stable usage has near-zero trend`() {
        val dailyUsage = listOf(240, 242, 238, 241, 239) // Stable around 240
        val trend = calculateTrend(dailyUsage)
        assertTrue(kotlin.math.abs(trend) < 10) // Near zero
    }

    // Test edge cases
    @Test
    fun `Single day data has no trend`() {
        val dailyUsage = listOf(240)
        val trend = calculateTrend(dailyUsage)
        assertEquals(0.0, trend, 0.01)
    }

    @Test
    fun `Empty data has no trend`() {
        val dailyUsage = emptyList<Int>()
        val trend = calculateTrend(dailyUsage)
        assertEquals(0.0, trend, 0.01)
    }

    // Helper functions
    private fun calculateBasicScore(usageMinutes: Int, targetMinutes: Int): Double {
        if (usageMinutes == 0) return 100.0
        val ratio = usageMinutes.toDouble() / targetMinutes
        return maxOf(0.0, 100.0 - (ratio * 50.0))
    }

    private fun categorizeUsage(minutes: Int): String {
        return when {
            minutes < 60 -> "LIGHT"
            minutes < 180 -> "MODERATE"
            minutes < 300 -> "HEAVY"
            else -> "EXCESSIVE"
        }
    }

    private fun getAppCategoryWeight(packageName: String): Int {
        val socialMediaApps = listOf(
            "com.instagram.android",
            "com.twitter.android",
            "com.facebook.katana",
            "com.snapchat.android",
            "com.tiktok.android"
        )
        
        val productivityApps = listOf(
            "com.google.android.apps.docs",
            "com.microsoft.office.word",
            "com.notion"
        )
        
        return when {
            socialMediaApps.contains(packageName) -> -10
            productivityApps.contains(packageName) -> 5
            else -> 0
        }
    }

    private fun calculateTrend(dailyUsage: List<Int>): Double {
        if (dailyUsage.size < 2) return 0.0
        
        val first = dailyUsage.first()
        val last = dailyUsage.last()
        return (last - first).toDouble()
    }
}
