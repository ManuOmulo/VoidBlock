import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusguard/services/app_limit_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppLimitService', () {
    late AppLimitService appLimitService;
    late List<MethodCall> methodCalls;

    setUp(() {
      appLimitService = AppLimitService();
      methodCalls = [];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.focusguard.app/app_limit'),
        (MethodCall methodCall) async {
          methodCalls.add(methodCall);

          switch (methodCall.method) {
            case 'createLimit':
              return 1; // Return created ID
            case 'getAllLimits':
              return [];
            case 'getLimitById':
              return null;
            case 'updateLimit':
              return true;
            case 'deleteLimit':
              return true;
            case 'toggleLimit':
              return true;
            case 'unlockLimit':
              return true;
            case 'requestUnlock':
              return true;
            case 'getDailyUsage':
              return <String, int>{};
            default:
              return null;
          }
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.focusguard.app/app_limit'),
        null,
      );
    });

    group('createLimit', () {
      test('sends correct limit data to native', () async {
        final limit = AppLimit(
          name: 'Social Media Limit',
          limitMinutes: 60,
          isActive: true,
          isStrictMode: true,
          strictModeLevel: 'MEDIUM',
          strictModeCooldownMinutes: 15,
          apps: ['com.instagram.android', 'com.twitter.android'],
        );

        final result = await appLimitService.createLimit(limit);

        expect(result, equals(1));
        expect(methodCalls, hasLength(1));
        expect(methodCalls.first.method, equals('createLimit'));

        final args = methodCalls.first.arguments as Map;
        expect(args['name'], equals('Social Media Limit'));
        expect(args['limitMinutes'], equals(60));
        expect(args['isStrictMode'], isTrue);
        expect(args['strictModeLevel'], equals('MEDIUM'));
        expect(args['strictModeCooldownMinutes'], equals(15));
        expect(args['apps'], hasLength(2));
      });

      test('creates limit with EASY mode (PIN)', () async {
        final limit = AppLimit(
          name: 'PIN Protected',
          limitMinutes: 30,
          isStrictMode: true,
          strictModeLevel: 'EASY',
          strictModePin: 'encrypted_1234',
          apps: ['com.youtube.android'],
        );

        await appLimitService.createLimit(limit);

        final args = methodCalls.first.arguments as Map;
        expect(args['strictModeLevel'], equals('EASY'));
        expect(args['strictModePin'], equals('encrypted_1234'));
      });

      test('creates limit with HARD mode', () async {
        final limit = AppLimit(
          name: 'Hard Locked',
          limitMinutes: 60,
          isStrictMode: true,
          strictModeLevel: 'HARD',
          hardModeDurationMinutes: 1440, // 24 hours
          apps: ['com.game.android'],
        );

        await appLimitService.createLimit(limit);

        final args = methodCalls.first.arguments as Map;
        expect(args['strictModeLevel'], equals('HARD'));
        expect(args['hardModeDurationMinutes'], equals(1440));
      });

      test('returns null on platform exception', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.focusguard.app/app_limit'),
          (MethodCall methodCall) async {
            throw PlatformException(code: 'ERROR', message: 'Failed');
          },
        );

        final limit = AppLimit(
          name: 'Test',
          limitMinutes: 30,
          apps: ['com.app'],
        );

        final result = await appLimitService.createLimit(limit);
        expect(result, isNull);
      });
    });

    group('getAllLimits', () {
      test('returns empty list when no limits', () async {
        final result = await appLimitService.getAllLimits();
        expect(result, isEmpty);
      });

      test('parses multiple limits correctly', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.focusguard.app/app_limit'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getAllLimits') {
              return [
                {
                  'id': 1,
                  'name': 'Social Media',
                  'limitMinutes': 60,
                  'isActive': true,
                  'isStrictMode': false,
                  'strictModeLevel': 'NONE',
                  'apps': ['com.instagram.android'],
                },
                {
                  'id': 2,
                  'name': 'Gaming',
                  'limitMinutes': 120,
                  'isActive': true,
                  'isStrictMode': true,
                  'strictModeLevel': 'HARD',
                  'hardModeEndsAt': 1704153600000,
                  'apps': ['com.game1', 'com.game2'],
                },
              ];
            }
            return null;
          },
        );

        final result = await appLimitService.getAllLimits();

        expect(result, hasLength(2));
        expect(result[0].id, equals(1));
        expect(result[0].name, equals('Social Media'));
        expect(result[0].isStrictMode, isFalse);
        expect(result[1].id, equals(2));
        expect(result[1].strictModeLevel, equals('HARD'));
        expect(result[1].hardModeEndsAt, isNotNull);
      });
    });

    group('getDailyUsage', () {
      test('returns empty map when no usage', () async {
        final result = await appLimitService.getDailyUsage(['com.app']);
        expect(result, isEmpty);
      });

      test('returns usage data for requested packages', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.focusguard.app/app_limit'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getDailyUsage') {
              return {
                'com.instagram.android': 45,
                'com.twitter.android': 30,
                'com.youtube.android': 120,
              };
            }
            return null;
          },
        );

        final result = await appLimitService.getDailyUsage([
          'com.instagram.android',
          'com.twitter.android',
          'com.youtube.android',
        ]);

        expect(result, hasLength(3));
        expect(result['com.instagram.android'], equals(45));
        expect(result['com.twitter.android'], equals(30));
        expect(result['com.youtube.android'], equals(120));
      });

      test('sends correct package names to native', () async {
        await appLimitService.getDailyUsage(['com.app1', 'com.app2']);

        expect(methodCalls.first.method, equals('getDailyUsage'));
        expect(
          methodCalls.first.arguments['packageNames'],
          equals(['com.app1', 'com.app2']),
        );
      });
    });

    group('toggleLimit', () {
      test('enables limit', () async {
        final result = await appLimitService.toggleLimit(1, true);

        expect(result, isTrue);
        expect(methodCalls.first.method, equals('toggleLimit'));
        expect(methodCalls.first.arguments['id'], equals(1));
        expect(methodCalls.first.arguments['isActive'], isTrue);
      });

      test('disables limit', () async {
        final result = await appLimitService.toggleLimit(1, false);

        expect(result, isTrue);
        expect(methodCalls.first.arguments['isActive'], isFalse);
      });
    });

    group('unlockLimit', () {
      test('unlocks limit by ID', () async {
        final result = await appLimitService.unlockLimit(1);

        expect(result, isTrue);
        expect(methodCalls.first.method, equals('unlockLimit'));
        expect(methodCalls.first.arguments['id'], equals(1));
      });

      test('returns false on platform exception', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.focusguard.app/app_limit'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'unlockLimit') {
              throw PlatformException(
                code: 'HARD_MODE',
                message: 'Cannot unlock during hard mode',
              );
            }
            return null;
          },
        );

        final result = await appLimitService.unlockLimit(1);
        expect(result, isFalse);
      });
    });

    group('requestUnlock', () {
      test('requests unlock for limit', () async {
        final result = await appLimitService.requestUnlock(1);

        expect(result, isTrue);
        expect(methodCalls.first.method, equals('requestUnlock'));
        expect(methodCalls.first.arguments['id'], equals(1));
      });
    });

    group('deleteLimit', () {
      test('deletes limit by ID', () async {
        final result = await appLimitService.deleteLimit(1);

        expect(result, isTrue);
        expect(methodCalls.first.method, equals('deleteLimit'));
        expect(methodCalls.first.arguments['id'], equals(1));
      });

      test('throws exception when HARD mode prevents deletion', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.focusguard.app/app_limit'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'deleteLimit') {
              throw PlatformException(
                code: 'HARD_MODE_ACTIVE',
                message: 'Cannot delete limit during hard mode lock',
              );
            }
            return null;
          },
        );

        expect(
          () => appLimitService.deleteLimit(1),
          throwsA(isA<PlatformException>()),
        );
      });
    });

    group('Limit Enforcement Scenarios', () {
      test('usage under limit - not enforced', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.focusguard.app/app_limit'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getDailyUsage') {
              return {'com.instagram.android': 30}; // 30 min used
            }
            if (methodCall.method == 'getAllLimits') {
              return [
                {
                  'id': 1,
                  'name': 'Social',
                  'limitMinutes': 60, // 60 min limit
                  'isActive': true,
                  'apps': ['com.instagram.android'],
                }
              ];
            }
            return null;
          },
        );

        final usage =
            await appLimitService.getDailyUsage(['com.instagram.android']);
        final limits = await appLimitService.getAllLimits();

        // 30 min used < 60 min limit
        expect(
            usage['com.instagram.android']!, lessThan(limits[0].limitMinutes));
      });

      test('usage at limit - should enforce', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.focusguard.app/app_limit'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getDailyUsage') {
              return {'com.instagram.android': 60}; // At limit
            }
            if (methodCall.method == 'getAllLimits') {
              return [
                {
                  'id': 1,
                  'name': 'Social',
                  'limitMinutes': 60,
                  'isActive': true,
                  'apps': ['com.instagram.android'],
                }
              ];
            }
            return null;
          },
        );

        final usage =
            await appLimitService.getDailyUsage(['com.instagram.android']);
        final limits = await appLimitService.getAllLimits();

        expect(usage['com.instagram.android']!, equals(limits[0].limitMinutes));
      });

      test('usage over limit - should enforce', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.focusguard.app/app_limit'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getDailyUsage') {
              return {'com.instagram.android': 75}; // Over limit
            }
            if (methodCall.method == 'getAllLimits') {
              return [
                {
                  'id': 1,
                  'name': 'Social',
                  'limitMinutes': 60,
                  'isActive': true,
                  'apps': ['com.instagram.android'],
                }
              ];
            }
            return null;
          },
        );

        final usage =
            await appLimitService.getDailyUsage(['com.instagram.android']);
        final limits = await appLimitService.getAllLimits();

        expect(usage['com.instagram.android']!,
            greaterThan(limits[0].limitMinutes));
      });
    });
  });
}
