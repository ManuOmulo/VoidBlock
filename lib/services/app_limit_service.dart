import 'package:flutter/services.dart';

class AppLimit {
  final int? id;
  final String name;
  final int limitMinutes;
  final bool isActive;
  final bool isStrictMode;
  final String strictModeLevel;
  final String? strictModePin;
  final int? strictModeCooldownMinutes;
  final int? hardModeDurationMinutes;
  final int? hardModeEndsAt;
  final int? lastUnlockedAt;
  final bool unlockedUntilMidnight;
  final List<dynamic> apps;

  AppLimit({
    this.id,
    required this.name,
    required this.limitMinutes,
    this.isActive = true,
    this.isStrictMode = false,
    this.strictModeLevel = 'NONE',
    this.strictModePin,
    this.strictModeCooldownMinutes,
    this.hardModeDurationMinutes,
    this.hardModeEndsAt,
    this.lastUnlockedAt,
    this.unlockedUntilMidnight = false,
    this.apps = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'limitMinutes': limitMinutes,
        'isActive': isActive,
        'isStrictMode': isStrictMode,
        'strictModeLevel': strictModeLevel,
        'strictModePin': strictModePin,
        'strictModeCooldownMinutes': strictModeCooldownMinutes,
        'hardModeDurationMinutes': hardModeDurationMinutes,
        'hardModeEndsAt': hardModeEndsAt,
        'lastUnlockedAt': lastUnlockedAt,
        'unlockedUntilMidnight': unlockedUntilMidnight,
        'apps': apps,
      };

  factory AppLimit.fromJson(Map<String, dynamic> json) => AppLimit(
        id: json['id'],
        name: json['name'],
        limitMinutes: json['limitMinutes'],
        isActive: json['isActive'] ?? true,
        isStrictMode: json['isStrictMode'] ?? false,
        strictModeLevel: json['strictModeLevel'] ?? 'NONE',
        strictModePin: json['strictModePin'],
        strictModeCooldownMinutes: json['strictModeCooldownMinutes'],
        hardModeDurationMinutes: json['hardModeDurationMinutes'],
        hardModeEndsAt: json['hardModeEndsAt'],
        lastUnlockedAt: json['lastUnlockedAt'],
        unlockedUntilMidnight: json['unlockedUntilMidnight'] ?? false,
        apps: List<dynamic>.from(json['apps'] ?? []),
      );
}

class AppLimitService {
  static const platform = MethodChannel('com.voidblock.app/app_limit');

  Future<int?> createLimit(AppLimit limit) async {
    try {
      final result = await platform.invokeMethod('createLimit', limit.toJson());
      return result as int?;
    } on PlatformException catch (e) {
      print('Error creating limit: ${e.message}');
      return null;
    }
  }

  Future<List<AppLimit>> getAllLimits() async {
    try {
      final result = await platform.invokeMethod('getAllLimits');
      return (result as List)
          .map((json) => AppLimit.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } on PlatformException catch (e) {
      print('Error fetching limits: ${e.message}');
      return [];
    }
  }

  Future<AppLimit?> getLimitById(int id) async {
    try {
      final result = await platform.invokeMethod('getLimitById', {'id': id});
      return result != null
          ? AppLimit.fromJson(Map<String, dynamic>.from(result))
          : null;
    } on PlatformException catch (e) {
      print('Error fetching limit: ${e.message}');
      return null;
    }
  }

  Future<bool> updateLimit(AppLimit limit) async {
    try {
      final result = await platform.invokeMethod('updateLimit', limit.toJson());
      return result as bool;
    } on PlatformException catch (e) {
      print('Error updating limit: ${e.message}');
      return false;
    }
  }

  Future<bool> deleteLimit(int id) async {
    try {
      final result = await platform.invokeMethod('deleteLimit', {'id': id});
      return result as bool;
    } on PlatformException catch (e) {
      print('Error deleting limit: ${e.message}');
      throw e;
    }
  }

  Future<bool> toggleLimit(int id, bool isActive) async {
    try {
      final result = await platform.invokeMethod('toggleLimit', {
        'id': id,
        'isActive': isActive,
      });
      return result as bool;
    } on PlatformException catch (e) {
      print('Error toggling limit: ${e.message}');
      return false;
    }
  }

  Future<bool> unlockLimit(int id) async {
    try {
      final result = await platform.invokeMethod('unlockLimit', {'id': id});
      return result as bool;
    } on PlatformException catch (e) {
      print('Error unlocking limit: ${e.message}');
      return false;
    }
  }

  Future<bool> requestUnlock(int id) async {
    try {
      final result = await platform.invokeMethod('requestUnlock', {'id': id});
      return result as bool;
    } on PlatformException catch (e) {
      print('Error requesting unlock: ${e.message}');
      return false;
    }
  }

  Future<Map<String, int>> getDailyUsage(List<String> packageNames) async {
    try {
      final result = await platform.invokeMethod('getDailyUsage', {
        'packageNames': packageNames,
      });
      return Map<String, int>.from(result);
    } on PlatformException catch (e) {
      print('Error fetching daily usage: ${e.message}');
      return {};
    }
  }
}
