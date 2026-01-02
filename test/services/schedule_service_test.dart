import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidblock/services/schedule_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScheduleService', () {
    late ScheduleService scheduleService;
    late List<MethodCall> methodCalls;

    setUp(() {
      scheduleService = ScheduleService();
      methodCalls = [];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.voidblock.app/schedule'),
        (MethodCall methodCall) async {
          methodCalls.add(methodCall);

          switch (methodCall.method) {
            case 'createSchedule':
              return true;
            case 'getAllSchedules':
              return [];
            case 'getScheduleById':
              return null;
            case 'updateSchedule':
              return true;
            case 'deleteSchedule':
              return true;
            case 'toggleSchedule':
              return true;
            case 'getActiveSchedules':
              return [];
            default:
              return null;
          }
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.voidblock.app/schedule'),
        null,
      );
    });

    group('createSchedule', () {
      test('sends correct schedule data to native', () async {
        final schedule = Schedule(
          name: 'Work Focus',
          startTime: '09:00',
          endTime: '17:00',
          daysOfWeek: [1, 2, 3, 4, 5],
          isActive: true,
          isStrictMode: true,
          strictModeLevel: 'MEDIUM',
          strictModeCooldownMinutes: 15,
          blockedApps: ['com.instagram.android', 'com.twitter.android'],
        );

        final result = await scheduleService.createSchedule(schedule);

        expect(result, isTrue);
        expect(methodCalls, hasLength(1));
        expect(methodCalls.first.method, equals('createSchedule'));

        final args = methodCalls.first.arguments as Map;
        expect(args['name'], equals('Work Focus'));
        expect(args['startTime'], equals('09:00'));
        expect(args['endTime'], equals('17:00'));
        expect(args['daysOfWeek'], equals([1, 2, 3, 4, 5]));
        expect(args['isStrictMode'], isTrue);
        expect(args['strictModeLevel'], equals('MEDIUM'));
        expect(args['blockedApps'], hasLength(2));
      });

      test('creates schedule with HARD mode', () async {
        final schedule = Schedule(
          name: 'Hard Mode Focus',
          startTime: '10:00',
          endTime: '12:00',
          daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
          isStrictMode: true,
          strictModeLevel: 'HARD',
          blockedApps: ['com.youtube.android'],
        );

        await scheduleService.createSchedule(schedule);

        final args = methodCalls.first.arguments as Map;
        expect(args['strictModeLevel'], equals('HARD'));
        expect(args['strictModePin'], isNull);
        expect(args['strictModeCooldownMinutes'], isNull);
      });

      test('returns false on platform exception', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.voidblock.app/schedule'),
          (MethodCall methodCall) async {
            throw PlatformException(code: 'ERROR', message: 'Failed');
          },
        );

        final schedule = Schedule(
          name: 'Test',
          startTime: '10:00',
          endTime: '11:00',
          daysOfWeek: [1],
        );

        final result = await scheduleService.createSchedule(schedule);
        expect(result, isFalse);
      });
    });

    group('getAllSchedules', () {
      test('returns empty list when no schedules', () async {
        final result = await scheduleService.getAllSchedules();
        expect(result, isEmpty);
      });

      test('parses multiple schedules correctly', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.voidblock.app/schedule'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getAllSchedules') {
              return [
                {
                  'id': 1,
                  'name': 'Morning Focus',
                  'startTime': '08:00',
                  'endTime': '12:00',
                  'daysOfWeek': [1, 2, 3, 4, 5],
                  'isActive': true,
                  'isStrictMode': false,
                  'blockedApps': ['com.instagram.android'],
                },
                {
                  'id': 2,
                  'name': 'Evening Rest',
                  'startTime': '20:00',
                  'endTime': '22:00',
                  'daysOfWeek': [6, 7],
                  'isActive': false,
                  'isStrictMode': true,
                  'strictModeLevel': 'EASY',
                  'blockedApps': ['com.youtube.android'],
                },
              ];
            }
            return null;
          },
        );

        final result = await scheduleService.getAllSchedules();

        expect(result, hasLength(2));
        expect(result[0].id, equals(1));
        expect(result[0].name, equals('Morning Focus'));
        expect(result[0].isActive, isTrue);
        expect(result[1].id, equals(2));
        expect(result[1].isStrictMode, isTrue);
        expect(result[1].strictModeLevel, equals('EASY'));
      });

      test('returns empty list on platform exception', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.voidblock.app/schedule'),
          (MethodCall methodCall) async {
            throw PlatformException(code: 'ERROR', message: 'Failed');
          },
        );

        final result = await scheduleService.getAllSchedules();
        expect(result, isEmpty);
      });
    });

    group('getScheduleById', () {
      test('returns null for non-existent schedule', () async {
        final result = await scheduleService.getScheduleById(999);
        expect(result, isNull);
      });

      test('returns schedule when found', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.voidblock.app/schedule'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getScheduleById') {
              final id = methodCall.arguments['id'];
              if (id == 1) {
                return {
                  'id': 1,
                  'name': 'Test Schedule',
                  'startTime': '10:00',
                  'endTime': '11:00',
                  'daysOfWeek': [1, 2, 3],
                  'isActive': true,
                  'blockedApps': [],
                };
              }
            }
            return null;
          },
        );

        final result = await scheduleService.getScheduleById(1);

        expect(result, isNotNull);
        expect(result!.id, equals(1));
        expect(result.name, equals('Test Schedule'));
      });
    });

    group('updateSchedule', () {
      test('sends updated schedule data', () async {
        final schedule = Schedule(
          id: 1,
          name: 'Updated Schedule',
          startTime: '11:00',
          endTime: '13:00',
          daysOfWeek: [1, 2, 3],
          isActive: true,
          blockedApps: ['com.updated.app'],
        );

        final result = await scheduleService.updateSchedule(schedule);

        expect(result, isTrue);
        expect(methodCalls.first.method, equals('updateSchedule'));

        final args = methodCalls.first.arguments as Map;
        expect(args['id'], equals(1));
        expect(args['name'], equals('Updated Schedule'));
      });

      test('returns false on platform exception', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.voidblock.app/schedule'),
          (MethodCall methodCall) async {
            throw PlatformException(code: 'ERROR', message: 'Failed');
          },
        );

        final schedule = Schedule(
          id: 1,
          name: 'Test',
          startTime: '10:00',
          endTime: '11:00',
          daysOfWeek: [1],
        );

        final result = await scheduleService.updateSchedule(schedule);
        expect(result, isFalse);
      });
    });

    group('deleteSchedule', () {
      test('deletes schedule by ID', () async {
        final result = await scheduleService.deleteSchedule(1);

        expect(result, isTrue);
        expect(methodCalls.first.method, equals('deleteSchedule'));
        expect(methodCalls.first.arguments['id'], equals(1));
      });

      test('throws exception when HARD mode prevents deletion', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.voidblock.app/schedule'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'deleteSchedule') {
              throw PlatformException(
                code: 'HARD_MODE_ACTIVE',
                message: 'Cannot delete schedule during hard mode',
              );
            }
            return null;
          },
        );

        expect(
          () => scheduleService.deleteSchedule(1),
          throwsA(isA<PlatformException>()),
        );
      });
    });

    group('toggleSchedule', () {
      test('enables schedule', () async {
        final result = await scheduleService.toggleSchedule(1, true);

        expect(result, isTrue);
        expect(methodCalls.first.method, equals('toggleSchedule'));
        expect(methodCalls.first.arguments['id'], equals(1));
        expect(methodCalls.first.arguments['isActive'], isTrue);
      });

      test('disables schedule', () async {
        final result = await scheduleService.toggleSchedule(1, false);

        expect(result, isTrue);
        expect(methodCalls.first.arguments['isActive'], isFalse);
      });

      test('returns false on platform exception', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.voidblock.app/schedule'),
          (MethodCall methodCall) async {
            throw PlatformException(code: 'ERROR', message: 'Failed');
          },
        );

        final result = await scheduleService.toggleSchedule(1, true);
        expect(result, isFalse);
      });
    });

    group('getActiveSchedules', () {
      test('returns empty list when no active schedules', () async {
        final result = await scheduleService.getActiveSchedules();
        expect(result, isEmpty);
      });

      test('returns only currently active schedules', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.voidblock.app/schedule'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getActiveSchedules') {
              return [
                {
                  'id': 1,
                  'name': 'Active Now',
                  'startTime': '00:00',
                  'endTime': '23:59',
                  'daysOfWeek': [1, 2, 3, 4, 5, 6, 7],
                  'isActive': true,
                  'blockedApps': ['com.instagram.android'],
                },
              ];
            }
            return null;
          },
        );

        final result = await scheduleService.getActiveSchedules();

        expect(result, hasLength(1));
        expect(result[0].name, equals('Active Now'));
        expect(result[0].isActive, isTrue);
      });
    });

    group('Schedule Time Validation', () {
      test('overnight schedule (crosses midnight)', () async {
        final schedule = Schedule(
          name: 'Night Owl',
          startTime: '22:00',
          endTime: '06:00', // Next day
          daysOfWeek: [1, 2, 3, 4, 5],
          blockedApps: ['com.app1'],
        );

        await scheduleService.createSchedule(schedule);

        final args = methodCalls.first.arguments as Map;
        expect(args['startTime'], equals('22:00'));
        expect(args['endTime'], equals('06:00'));
      });

      test('full day schedule', () async {
        final schedule = Schedule(
          name: 'All Day',
          startTime: '00:00',
          endTime: '23:59',
          daysOfWeek: [6, 7],
          blockedApps: ['com.app1'],
        );

        await scheduleService.createSchedule(schedule);

        final args = methodCalls.first.arguments as Map;
        expect(args['startTime'], equals('00:00'));
        expect(args['endTime'], equals('23:59'));
      });
    });
  });
}
