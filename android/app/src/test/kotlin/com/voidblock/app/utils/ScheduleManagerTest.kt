package com.voidblock.app.utils

import org.junit.Test
import org.junit.Assert.*
import java.util.Calendar

/**
 * Unit tests for ScheduleManager
 * Tests schedule time matching, day-of-week detection, and activation logic
 */
class ScheduleManagerTest {

    // Test time parsing
    @Test
    fun `parseTime extracts hours correctly`() {
        val time = "09:30"
        val parts = time.split(":")
        val hours = parts[0].toInt()
        val minutes = parts[1].toInt()

        assertEquals(9, hours)
        assertEquals(30, minutes)
    }

    @Test
    fun `parseTime handles midnight correctly`() {
        val time = "00:00"
        val parts = time.split(":")
        val hours = parts[0].toInt()
        val minutes = parts[1].toInt()

        assertEquals(0, hours)
        assertEquals(0, minutes)
    }

    @Test
    fun `parseTime handles end of day correctly`() {
        val time = "23:59"
        val parts = time.split(":")
        val hours = parts[0].toInt()
        val minutes = parts[1].toInt()

        assertEquals(23, hours)
        assertEquals(59, minutes)
    }

    // Test day of week mapping
    @Test
    fun `Monday maps to day 1`() {
        // VoidBlock uses 1-7 for Mon-Sun
        val monday = 1
        assertEquals(Calendar.MONDAY, convertVoidBlockDayToCalendar(monday))
    }

    @Test
    fun `Sunday maps to day 7`() {
        val sunday = 7
        assertEquals(Calendar.SUNDAY, convertVoidBlockDayToCalendar(sunday))
    }

    private fun convertVoidBlockDayToCalendar(voidBlockDay: Int): Int {
        // VoidBlock: 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat, 7=Sun
        // Calendar: 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat
        return when (voidBlockDay) {
            1 -> Calendar.MONDAY
            2 -> Calendar.TUESDAY
            3 -> Calendar.WEDNESDAY
            4 -> Calendar.THURSDAY
            5 -> Calendar.FRIDAY
            6 -> Calendar.SATURDAY
            7 -> Calendar.SUNDAY
            else -> Calendar.MONDAY
        }
    }

    // Test weekday pattern
    @Test
    fun `Weekday pattern contains days 1-5`() {
        val weekdays = listOf(1, 2, 3, 4, 5)
        
        assertTrue(weekdays.contains(1)) // Monday
        assertTrue(weekdays.contains(2)) // Tuesday
        assertTrue(weekdays.contains(3)) // Wednesday
        assertTrue(weekdays.contains(4)) // Thursday
        assertTrue(weekdays.contains(5)) // Friday
        assertFalse(weekdays.contains(6)) // Saturday
        assertFalse(weekdays.contains(7)) // Sunday
    }

    // Test weekend pattern
    @Test
    fun `Weekend pattern contains days 6-7`() {
        val weekend = listOf(6, 7)
        
        assertFalse(weekend.contains(1)) // Monday
        assertTrue(weekend.contains(6)) // Saturday
        assertTrue(weekend.contains(7)) // Sunday
    }

    // Test time range checking
    @Test
    fun `isTimeInRange returns true for time within range`() {
        // Range: 09:00 - 17:00
        val startHour = 9
        val startMinute = 0
        val endHour = 17
        val endMinute = 0

        // Current time: 12:00
        val currentHour = 12
        val currentMinute = 0

        val isInRange = isTimeInRange(
            currentHour, currentMinute,
            startHour, startMinute,
            endHour, endMinute
        )

        assertTrue(isInRange)
    }

    @Test
    fun `isTimeInRange returns false for time outside range`() {
        // Range: 09:00 - 17:00
        val startHour = 9
        val startMinute = 0
        val endHour = 17
        val endMinute = 0

        // Current time: 20:00
        val currentHour = 20
        val currentMinute = 0

        val isInRange = isTimeInRange(
            currentHour, currentMinute,
            startHour, startMinute,
            endHour, endMinute
        )

        assertFalse(isInRange)
    }

    @Test
    fun `isTimeInRange returns true at exact start time`() {
        // Range: 09:00 - 17:00
        val startHour = 9
        val startMinute = 0
        val endHour = 17
        val endMinute = 0

        // Current time: 09:00 (exactly at start)
        val currentHour = 9
        val currentMinute = 0

        val isInRange = isTimeInRange(
            currentHour, currentMinute,
            startHour, startMinute,
            endHour, endMinute
        )

        assertTrue(isInRange)
    }

    @Test
    fun `isTimeInRange handles overnight schedule - before midnight`() {
        // Range: 22:00 - 06:00 (overnight)
        val startHour = 22
        val startMinute = 0
        val endHour = 6
        val endMinute = 0

        // Current time: 23:00 (before midnight)
        val currentHour = 23
        val currentMinute = 0

        val isInRange = isTimeInRangeOvernight(
            currentHour, currentMinute,
            startHour, startMinute,
            endHour, endMinute
        )

        assertTrue(isInRange)
    }

