import 'package:flutter/services.dart';

/**
 * Service for native blocking operations
 * Handles communication with native Android blocking service
 */
class BlockingService {
  static const platform = MethodChannel('com.voidblock.app/blocking');

  /// Start a manual blocking session with specified apps and duration
  Future<bool> startBlocking({
    required int durationMinutes,
    required List<String> apps,
    bool strictMode = false,
    String strictModeLevel = 'NONE',
    String? strictModePin,
    int? strictModeCooldownMinutes,
    String? message,
  }) async {
    try {
      final result = await platform.invokeMethod('startBlocking', {
        'apps': apps,
        'durationMinutes': durationMinutes,
        'strictMode': strictMode,
        'strictModeLevel': strictModeLevel,
        'strictModePin': strictModePin,
        'strictModeCooldownMinutes': strictModeCooldownMinutes,
        'message': message,
      });
      return result as bool;
    } on PlatformException catch (e) {
      print('Error starting blocking: ${e.message}');
      throw Exception('Failed to start blocking: ${e.message}');
    }
  }

  /// Stop the current blocking session
  Future<bool> stopBlocking() async {
    try {
      final result = await platform.invokeMethod('stopBlocking');
      return result as bool;
    } on PlatformException catch (e) {
      print('Error stopping blocking: ${e.message}');
      return false;
    }
  }

  /// Get the current active blocking session
  Future<Map<String, dynamic>?> getActiveSession() async {
    try {
      final result = await platform.invokeMethod('getActiveSession');
      return result != null ? Map<String, dynamic>.from(result) : null;
    } on PlatformException catch (e) {
      print('Error getting active session: ${e.message}');
      return null;
    }
  }

  /// Check if a specific app is currently blocked
  Future<bool> isAppBlocked(String packageName) async {
    try {
      final result = await platform.invokeMethod('isAppBlocked', {
        'packageName': packageName,
      });
      return result as bool;
    } on PlatformException catch (e) {
      print('Error checking blocked status: ${e.message}');
      return false;
    }
  }

  /// Pause the current blocking session
  Future<bool> pauseBlocking() async {
    try {
      final result = await platform.invokeMethod('pauseBlocking');
      return result as bool;
    } on PlatformException catch (e) {
      print('Error pausing blocking: ${e.message}');
      return false;
    }
  }

  /// Resume a paused blocking session
  Future<bool> resumeBlocking() async {
    try {
      final result = await platform.invokeMethod('resumeBlocking');
      return result as bool;
    } on PlatformException catch (e) {
      print('Error resuming blocking: ${e.message}');
      return false;
    }
  }
}
