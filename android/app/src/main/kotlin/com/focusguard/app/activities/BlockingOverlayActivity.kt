package com.focusguard.app.activities

import android.app.KeyguardManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.appcompat.app.AppCompatActivity
import android.widget.TextView
import android.widget.Button
import android.view.View
import android.graphics.Color
import com.focusguard.app.R

/**
 * Full-screen blocking overlay shown when user tries to access a blocked app
 * Prevents access and displays motivational message
 */
class BlockingOverlayActivity : AppCompatActivity() {
    
    private var blockedPackage: String? = null
    private var blockedAppName: String? = null

    override fun attachBaseContext(newBase: android.content.Context?) {
        super.attachBaseContext(newBase)
        android.util.Log.d("BlockingOverlay", "attachBaseContext called")
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        android.util.Log.d("BlockingOverlay", "onCreate called")
        
        // Make activity appear over other apps
        setupWindowFlags()
        
        // Get blocked app info
        blockedPackage = intent.getStringExtra("blocked_package")
        blockedAppName = intent.getStringExtra("blocked_app_name") ?: blockedPackage
        android.util.Log.d("BlockingOverlay", "Blocking app: $blockedPackage ($blockedAppName)")
        
        // Create and set simple layout
        createBlockingLayout()
    }

    override fun onStart() {
        super.onStart()
        android.util.Log.d("BlockingOverlay", "onStart called")
    }

    override fun onResume() {
        super.onResume()
        android.util.Log.d("BlockingOverlay", "onResume called")
    }

    override fun onPause() {
        super.onPause()
        android.util.Log.d("BlockingOverlay", "onPause called")
        // REMOVED finish() to prevent immediate closing by system/launcher transitions
    }

    override fun onStop() {
        super.onStop()
        android.util.Log.d("BlockingOverlay", "onStop called")
    }

    override fun onDestroy() {
        super.onDestroy()
        android.util.Log.d("BlockingOverlay", "onDestroy called")
    }
    
    /**
     * Setup window flags to show over locked screen and other apps
     */
    private fun setupWindowFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
        
        // Show over other apps (removed FLAG_NOT_TOUCHABLE to allow button clicks)
        window.addFlags(WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN)
    }
    
    /**
     * Set up the blocking UI using XML layout
     */
    private fun createBlockingLayout() {
        setContentView(R.layout.activity_blocking_overlay)
        
        // Get data from intent
        val blockedPackage = intent.getStringExtra("blocked_package") ?: ""
        val blockedAppName = intent.getStringExtra("blocked_app_name") ?: "App"
        val quote = intent.getStringExtra("quote") ?: "Stay focused on your goals!"
        
        // Update UI elements
        findViewById<android.widget.TextView>(R.id.app_name_text).text = "$blockedAppName is blocked"
        findViewById<android.widget.TextView>(R.id.message_text).text = quote
        
        // Set up close button
        findViewById<android.widget.Button>(R.id.close_button).setOnClickListener {
            navigateToHome()
        }
    }
    
    /**
     * Navigate to home screen
     */
    private fun navigateToHome() {
        val homeIntent = android.content.Intent(android.content.Intent.ACTION_MAIN).apply {
            addCategory(android.content.Intent.CATEGORY_HOME)
            flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(homeIntent)
        finish()
    }
    
    override fun onBackPressed() {
        // Prevent back button - must use "Go Back" button
        navigateToHome()
    }
    
    // override fun onPause() {
    //     super.onPause()
    //     // Close activity when user navigates away
    //     finish()
    // }
}
