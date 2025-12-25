package com.focusguard.app

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.focusguard.app.channels.*

/**
 * Main activity for FocusGuard
 * Registers platform channels for Flutter-Kotlin communication
 */
class MainActivity: FlutterFragmentActivity() {
    
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