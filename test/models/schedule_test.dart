import 'package:flutter_test/flutter_test.dart';
import 'package:voidblock/services/schedule_service.dart';

void main() {
  group('Schedule Model', () {
    group('JSON Serialization', () {
      test('toJson serializes all fields correctly', () {
        final schedule = Schedule(
          id: 1,
          name: 'Work Focus',
          startTime: '09:00',
          endTime: '17:00',
          daysOfWeek: [1, 2, 3, 4, 5],
          isActive: true,
          isPaused: false,
          isStrictMode: true,
          strictModeLevel: 'MEDIUM',
          strictModePin: 'encrypted_pin',
          strictModeCooldownMinutes: 15,
          motivationalMessage: 'Stay focused!',
          notificationsEnabled: true,
          blockedApps: ['com.instagram.android', 'com.twitter.android'],
        );

        final json = schedule.toJson();

        expect(json['id'], equals(1));
        expect(json['name'], equals('Work Focus'));
        expect(json['startTime'], equals('09:00'));
        expect(json['endTime'], equals('17:00'));
        expect(json['daysOfWeek'], equals([1, 2, 3, 4, 5]));
        expect(json['isActive'], isTrue);
        expect(json['isPaused'], isFalse);
        expect(json['isStrictMode'], isTrue);
        expect(json['strictModeLevel'], equals('MEDIUM'));
        expect(json['strictModePin'], equals('encrypted_pin'));
        expect(json['strictModeCooldownMinutes'], equals(15));
        expect(json['motivationalMessage'], equals('Stay focused!'));
        expect(json['notificationsEnabled'], isTrue);
        expect(json['blockedApps'], hasLength(2));
      });

      test('fromJson deserializes all fields correctly', () {
        final json = {
          'id': 2,
          'name': 'Evening Rest',
          'startTime': '20:00',
          'endTime': '22:00',
          'daysOfWeek': [6, 7],
          'isActive': false,
          'isPaused': true,
          'isStrictMode': false,
          'strictModeLevel': 'NONE',
          'strictModePin': null,
          'strictModeCooldownMinutes': null,
          'motivationalMessage': 'Relax time',
          'notificationsEnabled': false,
          'blockedApps': ['com.youtube.android'],
        };

        final schedule = Schedule.fromJson(json);

        expect(schedule.id, equals(2));
        expect(schedule.name, equals('Evening Rest'));
        expect(schedule.startTime, equals('20:00'));
        expect(schedule.endTime, equals('22:00'));
        expect(schedule.daysOfWeek, equals([6, 7]));
        expect(schedule.isActive, isFalse);
        expect(schedule.isPaused, isTrue);
        expect(schedule.isStrictMode, isFalse);
        expect(schedule.strictModeLevel, equals('NONE'));
        expect(schedule.strictModePin, isNull);
        expect(schedule.strictModeCooldownMinutes, isNull);
        expect(schedule.motivationalMessage, equals('Relax time'));
        expect(schedule.notificationsEnabled, isFalse);
        expect(schedule.blockedApps, hasLength(1));
      });

      test('round-trip serialization preserves data', () {
        final original = Schedule(
          id: 10,
          name: 'Test Schedule',
          startTime: '10:30',
          endTime: '14:45',
          daysOfWeek: [1, 3, 5],
          isActive: true,
          isStrictMode: true,
          strictModeLevel: 'HARD',
          blockedApps: ['com.app1', 'com.app2', 'com.app3'],
        );

        final json = original.toJson();
        final restored = Schedule.fromJson(json);

        expect(restored.id, equals(original.id));
        expect(restored.name, equals(original.name));
        expect(restored.startTime, equals(original.startTime));
        expect(restored.endTime, equals(original.endTime));
        expect(restored.daysOfWeek, equals(original.daysOfWeek));
        expect(restored.isActive, equals(original.isActive));
        expect(restored.isStrictMode, equals(original.isStrictMode));
        expect(restored.strictModeLevel, equals(original.strictModeLevel));
        expect(restored.blockedApps, equals(original.blockedApps));
      });
    });

    group('Default Values', () {
      test('fromJson handles missing optional fields with defaults', () {
        final minimalJson = {
          'name': 'Minimal Schedule',
          'startTime': '08:00',
          'endTime': '09:00',
        };

        final schedule = Schedule.fromJson(minimalJson);

        expect(schedule.id, isNull);
        expect(schedule.isActive, isTrue); // Default
        expect(schedule.isPaused, isFalse); // Default
        expect(schedule.isStrictMode, isFalse); // Default
        expect(schedule.notificationsEnabled, isTrue); // Default
        expect(schedule.daysOfWeek, isEmpty);
        expect(schedule.blockedApps, isEmpty);
      });

      test('fromJson handles null list fields', () {
        final jsonWithNulls = {
          'name': 'Test',
          'startTime': '10:00',
          'endTime': '11:00',
          'daysOfWeek': null,
          'blockedApps': null,
        };

        final schedule = Schedule.fromJson(jsonWithNulls);

        expect(schedule.daysOfWeek, isEmpty);
        expect(schedule.blockedApps, isEmpty);
      });
    });

    group('Strict Mode Levels', () {
      test('NONE level serialization', () {
        final schedule = Schedule(
          name: 'No Strict',
          startTime: '10:00',
          endTime: '11:00',
          daysOfWeek: [1],
          isStrictMode: false,
          strictModeLevel: null,
        );

        final json = schedule.toJson();
        expect(json['isStrictMode'], isFalse);
        expect(json['strictModeLevel'], isNull);
      });

      test('EASY level requires PIN', () {
        final schedule = Schedule(
          name: 'Easy Strict',
          startTime: '10:00',
          endTime: '11:00',
          daysOfWeek: [1],
          isStrictMode: true,
          strictModeLevel: 'EASY',
          strictModePin: 'encrypted_1234',
        );

        final json = schedule.toJson();
        expect(json['isStrictMode'], isTrue);
        expect(json['strictModeLevel'], equals('EASY'));
        expect(json['strictModePin'], isNotNull);
      });

      test('MEDIUM level requires cooldown', () {
        final schedule = Schedule(
          name: 'Medium Strict',
          startTime: '10:00',
          endTime: '11:00',
          daysOfWeek: [1],
          isStrictMode: true,
          strictModeLevel: 'MEDIUM',
          strictModeCooldownMinutes: 30,
        );

        final json = schedule.toJson();
        expect(json['strictModeLevel'], equals('MEDIUM'));
        expect(json['strictModeCooldownMinutes'], equals(30));
      });

      test('HARD level has no unlock options', () {
        final schedule = Schedule(
          name: 'Hard Strict',
          startTime: '10:00',
          endTime: '11:00',
          daysOfWeek: [1],
          isStrictMode: true,
          strictModeLevel: 'HARD',
        );

        final json = schedule.toJson();
        expect(json['strictModeLevel'], equals('HARD'));
        expect(json['strictModePin'], isNull);
        expect(json['strictModeCooldownMinutes'], isNull);
      });
    });

    group('Days of Week', () {
      test('weekdays pattern', () {
        final schedule = Schedule(
          name: 'Weekdays',
          startTime: '09:00',
          endTime: '17:00',
          daysOfWeek: [1, 2, 3, 4, 5], // Mon-Fri
        );

        expect(schedule.daysOfWeek, hasLength(5));
        expect(schedule.daysOfWeek, isNot(contains(6))); // No Saturday
        expect(schedule.daysOfWeek, isNot(contains(7))); // No Sunday
      });

      test('weekend pattern', () {
        final schedule = Schedule(
          name: 'Weekend',
          startTime: '10:00',
          endTime: '22:00',
          daysOfWeek: [6, 7], // Sat-Sun
        );

        expect(schedule.daysOfWeek, hasLength(2));
        expect(schedule.daysOfWeek, contains(6));
        expect(schedule.daysOfWeek, contains(7));
      });

      test('everyday pattern', () {
        final schedule = Schedule(
          name: 'Everyday',
          startTime: '00:00',
          endTime: '23:59',
          daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
        );

        expect(schedule.daysOfWeek, hasLength(7));
      });
    });
  });
}