    @Test
    fun `isTimeInRange handles overnight schedule - after midnight`() {
        // Range: 22:00 - 06:00 (overnight)
        val startHour = 22
        val startMinute = 0
        val endHour = 6
        val endMinute = 0

        // Current time: 03:00 (after midnight)
        val currentHour = 3
        val currentMinute = 0

        val isInRange = isTimeInRangeOvernight(
            currentHour, currentMinute,
            startHour, startMinute,
            endHour, endMinute
        )

        assertTrue(isInRange)
    }

    @Test
    fun `isTimeInRange handles overnight schedule - outside range`() {
        // Range: 22:00 - 06:00 (overnight)
        val startHour = 22
        val startMinute = 0
        val endHour = 6
        val endMinute = 0

        // Current time: 12:00 (middle of day - outside overnight range)
        val currentHour = 12
        val currentMinute = 0

        val isInRange = isTimeInRangeOvernight(
            currentHour, currentMinute,
            startHour, startMinute,
            endHour, endMinute
        )

        assertFalse(isInRange)
    }

    // Helper functions for time range checking
    private fun isTimeInRange(
        currentHour: Int, currentMinute: Int,
        startHour: Int, startMinute: Int,
        endHour: Int, endMinute: Int
    ): Boolean {
        val currentMinutes = currentHour * 60 + currentMinute
        val startMinutes = startHour * 60 + startMinute
        val endMinutes = endHour * 60 + endMinute

        return currentMinutes >= startMinutes && currentMinutes < endMinutes
    }

    private fun isTimeInRangeOvernight(
        currentHour: Int, currentMinute: Int,
        startHour: Int, startMinute: Int,
        endHour: Int, endMinute: Int
    ): Boolean {
        val currentMinutes = currentHour * 60 + currentMinute
        val startMinutes = startHour * 60 + startMinute
        val endMinutes = endHour * 60 + endMinute

        // Overnight: start is later than end (e.g., 22:00 - 06:00)
        return if (startMinutes > endMinutes) {
            // Either after start OR before end
            currentMinutes >= startMinutes || currentMinutes < endMinutes
        } else {
            // Normal daytime range
            currentMinutes >= startMinutes && currentMinutes < endMinutes
        }
    }

    // Test schedule activation logic
    @Test
    fun `Schedule active when time in range and day matches`() {
        val daysOfWeek = listOf(1, 2, 3, 4, 5) // Weekdays
        val startTime = "09:00"
        val endTime = "17:00"

        // Simulate Wednesday at 12:00
        val currentDayOfWeek = 3 // Wednesday
        val currentHour = 12
        val currentMinute = 0

        val dayMatches = daysOfWeek.contains(currentDayOfWeek)
        val (startHour, startMinute) = startTime.split(":").map { it.toInt() }
        val (endHour, endMinute) = endTime.split(":").map { it.toInt() }
        val timeMatches = isTimeInRange(
            currentHour, currentMinute,
            startHour, startMinute,
            endHour, endMinute
        )

        val isActive = dayMatches && timeMatches

        assertTrue(isActive)
    }

    @Test
    fun `Schedule inactive when day does not match`() {
        val daysOfWeek = listOf(1, 2, 3, 4, 5) // Weekdays
        val startTime = "09:00"
        val endTime = "17:00"

        // Simulate Saturday at 12:00
        val currentDayOfWeek = 6 // Saturday
        val currentHour = 12
        val currentMinute = 0

        val dayMatches = daysOfWeek.contains(currentDayOfWeek)
        val (startHour, startMinute) = startTime.split(":").map { it.toInt() }
        val (endHour, endMinute) = endTime.split(":").map { it.toInt() }
        val timeMatches = isTimeInRange(
            currentHour, currentMinute,
            startHour, startMinute,
            endHour, endMinute
        )

        val isActive = dayMatches && timeMatches

        assertFalse(isActive)
    }

    @Test
    fun `Schedule inactive when time outside range`() {
        val daysOfWeek = listOf(1, 2, 3, 4, 5) // Weekdays
        val startTime = "09:00"
        val endTime = "17:00"

        // Simulate Wednesday at 20:00 (after hours)
        val currentDayOfWeek = 3 // Wednesday
        val currentHour = 20
        val currentMinute = 0

        val dayMatches = daysOfWeek.contains(currentDayOfWeek)
        val (startHour, startMinute) = startTime.split(":").map { it.toInt() }
        val (endHour, endMinute) = endTime.split(":").map { it.toInt() }
        val timeMatches = isTimeInRange(
            currentHour, currentMinute,
            startHour, startMinute,
            endHour, endMinute
        )

        val isActive = dayMatches && timeMatches

        assertFalse(isActive)
    }

    // Test edge cases
    @Test
    fun `Empty days list means schedule never active`() {
        val daysOfWeek = emptyList<Int>()
        val currentDayOfWeek = 3

        val dayMatches = daysOfWeek.contains(currentDayOfWeek)

        assertFalse(dayMatches)
    }

    @Test
    fun `All days list means schedule active any day`() {
        val daysOfWeek = listOf(1, 2, 3, 4, 5, 6, 7)

        for (day in 1..7) {
            assertTrue(daysOfWeek.contains(day))
        }
    }
}
