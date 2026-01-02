package com.voidblock.app

import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.voidblock.app.channels.*
import android.os.Bundle

/**
 * Main activity for VoidBlock
 * Registers platform channels for Flutter-Kotlin communication
 */
class MainActivity: FlutterFragmentActivity() {
    
    override fun onCreate(savedInstanceState: Bundle?) {
        // Handle the splash screen transition.
        installSplashScreen()
        
        super.onCreate(savedInstanceState)
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register all method channels
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BlockingChannel.CHANNEL_NAME
        ).setMethodCallHandler(BlockingChannel(this))
        
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ScheduleChannel.CHANNEL_NAME
        ).setMethodCallHandler(ScheduleChannel(this))
        
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AnalyticsChannel.CHANNEL_NAME
        ).setMethodCallHandler(AnalyticsChannel(this))
        
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PermissionChannel.CHANNEL_NAME
        ).setMethodCallHandler(PermissionChannel(this))
        
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            StrictModeChannel.CHANNEL_NAME
        ).setMethodCallHandler(StrictModeChannel(this))
        
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AppLimitChannel.CHANNEL_NAME
        ).setMethodCallHandler(AppLimitChannel(this))
    }
}