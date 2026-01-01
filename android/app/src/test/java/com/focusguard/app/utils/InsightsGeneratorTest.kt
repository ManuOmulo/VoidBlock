package com.focusguard.app.utils

import com.focusguard.app.data.database.dao.AppUsageBreakdown
import com.focusguard.app.data.database.dao.DailyUsageSummary
import com.focusguard.app.data.database.entities.UsageLogEntity
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar

class InsightsGeneratorTest {

    private val generator = InsightsGenerator()

    @Test
    fun `test usage spike detection`() {
        // Arrange
        val breakdown = listOf(
            AppUsageBreakdown("com.instagram.android", "Instagram", 40 * 60 * 1000L, 0, 1),
            AppUsageBreakdown("com.google.android.youtube", "YouTube", 10 * 60 * 1000L, 0, 1),
            AppUsageBreakdown("com.mail.android", "Mail", 5 * 60 * 1000L, 0, 1)
        )
        // Total time = 55 mins. Insta = 40 mins (~72% > 15%)
        
        // Act
        val insights = generator.generateInsights(emptyList(), breakdown, emptyList(), 80.0)
        
        // Assert
        val spikeInsight = insights.find { it.title == "Usage Spike Detected" }
        assertTrue(spikeInsight != null)
        assertEquals("RECOMMENDATION", spikeInsight?.type)
        assertEquals("CREATE_LIMIT", spikeInsight?.actionType)
    }

    @Test
    fun `test category breakdown`() {
        // Arrange
        val breakdown = listOf(
            AppUsageBreakdown("com.instagram.android", "Instagram", 30 * 60 * 1000L, 0, 1),
            AppUsageBreakdown("com.twitter.android", "Twitter", 20 * 60 * 1000L, 0, 1),
            AppUsageBreakdown("com.microsoft.office.word", "Word", 10 * 60 * 1000L, 0, 1)
        )
        // Social = 50 mins, Total = 60 mins. Social = 83% > 40%
        
        // Act
        val insights = generator.generateInsights(emptyList(), breakdown, emptyList(), 80.0)
        
        // Assert
        val categoryInsight = insights.find { it.title.contains("Social Apps Dominating") }
        assertTrue(categoryInsight != null)
    }

    @Test
    fun `test peak distraction hour`() {
        // Arrange
        val calendar = Calendar.getInstance()
        calendar.set(Calendar.HOUR_OF_DAY, 14) // 2 PM
        val time2pm = calendar.timeInMillis
        
        val logs = listOf(
            createBlockedLog(time2pm),
            createBlockedLog(time2pm + 60000),
            createBlockedLog(time2pm + 120000), // 3 blocks at 2 PM
            createBlockedLog(time2pm - 3600000) // 1 block at 1 PM
        )
        
        // Act
        val insights = generator.generateInsights(emptyList(), emptyList(), logs, 80.0)
        
        // Assert
        val peakInsight = insights.find { it.title == "Peak Distraction Time" }
        assertTrue(peakInsight != null)
        assertTrue(peakInsight?.message?.contains("2 PM") == true)
    }

    @Test
    fun `test limit enforcement warning`() {
        // Arrange
        val now = System.currentTimeMillis()
        val logs = (0 until 12).map { i ->
            createBlockedLog(now + (i * 10000))
        }
        
        // Act
        val insights = generator.generateInsights(emptyList(), emptyList(), logs, 80.0)
        
        // Assert
        val warning = insights.find { it.title == "Persistently Distracted" }
        assertTrue(warning != null)
        assertEquals("WARNING", warning?.type)
        assertEquals("SETTINGS", warning?.actionType)
    }

    @Test
    fun `test weekend comparison`() {
        // Arrange
        // Create 7 days of data where weekends are heavy
        val summary = mutableListOf<DailyUsageSummary>()
        val calendar = Calendar.getInstance()
        
        // 5 weekdays with 1 block each
        for (i in 0 until 5) {
            // Monday to Friday
            calendar.set(Calendar.DAY_OF_WEEK, Calendar.MONDAY + i)
            summary.add(createDailySummary(calendar.timeInMillis, 1))
        }
        
        // 2 weekend days with 5 blocks each
        calendar.set(Calendar.DAY_OF_WEEK, Calendar.SATURDAY)
        summary.add(createDailySummary(calendar.timeInMillis, 5))
        calendar.set(Calendar.DAY_OF_WEEK, Calendar.SUNDAY)
        summary.add(createDailySummary(calendar.timeInMillis, 5))
        
        // Act
        val insights = generator.generateInsights(summary, emptyList(), emptyList(), 80.0)
        
        // Assert
        val weekendInsight = insights.find { it.title == "Weekend Screen Time Higher" }
        assertTrue(weekendInsight != null)
    }

    private fun createBlockedLog(time: Long): UsageLogEntity {
        return UsageLogEntity(
            packageName = "com.test",
            appName = "Test",
            startTime = time,
            endTime = time + 1000,
            durationMillis = 1000,
            wasBlocked = true
        )
    }

    private fun createDailySummary(time: Long, blockedCount: Int): DailyUsageSummary {
        return DailyUsageSummary(
            daysSinceEpoch = (time / (24 * 60 * 60 * 1000)).toInt(),
            totalTime = 0,
            sessionCount = 1,
            blockedCount = blockedCount
        )
    }
}
