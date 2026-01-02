package com.voidblock.app.utils

/**
 * Collection of motivational quotes for the blocking overlay
 */
object MotivationalQuotes {
    private val quotes = listOf(
        "Focus on being productive instead of busy.",
        "The only way to do great work is to love what you do.",
        "Starve your distractions, feed your focus.",
        "Your future is created by what you do today, not tomorrow.",
        "Discipline is choosing between what you want now and what you want most.",
        "Don't watch the clock; do what it does. Keep going.",
        "Success is the sum of small efforts, repeated day in and day out.",
        "The key to success is to focus on goals, not obstacles.",
        "You can do anything, but not everything.",
        "Focus is the art of knowing what to ignore.",
        "Productivity is never an accident. It is always the result of a commitment to excellence, intelligent planning, and focused effort.",
        "Until we can manage time, we can manage nothing else.",
        "Lost time is never found again.",
        "Action is the foundational key to all success.",
        "One day or day one. You decide."
    )

    fun getRandomQuote(): String {
        return quotes.random()
    }
}
