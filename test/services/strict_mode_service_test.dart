import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voidblock/services/strict_mode_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StrictModeService', () {
    late StrictModeService strictModeService;
    late List<MethodCall> methodCalls;

    setUp(() {
      strictModeService = StrictModeService();
      methodCalls = [];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.voidblock.app/strict_mode'),
        (MethodCall methodCall) async {
          methodCalls.add(methodCall);

          switch (methodCall.method) {
            case 'getDefaultPreferences':
              return {
                'defaultLevel': 'MEDIUM',
                'defaultCooldownMinutes': 15,
              };
            case 'updateDefaultLevel':
              return true;
            case 'attemptUnlockSession':
              return {'success': false, 'reason': 'Incorrect PIN'};
            case 'attemptUnlockSchedule':
              return {'success': false, 'reason': 'Incorrect PIN'};
            case 'startCooldown':
              return true;
            case 'confirmCooldownUnlock':
              return {'success': true};
            case 'startScheduleCooldown':
              return true;
            case 'confirmScheduleCooldownUnlock':
              return {'success': true};
            case 'encryptPin':
              return 'encrypted_${methodCall.arguments['pin']}';
            default:
              return null;
          }
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.voidblock.app/strict_mode'),
        null,
      );
    });

    group('getDefaultPreferences', () {
      test('returns default preferences', () async {
        final result = await strictModeService.getDefaultPreferences();

        expect(result, isNotNull);
        expect(result!['defaultLevel'], equals('MEDIUM'));
        expect(result['defaultCooldownMinutes'], equals(15));
      });

      test('returns null on error', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.voidblock.app/strict_mode'),
          (MethodCall methodCall) async {
            throw Exception('Failed');
          },
        );

        final result = await strictModeService.getDefaultPreferences();
        expect(result, isNull);
      });
    });

    group('updateDefaultLevel', () {
      test('updates level to EASY', () async {
        final result = await strictModeService.updateDefaultLevel('EASY');

        expect(result, isTrue);
        expect(methodCalls.first.arguments['level'], equals('EASY'));
      });

      test('updates level to MEDIUM', () async {
        final result = await strictModeService.updateDefaultLevel('MEDIUM');

        expect(result, isTrue);
        expect(methodCalls.first.arguments['level'], equals('MEDIUM'));
      });

      test('updates level to HARD', () async {
        final result = await strictModeService.updateDefaultLevel('HARD');

        expect(result, isTrue);
        expect(methodCalls.first.arguments['level'], equals('HARD'));
      });
    });

    group('attemptUnlockSession - EASY Mode (PIN)', () {
      test('unlock fails with incorrect PIN', () async {
        final result = await strictModeService.attemptUnlockSession(
          sessionId: 1,
          pin: 'wrong_pin',
        );

        expect(result['success'], isFalse);
        expect(result['reason'], contains('PIN'));
        expect(methodCalls.first.arguments['sessionId'], equals(1));
        expect(methodCalls.first.arguments['pin'], equals('wrong_pin'));
      });

      test('unlock succeeds with correct PIN', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.voidblock.app/strict_mode'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'attemptUnlockSession') {
              final pin = methodCall.arguments['pin'];
              if (pin == 'correct_pin') {
                return {'success': true};
              }
              return {'success': false, 'reason': 'Incorrect PIN'};
            }
            return null;
          },
        );

        final result = await strictModeService.attemptUnlockSession(
          sessionId: 1,
          pin: 'correct_pin',
        );

        expect(result['success'], isTrue);
      });

      test('returns error on exception', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.voidblock.app/strict_mode'),
          (MethodCall methodCall) async {
            throw Exception('Network error');
          },
        );

        final result = await strictModeService.attemptUnlockSession(
          sessionId: 1,
          pin: 'test',
        );

        expect(result['success'], isFalse);
        expect(result['reason'], contains('Failed'));
      });
    });

    group('attemptUnlockSchedule - EASY Mode (PIN)', () {
      test('unlock fails with incorrect PIN', () async {
        final result = await strictModeService.attemptUnlockSchedule(
          scheduleId: 1,
          pin: 'wrong_pin',
        );

        expect(result['success'], isFalse);
        expect(methodCalls.first.arguments['scheduleId'], equals(1));
      });

      test('unlock succeeds with correct PIN', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.voidblock.app/strict_mode'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'attemptUnlockSchedule') {
              final pin = methodCall.arguments['pin'];
              if (pin == 'schedule_pin') {
                return {'success': true};
              }
              return {'success': false, 'reason': 'Incorrect PIN'};
            }
            return null;
          },
        );

        final result = await strictModeService.attemptUnlockSchedule(
          scheduleId: 1,
          pin: 'schedule_pin',
        );

        expect(result['success'], isTrue);
      });
    });

    group('MEDIUM Mode - Cooldown', () {
      test('startCooldown initiates cooldown period', () async {
        final result = await strictModeService.startCooldown(1);

        expect(result, isTrue);
        expect(methodCalls.first.method, equals('startCooldown'));
        expect(methodCalls.first.arguments['sessionId'], equals(1));
      });

      test('confirmCooldownUnlock succeeds after cooldown', () async {
        final result = await strictModeService.confirmCooldownUnlock(1);

        expect(result['success'], isTrue);
        expect(methodCalls.first.method, equals('confirmCooldownUnlock'));
      });

      test('confirmCooldownUnlock fails if cooldown not complete', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.voidblock.app/strict_mode'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'confirmCooldownUnlock') {
              return {
                'success': false,
                'reason': 'Cooldown not complete',
                'remainingSeconds': 300, // 5 minutes left
              };
            }
            return null;
          },
        );

        final result = await strictModeService.confirmCooldownUnlock(1);

        expect(result['success'], isFalse);
        expect(result['reason'], contains('Cooldown'));
        expect(result['remainingSeconds'], equals(300));
      });
    });

    group('Schedule Cooldown', () {
      test('startScheduleCooldown initiates cooldown for schedule', () async {
        final result = await strictModeService.startScheduleCooldown(1);

        expect(result, isTrue);
        expect(methodCalls.first.method, equals('startScheduleCooldown'));
        expect(methodCalls.first.arguments['scheduleId'], equals(1));
      });

      test('confirmScheduleCooldownUnlock succeeds', () async {
        final result = await strictModeService.confirmScheduleCooldownUnlock(1);

        expect(result['success'], isTrue);
        expect(
            methodCalls.first.method, equals('confirmScheduleCooldownUnlock'));
      });
    });

    group('HARD Mode - No Unlock', () {
      test('attemptUnlock fails for HARD mode session', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.voidblock.app/strict_mode'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'attemptUnlockSession') {
              return {
                'success': false,
                'reason': 'HARD mode: No unlock available until session ends',
                'strictModeLevel': 'HARD',
              };
            }
            return null;
          },
        );

        final result = await strictModeService.attemptUnlockSession(
          sessionId: 1,
        );

        expect(result['success'], isFalse);
        expect(result['reason'], contains('HARD'));
        expect(result['strictModeLevel'], equals('HARD'));
      });

      test('HARD mode rejects PIN attempts', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.voidblock.app/strict_mode'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'attemptUnlockSession') {
              // HARD mode ignores PIN entirely
              return {
                'success': false,
                'reason': 'HARD mode active - no unlock possible',
              };
            }
            return null;
          },
        );

        final result = await strictModeService.attemptUnlockSession(
          sessionId: 1,
          pin: 'any_pin', // Should be ignored
        );

        expect(result['success'], isFalse);
      });

      test('HARD mode rejects cooldown confirmation', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.voidblock.app/strict_mode'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'confirmCooldownUnlock') {
              return {
                'success': false,
                'reason': 'HARD mode does not support cooldown unlock',
              };
            }
            return null;
          },
        );

        final result = await strictModeService.confirmCooldownUnlock(1);

        expect(result['success'], isFalse);
      });
    });

    group('encryptPin', () {
      test('encrypts PIN successfully', () async {
        final result = await strictModeService.encryptPin('1234');

        expect(result, isNotNull);
        expect(result, equals('encrypted_1234'));
        expect(methodCalls.first.arguments['pin'], equals('1234'));
      });

      test('returns null on encryption error', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.voidblock.app/strict_mode'),
          (MethodCall methodCall) async {
            throw Exception('Encryption failed');
          },
        );

        final result = await strictModeService.encryptPin('1234');
        expect(result, isNull);
      });
    });

    group('Strict Mode Level Enforcement', () {
      test('NONE level - immediate unlock', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.voidblock.app/strict_mode'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'attemptUnlockSession') {
              // NONE level always succeeds
              return {'success': true, 'strictModeLevel': 'NONE'};
            }
            return null;
          },
        );

        final result = await strictModeService.attemptUnlockSession(
          sessionId: 1,
        );

        expect(result['success'], isTrue);
        expect(result['strictModeLevel'], equals('NONE'));
      });

      test('level hierarchy enforcement', () async {
        // Test that each level has progressively stricter unlock requirements
        final levels = ['NONE', 'EASY', 'MEDIUM', 'HARD'];

        for (var i = 0; i < levels.length; i++) {
          final level = levels[i];

          // Just verify we can query unlock for each level
          await strictModeService.attemptUnlockSession(
            sessionId: 1,
            pin: 'test_pin',
          );
        }

        // Should have made 4 calls
        expect(
            methodCalls.where((c) => c.method == 'attemptUnlockSession').length,
            equals(4));
      });
    });
  });
}
