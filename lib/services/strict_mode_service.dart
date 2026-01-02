import 'package:flutter/services.dart';

/// Flutter service for interacting with strict mode functionality
/// Bridges to native StrictModeManager
class StrictModeService {
  static const MethodChannel _channel =
      MethodChannel('com.voidblock.app/strict_mode');

  /// Get default strict mode preferences
  Future<Map<String, dynamic>?> getDefaultPreferences() async {
    try {
      final result = await _channel.invokeMethod('getDefaultPreferences');
      return result != null ? Map<String, dynamic>.from(result) : null;
    } catch (e) {
      print('Error getting strict mode preferences: $e');
      return null;
    }
  }

  /// Update default strict mode level
  Future<bool> updateDefaultLevel(String level) async {
    try {
      await _channel.invokeMethod('updateDefaultLevel', {'level': level});
      return true;
    } catch (e) {
      print('Error updating default level: $e');
      return false;
    }
  }

  /// Attempt to unlock a blocking session with PIN
  Future<Map<String, dynamic>> attemptUnlockSession({
    required int sessionId,
    String? pin,
  }) async {
    try {
      final result = await _channel.invokeMethod('attemptUnlockSession', {
        'sessionId': sessionId,
        'pin': pin,
      });
      return Map<String, dynamic>.from(result);
    } catch (e) {
      print('Error attempting unlock: $e');
      return {
        'success': false,
        'reason': 'Failed to unlock: $e',
      };
    }
  }

  /// Attempt to unlock a schedule with PIN
  Future<Map<String, dynamic>> attemptUnlockSchedule({
    required int scheduleId,
    String? pin,
  }) async {
    try {
      final result = await _channel.invokeMethod('attemptUnlockSchedule', {
        'scheduleId': scheduleId,
        'pin': pin,
      });
      return Map<String, dynamic>.from(result);
    } catch (e) {
      print('Error attempting schedule unlock: $e');
      return {
        'success': false,
        'reason': 'Failed to unlock: $e',
      };
    }
  }

  /// Start cooldown period for a session
  Future<bool> startCooldown(int sessionId) async {
    try {
      await _channel.invokeMethod('startCooldown', {'sessionId': sessionId});
      return true;
    } catch (e) {
      print('Error starting cooldown: $e');
      return false;
    }
  }

  /// Confirm cooldown unlock
  Future<Map<String, dynamic>> confirmCooldownUnlock(int sessionId) async {
    try {
      final result = await _channel.invokeMethod('confirmCooldownUnlock', {
        'sessionId': sessionId,
      });
      return Map<String, dynamic>.from(result);
    } catch (e) {
      print('Error confirming cooldown: $e');
      return {
        'success': false,
        'reason': 'Failed to confirm: $e',
      };
    }
  }

  /// Start cooldown period for a schedule
  Future<bool> startScheduleCooldown(int scheduleId) async {
    try {
      await _channel
          .invokeMethod('startScheduleCooldown', {'scheduleId': scheduleId});
      return true;
    } catch (e) {
      print('Error starting schedule cooldown: $e');
      return false;
    }
  }

  /// Confirm cooldown unlock for a schedule
  Future<Map<String, dynamic>> confirmScheduleCooldownUnlock(
      int scheduleId) async {
    try {
      final result =
          await _channel.invokeMethod('confirmScheduleCooldownUnlock', {
        'scheduleId': scheduleId,
      });
      return Map<String, dynamic>.from(result);
    } catch (e) {
      print('Error confirming schedule cooldown: $e');
      return {
        'success': false,
        'reason': 'Failed to confirm: $e',
      };
    }
  }

  /// Encrypt a PIN (for storage)
  Future<String?> encryptPin(String pin) async {
    try {
      final encrypted = await _channel.invokeMethod('encryptPin', {'pin': pin});
      return encrypted;
    } catch (e) {
      print('Error encrypting PIN: $e');
      return null;
    }
  }
}
