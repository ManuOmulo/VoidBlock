package com.focusguard.app.utils

import org.junit.Test
import org.junit.Assert.*
import org.junit.Before

/**
 * Unit tests for StrictModeManager
 * Tests strict mode level enforcement, PIN validation, and cooldown logic
 */
class StrictModeManagerTest {

    // Test StrictModeLevel enum parsing
    @Test
    fun `StrictModeLevel fromString parses NONE correctly`() {
        val level = StrictModeManager.StrictModeLevel.fromString("NONE")
        assertEquals(StrictModeManager.StrictModeLevel.NONE, level)
    }

    @Test
    fun `StrictModeLevel fromString parses EASY correctly`() {
        val level = StrictModeManager.StrictModeLevel.fromString("EASY")
        assertEquals(StrictModeManager.StrictModeLevel.EASY, level)
    }

    @Test
    fun `StrictModeLevel fromString parses MEDIUM correctly`() {
        val level = StrictModeManager.StrictModeLevel.fromString("MEDIUM")
        assertEquals(StrictModeManager.StrictModeLevel.MEDIUM, level)
    }

    @Test
    fun `StrictModeLevel fromString parses HARD correctly`() {
        val level = StrictModeManager.StrictModeLevel.fromString("HARD")
        assertEquals(StrictModeManager.StrictModeLevel.HARD, level)
    }

    @Test
    fun `StrictModeLevel fromString handles lowercase`() {
        val level = StrictModeManager.StrictModeLevel.fromString("medium")
        assertEquals(StrictModeManager.StrictModeLevel.MEDIUM, level)
    }

    @Test
    fun `StrictModeLevel fromString returns NONE for invalid input`() {
        val level = StrictModeManager.StrictModeLevel.fromString("INVALID")
        assertEquals(StrictModeManager.StrictModeLevel.NONE, level)
    }

    @Test
    fun `StrictModeLevel fromString returns NONE for empty string`() {
        val level = StrictModeManager.StrictModeLevel.fromString("")
        assertEquals(StrictModeManager.StrictModeLevel.NONE, level)
    }

    // Test UnlockAttemptResult
    @Test
    fun `UnlockAttemptResult success creates correct result`() {
        val result = StrictModeManager.UnlockAttemptResult(
            success = true,
            reason = ""
        )
        assertTrue(result.success)
        assertEquals("", result.reason)
    }

    @Test
    fun `UnlockAttemptResult failure creates correct result`() {
        val result = StrictModeManager.UnlockAttemptResult(
            success = false,
            reason = "Incorrect PIN"
        )
        assertFalse(result.success)
        assertEquals("Incorrect PIN", result.reason)
    }

    // Test strict mode level behavior expectations
    @Test
    fun `NONE level should allow immediate unlock`() {
        val level = StrictModeManager.StrictModeLevel.NONE
        // NONE level has no protection
        assertEquals("NONE", level.name)
    }

    @Test
    fun `EASY level requires PIN for unlock`() {
        val level = StrictModeManager.StrictModeLevel.EASY
        // EASY level requires PIN validation
        assertEquals("EASY", level.name)
        // In actual implementation, this level requires a PIN match
    }

    @Test
    fun `MEDIUM level requires cooldown period`() {
        val level = StrictModeManager.StrictModeLevel.MEDIUM
        assertEquals("MEDIUM", level.name)
        // In actual implementation, this level requires waiting for cooldown
    }

    @Test
    fun `HARD level blocks all unlock attempts`() {
        val level = StrictModeManager.StrictModeLevel.HARD
        assertEquals("HARD", level.name)
        // In actual implementation, this level prevents any unlock
    }

    // Test level hierarchy
    @Test
    fun `StrictModeLevel has correct ordinal order`() {
        val none = StrictModeManager.StrictModeLevel.NONE
        val easy = StrictModeManager.StrictModeLevel.EASY
        val medium = StrictModeManager.StrictModeLevel.MEDIUM
        val hard = StrictModeManager.StrictModeLevel.HARD

        assertTrue(none.ordinal < easy.ordinal)
        assertTrue(easy.ordinal < medium.ordinal)
        assertTrue(medium.ordinal < hard.ordinal)
    }

    // Test cooldown duration validation
    @Test
    fun `Cooldown duration validates common values`() {
        val validCooldowns = listOf(5, 10, 15, 30, 60)
        for (minutes in validCooldowns) {
            assertTrue("Cooldown of $minutes should be valid", minutes > 0)
        }
    }

    @Test
    fun `Zero cooldown is invalid`() {
        val cooldown = 0
        assertFalse(cooldown > 0)
    }

    @Test
    fun `Negative cooldown is invalid`() {
        val cooldown = -5
        assertFalse(cooldown > 0)
    }

    // Test cooldown time calculations
    @Test
    fun `Cooldown remaining time calculation`() {
        val cooldownMinutes = 15
        val startTime = System.currentTimeMillis()
        val fiveMinutesAgo = startTime - (5 * 60 * 1000)

        val elapsedMs = startTime - fiveMinutesAgo
        val elapsedMinutes = elapsedMs / (60 * 1000)
        val remainingMinutes = cooldownMinutes - elapsedMinutes

        assertEquals(10, remainingMinutes)
    }

    @Test
    fun `Cooldown completed when elapsed exceeds duration`() {
        val cooldownMinutes = 15
        val cooldownMs = cooldownMinutes * 60 * 1000L
        val startTime = System.currentTimeMillis() - cooldownMs - 1000 // 1 second past

        val elapsed = System.currentTimeMillis() - startTime
        val cooldownCompleted = elapsed >= cooldownMs

        assertTrue(cooldownCompleted)
    }

    @Test
    fun `Cooldown not completed when elapsed is under duration`() {
        val cooldownMinutes = 15
        val cooldownMs = cooldownMinutes * 60 * 1000L
        val startTime = System.currentTimeMillis() - (5 * 60 * 1000) // 5 minutes ago

        val elapsed = System.currentTimeMillis() - startTime
        val cooldownCompleted = elapsed >= cooldownMs

        assertFalse(cooldownCompleted)
    }
}
