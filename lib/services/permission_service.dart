import 'package:flutter/services.dart';

/**
 * Service for managing app permissions
 */
class PermissionService {
  static const platform = MethodChannel('com.voidblock.app/permissions');

  /// Check if usage stats permission is granted
  Future<bool> checkUsageStatsPermission() async {
    try {
      final result = await platform.invokeMethod('checkUsageStatsPermission');
      return result as bool;
    } on PlatformException catch (e) {
      print('Error checking usage stats permission: ${e.message}');
      return false;
    }
  }

  /// Request usage stats permission
  Future<bool> requestUsageStatsPermission() async {
    try {
      final result = await platform.invokeMethod('requestUsageStatsPermission');
      return result as bool;
    } on PlatformException catch (e) {
      print('Error requesting usage stats permission: ${e.message}');
      return false;
    }
  }

  /// Check if overlay permission is granted
  Future<bool> checkOverlayPermission() async {
    try {
      final result = await platform.invokeMethod('checkOverlayPermission');
      return result as bool;
    } on PlatformException catch (e) {
      print('Error checking overlay permission: ${e.message}');
      return false;
    }
  }

  /// Request overlay permission
  Future<bool> requestOverlayPermission() async {
    try {
      final result = await platform.invokeMethod('requestOverlayPermission');
      return result as bool;
    } on PlatformException catch (e) {
      print('Error requesting overlay permission: ${e.message}');
      return false;
    }
  }

  /// Check if notification permission is granted
  Future<bool> checkNotificationPermission() async {
    try {
      final result = await platform.invokeMethod('checkNotificationPermission');
      return result as bool;
    } on PlatformException catch (e) {
      print('Error checking notification permission: ${e.message}');
      return false;
    }
  }

  /// Request notification permission
  Future<bool> requestNotificationPermission() async {
    try {
      final result =
          await platform.invokeMethod('requestNotificationPermission');
      return result as bool;
    } on PlatformException catch (e) {
      print('Error requesting notification permission: ${e.message}');
      return false;
    }
  }

  /// Check if battery optimization is disabled
  Future<bool> checkBatteryOptimization() async {
    try {
      final result = await platform.invokeMethod('checkBatteryOptimization');
      return result as bool;
    } on PlatformException catch (e) {
      print('Error checking battery optimization: ${e.message}');
      return false;
    }
  }

  /// Request to disable battery optimization
  Future<bool> requestBatteryOptimization() async {
    try {
      final result = await platform.invokeMethod('requestBatteryOptimization');
      return result as bool;
    } on PlatformException catch (e) {
      print('Error requesting battery optimization: ${e.message}');
      return false;
    }
  }

  /// Check if exact alarms permission is granted
  Future<bool> checkExactAlarmsPermission() async {
    try {
      final result = await platform.invokeMethod('checkExactAlarmsPermission');
      return result as bool;
    } on PlatformException catch (e) {
      print('Error checking exact alarms permission: ${e.message}');
      return false;
    }
  }

  /// Request exact alarms permission
  Future<bool> requestExactAlarmsPermission() async {
    try {
      final result =
          await platform.invokeMethod('requestExactAlarmsPermission');
      return result as bool;
    } on PlatformException catch (e) {
      print('Error requesting exact alarms permission: ${e.message}');
      return false;
    }
  }

  /// Check all required permissions
  Future<Map<String, bool>> checkAllPermissions() async {
    try {
      final result = await platform.invokeMethod('checkAllPermissions');
      return Map<String, bool>.from(result ?? {});
    } on PlatformException catch (e) {
      print('Error checking all permissions: ${e.message}');
      return {
        'usageStats': false,
        'overlay': false,
        'notification': false,
        'batteryOptimization': false,
        'exactAlarms': false,
      };
    }
  }

  /// Check if all critical permissions are granted
  Future<bool> hasAllCriticalPermissions() async {
    try {
      final result = await platform.invokeMethod('hasAllCriticalPermissions');
      return result as bool;
    } on PlatformException catch (e) {
      print('Error checking critical permissions: ${e.message}');
      return false;
    }
  }

  /// Get list of missing permissions
  Future<List<String>> getMissingPermissions() async {
    try {
      final result = await platform.invokeMethod('getMissingPermissions');
      return List<String>.from(result ?? []);
    } on PlatformException catch (e) {
      print('Error getting missing permissions: ${e.message}');
      return [];
    }
  }
}
