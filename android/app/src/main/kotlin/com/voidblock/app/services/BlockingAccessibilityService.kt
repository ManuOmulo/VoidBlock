package com.voidblock.app.services

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent

/**
 * Accessibility service to detect foreground app changes instantly.
 * This is more reliable than UsageStatsManager for blocking bypasses.
 */
class BlockingAccessibilityService : AccessibilityService() {

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            val packageName = event.packageName?.toString()
            if (packageName != null) {
                // Notify the BlockingService of the foreground app change
                val intent = Intent(this, BlockingService::class.java).apply {
                    action = "com.voidblock.app.service.ACCESSIBILITY_EVENT"
                    putExtra("package_name", packageName)
                }
                startService(intent)
            }
        }
    }

    override fun onInterrupt() {
        // Required method
    }
}
