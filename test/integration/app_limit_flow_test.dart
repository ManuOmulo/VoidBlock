import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Integration tests for app limit flow
/// Tests limit creation, usage tracking, and enforcement
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('App Limit Flow Integration Tests', () {
    late List<Map<String, dynamic>> mockLimits;
    late Map<String, int> mockUsage;
    late List<MethodCall> methodCalls;

    setUp(() {
      mockLimits = [];
      mockUsage = {};
      methodCalls = [];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.focusguard.app/app_limit'),
        (MethodCall methodCall) async {
          methodCalls.add(methodCall);

          switch (methodCall.method) {
            case 'createLimit':
              final args = Map<String, dynamic>.from(methodCall.arguments);
              args['id'] = mockLimits.length + 1;
              mockLimits.add(args);
              return args['id'];
            case 'getAllLimits':
              return mockLimits;
            case 'getLimitById':
              final id = methodCall.arguments['id'];
              return mockLimits.firstWhere(
                (l) => l['id'] == id,
                orElse: () => <String, dynamic>{},
              );
            case 'updateLimit':
              final args = Map<String, dynamic>.from(methodCall.arguments);
              final index = mockLimits.indexWhere((l) => l['id'] == args['id']);
              if (index >= 0) {
                mockLimits[index] = args;
              }
              return true;
            case 'deleteLimit':
              final id = methodCall.arguments['id'];
              mockLimits.removeWhere((l) => l['id'] == id);
              return true;
            case 'toggleLimit':
              final id = methodCall.arguments['id'];
              final isActive = methodCall.arguments['isActive'];
              final limit = mockLimits.firstWhere((l) => l['id'] == id);
              limit['isActive'] = isActive;
              return true;
            case 'getDailyUsage':
              final packages =
                  List<String>.from(methodCall.arguments['packageNames']);
              final result = <String, int>{};
              for (final pkg in packages) {
                result[pkg] = mockUsage[pkg] ?? 0;
              }
              return result;
            case 'unlockLimit':
              return true;
            case 'requestUnlock':
              return true;
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
          if (methodCall.method == 'isAppBlocked') {
            final packageName = methodCall.arguments['packageName'];

            // Check if any limit is exceeded for this app
            for (final limit in mockLimits) {
              if (limit['isActive'] != true) continue;

              final apps = limit['apps'] as List? ?? [];
              final limitMinutes = limit['limitMinutes'] as int;

              for (final app in apps) {
                String pkg;
                if (app is String) {
                  pkg = app;
                } else if (app is Map) {
                  pkg = app['packageName'];
                } else {
                  continue;
                }

                if (pkg == packageName) {
                  final usage = mockUsage[packageName] ?? 0;
                  if (usage >= limitMinutes) {
                    return true; // Blocked due to limit exceeded
                  }
                }
              }
            }
            return false;
          }
          return null;
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.focusguard.app/app_limit'),
        null,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.focusguard.app/blocking'),
        null,
      );
    });

    group('Limit CRUD Operations', () {
      test('Create limit with all fields', () async {
        const platform = MethodChannel('com.focusguard.app/app_limit');

        final id = await platform.invokeMethod('createLimit', {
          'name': 'Social Media Limit',
          'limitMinutes': 60,
          'isActive': true,
          'isStrictMode': true,
          'strictModeLevel': 'MEDIUM',
          'strictModeCooldownMinutes': 15,
          'apps': ['com.instagram.android', 'com.twitter.android'],
        });

        expect(id, equals(1));
        expect(mockLimits, hasLength(1));
        expect(mockLimits[0]['name'], equals('Social Media Limit'));
        expect(mockLimits[0]['limitMinutes'], equals(60));
        expect(mockLimits[0]['strictModeLevel'], equals('MEDIUM'));
      });

      test('Get all limits returns created limits', () async {
        const platform = MethodChannel('com.focusguard.app/app_limit');

        await platform.invokeMethod('createLimit', {
          'name': 'Limit 1',
          'limitMinutes': 30,
          'isActive': true,
          'apps': ['com.app1'],
        });

        await platform.invokeMethod('createLimit', {
          'name': 'Limit 2',
          'limitMinutes': 60,
          'isActive': true,
          'apps': ['com.app2'],
        });

        final limits = await platform.invokeMethod('getAllLimits');

        expect(limits, hasLength(2));
      });

      test('Toggle limit changes active state', () async {
        const platform = MethodChannel('com.focusguard.app/app_limit');

        await platform.invokeMethod('createLimit', {
          'name': 'Toggle Test',
          'limitMinutes': 30,
          'isActive': true,
          'apps': ['com.app1'],
        });

        expect(mockLimits[0]['isActive'], isTrue);

        await platform.invokeMethod('toggleLimit', {
          'id': 1,
          'isActive': false,
        });

        expect(mockLimits[0]['isActive'], isFalse);
      });

      test('Delete limit removes it', () async {
        const platform = MethodChannel('com.focusguard.app/app_limit');

        await platform.invokeMethod('createLimit', {
          'name': 'To Delete',
          'limitMinutes': 30,
          'isActive': true,
          'apps': ['com.app1'],
        });

        expect(mockLimits, hasLength(1));

        await platform.invokeMethod('deleteLimit', {'id': 1});

        expect(mockLimits, isEmpty);
      });
    });

    group('Usage Tracking', () {
      test('Get daily usage returns correct values', () async {
        const platform = MethodChannel('com.focusguard.app/app_limit');

        // Set up mock usage
        mockUsage['com.instagram.android'] = 45;
        mockUsage['com.twitter.android'] = 30;

        final usage = await platform.invokeMethod('getDailyUsage', {
          'packageNames': ['com.instagram.android', 'com.twitter.android'],
        });

        expect(usage['com.instagram.android'], equals(45));
        expect(usage['com.twitter.android'], equals(30));
      });

      test('Usage returns 0 for apps with no recorded usage', () async {
        const platform = MethodChannel('com.focusguard.app/app_limit');

        final usage = await platform.invokeMethod('getDailyUsage', {
          'packageNames': ['com.new.app'],
        });

        expect(usage['com.new.app'], equals(0));
      });
    });

    group('Limit Enforcement', () {
      test('App NOT blocked when usage under limit', () async {
        const blockingPlatform = MethodChannel('com.focusguard.app/blocking');
        const limitPlatform = MethodChannel('com.focusguard.app/app_limit');

        // Create a limit of 60 minutes
        await limitPlatform.invokeMethod('createLimit', {
          'name': 'Test Limit',
          'limitMinutes': 60,
          'isActive': true,
          'apps': ['com.instagram.android'],
        });

        // Usage is 30 minutes (under limit)
        mockUsage['com.instagram.android'] = 30;

        final isBlocked = await blockingPlatform.invokeMethod('isAppBlocked', {
          'packageName': 'com.instagram.android',
        });

        expect(isBlocked, isFalse);
      });

      test('App IS blocked when usage equals limit', () async {
        const blockingPlatform = MethodChannel('com.focusguard.app/blocking');
        const limitPlatform = MethodChannel('com.focusguard.app/app_limit');

        // Create a limit of 60 minutes
        await limitPlatform.invokeMethod('createLimit', {
          'name': 'Test Limit',
          'limitMinutes': 60,
          'isActive': true,
          'apps': ['com.instagram.android'],
        });

        // Usage equals limit
        mockUsage['com.instagram.android'] = 60;

        final isBlocked = await blockingPlatform.invokeMethod('isAppBlocked', {
          'packageName': 'com.instagram.android',
        });

        expect(isBlocked, isTrue);
      });

      test('App IS blocked when usage exceeds limit', () async {
        const blockingPlatform = MethodChannel('com.focusguard.app/blocking');
        const limitPlatform = MethodChannel('com.focusguard.app/app_limit');

        // Create a limit of 60 minutes
        await limitPlatform.invokeMethod('createLimit', {
          'name': 'Test Limit',
          'limitMinutes': 60,
          'isActive': true,
          'apps': ['com.instagram.android'],
        });

        // Usage exceeds limit
        mockUsage['com.instagram.android'] = 75;

        final isBlocked = await blockingPlatform.invokeMethod('isAppBlocked', {
          'packageName': 'com.instagram.android',
        });

        expect(isBlocked, isTrue);
      });

      test('Inactive limit does NOT block app', () async {
        const blockingPlatform = MethodChannel('com.focusguard.app/blocking');
        const limitPlatform = MethodChannel('com.focusguard.app/app_limit');

        // Create an INACTIVE limit
        await limitPlatform.invokeMethod('createLimit', {
          'name': 'Inactive Limit',
          'limitMinutes': 10,
          'isActive': false, // Inactive
          'apps': ['com.instagram.android'],
        });

        // Usage exceeds limit, but limit is inactive
        mockUsage['com.instagram.android'] = 100;

        final isBlocked = await blockingPlatform.invokeMethod('isAppBlocked', {
          'packageName': 'com.instagram.android',
        });

        expect(isBlocked, isFalse);
      });

      test('Unlisted app is NOT blocked', () async {
        const blockingPlatform = MethodChannel('com.focusguard.app/blocking');
        const limitPlatform = MethodChannel('com.focusguard.app/app_limit');

        // Create a limit for Instagram
        await limitPlatform.invokeMethod('createLimit', {
          'name': 'Instagram Limit',
          'limitMinutes': 30,
          'isActive': true,
          'apps': ['com.instagram.android'],
        });

        // High usage for YouTube (not in limit)
        mockUsage['com.youtube.android'] = 500;

        final isBlocked = await blockingPlatform.invokeMethod('isAppBlocked', {
          'packageName': 'com.youtube.android',
        });

        expect(isBlocked, isFalse);
      });
    });

    group('Multiple Limits', () {
      test('App with multiple limits uses each limit independently', () async {
        const blockingPlatform = MethodChannel('com.focusguard.app/blocking');
        const limitPlatform = MethodChannel('com.focusguard.app/app_limit');

        // Create a generous limit for Instagram
        await limitPlatform.invokeMethod('createLimit', {
          'name': 'Social Limit',
          'limitMinutes': 120,
          'isActive': true,
          'apps': ['com.instagram.android'],
        });

        // Create a strict limit also including Instagram
        await limitPlatform.invokeMethod('createLimit', {
          'name': 'Strict Limit',
          'limitMinutes': 30,
          'isActive': true,
          'apps': ['com.instagram.android', 'com.twitter.android'],
        });

        // Usage of 60 minutes exceeds strict limit but not generous limit
        mockUsage['com.instagram.android'] = 60;

        final isBlocked = await blockingPlatform.invokeMethod('isAppBlocked', {
          'packageName': 'com.instagram.android',
        });

        // Should be blocked by the strict limit
        expect(isBlocked, isTrue);
      });
    });

    group('Limit Strict Mode', () {
      test('Limit with EASY mode has PIN', () async {
        const platform = MethodChannel('com.focusguard.app/app_limit');

        await platform.invokeMethod('createLimit', {
          'name': 'PIN Protected',
          'limitMinutes': 30,
          'isActive': true,
          'isStrictMode': true,
          'strictModeLevel': 'EASY',
          'strictModePin': 'encrypted_1234',
          'apps': ['com.app1'],
        });

        expect(mockLimits[0]['strictModeLevel'], equals('EASY'));
        expect(mockLimits[0]['strictModePin'], isNotNull);
      });

      test('Limit with MEDIUM mode has cooldown', () async {
        const platform = MethodChannel('com.focusguard.app/app_limit');

        await platform.invokeMethod('createLimit', {
          'name': 'Cooldown Protected',
          'limitMinutes': 30,
          'isActive': true,
          'isStrictMode': true,
          'strictModeLevel': 'MEDIUM',
          'strictModeCooldownMinutes': 30,
          'apps': ['com.app1'],
        });

        expect(mockLimits[0]['strictModeLevel'], equals('MEDIUM'));
        expect(mockLimits[0]['strictModeCooldownMinutes'], equals(30));
      });

      test('Limit with HARD mode has time lock', () async {
        const platform = MethodChannel('com.focusguard.app/app_limit');

        await platform.invokeMethod('createLimit', {
          'name': 'Hard Mode',
          'limitMinutes': 30,
          'isActive': true,
          'isStrictMode': true,
          'strictModeLevel': 'HARD',
          'hardModeDurationMinutes': 1440,
          'apps': ['com.app1'],
        });

        expect(mockLimits[0]['strictModeLevel'], equals('HARD'));
        expect(mockLimits[0]['hardModeDurationMinutes'], equals(1440));
      });
    });

    group('Edge Cases', () {
      test('Zero usage never triggers limit', () async {
        const blockingPlatform = MethodChannel('com.focusguard.app/blocking');
        const limitPlatform = MethodChannel('com.focusguard.app/app_limit');

        await limitPlatform.invokeMethod('createLimit', {
          'name': 'Very Strict',
          'limitMinutes': 1, // 1 minute limit
          'isActive': true,
          'apps': ['com.app1'],
        });

        mockUsage['com.app1'] = 0;

        final isBlocked = await blockingPlatform.invokeMethod('isAppBlocked', {
          'packageName': 'com.app1',
        });

        expect(isBlocked, isFalse);
      });

      test('Very large usage is still correctly detected', () async {
        const blockingPlatform = MethodChannel('com.focusguard.app/blocking');
        const limitPlatform = MethodChannel('com.focusguard.app/app_limit');

        await limitPlatform.invokeMethod('createLimit', {
          'name': 'Daily Limit',
          'limitMinutes': 120,
          'isActive': true,
          'apps': ['com.app1'],
        });

        // 10 hours of usage (way over limit)
        mockUsage['com.app1'] = 600;

        final isBlocked = await blockingPlatform.invokeMethod('isAppBlocked', {
          'packageName': 'com.app1',
        });

        expect(isBlocked, isTrue);
      });
    });
  });
}
