package com.voidblock.app.channels

import android.content.Context
import com.voidblock.app.utils.PermissionManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Platform channel for permission management operations
 */
class PermissionChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    
    private val permissionManager = PermissionManager(context)
    
    companion object {
        const val CHANNEL_NAME = "com.voidblock.app/permissions"
    }
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkUsageStatsPermission" -> {
                result.success(permissionManager.hasUsageStatsPermission())
            }
            
            "requestUsageStatsPermission" -> {
                permissionManager.requestUsageStatsPermission()
                result.success(true)
            }
            
            "checkOverlayPermission" -> {
                result.success(permissionManager.hasOverlayPermission())
            }
            
            "requestOverlayPermission" -> {
                permissionManager.requestOverlayPermission()
                result.success(true)
            }
            
            "checkNotificationPermission" -> {
                result.success(permissionManager.hasNotificationPermission())
            }
            
            "requestNotificationPermission" -> {
                permissionManager.requestNotificationPermission()
                result.success(true)
            }
            
            "checkBatteryOptimization" -> {
                result.success(permissionManager.isBatteryOptimizationDisabled())
            }
            
            "requestBatteryOptimization" -> {
                permissionManager.requestDisableBatteryOptimization()
                result.success(true)
            }
            
            "checkExactAlarmsPermission" -> {
                result.success(permissionManager.canScheduleExactAlarms())
            }
            
            "requestExactAlarmsPermission" -> {
                permissionManager.requestScheduleExactAlarmsPermission()
                result.success(true)
            }
            
            "checkAllPermissions" -> {
                val permissions = permissionManager.checkAllPermissions()
                result.success(permissions)
            }
            
            "hasAllCriticalPermissions" -> {
                result.success(permissionManager.hasAllCriticalPermissions())
            }
            
            "getMissingPermissions" -> {
                result.success(permissionManager.getMissingPermissions())
            }
            
            else -> result.notImplemented()
        }
    }
}
