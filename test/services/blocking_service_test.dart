import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidblock/services/blocking_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BlockingService', () {
    late BlockingService blockingService;
    late List<MethodCall> methodCalls;

    setUp(() {
      blockingService = BlockingService();
      methodCalls = [];

      // Set up mock method channel handler
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.voidblock.app/blocking'),
        (MethodCall methodCall) async {
          methodCalls.add(methodCall);

          switch (methodCall.method) {
            case 'startBlocking':
              return true;
            case 'stopBlocking':
              return true;
            case 'getActiveSession':
              // Return null for no active session by default
              return null;
            case 'isAppBlocked':
              return false;
            case 'pauseBlocking':
              return true;
            case 'resumeBlocking':
              return true;
            default:
              return null;
          }
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.voidblock.app/blocking'),
        null,
      );
    });

    group('startBlocking', () {
      test('sends correct parameters to native layer', () async {
        final result = await blockingService.startBlocking(
          durationMinutes: 30,
          apps: ['com.instagram.android', 'com.twitter.android'],
          strictMode: true,
          strictModeLevel: 'MEDIUM',
          strictModePin: 'encrypted_1234',
          strictModeCooldownMinutes: 15,
          message: 'Stay focused!',
        );

        expect(result, isTrue);
        expect(methodCalls, hasLength(1));
        expect(methodCalls.first.method, equals('startBlocking'));

        final args = methodCalls.first.arguments as Map;
        expect(args['apps'],
            equals(['com.instagram.android', 'com.twitter.android']));
        expect(args['durationMinutes'], equals(30));
        expect(args['strictMode'], isTrue);
        expect(args['strictModeLevel'], equals('MEDIUM'));
        expect(args['strictModePin'], equals('encrypted_1234'));
        expect(args['strictModeCooldownMinutes'], equals(15));
        expect(args['message'], equals('Stay focused!'));
      });

      test('sends minimal parameters when strict mode disabled', () async {
        await blockingService.startBlocking(
          durationMinutes: 60,
          apps: ['com.youtube.android'],
        );

        expect(methodCalls, hasLength(1));
        final args = methodCalls.first.arguments as Map;
        expect(args['strictMode'], isFalse);
        expect(args['strictModeLevel'], equals('NONE'));
      });

      test('handles different strict mode levels', () async {
        // Test EASY level
        await blockingService.startBlocking(
          durationMinutes: 30,
          apps: ['com.app1'],
          strictMode: true,
          strictModeLevel: 'EASY',
          strictModePin: 'pin123',
        );

        final args = methodCalls.first.arguments as Map;
        expect(args['strictModeLevel'], equals('EASY'));
      });

      test('handles HARD mode (no unlock options)', () async {
        await blockingService.startBlocking(
          durationMinutes: 60,
          apps: ['com.app1'],
          strictMode: true,
          strictModeLevel: 'HARD',
        );

        final args = methodCalls.first.arguments as Map;
        expect(args['strictModeLevel'], equals('HARD'));
        expect(args['strictModePin'], isNull);
        expect(args['strictModeCooldownMinutes'], isNull);
      });
    });

    group('stopBlocking', () {
      test('calls native stopBlocking method', () async {
        final result = await blockingService.stopBlocking();

        expect(result, isTrue);
        expect(methodCalls, hasLength(1));
        expect(methodCalls.first.method, equals('stopBlocking'));
      });

      test('returns false on platform exception', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.voidblock.app/blocking'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'stopBlocking') {
              throw PlatformException(code: 'ERROR', message: 'Cannot stop');
            }
            return null;
          },
        );

        final result = await blockingService.stopBlocking();
        expect(result, isFalse);
      });
    });

    group('getActiveSession', () {
      test('returns null when no active session', () async {
        final result = await blockingService.getActiveSession();
        expect(result, isNull);
      });

      test('returns session data when active', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.voidblock.app/blocking'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getActiveSession') {
              return {
                'id': 1,
                'apps': ['com.instagram.android'],
                'durationMinutes': 30,
                'remainingMinutes': 15,
                'isStrictMode': true,
                'strictModeLevel': 'MEDIUM',
                'isPaused': false,
                'startTime': DateTime.now().millisecondsSinceEpoch,
              };
            }
            return null;
          },
        );

        final result = await blockingService.getActiveSession();

        expect(result, isNotNull);
        expect(result!['id'], equals(1));
        expect(result['apps'], hasLength(1));
        expect(result['durationMinutes'], equals(30));
        expect(result['remainingMinutes'], equals(15));
        expect(result['isStrictMode'], isTrue);
        expect(result['strictModeLevel'], equals('MEDIUM'));
        expect(result['isPaused'], isFalse);
      });

      test('returns null on platform exception', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.voidblock.app/blocking'),
          (MethodCall methodCall) async {
            throw PlatformException(code: 'ERROR', message: 'Failed');
          },
        );

        final result = await blockingService.getActiveSession();
        expect(result, isNull);
      });
    });

    group('isAppBlocked', () {
      test('checks if specific app is blocked', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.voidblock.app/blocking'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'isAppBlocked') {
              final packageName = methodCall.arguments['packageName'];
              return packageName == 'com.instagram.android';
            }
            return false;
          },
        );

        // Instagram should be blocked
        final instagramBlocked =
            await blockingService.isAppBlocked('com.instagram.android');
        expect(instagramBlocked, isTrue);

        // YouTube should not be blocked
        final youtubeBlocked =
            await blockingService.isAppBlocked('com.youtube.android');
        expect(youtubeBlocked, isFalse);
      });

      test('returns false on platform exception', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.voidblock.app/blocking'),
          (MethodCall methodCall) async {
            throw PlatformException(code: 'ERROR', message: 'Failed');
          },
        );

        final result = await blockingService.isAppBlocked('com.any.app');
        expect(result, isFalse);
      });
    });

    group('pauseBlocking', () {
      test('calls native pauseBlocking method', () async {
        final result = await blockingService.pauseBlocking();

        expect(result, isTrue);
        expect(methodCalls.last.method, equals('pauseBlocking'));
      });

      test('returns false when no active session', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.voidblock.app/blocking'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'pauseBlocking') {
              throw PlatformException(
                code: 'NO_SESSION',
                message: 'No active session to pause',
              );
            }
            return null;
          },
        );

        final result = await blockingService.pauseBlocking();
        expect(result, isFalse);
      });
    });

    group('resumeBlocking', () {
      test('calls native resumeBlocking method', () async {
        final result = await blockingService.resumeBlocking();

        expect(result, isTrue);
        expect(methodCalls.last.method, equals('resumeBlocking'));
      });

      test('returns false when no paused session', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.voidblock.app/blocking'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'resumeBlocking') {
              throw PlatformException(
                code: 'NOT_PAUSED',
                message: 'Session not paused',
              );
            }
            return null;
          },
        );

        final result = await blockingService.resumeBlocking();
        expect(result, isFalse);
      });
    });

    group('Session State Transitions', () {
      test('complete blocking lifecycle', () async {
        // 1. Start blocking
        await blockingService.startBlocking(
          durationMinutes: 30,
          apps: ['com.instagram.android'],
        );

        // 2. Pause blocking
        await blockingService.pauseBlocking();

        // 3. Resume blocking
        await blockingService.resumeBlocking();

        // 4. Stop blocking
        await blockingService.stopBlocking();

        expect(methodCalls, hasLength(4));
        expect(methodCalls[0].method, equals('startBlocking'));
        expect(methodCalls[1].method, equals('pauseBlocking'));
        expect(methodCalls[2].method, equals('resumeBlocking'));
        expect(methodCalls[3].method, equals('stopBlocking'));
      });
    });
  });
}
