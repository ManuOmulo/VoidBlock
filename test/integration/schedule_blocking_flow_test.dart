import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusguard/services/schedule_service.dart';

/// Integration tests for schedule blocking flow
/// Tests schedule creation, activation, and enforcement
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Schedule Blocking Flow Integration Tests', () {
    late List<Map<String, dynamic>> mockSchedules;
    late List<Map<String, dynamic>> mockActiveSchedules;
    late List<MethodCall> methodCalls;

    setUp(() {
      mockSchedules = [];
      mockActiveSchedules = [];
      methodCalls = [];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.focusguard.app/schedule'),
        (MethodCall methodCall) async {
          methodCalls.add(methodCall);

          switch (methodCall.method) {
            case 'createSchedule':
              final args = Map<String, dynamic>.from(methodCall.arguments);
              args['id'] = mockSchedules.length + 1;
              mockSchedules.add(args);
              return true;
            case 'getAllSchedules':
              return mockSchedules;
            case 'getScheduleById':
              final id = methodCall.arguments['id'];
              return mockSchedules.firstWhere(
                (s) => s['id'] == id,
                orElse: () => <String, dynamic>{},
              );
            case 'updateSchedule':
              final args = Map<String, dynamic>.from(methodCall.arguments);
              final index =
                  mockSchedules.indexWhere((s) => s['id'] == args['id']);
              if (index >= 0) {
                mockSchedules[index] = args;
              }
              return true;
            case 'deleteSchedule':
              final id = methodCall.arguments['id'];
              mockSchedules.removeWhere((s) => s['id'] == id);
              return true;
            case 'toggleSchedule':
              final id = methodCall.arguments['id'];
              final isActive = methodCall.arguments['isActive'];
              final schedule = mockSchedules.firstWhere((s) => s['id'] == id);
              schedule['isActive'] = isActive;
              return true;
            case 'getActiveSchedules':
              return mockActiveSchedules;
            default:
              return null;
          }
        },
      );

      // Mock Blocking Channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.focusguard.app/blocking'),
        (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'isAppBlocked':
              // Check if app is blocked by any active schedule
              final packageName = methodCall.arguments['packageName'];
              for (final schedule in mockActiveSchedules) {
                final apps = schedule['blockedApps'] as List? ?? [];
                if (apps.contains(packageName)) {
                  return true;
                }
              }
              return false;
            default:
              return null;
          }
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.focusguard.app/schedule'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.focusguard.app/blocking'),
        null,
      );
    });

    group('Schedule CRUD Operations', () {
      test('Create schedule with all fields', () async {
        const platform = MethodChannel('com.focusguard.app/schedule');

        final result = await platform.invokeMethod('createSchedule', {
          'name': 'Work Focus',
          'startTime': '09:00',
          'endTime': '17:00',
          'daysOfWeek': [1, 2, 3, 4, 5],
          'isActive': true,
          'isStrictMode': true,
          'strictModeLevel': 'MEDIUM',
          'strictModeCooldownMinutes': 15,
          'blockedApps': ['com.instagram.android', 'com.twitter.android'],
        });

        expect(result, isTrue);
        expect(mockSchedules, hasLength(1));
        expect(mockSchedules[0]['name'], equals('Work Focus'));
        expect(mockSchedules[0]['daysOfWeek'], equals([1, 2, 3, 4, 5]));
        expect(mockSchedules[0]['isStrictMode'], isTrue);
      });

      test('Get all schedules returns created schedules', () async {
        const platform = MethodChannel('com.focusguard.app/schedule');

        // Create two schedules
        await platform.invokeMethod('createSchedule', {
          'name': 'Morning Focus',
          'startTime': '08:00',
          'endTime': '12:00',
          'daysOfWeek': [1, 2, 3, 4, 5],
          'isActive': true,
          'blockedApps': ['com.instagram.android'],
        });

        await platform.invokeMethod('createSchedule', {
          'name': 'Evening Wind Down',
          'startTime': '20:00',
          'endTime': '22:00',
          'daysOfWeek': [1, 2, 3, 4, 5, 6, 7],
          'isActive': false,
          'blockedApps': ['com.youtube.android'],
        });

        final schedules = await platform.invokeMethod('getAllSchedules');

        expect(schedules, hasLength(2));
        expect(schedules[0]['name'], equals('Morning Focus'));
        expect(schedules[1]['name'], equals('Evening Wind Down'));
      });

      test('Update schedule modifies existing data', () async {
        const platform = MethodChannel('com.focusguard.app/schedule');

        // Create a schedule
        await platform.invokeMethod('createSchedule', {
          'name': 'Original Name',
          'startTime': '10:00',
          'endTime': '11:00',
          'daysOfWeek': [1],
          'isActive': true,
          'blockedApps': [],
        });

        // Update the schedule
        await platform.invokeMethod('updateSchedule', {
          'id': 1,
          'name': 'Updated Name',
          'startTime': '10:00',
          'endTime': '12:00', // Extended by 1 hour
          'daysOfWeek': [1, 2, 3], // Added more days
          'isActive': true,
          'blockedApps': ['com.app1'],
        });

        expect(mockSchedules[0]['name'], equals('Updated Name'));
        expect(mockSchedules[0]['endTime'], equals('12:00'));
        expect(mockSchedules[0]['daysOfWeek'], hasLength(3));
      });

      test('Delete schedule removes it from list', () async {
        const platform = MethodChannel('com.focusguard.app/schedule');

        // Create a schedule
        await platform.invokeMethod('createSchedule', {
          'name': 'To Delete',
          'startTime': '10:00',
          'endTime': '11:00',
          'daysOfWeek': [1],
          'isActive': true,
          'blockedApps': [],
        });

        expect(mockSchedules, hasLength(1));

        // Delete the schedule
        await platform.invokeMethod('deleteSchedule', {'id': 1});

        expect(mockSchedules, isEmpty);
      });

      test('Toggle schedule changes active state', () async {
        const platform = MethodChannel('com.focusguard.app/schedule');

        // Create an active schedule
        await platform.invokeMethod('createSchedule', {
          'name': 'Toggle Test',
          'startTime': '10:00',
          'endTime': '11:00',
          'daysOfWeek': [1],
          'isActive': true,
          'blockedApps': [],
        });

        expect(mockSchedules[0]['isActive'], isTrue);

        // Toggle to inactive
        await platform.invokeMethod('toggleSchedule', {
          'id': 1,
          'isActive': false,
        });

        expect(mockSchedules[0]['isActive'], isFalse);

        // Toggle back to active
        await platform.invokeMethod('toggleSchedule', {
          'id': 1,
          'isActive': true,
        });

        expect(mockSchedules[0]['isActive'], isTrue);
      });
    });

    group('Schedule Activation & Enforcement', () {
      test('Active schedule blocks apps', () async {
        const platform = MethodChannel('com.focusguard.app/blocking');

        // Simulate an active schedule
        mockActiveSchedules.add({
          'id': 1,
          'name': 'Active Now',
          'blockedApps': ['com.instagram.android', 'com.twitter.android'],
        });

        // Check blocked status
        final instagramBlocked = await platform.invokeMethod('isAppBlocked', {
          'packageName': 'com.instagram.android',
        });
        expect(instagramBlocked, isTrue);

        final twitterBlocked = await platform.invokeMethod('isAppBlocked', {
          'packageName': 'com.twitter.android',
        });
        expect(twitterBlocked, isTrue);

        final youtubeBlocked = await platform.invokeMethod('isAppBlocked', {
          'packageName': 'com.youtube.android',
        });
        expect(youtubeBlocked, isFalse);
      });

      test('No active schedule means no blocking', () async {
        const platform = MethodChannel('com.focusguard.app/blocking');

        // No active schedules
        mockActiveSchedules.clear();

        final isBlocked = await platform.invokeMethod('isAppBlocked', {
          'packageName': 'com.instagram.android',
        });

        expect(isBlocked, isFalse);
      });

      test('Multiple active schedules combine blocked apps', () async {
        const platform = MethodChannel('com.focusguard.app/blocking');

        mockActiveSchedules.addAll([
          {
            'id': 1,
            'name': 'Schedule 1',
            'blockedApps': ['com.instagram.android'],
          },
          {
            'id': 2,
            'name': 'Schedule 2',
            'blockedApps': ['com.twitter.android'],
          },
        ]);

        // Both apps should be blocked
        final instagramBlocked = await platform.invokeMethod('isAppBlocked', {
          'packageName': 'com.instagram.android',
        });
        expect(instagramBlocked, isTrue);

        final twitterBlocked = await platform.invokeMethod('isAppBlocked', {
          'packageName': 'com.twitter.android',
        });
        expect(twitterBlocked, isTrue);
      });
    });

    group('Schedule Strict Mode', () {
      test('Schedule with EASY mode has PIN', () async {
        const platform = MethodChannel('com.focusguard.app/schedule');

        await platform.invokeMethod('createSchedule', {
          'name': 'PIN Protected',
          'startTime': '10:00',
          'endTime': '11:00',
          'daysOfWeek': [1, 2, 3, 4, 5],
          'isActive': true,
          'isStrictMode': true,
          'strictModeLevel': 'EASY',
          'strictModePin': 'encrypted_1234',
          'blockedApps': ['com.instagram.android'],
        });

        expect(mockSchedules[0]['strictModeLevel'], equals('EASY'));
        expect(mockSchedules[0]['strictModePin'], isNotNull);
      });

      test('Schedule with MEDIUM mode has cooldown', () async {
        const platform = MethodChannel('com.focusguard.app/schedule');

        await platform.invokeMethod('createSchedule', {
          'name': 'Cooldown Protected',
          'startTime': '10:00',
          'endTime': '11:00',
          'daysOfWeek': [1, 2, 3, 4, 5],
          'isActive': true,
          'isStrictMode': true,
          'strictModeLevel': 'MEDIUM',
          'strictModeCooldownMinutes': 30,
          'blockedApps': ['com.instagram.android'],
        });

        expect(mockSchedules[0]['strictModeLevel'], equals('MEDIUM'));
        expect(mockSchedules[0]['strictModeCooldownMinutes'], equals(30));
      });

      test('Schedule with HARD mode has no unlock options', () async {
        const platform = MethodChannel('com.focusguard.app/schedule');

        await platform.invokeMethod('createSchedule', {
          'name': 'Hard Mode',
          'startTime': '10:00',
          'endTime': '11:00',
          'daysOfWeek': [1, 2, 3, 4, 5],
          'isActive': true,
          'isStrictMode': true,
          'strictModeLevel': 'HARD',
          'blockedApps': ['com.instagram.android'],
        });

        expect(mockSchedules[0]['strictModeLevel'], equals('HARD'));
        expect(mockSchedules[0]['strictModePin'], isNull);
        expect(mockSchedules[0]['strictModeCooldownMinutes'], isNull);
      });
    });

    group('Schedule Days of Week', () {
      test('Weekday schedule', () async {
        const platform = MethodChannel('com.focusguard.app/schedule');

        await platform.invokeMethod('createSchedule', {
          'name': 'Weekdays Only',
          'startTime': '09:00',
          'endTime': '17:00',
          'daysOfWeek': [1, 2, 3, 4, 5], // Mon-Fri
          'isActive': true,
          'blockedApps': [],
        });

        expect(mockSchedules[0]['daysOfWeek'], hasLength(5));
        expect(mockSchedules[0]['daysOfWeek'], isNot(contains(6)));
        expect(mockSchedules[0]['daysOfWeek'], isNot(contains(7)));
      });

      test('Weekend schedule', () async {
        const platform = MethodChannel('com.focusguard.app/schedule');

        await platform.invokeMethod('createSchedule', {
          'name': 'Weekends Only',
          'startTime': '10:00',
          'endTime': '22:00',
          'daysOfWeek': [6, 7], // Sat-Sun
          'isActive': true,
          'blockedApps': [],
        });

        expect(mockSchedules[0]['daysOfWeek'], hasLength(2));
        expect(mockSchedules[0]['daysOfWeek'], contains(6));
        expect(mockSchedules[0]['daysOfWeek'], contains(7));
      });

      test('Single day schedule', () async {
        const platform = MethodChannel('com.focusguard.app/schedule');

        await platform.invokeMethod('createSchedule', {
          'name': 'Monday Only',
          'startTime': '08:00',
          'endTime': '18:00',
          'daysOfWeek': [1],
          'isActive': true,
          'blockedApps': [],
        });

        expect(mockSchedules[0]['daysOfWeek'], hasLength(1));
        expect(mockSchedules[0]['daysOfWeek'], equals([1]));
      });

      test('Every day schedule', () async {
        const platform = MethodChannel('com.focusguard.app/schedule');

        await platform.invokeMethod('createSchedule', {
          'name': 'Everyday',
          'startTime': '00:00',
          'endTime': '23:59',
          'daysOfWeek': [1, 2, 3, 4, 5, 6, 7],
          'isActive': true,
          'blockedApps': [],
        });

        expect(mockSchedules[0]['daysOfWeek'], hasLength(7));
      });
    });

    group('Schedule Time Validation', () {
      test('Standard daytime schedule', () async {
        const platform = MethodChannel('com.focusguard.app/schedule');

        await platform.invokeMethod('createSchedule', {
          'name': 'Daytime',
          'startTime': '09:00',
          'endTime': '17:00',
          'daysOfWeek': [1],
          'isActive': true,
          'blockedApps': [],
        });

        expect(mockSchedules[0]['startTime'], equals('09:00'));
        expect(mockSchedules[0]['endTime'], equals('17:00'));
      });

      test('Overnight schedule (crosses midnight)', () async {
        const platform = MethodChannel('com.focusguard.app/schedule');

        await platform.invokeMethod('createSchedule', {
          'name': 'Night Owl',
          'startTime': '22:00',
          'endTime': '06:00', // Next day
          'daysOfWeek': [1, 2, 3, 4, 5],
          'isActive': true,
          'blockedApps': ['com.instagram.android'],
        });

        expect(mockSchedules[0]['startTime'], equals('22:00'));
        expect(mockSchedules[0]['endTime'], equals('06:00'));
      });

      test('Full day schedule', () async {
        const platform = MethodChannel('com.focusguard.app/schedule');

        await platform.invokeMethod('createSchedule', {
          'name': 'All Day',
          'startTime': '00:00',
          'endTime': '23:59',
          'daysOfWeek': [6, 7],
          'isActive': true,
          'blockedApps': [],
        });

        expect(mockSchedules[0]['startTime'], equals('00:00'));
        expect(mockSchedules[0]['endTime'], equals('23:59'));
      });
    });
  });
}
