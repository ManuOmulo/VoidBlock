import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:typed_data';

/**
 * Model for installed app information
 */
class InstalledApp {
  final String packageName;
  final String appName;
  final bool isSystemApp;
  final String? iconBase64;

  InstalledApp({
    required this.packageName,
    required this.appName,
    required this.isSystemApp,
    this.iconBase64,
  });

  factory InstalledApp.fromJson(Map<String, dynamic> json) => InstalledApp(
        packageName: json['packageName'],
        appName: json['appName'],
        isSystemApp: json['isSystemApp'] ?? false,
        iconBase64: json['iconBase64'],
      );

  /// Get icon as image bytes
  Uint8List? getIconBytes() {
    if (iconBase64 == null) return null;
    try {
      return base64Decode(iconBase64!);
    } catch (e) {
      return null;
    }
  }
}

/**
 * Service for analytics and usage tracking operations
 */
class AnalyticsService {
  static const platform = MethodChannel('com.voidblock.app/analytics');

  /// Get usage statistics for the past N days
  Future<Map<String, dynamic>> getUsageStats({int days = 7}) async {
    try {
      final result = await platform.invokeMethod('getUsageStats', {
        'days': days,
      });
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      print('Error getting usage stats: ${e.message}');
      return {};
    }
  }

  /// Get all installed apps (including system apps)
  Future<List<InstalledApp>> getAllInstalledApps() async {
    try {
      final result = await platform.invokeMethod('getInstalledApps');
      return (result as List)
          .map((json) => InstalledApp.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } on PlatformException catch (e) {
      print('Error getting all apps: ${e.message}');
      return [];
    }
  }

  /// Get only user-installed apps (excludes system apps)
  Future<List<InstalledApp>> getUserApps() async {
    try {
      final result = await platform.invokeMethod('getUserApps');
      return (result as List)
          .map((json) => InstalledApp.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } on PlatformException catch (e) {
      print('Error getting user apps: ${e.message}');
      return [];
    }
  }

  /// Search installed apps by name or package
  Future<List<InstalledApp>> searchApps({
    required String query,
    bool includeSystem = false,
  }) async {
    try {
      final result = await platform.invokeMethod('searchApps', {
        'query': query,
        'includeSystem': includeSystem,
      });
      return (result as List)
          .map((json) => InstalledApp.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } on PlatformException catch (e) {
      print('Error searching apps: ${e.message}');
      return [];
    }
  }

  /// Get info for a specific app by package name
  Future<InstalledApp?> getAppInfo(String packageName) async {
    try {
      final result = await platform.invokeMethod('getAppInfo', {
        'packageName': packageName,
      });
      return result != null
          ? InstalledApp.fromJson(Map<String, dynamic>.from(result))
          : null;
    } on PlatformException catch (e) {
      print('Error getting app info: ${e.message}');
      return null;
    }
  }

  /// Get usage time for a specific app
  Future<int> getAppUsageTime({
    required String packageName,
    int days = 7,
  }) async {
    try {
      final result = await platform.invokeMethod('getAppUsageTime', {
        'packageName': packageName,
        'days': days,
      });
      return result as int;
    } on PlatformException catch (e) {
      print('Error getting app usage time: ${e.message}');
      return 0;
    }
  }

  /// Get productivity score (0.0 - 100.0)
  Future<double> getProductivityScore({int days = 7}) async {
    try {
      final result = await platform.invokeMethod('getProductivityScore', {
        'days': days,
      });
      return (result as num).toDouble();
    } on PlatformException catch (e) {
      print('Error getting productivity score: ${e.message}');
      return 0.0;
    }
  }

  /// Get personalized insights
  Future<List<Map<String, dynamic>>> getInsights({int days = 7}) async {
    try {
      final result = await platform.invokeMethod('getInsights', {
        'days': days,
      });
      return (result as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } on PlatformException catch (e) {
      print('Error getting insights: ${e.message}');
      return [];
    }
  }

  /// Get daily statistics
  Future<List<Map<String, dynamic>>> getDailyStats({int days = 30}) async {
    try {
      final result = await platform.invokeMethod('getDailyStats', {
        'days': days,
      });
      return (result as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } on PlatformException catch (e) {
      print('Error getting daily stats: ${e.message}');
      return [];
    }
  }

  /// Get most used apps
  Future<List<Map<String, dynamic>>> getMostUsedApps({int limit = 10}) async {
    try {
      final result = await platform.invokeMethod('getMostUsedApps', {
        'limit': limit,
      });
      return (result as List)
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } on PlatformException catch (e) {
      print('Error getting most used apps: ${e.message}');
      return [];
    }
  }

  /// Export usage data
  Future<Map<String, dynamic>> exportUsageData({
    required int startTime,
    required int endTime,
  }) async {
    try {
      final result = await platform.invokeMethod('exportUsageData', {
        'startTime': startTime,
        'endTime': endTime,
      });
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      print('Error exporting usage data: ${e.message}');
      return {'success': false, 'message': e.message};
    }
  }

  /// Clear all usage history
  Future<bool> clearUsageData() async {
    try {
      final result = await platform.invokeMethod('clearUsageData');
      return result as bool;
    } on PlatformException catch (e) {
      print('Error clearing usage data: ${e.message}');
      return false;
    }
  }

  /// Get hourly usage pattern for peak usage heatmap
  Future<List<int>> getPeakUsagePattern({int days = 1}) async {
    try {
      final result = await platform.invokeMethod('getPeakUsagePattern', {
        'days': days,
      });
      return List<int>.from(result ?? []);
    } on PlatformException catch (e) {
      print('Error getting peak usage pattern: ${e.message}');
      return List.filled(24, 0);
    }
  }

  /// Get comparison data for screen time and time saved
  Future<Map<String, dynamic>> getComparisonData() async {
    try {
      final result = await platform.invokeMethod('getComparisonData');
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      print('Error getting comparison data: ${e.message}');
      return {};
    }
  }
}
