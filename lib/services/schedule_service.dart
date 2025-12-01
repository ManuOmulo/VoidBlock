import 'package:flutter/services.dart';

/**
 * Model representing a schedule
 */
class Schedule {
  final int? id;
  final String name;
  final String startTime;
  final String endTime;
  final List<int> daysOfWeek;
  final bool isActive;
  final bool isPaused;
  final bool isStrictMode;
  final String? strictModeLevel; // NONE, EASY, MEDIUM, HARD
  final String? strictModePin; // Encrypted PIN
  final int? strictModeCooldownMinutes;
  final String? motivationalMessage;
  final bool notificationsEnabled;
  final List<String> blockedApps;

  Schedule({
    this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.daysOfWeek,
    this.isActive = true,
    this.isPaused = false,
    this.isStrictMode = false,
    this.strictModeLevel,
    this.strictModePin,
    this.strictModeCooldownMinutes,
    this.motivationalMessage,
    this.notificationsEnabled = true,
    this.blockedApps = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'startTime': startTime,
        'endTime': endTime,
        'daysOfWeek': daysOfWeek,
        'isActive': isActive,
        'isPaused': isPaused,
        'isStrictMode': isStrictMode,
        'strictModeLevel': strictModeLevel,
        'strictModePin': strictModePin,
        'strictModeCooldownMinutes': strictModeCooldownMinutes,
        'motivationalMessage': motivationalMessage,
        'notificationsEnabled': notificationsEnabled,
        'blockedApps': blockedApps,
      };

  factory Schedule.fromJson(Map<String, dynamic> json) => Schedule(
        id: json['id'],
        name: json['name'],
        startTime: json['startTime'],
        endTime: json['endTime'],
        daysOfWeek: List<int>.from(json['daysOfWeek'] ?? []),
        isActive: json['isActive'] ?? true,
        isPaused: json['isPaused'] ?? false,
        isStrictMode: json['isStrictMode'] ?? false,
        strictModeLevel: json['strictModeLevel'],
        strictModePin: json['strictModePin'],
        strictModeCooldownMinutes: json['strictModeCooldownMinutes'],
        motivationalMessage: json['motivationalMessage'],
        notificationsEnabled: json['notificationsEnabled'] ?? true,
        blockedApps: List<String>.from(json['blockedApps'] ?? []),
      );
}

/**
 * Service for schedule management operations
 */
class ScheduleService {
  static const platform = MethodChannel('com.focusguard.app/schedule');

  /// Create a new schedule
  Future<bool> createSchedule(Schedule schedule) async {
    try {
      final result = await platform.invokeMethod(
        'createSchedule',
        schedule.toJson(),
      );
      return result as bool;
    } on PlatformException catch (e) {
      print('Error creating schedule: ${e.message}');
      return false;
    }
  }

  /// Get all schedules
  Future<List<Schedule>> getAllSchedules() async {
    try {
      final result = await platform.invokeMethod('getAllSchedules');
      return (result as List)
          .map((json) => Schedule.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } on PlatformException catch (e) {
      print('Error fetching schedules: ${e.message}');
      return [];
    }
  }

  /// Get a specific schedule by ID
  Future<Schedule?> getScheduleById(int id) async {
    try {
      final result = await platform.invokeMethod('getScheduleById', {'id': id});
      return result != null
          ? Schedule.fromJson(Map<String, dynamic>.from(result))
          : null;
    } on PlatformException catch (e) {
      print('Error fetching schedule: ${e.message}');
      return null;
    }
  }

  /// Update an existing schedule
  Future<bool> updateSchedule(Schedule schedule) async {
    try {
      final result = await platform.invokeMethod(
        'updateSchedule',
        schedule.toJson(),
      );
      return result as bool;
    } on PlatformException catch (e) {
      print('Error updating schedule: ${e.message}');
      return false;
    }
  }

  /// Delete a schedule
  Future<bool> deleteSchedule(int id) async {
    try {
      final result = await platform.invokeMethod('deleteSchedule', {'id': id});
      return result as bool;
    } on PlatformException catch (e) {
      print('Error deleting schedule: ${e.message}');
      throw e; // Rethrow to let UI handle specific errors (e.g. Hard Mode)
    }
  }

  /// Toggle schedule active status
  Future<bool> toggleSchedule(int id, bool isActive) async {
    try {
      final result = await platform.invokeMethod('toggleSchedule', {
        'id': id,
        'isActive': isActive,
      });
      return result as bool;
    } on PlatformException catch (e) {
      print('Error toggling schedule: ${e.message}');
      return false;
    }
  }

  /// Get currently active schedules
  Future<List<Schedule>> getActiveSchedules() async {
    try {
      final result = await platform.invokeMethod('getActiveSchedules');
      return (result as List)
          .map((json) => Schedule.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    } on PlatformException catch (e) {
      print('Error fetching active schedules: ${e.message}');
      return [];
    }
  }
}
